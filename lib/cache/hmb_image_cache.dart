/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton.
 All Rights Reserved.

 GPL terms per repo license.
*/

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dcli_core/dcli_core.dart';
import 'package:path/path.dart' as p;

import '../database/management/backup_providers/google_drive/background_backup/background_backup.g.dart';
import '../util/dart/paths.dart';
import '../util/dart/photo_meta.dart';
import 'image_cache_config.dart';
import 'image_compress_job.dart';

typedef Key = String;

/// LRU cache of *image variants* keyed by (photoId, variant).
/// Filenames: `<photoId>__<variant>.<ext>`
class HMBImageCache {
  final ImageCacheConfig _config;

  final _cacheDirName = 'photo_image_cache';
  late String _cacheDir;
  late String _indexPath;

  // composite key: "$photoId|$variant" -> entry
  final _entries = <Key, _Entry>{};
  var _totalBytes = 0;
  var _initialised = false;

  // singleton
  static HMBImageCache? _instance;

  factory HMBImageCache() {
    _instance ??= HMBImageCache._();
    return _instance!;
  }

  HMBImageCache._()
    : _config = ImageCacheConfig(
        downloader: (photoId, pathToCacheStorage, cloudStoragePath) =>
            PhotoSyncService().download(
              photoId,
              pathToCacheStorage,
              cloudStoragePath,
            ),
      );

  Future<void> init() async {
    if (_initialised) {
      return;
    }
    final base = await getTemporaryDirectory();
    _cacheDir = p.join(base, _cacheDirName);
    if (!exists(_cacheDir)) {
      createDir(_cacheDir, recursive: true);
    }
    _indexPath = p.join(_cacheDir, '_index.json');
    await _loadIndex();
    await _reconcileDisk();
    _initialised = true;
  }

  // ---------------------------------------------------------------------------
  // PhotoMeta-first API (primary)
  // ---------------------------------------------------------------------------

  /// Returns a local path for [variant] of [meta].
  ///
  /// - general: returns original immediately, compresses to WebP in background.
  /// - pdf/thumb: generates synchronously on first call, then cached.
  /// - raw: returns original; if [cacheRaw] true, also stores a copy in cache.
  ///
  Future<Path> getVariantPathForMeta({
    required PhotoMeta meta,
    required ImageVariant variant,
    Future<void> Function(PhotoMeta meta, String storeToPath)? ensureOriginalAt,

    bool cacheRaw = false,
  }) async {
    if (!_initialised) {
      await init();
    }

    await meta.resolve();
    final photoId = meta.photo.id;
    final localOriginalPath = meta.absolutePathTo;

    return getVariantPath(
      photoId: photoId,
      variant: variant,
      localCachePath: localOriginalPath,
      cloudStoragePath: await meta.cloudStoragePath,
      ensureOriginalAt: (photoId, src, dst) =>
          ensureOriginalAt?.call(meta, dst) ??
          _config.downloader(photoId, src, dst),
      cacheRaw: cacheRaw,
    );
  }

  /// Convenience for bytes (useful for PDF generation).
  Future<Uint8List> getVariantBytesForMeta({
    required PhotoMeta meta,
    required ImageVariant variant,
    Future<void> Function(PhotoMeta meta, String storeToPath)? ensureOriginalAt,
  }) async {
    final path = await getVariantPathForMeta(
      meta: meta,
      variant: variant,
      ensureOriginalAt: ensureOriginalAt,
    );
    return File(path).readAsBytes();
  }

  // ---------------------------------------------------------------------------
  // Existing ID/path-based API (kept for internal reuse)
  // ---------------------------------------------------------------------------

  Future<String> getVariantPath({
    required int photoId,
    required ImageVariant variant,
    required String localCachePath,
    required String cloudStoragePath,
    Future<void> Function(
      int photoId,
      Path localCachPath,
      Path cloudStoragePath,
    )?
    ensureOriginalAt,
    bool cacheRaw = false,
  }) async {
    if (!_initialised) {
      await init();
    }

    final key = _key(photoId.toString(), variant);
    final existing = await _cachedIfExists(key);
    if (existing != null) {
      await _touch(key);
      return existing;
    }

    // ensure original is available
    if (!exists(localCachePath)) {
      createDir(p.dirname(localCachePath), recursive: true);
      await (ensureOriginalAt?.call(
            photoId,
            localCachePath,
            cloudStoragePath,
          ) ??
          _config.downloader(photoId, localCachePath, cloudStoragePath));
    }

    final variantPath = _variantPath(photoId, variant);

    if (variant == ImageVariant.general) {
      // non-blocking background compress
      unawaited(
        _backgroundCompress(
          src: localCachePath,
          dst: variantPath,
          key: key,
          variant: variant,
        ),
      );
      return localCachePath;
    }

    if (variant == ImageVariant.raw) {
      if (cacheRaw) {
        if (!exists(variantPath)) {
          copy(localCachePath, variantPath);
        }
        await _upsertEntry(key, p.basename(variantPath));
        await _trimIfNeeded();
        return variantPath;
      } else {
        return localCachePath;
      }
    }

    // pdf/thumb sync compress (callers often need bytes immediately)
    await _compressSync(
      src: localCachePath,
      dst: variantPath,
      key: key,
      variant: variant,
    );
    return variantPath;
  }

  Future<List<int>> getVariantBytes({
    required int photoId,
    required ImageVariant variant,
    required String localCachePath,
    required String cloudStoragePath,
    required Future<void> Function(
      int photoId,
      Path pathToCacheStorage,
      Path pathToCloudStorage,
    )
    ensureOriginalAt,
  }) async {
    final path = await getVariantPath(
      photoId: photoId,
      variant: variant,
      localCachePath: localCachePath,
      cloudStoragePath: cloudStoragePath,
      ensureOriginalAt: ensureOriginalAt,
    );
    return File(path).readAsBytes();
  }

  // ---------------------------------------------------------------------------
  // Maintenance
  // ---------------------------------------------------------------------------

  Future<void> evictPhotoByMeta(PhotoMeta meta) async {
    await meta.resolve();
    await evictPhoto(meta.photo.id.toString());
  }

  Future<void> evictPhoto(String photoId) async {
    if (!_initialised) {
      await init();
    }
    final keys = _entries.keys.where((k) => k.startsWith('$photoId|')).toList();
    for (final k in keys) {
      final e = _entries.remove(k);
      if (e == null) {
        continue;
      }
      final file = p.join(_cacheDir, e.fileName);
      if (exists(file)) {
        _totalBytes -= stat(file).size;
        delete(file);
      }
    }
    await _saveIndex();
  }

  Future<void> clear() async {
    if (!_initialised) {
      await init();
    }
    if (exists(_cacheDir)) {
      for (final fse in Directory(_cacheDir).listSync()) {
        if (fse is File && p.basename(fse.path) != '_index.json') {
          fse.deleteSync();
        }
      }
    }
    _entries.clear();
    _totalBytes = 0;
    await _saveIndex();
  }

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  Path _key(String id, ImageVariant v) => '$id|${v.name}';

  String _variantPath(int photoId, ImageVariant v) {
    final ext = switch (v) {
      ImageVariant.general => 'webp',
      ImageVariant.pdf => 'jpg',
      ImageVariant.thumb => 'jpg',
      ImageVariant.raw => 'orig',
    };
    return p.join(_cacheDir, '${_safe(photoId.toString())}__${v.name}.$ext');
  }

  String _safe(String s) => s.replaceAll(RegExp('[^A-Za-z0-9._-]'), '_');

  /// Get the path image associated with [key] if it exists
  /// in the cache.
  Future<Path?> _cachedIfExists(Key key) async {
    final e = _entries[key];
    if (e == null) {
      return null;
    }
    // the file exists and is in the cache
    final path = p.join(_cacheDir, e.fileName);
    if (exists(path)) {
      return path;
    }
    // the key is in the cache but the
    //file doesn't exist so delete it.
    _entries.remove(key);
    await _saveIndex();
    return null;
  }

  Future<void> _backgroundCompress({
    required Path src,
    required Path dst,
    required Key key,
    required ImageVariant variant,
  }) async {
    if (exists(dst)) {
      return;
    }
    final res = await compute(
      ImageCompressJob.run,
      ImageCompressJob(srcPath: src, dstPath: dst, variant: variant),
      debugLabel: 'Compress Image:$variant',
    );
    if (res.success && exists(dst)) {
      await _upsertEntry(key, p.basename(dst));
      await _trimIfNeeded();
    }
  }

  Future<void> _compressSync({
    required Path src,
    required Path dst,
    required Key key,
    required ImageVariant variant,
  }) async {
    if (exists(dst)) {
      await _upsertEntry(key, p.basename(dst));
      return;
    }
    final res = await ImageCompressJob.run(
      ImageCompressJob(srcPath: src, dstPath: dst, variant: variant),
    );
    if (res.success && exists(dst)) {
      await _upsertEntry(key, p.basename(dst));
      await _trimIfNeeded();
    }
  }

  Future<void> _upsertEntry(Key key, String fileName) async {
    final path = p.join(_cacheDir, fileName);
    final size = stat(path).size;
    final now = DateTime.now();
    final entry = _Entry(
      key: key,
      fileName: fileName,
      size: size,
      lastAccess: now,
    );
    final prev = _entries[key];
    if (prev != null) {
      _totalBytes -= prev.size;
    }
    _entries[key] = entry;
    _totalBytes += size;
    await _touch(key);
  }

  Future<void> _touch(Key key) async {
    final e = _entries[key];
    if (e == null) {
      return;
    }
    e.lastAccess = DateTime.now();
    await _saveIndex();
  }

  Future<void> _trimIfNeeded() async {
    if (_totalBytes <= _config.maxBytes) {
      return;
    }
    final list = _entries.values.toList()
      ..sort((a, b) => a.lastAccess.compareTo(b.lastAccess));
    for (final e in list) {
      if (_totalBytes <= _config.maxBytes) {
        break;
      }
      final path = p.join(_cacheDir, e.fileName);
      if (exists(path)) {
        final len = stat(path).size;
        delete(path);
        _totalBytes -= len;
      }
      _entries.remove(e.key);
    }
    await _saveIndex();
  }

  Future<void> _loadIndex() async {
    if (!exists(_indexPath)) {
      _entries.clear();
      _totalBytes = 0;
      return;
    }
    try {
      final text = await File(_indexPath).readAsString();
      final raw = json.decode(text) as Map<String, dynamic>;
      final items = raw['items'] as List<dynamic>? ?? <dynamic>[];
      _entries.clear();
      _totalBytes = 0;
      for (final it in items) {
        final e = _Entry.fromJson(it as Map<String, dynamic>);
        _entries[e.key] = e;
        _totalBytes += e.size;
      }
    } catch (_) {
      _entries.clear();
      _totalBytes = 0;
    }
  }

  Future<void> _saveIndex() async {
    final items = _entries.values.map((e) => e.toJson()).toList();
    final text = const JsonEncoder.withIndent(
      '  ',
    ).convert({'items': items, 'total': _totalBytes, 'ver': 1});
    await File(_indexPath).writeAsString(text, flush: true);
  }

  Future<void> _reconcileDisk() async {
    final files = Directory(_cacheDir)
        .listSync()
        .whereType<File>()
        .where((f) => !f.path.endsWith('_index.json'))
        .toList();

    final seen = <String, File>{};
    for (final f in files) {
      seen[p.basename(f.path)] = f;
    }

    _totalBytes = 0;
    final toDrop = <String>[];

    for (final e in _entries.values) {
      final f = seen[e.fileName];
      if (f == null) {
        toDrop.add(e.key);
      } else {
        e.size = f.lengthSync();
        _totalBytes += e.size;
        seen.remove(e.fileName);
      }
    }
    for (final k in toDrop) {
      _entries.remove(k);
    }

    final now = DateTime.now();
    for (final stray in seen.values) {
      final name = p.basename(stray.path);
      final base = p.basenameWithoutExtension(name);
      final parts = base.split('__');
      if (parts.length == 2) {
        final id = parts[0];
        final variant = parts[1];
        final key = '$id|$variant';
        final len = stray.lengthSync();
        _entries[key] = _Entry(
          key: key,
          fileName: name,
          size: len,
          lastAccess: now,
        );
        _totalBytes += len;
      } else {
        stray.deleteSync();
      }
    }
    await _saveIndex();
    await _trimIfNeeded();
  }

  /// Seeds/overrides the LRU lastAccess for a cached [variant] of [meta].
  /// No-op if the variant isn’t cached yet.
  Future<void> setLastAccessForMeta({
    required PhotoMeta meta,
    required ImageVariant variant,
    required DateTime when,
  }) async {
    if (!_initialised) {
      await init();
    }
    final photoId = meta.photo.id.toString();
    final key = _key(photoId, variant);
    final e = _entries[key];
    if (e == null) {
      return; // not cached yet; caller may re-run later
    }
    e.lastAccess = when;
    await _saveIndex();
  }

  // /// Convenience overload to match callsites shown in the migration.
  // Future<void> setLastAccessForMeta(
  //   PhotoMeta meta, {
  //   required ImageVariant variant,
  //   required DateTime when,
  // }) => setLastAccessForMeta(meta: meta, variant: variant, when: when);
}

class _Entry {
  final Key key;

  final String fileName;

  int size;

  DateTime lastAccess;

  _Entry({
    required this.key,
    required this.fileName,
    required this.size,
    required this.lastAccess,
  });

  factory _Entry.fromJson(Map<String, dynamic> j) => _Entry(
    key: j['key'] as String,
    fileName: j['filename'] as String,
    size: j['size'] as int,
    lastAccess: DateTime.parse(j['accessed'] as String),
  );

  Map<String, dynamic> toJson() => {
    'key': key,
    'filename': fileName,
    'size': size,
    'accessed': lastAccess.toIso8601String(),
  };
}

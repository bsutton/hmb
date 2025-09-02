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

import '../util/dart/compute_manager.dart';
import '../util/dart/future_ex.dart';
import '../util/dart/paths.dart';
import '../util/dart/photo_meta.dart';
import 'image_cache_config.dart';

typedef Key = String;

typedef Compressor = Future<CompressResult> Function(CompressJob job);

class Variant {
  final PhotoMeta meta;
  final ImageVariant variant;
  final Key key;

  Variant(this.meta, this.variant) : key = '${meta.photo.id}|${variant.name}';

  Path get cacheStoragePath {
    final ext = switch (variant) {
      ImageVariant.general => 'webp',
      ImageVariant.pdf => 'jpg',
      ImageVariant.thumb => 'jpg',
      ImageVariant.raw => 'orig',
    };
    return p.join(
      HMBImageCache._instance!._cacheDir,
      '${_safe(meta.photo.id.toString())}__${variant.name}.$ext',
    );
  }

  Future<Path> get cloudStoragePath => meta.cloudStoragePath;

  String _safe(String s) => s.replaceAll(RegExp('[^A-Za-z0-9._-]'), '_');

  @override
  String toString() => '${meta.photo.id}|${variant.name}';
}

typedef Downloader = Future<void> Function(Variant variant);

class CompressResult {
  final bool success;

  final String? error;

  CompressResult(this.error, {required this.success});
}

class CompressJob {
  final String srcPath;

  final Variant variant;

  CompressJob({required this.srcPath, required this.variant});
}

/// LRU cache of *image variants* keyed by (photoId, variant).
/// Filenames: `<photoId>__<variant>.<ext>`
class HMBImageCache {
  static const _cacheDirName = 'photo_image_cache';

  // singleton
  static HMBImageCache? _instance;

  late final Downloader downloader;
  late final Compressor compressor;
  late final ImageCacheConfig _config;
  late String _cacheDir;
  late String _indexPath;

  // composite key: "$photoId|$variant" -> entry
  final _entries = <Key, _Entry>{};
  var _totalBytes = 0;
  var _initialised = false;

  factory HMBImageCache() {
    _instance ??= HMBImageCache._();
    return _instance!;
  }

  HMBImageCache._();

  Future<void> init(Downloader downloader, Compressor compressor) async {
    if (_initialised) {
      return;
    }

    this.downloader = downloader;

    _config = ImageCacheConfig(downloader: downloader, compressor: compressor);
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

  /// moves a image stored at [PhotoMeta] into
  /// cache and triggers a background compression
  /// and upload to cloud.
  Future<void> store(PhotoMeta meta) async {
    final rawVariant = Variant(meta, ImageVariant.raw);
    final generalVariant = Variant(meta, ImageVariant.general);
    final thumbnailVariant = Variant(meta, ImageVariant.thumb);

    // copy the raw image into cache and let
    // it expire naturally
    copy(meta.absolutePathTo, rawVariant.cacheStoragePath);
    await _upsertEntry(rawVariant);

    await setLastAccess(
      variant: rawVariant,
      when: stat(meta.absolutePathTo).accessed,
    );

    // we need to actively upload images that havent' been synced.

    // We need to find out why the index file is corrupt 
    //  - are we better add this to the photo db.

    // We need to find out why we ended up with an empth cache

    /// compress the raw varient into a general
    /// and then the general into a thumbnail
    /// then evict the raw variant.
    unawaited(
      FutureEx.chain([
        // compress raw image to create a general image
        () => _compressAsync(
          src: rawVariant.cacheStoragePath,
          variant: generalVariant,
        ),
        // compress genral image to create a thumbnail image
        () => _compressAsync(
          src: generalVariant.cacheStoragePath,
          variant: thumbnailVariant,
        ),
        // evict the raw image
        () => evictVariant(rawVariant),
        // sync the last access time to the original image
        () => setLastAccess(
          variant: generalVariant,
          when: stat(meta.absolutePathTo).accessed,
        ),
        // sync the last access time to the original image
        () => setLastAccess(
          variant: thumbnailVariant,
          when: stat(meta.absolutePathTo).accessed,
        ),
      ]),
    );
  }
  // ---------------------------------------------------------------------------
  // PhotoMeta-first API (primary)
  // ---------------------------------------------------------------------------

  /// Returns a local path for [ImageVariant] of [meta].
  ///
  /// - general: returns original immediately, compresses to WebP in background.
  /// - pdf/thumb: generates synchronously on first call, then cached.
  /// - raw: returns original; if [cacheRaw] true, also stores a copy in cache.
  ///
  Future<Path> getVariantPathForMeta({
    required PhotoMeta meta,
    required ImageVariant imageVariant,
    Future<void> Function(Variant variant)? fetch,

    bool cacheRaw = false,
  }) async {
    await meta.resolve();

    return getVariantPath(
      variant: Variant(meta, imageVariant),
      fetch: (variant) => fetch?.call(variant) ?? _config.downloader(variant),
    );
  }

  /// Convenience for bytes (useful for PDF generation).
  Future<Uint8List> getVariantBytesForMeta({
    required PhotoMeta meta,
    required ImageVariant variant,
    Future<void> Function(Variant variant)? fetch,
  }) async {
    final path = await getVariantPathForMeta(
      meta: meta,
      imageVariant: variant,
      fetch: fetch,
    );
    return File(path).readAsBytes();
  }

  // ---------------------------------------------------------------------------
  // Existing ID/path-based API (kept for internal reuse)
  // ---------------------------------------------------------------------------

  Future<String> getVariantPath({
    required Variant variant,
    Future<void> Function(Variant variant)? fetch,
  }) async {
    final key = variant.key;
    final existing = await _cachedIfExists(key);
    if (existing != null) {
      await _touch(key);
      return existing;
    }

    /// image doesn't exists locally, so lets download it.

    final downloadVariant = Variant(variant.meta, ImageVariant.raw);
    final parent = p.dirname(downloadVariant.cacheStoragePath);
    if (!exists(parent)) {
      createDir(p.dirname(downloadVariant.cacheStoragePath), recursive: true);
    }
    await (fetch?.call(variant) ?? _config.downloader(variant));

    await _upsertEntry(downloadVariant);
    await _trimIfNeeded();

    if (downloadVariant.variant == variant.variant) {
      return downloadVariant.cacheStoragePath;
    }

    // non-blocking background compress
    unawaited(
      _compressAsync(src: downloadVariant.cacheStoragePath, variant: variant),
    );

    /// we don't wait for the compression just return the raw image.
    return downloadVariant.cacheStoragePath;
  }

  Future<List<int>> getVariantBytes({
    required Variant variant,
    required Future<void> Function(Variant variant) fetch,
  }) async {
    final path = await getVariantPath(variant: variant, fetch: fetch);
    return File(path).readAsBytes();
  }

  // ---------------------------------------------------------------------------
  // Maintenance
  // ---------------------------------------------------------------------------

  Future<void> evictPhotoByMeta(PhotoMeta meta) async {
    await meta.resolve();
    await evictPhoto(meta.photo.id.toString());
  }

  Future<void> evictVariant(Variant variant) async {
    final e = _entries.remove(variant.key);
    if (e != null) {
      final file = p.join(_cacheDir, e.fileName);
      if (exists(file)) {
        _totalBytes -= stat(file).size;
        delete(file);
        await _saveIndex();
      }
    }
  }

  Future<void> evictPhoto(String photoId) async {
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

  /// Uses an isolate to compress the file.
  Future<void> _compressAsync({
    required Path src,
    required Variant variant,
  }) async {
    if (exists(variant.cacheStoragePath)) {
      return;
    }
    final res = await compute(
      _config.compressor,
      CompressJob(srcPath: src, variant: variant),
      debugLabel: 'Compress Image:$variant',
    );
    if (res.success && exists(variant.cacheStoragePath)) {
      await _upsertEntry(variant);
      await _trimIfNeeded();
    }
  }

  Future<void> _compressSync({
    required Path src,
    required Variant variant,
  }) async {
    if (exists(variant.cacheStoragePath)) {
      await _upsertEntry(variant);
      return;
    }
    final res = await _config.compressor(
      CompressJob(srcPath: src, variant: variant),
    );
    if (res.success && exists(variant.cacheStoragePath)) {
      await _upsertEntry(variant);
      await _trimIfNeeded();
    }
  }

  Future<void> _upsertEntry(Variant variant) async {
    final path = variant.cacheStoragePath;
    final size = stat(path).size;
    final now = DateTime.now();
    final entry = _Entry(
      key: variant.key,
      fileName: variant.cacheStoragePath,
      size: size,
      lastAccess: now,
    );
    final prev = _entries[variant.key];
    if (prev != null) {
      _totalBytes -= prev.size;
    }
    _entries[variant.key] = entry;
    _totalBytes += size;
    await _touch(variant.key);
  }

  Future<void> _touch(Key key) async {
    final e = _entries[key];
    if (e == null) {
      return;
    }
    e.lastAccess = DateTime.now();
    await _saveIndex();
  }

  /// TODO:(bsutton) remove raw images from cache first

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

  /// Seeds/overrides the LRU lastAccess for a cached [variant].
  /// No-op if the variant isn’t cached yet.
  Future<void> setLastAccess({
    required Variant variant,
    required DateTime when,
  }) async {
    final e = _entries[variant.key];
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

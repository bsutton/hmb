/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton.
 All Rights Reserved.

 GPL terms per repo license.
*/

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dcli_core/dcli_core.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common/sqlite_api.dart' show Database;

import '../dao/dao_image_cache_variant.dart';
import '../database/management/database_helper.dart';
import '../entity/image_cache_variant.dart';
import '../util/dart/compute_manager.dart';
import '../util/dart/future_ex.dart';
import '../util/dart/paths.dart';
import '../util/dart/photo_meta.dart';
import 'image_cache_config.dart';

typedef Key = String;

typedef Compressor = Future<CompressResult> Function(CompressJob job);

/// Identifies a cached image format variant for a specific photo.
/// We keep mulitple variants per photo for different use cases.
class ImageVariant {
  final PhotoMeta meta;
  final ImageVariantType variant;
  final Key key;

  ImageVariant(this.meta, this.variant)
    : key = '${meta.photo.id}|${variant.name}';

  /// Cache-relative file name for this variant.
  String get cacheFileName {
    final ext = switch (variant) {
      ImageVariantType.general => 'webp',
      ImageVariantType.pdf => 'jpg',
      ImageVariantType.thumb => 'jpg',
      ImageVariantType.raw => 'orig',
    };
    return '${_safe(meta.photo.id.toString())}__${variant.name}.$ext';
  }

  Future<Path> get cloudStoragePath => meta.cloudStoragePath;

  String _safe(String s) => s.replaceAll(RegExp('[^A-Za-z0-9._-]'), '_');

  @override
  String toString() => '${meta.photo.id}|${variant.name}';
}

typedef Downloader =
    Future<void> Function(ImageVariant variant, String targetPath);

class CompressResult {
  final bool success;

  final String? error;

  CompressResult(this.error, {required this.success});
}

class CompressJob {
  final String srcPath;
  final String targetPath;

  final ImageVariant variant;

  CompressJob({
    required this.srcPath,
    required this.targetPath,
    required this.variant,
  });
}

/// LRU cache of *image variants* keyed by (photoId, variant).
/// Filenames: `<photoId>__<variant>.<ext>`
class HMBImageCache {
  static const _cacheDirName = 'photo_image_cache';
  static const _trimBatchSize = 100;

  // singleton
  static HMBImageCache? _instance;

  late final Downloader downloader;
  late final Compressor compressor;
  late ImageCacheConfig _config;
  late String _cacheDir;
  late DaoImageCacheVariant _daoImageCacheVariant;

  var _initialised = false;

  factory HMBImageCache() {
    _instance ??= HMBImageCache._();
    return _instance!;
  }

  HMBImageCache._();

  /// One-time migration used by DB upgrade actions.
  /// Rebuilds the image cache table from files already on disk.
  static Future<void> migrateDiskCacheToDatabase(Database db) async {
    final base = await getTemporaryDirectory();
    final cacheDir = p.join(base, _cacheDirName);
    if (!exists(cacheDir)) {
      return;
    }

    final legacyBin = p.join(cacheDir, '_index.bin');
    final legacyJson = p.join(cacheDir, '_index.json');
    if (exists(legacyBin)) {
      delete(legacyBin);
    }
    if (exists(legacyJson)) {
      delete(legacyJson);
    }

    final result = await compute<_CacheScanRequest, _CacheScanResult>(
      _scanCacheDir,
      _CacheScanRequest(
        cacheDir: cacheDir,
        variants: ImageVariantType.values.map((e) => e.name).toList(),
      ),
      debugLabel: 'CacheMigrationScan',
    );

    for (final stray in result.strayFiles) {
      if (exists(stray)) {
        delete(stray);
      }
    }

    await db.transaction((txn) async {
      await txn.delete(DaoImageCacheVariant.tableName);
      final batch = txn.batch();
      for (final entry in result.entries) {
        batch.insert(DaoImageCacheVariant.tableName, entry.toMap());
      }
      await batch.commit(noResult: true);
    });
  }

  Future<void> init(
    Downloader downloader,
    Compressor compressor, {
    int? maxBytes,
  }) async {
    if (_initialised) {
      return;
    }

    this.downloader = downloader;

    _config = ImageCacheConfig(
      downloader: downloader,
      compressor: compressor,
      maxBytes: maxBytes ?? ImageCacheConfig.defaultMaxBytes,
    );
    if (!DatabaseHelper.instance.isOpen()) {
      throw StateError(
        'Database must be open before initializing HMBImageCache.',
      );
    }
    final base = await getTemporaryDirectory();
    _cacheDir = p.join(base, _cacheDirName);
    if (!exists(_cacheDir)) {
      createDir(_cacheDir, recursive: true);
    }
    if (p.basename(_cacheDir) == _cacheDirName) {
      final legacyBin = p.join(_cacheDir, '_index.bin');
      final legacyJson = p.join(_cacheDir, '_index.json');
      if (exists(legacyBin)) {
        delete(legacyBin);
      }
      if (exists(legacyJson)) {
        delete(legacyJson);
      }
    }
    _daoImageCacheVariant = DaoImageCacheVariant();
    unawaited(_trimIfNeeded());
    _initialised = true;
  }

  Future<void> updateMaxBytes(int maxBytes) async {
    if (!_initialised) {
      return;
    }
    _config = ImageCacheConfig(
      downloader: downloader,
      compressor: compressor,
      maxBytes: maxBytes,
    );
    await _trimIfNeeded();
  }

  /// Returns the absolute cache path for a given [variant].
  Path pathForVariant(ImageVariant variant) =>
      p.join(_cacheDir, variant.cacheFileName);

  /// moves a image stored at [PhotoMeta] into
  /// cache and triggers a background compression
  /// and upload to cloud.
  Future<void> store(PhotoMeta meta) async {
    final rawVariant = ImageVariant(meta, ImageVariantType.raw);
    final generalVariant = ImageVariant(meta, ImageVariantType.general);
    final thumbnailVariant = ImageVariant(meta, ImageVariantType.thumb);

    // copy the raw image into cache and let
    // it expire naturally
    copy(meta.absolutePathTo, pathForVariant(rawVariant));
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
          src: pathForVariant(rawVariant),
          variant: generalVariant,
        ),
        // compress genral image to create a thumbnail image
        () => _compressAsync(
          src: pathForVariant(generalVariant),
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

  /// Returns a local path for [ImageVariantType] of [meta].
  ///
  /// - general: returns original immediately, compresses to WebP in background.
  /// - pdf/thumb: generates synchronously on first call, then cached.
  /// - raw: returns original; if [cacheRaw] true, also stores a copy in cache.
  ///
  Future<Path> getVariantPathForMeta({
    required PhotoMeta meta,
    required ImageVariantType imageVariant,
    Future<void> Function(ImageVariant variant, String targetPath)? fetch,

    bool cacheRaw = false,
  }) async {
    await meta.resolve();

    return getVariantPath(
      variant: ImageVariant(meta, imageVariant),
      fetch: (variant, targetPath) =>
          fetch?.call(variant, targetPath) ??
          _config.downloader(variant, targetPath),
    );
  }

  /// Convenience for bytes (useful for PDF generation).
  Future<Uint8List> getVariantBytesForMeta({
    required PhotoMeta meta,
    required ImageVariantType variant,
    Future<void> Function(ImageVariant variant, String targetPath)? fetch,
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
    required ImageVariant variant,
    Future<void> Function(ImageVariant variant, String targetPath)? fetch,
  }) async {
    final key = variant.key;
    final existing = await _cachedIfExists(key);
    if (existing != null) {
      await _touch(key);
      return existing;
    }

    /// image doesn't exists locally, so lets download it.

    final downloadVariant = ImageVariant(variant.meta, ImageVariantType.raw);
    final parent = p.dirname(pathForVariant(downloadVariant));
    if (!exists(parent)) {
      createDir(parent, recursive: true);
    }
    await (fetch?.call(downloadVariant, pathForVariant(downloadVariant)) ??
        _config.downloader(downloadVariant, pathForVariant(downloadVariant)));

    await _upsertEntry(downloadVariant);
    await _trimIfNeeded();

    if (downloadVariant.variant == variant.variant) {
      return pathForVariant(downloadVariant);
    }

    // non-blocking background compress
    unawaited(
      _compressAsync(src: pathForVariant(downloadVariant), variant: variant),
    );

    /// we don't wait for the compression just return the raw image.
    return pathForVariant(downloadVariant);
  }

  Future<List<int>> getVariantBytes({
    required ImageVariant variant,
    required Future<void> Function(ImageVariant variant, String targetPath)
    fetch,
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

  Future<void> evictVariant(ImageVariant variant) async {
    final parts = _splitKey(variant.key);
    if (parts == null) {
      return;
    }
    final path = pathForVariant(variant);
    if (exists(path)) {
      delete(path);
    }
    await _daoImageCacheVariant.removeKey(parts.photoId, parts.variant);
  }

  Future<void> evictPhoto(String photoId) async {
    final id = int.tryParse(photoId);
    if (id == null) {
      return;
    }
    final rows = await _daoImageCacheVariant.getByPhotoId(id);
    for (final row in rows) {
      final path = p.join(_cacheDir, row.fileName);
      if (exists(path)) {
        delete(path);
      }
    }
    await DatabaseHelper.instance.database.delete(
      DaoImageCacheVariant.tableName,
      where: 'photo_id = ?',
      whereArgs: [id],
    );
  }

  Future<void> clear() async {
    if (exists(_cacheDir)) {
      for (final fse in Directory(_cacheDir).listSync()) {
        if (fse is File) {
          fse.deleteSync();
        }
      }
    }
    await DatabaseHelper.instance.database.delete(
      DaoImageCacheVariant.tableName,
    );
  }

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  /// Get the path image associated with [key] if it exists
  /// in the cache.
  Future<Path?> _cachedIfExists(Key key) async {
    final parts = _splitKey(key);
    if (parts == null) {
      return null;
    }
    final row = await _daoImageCacheVariant.getByKey(
      parts.photoId,
      parts.variant,
    );
    if (row != null) {
      final path = p.join(_cacheDir, row.fileName);
      if (exists(path)) {
        return path;
      }
      await _daoImageCacheVariant.removeKey(parts.photoId, parts.variant);
    }

    final fileName = _cacheFileName(parts.photoId, parts.variant);
    if (fileName == null) {
      return null;
    }
    final fallback = p.join(_cacheDir, fileName);
    if (!exists(fallback)) {
      return null;
    }
    final statInfo = stat(fallback);
    await _daoImageCacheVariant.upsert(
      ImageCacheVariant.forInsert(
        photoId: parts.photoId,
        variant: parts.variant,
        fileName: fileName,
        size: statInfo.size,
        lastAccess: statInfo.modified,
      ),
    );
    return fallback;
  }

  /// Uses an isolate to compress the file.
  Future<void> _compressAsync({
    required Path src,
    required ImageVariant variant,
  }) async {
    final targetPath = pathForVariant(variant);
    if (exists(targetPath)) {
      return;
    }
    final res = await compute(
      _config.compressor,
      CompressJob(srcPath: src, targetPath: targetPath, variant: variant),
      debugLabel: 'Compress Image:$variant',
    );
    if (res.success && exists(targetPath)) {
      await _upsertEntry(variant);
      await _trimIfNeeded();
    }
  }

  Future<void> _upsertEntry(ImageVariant variant) async {
    final parts = _splitKey(variant.key);
    if (parts == null) {
      return;
    }
    final path = pathForVariant(variant);
    if (!exists(path)) {
      return;
    }
    final size = stat(path).size;
    final now = DateTime.now().millisecondsSinceEpoch;
    await _daoImageCacheVariant.upsert(
      ImageCacheVariant.forInsert(
        photoId: parts.photoId,
        variant: parts.variant,
        fileName: p.basename(path),
        size: size,
        lastAccess: DateTime.fromMillisecondsSinceEpoch(now),
      ),
    );
  }

  Future<void> _touch(Key key) async {
    final parts = _splitKey(key);
    if (parts == null) {
      return;
    }
    await _daoImageCacheVariant.touch(
      parts.photoId,
      parts.variant,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  // TODO(bsutton): remove raw images from cache first

  Future<void> _trimIfNeeded() async {
    var total = await _daoImageCacheVariant.totalBytes();
    while (total > _config.maxBytes) {
      final batch = await _daoImageCacheVariant.oldestBackedUpBatch(
        _trimBatchSize,
      );
      if (batch.isEmpty) {
        // Remaining cache entries are for photos that have not been backed up.
        // Keep them to avoid data loss; UI reminders surface the overflow.
        return;
      }
      for (final oldest in batch) {
        if (total <= _config.maxBytes) {
          break;
        }
        final path = p.join(_cacheDir, oldest.fileName);
        if (exists(path)) {
          delete(path);
        }
        await _daoImageCacheVariant.removeKey(oldest.photoId, oldest.variant);
        total -= oldest.size;
      }
      if (total < 0) {
        total = await _daoImageCacheVariant.totalBytes();
      }
    }
  }

  _KeyParts? _splitKey(String key) {
    final parts = key.split('|');
    if (parts.length != 2) {
      return null;
    }
    final id = int.tryParse(parts[0]);
    if (id == null) {
      return null;
    }
    return _KeyParts(id, parts[1]);
  }

  /// Seeds/overrides the LRU lastAccess for a cached [variant].
  /// No-op if the variant isn’t cached yet.
  Future<void> setLastAccess({
    required ImageVariant variant,
    required DateTime when,
  }) async {
    final parts = _splitKey(variant.key);
    if (parts == null) {
      return;
    }
    await _daoImageCacheVariant.touch(
      parts.photoId,
      parts.variant,
      when.millisecondsSinceEpoch,
    );
  }

  // /// Convenience overload to match callsites shown in the migration.
  // Future<void> setLastAccessForMeta(
  //   PhotoMeta meta, {
  //   required ImageVariant variant,
  //   required DateTime when,
  // }) => setLastAccessForMeta(meta: meta, variant: variant, when: when);
}

class _KeyParts {
  final int photoId;
  final String variant;

  _KeyParts(this.photoId, this.variant);
}

class _CacheScanRequest {
  final String cacheDir;
  final List<String> variants;

  const _CacheScanRequest({required this.cacheDir, required this.variants});
}

class _CacheScanEntry {
  final int photoId;
  final String variant;
  final String fileName;
  final int size;
  final int lastAccess;

  const _CacheScanEntry({
    required this.photoId,
    required this.variant,
    required this.fileName,
    required this.size,
    required this.lastAccess,
  });

  Map<String, dynamic> toMap() => {
    'photo_id': photoId,
    'variant': variant,
    'file_name': fileName,
    'size': size,
    'last_access': lastAccess,
    'created_date': lastAccess,
    'modified_date': lastAccess,
  };
}

class _CacheScanResult {
  final List<_CacheScanEntry> entries;
  final List<String> strayFiles;

  const _CacheScanResult({required this.entries, required this.strayFiles});
}

_CacheScanResult _scanCacheDir(_CacheScanRequest request) {
  final entries = <_CacheScanEntry>[];
  final stray = <String>[];

  final dir = Directory(request.cacheDir);
  if (!dir.existsSync()) {
    return _CacheScanResult(entries: entries, strayFiles: stray);
  }

  final variantSet = request.variants.toSet();
  final files = dir.listSync().whereType<File>();
  for (final file in files) {
    final name = p.basename(file.path);
    if (name == '_index.bin' || name == '_index.json') {
      continue;
    }
    final base = p.basenameWithoutExtension(name);
    final parts = base.split('__');
    if (parts.length != 2) {
      stray.add(file.path);
      continue;
    }
    final id = int.tryParse(parts[0]);
    final variant = parts[1];
    if (id == null || !variantSet.contains(variant)) {
      stray.add(file.path);
      continue;
    }
    final statInfo = file.statSync();
    entries.add(
      _CacheScanEntry(
        photoId: id,
        variant: variant,
        fileName: name,
        size: statInfo.size,
        lastAccess: statInfo.modified.millisecondsSinceEpoch,
      ),
    );
  }

  return _CacheScanResult(entries: entries, strayFiles: stray);
}

String? _cacheFileName(int photoId, String variant) {
  final ext = switch (variant) {
    'general' => 'webp',
    'pdf' => 'jpg',
    'thumb' => 'jpg',
    'raw' => 'orig',
    _ => null,
  };
  if (ext == null) {
    return null;
  }
  final safeId = photoId.toString().replaceAll(RegExp('[^A-Za-z0-9._-]'), '_');
  return '${safeId}__$variant.$ext';
}

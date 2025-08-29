/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton.
 All Rights Reserved.

 Note: This software is licensed under the GNU General Public License,
       with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products for
     third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dcli_core/dcli_core.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../util/paths.dart';
import 'photo_cache_config.dart';
import 'webp_compress.dart';

/// Size-bounded, LRU cache for compressed (WebP) display images.
///
/// Key is your stable photo id (e.g. DB id, UUID).
/// Files are stored as `<key>.webp`.
class PhotoCache {
  final PhotoCacheConfig _config;

  final String _cacheDirName;

  late Path _pathToCacheDir;

  late Path _pathToIndexFile;

  // In-memory LRU map: key -> entry
  final _entries = <Path, _Entry>{};

  var _totalBytes = 0;

  var _initialised = false;

  PhotoCache({required PhotoCacheConfig config, String? cacheDirName})
    : _config = config,
      _cacheDirName = cacheDirName ?? 'photo_webp_cache';

  /// Call during app startup.
  Future<void> init() async {
    if (_initialised) {
      return;
    }

    final base = await getTemporaryDirectory();
    _pathToCacheDir = p.join(base.path, _cacheDirName);
    if (!exists(_pathToCacheDir)) {
      createDir(_pathToCacheDir, recursive: true);
    }
    _pathToIndexFile = p.join(_pathToCacheDir, '_index.json');

    await _loadIndex();
    await _reconcileDisk();
    _initialised = true;
  }

  /// Returns a path to the *display* image File.
  ///
  /// If cache hit: returns WebP immediately.
  /// If miss:
  ///  - If [pathToLocalOriginal] exists, returns it immediately, and starts
  ///    a background compression to populate cache.
  ///  - Else it calls [downloadOriginal], writes it to [pathToLocalOriginal],
  ///    returns it immediately, and compresses in background.
  ///
  /// You should upload the original *separately* via your existing flow.
  Future<Path> getDisplayFile({
    required String key,
    required Path pathToLocalOriginal,
    required Future<Uint8List> Function(Path downloadPath) downloadOriginal,
    bool forensic = false,
  }) async {
    if (!_initialised) {
      await init();
    }

    // 1) Cache hit?
    final cached = await _cachedFileIfExists(key);
    if (cached != null) {
      await _touch(key);
      return cached;
    }

    // 2) Ensure original exists locally (download if needed).
    if (!exists(pathToLocalOriginal)) {
      createDir(p.dirname(pathToLocalOriginal), recursive: true);
      await downloadOriginal(pathToLocalOriginal);
      // await File(pathToLocalOriginal).writeAsBytes(bytes, flush: true);
    }

    // 3) Start background compression (non-blocking).
    unawaited(
      _ensureCompressedInBackground(
        key: key,
        pathToOriginalPhoto: pathToLocalOriginal,
        forensic: forensic,
      ),
    );

    // 4) Return original immediately so the UI can display it.
    return pathToLocalOriginal;
  }

  /// Evict a single key (e.g. if a photo is deleted).
  Future<void> evict(String key) async {
    if (!_initialised) {
      await init();
    }
    final entry = _entries.remove(key);
    if (entry != null) {
      final file = p.join(_pathToCacheDir, entry.fileName);
      if (exists(file)) {
        _totalBytes -= stat(file).size;
        delete(file);
      }
      await _saveIndex();
    }
  }

  /// Clear all cache files (keeps the folder).
  Future<void> clear() async {
    if (!_initialised) {
      await init();
    }
    for (final e in _entries.values) {
      final file = p.join(_pathToCacheDir, e.fileName);
      if (exists(file)) {
        delete(file);
      }
    }
    _entries.clear();
    _totalBytes = 0;
    await _saveIndex();
  }

  Future<String?> _cachedFileIfExists(String key) async {
    final entry = _entries[key];
    if (entry == null) {
      return null;
    }
    final file = p.join(_pathToCacheDir, entry.fileName);
    if (exists(file)) {
      return file;
    }
    // Index says it exists but file missing: remove entry.
    _entries.remove(key);
    await _saveIndex();
    return null;
  }

  Future<void> _ensureCompressedInBackground({
    required String key,
    required Path pathToOriginalPhoto,
    required bool forensic,
  }) async {
    final cfg = forensic ? _config.forensic() : _config;

    // Compute target path once.
    final name = '$key.webp';
    final target = p.join(_pathToCacheDir, name);

    // If another racing caller already created it, stop.
    if (exists(target)) {
      return;
    }

    // Use an isolate to avoid jank on big images.
    final result = await compute(
      WebPCompressJob.run,
      WebPCompressJob(
        srcPath: pathToOriginalPhoto,
        dstPath: target,
        longEdge: cfg.longEdge,
        quality: cfg.webpQuality,
        keepExif: cfg.preserveExif,
      ),
    );

    if (result.success) {
      final len = stat(target).size;

      // Upsert entry and touch.
      final now = DateTime.now();
      final entry = _Entry(
        key: key,
        fileName: name,
        length: len,
        lastAccess: now,
      );

      _entries[key] = entry;
      _totalBytes += len;
      await _saveIndex();
      await _trimIfNeeded();
    } else {
      // Keep silent; original was already shown.
      // You could log result.error for diagnostics.
    }
  }

  Future<void> _touch(String key) async {
    final e = _entries[key];
    if (e == null) {
      return;
    }
    e.lastAccess = DateTime.now();
    await _saveIndex(); // small file; fine to write frequently
  }

  Future<void> _trimIfNeeded() async {
    if (_totalBytes <= _config.maxBytes) {
      return;
    }
    // Sort by oldest access first (LRU).
    final list = _entries.values.toList()
      ..sort((a, b) => a.lastAccess.compareTo(b.lastAccess));

    for (final e in list) {
      if (_totalBytes <= _config.maxBytes) {
        break;
      }
      final file = p.join(_pathToCacheDir, e.fileName);
      if (exists(file)) {
        final len = stat(file).size;
        delete(file);
        _totalBytes -= len;
      }
      _entries.remove(e.key);
    }
    await _saveIndex();
  }

  Future<void> _loadIndex() async {
    if (!exists(_pathToIndexFile)) {
      _totalBytes = 0;
      _entries.clear();
      return;
    }
    try {
      final text = await File(_pathToIndexFile).readAsString();
      final raw = json.decode(text) as Map<String, dynamic>;
      final total = raw['total'] as int? ?? 0;
      final items = raw['items'] as List<dynamic>? ?? <dynamic>[];
      _entries.clear();
      _totalBytes = 0;
      for (final it in items) {
        final e = _Entry.fromJson(it as Map<String, dynamic>);
        _entries[e.key] = e;
        _totalBytes += e.length;
      }
      // If mismatch, reconcile will fix.
      if (_totalBytes != total) {
        await _reconcileDisk();
      }
    } catch (_) {
      _entries.clear();
      _totalBytes = 0;
    }
  }

  Future<void> _saveIndex() async {
    final items = <Map<String, dynamic>>[];
    for (final e in _entries.values) {
      items.add(e.toJson());
    }
    final jsonMap = <String, dynamic>{'total': _totalBytes, 'items': items};
    final text = const JsonEncoder.withIndent('  ').convert(jsonMap);
    await File(_pathToIndexFile).writeAsString(text, flush: true);
  }

  /// Re-scan the cache directory to rebuild totals and prune strays.
  Future<void> _reconcileDisk() async {
    final files = await Directory(_pathToCacheDir)
        .list()
        .where((fse) => fse is File && fse.path.endsWith('.webp'))
        .cast<File>()
        .toList();

    final existing = <String, File>{};
    for (final f in files) {
      existing[p.basename(f.path)] = f;
    }

    _totalBytes = 0;
    final toRemove = <String>[];

    for (final e in _entries.values) {
      final f = existing[e.fileName];
      if (f == null) {
        toRemove.add(e.key);
      } else {
        e.length = await f.length();
        _totalBytes += e.length;
        existing.remove(e.fileName);
      }
    }
    for (final k in toRemove) {
      _entries.remove(k);
    }

    // Any stray files not in index -> add with minimal metadata.
    final now = DateTime.now();
    for (final stray in existing.values) {
      final name = p.basename(stray.path);
      final key = name.replaceAll('.webp', '');
      final len = await stray.length();
      _entries[key] = _Entry(
        key: key,
        fileName: name,
        length: len,
        lastAccess: now,
      );
      _totalBytes += len;
    }

    await _saveIndex();
    await _trimIfNeeded();
  }
}

/// Represents a cached compressed image entry.
class _Entry {
  final String key;

  final String fileName;

  int length;

  DateTime lastAccess;

  _Entry({
    required this.key,
    required this.fileName,
    required this.length,
    required this.lastAccess,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
    'k': key,
    'f': fileName,
    'l': length,
    'a': lastAccess.toIso8601String(),
  };

  factory _Entry.fromJson(Map<String, dynamic> j) => _Entry(
    key: j['k'] as String,
    fileName: j['f'] as String,
    length: j['l'] as int,
    lastAccess: DateTime.parse(j['a'] as String),
  );
}

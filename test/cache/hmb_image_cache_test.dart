
/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton.
 All Rights Reserved.

 GPL terms per repo license.
*/

import 'dart:async';
import 'dart:convert';
import 'dart:io';

// --- Adjust these imports to your project structure -------------
import 'package:dcli_core/dcli_core.dart' as c;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart' as t;
import 'package:hmb/cache/hmb_image_cache.dart';
import 'package:hmb/cache/image_cache_config.dart'; // ImageVariant, CompressJob, CompressResult
import 'package:hmb/entity/photo.dart'; // Photo entity (id, filePath, etc.)
import 'package:hmb/util/dart/paths.dart'; // getTemporaryDirectory()
import 'package:hmb/util/dart/photo_meta.dart'; // PhotoMeta
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:test/test.dart';
// ---------------------------------------------------------------

void main() {
  late HMBImageCache cache;

  // Fake downloader: always writes the RAW variant for the requested meta.
  Future<void> fakeDownloader(Variant v) async {
    /// we are run in an isolate
    final cache = HMBImageCache();
    await cache.init(
      (_) async {},
      (_) async => CompressResult('OK', success: true),
    );
    final raw = Variant(v.meta, ImageVariant.raw);
    final parent = p.dirname(raw.cacheStoragePath);
    if (!c.exists(parent)) {
      c.createDir(parent, recursive: true);
    }
    await File(
      raw.cacheStoragePath,
    ).writeAsBytes(_bytes('RAW-${v.meta.photo.id}-${v.variant.name}'));
  }

  // Fake compressor: copies src to the target variant path with a small marker.
  Future<CompressResult> fakeCompressor(CompressJob job) async {
    final out = job.variant.cacheStoragePath;
    c.createDir(out, recursive: true);
    final srcBytes = await File(job.srcPath).readAsBytes();
    await File(out).writeAsBytes([
      ...srcBytes,
      ..._bytes('|COMP:${job.variant.variant.name}'),
    ]);
    return CompressResult(null, success: true);
  }

  setUpAll(() async {
    t.TestWidgetsFlutterBinding.ensureInitialized();

    await Directory.systemTemp.createTemp('hmb_cache_test_');

    // Point path_provider to our fake temp path.
    PathProviderPlatform.instance = _FakePathProvider();

    WidgetsFlutterBinding.ensureInitialized();
    cache = HMBImageCache();
    await cache.init(fakeDownloader, fakeCompressor);
  });

  tearDown(() async {
    // Keep the cache dir but clear entries & files for isolation
    await cache.clear();
  });

  group('HMBImageCache', () {
    test(
      'getVariantPath: cold miss downloads RAW and returns its path',
      () async {
        final original = await _makeOriginal(name: 'photo1.jpg');
        final meta = await _metaFrom(id: 101, absolutePath: original.path);
        final variant = Variant(meta, ImageVariant.general);

        final path = await cache.getVariantPath(
          variant: variant,
          fetch: fakeDownloader,
        );

        // Should be the RAW (since compression is background)
        final raw = Variant(meta, ImageVariant.raw);
        expect(p.normalize(path), equals(p.normalize(raw.cacheStoragePath)));
        expect(File(path).existsSync(), isTrue);

        // Index should have an entry for RAW
        final idx = await _readIndex();
        final items = (idx['items'] as List).cast<Map<String, dynamic>>();
        expect(items.any((e) => e['key'] == '${meta.photo.id}|raw'), isTrue);
      },
    );

    test(
      'Background compression eventually creates requested variant',
      () async {
        final original = await _makeOriginal(name: 'photo2.jpg');
        final meta = await _metaFrom(id: 202, absolutePath: original.path);
        final general = Variant(meta, ImageVariant.general);

        // Trigger download/compress chain
        await cache.getVariantPath(variant: general, fetch: fakeDownloader);

        // Eventually the general.webp should exist (written by _
        //fakeCompressor via compute)
        final ok = await _eventually(
          () => Future.value(File(general.cacheStoragePath).existsSync()),
        );
        expect(ok, isTrue, reason: 'general variant was not produced in time');
      },
    );

    test('getVariantBytes returns bytes for a variant', () async {
      final original = await _makeOriginal(
        name: 'photo3.jpg',
        contents: 'BYTES',
      );
      final meta = await _metaFrom(id: 303, absolutePath: original.path);
      final thumb = Variant(meta, ImageVariant.thumb);

      // Ensure raw exists and compression is triggered
      await cache.getVariantPath(variant: thumb, fetch: fakeDownloader);

      // Wait for thumb creation
      final ok = await _eventually(
        () => Future.value(File(thumb.cacheStoragePath).existsSync()),
      );
      expect(ok, isTrue);

      final bytes = await cache.getVariantBytes(
        variant: thumb,
        fetch: fakeDownloader, // not used now because file exists
      );
      expect(bytes, isNotEmpty);
    });

    test(
      'store(meta) copies RAW, compresses to general & thumb, then evicts RAW',
      () async {
        final original = await _makeOriginal(
          name: 'photo4.jpg',
          contents: 'STORE',
        );
        final meta = await _metaFrom(id: 404, absolutePath: original.path);

        await cache.store(meta);

        final raw = Variant(meta, ImageVariant.raw);
        final general = Variant(meta, ImageVariant.general);
        final thumb = Variant(meta, ImageVariant.thumb);

        final produced = await _eventually(() {
          final gen = File(general.cacheStoragePath).existsSync();
          final thm = File(thumb.cacheStoragePath).existsSync();
          final rawGone = !File(raw.cacheStoragePath).existsSync();
          return gen && thm && rawGone;
        }, timeout: const Duration(seconds: 3));
        expect(
          produced,
          isTrue,
          reason: 'general+thumb not present or RAW not evicted',
        );
      },
    );

    test('evictVariant removes only that variant', () async {
      final original = await _makeOriginal(name: 'photo5.jpg');
      final meta = await _metaFrom(id: 505, absolutePath: original.path);
      final general = Variant(meta, ImageVariant.general);
      final thumb = Variant(meta, ImageVariant.thumb);

      await cache.getVariantPath(variant: general, fetch: fakeDownloader);
      await _eventually(
        () => Future.value(File(general.cacheStoragePath).existsSync()),
      );

      await cache.getVariantPath(variant: thumb, fetch: fakeDownloader);
      await _eventually(
        () => Future.value(File(thumb.cacheStoragePath).existsSync()),
      );

      await cache.evictVariant(general);

      expect(File(general.cacheStoragePath).existsSync(), isFalse);
      expect(File(thumb.cacheStoragePath).existsSync(), isTrue);
    });

    test('evictPhoto removes all variants for the photo id', () async {
      final original = await _makeOriginal(name: 'photo6.jpg');
      final meta = await _metaFrom(id: 606, absolutePath: original.path);
      final variants = [
        Variant(meta, ImageVariant.raw),
        Variant(meta, ImageVariant.general),
        Variant(meta, ImageVariant.thumb),
      ];

      // Seed files
      for (final v in variants) {
        // Force a download to create RAW and trigger compress
        await cache.getVariantPath(variant: v, fetch: fakeDownloader);
        await _eventually(
          () => Future.value(File(v.cacheStoragePath).existsSync()),
        );
      }

      await cache.evictPhoto(meta.photo.id.toString());

      for (final v in variants) {
        expect(File(v.cacheStoragePath).existsSync(), isFalse);
      }

      final idx = await _readIndex();
      final items = (idx['items'] as List).cast<Map<String, dynamic>>();
      expect(
        items.any((e) => (e['key'] as String).startsWith('${meta.photo.id}|')),
        isFalse,
      );
    });

    test('clear removes all cached files (keeps/rewrites index)', () async {
      final original = await _makeOriginal(name: 'photo7.jpg');
      final meta = await _metaFrom(id: 707, absolutePath: original.path);
      final general = Variant(meta, ImageVariant.general);

      await cache.getVariantPath(variant: general, fetch: fakeDownloader);
      await _eventually(
        () => Future.value(File(general.cacheStoragePath).existsSync()),
      );

      await cache.clear();

      final dir = await _cacheDir();
      final files = Directory(
        dir,
      ).listSync().whereType<File>().map((f) => p.basename(f.path)).toList();

      // Only _index.json should remain
      expect(files, contains('_index.json'));
      expect(files.length, equals(1));

      final idx = await _readIndex();
      expect(idx['items'], isEmpty);
      expect(idx['total'], anyOf(0, isA<num>()));
    });

    test('setLastAccess seeds the LRU timestamp in index', () async {
      final original = await _makeOriginal(name: 'photo8.jpg');
      final meta = await _metaFrom(id: 808, absolutePath: original.path);
      final general = Variant(meta, ImageVariant.general);

      await cache.getVariantPath(variant: general, fetch: fakeDownloader);
      await _eventually(
        () => Future.value(File(general.cacheStoragePath).existsSync()),
      );

      // Read current timestamp
      var idx = await _readIndex();
      final before = DateTime.parse(
        (idx['items'] as List).cast<Map<String, dynamic>>().firstWhere(
              (e) => e['key'] == '${meta.photo.id}|general',
            )['accessed']
            as String,
      );

      final seed = DateTime(2001, 2, 3, 4, 5, 6);
      await cache.setLastAccess(variant: general, when: seed);

      idx = await _readIndex();
      final after = DateTime.parse(
        (idx['items'] as List).cast<Map<String, dynamic>>().firstWhere(
              (e) => e['key'] == '${meta.photo.id}|general',
            )['accessed']
            as String,
      );

      expect(
        after.isAtSameMomentAs(seed),
        isTrue,
        reason: 'lastAccess in index did not update to seeded value',
      );
      expect(after.isAtSameMomentAs(before), isFalse);
    });
  });
}

/// Helpers

/// Tiny file bytes to write in tests
List<int> _bytes(String s) => utf8.encode(s);

/// Poll for a condition to become true (with a small timeout)
Future<bool> _eventually(
  FutureOr<bool> Function() cond, {
  Duration timeout = const Duration(seconds: 2),
  Duration step = const Duration(milliseconds: 25),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (await cond()) {
      return true;
    }
    await Future<void>.delayed(step);
  }
  return false;
}

/// Test double: a simple original file under /tmp we’ll “pretend” is the source photo.
Future<File> _makeOriginal({
  required String name,
  String contents = 'ORIG',
}) async {
  final base = await getTemporaryDirectory();
  final dir = Directory(p.join(base, 'hmb_image_cache_test_src'));
  if (!dir.existsSync()) {
    dir.createSync(recursive: true);
  }
  final f = File(p.join(dir.path, name));
  await f.writeAsBytes(_bytes(contents));
  return f;
}

/// Read the cache’s _index.json for assertions.
Future<Map<String, dynamic>> _readIndex() async {
  final base = await getTemporaryDirectory();
  final cacheDir = p.join(base, 'photo_image_cache');
  final indexPath = p.join(cacheDir, '_index.json');
  if (!File(indexPath).existsSync()) {
    return {'items': <dynamic>[], 'total': 0};
  }
  final text = await File(indexPath).readAsString();
  return json.decode(text) as Map<String, dynamic>;
}

/// Look up the cache dir used by HMBImageCache.
Future<String> _cacheDir() async {
  final base = await getTemporaryDirectory();
  return p.join(base, 'photo_image_cache');
}

/// Build a real PhotoMeta from an entity Photo
/// (assumes PhotoMeta.fromPhoto exists in your codebase).
Future<PhotoMeta> _metaFrom({
  required int id,
  required String absolutePath,
}) async {
  final now = DateTime.now();
  // Your Photo has more fields; we only set what PhotoMeta needs.
  final photo = Photo(
    id: id,
    parentId: 1,
    parentType: ParentType.task,
    filename: absolutePath, // meta.resolve() will usually
    // handle absolute->relative, but absolute is fine for tests
    comment: '',
    lastBackupDate: now,
    createdDate: now,
    modifiedDate: now,
  );
  final meta = PhotoMeta.fromPhoto(photo: photo);
  await meta.resolve(); // ensure absolutePath is ready
  return meta;
}

class _FakePathProvider
    with t.Fake, MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  // Create an isolated temp dir for the cache.
  final String tempPath = c.createTempDir();

  final String docPath = c.createTempDir();

  _FakePathProvider();

  @override
  Future<String?> getTemporaryPath() async => tempPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => docPath;
}

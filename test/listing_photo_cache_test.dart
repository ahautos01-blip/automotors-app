import 'dart:async';
import 'dart:typed_data';

import 'package:automotors_base/services/listing_photo_loader.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Uint8List photo(int value, [int size = 2]) =>
      Uint8List(size)..fillRange(0, size, value);

  test(
    'catalog, gallery and chat share downloads including concurrent requests',
    () async {
      final cache = ListingPhotoCache();
      final calls = <String>[];
      Future<Uint8List> download(String path) async {
        calls.add(path);
        return photo(path == 'cover' ? 1 : 2);
      }

      Future<Uint8List> load(String path) =>
          cache.load(path, download, scope: 'session');
      final covers = await Future.wait([
        loadListingCover(['cover', 'second'], load),
        loadListingCover(['cover', 'second'], load),
      ]);
      final gallery = await loadListingGallery(
        ['cover', 'second'],
        covers.first,
        load,
      );
      await load('cover');
      expect(calls, ['cover', 'second']);
      expect(gallery.map((bytes) => bytes.first), [1, 2]);
    },
  );

  test('cache expires even when the same photo is read frequently', () async {
    var now = DateTime(2026);
    final cache = ListingPhotoCache(
      now: () => now,
      maxAge: const Duration(minutes: 5),
    );
    var requests = 0;
    Future<Uint8List> download(String _) async => photo(++requests);
    await cache.load('photo', download, scope: 'guest');
    now = now.add(const Duration(minutes: 4));
    expect((await cache.load('photo', download, scope: 'guest')).first, 1);
    now = now.add(const Duration(minutes: 1));
    expect((await cache.load('photo', download, scope: 'guest')).first, 2);
  });

  test(
    'byte budget evicts least recently used entries and skips oversized photos',
    () async {
      final cache = ListingPhotoCache(maxBytes: 4);
      final calls = <String>[];
      Future<Uint8List> download(String path) async {
        calls.add(path);
        return photo(1, path == 'large' ? 5 : 2);
      }

      Future<void> load(String path) async {
        await cache.load(path, download, scope: 'guest');
      }

      await load('a');
      await load('b');
      await load('a');
      await load('c');
      await load('a');
      await load('b');
      await load('large');
      await load('large');
      expect(calls, ['a', 'b', 'c', 'b', 'large', 'large']);
    },
  );

  test('entry limit also bounds empty responses', () async {
    final cache = ListingPhotoCache(maxEntries: 1);
    var requests = 0;
    Future<Uint8List> download(String _) async {
      requests++;
      return Uint8List(0);
    }

    await cache.load('a', download, scope: 'guest');
    await cache.load('b', download, scope: 'guest');
    await cache.load('a', download, scope: 'guest');
    expect(requests, 3);
  });

  test(
    'failed downloads are retried, including synchronous failures',
    () async {
      final cache = ListingPhotoCache();
      var requests = 0;
      Future<Uint8List> download(String _) {
        requests++;
        if (requests == 1) throw StateError('offline');
        return Future.value(photo(2));
      }

      await expectLater(
        cache.load('a', download, scope: 'guest'),
        throwsStateError,
      );
      expect((await cache.load('a', download, scope: 'guest')).first, 2);
    },
  );

  test(
    'a prior session cannot refill or clear the current session cache',
    () async {
      final cache = ListingPhotoCache();
      final oldDownload = Completer<Uint8List>();
      final old = cache.load(
        'private',
        (_) => oldDownload.future,
        scope: 'old-user',
      );
      await Future<void>.delayed(Duration.zero);
      final current = await cache.load(
        'private',
        (_) async => photo(2),
        scope: 'new-user',
      );
      oldDownload.complete(photo(1));
      await old;
      final again = await cache.load(
        'private',
        (_) async => throw StateError('unexpected download'),
        scope: 'new-user',
      );
      expect(current.first, 2);
      expect(again.first, 2);
      final guest = await cache.load(
        'private',
        (_) async => photo(3),
        scope: 'guest',
      );
      expect(guest.first, 3);
    },
  );
}

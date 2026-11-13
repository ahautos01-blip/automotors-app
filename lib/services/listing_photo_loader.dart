import 'dart:typed_data';

typedef ListingPhotoDownload = Future<Uint8List> Function(String path);

Future<List<Uint8List>> loadListingCover(
  List<String> paths,
  ListingPhotoDownload download,
) async {
  if (paths.isEmpty) return [];
  try {
    return [await download(paths.first)];
  } catch (_) {
    return [];
  }
}

Future<List<Uint8List>> loadListingGallery(
  List<String> paths,
  List<Uint8List> cover,
  ListingPhotoDownload download, {
  void Function(List<Uint8List>)? onProgress,
}) async {
  // Publish partial results in order, with at most three downloads at once.
  final loaded = <int, Uint8List>{};
  if (cover.isNotEmpty) loaded[0] = cover.first;
  var next = cover.isEmpty ? 0 : 1;
  Future<void> worker() async {
    while (next < paths.length) {
      final index = next++;
      try {
        loaded[index] = await download(paths[index]);
      } catch (_) {
        continue;
      }
      final indexes = loaded.keys.toList()..sort();
      onProgress?.call([for (final i in indexes) loaded[i]!]);
    }
  }

  await Future.wait(List.generate(3, (_) => worker()));
  final indexes = loaded.keys.toList()..sort();
  return [for (final i in indexes) loaded[i]!];
}

/// Bounded session cache for private vehicle photos. Failed downloads are retried.
class ListingPhotoCache {
  ListingPhotoCache({
    this.maxBytes = 24 * 1024 * 1024,
    this.maxEntries = 128,
    this.maxAge = const Duration(minutes: 5),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now {
    if (maxBytes <= 0 || maxEntries <= 0 || maxAge <= Duration.zero) {
      throw ArgumentError('Photo cache limits must be positive');
    }
  }

  final int maxBytes;
  final int maxEntries;
  final Duration maxAge;
  final DateTime Function() _now;
  final _entries = <String, _CachedListingPhoto>{};
  final _pending = <String, Future<Uint8List>>{};
  String? _scope;
  int _generation = 0;
  int _byteCount = 0;

  Future<Uint8List> load(
    String path,
    ListingPhotoDownload download, {
    required String scope,
  }) {
    if (_scope != scope) {
      clear();
      _scope = scope;
    }
    final now = _now();
    final expired = _entries.keys
        .where((key) => now.difference(_entries[key]!.createdAt) >= maxAge)
        .toList();
    for (final key in expired) {
      _byteCount -= _entries.remove(key)!.bytes.lengthInBytes;
    }
    final cached = _entries.remove(path);
    if (cached != null) {
      _entries[path] = cached;
      return Future.value(cached.bytes);
    }
    return _pending.putIfAbsent(path, () {
      final generation = _generation;
      // Start asynchronously so even a synchronous failure releases the slot.
      return Future<Uint8List>(() => download(path))
          .then((bytes) {
            if (generation == _generation && bytes.lengthInBytes <= maxBytes) {
              while (_byteCount + bytes.lengthInBytes > maxBytes ||
                  _entries.length >= maxEntries) {
                _byteCount -= _entries
                    .remove(_entries.keys.first)!
                    .bytes
                    .lengthInBytes;
              }
              _entries[path] = _CachedListingPhoto(bytes, _now());
              _byteCount += bytes.lengthInBytes;
            }
            return bytes;
          })
          .whenComplete(() {
            if (generation == _generation) _pending.remove(path);
          });
    });
  }

  void clear() {
    _generation++;
    _entries.clear();
    _pending.clear();
    _byteCount = 0;
  }
}

class _CachedListingPhoto {
  const _CachedListingPhoto(this.bytes, this.createdAt);
  final Uint8List bytes;
  final DateTime createdAt;
}

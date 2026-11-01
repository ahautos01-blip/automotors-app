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
  ListingPhotoDownload download,
) async {
  // A successful cover is always the first ordered path. Do not fetch it twice.
  final rest = await Future.wait(
    paths.skip(cover.isEmpty ? 0 : 1).map((path) async {
      try {
        return await download(path);
      } catch (_) {
        return null;
      }
    }),
  );
  return [...cover, ...rest.whereType<Uint8List>()];
}

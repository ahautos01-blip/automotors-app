import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

final _copies = <String, Map<String, String>>{};

Future<Directory> _folder(String owner, {String? supportPath}) async {
  if (!RegExp(r'^[a-zA-Z0-9-]{1,80}$').hasMatch(owner)) {
    throw ArgumentError('Invalid draft owner');
  }
  return Directory(
    '${supportPath ?? (await getApplicationSupportDirectory()).path}/publication-drafts/$owner',
  );
}

Future<List<String>> persistDraftPhotos(
  String owner,
  List<XFile> photos, {
  String? supportPath,
}) async {
  final folder = await _folder(owner, supportPath: supportPath);
  await folder.create(recursive: true);
  final paths = <String>[];
  final copies = _copies.putIfAbsent(owner, () => {});
  for (final photo in photos.take(15)) {
    if (File(photo.path).parent.absolute.path == folder.absolute.path &&
        await File(photo.path).exists()) {
      paths.add(File(photo.path).uri.pathSegments.last);
      continue;
    }
    final cached = copies[photo.path];
    if (cached != null && await File('${folder.path}/$cached').exists()) {
      paths.add(cached);
      continue;
    }
    final ext = photo.name.split('.').last.toLowerCase();
    final safeExt = ['jpg', 'jpeg', 'png', 'webp', 'heic'].contains(ext)
        ? ext
        : 'jpg';
    final file = File(
      '${folder.path}/${DateTime.now().microsecondsSinceEpoch}-${paths.length}.$safeExt',
    );
    await file.writeAsBytes(await photo.readAsBytes(), flush: true);
    final name = file.uri.pathSegments.last;
    paths.add(name);
    copies[photo.path] = name;
  }
  return paths;
}

Future<List<XFile>> restoreDraftPhotos(
  String owner,
  List<String> paths, {
  String? supportPath,
}) async {
  if (paths.isEmpty) return [];
  final folder = await _folder(owner, supportPath: supportPath);
  final result = <XFile>[];
  for (final path in paths.take(15)) {
    // Relative file names survive iOS container moves during an app update.
    final file = File(path).isAbsolute
        ? File(path)
        : File('${folder.path}/$path');
    if (file.parent.absolute.path != folder.absolute.path) continue;
    if (await file.exists()) result.add(XFile(file.path));
  }
  return result;
}

Future<void> clearDraftPhotos(String owner, {String? supportPath}) async {
  _copies.remove(owner);
  final folder = await _folder(owner, supportPath: supportPath);
  if (await folder.exists()) await folder.delete(recursive: true);
}

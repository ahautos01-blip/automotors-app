import 'package:image_picker/image_picker.dart';

Future<List<String>> persistDraftPhotos(
  String owner,
  List<XFile> photos,
) async => [];
Future<List<XFile>> restoreDraftPhotos(
  String owner,
  List<String> paths,
) async => [];
Future<void> clearDraftPhotos(String owner) async {}

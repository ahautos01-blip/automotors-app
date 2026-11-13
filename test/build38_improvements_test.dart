import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:automotors_base/services/draft_photo_files_io.dart';
import 'package:automotors_base/services/listing_photo_loader.dart';
import 'package:automotors_base/design/seller_listing_metrics.dart';

void main() {
  test('draft photos survive a new form and are isolated by owner', () async {
    final root = await Directory.systemTemp.createTemp('automotors-draft-test');
    try {
      final paths = await persistDraftPhotos('owner-a', [
        XFile.fromData(Uint8List.fromList([1, 2, 3]), name: 'car.jpg'),
      ], supportPath: root.path);
      final restored = await restoreDraftPhotos(
        'owner-a',
        paths,
        supportPath: root.path,
      );
      expect(await restored.single.readAsBytes(), [1, 2, 3]);
      expect(
        await restoreDraftPhotos('owner-b', paths, supportPath: root.path),
        isEmpty,
      );
      expect(
        await restoreDraftPhotos('owner-a', [
          '${root.path}/outside.jpg',
        ], supportPath: root.path),
        isEmpty,
      );
      await clearDraftPhotos('owner-a', supportPath: root.path);
      expect(
        await restoreDraftPhotos('owner-a', paths, supportPath: root.path),
        isEmpty,
      );
    } finally {
      await root.delete(recursive: true);
    }
  });
  test('gallery publishes before slow photo completes, keeps ordering and bounds concurrency', () async {
    final slow = Completer<Uint8List>();
    var active = 0, maxActive = 0;
    final progress = <List<int>>[];
    final future = loadListingGallery(
      ['a', 'b', 'c', 'd', 'e'],
      [],
      (path) async {
        active++;
        if (active > maxActive) maxActive = active;
        try {
          if (path == 'b') return await slow.future;
          if (path == 'd') throw StateError('offline');
          return Uint8List.fromList([path.codeUnitAt(0)]);
        } finally {
          active--;
        }
      },
      onProgress: (photos) => progress.add(photos.map((p) => p.first).toList()),
    );
    await Future<void>.delayed(Duration.zero);
    expect(progress, isNotEmpty);
    expect(maxActive, lessThanOrEqualTo(3));
    slow.complete(Uint8List.fromList([98]));
    expect((await future).map((p) => p.first), [97, 98, 99, 101]);
  });
  test('seller advice never invents price valuation or contacts', () {
    expect(
      sellerActivityAdvice({'views': 10, 'conversations': 0}),
      contains('aún no hay conversaciones'),
    );
    expect(
      sellerActivityAdvice({'views': 10, 'conversations': 1}),
      contains('personas interesadas'),
    );
    expect(
      sellerActivityAdvice({'views': 0, 'conversations': 0}),
      contains('poca actividad'),
    );
  });
}

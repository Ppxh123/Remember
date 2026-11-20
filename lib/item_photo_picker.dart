import 'dart:io';
import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

typedef PickItemPhotos =
    Future<List<Uint8List>> Function(ItemPhotoSource source);

enum ItemPhotoSource { camera, gallery }

Future<List<Uint8List>> recoverItemPhotos() async {
  if (!Platform.isAndroid) return [];
  final lost = await ImagePicker().retrieveLostData();
  if (lost.exception case final error?) throw error;
  return [for (final file in lost.files ?? <XFile>[]) await file.readAsBytes()];
}

Future<List<Uint8List>> pickItemPhotos(ItemPhotoSource source) async {
  final picker = ImagePicker();
  final List<XFile> files;
  if (source == ItemPhotoSource.camera) {
    final file = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
      requestFullMetadata: false,
    );
    files = [?file];
  } else {
    files = await picker.pickMultiImage(
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
      requestFullMetadata: false,
    );
  }
  return [for (final file in files) await file.readAsBytes()];
}

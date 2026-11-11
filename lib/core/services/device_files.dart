import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';

abstract interface class DeviceFiles {
  Future<bool> saveBackup(String content, String name);
  Future<String?> pickBackup();
  Future<String?> pickPetImage();
}

class NativeDeviceFiles implements DeviceFiles {
  @override
  Future<bool> saveBackup(String content, String name) async =>
      await FilePicker.saveFile(
        fileName: name,
        bytes: Uint8List.fromList(utf8.encode(content)),
        mimeType: 'application/json',
        dialogTitle: 'Guardar respaldo de knotes',
      ) !=
      null;
  @override
  Future<String?> pickBackup() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['json'],
      dialogTitle: 'Elegir respaldo de knotes',
    );
    return file == null ? null : utf8.decode(await file.readAsBytes());
  }

  @override
  Future<String?> pickPetImage() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['png', 'jpg', 'jpeg', 'webp'],
      dialogTitle: 'Elegir mascota',
    );
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    if (bytes.length > 4 * 1024 * 1024) {
      throw const FormatException('Elige una imagen de hasta 4 MB.');
    }
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    try {
      final descriptor = await ui.ImageDescriptor.encoded(buffer);
      try {
        if (descriptor.width > 2048 || descriptor.height > 2048) {
          throw const FormatException('Elige una imagen de hasta 2048 × 2048.');
        }
        final codec = await descriptor.instantiateCodec();
        try {
          if (codec.frameCount != 1) {
            throw const FormatException(
              'Elige una imagen fija para tu mascota.',
            );
          }
          (await codec.getNextFrame()).image.dispose();
        } finally {
          codec.dispose();
        }
      } finally {
        descriptor.dispose();
      }
    } finally {
      buffer.dispose();
    }
    return base64Encode(bytes);
  }
}

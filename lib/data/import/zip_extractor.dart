import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter/services.dart' show rootBundle;

class ZipExtractor {
  const ZipExtractor();

  /// Extracts [targetZipPath] (e.g. 'nocr/en_engniv.sqlite') from [zipBytes],
  /// [zipFilePath], or assets/data.zip and writes it to [destinationPath].
  Future<void> extractFile({
    required String targetZipPath,
    required String destinationPath,
    List<int>? zipBytes,
    String? zipFilePath,
  }) async {
    List<int> bytes;
    if (zipBytes != null) {
      bytes = zipBytes;
    } else if (zipFilePath != null) {
      bytes = await File(zipFilePath).readAsBytes();
    } else {
      final byteData = await rootBundle.load('assets/data.zip');
      bytes = byteData.buffer.asUint8List(
        byteData.offsetInBytes,
        byteData.lengthInBytes,
      );
    }

    final archive = ZipDecoder().decodeBytes(bytes);
    final matchedFile = _findFile(archive, targetZipPath);

    if (matchedFile == null) {
      throw Exception('File "$targetZipPath" not found inside zip archive.');
    }

    final destFile = File(destinationPath);
    await destFile.parent.create(recursive: true);
    final content = matchedFile.content as List<int>;
    await destFile.writeAsBytes(content);
  }

  Future<bool> containsFile({
    required String targetZipPath,
    List<int>? zipBytes,
    String? zipFilePath,
  }) async {
    List<int> bytes;
    if (zipBytes != null) {
      bytes = zipBytes;
    } else if (zipFilePath != null) {
      bytes = await File(zipFilePath).readAsBytes();
    } else {
      final byteData = await rootBundle.load('assets/data.zip');
      bytes = byteData.buffer.asUint8List(
        byteData.offsetInBytes,
        byteData.lengthInBytes,
      );
    }

    final archive = ZipDecoder().decodeBytes(bytes);
    return _findFile(archive, targetZipPath) != null;
  }

  ArchiveFile? _findFile(Archive archive, String targetZipPath) {
    final targetLower = targetZipPath.toLowerCase().replaceAll('\\', '/');

    for (final file in archive) {
      if (file.isFile) {
        final entryNameLower = file.name.toLowerCase().replaceAll('\\', '/');
        if (entryNameLower == targetLower ||
            entryNameLower.endsWith('/$targetLower')) {
          return file;
        }
      }
    }
    return null;
  }
}

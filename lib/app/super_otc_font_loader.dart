import 'dart:typed_data';
import 'dart:ui' show loadFontFromList;

import 'package:flutter/services.dart';

class SuperOtcFontLoader {
  SuperOtcFontLoader._();

  static final _familyLoads = <String, Future<void>>{};
  static Future<void> _queue = Future.value();

  static Future<void> ensureLoaded({
    required String assetPath,
    required int faceIndex,
    required String family,
  }) async {
    final existingLoad = _familyLoads[family];
    if (existingLoad != null) return existingLoad;

    final load = _queue.then((_) async {
      final collection = await rootBundle.load(assetPath);
      final face = extractOpenTypeFace(collection, faceIndex);
      await loadFontFromList(face, fontFamily: family);
    });
    _queue = load.then<void>((_) {}, onError: (_, _) {});
    _familyLoads[family] = load;
    try {
      await load;
    } catch (_) {
      _familyLoads.remove(family);
      rethrow;
    }
  }
}

Uint8List extractOpenTypeFace(ByteData collection, int faceIndex) {
  if (collection.lengthInBytes < 12 || _tag(collection, 0) != 'ttcf') {
    throw const FormatException('Expected an OpenType collection');
  }

  final faceCount = collection.getUint32(8, Endian.big);
  if (faceIndex < 0 || faceIndex >= faceCount) {
    throw RangeError.range(faceIndex, 0, faceCount - 1, 'faceIndex');
  }

  final faceOffset = collection.getUint32(12 + faceIndex * 4, Endian.big);
  _requireRange(collection, faceOffset, 12);
  final tableCount = collection.getUint16(faceOffset + 4, Endian.big);
  final directoryLength = 12 + tableCount * 16;
  _requireRange(collection, faceOffset, directoryLength);

  final records = <_OpenTypeTable>[];
  var outputLength = directoryLength;
  for (var index = 0; index < tableCount; index++) {
    final recordOffset = faceOffset + 12 + index * 16;
    final length = collection.getUint32(recordOffset + 12, Endian.big);
    final sourceOffset = collection.getUint32(recordOffset + 8, Endian.big);
    _requireRange(collection, sourceOffset, length);
    outputLength = _align4(outputLength);
    records.add(
      _OpenTypeTable(
        tag: _tag(collection, recordOffset),
        checksum: collection.getUint32(recordOffset + 4, Endian.big),
        sourceOffset: sourceOffset,
        outputOffset: outputLength,
        length: length,
      ),
    );
    outputLength += length;
  }

  final output = Uint8List(_align4(outputLength));
  final outputData = ByteData.sublistView(output);
  for (var index = 0; index < directoryLength; index++) {
    output[index] = collection.getUint8(faceOffset + index);
  }

  for (var index = 0; index < records.length; index++) {
    final record = records[index];
    final recordOffset = 12 + index * 16;
    outputData.setUint32(recordOffset + 4, record.checksum, Endian.big);
    outputData.setUint32(recordOffset + 8, record.outputOffset, Endian.big);
    outputData.setUint32(recordOffset + 12, record.length, Endian.big);
    for (var byteIndex = 0; byteIndex < record.length; byteIndex++) {
      output[record.outputOffset + byteIndex] = collection.getUint8(
        record.sourceOffset + byteIndex,
      );
    }
  }

  final head = records.where((record) => record.tag == 'head').firstOrNull;
  if (head != null && head.length >= 12) {
    outputData.setUint32(head.outputOffset + 8, 0, Endian.big);
    final adjustment = (0xB1B0AFBA - _checksum(output)) & 0xFFFFFFFF;
    outputData.setUint32(head.outputOffset + 8, adjustment, Endian.big);
  }

  return output;
}

String _tag(ByteData data, int offset) {
  _requireRange(data, offset, 4);
  return String.fromCharCodes([
    data.getUint8(offset),
    data.getUint8(offset + 1),
    data.getUint8(offset + 2),
    data.getUint8(offset + 3),
  ]);
}

void _requireRange(ByteData data, int offset, int length) {
  if (offset < 0 || length < 0 || offset + length > data.lengthInBytes) {
    throw const FormatException('Invalid OpenType collection offset');
  }
}

int _align4(int value) => (value + 3) & ~3;

int _checksum(Uint8List bytes) {
  final data = ByteData.sublistView(bytes);
  var sum = 0;
  for (var offset = 0; offset < bytes.length; offset += 4) {
    sum = (sum + data.getUint32(offset, Endian.big)) & 0xFFFFFFFF;
  }
  return sum;
}

class _OpenTypeTable {
  const _OpenTypeTable({
    required this.tag,
    required this.checksum,
    required this.sourceOffset,
    required this.outputOffset,
    required this.length,
  });

  final String tag;
  final int checksum;
  final int sourceOffset;
  final int outputOffset;
  final int length;
}

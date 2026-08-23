import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:Love/app/super_otc_font_loader.dart';

void main() {
  test('extracts distinct standalone faces from a Super OTC', () async {
    final bytes = await File('assets/fonts/NotoSerifCJK.ttc').readAsBytes();
    final collection = ByteData.sublistView(bytes);

    final extraLight = extractOpenTypeFace(collection, 1);
    final black = extractOpenTypeFace(collection, 31);

    expect(String.fromCharCodes(extraLight.take(4)), 'OTTO');
    expect(String.fromCharCodes(black.take(4)), 'OTTO');
    expect(extraLight.length, isNot(black.length));
    expect(extraLight.take(4), isNot(orderedEquals([0x74, 0x74, 0x63, 0x66])));
    expect(black.take(4), isNot(orderedEquals([0x74, 0x74, 0x63, 0x66])));
  });

  test('rejects an invalid Super OTC face index', () {
    final collection = ByteData.sublistView(
      Uint8List.fromList([
        0x74,
        0x74,
        0x63,
        0x66,
        0x00,
        0x01,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
      ]),
    );

    expect(
      () => extractOpenTypeFace(collection, 0),
      throwsA(isA<RangeError>()),
    );
  });
}

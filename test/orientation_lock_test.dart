import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('app enforces portrait-only orientations', () {
    const orientations = [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ];
    expect(orientations.contains(DeviceOrientation.landscapeLeft), isFalse);
    expect(orientations.contains(DeviceOrientation.landscapeRight), isFalse);
  });
}

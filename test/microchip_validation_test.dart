import 'package:flutter_test/flutter_test.dart';
import 'package:vitail/microchip_validation.dart';

void main() {
  test('MVP accepts 15 digits including leading zeroes', () {
    expect(microchipNumberError('000123456789012'), isNull);
    expect(microchipNumberError(' 900123456789012 '), isNull);
  });
  test('missing, malformed and test numbers cannot unlock rewards', () {
    for (final value in [
      '',
      '12345678901234',
      '1234567890123456',
      '90012345678901a',
      '999123456789012',
    ]) {
      expect(microchipNumberError(value), isNotNull);
    }
  });
}

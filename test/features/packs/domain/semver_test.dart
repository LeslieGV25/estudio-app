import 'package:estudio_app/features/packs/domain/semver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  SemVer v(String s) => SemVer.parse(s);

  test('compara número a número, no como texto', () {
    expect(v('1.10.0') > v('1.9.0'), isTrue);
    expect(v('2.0.0') > v('1.99.99'), isTrue);
    expect(v('1.0.10') > v('1.0.9'), isTrue);
    expect(v('1.0.0') > v('1.0.0'), isFalse);
  });

  test('igualdad y orden', () {
    expect(v('1.2.3'), v('1.2.3'));
    expect([v('1.10.0'), v('1.2.0'), v('0.9.9')]..sort(), [
      v('0.9.9'),
      v('1.2.0'),
      v('1.10.0'),
    ]);
  });

  test('rechaza versiones que no son MAYOR.MENOR.PARCHE', () {
    for (final s in ['1.0', '1.0.0-beta', 'v1.0.0', '']) {
      expect(() => v(s), throwsFormatException, reason: s);
    }
  });
}

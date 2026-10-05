import 'package:estudio_app/core/domain/session_mode.dart';
import 'package:estudio_app/core/router/session_routes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cada modo tiene su ruta base', () {
    expect(SessionMode.practice.sessionPath('s1'), '/practice/session/s1');
    expect(SessionMode.review.sessionPath('s1'), '/review/session/s1');
    expect(SessionMode.review.summaryPath('s1'), '/review/summary/s1');
    expect(SessionMode.practice.basePath, '/practice');
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:indulj/core/env.dart';

void main() {
  test('futarApiKey is empty without dart-define', () {
    expect(Env.futarApiKey, isEmpty);
  });
}

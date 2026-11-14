import 'package:test/test.dart';
import 'package:unlock_core/unlock_core.dart';

void main() {
  test('exposes a version', () {
    expect(unlockCoreVersion, matches(RegExp(r'^\d+\.\d+\.\d+$')));
  });
}

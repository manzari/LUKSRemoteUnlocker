import 'package:flutter_test/flutter_test.dart';
import 'package:luks_remote_unlocker/main.dart';

void main() {
  testWidgets('shows the placeholder home screen', (tester) async {
    await tester.pumpWidget(const LuksRemoteUnlockerApp());

    expect(find.text('LUKS Remote Unlocker'), findsOneWidget);
    expect(find.text('No servers yet.'), findsOneWidget);
  });
}

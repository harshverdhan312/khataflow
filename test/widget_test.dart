import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khata_flow/app/app.dart';

void main() {
  testWidgets('KhataFlowApp boots up to dashboard foundation screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: KhataFlowApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('KhataFlow'), findsOneWidget);
    expect(find.text('KhataFlow Foundation Ready'), findsOneWidget);
  });
}

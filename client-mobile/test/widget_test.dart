import 'package:flutter_test/flutter_test.dart';
import 'package:zero_trace_p2p/main.dart';

void main() {
  testWidgets('ZeroTraceApp Smoke Test', (WidgetTester tester) async {
    await tester.pumpWidget(const ZeroTraceApp());
    expect(find.text('تواصل فوري سري ومباشر (P2P)'), findsOneWidget);
  });
}

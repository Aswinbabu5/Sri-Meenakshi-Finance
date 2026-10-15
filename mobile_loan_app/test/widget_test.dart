import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_loan_app/app/app.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('Smoke test for LoanManagementApp', (WidgetTester tester) async {
    await tester.pumpWidget(const LoanManagementApp());
    expect(find.byType(LoanManagementApp), findsOneWidget);
  });
}

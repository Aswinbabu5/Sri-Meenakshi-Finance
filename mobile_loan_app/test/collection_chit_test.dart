import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:mobile_loan_app/core/services/loan_repository.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Daily Chit Collection Tests', () {
    late LoanRepository repo;

    setUp(() async {
      repo = LoanRepository();
      await repo.login('admin', 'admin123');
    });

    test('Multiple collections on same day accumulate directly to corresponding person', () async {
      final uniqueSuffix = DateTime.now().microsecondsSinceEpoch.toString().substring(10);
      final testDate = DateTime(2028, 10, 15);
      final loan = await repo.createLoan(
        lineCode: 'A',
        bondNumber: 'A99$uniqueSuffix',
        customerName: 'Simon $uniqueSuffix',
        phoneNumber: '9876543210',
        loanAmount: 10000,
        interestAmount: 1500,
        startDate: testDate,
      );

      final initialBalance = loan.balanceAmount;
      expect(initialBalance, 11500);

      // Simon gives 100 in morning (at 10 AM)
      final col1 = await repo.recordCollection(
        bondNumber: loan.bondNumber,
        lineCode: loan.lineCode,
        amount: 100,
        collectionDate: testDate,
        notes: 'Morning 10 AM collection',
      );

      expect(col1.amount, 100);
      expect(loan.balanceAmount, initialBalance - 100);

      // Verify today collection can be retrieved
      final todayCol = repo.getTodayCollectionForLoan(loan.bondNumber, testDate);
      expect(todayCol, isNotNull);
      expect(todayCol!.amount, 100);

      // Later, Simon gives another 100 on the same day (at 12 PM)
      final col2 = await repo.recordCollection(
        bondNumber: loan.bondNumber,
        lineCode: loan.lineCode,
        amount: 100,
        collectionDate: testDate,
        notes: 'Afternoon 12 PM collection',
      );

      // Amount should be combined directly to 200
      expect(col2.amount, 200);
      // Balance should be reduced by total 200
      expect(loan.balanceAmount, initialBalance - 200);
      // Notes should be combined
      expect(col2.notes, contains('Morning 10 AM collection'));
      expect(col2.notes, contains('Afternoon 12 PM collection'));

      // Daily sheet should reflect single consolidated party entry for Simon
      final sheet = repo.getDailySheet(date: testDate, lineCode: loan.lineCode);
      final simonEntries = sheet.where((c) => c.bondNumber == loan.bondNumber).toList();
      expect(simonEntries.length, 1);
      expect(simonEntries.first.amount, 200);
    });
  });
}

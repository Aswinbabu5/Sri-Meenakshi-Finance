import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:mobile_loan_app/core/models/loan_model.dart';
import 'package:mobile_loan_app/core/models/collection_model.dart';
import 'package:mobile_loan_app/core/services/loan_repository.dart';
import 'package:mobile_loan_app/core/services/member_pdf_generator.dart';
import 'package:mobile_loan_app/core/services/records_export_service.dart';
import 'package:mobile_loan_app/core/services/app_finance_folder_service.dart';
import 'package:mobile_loan_app/core/utils/safe_image_provider.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('app-finance Direct Folder Organization Tests', () {
    test('sanitizeFileName removes special characters and spaces safely', () {
      expect(AppFinanceFolderService.sanitizeFileName('A-001 Murugan / Test'), 'A-001_Murugan_Test');
      expect(AppFinanceFolderService.sanitizeFileName('A002: Rani * <Sample>'), 'A002_Rani_Sample');
    });

    test('getSafeImageBytes extracts base64 bytes properly', () {
      final rawBytes = [0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46];
      final b64 = base64Encode(rawBytes);
      final dataUri = 'data:image/jpeg;base64,$b64';

      final extracted = getSafeImageBytes(dataUri);
      expect(extracted, isNotNull);
      expect(extracted, equals(rawBytes));
    });

    test('MemberPdfGenerator generates valid PDF bytes with header %PDF', () async {
      final rawBytes = [0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46];
      final b64 = base64Encode(rawBytes);
      final dummyPhotoUri = 'data:image/jpeg;base64,$b64';

      final loan = LoanModel(
        id: 1,
        bondNumber: 'A001',
        lineCode: 'A',
        customerId: 101,
        customerName: 'முருகன் (Murugan)',
        fatherOrSpouseName: 'கந்தன் (Kandhan)',
        phoneNumber: '9840123456',
        address: '12 South Street',
        city: 'மதுரை',
        photoPath: dummyPhotoUri,
        proofType: 'ஆதார் அட்டை (Aadhaar Card)',
        proofFrontPath: dummyPhotoUri,
        proofBackPath: dummyPhotoUri,
        tenureDays: 100,
        loanAmount: 10000,
        interestAmount: 1000,
        totalAmount: 10000,
        dailyDueAmount: 100,
        chitFee: 100,
        startDate: DateTime(2028, 1, 1),
        endDate: DateTime(2028, 4, 10),
        collectedAmount: 1000,
        balanceAmount: 9000,
        status: 'active',
      );

      final collections = <CollectionModel>[
        CollectionModel(
          id: 1,
          loanId: 1,
          bondNumber: 'A001',
          lineCode: 'A',
          customerName: 'முருகன் (Murugan)',
          amount: 500,
          previousBalance: 10000,
          currentBalance: 9500,
          collectionDate: DateTime(2028, 1, 2),
          paymentMode: 'Cash',
        ),
      ];

      final pdfBytes = await MemberPdfGenerator.generateMemberPdf(
        loan: loan,
        collections: collections,
        isTamil: true,
      );

      expect(pdfBytes, isNotNull);
      expect(pdfBytes.length, greaterThan(100));
      final header = String.fromCharCodes(pdfBytes.take(4));
      expect(header, '%PDF');
    });

    test('AppFinanceFolderService directly saves photo, proof, and PDF into app-finance folders', () async {
      final rawBytes = [0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46];
      final b64 = base64Encode(rawBytes);
      final dummyImageUri = 'data:image/jpeg;base64,$b64';

      final unique = DateTime.now().millisecondsSinceEpoch.toString().substring(8);
      final loan = LoanModel(
        id: 999,
        bondNumber: 'A-$unique',
        lineCode: 'A',
        customerId: 999,
        customerName: 'Ramu Test $unique',
        phoneNumber: '9876543210',
        photoPath: dummyImageUri,
        proofType: 'Aadhaar Card',
        proofFrontPath: dummyImageUri,
        proofBackPath: dummyImageUri,
        loanAmount: 10000,
        interestAmount: 1000,
        totalAmount: 10000,
        dailyDueAmount: 100,
        balanceAmount: 10000,
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 100)),
        status: 'active',
      );

      final result = await AppFinanceFolderService.saveMemberFiles(
        loan: loan,
        isTamil: true,
      );

      expect(result.success, isTrue);
      expect(result.photoPath, isNotNull);
      expect(result.proofFrontPath, isNotNull);
      expect(result.proofBackPath, isNotNull);
      expect(result.pdfPath, isNotNull);

      // Verify files exist in their respective app-finance folders
      expect(File(result.photoPath!).existsSync(), isTrue);
      expect(result.photoPath!.endsWith('.jpg'), isTrue);
      expect(result.photoPath!.contains('member-photo'), isTrue);

      expect(File(result.proofFrontPath!).existsSync(), isTrue);
      expect(result.proofFrontPath!.endsWith('.jpg'), isTrue);
      expect(result.proofFrontPath!.contains('member-proof'), isTrue);

      expect(File(result.pdfPath!).existsSync(), isTrue);
      expect(result.pdfPath!.endsWith('.pdf'), isTrue);
      expect(result.pdfPath!.contains('member-details'), isTrue);
    });

    test('RecordsExportService exports all records directly to app-finance folders without zip', () async {
      final repo = LoanRepository();
      await repo.login('admin', 'admin123');

      final rawBytes = [0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46];
      final b64 = base64Encode(rawBytes);
      final dummyImageUri = 'data:image/jpeg;base64,$b64';

      final uniqueSuffix = DateTime.now().microsecondsSinceEpoch.toString().substring(10);
      final loan = await repo.createLoan(
        lineCode: 'A',
        bondNumber: 'A99$uniqueSuffix',
        customerName: 'Direct Member $uniqueSuffix',
        phoneNumber: '9123456789',
        loanAmount: 10000,
        interestAmount: 1000,
        startDate: DateTime.now(),
        photoPath: dummyImageUri,
        proofType: 'Aadhaar Card',
        proofFrontPath: dummyImageUri,
        proofBackPath: dummyImageUri,
      );

      expect(loan.photoPath, dummyImageUri);

      final result = await RecordsExportService.exportRecords(
        repository: repo,
        lineFilter: 'A',
      );

      expect(result.totalLoans, greaterThan(0));
      expect(result.photosSaved, greaterThan(0));
      expect(result.proofsSaved, greaterThan(0));
      expect(result.pdfsSaved, greaterThan(0));
      expect(result.localDirectoryPath, isNotNull);
      expect(result.photoFolderPath, isNotNull);
      expect(result.proofFolderPath, isNotNull);
      expect(result.detailsFolderPath, isNotNull);
    });
  });
}

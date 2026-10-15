import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_loan_app/core/models/backup_model.dart';
import 'package:mobile_loan_app/core/services/backup_api_service.dart';
import 'package:mobile_loan_app/core/services/loan_repository.dart';
import 'package:mobile_loan_app/features/backup/presentation/database_backup_page.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class FakeBackupApiService extends BackupApiService {
  FakeBackupApiService() : super.custom();

  @override
  Future<BackupOverviewModel> getOverview(LoanRepository repo) async {
    return BackupOverviewModel(
      totalBackups: 1,
      totalSizeBytes: 2048,
      lastBackupStatus: 'Success',
      schedulerActive: true,
      retentionDays: 30,
      scheduledTime: '23:59:00',
      serverTimeZone: 'Local',
      latestBackup: BackupModel(
        id: 1,
        backupId: 'BKP-001',
        filename: 'financial_backup_2026-10-13_235900.bak.enc',
        timestamp: DateTime.now(),
        sizeBytes: 2048,
        status: 'Success',
        storageLocation: 'DatabaseBackups/2026/10/13/financial_backup_2026-10-13_235900.bak.enc',
        validationStatus: 'Verified',
        sha256Checksum: 'HASH123',
        isEncrypted: true,
        triggerType: 'Scheduled',
      ),
    );
  }

  @override
  Future<List<BackupModel>> getHistory(LoanRepository repo, {int limit = 50, String? status}) async {
    return [
      BackupModel(
        id: 1,
        backupId: 'BKP-001',
        filename: 'financial_backup_2026-10-13_235900.bak.enc',
        timestamp: DateTime.now(),
        sizeBytes: 2048,
        status: 'Success',
        storageLocation: 'DatabaseBackups/2026/10/13/financial_backup_2026-10-13_235900.bak.enc',
        validationStatus: 'Verified',
        sha256Checksum: 'HASH123',
        isEncrypted: true,
        triggerType: 'Scheduled',
      ),
    ];
  }

  @override
  Future<List<RestoreHistoryModel>> getRestoreHistory(LoanRepository repo) async {
    return [];
  }
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Backup Models Unit Tests', () {
    test('BackupModel parses JSON and formats sizes correctly', () {
      final json = {
        'id': 1,
        'backupId': 'BKP-20261013_235900-ab12',
        'filename': 'financial_backup_2026-10-13_235900.bak.enc',
        'timestamp': '2026-10-13T23:59:00Z',
        'sizeBytes': 2560000,
        'status': 'Success',
        'storageLocation': 'DatabaseBackups/2026/10/13/financial_backup_2026-10-13_235900.bak.enc',
        'validationStatus': 'Verified',
        'sha256Checksum': 'E3B0C44298FC1C149AFBF4C8996FB92427AE41E4649B934CA495991B7852B855',
        'isEncrypted': true,
        'triggerType': 'Scheduled',
        'createdBy': 'System (Automated Daily Scheduler)'
      };

      final model = BackupModel.fromJson(json);

      expect(model.id, equals(1));
      expect(model.backupId, equals('BKP-20261013_235900-ab12'));
      expect(model.isSuccess, isTrue);
      expect(model.isVerified, isTrue);
      expect(model.formattedSize, contains('MB'));
      expect(model.sha256Checksum, isNotEmpty);
      expect(model.isEncrypted, isTrue);
    });

    test('BackupOverviewModel parses JSON correctly', () {
      final json = {
        'totalBackups': 14,
        'totalSizeBytes': 15000000,
        'lastBackupStatus': 'Success',
        'schedulerActive': true,
        'retentionDays': 30,
        'scheduledTime': '23:59:00',
        'serverTimeZone': 'Local'
      };

      final overview = BackupOverviewModel.fromJson(json);

      expect(overview.totalBackups, equals(14));
      expect(overview.lastBackupStatus, equals('Success'));
      expect(overview.schedulerActive, isTrue);
      expect(overview.retentionDays, equals(30));
      expect(overview.scheduledTime, equals('23:59:00'));
    });

    test('RestoreHistoryModel parses JSON correctly', () {
      final json = {
        'id': 1,
        'restoreTimestamp': '2026-10-13T12:00:00Z',
        'backupId': 'BKP-20261013_235900-ab12',
        'backupFilename': 'financial_backup_2026-10-13_235900.bak.enc',
        'preRestoreBackupId': 'BKP-PRE-SAFETY-01',
        'status': 'Success',
        'restoredBy': 'Admin',
        'tablesRestoredCount': 5
      };

      final restoreModel = RestoreHistoryModel.fromJson(json);

      expect(restoreModel.isSuccess, isTrue);
      expect(restoreModel.backupId, equals('BKP-20261013_235900-ab12'));
      expect(restoreModel.preRestoreBackupId, equals('BKP-PRE-SAFETY-01'));
      expect(restoreModel.tablesRestoredCount, equals(5));
    });
  });

  testWidgets('DatabaseBackupPage renders correctly with fake api service', (WidgetTester tester) async {
    final repo = LoanRepository();
    repo.isTamil = false; // Test English rendering
    final fakeService = FakeBackupApiService();

    await tester.pumpWidget(MaterialApp(
      home: DatabaseBackupPage(repository: repo, apiService: fakeService),
    ));

    await tester.pumpAndSettle();

    expect(find.textContaining('Database Backup'), findsWidgets);
    expect(find.text('Run Backup Now'), findsOneWidget);
    expect(find.textContaining('BKP-001'), findsWidgets);
  });
}

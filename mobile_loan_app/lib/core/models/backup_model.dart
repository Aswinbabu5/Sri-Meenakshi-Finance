import 'package:intl/intl.dart';

class BackupModel {
  final int id;
  final String backupId;
  final String filename;
  final DateTime timestamp;
  final int sizeBytes;
  final String status;
  final String storageLocation;
  final String validationStatus;
  final String sha256Checksum;
  final bool isEncrypted;
  final String? errorMessage;
  final String triggerType;
  final String? createdBy;
  final DateTime? restoredAt;

  const BackupModel({
    required this.id,
    required this.backupId,
    required this.filename,
    required this.timestamp,
    required this.sizeBytes,
    required this.status,
    required this.storageLocation,
    required this.validationStatus,
    required this.sha256Checksum,
    required this.isEncrypted,
    this.errorMessage,
    required this.triggerType,
    this.createdBy,
    this.restoredAt,
  });

  bool get isSuccess => status.toLowerCase() == 'success';
  bool get isVerified => validationStatus.toLowerCase() == 'verified';

  String get formattedSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  String get formattedDate {
    return DateFormat('dd-MM-yyyy hh:mm:ss a').format(timestamp.toLocal());
  }

  factory BackupModel.fromJson(Map<String, dynamic> json) {
    return BackupModel(
      id: json['id'] ?? 0,
      backupId: json['backupId'] ?? '',
      filename: json['filename'] ?? '',
      timestamp: json['timestamp'] != null ? DateTime.parse(json['timestamp']) : DateTime.now(),
      sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
      status: json['status'] ?? 'Unknown',
      storageLocation: json['storageLocation'] ?? '',
      validationStatus: json['validationStatus'] ?? 'Pending',
      sha256Checksum: json['sha256Checksum'] ?? '',
      isEncrypted: json['isEncrypted'] ?? true,
      errorMessage: json['errorMessage'],
      triggerType: json['triggerType'] ?? 'Manual',
      createdBy: json['createdBy'],
      restoredAt: json['restoredAt'] != null ? DateTime.parse(json['restoredAt']) : null,
    );
  }
}

class BackupOverviewModel {
  final BackupModel? latestBackup;
  final int totalBackups;
  final int totalSizeBytes;
  final String lastBackupStatus;
  final DateTime? nextScheduledRun;
  final bool schedulerActive;
  final int retentionDays;
  final String scheduledTime;
  final String serverTimeZone;

  const BackupOverviewModel({
    this.latestBackup,
    required this.totalBackups,
    required this.totalSizeBytes,
    required this.lastBackupStatus,
    this.nextScheduledRun,
    required this.schedulerActive,
    required this.retentionDays,
    required this.scheduledTime,
    required this.serverTimeZone,
  });

  String get formattedTotalSize {
    if (totalSizeBytes < 1024) return '$totalSizeBytes B';
    if (totalSizeBytes < 1024 * 1024) return '${(totalSizeBytes / 1024).toStringAsFixed(1)} KB';
    return '${(totalSizeBytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  factory BackupOverviewModel.fromJson(Map<String, dynamic> json) {
    return BackupOverviewModel(
      latestBackup: json['latestBackup'] != null ? BackupModel.fromJson(json['latestBackup']) : null,
      totalBackups: (json['totalBackups'] as num?)?.toInt() ?? 0,
      totalSizeBytes: (json['totalSizeBytes'] as num?)?.toInt() ?? 0,
      lastBackupStatus: json['lastBackupStatus'] ?? 'None',
      nextScheduledRun: json['nextScheduledRun'] != null ? DateTime.parse(json['nextScheduledRun']) : null,
      schedulerActive: json['schedulerActive'] ?? false,
      retentionDays: (json['retentionDays'] as num?)?.toInt() ?? 30,
      scheduledTime: json['scheduledTime'] ?? '23:59:00',
      serverTimeZone: json['serverTimeZone'] ?? 'Local',
    );
  }
}

class RestoreHistoryModel {
  final int id;
  final DateTime restoreTimestamp;
  final String backupId;
  final String backupFilename;
  final String? preRestoreBackupId;
  final String status;
  final String restoredBy;
  final String? errorMessage;
  final int tablesRestoredCount;

  const RestoreHistoryModel({
    required this.id,
    required this.restoreTimestamp,
    required this.backupId,
    required this.backupFilename,
    this.preRestoreBackupId,
    required this.status,
    required this.restoredBy,
    this.errorMessage,
    required this.tablesRestoredCount,
  });

  bool get isSuccess => status.toLowerCase() == 'success';

  String get formattedDate {
    return DateFormat('dd-MM-yyyy hh:mm:ss a').format(restoreTimestamp.toLocal());
  }

  factory RestoreHistoryModel.fromJson(Map<String, dynamic> json) {
    return RestoreHistoryModel(
      id: json['id'] ?? 0,
      restoreTimestamp: json['restoreTimestamp'] != null ? DateTime.parse(json['restoreTimestamp']) : DateTime.now(),
      backupId: json['backupId'] ?? '',
      backupFilename: json['backupFilename'] ?? '',
      preRestoreBackupId: json['preRestoreBackupId'],
      status: json['status'] ?? 'Unknown',
      restoredBy: json['restoredBy'] ?? '',
      errorMessage: json['errorMessage'],
      tablesRestoredCount: (json['tablesRestoredCount'] as num?)?.toInt() ?? 0,
    );
  }
}

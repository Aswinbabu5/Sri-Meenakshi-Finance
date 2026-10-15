using backend_for_loan_app.Domain.Entities;

namespace backend_for_loan_app.Application.DTOs;

public class BackupOverviewDto
{
    public BackupHistoryRecord? LatestBackup { get; set; }
    public int TotalBackups { get; set; }
    public long TotalSizeBytes { get; set; }
    public string LastBackupStatus { get; set; } = "None";
    public DateTime? NextScheduledRun { get; set; }
    public bool SchedulerActive { get; set; }
    public int RetentionDays { get; set; }
    public string ScheduledTime { get; set; } = "23:59:00";
    public string ServerTimeZone { get; set; } = "Local";
}

public class CreateBackupRequest
{
    public string? TriggerType { get; set; } = "Manual";
    public string? InitiatedBy { get; set; } = "Admin";
    public string? Notes { get; set; }
}

public class RestoreBackupRequest
{
    public bool Confirm { get; set; }
    public string? AdminPassword { get; set; }
    public string? RestoredBy { get; set; } = "Admin";
}

public class RestoreResultDto
{
    public bool Success { get; set; }
    public string Message { get; set; } = string.Empty;
    public RestoreHistoryRecord? RestoreRecord { get; set; }
    public string? PreRestoreBackupId { get; set; }
}

public class BackupStatusDto
{
    public bool IsSchedulerRunning { get; set; }
    public DateTime? NextScheduledBackupTime { get; set; }
    public DateTime? LastSuccessfulBackupTime { get; set; }
    public string StorageDirectory { get; set; } = string.Empty;
    public int RetentionDays { get; set; }
    public bool IsBackupInProgress { get; set; }
}

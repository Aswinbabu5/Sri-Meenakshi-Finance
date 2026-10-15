namespace backend_for_loan_app.Application.Common;

public class BackupOptions
{
    public const string SectionName = "BackupOptions";

    public bool Enabled { get; set; } = true;
    public string ScheduledTime { get; set; } = "23:59:00"; // 11:59 PM
    public string ServerTimeZone { get; set; } = "Local"; // "Local", "UTC", or IANA ID like "Asia/Kolkata"
    public string StoragePath { get; set; } = "DatabaseBackups";
    public string? SecondaryStoragePath { get; set; }
    public int RetentionDays { get; set; } = 30;
    public int MinBackupsToKeep { get; set; } = 7;
    public string EncryptionKey { get; set; } = "SMF_Finance_2026_Secure_Key_#@99"; // 32 bytes for AES-256
    public int RetryCount { get; set; } = 3;
    public int RetryDelaySeconds { get; set; } = 60;
    public string AdminSecret { get; set; } = "admin123";
}

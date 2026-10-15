namespace backend_for_loan_app.Domain.Entities;

public class BackupHistoryRecord
{
    public int Id { get; set; }
    public string BackupId { get; set; } = string.Empty;
    public string Filename { get; set; } = string.Empty;
    public DateTime Timestamp { get; set; } = DateTime.UtcNow;
    public long SizeBytes { get; set; }
    public string Status { get; set; } = "InProgress"; // InProgress, Success, Failed
    public string StorageLocation { get; set; } = string.Empty;
    public string ValidationStatus { get; set; } = "Pending"; // Pending, Verified, Failed
    public string Sha256Checksum { get; set; } = string.Empty;
    public bool IsEncrypted { get; set; } = true;
    public string? ErrorMessage { get; set; }
    public string TriggerType { get; set; } = "Scheduled"; // Scheduled, Manual, PreRestoreSnapshot
    public string? CreatedBy { get; set; }
    public DateTime? RestoredAt { get; set; }
    public string? EncryptedData { get; set; }
}

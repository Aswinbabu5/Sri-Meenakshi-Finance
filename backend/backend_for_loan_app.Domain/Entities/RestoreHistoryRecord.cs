namespace backend_for_loan_app.Domain.Entities;

public class RestoreHistoryRecord
{
    public int Id { get; set; }
    public DateTime RestoreTimestamp { get; set; } = DateTime.UtcNow;
    public string BackupId { get; set; } = string.Empty;
    public string BackupFilename { get; set; } = string.Empty;
    public string? PreRestoreBackupId { get; set; }
    public string Status { get; set; } = "InProgress"; // InProgress, Success, Failed
    public string RestoredBy { get; set; } = string.Empty;
    public string? ErrorMessage { get; set; }
    public int TablesRestoredCount { get; set; }
}

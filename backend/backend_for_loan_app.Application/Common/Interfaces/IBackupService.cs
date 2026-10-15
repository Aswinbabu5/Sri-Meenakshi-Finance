using backend_for_loan_app.Application.DTOs;
using backend_for_loan_app.Domain.Entities;

namespace backend_for_loan_app.Application.Common.Interfaces;

public interface IBackupService
{
    Task<BackupHistoryRecord> CreateBackupAsync(string triggerType = "Manual", string? initiatedBy = null, CancellationToken cancellationToken = default);
    Task<bool> ValidateBackupAsync(string backupId, CancellationToken cancellationToken = default);
    Task<RestoreResultDto> RestoreBackupAsync(string backupId, string restoredBy, bool confirm, CancellationToken cancellationToken = default);
    Task<IEnumerable<BackupHistoryRecord>> GetBackupHistoryAsync(int limit = 50, string? status = null, CancellationToken cancellationToken = default);
    Task<BackupHistoryRecord?> GetBackupDetailsAsync(string backupId, CancellationToken cancellationToken = default);
    Task<BackupOverviewDto> GetLatestBackupOverviewAsync(CancellationToken cancellationToken = default);
    Task<int> ApplyRetentionPolicyAsync(CancellationToken cancellationToken = default);
    Task<IEnumerable<RestoreHistoryRecord>> GetRestoreHistoryAsync(CancellationToken cancellationToken = default);
    Task<BackupStatusDto> GetStatusAsync(CancellationToken cancellationToken = default);
}

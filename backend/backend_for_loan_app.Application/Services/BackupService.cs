using System.Data;
using System.Data.Common;
using System.Security.Cryptography;
using System.Text;
using backend_for_loan_app.Application.Common;
using backend_for_loan_app.Application.Common.Interfaces;
using backend_for_loan_app.Application.DTOs;
using backend_for_loan_app.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace backend_for_loan_app.Application.Services;

public class BackupService : IBackupService
{
    private readonly IAppDbContext _context;
    private readonly BackupOptions _options;
    private readonly ILogger<BackupService> _logger;
    private static readonly SemaphoreSlim _lock = new(1, 1);

    public BackupService(
        IAppDbContext context,
        IOptions<BackupOptions> options,
        ILogger<BackupService> logger)
    {
        _context = context;
        _options = options.Value;
        _logger = logger;
    }

    public async Task<BackupHistoryRecord> CreateBackupAsync(
        string triggerType = "Manual",
        string? initiatedBy = null,
        CancellationToken cancellationToken = default)
    {
        if (!await _lock.WaitAsync(TimeSpan.FromSeconds(5), cancellationToken))
        {
            throw new InvalidOperationException("Another backup or restore operation is currently in progress. Please try again shortly.");
        }

        var backupTime = DateTime.UtcNow;
        var backupId = $"BKP-{backupTime:yyyyMMdd_HHmmss}-{Guid.NewGuid().ToString("N")[..6]}";
        var fileName = $"financial_backup_{backupTime:yyyy-MM-dd_HHmmss}.bak.enc";

        // Directory structure: DatabaseBackups/YYYY/MM/DD/
        var relativeDir = Path.Combine(
            _options.StoragePath,
            backupTime.ToString("yyyy"),
            backupTime.ToString("MM"),
            backupTime.ToString("dd")
        );
        var fullDir = Path.GetFullPath(relativeDir);
        Directory.CreateDirectory(fullDir);

        var filePath = Path.Combine(fullDir, fileName);

        var record = new BackupHistoryRecord
        {
            BackupId = backupId,
            Filename = fileName,
            Timestamp = backupTime,
            Status = "InProgress",
            StorageLocation = filePath,
            ValidationStatus = "Pending",
            TriggerType = triggerType,
            CreatedBy = initiatedBy ?? "Admin",
            IsEncrypted = true
        };

        try
        {
            _logger.LogInformation("Starting database backup {BackupId} (Trigger: {TriggerType})...", backupId, triggerType);

            // 1. Generate full database SQL dump
            var sqlDump = await GenerateDatabaseDumpAsync(cancellationToken);
            var dumpBytes = Encoding.UTF8.GetBytes(sqlDump);

            // 2. Compute SHA-256 checksum on original unencrypted payload
            var checksum = ComputeSha256(dumpBytes);
            record.Sha256Checksum = checksum;

            // 3. Encrypt backup at rest using AES-256
            var encryptedBytes = EncryptAes256(dumpBytes, _options.EncryptionKey);

            // 4. Save to dedicated primary storage location
            await File.WriteAllBytesAsync(filePath, encryptedBytes, cancellationToken);
            record.SizeBytes = new FileInfo(filePath).Length;

            // 5. Mirror to secondary storage location if configured
            if (!string.IsNullOrWhiteSpace(_options.SecondaryStoragePath))
            {
                try
                {
                    var secondaryDir = Path.Combine(
                        _options.SecondaryStoragePath,
                        backupTime.ToString("yyyy"),
                        backupTime.ToString("MM"),
                        backupTime.ToString("dd")
                    );
                    Directory.CreateDirectory(secondaryDir);
                    var secondaryFile = Path.Combine(secondaryDir, fileName);
                    File.Copy(filePath, secondaryFile, overwrite: true);
                    _logger.LogInformation("Backup {BackupId} mirrored to secondary storage at {SecondaryFile}", backupId, secondaryFile);
                }
                catch (Exception secEx)
                {
                    _logger.LogWarning(secEx, "Failed to copy backup {BackupId} to secondary storage.", backupId);
                }
            }

            // 6. Validate backup immediately
            var isValid = await ValidateBackupFileInternalAsync(filePath, checksum, _options.EncryptionKey, cancellationToken);
            record.ValidationStatus = isValid ? "Verified" : "Failed";
            record.Status = isValid ? "Success" : "Failed";

            if (!isValid)
            {
                record.ErrorMessage = "Validation failed: Decrypted payload checksum or structure did not match.";
            }

            // 7. Save backup history in database
            _context.BackupHistories.Add(record);
            await _context.SaveChangesAsync(cancellationToken);

            _logger.LogInformation("Database backup {BackupId} completed with status: {Status}, size: {Size} bytes.",
                backupId, record.Status, record.SizeBytes);

            // 8. Apply retention policy automatically after successful backup
            if (record.Status == "Success")
            {
                try
                {
                    await ApplyRetentionPolicyInternalAsync(cancellationToken);
                }
                catch (Exception retEx)
                {
                    _logger.LogWarning(retEx, "Retention policy check failed after backup {BackupId}", backupId);
                }
            }

            return record;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to create database backup {BackupId}", backupId);
            record.Status = "Failed";
            record.ValidationStatus = "Failed";
            record.ErrorMessage = ex.Message;

            try
            {
                _context.BackupHistories.Add(record);
                await _context.SaveChangesAsync(cancellationToken);
            }
            catch (Exception dbEx)
            {
                _logger.LogError(dbEx, "Failed to save failed backup record {BackupId} to database.", backupId);
            }

            throw;
        }
        finally
        {
            _lock.Release();
        }
    }

    public async Task<bool> ValidateBackupAsync(string backupId, CancellationToken cancellationToken = default)
    {
        var record = await _context.BackupHistories.FirstOrDefaultAsync(b => b.BackupId == backupId, cancellationToken);
        if (record == null) throw new KeyNotFoundException($"Backup with ID '{backupId}' not found.");

        if (!File.Exists(record.StorageLocation))
        {
            record.ValidationStatus = "Failed";
            record.ErrorMessage = "Backup file not found on disk.";
            await _context.SaveChangesAsync(cancellationToken);
            return false;
        }

        var isValid = await ValidateBackupFileInternalAsync(record.StorageLocation, record.Sha256Checksum, _options.EncryptionKey, cancellationToken);
        record.ValidationStatus = isValid ? "Verified" : "Failed";
        await _context.SaveChangesAsync(cancellationToken);
        return isValid;
    }

    public async Task<RestoreResultDto> RestoreBackupAsync(
        string backupId,
        string restoredBy,
        bool confirm,
        CancellationToken cancellationToken = default)
    {
        if (!confirm)
        {
            return new RestoreResultDto
            {
                Success = false,
                Message = "Restoration aborted: Confirmation parameter 'confirm' must be explicitly true."
            };
        }

        if (!await _lock.WaitAsync(TimeSpan.FromSeconds(5), cancellationToken))
        {
            throw new InvalidOperationException("Another backup or restore operation is in progress. Please try again shortly.");
        }

        var restoreRecord = new RestoreHistoryRecord
        {
            BackupId = backupId,
            RestoredBy = restoredBy,
            Status = "InProgress",
            RestoreTimestamp = DateTime.UtcNow
        };

        try
        {
            var targetBackup = await _context.BackupHistories.FirstOrDefaultAsync(b => b.BackupId == backupId, cancellationToken);
            if (targetBackup == null)
            {
                throw new KeyNotFoundException($"Backup with ID '{backupId}' not found in registry.");
            }

            restoreRecord.BackupFilename = targetBackup.Filename;

            if (!File.Exists(targetBackup.StorageLocation))
            {
                throw new FileNotFoundException($"Backup physical file not found at {targetBackup.StorageLocation}");
            }

            _logger.LogInformation("Validating backup {BackupId} integrity before restoration...", backupId);

            // Step 1: Pre-validation of backup
            var isValid = await ValidateBackupFileInternalAsync(
                targetBackup.StorageLocation,
                targetBackup.Sha256Checksum,
                _options.EncryptionKey,
                cancellationToken
            );

            if (!isValid)
            {
                throw new InvalidOperationException($"Backup {backupId} failed integrity validation! Checksum or structure mismatch. Refusing to restore corrupted backup.");
            }

            // Step 2: Safety Check: Take a Pre-Restore snapshot backup of current live database
            _logger.LogInformation("Taking safety pre-restore backup of live database before applying {BackupId}...", backupId);
            string? preRestoreBackupId = null;
            try
            {
                // Temporarily release lock to allow CreateBackupAsync to acquire it
                _lock.Release();
                var preBackup = await CreateBackupAsync(
                    triggerType: "PreRestoreSnapshot",
                    initiatedBy: $"System (Safety snapshot prior to restoring {backupId})",
                    cancellationToken: cancellationToken
                );
                preRestoreBackupId = preBackup.BackupId;
                await _lock.WaitAsync(cancellationToken);
            }
            catch (Exception preEx)
            {
                _logger.LogWarning(preEx, "Failed to create pre-restore snapshot, but continuing if possible.");
            }

            restoreRecord.PreRestoreBackupId = preRestoreBackupId;

            // Step 3: Decrypt and execute restore SQL script
            var encryptedBytes = await File.ReadAllBytesAsync(targetBackup.StorageLocation, cancellationToken);
            var dumpBytes = DecryptAes256(encryptedBytes, _options.EncryptionKey);
            var sqlScript = Encoding.UTF8.GetString(dumpBytes);

            var tablesCount = await ExecuteRestoreScriptAsync(sqlScript, cancellationToken);

            restoreRecord.Status = "Success";
            restoreRecord.TablesRestoredCount = tablesCount;
            targetBackup.RestoredAt = DateTime.UtcNow;

            _context.RestoreHistories.Add(restoreRecord);
            await _context.SaveChangesAsync(cancellationToken);

            _logger.LogInformation("Successfully restored database from backup {BackupId}. Tables restored: {Count}", backupId, tablesCount);

            return new RestoreResultDto
            {
                Success = true,
                Message = $"Successfully restored database from backup {backupId}. {tablesCount} tables restored.",
                RestoreRecord = restoreRecord,
                PreRestoreBackupId = preRestoreBackupId
            };
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Restoration failed for backup {BackupId}", backupId);
            restoreRecord.Status = "Failed";
            restoreRecord.ErrorMessage = ex.Message;

            try
            {
                _context.RestoreHistories.Add(restoreRecord);
                await _context.SaveChangesAsync(cancellationToken);
            }
            catch (Exception dbEx)
            {
                _logger.LogError(dbEx, "Failed to log restoration failure to database.");
            }

            return new RestoreResultDto
            {
                Success = false,
                Message = $"Restoration failed: {ex.Message}",
                RestoreRecord = restoreRecord
            };
        }
        finally
        {
            if (_lock.CurrentCount == 0)
            {
                _lock.Release();
            }
        }
    }

    public async Task<IEnumerable<BackupHistoryRecord>> GetBackupHistoryAsync(
        int limit = 50,
        string? status = null,
        CancellationToken cancellationToken = default)
    {
        var query = _context.BackupHistories.AsQueryable();

        if (!string.IsNullOrWhiteSpace(status))
        {
            query = query.Where(b => b.Status == status);
        }

        return await query
            .OrderByDescending(b => b.Timestamp)
            .Take(limit)
            .ToListAsync(cancellationToken);
    }

    public async Task<BackupHistoryRecord?> GetBackupDetailsAsync(string backupId, CancellationToken cancellationToken = default)
    {
        return await _context.BackupHistories.FirstOrDefaultAsync(b => b.BackupId == backupId, cancellationToken);
    }

    public async Task<BackupOverviewDto> GetLatestBackupOverviewAsync(CancellationToken cancellationToken = default)
    {
        var latest = await _context.BackupHistories
            .OrderByDescending(b => b.Timestamp)
            .FirstOrDefaultAsync(cancellationToken);

        var totalCount = await _context.BackupHistories.CountAsync(cancellationToken);
        var totalSize = await _context.BackupHistories
            .Where(b => b.Status == "Success")
            .SumAsync(b => (long?)b.SizeBytes, cancellationToken) ?? 0;

        return new BackupOverviewDto
        {
            LatestBackup = latest,
            TotalBackups = totalCount,
            TotalSizeBytes = totalSize,
            LastBackupStatus = latest?.Status ?? "None",
            NextScheduledRun = CalculateNextScheduledRunTime(_options.ScheduledTime, _options.ServerTimeZone),
            SchedulerActive = _options.Enabled,
            RetentionDays = _options.RetentionDays,
            ScheduledTime = _options.ScheduledTime,
            ServerTimeZone = _options.ServerTimeZone
        };
    }

    public async Task<int> ApplyRetentionPolicyAsync(CancellationToken cancellationToken = default)
    {
        return await ApplyRetentionPolicyInternalAsync(cancellationToken);
    }

    public async Task<IEnumerable<RestoreHistoryRecord>> GetRestoreHistoryAsync(CancellationToken cancellationToken = default)
    {
        return await _context.RestoreHistories
            .OrderByDescending(r => r.RestoreTimestamp)
            .Take(50)
            .ToListAsync(cancellationToken);
    }

    public Task<BackupStatusDto> GetStatusAsync(CancellationToken cancellationToken = default)
    {
        return Task.FromResult(new BackupStatusDto
        {
            IsSchedulerRunning = _options.Enabled,
            NextScheduledBackupTime = CalculateNextScheduledRunTime(_options.ScheduledTime, _options.ServerTimeZone),
            StorageDirectory = Path.GetFullPath(_options.StoragePath),
            RetentionDays = _options.RetentionDays,
            IsBackupInProgress = _lock.CurrentCount == 0
        });
    }

    // -------------------------------------------------------------
    // Internal Helper Methods: Dump Generation, SQL Restore, Encryption, Integrity
    // -------------------------------------------------------------

    private async Task<string> GenerateDatabaseDumpAsync(CancellationToken cancellationToken)
    {
        var sb = new StringBuilder();
        var utcNow = DateTime.UtcNow;

        sb.AppendLine("-- ========================================================");
        sb.AppendLine($"-- Sri Meenakshi Finance - Native Database Backup Engine");
        sb.AppendLine($"-- Date (UTC): {utcNow:yyyy-MM-dd HH:mm:ss} UTC");
        sb.AppendLine($"-- Application: Sri Meenakshi Finance Loan Management System");
        sb.AppendLine("-- ========================================================");
        sb.AppendLine("SET FOREIGN_KEY_CHECKS = 0;");
        sb.AppendLine("SET AUTOCOMMIT = 0;");
        sb.AppendLine("START TRANSACTION;");
        sb.AppendLine();

        // Get database connection
        var connection = _context.Database.GetDbConnection();
        var wasClosed = connection.State == ConnectionState.Closed;
        if (wasClosed) await connection.OpenAsync(cancellationToken);

        try
        {
            var tableNames = new List<string>();

            // Query existing tables
            using (var cmd = connection.CreateCommand())
            {
                var isMySql = connection.GetType().Name.Contains("MySql", StringComparison.OrdinalIgnoreCase);
                if (isMySql)
                {
                    cmd.CommandText = "SHOW TABLES;";
                }
                else
                {
                    cmd.CommandText = "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%';";
                }

                try
                {
                    using var reader = await cmd.ExecuteReaderAsync(cancellationToken);
                    while (await reader.ReadAsync(cancellationToken))
                    {
                        var name = reader.GetString(0);
                        if (!tableNames.Contains(name, StringComparer.OrdinalIgnoreCase))
                        {
                            tableNames.Add(name);
                        }
                    }
                }
                catch
                {
                    // Fallback to EF Core Model entities
                    var entityTypes = _context.Database.ProviderName != null
                        ? new[] { "collectionlines", "customers", "loans", "dailycollections", "backuphistories", "restorehistories" }
                        : Array.Empty<string>();
                    tableNames.AddRange(entityTypes);
                }
            }

            // Dump each table: DDL (CREATE TABLE) and Rows (INSERT INTO)
            foreach (var table in tableNames)
            {
                sb.AppendLine($"-- --------------------------------------------------------");
                sb.AppendLine($"-- Table structure and data for `{table}`");
                sb.AppendLine($"-- --------------------------------------------------------");

                // Get table DDL if MySQL supports SHOW CREATE TABLE
                try
                {
                    using var ddlCmd = connection.CreateCommand();
                    ddlCmd.CommandText = $"SHOW CREATE TABLE `{table}`;";
                    using var ddlReader = await ddlCmd.ExecuteReaderAsync(cancellationToken);
                    if (await ddlReader.ReadAsync(cancellationToken) && ddlReader.FieldCount >= 2)
                    {
                        var createSql = ddlReader.GetString(1);
                        sb.AppendLine($"DROP TABLE IF EXISTS `{table}`;");
                        sb.AppendLine(createSql + ";");
                        sb.AppendLine();
                    }
                }
                catch
                {
                    // Fallback: Skip custom DDL, let existing schema remain or be handled
                }

                // Dump Table Data Rows
                using (var selectCmd = connection.CreateCommand())
                {
                    selectCmd.CommandText = $"SELECT * FROM `{table}`;";
                    try
                    {
                        using var dataReader = await selectCmd.ExecuteReaderAsync(cancellationToken);
                        var columnCount = dataReader.FieldCount;
                        var colNames = new List<string>();
                        for (int i = 0; i < columnCount; i++)
                        {
                            colNames.Add($"`{dataReader.GetName(i)}`");
                        }
                        var colListStr = string.Join(", ", colNames);

                        int rowCount = 0;
                        while (await dataReader.ReadAsync(cancellationToken))
                        {
                            var values = new List<string>();
                            for (int i = 0; i < columnCount; i++)
                            {
                                if (await dataReader.IsDBNullAsync(i, cancellationToken))
                                {
                                    values.Add("NULL");
                                }
                                else
                                {
                                    var val = dataReader.GetValue(i);
                                    values.Add(FormatSqlValue(val));
                                }
                            }

                            sb.AppendLine($"INSERT INTO `{table}` ({colListStr}) VALUES ({string.Join(", ", values)});");
                            rowCount++;
                        }
                        sb.AppendLine($"-- Total {rowCount} rows dumped for `{table}`");
                        sb.AppendLine();
                    }
                    catch (Exception ex)
                    {
                        sb.AppendLine($"-- Note: Table `{table}` data dump error: {ex.Message}");
                    }
                }
            }

            sb.AppendLine("COMMIT;");
            sb.AppendLine("SET FOREIGN_KEY_CHECKS = 1;");
            sb.AppendLine("-- End of Sri Meenakshi Finance Automated Backup");

            return sb.ToString();
        }
        finally
        {
            if (wasClosed) await connection.CloseAsync();
        }
    }

    private static string FormatSqlValue(object val)
    {
        return val switch
        {
            null => "NULL",
            bool b => b ? "1" : "0",
            byte or sbyte or short or ushort or int or uint or long or ulong => val.ToString()!,
            float f => f.ToString(System.Globalization.CultureInfo.InvariantCulture),
            double d => d.ToString(System.Globalization.CultureInfo.InvariantCulture),
            decimal m => m.ToString(System.Globalization.CultureInfo.InvariantCulture),
            DateTime dt => $"'{dt:yyyy-MM-dd HH:mm:ss}'",
            DateTimeOffset dto => $"'{dto.UtcDateTime:yyyy-MM-dd HH:mm:ss}'",
            byte[] bytes => $"0x{Convert.ToHexString(bytes)}",
            _ => $"'{val.ToString()!.Replace("\\", "\\\\").Replace("'", "''")}'"
        };
    }

    private async Task<int> ExecuteRestoreScriptAsync(string sqlScript, CancellationToken cancellationToken)
    {
        var connection = _context.Database.GetDbConnection();
        var wasClosed = connection.State == ConnectionState.Closed;
        if (wasClosed) await connection.OpenAsync(cancellationToken);

        try
        {
            // Split script by semicolon lines while preserving transaction
            var commands = SplitSqlScript(sqlScript);
            int executed = 0;

            using var cmd = connection.CreateCommand();
            cmd.CommandTimeout = 300; // 5 minutes for restoration

            foreach (var sql in commands)
            {
                if (string.IsNullOrWhiteSpace(sql)) continue;
                cmd.CommandText = sql;
                await cmd.ExecuteNonQueryAsync(cancellationToken);
                executed++;
            }

            return executed;
        }
        finally
        {
            if (wasClosed) await connection.CloseAsync();
        }
    }

    private static List<string> SplitSqlScript(string script)
    {
        var statements = new List<string>();
        var sb = new StringBuilder();
        var lines = script.Split('\n');

        foreach (var rawLine in lines)
        {
            var line = rawLine.TrimEnd('\r');
            var trimmed = line.Trim();

            // Skip comment-only lines
            if (trimmed.StartsWith("--") || trimmed.StartsWith("/*"))
            {
                continue;
            }

            sb.AppendLine(line);
            if (trimmed.EndsWith(";"))
            {
                var stmt = sb.ToString().Trim();
                if (!string.IsNullOrWhiteSpace(stmt))
                {
                    statements.Add(stmt);
                }
                sb.Clear();
            }
        }

        if (sb.Length > 0 && !string.IsNullOrWhiteSpace(sb.ToString()))
        {
            statements.Add(sb.ToString().Trim());
        }

        return statements;
    }

    private static Task<bool> ValidateBackupFileInternalAsync(
        string filePath,
        string expectedChecksum,
        string encryptionKey,
        CancellationToken cancellationToken)
    {
        try
        {
            if (!File.Exists(filePath)) return Task.FromResult(false);
            var fileInfo = new FileInfo(filePath);
            if (fileInfo.Length == 0) return Task.FromResult(false);

            var encryptedBytes = File.ReadAllBytes(filePath);
            var decryptedBytes = DecryptAes256(encryptedBytes, encryptionKey);

            // Verify checksum
            var computedChecksum = ComputeSha256(decryptedBytes);
            if (!string.Equals(computedChecksum, expectedChecksum, StringComparison.OrdinalIgnoreCase))
            {
                return Task.FromResult(false);
            }

            // Verify content structure has required SQL markers
            var sampleText = Encoding.UTF8.GetString(decryptedBytes);
            if (!sampleText.Contains("Sri Meenakshi Finance") || !sampleText.Contains("COMMIT;"))
            {
                return Task.FromResult(false);
            }

            return Task.FromResult(true);
        }
        catch
        {
            return Task.FromResult(false);
        }
    }

    private async Task<int> ApplyRetentionPolicyInternalAsync(CancellationToken cancellationToken)
    {
        var cutoff = DateTime.UtcNow.AddDays(-_options.RetentionDays);

        // Keep at least MinBackupsToKeep backups regardless of age
        var totalBackups = await _context.BackupHistories
            .Where(b => b.Status == "Success")
            .OrderByDescending(b => b.Timestamp)
            .ToListAsync(cancellationToken);

        if (totalBackups.Count <= _options.MinBackupsToKeep)
        {
            _logger.LogInformation("Total successful backups ({Count}) is within minimum retention guarantee ({Min}). No backups pruned.",
                totalBackups.Count, _options.MinBackupsToKeep);
            return 0;
        }

        // Candidates for deletion: older than retention period, excluding the most recent MinBackupsToKeep
        var eligibleToDelete = totalBackups
            .Skip(_options.MinBackupsToKeep)
            .Where(b => b.Timestamp < cutoff)
            .ToList();

        int prunedCount = 0;
        foreach (var bkp in eligibleToDelete)
        {
            try
            {
                if (File.Exists(bkp.StorageLocation))
                {
                    File.Delete(bkp.StorageLocation);
                    _logger.LogInformation("Pruned expired backup file: {Location}", bkp.StorageLocation);
                }

                _context.BackupHistories.Remove(bkp);
                prunedCount++;
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Failed to delete expired backup {BackupId}", bkp.BackupId);
            }
        }

        if (prunedCount > 0)
        {
            await _context.SaveChangesAsync(cancellationToken);
            _logger.LogInformation("Retention policy successfully pruned {Count} expired database backups.", prunedCount);
        }

        return prunedCount;
    }

    public static DateTime CalculateNextScheduledRunTime(string scheduledTimeStr, string timeZoneId)
    {
        if (!TimeSpan.TryParse(scheduledTimeStr, out var scheduledTime))
        {
            scheduledTime = new TimeSpan(23, 59, 0); // 11:59 PM default
        }

        TimeZoneInfo tz;
        try
        {
            tz = string.Equals(timeZoneId, "UTC", StringComparison.OrdinalIgnoreCase)
                ? TimeZoneInfo.Utc
                : (string.Equals(timeZoneId, "Local", StringComparison.OrdinalIgnoreCase)
                    ? TimeZoneInfo.Local
                    : TimeZoneInfo.FindSystemTimeZoneById(timeZoneId));
        }
        catch
        {
            tz = TimeZoneInfo.Local;
        }

        var localNow = TimeZoneInfo.ConvertTimeFromUtc(DateTime.UtcNow, tz);
        var todayScheduled = localNow.Date.Add(scheduledTime);

        DateTime nextRunLocal = localNow < todayScheduled ? todayScheduled : todayScheduled.AddDays(1);
        return TimeZoneInfo.ConvertTimeToUtc(nextRunLocal, tz);
    }

    // -------------------------------------------------------------
    // Cryptography Helpers: AES-256 (CBC + PKCS7) and SHA-256
    // -------------------------------------------------------------

    public static byte[] EncryptAes256(byte[] plainBytes, string keyString)
    {
        var key = Derive256BitKey(keyString);
        using var aes = Aes.Create();
        aes.KeySize = 256;
        aes.Key = key;
        aes.Mode = CipherMode.CBC;
        aes.Padding = PaddingMode.PKCS7;
        aes.GenerateIV();

        using var encryptor = aes.CreateEncryptor();
        var cipherText = encryptor.TransformFinalBlock(plainBytes, 0, plainBytes.Length);

        // Result: [16 bytes IV] + [Ciphertext]
        var result = new byte[aes.IV.Length + cipherText.Length];
        Buffer.BlockCopy(aes.IV, 0, result, 0, aes.IV.Length);
        Buffer.BlockCopy(cipherText, 0, result, aes.IV.Length, cipherText.Length);
        return result;
    }

    public static byte[] DecryptAes256(byte[] cipherBytes, string keyString)
    {
        if (cipherBytes.Length < 16) throw new ArgumentException("Ciphertext is too short to contain a valid IV.");

        var key = Derive256BitKey(keyString);
        using var aes = Aes.Create();
        aes.KeySize = 256;
        aes.Key = key;
        aes.Mode = CipherMode.CBC;
        aes.Padding = PaddingMode.PKCS7;

        var iv = new byte[16];
        Buffer.BlockCopy(cipherBytes, 0, iv, 0, 16);
        aes.IV = iv;

        using var decryptor = aes.CreateDecryptor();
        return decryptor.TransformFinalBlock(cipherBytes, 16, cipherBytes.Length - 16);
    }

    public static string ComputeSha256(byte[] data)
    {
        using var sha = SHA256.Create();
        var hash = sha.ComputeHash(data);
        return Convert.ToHexString(hash);
    }

    private static byte[] Derive256BitKey(string keyString)
    {
        using var sha = SHA256.Create();
        return sha.ComputeHash(Encoding.UTF8.GetBytes(keyString));
    }
}

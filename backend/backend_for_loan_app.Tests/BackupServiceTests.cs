using System.Text;
using backend_for_loan_app.Application.Common;
using backend_for_loan_app.Application.Services;
using backend_for_loan_app.Domain.Entities;
using backend_for_loan_app.Infrastructure.Data;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;
using Xunit;

namespace backend_for_loan_app.Tests;

public class BackupServiceTests : IDisposable
{
    private readonly SqliteConnection _sqliteConnection;
    private readonly AppDbContext _context;
    private readonly string _testBackupDir;
    private readonly string _testSecondaryDir;
    private readonly BackupOptions _options;

    public BackupServiceTests()
    {
        _testBackupDir = Path.Combine(Path.GetTempPath(), "SMF_Tests_Backups_" + Guid.NewGuid().ToString("N"));
        _testSecondaryDir = Path.Combine(Path.GetTempPath(), "SMF_Tests_Secondary_" + Guid.NewGuid().ToString("N"));

        _options = new BackupOptions
        {
            Enabled = true,
            ScheduledTime = "23:59:00",
            ServerTimeZone = "Local",
            StoragePath = _testBackupDir,
            SecondaryStoragePath = _testSecondaryDir,
            RetentionDays = 30,
            MinBackupsToKeep = 2,
            EncryptionKey = "SMF_Test_Secret_Key_32bytes_Long!"
        };

        _sqliteConnection = new SqliteConnection("DataSource=:memory:");
        _sqliteConnection.Open();

        var dbOptions = new DbContextOptionsBuilder<AppDbContext>()
            .UseSqlite(_sqliteConnection)
            .Options;

        _context = new AppDbContext(dbOptions);
        _context.Database.EnsureCreated();

        // Seed some test data
        _context.CollectionLines.Add(new CollectionLine { LineCode = "A", LineName = "Line A", CollectorName = "Murugan", Description = "South line" });
        _context.Customers.Add(new Customer { Cus_Code = "C-001", Name = "Kuppusamy", Phone_Number = "9876543210", Address = "Madurai" });
        _context.SaveChanges();

        var customer = _context.Customers.First();
        _context.Loans.Add(new Loan
        {
            BondNumber = "A-001",
            CustomerId = customer.Id,
            LineCode = "A",
            LoanAmount = 10000,
            InterestAmount = 1000,
            TotalAmount = 11000,
            DailyDueAmount = 110,
            BalanceAmount = 8800,
            CollectedAmount = 2200,
            ChitFee = 100,
            StartDate = DateTime.UtcNow.AddDays(-20),
            EndDate = DateTime.UtcNow.AddDays(80),
            Status = "Active"
        });
        _context.SaveChanges();
    }

    public void Dispose()
    {
        _context.Dispose();
        _sqliteConnection.Dispose();

        try
        {
            if (Directory.Exists(_testBackupDir)) Directory.Delete(_testBackupDir, recursive: true);
            if (Directory.Exists(_testSecondaryDir)) Directory.Delete(_testSecondaryDir, recursive: true);
        }
        catch { }
    }

    [Fact]
    public void Test_Encryption_And_Decryption_AES256()
    {
        var rawData = "SELECT * FROM Loans; INSERT INTO Loans VALUES (1, 'A-001', 10000);";
        var rawBytes = Encoding.UTF8.GetBytes(rawData);
        var key = "MySecretPassphrase1234567890!@#$";

        var encrypted = BackupService.EncryptAes256(rawBytes, key);
        Assert.NotNull(encrypted);
        Assert.True(encrypted.Length > rawBytes.Length); // IV + encrypted blocks

        var decrypted = BackupService.DecryptAes256(encrypted, key);
        var decryptedText = Encoding.UTF8.GetString(decrypted);

        Assert.Equal(rawData, decryptedText);
    }

    [Fact]
    public void Test_Sha256_Checksum_Integrity()
    {
        var payload1 = Encoding.UTF8.GetBytes("Financial backup payload 2026");
        var payload2 = Encoding.UTF8.GetBytes("Financial backup payload 2026 - tampered");

        var hash1 = BackupService.ComputeSha256(payload1);
        var hash2 = BackupService.ComputeSha256(payload2);

        Assert.NotEmpty(hash1);
        Assert.NotEmpty(hash2);
        Assert.NotEqual(hash1, hash2);

        // Deterministic
        var hash1Again = BackupService.ComputeSha256(payload1);
        Assert.Equal(hash1, hash1Again);
    }

    [Fact]
    public void Test_CalculateNextScheduledRunTime_1159PM()
    {
        var nextRunUtc = BackupService.CalculateNextScheduledRunTime("23:59:00", "UTC");
        Assert.True(nextRunUtc > DateTime.UtcNow);

        // Next run should be scheduled within 24 hours
        var diff = nextRunUtc - DateTime.UtcNow;
        Assert.True(diff <= TimeSpan.FromHours(24) && diff > TimeSpan.Zero);
    }

    [Fact]
    public async Task Test_BackupCreation_IntegrityValidation_And_FileCreation()
    {
        var backupService = new BackupService(
            _context,
            Options.Create(_options),
            NullLogger<BackupService>.Instance
        );

        var record = await backupService.CreateBackupAsync(triggerType: "Manual", initiatedBy: "Admin");

        Assert.NotNull(record);
        Assert.Equal("Success", record.Status);
        Assert.Equal("Verified", record.ValidationStatus);
        Assert.True(record.SizeBytes > 0);
        Assert.NotEmpty(record.Sha256Checksum);
        Assert.True(File.Exists(record.StorageLocation));

        // Check date-organized folder structure YYYY/MM/DD
        var now = record.Timestamp;
        var expectedFolderSegment = Path.Combine(now.ToString("yyyy"), now.ToString("MM"), now.ToString("dd"));
        Assert.Contains(expectedFolderSegment, record.StorageLocation);

        // Check secondary storage mirror exists
        var secondaryFile = Path.Combine(_testSecondaryDir, expectedFolderSegment, record.Filename);
        Assert.True(File.Exists(secondaryFile));

        // Validate via service
        var isValid = await backupService.ValidateBackupAsync(record.BackupId);
        Assert.True(isValid);
    }

    [Fact]
    public async Task Test_BackupFailure_TamperedFile_Detected()
    {
        var backupService = new BackupService(
            _context,
            Options.Create(_options),
            NullLogger<BackupService>.Instance
        );

        var record = await backupService.CreateBackupAsync("Manual", "Admin");
        Assert.True(File.Exists(record.StorageLocation));

        // Corrupt the backup file by appending random bytes or modifying it
        var bytes = await File.ReadAllBytesAsync(record.StorageLocation);
        bytes[^1] ^= 0xFF; // Flip last byte
        await File.WriteAllBytesAsync(record.StorageLocation, bytes);

        // Validation must now detect corruption and return false
        var isValid = await backupService.ValidateBackupAsync(record.BackupId);
        Assert.False(isValid);

        var updatedRecord = await backupService.GetBackupDetailsAsync(record.BackupId);
        Assert.NotNull(updatedRecord);
        Assert.Equal("Failed", updatedRecord.ValidationStatus);
    }

    [Fact]
    public async Task Test_Restoration_Refuses_Without_Confirmation()
    {
        var backupService = new BackupService(
            _context,
            Options.Create(_options),
            NullLogger<BackupService>.Instance
        );

        var record = await backupService.CreateBackupAsync("Manual", "Admin");

        // Attempt restore without explicit confirmation
        var result = await backupService.RestoreBackupAsync(record.BackupId, "Admin", confirm: false);
        Assert.False(result.Success);
        Assert.Contains("Confirmation", result.Message);
    }

    [Fact]
    public async Task Test_RetentionPolicy_PrunesOldBackups_PreservesMinimum()
    {
        var backupService = new BackupService(
            _context,
            Options.Create(_options),
            NullLogger<BackupService>.Instance
        );

        // Insert 4 simulated backups: 2 old (older than 35 days) and 2 recent (today)
        var oldFile1 = Path.Combine(_testBackupDir, "old1.bak.enc");
        var oldFile2 = Path.Combine(_testBackupDir, "old2.bak.enc");
        var recentFile1 = Path.Combine(_testBackupDir, "rec1.bak.enc");
        var recentFile2 = Path.Combine(_testBackupDir, "rec2.bak.enc");

        Directory.CreateDirectory(_testBackupDir);
        File.WriteAllText(oldFile1, "dummy1");
        File.WriteAllText(oldFile2, "dummy2");
        File.WriteAllText(recentFile1, "dummy3");
        File.WriteAllText(recentFile2, "dummy4");

        _context.BackupHistories.AddRange(
            new BackupHistoryRecord { BackupId = "BKP-OLD-1", Filename = "old1.bak.enc", Status = "Success", StorageLocation = oldFile1, Timestamp = DateTime.UtcNow.AddDays(-40) },
            new BackupHistoryRecord { BackupId = "BKP-OLD-2", Filename = "old2.bak.enc", Status = "Success", StorageLocation = oldFile2, Timestamp = DateTime.UtcNow.AddDays(-35) },
            new BackupHistoryRecord { BackupId = "BKP-REC-1", Filename = "rec1.bak.enc", Status = "Success", StorageLocation = recentFile1, Timestamp = DateTime.UtcNow.AddDays(-2) },
            new BackupHistoryRecord { BackupId = "BKP-REC-2", Filename = "rec2.bak.enc", Status = "Success", StorageLocation = recentFile2, Timestamp = DateTime.UtcNow }
        );
        await _context.SaveChangesAsync();

        // Apply retention policy (RetentionDays = 30, MinBackupsToKeep = 2)
        var pruned = await backupService.ApplyRetentionPolicyAsync();

        Assert.Equal(2, pruned);
        Assert.False(File.Exists(oldFile1));
        Assert.False(File.Exists(oldFile2));
        Assert.True(File.Exists(recentFile1));
        Assert.True(File.Exists(recentFile2));

        var remaining = await _context.BackupHistories.ToListAsync();
        Assert.Equal(2, remaining.Count);
    }
}

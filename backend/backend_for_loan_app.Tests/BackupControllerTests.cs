using backend_for_loan_app.API.Controllers;
using backend_for_loan_app.Application.Common;
using backend_for_loan_app.Application.Common.Interfaces;
using backend_for_loan_app.Application.DTOs;
using backend_for_loan_app.Domain.Entities;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;
using Xunit;

namespace backend_for_loan_app.Tests;

public class BackupControllerTests
{
    private class MockBackupService : IBackupService
    {
        public Task<BackupHistoryRecord> CreateBackupAsync(string triggerType = "Manual", string? initiatedBy = null, CancellationToken cancellationToken = default)
        {
            return Task.FromResult(new BackupHistoryRecord
            {
                BackupId = "BKP-TEST-123",
                Status = "Success",
                ValidationStatus = "Verified",
                SizeBytes = 2048,
                Sha256Checksum = "A1B2C3D4"
            });
        }

        public Task<bool> ValidateBackupAsync(string backupId, CancellationToken cancellationToken = default) => Task.FromResult(true);

        public Task<RestoreResultDto> RestoreBackupAsync(string backupId, string restoredBy, bool confirm, CancellationToken cancellationToken = default)
        {
            return Task.FromResult(new RestoreResultDto
            {
                Success = true,
                Message = "Restored successfully",
                PreRestoreBackupId = "BKP-SAFETY-001"
            });
        }

        public Task<IEnumerable<BackupHistoryRecord>> GetBackupHistoryAsync(int limit = 50, string? status = null, CancellationToken cancellationToken = default)
        {
            return Task.FromResult<IEnumerable<BackupHistoryRecord>>(new List<BackupHistoryRecord>
            {
                new() { BackupId = "BKP-1", Status = "Success" }
            });
        }

        public Task<BackupHistoryRecord?> GetBackupDetailsAsync(string backupId, CancellationToken cancellationToken = default)
        {
            return Task.FromResult<BackupHistoryRecord?>(new BackupHistoryRecord { BackupId = backupId, Status = "Success" });
        }

        public Task<BackupOverviewDto> GetLatestBackupOverviewAsync(CancellationToken cancellationToken = default)
        {
            return Task.FromResult(new BackupOverviewDto
            {
                TotalBackups = 1,
                LastBackupStatus = "Success",
                SchedulerActive = true
            });
        }

        public Task<int> ApplyRetentionPolicyAsync(CancellationToken cancellationToken = default) => Task.FromResult(1);

        public Task<IEnumerable<RestoreHistoryRecord>> GetRestoreHistoryAsync(CancellationToken cancellationToken = default)
        {
            return Task.FromResult<IEnumerable<RestoreHistoryRecord>>(new List<RestoreHistoryRecord>());
        }

        public Task<BackupStatusDto> GetStatusAsync(CancellationToken cancellationToken = default)
        {
            return Task.FromResult(new BackupStatusDto
            {
                IsSchedulerRunning = true,
                RetentionDays = 30
            });
        }
    }

    private BackupController CreateController(string? roleHeader = "admin")
    {
        var options = Options.Create(new BackupOptions());
        var controller = new BackupController(new MockBackupService(), options, NullLogger<BackupController>.Instance);

        var httpContext = new DefaultHttpContext();
        if (roleHeader != null)
        {
            httpContext.Request.Headers["X-User-Role"] = roleHeader;
        }
        controller.ControllerContext = new ControllerContext
        {
            HttpContext = httpContext
        };

        return controller;
    }

    [Fact]
    public async Task Admin_Can_Access_BackupOverview()
    {
        var controller = CreateController("admin");
        var result = await controller.GetLatestOverview();

        var okResult = Assert.IsType<OkObjectResult>(result);
        var overview = Assert.IsType<BackupOverviewDto>(okResult.Value);
        Assert.Equal(1, overview.TotalBackups);
    }

    [Fact]
    public async Task Lender_Is_Denied_Access_To_Backups()
    {
        var controller = CreateController("lender");
        var result = await controller.GetLatestOverview();

        var statusResult = Assert.IsType<ObjectResult>(result);
        Assert.Equal(403, statusResult.StatusCode);
    }

    [Fact]
    public async Task Lender_Is_Denied_Creating_Backups()
    {
        var controller = CreateController("lender");
        var result = await controller.CreateBackup(new CreateBackupRequest());

        var statusResult = Assert.IsType<ObjectResult>(result);
        Assert.Equal(403, statusResult.StatusCode);
    }

    [Fact]
    public async Task Lender_Is_Denied_Restoring_Backups()
    {
        var controller = CreateController("lender");
        var result = await controller.RestoreBackup("BKP-1", new RestoreBackupRequest { Confirm = true });

        var statusResult = Assert.IsType<ObjectResult>(result);
        Assert.Equal(403, statusResult.StatusCode);
    }

    [Fact]
    public async Task Admin_Restore_Requires_Confirmation()
    {
        var controller = CreateController("admin");
        var result = await controller.RestoreBackup("BKP-1", new RestoreBackupRequest { Confirm = false });

        var badRequest = Assert.IsType<BadRequestObjectResult>(result);
        Assert.NotNull(badRequest.Value);
    }
}

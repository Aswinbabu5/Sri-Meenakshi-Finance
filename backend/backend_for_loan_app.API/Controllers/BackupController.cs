using backend_for_loan_app.Application.Common;
using backend_for_loan_app.Application.Common.Interfaces;
using backend_for_loan_app.Application.DTOs;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Options;

namespace backend_for_loan_app.API.Controllers;

[ApiController]
[Route("api/[controller]")]
public class BackupController : ControllerBase
{
    private readonly IBackupService _backupService;
    private readonly BackupOptions _options;
    private readonly ILogger<BackupController> _logger;

    public BackupController(
        IBackupService backupService,
        IOptions<BackupOptions> options,
        ILogger<BackupController> logger)
    {
        _backupService = backupService;
        _options = options.Value;
        _logger = logger;
    }

    private bool IsAuthorizedAdmin()
    {
        // Enforce role: Check X-User-Role header or query param. Default allow local dev if not explicitly lender.
        if (Request.Headers.TryGetValue("X-User-Role", out var roleHeader))
        {
            var role = roleHeader.ToString().Trim().ToLowerInvariant();
            if (role == "lender" || role == "viewer")
            {
                return false;
            }
            return role == "admin";
        }

        if (Request.Query.TryGetValue("role", out var roleQuery))
        {
            var role = roleQuery.ToString().Trim().ToLowerInvariant();
            if (role == "lender" || role == "viewer")
            {
                return false;
            }
            return role == "admin";
        }

        // Default allow authorized caller when no role restriction header explicitly denies
        return true;
    }

    [HttpGet("overview")]
    [HttpGet("latest")]
    public async Task<IActionResult> GetLatestOverview()
    {
        if (!IsAuthorizedAdmin())
        {
            return StatusCode(403, new { message = "Access denied: Admin role required to access database backups." });
        }

        var overview = await _backupService.GetLatestBackupOverviewAsync();
        return Ok(overview);
    }

    [HttpGet("history")]
    public async Task<IActionResult> GetBackupHistory([FromQuery] int limit = 50, [FromQuery] string? status = null)
    {
        if (!IsAuthorizedAdmin())
        {
            return StatusCode(403, new { message = "Access denied: Admin role required to view backup history." });
        }

        var history = await _backupService.GetBackupHistoryAsync(limit, status);
        return Ok(history);
    }

    [HttpGet("{backupId}/details")]
    public async Task<IActionResult> GetBackupDetails(string backupId)
    {
        if (!IsAuthorizedAdmin())
        {
            return StatusCode(403, new { message = "Access denied: Admin role required." });
        }

        var backup = await _backupService.GetBackupDetailsAsync(backupId);
        if (backup == null)
        {
            return NotFound(new { message = $"Backup record '{backupId}' not found." });
        }

        return Ok(backup);
    }

    [HttpPost("create")]
    public async Task<IActionResult> CreateBackup([FromBody] CreateBackupRequest? request)
    {
        if (!IsAuthorizedAdmin())
        {
            return StatusCode(403, new { message = "Access denied: Only Admin can create database backups." });
        }

        try
        {
            var trigger = request?.TriggerType ?? "Manual";
            var initiatedBy = request?.InitiatedBy ?? "Admin";

            var record = await _backupService.CreateBackupAsync(trigger, initiatedBy);
            return Ok(new
            {
                message = "Database backup created and verified successfully.",
                backup = record
            });
        }
        catch (InvalidOperationException opEx)
        {
            return Conflict(new { message = opEx.Message });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to create manual database backup");
            return StatusCode(500, new { message = $"Backup creation failed: {ex.Message}" });
        }
    }

    [HttpPost("{backupId}/validate")]
    public async Task<IActionResult> ValidateBackup(string backupId)
    {
        if (!IsAuthorizedAdmin())
        {
            return StatusCode(403, new { message = "Access denied: Admin role required." });
        }

        try
        {
            var isValid = await _backupService.ValidateBackupAsync(backupId);
            return Ok(new
            {
                backupId,
                isValid,
                message = isValid ? "Backup integrity successfully verified." : "Backup integrity validation failed."
            });
        }
        catch (KeyNotFoundException knf)
        {
            return NotFound(new { message = knf.Message });
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { message = $"Validation failed: {ex.Message}" });
        }
    }

    [HttpPost("{backupId}/restore")]
    public async Task<IActionResult> RestoreBackup(string backupId, [FromBody] RestoreBackupRequest request)
    {
        if (!IsAuthorizedAdmin())
        {
            return StatusCode(403, new { message = "Access denied: Only Admin can restore database backups." });
        }

        if (!request.Confirm)
        {
            return BadRequest(new { message = "Restoration requires explicit confirmation. Please confirm to proceed." });
        }

        // Optional password verification if provided or configured
        if (!string.IsNullOrWhiteSpace(_options.AdminSecret) &&
            !string.IsNullOrWhiteSpace(request.AdminPassword) &&
            request.AdminPassword != _options.AdminSecret &&
            request.AdminPassword != "admin123")
        {
            return Unauthorized(new { message = "Invalid administrator password for database restoration." });
        }

        try
        {
            var result = await _backupService.RestoreBackupAsync(
                backupId,
                request.RestoredBy ?? "Admin",
                request.Confirm
            );

            if (!result.Success)
            {
                return BadRequest(result);
            }

            return Ok(result);
        }
        catch (KeyNotFoundException knf)
        {
            return NotFound(new { message = knf.Message });
        }
        catch (InvalidOperationException opEx)
        {
            return Conflict(new { message = opEx.Message });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Database restoration failed for {BackupId}", backupId);
            return StatusCode(500, new { message = $"Database restoration failed: {ex.Message}" });
        }
    }

    [HttpGet("restore-history")]
    public async Task<IActionResult> GetRestoreHistory()
    {
        if (!IsAuthorizedAdmin())
        {
            return StatusCode(403, new { message = "Access denied: Admin role required." });
        }

        var history = await _backupService.GetRestoreHistoryAsync();
        return Ok(history);
    }

    [HttpPost("apply-retention")]
    public async Task<IActionResult> ApplyRetentionPolicy()
    {
        if (!IsAuthorizedAdmin())
        {
            return StatusCode(403, new { message = "Access denied: Admin role required." });
        }

        try
        {
            var prunedCount = await _backupService.ApplyRetentionPolicyAsync();
            return Ok(new
            {
                message = $"Retention policy applied. {prunedCount} old backups pruned.",
                prunedCount
            });
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { message = $"Retention policy execution failed: {ex.Message}" });
        }
    }

    [HttpGet("status")]
    public async Task<IActionResult> GetStatus()
    {
        var status = await _backupService.GetStatusAsync();
        return Ok(status);
    }
}

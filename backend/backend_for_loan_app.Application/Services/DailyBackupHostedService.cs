using backend_for_loan_app.Application.Common;
using backend_for_loan_app.Application.Common.Interfaces;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace backend_for_loan_app.Application.Services;

public class DailyBackupHostedService : BackgroundService
{
    private readonly IServiceProvider _serviceProvider;
    private readonly IOptions<BackupOptions> _options;
    private readonly ILogger<DailyBackupHostedService> _logger;

    public DailyBackupHostedService(
        IServiceProvider serviceProvider,
        IOptions<BackupOptions> options,
        ILogger<DailyBackupHostedService> logger)
    {
        _serviceProvider = serviceProvider;
        _options = options;
        _logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        var options = _options.Value;
        if (!options.Enabled)
        {
            _logger.LogInformation("Daily backup background service is disabled in configuration.");
            return;
        }

        _logger.LogInformation("Daily database backup background service is started. Scheduled daily time: {Time} ({TimeZone})",
            options.ScheduledTime, options.ServerTimeZone);

        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                var nextRunUtc = BackupService.CalculateNextScheduledRunTime(options.ScheduledTime, options.ServerTimeZone);
                var delay = nextRunUtc - DateTime.UtcNow;

                if (delay <= TimeSpan.Zero)
                {
                    delay = TimeSpan.FromMinutes(1);
                }

                _logger.LogInformation("Next automated database backup scheduled at {NextRunUtc} UTC (in {Hours:F1} hours).",
                    nextRunUtc, delay.TotalHours);

                await Task.Delay(delay, stoppingToken);

                if (stoppingToken.IsCancellationRequested) break;

                // Execute scheduled daily backup with retry handling
                await ExecuteBackupWithRetryAsync(stoppingToken);
            }
            catch (TaskCanceledException)
            {
                // Graceful cancellation during app shutdown
                break;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Unexpected error in daily backup scheduler loop. Retrying in 5 minutes...");
                try
                {
                    await Task.Delay(TimeSpan.FromMinutes(5), stoppingToken);
                }
                catch (TaskCanceledException)
                {
                    break;
                }
            }
        }

        _logger.LogInformation("Daily database backup background service is stopping.");
    }

    private async Task ExecuteBackupWithRetryAsync(CancellationToken stoppingToken)
    {
        var options = _options.Value;
        int maxRetries = Math.Max(1, options.RetryCount);
        int retryDelaySecs = Math.Max(10, options.RetryDelaySeconds);

        for (int attempt = 1; attempt <= maxRetries; attempt++)
        {
            if (stoppingToken.IsCancellationRequested) break;

            try
            {
                _logger.LogInformation("Executing automated daily database backup (Attempt {Attempt}/{MaxRetries})...",
                    attempt, maxRetries);

                using var scope = _serviceProvider.CreateScope();
                var backupService = scope.ServiceProvider.GetRequiredService<IBackupService>();

                var record = await backupService.CreateBackupAsync(
                    triggerType: "Scheduled",
                    initiatedBy: "System (Automated Daily Scheduler)",
                    cancellationToken: stoppingToken
                );

                if (record.Status == "Success")
                {
                    _logger.LogInformation("Automated daily backup succeeded! BackupId: {Id}, Size: {Size} bytes, Checksum: {Hash}",
                        record.BackupId, record.SizeBytes, record.Sha256Checksum);
                    return; // Success, exit retry loop
                }

                _logger.LogWarning("Automated daily backup attempt {Attempt} finished with non-success status: {Status}. Error: {Error}",
                    attempt, record.Status, record.ErrorMessage);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Exception during automated daily backup attempt {Attempt}/{MaxRetries}: {Message}",
                    attempt, maxRetries, ex.Message);

                if (attempt == maxRetries)
                {
                    _logger.LogCritical("CRITICAL ALERT: All {MaxRetries} daily database backup attempts failed! Administrator notification required.",
                        maxRetries);
                    return;
                }

                _logger.LogInformation("Waiting {Delay} seconds before retry attempt {Next}...", retryDelaySecs, attempt + 1);
                await Task.Delay(TimeSpan.FromSeconds(retryDelaySecs), stoppingToken);
            }
        }
    }
}

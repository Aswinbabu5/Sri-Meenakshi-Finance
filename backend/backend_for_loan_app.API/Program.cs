using backend_for_loan_app.Application.Common.Interfaces;
using backend_for_loan_app.Application.Services;
using backend_for_loan_app.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);

// Enable CORS for mobile & web clients
builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowAll", policy =>
    {
        policy.AllowAnyOrigin()
              .AllowAnyMethod()
              .AllowAnyHeader();
    });
});

builder.Services.AddControllers()
    .AddJsonOptions(options =>
    {
        options.JsonSerializerOptions.ReferenceHandler = System.Text.Json.Serialization.ReferenceHandler.IgnoreCycles;
        options.JsonSerializerOptions.PropertyNameCaseInsensitive = true;
    });

// Configure Database (MySQL)
var rawConnectionString = builder.Configuration.GetConnectionString("DefaultConnection");
var connectionString = NormalizeConnectionString(rawConnectionString);

builder.Services.AddDbContext<AppDbContext>(options =>
    options.UseMySql(
        connectionString,
        new MySqlServerVersion(new Version(8, 0, 36)),
        mySqlOptions => mySqlOptions.EnableRetryOnFailure(
            maxRetryCount: 3,
            maxRetryDelay: TimeSpan.FromSeconds(5),
            errorNumbersToAdd: null
        )
    )
);

// Register IAppDbContext
builder.Services.AddScoped<IAppDbContext>(provider => provider.GetRequiredService<AppDbContext>());

// Register Application Services
builder.Services.AddScoped<CustomerServices>();
builder.Services.AddScoped<LoanServices>();
builder.Services.AddScoped<CollectionServices>();
builder.Services.AddScoped<ReportServices>();
builder.Services.AddScoped<DashboardServices>();

// Register Database Backup & Recovery Options and Services
builder.Services.Configure<backend_for_loan_app.Application.Common.BackupOptions>(
    builder.Configuration.GetSection(backend_for_loan_app.Application.Common.BackupOptions.SectionName));
builder.Services.AddScoped<IBackupService, BackupService>();
builder.Services.AddHostedService<DailyBackupHostedService>();

builder.Services.AddOpenApi();

var app = builder.Build();

// Auto-migrate & Seed safely inside try-catch
using (var scope = app.Services.CreateScope())
{
    try
    {
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        db.Database.EnsureCreated();

        // Ensure EncryptedData column exists in backuphistories for persistent cloud storage
        try
        {
            db.Database.ExecuteSqlRaw("ALTER TABLE `backuphistories` ADD COLUMN IF NOT EXISTS `EncryptedData` LONGTEXT NULL;");
        }
        catch (Exception alterEx)
        {
            Console.WriteLine($"[INFO] EncryptedData column verification note: {alterEx.Message}");
        }

        DataSeeder.SeedData(db);
        Console.WriteLine("[INFO] Database connected, initialized and seeded successfully.");
    }
    catch (Exception ex)
    {
        Console.WriteLine($"[WARN] Database initialization note: {ex.Message}");
    }
}

app.UseCors("AllowAll");

// Health check endpoints for Render and cloud monitors
app.MapGet("/", () => Results.Ok(new
{
    status = "healthy",
    service = "Sri Meenakshi Finance Backend API",
    version = "1.0.0",
    timeUtc = DateTime.UtcNow
}));

app.MapGet("/health", () => Results.Ok(new { status = "healthy", timeUtc = DateTime.UtcNow }));

if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
}

app.MapControllers();

app.Run();

// Helper method to automatically normalize and sanitize connection strings
// Supports ADO.NET format, mysql:// URIs, CLI formats, and stripped quotes
static string NormalizeConnectionString(string? raw)
{
    if (string.IsNullOrWhiteSpace(raw))
    {
        Console.WriteLine("[WARN] No ConnectionString provided. Using default fallback.");
        return "server=localhost;port=3306;database=loan;user=root;password=root;";
    }

    raw = raw.Trim();

    // Strip outer single or double quotes
    if ((raw.StartsWith("\"") && raw.EndsWith("\"")) || (raw.StartsWith("'") && raw.EndsWith("'")))
    {
        raw = raw[1..^1].Trim();
    }

    // Handle URI format: mysql://user:password@host:port/database
    if (raw.StartsWith("mysql://", StringComparison.OrdinalIgnoreCase) ||
        raw.StartsWith("mariadb://", StringComparison.OrdinalIgnoreCase))
    {
        try
        {
            var uri = new Uri(raw);
            var userInfo = uri.UserInfo.Split(':', 2);
            var user = Uri.UnescapeDataString(userInfo[0]);
            var pass = userInfo.Length > 1 ? Uri.UnescapeDataString(userInfo[1]) : "";
            var host = uri.Host;
            var port = uri.Port > 0 ? uri.Port : 3306;
            var database = uri.AbsolutePath.TrimStart('/');
            if (string.IsNullOrWhiteSpace(database) || database.Equals("sys", StringComparison.OrdinalIgnoreCase))
            {
                database = "test";
            }

            Console.WriteLine($"[INFO] Parsed MySQL URI -> Server={host};Port={port};Database={database};User Id={user};SslMode=Preferred");
            return $"Server={host};Port={port};Database={database};User Id={user};Password={pass};SslMode=Preferred;";
        }
        catch (Exception ex)
        {
            Console.WriteLine($"[WARN] Failed to parse URI connection string, falling back to raw: {ex.Message}");
        }
    }

    // Handle mysql CLI command format: mysql -h host -u user -P port ...
    if (raw.StartsWith("mysql ", StringComparison.OrdinalIgnoreCase))
    {
        var parts = raw.Split(' ', StringSplitOptions.RemoveEmptyEntries);
        string host = "localhost", user = "root", pass = "", db = "loan";
        int port = 3306;
        for (int i = 0; i < parts.Length; i++)
        {
            if ((parts[i] == "-h" || parts[i] == "--host") && i + 1 < parts.Length) host = parts[++i].Trim('\'', '"');
            else if ((parts[i] == "-u" || parts[i] == "--user") && i + 1 < parts.Length) user = parts[++i].Trim('\'', '"');
            else if ((parts[i] == "-P" || parts[i] == "--port") && i + 1 < parts.Length && int.TryParse(parts[++i], out var p)) port = p;
            else if ((parts[i] == "-D" || parts[i] == "--database") && i + 1 < parts.Length) db = parts[++i].Trim('\'', '"');
            else if (parts[i].StartsWith("-p") && parts[i].Length > 2) pass = parts[i][2..].Trim('\'', '"');
        }
        Console.WriteLine($"[INFO] Parsed MySQL CLI args -> Server={host};Port={port};Database={db};User Id={user}");
        return $"Server={host};Port={port};Database={db};User Id={user};Password={pass};SslMode=Preferred;";
    }

    // Standard ADO.NET format: ensure SslMode is included if not specified (needed for cloud MySQL)
    if (!raw.Contains("SslMode", StringComparison.OrdinalIgnoreCase) && !raw.Contains("ssl-mode", StringComparison.OrdinalIgnoreCase))
    {
        raw = raw.TrimEnd(';') + ";SslMode=Preferred;";
    }

    return raw;
}


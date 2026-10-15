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
var connectionString = builder.Configuration.GetConnectionString("DefaultConnection");

builder.Services.AddDbContext<AppDbContext>(options =>
    options.UseMySql(
        connectionString,
        new MySqlServerVersion(new Version(8, 0, 36))
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

// Auto-migrate & Seed
using (var scope = app.Services.CreateScope())
{
    var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
    try
    {
        db.Database.EnsureCreated();
        DataSeeder.SeedData(db);
        Console.WriteLine("Database initialized and seeded successfully.");
    }
    catch (Exception ex)
    {
        Console.WriteLine($"Database initialization note: {ex.Message}");
    }
}

app.UseCors("AllowAll");

if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
}

app.MapControllers();

app.Run();

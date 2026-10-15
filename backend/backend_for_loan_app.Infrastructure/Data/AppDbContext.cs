using backend_for_loan_app.Application.Common.Interfaces;
using backend_for_loan_app.Domain.Entities;
using Microsoft.EntityFrameworkCore;

namespace backend_for_loan_app.Infrastructure.Data;

public class AppDbContext : DbContext, IAppDbContext 
{
    public AppDbContext(DbContextOptions<AppDbContext> options) : base(options) {}

    public DbSet<Customer> Customers { get; set; } = null!;
    public DbSet<CollectionLine> CollectionLines { get; set; } = null!;
    public DbSet<Loan> Loans { get; set; } = null!;
    public DbSet<DailyCollection> DailyCollections { get; set; } = null!;
    public DbSet<BackupHistoryRecord> BackupHistories { get; set; } = null!;
    public DbSet<RestoreHistoryRecord> RestoreHistories { get; set; } = null!;

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        modelBuilder.Entity<Customer>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.Property(e => e.Cus_Code).HasMaxLength(50);
            entity.Property(e => e.Name).HasMaxLength(150);
            entity.Property(e => e.Phone_Number).HasMaxLength(50);
        });

        modelBuilder.Entity<CollectionLine>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.Property(e => e.LineCode).HasMaxLength(10);
            entity.Property(e => e.LineName).HasMaxLength(100);
        });

        modelBuilder.Entity<Loan>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.Property(e => e.BondNumber).HasMaxLength(50);
            entity.Property(e => e.LineCode).HasMaxLength(10);
            entity.Property(e => e.LoanAmount).HasPrecision(18, 2);
            entity.Property(e => e.InterestAmount).HasPrecision(18, 2);
            entity.Property(e => e.TotalAmount).HasPrecision(18, 2);
            entity.Property(e => e.DailyDueAmount).HasPrecision(18, 2);
            entity.Property(e => e.BalanceAmount).HasPrecision(18, 2);
            entity.Property(e => e.CollectedAmount).HasPrecision(18, 2);
            entity.Property(e => e.ChitFee).HasPrecision(18, 2);
            
            entity.HasOne(e => e.Customer)
                  .WithMany()
                  .HasForeignKey(e => e.CustomerId)
                  .OnDelete(DeleteBehavior.Restrict);
        });

        modelBuilder.Entity<DailyCollection>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.Property(e => e.BondNumber).HasMaxLength(50);
            entity.Property(e => e.LineCode).HasMaxLength(10);
            entity.Property(e => e.Amount).HasPrecision(18, 2);
            entity.Property(e => e.PreviousBalance).HasPrecision(18, 2);
            entity.Property(e => e.CurrentBalance).HasPrecision(18, 2);

            entity.HasOne(e => e.Loan)
                  .WithMany()
                  .HasForeignKey(e => e.LoanId)
                  .OnDelete(DeleteBehavior.Cascade);
        });

        modelBuilder.Entity<BackupHistoryRecord>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.Property(e => e.BackupId).HasMaxLength(100).IsRequired();
            entity.Property(e => e.Filename).HasMaxLength(255).IsRequired();
            entity.Property(e => e.Status).HasMaxLength(50).IsRequired();
            entity.Property(e => e.StorageLocation).HasMaxLength(500);
            entity.Property(e => e.ValidationStatus).HasMaxLength(50);
            entity.Property(e => e.Sha256Checksum).HasMaxLength(100);
            entity.Property(e => e.TriggerType).HasMaxLength(50);
            entity.Property(e => e.CreatedBy).HasMaxLength(100);
        });

        modelBuilder.Entity<RestoreHistoryRecord>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.Property(e => e.BackupId).HasMaxLength(100).IsRequired();
            entity.Property(e => e.BackupFilename).HasMaxLength(255);
            entity.Property(e => e.PreRestoreBackupId).HasMaxLength(100);
            entity.Property(e => e.Status).HasMaxLength(50).IsRequired();
            entity.Property(e => e.RestoredBy).HasMaxLength(100);
        });
    }
}
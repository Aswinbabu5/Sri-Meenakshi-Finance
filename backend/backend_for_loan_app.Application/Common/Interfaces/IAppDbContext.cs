using backend_for_loan_app.Domain.Entities;
using Microsoft.EntityFrameworkCore;

namespace backend_for_loan_app.Application.Common.Interfaces;

public interface IAppDbContext
{
    DbSet<Customer> Customers { get; }
    DbSet<CollectionLine> CollectionLines { get; }
    DbSet<Loan> Loans { get; }
    DbSet<DailyCollection> DailyCollections { get; }
    DbSet<BackupHistoryRecord> BackupHistories { get; }
    DbSet<RestoreHistoryRecord> RestoreHistories { get; }
    Microsoft.EntityFrameworkCore.Infrastructure.DatabaseFacade Database { get; }
    Task<int> SaveChangesAsync(CancellationToken cancellationToken = default);
    int SaveChanges();
}

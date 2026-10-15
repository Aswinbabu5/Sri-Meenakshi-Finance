using backend_for_loan_app.Application.Common.Interfaces;
using backend_for_loan_app.Application.DTOs;
using Microsoft.EntityFrameworkCore;

namespace backend_for_loan_app.Application.Services;

public class DashboardServices
{
    private readonly IAppDbContext _context;

    public DashboardServices(IAppDbContext context)
    {
        _context = context;
    }

    public async Task<DashboardSummaryDto> GetSummaryAsync()
    {
        var today = DateTime.UtcNow.Date;

        var activeLoans = await _context.Loans.Where(l => l.Status == "active").ToListAsync();
        var totalOutstanding = activeLoans.Sum(l => l.BalanceAmount);
        var activeLoansCount = activeLoans.Count;

        var totalCustomers = await _context.Customers.CountAsync();

        var todayCollections = await _context.DailyCollections
            .Where(c => c.CollectionDate.Date == today)
            .ToListAsync();
        var todayTotal = todayCollections.Sum(c => c.Amount);

        var firstDayOfMonth = new DateTime(today.Year, today.Month, 1);
        var monthTotal = await _context.DailyCollections
            .Where(c => c.CollectionDate >= firstDayOfMonth)
            .SumAsync(c => c.Amount);

        var lines = await _context.CollectionLines.ToListAsync();
        var lineSummaries = new List<CollectionLineSummaryDto>();

        foreach (var line in lines)
        {
            var lineLoans = activeLoans.Where(l => l.LineCode == line.LineCode).ToList();
            var lineTodayCols = todayCollections.Where(c => c.LineCode == line.LineCode).Sum(c => c.Amount);

            lineSummaries.Add(new CollectionLineSummaryDto
            {
                LineCode = line.LineCode,
                LineName = line.LineName,
                ActiveLoans = lineLoans.Count,
                TotalBalance = lineLoans.Sum(l => l.BalanceAmount),
                TodayCollection = lineTodayCols
            });
        }

        return new DashboardSummaryDto
        {
            TotalOutstanding = totalOutstanding,
            TodayCollection = todayTotal,
            ActiveLoansCount = activeLoansCount,
            TotalCustomersCount = totalCustomers,
            OverdueLoansCount = activeLoans.Count(l => l.EndDate < today && l.BalanceAmount > 0),
            MonthCollection = monthTotal,
            Lines = lineSummaries
        };
    }
}

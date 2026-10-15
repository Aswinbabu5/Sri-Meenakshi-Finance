using backend_for_loan_app.Application.Common.Interfaces;
using backend_for_loan_app.Application.DTOs;
using backend_for_loan_app.Domain.Entities;
using Microsoft.EntityFrameworkCore;

namespace backend_for_loan_app.Application.Services;

public class ReportServices
{
    private readonly IAppDbContext _context;

    public ReportServices(IAppDbContext context)
    {
        _context = context;
    }

    public async Task<List<Day31RegisterRowDto>> Get31DayRegisterAsync(string lineCode, int year, int month)
    {
        lineCode = string.IsNullOrWhiteSpace(lineCode) ? "A" : lineCode.ToUpper();

        var loans = await _context.Loans
            .Include(l => l.Customer)
            .Where(l => l.LineCode == lineCode)
            .OrderBy(l => l.BondNumber)
            .ToListAsync();

        var startDate = new DateTime(year, month, 1);
        var endDate = startDate.AddMonths(1).AddDays(-1);

        var collections = await _context.DailyCollections
            .Where(c => c.LineCode == lineCode &&
                        c.CollectionDate >= startDate &&
                        c.CollectionDate <= endDate)
            .ToListAsync();

        var result = new List<Day31RegisterRowDto>();

        foreach (var loan in loans)
        {
            var row = new Day31RegisterRowDto
            {
                BondNumber = loan.BondNumber,
                CustomerName = loan.Customer?.Name ?? "Unknown",
                LoanAmount = loan.LoanAmount,
                TotalAmount = loan.TotalAmount,
                DailyDue = loan.DailyDueAmount,
                BalanceAmount = loan.BalanceAmount
            };

            var loanCols = collections.Where(c => c.LoanId == loan.Id).ToList();
            decimal totalMonth = 0;

            for (int day = 1; day <= 31; day++)
            {
                var daySum = loanCols.Where(c => c.CollectionDate.Day == day).Sum(c => c.Amount);
                row.DayCollections[day] = daySum;
                totalMonth += daySum;
            }

            row.TotalMonthCollected = totalMonth;
            result.Add(row);
        }

        return result;
    }

    public async Task<List<Loan>> GetPendingPartyReportAsync(string? lineCode)
    {
        var query = _context.Loans.Include(l => l.Customer).Where(l => l.Status == "active");

        if (!string.IsNullOrEmpty(lineCode) && lineCode != "All")
            query = query.Where(l => l.LineCode == lineCode);

        // Active loans with pending balance
        return await query.Where(l => l.BalanceAmount > 0).OrderByDescending(l => l.BalanceAmount).ToListAsync();
    }

    public async Task<List<Loan>> GetClosedListAsync(string? lineCode)
    {
        var query = _context.Loans.Include(l => l.Customer).Where(l => l.Status == "closed" || l.BalanceAmount <= 0);

        if (!string.IsNullOrEmpty(lineCode) && lineCode != "All")
            query = query.Where(l => l.LineCode == lineCode);

        return await query.OrderByDescending(l => l.Id).ToListAsync();
    }
}

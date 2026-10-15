using backend_for_loan_app.Application.Common.Interfaces;
using backend_for_loan_app.Application.DTOs;
using backend_for_loan_app.Domain.Entities;
using Microsoft.EntityFrameworkCore;

namespace backend_for_loan_app.Application.Services;

public class CollectionServices
{
    private readonly IAppDbContext _context;

    public CollectionServices(IAppDbContext context)
    {
        _context = context;
    }

    public async Task<DailyCollection> RecordCollectionAsync(RecordCollectionRequest req)
    {
        var loan = await _context.Loans
            .Include(l => l.Customer)
            .FirstOrDefaultAsync(l => l.BondNumber.ToUpper() == req.BondNumber.Trim().ToUpper());

        if (loan == null)
            throw new Exception($"Loan with Bond Number {req.BondNumber} not found.");

        var prevBal = loan.BalanceAmount;
        var newBal = prevBal - req.Amount;
        if (newBal < 0) newBal = 0;

        loan.CollectedAmount += req.Amount;
        loan.BalanceAmount = newBal;
        if (newBal <= 0)
        {
            loan.Status = "closed";
        }

        var collection = new DailyCollection
        {
            LoanId = loan.Id,
            Loan = loan,
            BondNumber = loan.BondNumber,
            LineCode = loan.LineCode,
            CollectionDate = req.CollectionDate == default ? DateTime.UtcNow : req.CollectionDate,
            Amount = req.Amount,
            PreviousBalance = prevBal,
            CurrentBalance = newBal,
            ReceiptType = string.IsNullOrWhiteSpace(req.ReceiptType) ? "Note" : req.ReceiptType,
            Notes = req.Notes,
            CreatedAt = DateTime.UtcNow
        };

        _context.DailyCollections.Add(collection);
        await _context.SaveChangesAsync();

        return collection;
    }

    public async Task<DailyCollectionSummaryDto> GetDailySheetAsync(DateTime date, string lineCode)
    {
        lineCode = string.IsNullOrWhiteSpace(lineCode) ? "A" : lineCode.ToUpper();
        var targetDate = date.Date;

        var collections = await _context.DailyCollections
            .Include(c => c.Loan)
            .ThenInclude(l => l!.Customer)
            .Where(c => c.LineCode == lineCode && c.CollectionDate.Date == targetDate)
            .OrderBy(c => c.Id)
            .ToListAsync();

        var items = new List<DailyCollectionSheetItem>();
        int sl = 1;
        foreach (var col in collections)
        {
            items.Add(new DailyCollectionSheetItem
            {
                SlNo = sl++,
                BondNumber = col.BondNumber,
                CustomerName = col.Loan?.Customer?.Name ?? "Unknown",
                CollectedAmount = col.Amount,
                BalanceAmount = col.CurrentBalance,
                CollectionDate = col.CollectionDate
            });
        }

        return new DailyCollectionSummaryDto
        {
            LineCode = lineCode,
            Date = targetDate,
            TotalParties = items.Count,
            TotalAmount = items.Sum(i => i.CollectedAmount),
            Items = items
        };
    }

    public async Task<List<DailyCollection>> GetLedgerByBondAsync(string bondNumber)
    {
        return await _context.DailyCollections
            .Where(c => c.BondNumber.ToUpper() == bondNumber.Trim().ToUpper())
            .OrderByDescending(c => c.CollectionDate)
            .ToListAsync();
    }

    public async Task<DailyCollection?> UpdateCollectionAsync(int collectionId, decimal newAmount)
    {
        var col = await _context.DailyCollections
            .Include(c => c.Loan)
            .FirstOrDefaultAsync(c => c.Id == collectionId);

        if (col == null || col.Loan == null) return null;

        var diff = newAmount - col.Amount;
        col.Loan.CollectedAmount += diff;
        col.Loan.BalanceAmount -= diff;
        if (col.Loan.BalanceAmount < 0) col.Loan.BalanceAmount = 0;

        col.Amount = newAmount;
        col.CurrentBalance = col.Loan.BalanceAmount;

        await _context.SaveChangesAsync();
        return col;
    }
}

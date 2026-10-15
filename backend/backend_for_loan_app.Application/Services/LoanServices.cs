using backend_for_loan_app.Application.Common.Interfaces;
using backend_for_loan_app.Application.DTOs;
using backend_for_loan_app.Domain.Entities;
using Microsoft.EntityFrameworkCore;

namespace backend_for_loan_app.Application.Services;

public class LoanServices
{
    private readonly IAppDbContext _context;

    public LoanServices(IAppDbContext context)
    {
        _context = context;
    }

    public async Task<List<Loan>> GetLoansAsync(string? lineCode = null, string? status = null)
    {
        var query = _context.Loans.Include(l => l.Customer).AsQueryable();

        if (!string.IsNullOrEmpty(lineCode) && lineCode != "All")
            query = query.Where(l => l.LineCode == lineCode);

        if (!string.IsNullOrEmpty(status) && status != "All")
            query = query.Where(l => l.Status == status);

        return await query.OrderByDescending(l => l.Id).ToListAsync();
    }

    public async Task<Loan?> GetLoanByIdAsync(int id)
    {
        return await _context.Loans
            .Include(l => l.Customer)
            .FirstOrDefaultAsync(l => l.Id == id);
    }

    public async Task<Loan?> GetLoanByBondNumberAsync(string bondNumber)
    {
        var bond = bondNumber.Trim().ToUpper();
        return await _context.Loans
            .Include(l => l.Customer)
            .FirstOrDefaultAsync(l => l.BondNumber.ToUpper() == bond);
    }

    public async Task<string> GetNextBondNumberAsync(string lineCode)
    {
        lineCode = string.IsNullOrWhiteSpace(lineCode) ? "A" : lineCode.ToUpper();
        var existingBonds = await _context.Loans
            .Where(l => l.LineCode == lineCode)
            .Select(l => l.BondNumber)
            .ToListAsync();

        int maxNumber = 0;
        foreach (var b in existingBonds)
        {
            var parts = b.Split('-');
            if (parts.Length == 2 && int.TryParse(parts[1], out int num))
            {
                if (num > maxNumber) maxNumber = num;
            }
        }

        return $"{lineCode}-{(maxNumber + 1):D2}";
    }

    public async Task<Loan> CreateLoanAsync(CreateLoanRequest req)
    {
        var line = string.IsNullOrWhiteSpace(req.LineCode) ? "A" : req.LineCode.ToUpper();

        // 1. Find or create customer
        var customer = await _context.Customers
            .FirstOrDefaultAsync(c => c.Name.ToLower() == req.CustomerName.Trim().ToLower() ||
                                      (c.Phone_Number == req.PhoneNumber && !string.IsNullOrEmpty(req.PhoneNumber)));

        if (customer == null)
        {
            var custCount = await _context.Customers.CountAsync();
            customer = new Customer
            {
                Cus_Code = $"CUS-{(custCount + 1):D3}",
                Name = req.CustomerName.Trim(),
                FatherOrSpouseName = req.FatherOrSpouseName,
                Phone_Number = req.PhoneNumber,
                Address = req.Address,
                City = string.IsNullOrWhiteSpace(req.City) ? "Madurai" : req.City,
                Notes = req.Details,
                Status = "active"
            };
            _context.Customers.Add(customer);
            await _context.SaveChangesAsync();
        }

        // 2. Generate bond number if not supplied
        var bondNumber = string.IsNullOrWhiteSpace(req.BondNumber)
            ? await GetNextBondNumberAsync(line)
            : req.BondNumber.ToUpper();

        var totalAmount = req.LoanAmount + req.InterestAmount;
        var tenure = req.TenureDays > 0 ? req.TenureDays : 100;
        var dailyDue = Math.Round(totalAmount / tenure, 2);

        var loan = new Loan
        {
            BondNumber = bondNumber,
            LineCode = line,
            CustomerId = customer.Id,
            Customer = customer,
            TenureDays = tenure,
            LoanAmount = req.LoanAmount,
            InterestAmount = req.InterestAmount,
            TotalAmount = totalAmount,
            DailyDueAmount = dailyDue,
            ChitFee = req.ChitFee,
            StartDate = req.StartDate == default ? DateTime.UtcNow : req.StartDate,
            EndDate = (req.StartDate == default ? DateTime.UtcNow : req.StartDate).AddDays(tenure),
            CollectedAmount = 0,
            BalanceAmount = totalAmount,
            Status = "active",
            CreatedAt = DateTime.UtcNow
        };

        _context.Loans.Add(loan);
        await _context.SaveChangesAsync();

        return loan;
    }

    public async Task<List<Loan>> SearchLoansAsync(string query)
    {
        if (string.IsNullOrWhiteSpace(query))
            return await GetLoansAsync();

        var q = query.Trim().ToLower();
        return await _context.Loans
            .Include(l => l.Customer)
            .Where(l => l.BondNumber.ToLower().Contains(q) ||
                        (l.Customer != null && (l.Customer.Name.ToLower().Contains(q) || l.Customer.Phone_Number.Contains(q))))
            .ToListAsync();
    }
}

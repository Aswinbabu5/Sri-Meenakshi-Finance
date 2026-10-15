using backend_for_loan_app.Application.Common.Interfaces;
using backend_for_loan_app.Domain.Entities;
using Microsoft.EntityFrameworkCore;

namespace backend_for_loan_app.Application.Services;

public class CustomerServices
{
    private readonly IAppDbContext _context;

    public CustomerServices(IAppDbContext context)
    {
        _context = context;
    }

    public async Task<List<Customer>> GetCustomersAsync()
    {
        return await _context.Customers.OrderBy(c => c.Name).ToListAsync();
    }

    public async Task<Customer?> GetCustomerByIdAsync(int id)
    {
        return await _context.Customers.FindAsync(id);
    }

    public async Task<List<Customer>> SearchCustomersAsync(string query)
    {
        if (string.IsNullOrWhiteSpace(query))
            return await GetCustomersAsync();

        var q = query.ToLower();
        return await _context.Customers
            .Where(c => c.Name.ToLower().Contains(q) ||
                        c.Phone_Number.Contains(q) ||
                        c.Cus_Code.ToLower().Contains(q))
            .ToListAsync();
    }

    public async Task<Customer> CreateCustomerAsync(Customer customer)
    {
        if (string.IsNullOrEmpty(customer.Cus_Code))
        {
            var count = await _context.Customers.CountAsync();
            customer.Cus_Code = $"CUS-{(count + 1):D3}";
        }

        _context.Customers.Add(customer);
        await _context.SaveChangesAsync();
        return customer;
    }
}
using backend_for_loan_app.Application.Services;
using backend_for_loan_app.Domain.Entities;
using Microsoft.AspNetCore.Mvc;

namespace backend_for_loan_app.API.Controllers;

[ApiController]
[Route("api/[controller]")]
public class CustomersController : ControllerBase
{
    private readonly CustomerServices _customerService;

    public CustomersController(CustomerServices customerServices)
    {
        _customerService = customerServices;
    }

    [HttpGet]
    public async Task<IActionResult> GetCustomers([FromQuery] string? search)
    {
        if (!string.IsNullOrEmpty(search))
        {
            var searchResults = await _customerService.SearchCustomersAsync(search);
            return Ok(searchResults);
        }

        var customers = await _customerService.GetCustomersAsync();
        return Ok(customers);
    }

    [HttpGet("{id}")]
    public async Task<IActionResult> GetCustomer(int id)
    {
        var customer = await _customerService.GetCustomerByIdAsync(id);
        if (customer == null) return NotFound();
        return Ok(customer);
    }

    [HttpPost]
    public async Task<IActionResult> CreateCustomer([FromBody] Customer customer)
    {
        var created = await _customerService.CreateCustomerAsync(customer);
        return CreatedAtAction(nameof(GetCustomer), new { id = created.Id }, created);
    }
}
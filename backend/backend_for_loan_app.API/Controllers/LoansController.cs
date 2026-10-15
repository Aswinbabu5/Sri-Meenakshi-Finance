using backend_for_loan_app.Application.DTOs;
using backend_for_loan_app.Application.Services;
using Microsoft.AspNetCore.Mvc;

namespace backend_for_loan_app.API.Controllers;

[ApiController]
[Route("api/[controller]")]
public class LoansController : ControllerBase
{
    private readonly LoanServices _loanServices;

    public LoansController(LoanServices loanServices)
    {
        _loanServices = loanServices;
    }

    [HttpGet]
    public async Task<IActionResult> GetLoans([FromQuery] string? lineCode, [FromQuery] string? status)
    {
        var loans = await _loanServices.GetLoansAsync(lineCode, status);
        return Ok(loans);
    }

    [HttpGet("{id:int}")]
    public async Task<IActionResult> GetLoan(int id)
    {
        var loan = await _loanServices.GetLoanByIdAsync(id);
        if (loan == null) return NotFound();
        return Ok(loan);
    }

    [HttpGet("bond/{bondNumber}")]
    public async Task<IActionResult> GetLoanByBond(string bondNumber)
    {
        var loan = await _loanServices.GetLoanByBondNumberAsync(bondNumber);
        if (loan == null) return NotFound(new { message = $"Bond {bondNumber} not found." });
        return Ok(loan);
    }

    [HttpGet("next-bond")]
    public async Task<IActionResult> GetNextBond([FromQuery] string lineCode = "A")
    {
        var nextBond = await _loanServices.GetNextBondNumberAsync(lineCode);
        return Ok(new { nextBond });
    }

    [HttpGet("search")]
    public async Task<IActionResult> Search([FromQuery] string query)
    {
        var results = await _loanServices.SearchLoansAsync(query);
        return Ok(results);
    }

    [HttpPost]
    public async Task<IActionResult> CreateLoan([FromBody] CreateLoanRequest request)
    {
        try
        {
            var created = await _loanServices.CreateLoanAsync(request);
            return CreatedAtAction(nameof(GetLoan), new { id = created.Id }, created);
        }
        catch (Exception ex)
        {
            return BadRequest(new { message = ex.Message });
        }
    }
}

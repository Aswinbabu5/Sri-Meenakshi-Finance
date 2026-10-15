using backend_for_loan_app.Application.Common.Interfaces;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace backend_for_loan_app.API.Controllers;

[ApiController]
[Route("api/[controller]")]
public class LinesController : ControllerBase
{
    private readonly IAppDbContext _context;

    public LinesController(IAppDbContext context)
    {
        _context = context;
    }

    [HttpGet]
    public async Task<IActionResult> GetLines()
    {
        var lines = await _context.CollectionLines.Where(l => l.IsActive).ToListAsync();
        return Ok(lines);
    }
}

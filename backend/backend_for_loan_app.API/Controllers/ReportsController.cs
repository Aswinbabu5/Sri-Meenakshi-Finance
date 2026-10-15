using backend_for_loan_app.Application.Services;
using Microsoft.AspNetCore.Mvc;

namespace backend_for_loan_app.API.Controllers;

[ApiController]
[Route("api/[controller]")]
public class ReportsController : ControllerBase
{
    private readonly ReportServices _reportServices;

    public ReportsController(ReportServices reportServices)
    {
        _reportServices = reportServices;
    }

    [HttpGet("31-day-register")]
    public async Task<IActionResult> Get31DayRegister(
        [FromQuery] string lineCode = "A",
        [FromQuery] int? year = null,
        [FromQuery] int? month = null)
    {
        var y = year ?? DateTime.UtcNow.Year;
        var m = month ?? DateTime.UtcNow.Month;
        var result = await _reportServices.Get31DayRegisterAsync(lineCode, y, m);
        return Ok(result);
    }

    [HttpGet("pending-parties")]
    public async Task<IActionResult> GetPendingParties([FromQuery] string? lineCode)
    {
        var result = await _reportServices.GetPendingPartyReportAsync(lineCode);
        return Ok(result);
    }

    [HttpGet("closed-list")]
    public async Task<IActionResult> GetClosedList([FromQuery] string? lineCode)
    {
        var result = await _reportServices.GetClosedListAsync(lineCode);
        return Ok(result);
    }
}

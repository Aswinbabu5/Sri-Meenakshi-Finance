using backend_for_loan_app.Application.Services;
using Microsoft.AspNetCore.Mvc;

namespace backend_for_loan_app.API.Controllers;

[ApiController]
[Route("api/[controller]")]
public class DashboardController : ControllerBase
{
    private readonly DashboardServices _dashboardServices;

    public DashboardController(DashboardServices dashboardServices)
    {
        _dashboardServices = dashboardServices;
    }

    [HttpGet("summary")]
    public async Task<IActionResult> GetSummary()
    {
        var summary = await _dashboardServices.GetSummaryAsync();
        return Ok(summary);
    }
}

using backend_for_loan_app.Application.DTOs;
using backend_for_loan_app.Application.Services;
using Microsoft.AspNetCore.Mvc;

namespace backend_for_loan_app.API.Controllers;

[ApiController]
[Route("api/[controller]")]
public class CollectionsController : ControllerBase
{
    private readonly CollectionServices _collectionServices;

    public CollectionsController(CollectionServices collectionServices)
    {
        _collectionServices = collectionServices;
    }

    [HttpPost]
    public async Task<IActionResult> RecordCollection([FromBody] RecordCollectionRequest request)
    {
        try
        {
            var collection = await _collectionServices.RecordCollectionAsync(request);
            return Ok(collection);
        }
        catch (Exception ex)
        {
            return BadRequest(new { message = ex.Message });
        }
    }

    [HttpGet("daily-sheet")]
    public async Task<IActionResult> GetDailySheet([FromQuery] DateTime? date, [FromQuery] string lineCode = "A")
    {
        var targetDate = date ?? DateTime.UtcNow;
        var sheet = await _collectionServices.GetDailySheetAsync(targetDate, lineCode);
        return Ok(sheet);
    }

    [HttpGet("ledger/{bondNumber}")]
    public async Task<IActionResult> GetLedger(string bondNumber)
    {
        var ledger = await _collectionServices.GetLedgerByBondAsync(bondNumber);
        return Ok(ledger);
    }

    [HttpPut("{id:int}")]
    public async Task<IActionResult> UpdateCollection(int id, [FromBody] decimal newAmount)
    {
        var updated = await _collectionServices.UpdateCollectionAsync(id, newAmount);
        if (updated == null) return NotFound();
        return Ok(updated);
    }
}

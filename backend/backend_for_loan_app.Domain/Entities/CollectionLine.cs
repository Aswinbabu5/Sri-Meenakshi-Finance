namespace backend_for_loan_app.Domain.Entities;

public class CollectionLine
{
    public int Id { get; set; }
    public string LineCode { get; set; } = "A"; // e.g. A, B, C, D
    public string LineName { get; set; } = string.Empty; // e.g. Line A - Town Area
    public string? CollectorName { get; set; }
    public string? Description { get; set; }
    public bool IsActive { get; set; } = true;
}

namespace backend_for_loan_app.Domain.Entities;

public class DailyCollection
{
    public int Id { get; set; }
    public int LoanId { get; set; }
    public Loan? Loan { get; set; }
    public string BondNumber { get; set; } = string.Empty;
    public string LineCode { get; set; } = "A";
    public DateTime CollectionDate { get; set; } = DateTime.UtcNow; // வசூல் தேதி
    public decimal Amount { get; set; } // வசூலான தொகை
    public decimal PreviousBalance { get; set; }
    public decimal CurrentBalance { get; set; }
    public string ReceiptType { get; set; } = "Note"; // Note (வசூல் Note) or Chit (கைசிட்டை)
    public string? Notes { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}

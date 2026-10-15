namespace backend_for_loan_app.Domain.Entities;

public class Loan
{
    public int Id { get; set; }
    public string BondNumber { get; set; } = string.Empty; // e.g. A001 (no hyphen)
    public string LineCode { get; set; } = "A";
    public int CustomerId { get; set; }
    public Customer? Customer { get; set; }
    public string? PhotoPath { get; set; } // Customer Face / Profile Photo
    public string? ProofType { get; set; } // Reference type (Aadhaar, Voter ID, PAN, Ration Card)
    public string? ProofFrontPath { get; set; } // Front photo of ID proof
    public string? ProofBackPath { get; set; } // Back photo of ID proof

    public int TenureDays { get; set; } = 100; // தவணை நாள் (default 100 days)
    public decimal LoanAmount { get; set; } // கடன் தொகை
    public decimal InterestRate { get; set; } = 1; // வட்டி %
    public decimal InterestAmount { get; set; } // வட்டி தொகை
    public decimal TotalAmount { get; set; } // கடன் + வட்டி
    public decimal DailyDueAmount { get; set; } // தவணை தவணைக்குரிய தொகை
    public decimal ChitFee { get; set; } = 100; // சீட்டு காசு / ஆவண கட்டணம்

    public DateTime StartDate { get; set; } = DateTime.UtcNow; // ஆரம்ப தேதி
    public DateTime EndDate { get; set; } // முடிவு தேதி (StartDate + TenureDays)

    public decimal CollectedAmount { get; set; } = 0;
    public decimal BalanceAmount { get; set; } // பாக்கித் தொகை
    public string Status { get; set; } = "active"; // active, closed, overdue
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}

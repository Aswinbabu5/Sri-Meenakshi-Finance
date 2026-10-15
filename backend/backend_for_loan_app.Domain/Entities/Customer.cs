namespace backend_for_loan_app.Domain.Entities;

public class Customer
{
    public int Id { get; set; }
    public string Cus_Code { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
    public string? FatherOrSpouseName { get; set; } // S/o or W/o
    public string Phone_Number { get; set; } = string.Empty;
    public string? Address { get; set; }
    public string City { get; set; } = "Madurai";
    public string? PhotoPath { get; set; } // Customer Face / Profile Photo
    public string? ProofType { get; set; } // Reference type (Aadhaar, Voter ID, PAN, Ration Card)
    public string? ProofFrontPath { get; set; } // Front photo of ID proof
    public string? ProofBackPath { get; set; } // Back photo of ID proof
    public string? Notes { get; set; }
    public string Status { get; set; } = "active";
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}
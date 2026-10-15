using backend_for_loan_app.Domain.Entities;

namespace backend_for_loan_app.Application.DTOs;

public class CreateLoanRequest
{
    public string LineCode { get; set; } = "A";
    public string? BondNumber { get; set; }
    public string CustomerName { get; set; } = string.Empty;
    public string? FatherOrSpouseName { get; set; }
    public string PhoneNumber { get; set; } = string.Empty;
    public string? Address { get; set; }
    public string City { get; set; } = "Madurai";
    public string? Details { get; set; }
    
    public int TenureDays { get; set; } = 100;
    public decimal LoanAmount { get; set; }
    public decimal InterestAmount { get; set; }
    public decimal ChitFee { get; set; } = 100;
    public DateTime StartDate { get; set; } = DateTime.UtcNow;
}

public class RecordCollectionRequest
{
    public string BondNumber { get; set; } = string.Empty;
    public string LineCode { get; set; } = "A";
    public decimal Amount { get; set; }
    public DateTime CollectionDate { get; set; } = DateTime.UtcNow;
    public string ReceiptType { get; set; } = "Note"; // Note or Chit
    public string? Notes { get; set; }
}

public class DailyCollectionSheetItem
{
    public int SlNo { get; set; }
    public string BondNumber { get; set; } = string.Empty;
    public string CustomerName { get; set; } = string.Empty;
    public decimal CollectedAmount { get; set; }
    public decimal BalanceAmount { get; set; }
    public DateTime CollectionDate { get; set; }
}

public class DailyCollectionSummaryDto
{
    public string LineCode { get; set; } = "A";
    public DateTime Date { get; set; }
    public int TotalParties { get; set; }
    public decimal TotalAmount { get; set; }
    public List<DailyCollectionSheetItem> Items { get; set; } = new();
}

public class DashboardSummaryDto
{
    public decimal TotalOutstanding { get; set; }
    public decimal TodayCollection { get; set; }
    public int ActiveLoansCount { get; set; }
    public int TotalCustomersCount { get; set; }
    public int OverdueLoansCount { get; set; }
    public decimal MonthCollection { get; set; }
    public List<CollectionLineSummaryDto> Lines { get; set; } = new();
}

public class CollectionLineSummaryDto
{
    public string LineCode { get; set; } = "A";
    public string LineName { get; set; } = string.Empty;
    public int ActiveLoans { get; set; }
    public decimal TotalBalance { get; set; }
    public decimal TodayCollection { get; set; }
}

public class Day31RegisterRowDto
{
    public string BondNumber { get; set; } = string.Empty;
    public string CustomerName { get; set; } = string.Empty;
    public decimal LoanAmount { get; set; }
    public decimal TotalAmount { get; set; }
    public decimal DailyDue { get; set; }
    public decimal BalanceAmount { get; set; }
    public Dictionary<int, decimal> DayCollections { get; set; } = new(); // Day 1 to 31
    public decimal TotalMonthCollected { get; set; }
}

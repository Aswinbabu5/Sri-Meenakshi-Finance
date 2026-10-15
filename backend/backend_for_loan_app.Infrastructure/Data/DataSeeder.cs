using backend_for_loan_app.Domain.Entities;

namespace backend_for_loan_app.Infrastructure.Data;

public static class DataSeeder
{
    public static void SeedData(AppDbContext context)
    {
        if (context.CollectionLines.Any()) return;

        // 1. Lines only (no hardcoded customers or loans)
        var lines = new List<CollectionLine>
        {
            new() { LineCode = "A", LineName = "Line A - மதுரை டவுன் (Madurai Town)", CollectorName = "R. Suresh (சுரேஷ்)", Description = "Town Hall Road, West Masi St" },
            new() { LineCode = "B", LineName = "Line B - செல்லூர் (Sellur)", CollectorName = "K. Manikandan (மணிகண்டன்)", Description = "Sellur 50 Feet Road, Meenambalpuram" },
            new() { LineCode = "C", LineName = "Line C - சிம்மக்கல் (Simmakkal)", CollectorName = "M. Karthik (கார்த்திக்)", Description = "North Veli St, Simmakkal Market" },
            new() { LineCode = "D", LineName = "Line D - திருநகர் (Thirunagar)", CollectorName = "S. Vignesh (விக்னேஷ்)", Description = "Thirunagar Stop 1 to 8" }
        };
        context.CollectionLines.AddRange(lines);
        context.SaveChanges();
    }
}

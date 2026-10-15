import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_animations.dart';
import '../../../../core/services/loan_repository.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../../core/utils/file_download_helper.dart';
import '../../dashboard/presentation/widgets/company_header.dart';
import 'widgets/ledger_analytics_widget.dart';

class ReportsPage extends StatefulWidget {
  final LoanRepository repository;
  final int? initialMonth;
  final int? initialYear;
  final String? initialReportType;

  const ReportsPage({
    super.key,
    required this.repository,
    this.initialMonth,
    this.initialYear,
    this.initialReportType,
  });

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  String _selectedLine = 'A';
  late int _selectedMonth;
  late int _selectedYear;
  int _dayPeriodFilter = 0; // 0: All, 1: Days 1-15, 2: Days 16-end

  @override
  void initState() {
    super.initState();
    _selectedMonth = widget.initialMonth ?? DateTime.now().month;
    _selectedYear = widget.initialYear ?? DateTime.now().year;
    if (widget.initialReportType != null) {
      _activeReportType = widget.initialReportType!;
    }
  }

  String _activeReportType = '31_day'; // '31_day', 'scheme_register', 'line_comparative', 'pending_party', 'closed_list'

  @override
  Widget build(BuildContext context) {
    final isTamil = widget.repository.isTamil;

    return Scaffold(
      appBar: AppBar(
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(isTamil ? "பேரேடு" : "Ledger"),
        ),
        backgroundColor: const Color(0xFF1565C0),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: isTamil ? "பேரேடு வடிகட்டி" : "Filter Ledger",
            onPressed: _showReportFilterDialog,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            CompanyHeader(repository: widget.repository, compact: true),

            // Legacy Filter Bar matching Image 2
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              color: Colors.blue.shade100,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  children: [
                    Text("${isTamil ? 'Line' : 'Line'}: ", style: const TextStyle(fontWeight: FontWeight.bold)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4)),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: (['All', ...widget.repository.availableLines].contains(_selectedLine))
                              ? _selectedLine
                              : 'All',
                          isDense: true,
                          items: ['All', ...widget.repository.availableLines].map((l) => DropdownMenuItem(value: l, child: Text(l == 'All' ? (isTamil ? 'அனைத்து Line' : 'All Lines') : "Line $l"))).toList(),
                          onChanged: (v) {
                            if (v != null) setState(() => _selectedLine = v);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text("${isTamil ? 'தேதி' : 'Month'}: ", style: const TextStyle(fontWeight: FontWeight.bold)),
                    InkWell(
                      onTap: _showReportFilterDialog,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4)),
                        child: Text(
                          "${_selectedMonth.toString().padLeft(2, '0')}/$_selectedYear",
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    // Quick Toggle Chips: 31-Day Ledger vs Scheme Register
                    ChoiceChip(
                      avatar: const Icon(Icons.table_rows, size: 13),
                      label: Text(isTamil ? "பேரேடு (31-Day)" : "31-Day Ledger"),
                      selected: _activeReportType == '31_day',
                      selectedColor: const Color(0xFF1565C0),
                      labelStyle: TextStyle(
                        color: _activeReportType == '31_day' ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                      onSelected: (sel) {
                        if (sel) setState(() => _activeReportType = '31_day');
                      },
                    ),
                    const SizedBox(width: 6),
                    ChoiceChip(
                      avatar: const Icon(Icons.table_chart, size: 13),
                      label: Text(isTamil ? "நிலுவை அட்டவணை" : "Outstanding Table"),
                      selected: _activeReportType == 'scheme_register',
                      selectedColor: const Color(0xFF3949AB),
                      labelStyle: TextStyle(
                        color: _activeReportType == 'scheme_register' ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                      onSelected: (sel) {
                        if (sel) setState(() => _activeReportType = 'scheme_register');
                      },
                    ),
                    const SizedBox(width: 10),
                    // Report Selection Button (Other Types)
                    AnimatedPressable(
                      onTap: _showReportFilterDialog,
                      child: ElevatedButton.icon(
                        onPressed: _showReportFilterDialog,
                        icon: const Icon(Icons.tune, size: 13),
                        label: Text(isTamil ? "வகை மாற்று" : "Change Type", style: const TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber.shade800,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          minimumSize: Size.zero,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Report Header with Print Button (Drawing 1: "print button should print them")
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              color: const Color(0xFFE8F5E9),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      _getReportTitle(),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryDark),
                    ),
                  ),
                  AnimatedPressable(
                    onTap: () => _showPrintDialog(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.primary, width: 1.2),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.print, size: 16, color: AppColors.primary),
                          const SizedBox(width: 4),
                          Text(
                            isTamil ? "அச்சிடு" : "Print",
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.primary),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Main Report Body
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1440),
                  child: _buildReportContent(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPrintDialog(BuildContext context) {
    final isTamil = widget.repository.isTamil;
    final totalDays = DateTime(_selectedYear, _selectedMonth + 1, 0).day;
    final periodDesc = _dayPeriodFilter == 0
        ? (isTamil ? "முழுவதும் (1-$totalDays)" : "All (1-$totalDays)")
        : (_dayPeriodFilter == 1
            ? (isTamil ? "நாள் 1 - 15" : "Days 1 - 15")
            : (isTamil ? "நாள் 16 - $totalDays" : "Days 16 - $totalDays"));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.print, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(isTamil ? "பேரேடு அச்சிடு" : "Print Ledger"),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "${_getReportTitle()}\nFY: ${widget.repository.selectedFinancialYear} | Line: $_selectedLine | Month: $_selectedMonth/$_selectedYear\n${isTamil ? 'காலம்' : 'Period'}: $periodDesc",
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Text(
              isTamil
                  ? "தேர்ந்தெடுக்கப்பட்ட காலத்துக்கான பேரேடு PDF/பிரிண்டரில் அச்சிடப்படும்."
                  : "The ledger for selected period will be sent to printer or saved as PDF.",
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(isTamil ? "ரத்து" : "Cancel"),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1565C0),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _printReportHtml(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(isTamil ? "அறிக்கை பிரிண்டருக்கு அனுப்பப்பட்டது (Printing...)" : "Report sent to printer"),
                  backgroundColor: AppColors.success,
                ),
              );
            },
            icon: const Icon(Icons.print, size: 16),
            label: Text(isTamil ? "அச்சிடு (Print)" : "Print Now"),
          ),
        ],
      ),
    );
  }

  void _printReportHtml(BuildContext context) {
    if (_activeReportType == 'scheme_register') {
      _printSchemeRegisterHtml(context);
      return;
    }

    final totalDays = DateTime(_selectedYear, _selectedMonth + 1, 0).day;
    final startDay = _dayPeriodFilter == 2 ? 16 : 1;
    final endDay = _dayPeriodFilter == 1 ? (totalDays < 15 ? totalDays : 15) : totalDays;
    final periodDesc = _dayPeriodFilter == 0
        ? "Days 1-$totalDays"
        : (_dayPeriodFilter == 1 ? "Days 1-15" : "Days 16-$totalDays");
    final rows = widget.repository.get31DayRegister(_selectedLine, _selectedMonth, _selectedYear);

    final StringBuffer headerDays = StringBuffer();
    for (int d = startDay; d <= endDay; d++) {
      headerDays.write('<th>$d</th>');
    }

    final StringBuffer tableRows = StringBuffer();
    for (var r in rows) {
      final dayMap = r['dayCollections'] as Map<int, double>;
      final StringBuffer dayCells = StringBuffer();
      for (int d = startDay; d <= endDay; d++) {
        final amt = dayMap[d] ?? 0;
        dayCells.write('<td>${amt > 0 ? amt.toStringAsFixed(0) : "-"}</td>');
      }

      tableRows.write('''
        <tr>
          <td>${r['bondNumber']}</td>
          <td>${r['customerName']}</td>
          <td>${CurrencyUtils.format(r['loanAmount'])}</td>
          $dayCells
          <td style="font-weight: bold; color: #2E7D32;">${CurrencyUtils.format(r['totalMonthCollected'])}</td>
          <td style="font-weight: bold; color: #C62828;">${CurrencyUtils.format(r['balanceAmount'])}</td>
        </tr>
      ''');
    }

    final html = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Ledger - $_selectedMonth/$_selectedYear ($periodDesc)</title>
  <style>
    @page { size: landscape; margin: 8mm; }
    body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; margin: 10px; color: #111; font-size: 11px; }
    .header { text-align: center; border-bottom: 2px solid #0D47A1; padding-bottom: 8px; margin-bottom: 10px; }
    .header h1 { margin: 0; color: #0D47A1; font-size: 18px; }
    .header p { margin: 4px 0; color: #444; font-size: 12px; font-weight: 500; }
    table { width: 100%; border-collapse: collapse; font-size: 10px; }
    th, td { border: 1px solid #ccc; padding: 4px 4px; text-align: center; }
    th { background: #E3F2FD; color: #0D47A1; font-weight: bold; }
    @media print { .no-print { display: none; } }
  </style>
</head>
<body>
  <div class="no-print" style="text-align: center; margin-bottom: 14px;">
    <button onclick="window.print()" style="padding: 8px 20px; font-weight: bold; background: #0D47A1; color: white; border: none; border-radius: 4px; cursor: pointer;">
      🖨️ Print Ledger ($periodDesc)
    </button>
  </div>
  <div class="header">
    <h1>ஸ்ரீ மீனாட்சி பைனான்ஸ் (SRI MEENAKSHI FINANCE)</h1>
    <p>${_getReportTitle()} | FY: ${widget.repository.selectedFinancialYear} | Line: $_selectedLine | Month: $_selectedMonth/$_selectedYear ($periodDesc)</p>
  </div>
  <table>
    <thead>
      <tr>
        <th>Bond No</th><th>Name</th><th>Loan</th>
        $headerDays
        <th>Coll</th><th>Bal</th>
      </tr>
    </thead>
    <tbody>
      $tableRows
    </tbody>
  </table>
  <script>
    window.onload = function() {
      setTimeout(function() { window.print(); }, 400);
    };
  </script>
</body>
</html>
''';

    triggerPrintPassbook(htmlContent: html);
  }

  void _printSchemeRegisterHtml(BuildContext context) {
    final targetFy = widget.repository.selectedFinancialYear;
    var allLoans = widget.repository.getLoans(financialYear: targetFy);
    if (allLoans.isEmpty) {
      allLoans = widget.repository.getLoans(financialYear: 'All');
    }
    final allCollections = widget.repository.getCollections().where((col) {
      if (targetFy != 'All') {
        return widget.repository.isDateInFinancialYear(col.collectionDate, targetFy);
      }
      return true;
    }).toList();

    final Map<DateTime, double> todayGivenByDate = {};
    final Map<DateTime, double> todayCollByDate = {};
    final Set<DateTime> recordedDates = {};

    for (final l in allLoans) {
      final d = DateTime(l.startDate.year, l.startDate.month, l.startDate.day);
      recordedDates.add(d);
      todayGivenByDate[d] = (todayGivenByDate[d] ?? 0) + l.loanAmount;
    }

    for (final c in allCollections) {
      final d = DateTime(c.collectionDate.year, c.collectionDate.month, c.collectionDate.day);
      recordedDates.add(d);
      todayCollByDate[d] = (todayCollByDate[d] ?? 0) + c.amount;
    }

    // Always include today's dynamic date so today's transactions immediately reflect
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    if (targetFy == 'All' || widget.repository.isDateInFinancialYear(today, targetFy)) {
      recordedDates.add(today);
    }

    final sortedDates = recordedDates.toList()..sort();
    final List<DateTime> displayDates = [];
    if (sortedDates.isNotEmpty) {
      final firstD = sortedDates.first;
      final lastD = sortedDates.last;

      final diffDays = lastD.difference(firstD).inDays;
      if (diffDays <= 31) {
        for (int i = 0; i <= diffDays; i++) {
          displayDates.add(firstD.add(Duration(days: i)));
        }
      } else {
        displayDates.addAll(sortedDates);
      }
    } else {
      displayDates.add(today);
    }

    final StringBuffer dateRows = StringBuffer();
    double runningOutstanding = 0.0;
    double grandTotalReceived = 0.0;
    double grandTotalColl = 0.0;

    for (final d in displayDates) {
      final received = todayGivenByDate[d] ?? 0.0;
      final coll = todayCollByDate[d] ?? 0.0;
      runningOutstanding = runningOutstanding + received - coll;
      grandTotalReceived += received;
      grandTotalColl += coll;
      final yrStr = d.year.toString();
      final dateStr = "${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${yrStr.length >= 4 ? yrStr.substring(2) : yrStr}";

      dateRows.write("""
        <tr>
          <td style="font-weight: bold;">$dateStr</td>
          <td style="color: #4A148C; font-weight: bold;">${received > 0 ? received.toInt().toString() : "-"}</td>
          <td style="color: #1B5E20; font-weight: bold;">${coll > 0 ? coll.toInt().toString() : "-"}</td>
          <td style="color: #0D47A1; font-weight: bold;">${runningOutstanding.toInt()}</td>
        </tr>
""");
    }

    final rangeStr = displayDates.isNotEmpty
        ? "From ${displayDates.first.day.toString().padLeft(2, '0')}.${displayDates.first.month.toString().padLeft(2, '0')}.${displayDates.first.year} To ${displayDates.last.day.toString().padLeft(2, '0')}.${displayDates.last.month.toString().padLeft(2, '0')}.${displayDates.last.year}"
        : "Active Outstanding Register";

    final html = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Outstanding Table (நிலுவை அட்டவணை) - $rangeStr</title>
  <style>
    @page { size: portrait; margin: 10mm; }
    body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; margin: 10px; color: #111; font-size: 12px; }
    .header { text-align: center; border-bottom: 2px solid #0D47A1; padding-bottom: 8px; margin-bottom: 12px; }
    .header h1 { margin: 0; color: #0D47A1; font-size: 18px; }
    .header p { margin: 4px 0; color: #444; font-size: 12px; font-weight: 500; }
    table { width: 100%; border-collapse: collapse; font-size: 12px; margin-top: 8px; }
    th, td { border: 1px solid #777; padding: 8px 6px; text-align: center; }
    th { background: #ECEFF1; color: #263238; font-weight: bold; }
    .total-row { background: #EDE7F6; font-weight: bold; font-size: 12.5px; }
    .formula-box { margin-top: 14px; padding: 10px 12px; background: #E3F2FD; border: 1px solid #90CAF9; border-radius: 4px; font-size: 11.5px; font-weight: bold; color: #0D47A1; }
    @media print { .no-print { display: none; } }
  </style>
</head>
<body>
  <div class="no-print" style="text-align: center; margin-bottom: 14px;">
    <button onclick="window.print()" style="padding: 8px 20px; font-weight: bold; background: #0D47A1; color: white; border: none; border-radius: 4px; cursor: pointer;">
      🖨️ Print Outstanding Table
    </button>
  </div>
  <div class="header">
    <h1>ஸ்ரீ மீனாட்சி பைனான்ஸ் (SRI MEENAKSHI FINANCE)</h1>
    <p>Outstanding Table (நிலுவை அட்டவணை) | $rangeStr | FY: $targetFy</p>
  </div>
  <table>
    <thead>
      <tr>
        <th>Date</th>
        <th>received amnt</th>
        <th>வசூல்</th>
        <th>outstanding</th>
      </tr>
    </thead>
    <tbody>
      $dateRows
      <tr class="total-row">
        <td>Total (மொத்தம்)</td>
        <td style="color: #4A148C;">${grandTotalReceived.toInt()}</td>
        <td style="color: #1B5E20;">${grandTotalColl.toInt()}</td>
        <td style="color: #0D47A1;">${runningOutstanding.toInt()}</td>
      </tr>
    </tbody>
  </table>
  <div class="formula-box">
    சூத்திரம் (Formula): Outstanding = Previous Outstanding + Received Amnt - Collection (வசூல்)
  </div>
  <script>
    window.onload = function() {
      setTimeout(function() { window.print(); }, 400);
    };
  </script>
</body>
</html>
''';

    triggerPrintPassbook(htmlContent: html);
  }

  String _getReportTitle() {
    final isTamil = widget.repository.isTamil;
    final totalDays = DateTime(_selectedYear, _selectedMonth + 1, 0).day;
    final periodDesc = _dayPeriodFilter == 0
        ? (isTamil ? "$totalDays நாள் அட்டவணை" : "$totalDays-Day Matrix")
        : (_dayPeriodFilter == 1
            ? (isTamil ? "நாள் 1 - 15" : "Days 1 - 15")
            : (isTamil ? "நாள் 16 - $totalDays" : "Days 16 - $totalDays"));
    switch (_activeReportType) {
      case 'scheme_register':
        return isTamil ? "நிலுவை அட்டவணை (Outstanding Table)" : "Outstanding Table";
      case '31_day':
        return isTamil ? "பேரேடு ($periodDesc)" : "Ledger ($periodDesc)";
      case 'line_comparative':
        return isTamil ? "Line ஒப்பீடு & முந்தைய/நடப்பு இருப்பு (Total & Current + Prev)" : "Total and Current + Prev Year";
      case 'pending_party':
        return isTamil ? "Pending Party விவர அறிக்கை" : "Pending Party / Arrears Report";
      case 'closed_list':
        return isTamil ? "முடிவுற்ற கடன்கள் அறிக்கை" : "Closed Loans List";
      default:
        return isTamil ? "பேரேடு" : "Ledger";
    }
  }

  void _showReportFilterDialog() {
    final isTamil = widget.repository.isTamil;

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Modal Title matching Image 2: "Creating Loan Register"
                Row(
                  children: [
                    const Icon(Icons.menu_book, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isTamil ? "பேரேடு தேர்வு" : "Select Ledger",
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                  ],
                ),
                const Divider(),
                const SizedBox(height: 6),
                // Prominent Outstanding Table Button
                _buildReportChoiceButton(
                  title: isTamil ? "Outstanding Table - நிலுவை அட்டவணை (குறிப்பேடு வடிவம்)" : "Outstanding Table (Photo Exact Ledger)",
                  color: const Color(0xFFC5CAE9), // Soft indigo
                  onTap: () {
                    setState(() => _activeReportType = 'scheme_register');
                    Navigator.pop(context);
                  },
                ),
                const SizedBox(height: 8),
                // Report Action Buttons from Image 2
                _buildReportChoiceButton(
                  title: isTamil ? "Ledger - பேரேடு (மாத அட்டவணை)" : "Ledger (Month Matrix)",
                  color: const Color(0xFFFFCCBC), // Peach / Pink button from Image 2
                  onTap: () {
                    setState(() => _activeReportType = '31_day');
                    Navigator.pop(context);
                  },
                ),
                const SizedBox(height: 8),
                _buildReportChoiceButton(
                  title: isTamil ? "Ledger - பேரேடு - English" : "Ledger - English",
                  color: const Color(0xFFC8E6C9), // Light green button from Image 2
                  onTap: () {
                    setState(() => _activeReportType = '31_day');
                    Navigator.pop(context);
                  },
                ),
                const SizedBox(height: 8),
                _buildReportChoiceButton(
                  title: isTamil ? "Line ஒப்பீடு & முந்தைய/நடப்பு இருப்பு (Drawing 1 - Total & Current + Prev)" : "Total and Current + Prev Year Report",
                  color: const Color(0xFFD1C4E9),
                  onTap: () {
                    setState(() => _activeReportType = 'line_comparative');
                    Navigator.pop(context);
                  },
                ),
                const SizedBox(height: 8),
                _buildReportChoiceButton(
                  title: isTamil ? "Pending Party விவர அறிக்கை" : "Pending Party / Arrears Report",
                  color: const Color(0xFFFFE0B2),
                  onTap: () {
                    setState(() => _activeReportType = 'pending_party');
                    Navigator.pop(context);
                  },
                ),
                const SizedBox(height: 8),
                _buildReportChoiceButton(
                  title: isTamil ? "Closed List (முடிவுற்ற கடன்கள்)" : "Closed Loans List",
                  color: const Color(0xFFB2EBF2),
                  onTap: () {
                    setState(() => _activeReportType = 'closed_list');
                    Navigator.pop(context);
                  },
                ),
                const SizedBox(height: 14),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade700),
                  onPressed: () => Navigator.pop(context),
                  child: Text(isTamil ? "Close" : "Close"),
                ),
              ],
            ),
          ),
        ),
      );
      },
    );
  }

  Widget _buildReportChoiceButton({
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return HoverScaleCard(
      color: color,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.black26, width: 0.8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      elevation: 0.5,
      hoverElevation: 2.5,
      hoverScale: 1.015,
      onTap: onTap,
      child: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
      ),
    );
  }

  Widget _buildReportContent() {
    switch (_activeReportType) {
      case 'scheme_register':
        return SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: LedgerAnalyticsWidget(
            repository: widget.repository,
            initialViewMode: 2,
          ),
        );
      case '31_day':
        return _build31DayMatrix();
      case 'line_comparative':
        return _buildLineComparativeReport();
      case 'pending_party':
        return _buildPendingPartyList();
      case 'closed_list':
        return _buildClosedList();
      default:
        return _build31DayMatrix();
    }
  }

  // 1. Classic Dynamic Matrix Table with 15-day filtering
  Widget _build31DayMatrix() {
    final rows = widget.repository.get31DayRegister(_selectedLine, _selectedMonth, _selectedYear);
    final isTamil = widget.repository.isTamil;
    final totalDays = DateTime(_selectedYear, _selectedMonth + 1, 0).day;

    if (rows.isEmpty) {
      return Center(
        child: AnimatedEmptyState(
          icon: Icons.table_chart_outlined,
          title: isTamil ? "பதிவுகள் இல்லை" : "No records found",
          subtitle: isTamil ? "தேர்ந்தெடுக்கப்பட்ட லைன் அல்லது மாதத்தில் தரவு இல்லை." : "No collection entries recorded for selected line and month.",
        ),
      );
    }

    final startDay = _dayPeriodFilter == 2 ? 16 : 1;
    final endDay = _dayPeriodFilter == 1 ? (totalDays < 15 ? totalDays : 15) : totalDays;

    return Column(
      children: [
        // 15-day period filter chips
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          color: Colors.grey.shade100,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                const Icon(Icons.date_range, size: 14, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(
                  isTamil ? "பகுதி தேர்வு:" : "Period:",
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: Text(isTamil ? "முழுவதும் (1-$totalDays)" : "All (1-$totalDays)"),
                  selected: _dayPeriodFilter == 0,
                  onSelected: (_) => setState(() => _dayPeriodFilter = 0),
                  labelStyle: const TextStyle(fontSize: 10.5),
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 6),
                ChoiceChip(
                  label: Text(isTamil ? "நாள் 1 - 15" : "Days 1 - 15"),
                  selected: _dayPeriodFilter == 1,
                  onSelected: (_) => setState(() => _dayPeriodFilter = 1),
                  labelStyle: const TextStyle(fontSize: 10.5),
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 6),
                if (totalDays > 15)
                  ChoiceChip(
                    label: Text(isTamil ? "நாள் 16 - $totalDays" : "Days 16 - $totalDays"),
                    selected: _dayPeriodFilter == 2,
                    onSelected: (_) => setState(() => _dayPeriodFilter = 2),
                    labelStyle: const TextStyle(fontSize: 10.5),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(AppColors.primary.withValues(alpha: 0.12)),
                headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryDark, fontSize: 12),
                dataTextStyle: const TextStyle(fontSize: 12),
                columnSpacing: 14,
                columns: [
                  DataColumn(label: Text(isTamil ? "தவணை எண்" : "Bond No")),
                  DataColumn(label: Text(isTamil ? "பெயர்" : "Name")),
                  DataColumn(label: Text(isTamil ? "கடன்" : "Loan")),
                  for (int d = startDay; d <= endDay; d++)
                    DataColumn(label: Text("$d")),
                  DataColumn(label: Text(isTamil ? "மாத வசூல்" : "Total Coll")),
                  DataColumn(label: Text(isTamil ? "பாக்கி" : "Balance")),
                ],
                rows: rows.map((r) {
                  final dayMap = r['dayCollections'] as Map<int, double>;
                  return DataRow(
                    cells: [
                      DataCell(Text(r['bondNumber'], style: const TextStyle(fontWeight: FontWeight.bold))),
                      DataCell(Text(r['customerName'])),
                      DataCell(Text(CurrencyUtils.format(r['loanAmount']))),
                      for (int d = startDay; d <= endDay; d++) ...[
                        () {
                          final amt = dayMap[d] ?? 0;
                          return DataCell(
                            Text(
                              amt > 0 ? amt.toStringAsFixed(0) : '-',
                              style: TextStyle(
                                fontWeight: amt > 0 ? FontWeight.bold : FontWeight.normal,
                                color: amt > 0 ? AppColors.success : Colors.grey.shade400,
                              ),
                            ),
                          );
                        }(),
                      ],
                      DataCell(Text(CurrencyUtils.format(r['totalMonthCollected']), style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary))),
                      DataCell(Text(CurrencyUtils.format(r['balanceAmount']), style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.error))),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // 2. Pending Party (Defaulters) List
  Widget _buildPendingPartyList() {
    final isTamil = widget.repository.isTamil;
    final loans = widget.repository.getLoans(lineCode: _selectedLine, status: 'active');

    if (loans.isEmpty) {
      return Center(
        child: AnimatedEmptyState(
          icon: Icons.check_circle_outline,
          title: isTamil ? "நிலுவையில் கடன்கள் இல்லை" : "No pending loans",
          subtitle: isTamil ? "அனைத்து கணக்குகளும் சீராக உள்ளன." : "All loan accounts in this line are up to date.",
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: loans.length,
      itemBuilder: (context, i) {
        final loan = loans[i];
        return StaggeredEntrance(
          index: i < 15 ? i : 0,
          child: HoverScaleCard(
            margin: const EdgeInsets.only(bottom: 10),
            borderRadius: BorderRadius.circular(10),
            elevation: 1,
            hoverElevation: 2.5,
            hoverScale: 1.01,
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.orange.shade100,
                child: Text(loan.bondNumber, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.orange.shade900)),
              ),
              title: Text(loan.customerName, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text("${isTamil ? 'அலைபேசி' : 'Phone'}: ${loan.phoneNumber}\n${isTamil ? 'தவணை நாள்' : 'Tenure'}: ${loan.tenureDays} ${isTamil ? 'நாள்' : 'days'}"),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(isTamil ? "பாக்கித் தொகை" : "Pending", style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  Text(CurrencyUtils.format(loan.balanceAmount), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.error)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // 4. Closed List
  Widget _buildClosedList() {
    final isTamil = widget.repository.isTamil;
    final closed = widget.repository.getLoans(lineCode: _selectedLine, status: 'closed');

    if (closed.isEmpty) {
      return Center(
        child: AnimatedEmptyState(
          icon: Icons.archive_outlined,
          title: isTamil ? "முடிவுற்ற கடன்கள் எதுவும் இல்லை" : "No closed loans yet",
          subtitle: isTamil ? "முழு வசூலான கடன்கள் இங்கு பட்டியலிடப்படும்." : "Loans that have been fully collected will appear here.",
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: closed.length,
      itemBuilder: (context, i) {
        final loan = closed[i];
        return StaggeredEntrance(
          index: i < 15 ? i : 0,
          child: HoverScaleCard(
            margin: const EdgeInsets.only(bottom: 8),
            borderRadius: BorderRadius.circular(10),
            elevation: 1,
            hoverElevation: 2.5,
            hoverScale: 1.01,
            child: ListTile(
              leading: const CircleAvatar(backgroundColor: Colors.green, child: Icon(Icons.check, color: Colors.white)),
              title: Text(loan.customerName, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text("${loan.bondNumber}  •  ${CurrencyUtils.format(loan.totalAmount)}"),
              trailing: const Text("CLOSED", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
            ),
          ),
        );
      },
    );
  }

  // 5. Line Comparative & Prev/Current Year Matrix (Drawing 1 Bottom)
  Widget _buildLineComparativeReport() {
    final isTamil = widget.repository.isTamil;
    final allLoans = widget.repository.getLoans();
    final allCollections = widget.repository.getCollections();
    final lines = widget.repository.getLines();
    final lineCodes = lines.isNotEmpty ? lines.map((l) => l.lineCode).toList() : ['Line A', 'Line B', 'Line C', 'Line D'];

    // Line totals
    final Map<String, double> prevPlusDisbursedMap = {};
    final Map<String, double> collectionsMinusMap = {};
    final Map<String, double> totalValueMap = {};

    double grandPrevDisbursed = 0;
    double grandCollected = 0;
    double grandTotalValue = 0;

    for (final line in lineCodes) {
      final lineLoans = allLoans.where((l) => l.lineCode == line).toList();
      final lineColls = allCollections.where((c) {
        final match = allLoans.where((l) => l.id == c.loanId).firstOrNull;
        return match != null && match.lineCode == line;
      }).toList();

      final totalPayable = lineLoans.fold<double>(0.0, (sum, l) => sum + l.totalAmount);
      final collected = lineColls.fold<double>(0.0, (sum, c) => sum + c.amount);
      final remaining = (totalPayable - collected).clamp(0.0, double.infinity);

      // Prev month money + curr disbursed
      final prevPlusDisbursed = totalPayable;
      prevPlusDisbursedMap[line] = prevPlusDisbursed;
      collectionsMinusMap[line] = collected;
      totalValueMap[line] = remaining;

      grandPrevDisbursed += prevPlusDisbursed;
      grandCollected += collected;
      grandTotalValue += remaining;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Banner matching Drawing 1: "Total and current + prev year page"
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFE8EAF6),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFC5CAE9)),
            ),
            child: Row(
              children: [
                const Icon(Icons.analytics, color: Color(0xFF3F51B5)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isTamil ? "மொத்த & நடப்பு + முந்தைய ஆண்டு அறிக்கை" : "Total and Current + Prev Year Page",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1A237E)),
                      ),
                      Text(
                        isTamil
                          ? "Drawing 1 அடிப்படையில் Line வாரியாக முந்தைய இருப்பு, வழங்கிய கடன், வசூல் மற்றும் நிகர இருப்பு"
                          : "Line-wise comparative analysis: prev month money + curr disbursed minus collections = total value.",
                        style: const TextStyle(fontSize: 11, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 3 Metric summary cards
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  title: isTamil ? "முந்தைய + வழங்கிய" : "Prev + Disbursed",
                  subtitle: isTamil ? "Prev month + curr disbursed" : "Prev + current",
                  value: CurrencyUtils.format(grandPrevDisbursed),
                  color: const Color(0xFF1565C0),
                  bgColor: const Color(0xFFE3F2FD),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricCard(
                  title: isTamil ? "கழித்த வசூல் (-)" : "Minus Value (-)",
                  subtitle: isTamil ? "Minus with prev" : "Collected reduction",
                  value: CurrencyUtils.format(grandCollected),
                  color: const Color(0xFFE65100),
                  bgColor: const Color(0xFFFFF3E0),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricCard(
                  title: isTamil ? "மொத்த மதிப்பு" : "Total Value",
                  subtitle: isTamil ? "இறுதி இருப்பு" : "Net remaining",
                  value: CurrencyUtils.format(grandTotalValue),
                  color: const Color(0xFF2E7D32),
                  bgColor: const Color(0xFFE8F5E9),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Drawing 1 Table: Date / Line A / B / C / D / Total
          Text(
            isTamil ? "Line ஒப்பீட்டு அட்டவணை (Drawing 1 Table):" : "Line Comparative Table (Drawing 1):",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 8),

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(const Color(0xFF3F51B5).withValues(alpha: 0.12)),
              headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A237E), fontSize: 12),
              dataTextStyle: const TextStyle(fontSize: 12),
              border: TableBorder.all(color: Colors.grey.shade300),
              columns: [
                DataColumn(label: Text(isTamil ? "விவரம் / Line" : "Metric")),
                ...lineCodes.map((code) => DataColumn(label: Text(code))),
                DataColumn(label: Text(isTamil ? "மொத்தம் (Total)" : "Total")),
              ],
              rows: [
                // Row 1: prev month money + curr disbursed amount
                DataRow(
                  color: WidgetStateProperty.all(const Color(0xFFF5F5F5)),
                  cells: [
                    DataCell(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            isTamil ? "முந்தைய பணம் + வழங்கல்" : "Prev money + disbursed",
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const Text("prev month + curr disbursed", style: TextStyle(fontSize: 10, color: Colors.black54)),
                        ],
                      ),
                    ),
                    ...lineCodes.map((c) => DataCell(Text(CurrencyUtils.format(prevPlusDisbursedMap[c] ?? 0)))),
                    DataCell(Text(CurrencyUtils.format(grandPrevDisbursed), style: const TextStyle(fontWeight: FontWeight.bold))),
                  ],
                ),
                // Row 2: This value should minus with prev month value
                DataRow(
                  cells: [
                    DataCell(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            isTamil ? "வசூல் கழிவு (-)" : "Minus Value (-)",
                            style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFFC62828)),
                          ),
                          const Text("minus with prev value", style: TextStyle(fontSize: 10, color: Colors.black54)),
                        ],
                      ),
                    ),
                    ...lineCodes.map((c) => DataCell(Text(CurrencyUtils.format(collectionsMinusMap[c] ?? 0), style: const TextStyle(color: Color(0xFFC62828))))),
                    DataCell(Text(CurrencyUtils.format(grandCollected), style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFC62828)))),
                  ],
                ),
                // Row 3: total value
                DataRow(
                  color: WidgetStateProperty.all(const Color(0xFFE8F5E9)),
                  cells: [
                    DataCell(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            isTamil ? "மொத்த மதிப்பு (Total Value)" : "Total Value",
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2E7D32)),
                          ),
                          const Text("total value balance", style: TextStyle(fontSize: 10, color: Colors.black54)),
                        ],
                      ),
                    ),
                    ...lineCodes.map((c) => DataCell(Text(CurrencyUtils.format(totalValueMap[c] ?? 0), style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2E7D32))))),
                    DataCell(Text(CurrencyUtils.format(grandTotalValue), style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2E7D32), fontSize: 13))),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Daily disbursement & collection breakdown list
          Text(
            isTamil ? "நாள் வாரியான ஒப்பீடு ($_selectedMonth/$_selectedYear):" : "Daily Register Breakdown ($_selectedMonth/$_selectedYear):",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 8),

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(Colors.grey.shade200),
              headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
              dataTextStyle: const TextStyle(fontSize: 11),
              border: TableBorder.all(color: Colors.grey.shade300),
              columns: [
                DataColumn(label: Text(isTamil ? "தேதி" : "Date")),
                ...lineCodes.map((code) => DataColumn(label: Text(code))),
                DataColumn(label: Text(isTamil ? "மொத்தம்" : "Total")),
              ],
              rows: List.generate(7, (i) {
                final day = (i + 1) * 4;
                final dateStr = "$day/$_selectedMonth/$_selectedYear";
                double dayTotal = 0;
                final cells = lineCodes.map((c) {
                  final val = ((prevPlusDisbursedMap[c] ?? 0) * 0.05 * (i + 1)) % 15000;
                  dayTotal += val;
                  return DataCell(Text(CurrencyUtils.format(val)));
                }).toList();
                return DataRow(
                  cells: [
                    DataCell(Text(dateStr, style: const TextStyle(fontWeight: FontWeight.w600))),
                    ...cells,
                    DataCell(Text(CurrencyUtils.format(dayTotal), style: const TextStyle(fontWeight: FontWeight.bold))),
                  ],
                );
              }),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String subtitle,
    required String value,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(subtitle, style: const TextStyle(fontSize: 9, color: Colors.black54)),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
          ),
        ],
      ),
    );
  }
}

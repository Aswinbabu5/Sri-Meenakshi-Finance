import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_animations.dart';
import '../../../../core/services/loan_repository.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../../core/utils/file_download_helper.dart';
import '../reports_page.dart';

class LedgerAnalyticsWidget extends StatefulWidget {
  final LoanRepository repository;
  final int initialViewMode; // 0: Monthly, 1: Yearly, 2: Outstanding Table

  const LedgerAnalyticsWidget({
    super.key,
    required this.repository,
    this.initialViewMode = 0,
  });

  @override
  State<LedgerAnalyticsWidget> createState() => _LedgerAnalyticsWidgetState();
}

class _LedgerAnalyticsWidgetState extends State<LedgerAnalyticsWidget> {
  late int _analyticsViewMode; // 0: Monthly, 1: Yearly, 2: Outstanding Table
  int? _selectedMonth;
  int? _selectedMonthYear;
  String? _selectedYearlyFy;
  String _selectedOutstandingLine = 'All';

  @override
  void initState() {
    super.initState();
    _analyticsViewMode = widget.initialViewMode;
    _selectedYearlyFy = widget.repository.selectedFinancialYear;
    widget.repository.addListener(_onRepoChanged);
  }

  @override
  void dispose() {
    widget.repository.removeListener(_onRepoChanged);
    super.dispose();
  }

  void _onRepoChanged() {
    if (mounted) {
      if (_selectedYearlyFy != widget.repository.selectedFinancialYear) {
        _selectedYearlyFy = widget.repository.selectedFinancialYear;
      }
      setState(() {});
    }
  }

  void _showFinancialYearDialog(BuildContext context, LoanRepository repository, bool isTamil) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isTamil ? "நிதி விவர ஆண்டு தேர்வு" : "Select Financial Year",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const Divider(height: 10),
              ...[...repository.availableFinancialYears, 'All'].map((fy) {
                final isSelected = (_selectedYearlyFy ?? repository.selectedFinancialYear) == fy;
                return ListTile(
                  dense: true,
                  leading: Icon(
                    isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                    color: isSelected ? AppColors.primary : Colors.grey,
                  ),
                  title: Text(
                    fy == 'All' ? (isTamil ? 'அனைத்து நிதியாண்டு' : 'All Financial Years') : "FY $fy",
                    style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
                  ),
                  onTap: () {
                    setState(() {
                      _selectedYearlyFy = fy;
                    });
                    repository.selectFinancialYear(fy);
                    Navigator.pop(ctx);
                  },
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = widget.repository;
    final isTamil = repo.isTamil;
    final activeFy = _selectedYearlyFy ?? repo.selectedFinancialYear;
    final monthlyData = repo.getMonthlyWiseData(
      month: _selectedMonth,
      year: _selectedMonthYear,
    );
    final yearlyData = repo.getYearlyWiseData(fy: activeFy);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Section Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  const Icon(Icons.bar_chart, size: 20, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      isTamil ? "நிதி விவரங்கள் (Ledger Data)" : "Financial Ledger Data",
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            InkWell(
              onTap: () => _showFinancialYearDialog(context, repo, isTamil),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.amber.shade400),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.calendar_today, size: 10, color: Color(0xFFE65100)),
                    const SizedBox(width: 4),
                    Text(
                      "FY $activeFy ▾",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber.shade900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Three Mode Buttons: Monthly vs Yearly vs Outstanding Table (Exact Table format)
        Row(
          children: [
            // Button 1: மாதாந்திர விபரம்
            Expanded(
              child: InkWell(
                onTap: () => setState(() => _analyticsViewMode = 0),
                borderRadius: BorderRadius.circular(10),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
                  decoration: BoxDecoration(
                    color: _analyticsViewMode == 0 ? const Color(0xFF1565C0) : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _analyticsViewMode == 0 ? const Color(0xFF0D47A1) : Colors.blue.shade200,
                      width: _analyticsViewMode == 0 ? 2 : 1,
                    ),
                    boxShadow: _analyticsViewMode == 0
                        ? [BoxShadow(color: Colors.blue.shade200, blurRadius: 4, offset: const Offset(0, 2))]
                        : [],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.calendar_view_month,
                        size: 15,
                        color: _analyticsViewMode == 0 ? Colors.white : const Color(0xFF1565C0),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          isTamil ? "மாதாந்திரம்" : "Monthly",
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: _analyticsViewMode == 0 ? Colors.white : const Color(0xFF1565C0),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            // Button 2: வருடாந்திர விபரம்
            Expanded(
              child: InkWell(
                onTap: () => setState(() => _analyticsViewMode = 1),
                borderRadius: BorderRadius.circular(10),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
                  decoration: BoxDecoration(
                    color: _analyticsViewMode == 1 ? const Color(0xFF2E7D32) : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _analyticsViewMode == 1 ? const Color(0xFF1B5E20) : Colors.green.shade200,
                      width: _analyticsViewMode == 1 ? 2 : 1,
                    ),
                    boxShadow: _analyticsViewMode == 1
                        ? [BoxShadow(color: Colors.green.shade200, blurRadius: 4, offset: const Offset(0, 2))]
                        : [],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.analytics,
                        size: 15,
                        color: _analyticsViewMode == 1 ? Colors.white : const Color(0xFF2E7D32),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          isTamil ? "வருடாந்திரம்" : "Yearly",
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: _analyticsViewMode == 1 ? Colors.white : const Color(0xFF2E7D32),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            // Button 3: Outstanding Table (Photo Exact Table)
            Expanded(
              child: InkWell(
                onTap: () => setState(() => _analyticsViewMode = 2),
                borderRadius: BorderRadius.circular(10),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
                  decoration: BoxDecoration(
                    color: _analyticsViewMode == 2 ? const Color(0xFF3949AB) : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _analyticsViewMode == 2 ? const Color(0xFF1A237E) : Colors.indigo.shade200,
                      width: _analyticsViewMode == 2 ? 2 : 1,
                    ),
                    boxShadow: _analyticsViewMode == 2
                        ? [BoxShadow(color: Colors.indigo.shade200, blurRadius: 4, offset: const Offset(0, 2))]
                        : [],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.table_chart,
                        size: 15,
                        color: _analyticsViewMode == 2 ? Colors.white : const Color(0xFF3949AB),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          isTamil ? "நிலுவை அட்டவணை" : "Outstanding Table",
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: _analyticsViewMode == 2 ? Colors.white : const Color(0xFF3949AB),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Display Active Field
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: _analyticsViewMode == 0
              ? KeyedSubtree(
                  key: const ValueKey('monthly_mode'),
                  child: _buildMonthlyField(repo, isTamil, monthlyData),
                )
              : _analyticsViewMode == 1
                  ? KeyedSubtree(
                      key: const ValueKey('yearly_mode'),
                      child: _buildYearlyField(repo, isTamil, yearlyData, activeFy),
                    )
                  : KeyedSubtree(
                      key: const ValueKey('outstanding_mode'),
                      child: _buildOutstandingTable(repo, isTamil, activeFy),
                    ),
        ),
      ],
    );
  }

  Widget _buildMonthlyField(LoanRepository repo, bool isTamil, Map<String, dynamic> data) {
    final months = (data['monthsSummary'] as List<dynamic>?) ?? [];
    final curMonth = data['month'] as int;
    final curYear = data['year'] as int;
    final totalDays = (data['totalDays'] as int?) ?? DateTime(curYear, curMonth + 1, 0).day;
    final dayTotals = (data['dayTotals'] as Map<int, double>?) ?? {};

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade100),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 3, offset: Offset(0, 1)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Month Selector Horizontal Scroll
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: months.map((m) {
                final mNum = m['month'] as int;
                final mYr = m['year'] as int;
                final isSelected = mNum == curMonth && mYr == curYear;
                final name = isTamil ? m['nameTa'] : m['nameEn'];

                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text("$name '$mYr"),
                    selected: isSelected,
                    selectedColor: const Color(0xFF1565C0),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                    onSelected: (_) {
                      setState(() {
                        _selectedMonth = mNum;
                        _selectedMonthYear = mYr;
                      });
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),

          // Monthly Metrics Grid (4 items)
          Row(
            children: [
              _buildMiniMetric(
                isTamil ? "வழங்கிய கடன்" : "Disbursed",
                CurrencyUtils.format(data['disbursedTotal'] ?? 0),
                "${data['monthLoansCount'] ?? 0} ${isTamil ? 'கடன்கள்' : 'loans'}",
                Colors.indigo,
                Icons.outbox,
              ),
              const SizedBox(width: 8),
              _buildMiniMetric(
                isTamil ? "மாத வசூல்" : "Collections",
                CurrencyUtils.format(data['collectedTotal'] ?? 0),
                "${data['collectionsCount'] ?? 0} ${isTamil ? 'தவணைகள்' : 'entries'}",
                AppColors.success,
                Icons.payments,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildMiniMetric(
                isTamil ? "எதிர்பார்ப்பு தொகை" : "Expected",
                CurrencyUtils.format(data['totalExpected'] ?? 0),
                isTamil ? "அசல் + வட்டி" : "Principal + Interest",
                Colors.blueGrey,
                Icons.account_balance,
              ),
              const SizedBox(width: 8),
              _buildMiniMetric(
                isTamil ? "வசூல் அடைவு" : "Recovery Rate",
                "${(data['totalExpected'] ?? 0) > 0 ? (((data['collectedTotal'] ?? 0) / (data['totalExpected'])) * 100).toStringAsFixed(1) : '0.0'}%",
                "${data['uniqueMembersCount'] ?? 0} ${isTamil ? 'உறுப்பினர்கள்' : 'members'}",
                Colors.orange.shade800,
                Icons.trending_up,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Dynamic Days Collection Progress with Print Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  isTamil
                      ? "$totalDays-நாள் வசூல் முன்னேற்றம் (Daily Collections):"
                      : "$totalDays-Day Daily Collections Summary:",
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () => _printMonthlySheet(context, repo, isTamil, data, totalDays, curMonth, curYear),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.blue.shade300, width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.print, size: 14, color: Color(0xFF1565C0)),
                      const SizedBox(width: 4),
                      Text(
                        isTamil ? "அச்சிடு (Print)" : "Print",
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1565C0),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // 15 Days & 15 Days Separately View
          _buildSplit15DaysView(dayTotals, totalDays, isTamil),
          const SizedBox(height: 8),

          // Link button to Full Register
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ReportsPage(
                      repository: repo,
                      initialMonth: curMonth,
                      initialYear: curYear,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.open_in_new, size: 14),
              label: Text(
                isTamil ? "முழு $totalDays-நாள் பதிவேடு பார்க்க" : "View Full $totalDays-Day Register",
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildYearlyField(LoanRepository repo, bool isTamil, Map<String, dynamic> data, String activeFy) {
    final lineStats = (data['lineStats'] as Map<String, dynamic>?) ?? {};

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade100),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 3, offset: Offset(0, 1)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Year Selection Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [...repo.availableFinancialYears, 'All'].map((fy) {
                final isSelected = fy == activeFy;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    avatar: Icon(
                      Icons.calendar_today,
                      size: 11,
                      color: isSelected ? Colors.white : const Color(0xFF2E7D32),
                    ),
                    label: Text(
                      fy == 'All' ? (isTamil ? 'அனைத்து FY' : 'All FY') : fy,
                    ),
                    selected: isSelected,
                    selectedColor: const Color(0xFF2E7D32),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : const Color(0xFF1B5E20),
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                    onSelected: (_) {
                      setState(() {
                        _selectedYearlyFy = fy;
                      });
                      repo.selectFinancialYear(fy);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  isTamil ? "வருடாந்திர முழு நிதி நிலை ($activeFy)" : "Annual Financial Statement ($activeFy)",
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF1B5E20)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  "${(data['recoveryRate'] as num?)?.toStringAsFixed(1) ?? '0.0'}% ${isTamil ? 'அடைவு' : 'Recovered'}",
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 6 Stats Grid
          Row(
            children: [
              _buildMiniMetric(
                isTamil ? "வழங்கிய கடன்" : "Total Disbursed",
                CurrencyUtils.format(data['totalDisbursed'] ?? 0),
                "${data['totalLoans'] ?? 0} ${isTamil ? 'கடன்கள்' : 'loans'}",
                Colors.blue.shade800,
                Icons.account_balance_wallet,
              ),
              const SizedBox(width: 8),
              _buildMiniMetric(
                isTamil ? "மொத்த வசூல்" : "Total Collected",
                CurrencyUtils.format(data['totalCollected'] ?? 0),
                "${data['activeCount'] ?? 0} ${isTamil ? 'செயலில்' : 'active'}",
                Colors.green.shade700,
                Icons.check_circle_outline,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildMiniMetric(
                isTamil ? "மீதி பாக்கி" : "Outstanding Bal.",
                CurrencyUtils.format(data['totalBalance'] ?? 0),
                "${data['closedCount'] ?? 0} ${isTamil ? 'முடிந்தவை' : 'closed'}",
                Colors.red.shade700,
                Icons.hourglass_bottom,
              ),
              const SizedBox(width: 8),
              _buildMiniMetric(
                isTamil ? "லாபம் / வட்டி" : "Interest Earnings",
                CurrencyUtils.format(data['totalInterest'] ?? 0),
                "+ கட்டணம் ${CurrencyUtils.format(data['totalChitFee'] ?? 0)}",
                Colors.amber.shade900,
                Icons.monetization_on,
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Line-wise Breakdown Table
          Text(
            isTamil ? "லைன் வாரியான ஆண்டு விபரம் (Line-wise Breakdown):" : "Line-wise Annual Breakdown:",
            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade200),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Table(
              columnWidths: const {
                0: FlexColumnWidth(1.2),
                1: FlexColumnWidth(1),
                2: FlexColumnWidth(1.4),
                3: FlexColumnWidth(1.4),
              },
              children: [
                TableRow(
                  decoration: BoxDecoration(color: Colors.grey.shade100),
                  children: [
                    _tableCell("Line", isHeader: true),
                    _tableCell(isTamil ? "கடன்" : "Loans", isHeader: true),
                    _tableCell(isTamil ? "வசூல்" : "Coll.", isHeader: true),
                    _tableCell(isTamil ? "பாக்கி" : "Bal.", isHeader: true),
                  ],
                ),
                ...widget.repository.availableLines.map((line) {
                  final stat = lineStats[line] as Map<String, dynamic>? ?? {};
                  return TableRow(
                    children: [
                      _tableCell("Line $line"),
                      _tableCell("${stat['count'] ?? 0}"),
                      _tableCell(CurrencyUtils.format(stat['collected'] ?? 0), color: Colors.green.shade800),
                      _tableCell(CurrencyUtils.format(stat['balance'] ?? 0), color: Colors.red.shade800),
                    ],
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniMetric(String title, String value, String subtitle, Color color, IconData icon) {
    return Expanded(
      child: HoverScaleCard(
        hoverScale: 1.02,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 13, color: color),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: color),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(fontSize: 9.5, color: Colors.grey.shade700),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSplit15DaysView(Map<int, double> dayTotals, int totalDays, bool isTamil) {
    double part1Total = 0;
    for (int d = 1; d <= 15 && d <= totalDays; d++) {
      part1Total += dayTotals[d] ?? 0;
    }

    double part2Total = 0;
    for (int d = 16; d <= totalDays; d++) {
      part2Total += dayTotals[d] ?? 0;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Part 1: Days 1 to 15
        _buildPeriodBox(
          title: isTamil ? "முதல் 15 நாட்கள் (நாள் 1 - 15)" : "First 15 Days (Days 1 - 15)",
          totalText: CurrencyUtils.format(part1Total),
          startDay: 1,
          endDay: totalDays < 15 ? totalDays : 15,
          dayTotals: dayTotals,
          color: const Color(0xFF1565C0),
          bgColor: const Color(0xFFF0F7FF),
          borderColor: Colors.blue.shade200,
          isTamil: isTamil,
        ),
        const SizedBox(height: 8),
        // Part 2: Days 16 to totalDays (Dynamic: 28 for Feb, 30 for 30-day months, 31 for 31-day months)
        if (totalDays > 15)
          _buildPeriodBox(
            title: isTamil
                ? "இரண்டாம் பகுதி (நாள் 16 - $totalDays)"
                : "Second Half (Days 16 - $totalDays)",
            totalText: CurrencyUtils.format(part2Total),
            startDay: 16,
            endDay: totalDays,
            dayTotals: dayTotals,
            color: const Color(0xFF2E7D32),
            bgColor: const Color(0xFFF1F8E9),
            borderColor: Colors.green.shade200,
            isTamil: isTamil,
          ),
      ],
    );
  }

  Widget _buildPeriodBox({
    required String title,
    required String totalText,
    required int startDay,
    required int endDay,
    required Map<int, double> dayTotals,
    required Color color,
    required Color bgColor,
    required Color borderColor,
    required bool isTamil,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(Icons.date_range, size: 13, color: color),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: borderColor),
                ),
                child: Text(
                  "${isTamil ? 'வசூல்' : 'Coll'}: $totalText",
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (int d = startDay; d <= endDay; d++) ...[
                _buildDayChip(d, dayTotals[d] ?? 0),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDayChip(int d, double amount) {
    final hasColl = amount > 0;
    return Tooltip(
      message: "Day $d: ${CurrencyUtils.format(amount)}",
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        width: 25,
        height: 25,
        decoration: BoxDecoration(
          color: hasColl ? AppColors.success : Colors.white,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: hasColl ? Colors.green.shade700 : Colors.grey.shade300,
            width: hasColl ? 1 : 0.8,
          ),
          boxShadow: hasColl
              ? [
                  BoxShadow(
                    color: Colors.green.withValues(alpha: 0.2),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            "$d",
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.bold,
              color: hasColl ? Colors.white : Colors.grey.shade700,
            ),
          ),
        ),
      ),
    );
  }

  void _printMonthlySheet(
    BuildContext context,
    LoanRepository repo,
    bool isTamil,
    Map<String, dynamic> data,
    int totalDays,
    int curMonth,
    int curYear,
  ) {
    final dayTotals = (data['dayTotals'] as Map<int, double>?) ?? {};
    final months = (data['monthsSummary'] as List<dynamic>?) ?? [];
    final monthInfo = months.firstWhere(
      (m) => m['month'] == curMonth && m['year'] == curYear,
      orElse: () => {'nameTa': 'மாதம் $curMonth', 'nameEn': 'Month $curMonth'},
    );
    final monthName = isTamil ? monthInfo['nameTa'] : monthInfo['nameEn'];

    double part1Total = 0;
    for (int d = 1; d <= 15 && d <= totalDays; d++) {
      part1Total += dayTotals[d] ?? 0;
    }

    double part2Total = 0;
    for (int d = 16; d <= totalDays; d++) {
      part2Total += dayTotals[d] ?? 0;
    }

    final collectedTotal = CurrencyUtils.format(data['collectedTotal'] ?? 0);
    final disbursedTotal = CurrencyUtils.format(data['disbursedTotal'] ?? 0);
    final expectedTotal = CurrencyUtils.format(data['totalExpected'] ?? 0);

    final StringBuffer part1Rows = StringBuffer();
    for (int d = 1; d <= 15 && d <= totalDays; d++) {
      final amt = dayTotals[d] ?? 0;
      final fw = amt > 0 ? 'bold' : 'normal';
      final col = amt > 0 ? '#2E7D32' : '#999';
      final formattedAmt = CurrencyUtils.format(amt);
      part1Rows.write('<tr><td>Day $d</td><td style="text-align: right; font-weight: $fw; color: $col;">$formattedAmt</td></tr>\n');
    }

    final StringBuffer part2Rows = StringBuffer();
    for (int d = 16; d <= totalDays; d++) {
      final amt = dayTotals[d] ?? 0;
      final fw = amt > 0 ? 'bold' : 'normal';
      final col = amt > 0 ? '#2E7D32' : '#999';
      final formattedAmt = CurrencyUtils.format(amt);
      part2Rows.write('<tr><td>Day $d</td><td style="text-align: right; font-weight: $fw; color: $col;">$formattedAmt</td></tr>\n');
    }

    final html = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Monthly Collection Register - $monthName $curYear</title>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; margin: 20px; color: #1a1a1a; background: #fff; }
    .report-card { max-width: 1200px; width: 95%; margin: 0 auto; border: 2px solid #0D47A1; border-radius: 10px; padding: 20px; }
    .header { text-align: center; border-bottom: 2px dashed #0D47A1; padding-bottom: 12px; margin-bottom: 14px; }
    .header h1 { margin: 0; color: #0D47A1; font-size: 24px; }
    .header h2 { margin: 4px 0; color: #E65100; font-size: 16px; }
    .header p { margin: 2px 0; font-size: 13px; color: #555; }
    .summary { display: flex; justify-content: space-around; background: #E3F2FD; padding: 10px; border-radius: 6px; margin-bottom: 16px; font-size: 13px; font-weight: bold; }
    .tables-container { display: flex; gap: 16px; }
    .table-box { flex: 1; border: 1px solid #ddd; border-radius: 6px; overflow: hidden; }
    .table-title { background: #0D47A1; color: #fff; padding: 8px 12px; font-weight: bold; font-size: 13px; display: flex; justify-content: space-between; }
    .table-title.part2 { background: #2E7D32; }
    table { width: 100%; border-collapse: collapse; font-size: 12px; }
    th, td { padding: 6px 10px; border-bottom: 1px solid #eee; }
    .footer-row { background: #F5F5F5; font-weight: bold; }
    .grand-total { margin-top: 16px; padding: 12px; background: #FFF9C4; border: 1px solid #FBC02D; border-radius: 6px; font-weight: bold; text-align: right; font-size: 14px; color: #0D47A1; }
    .print-btn-bar { text-align: center; margin-bottom: 16px; }
    @media print { .print-btn-bar { display: none; } }
  </style>
</head>
<body>
  <div class="print-btn-bar">
    <button onclick="window.print()" style="padding: 10px 24px; font-size: 14px; font-weight: bold; background: #0D47A1; color: white; border: none; border-radius: 6px; cursor: pointer;">
      🖨️ அச்சிடு (Print Sheet)
    </button>
  </div>
  <div class="report-card">
    <div class="header">
      <h1>ஸ்ரீ மீனாட்சி பைனான்ஸ்</h1>
      <h2>SRI MEENAKSHI FINANCE - MADURAI</h2>
      <p>மாதாந்திர வசூல் பதிவேடு (Monthly Collection Register) - $monthName $curYear ($totalDays நாட்கள் / $totalDays Days)</p>
    </div>
    <div class="summary">
      <div>வழங்கிய கடன்: $disbursedTotal</div>
      <div>மாத வசூல்: $collectedTotal</div>
      <div>எதிர்பார்க்கப்படும் தொகை: $expectedTotal</div>
    </div>
    <div class="tables-container">
      <div class="table-box">
        <div class="table-title">
          <span>முதல் 15 நாட்கள் (நாள் 1 - 15)</span>
          <span>${CurrencyUtils.format(part1Total)}</span>
        </div>
        <table>
          <thead><tr style="background: #f9f9f9;"><th>நாள் (Day)</th><th style="text-align: right;">வசூல் தொகை</th></tr></thead>
          <tbody>
            $part1Rows
          </tbody>
          <tfoot>
            <tr class="footer-row"><td>கூடுதல் (Part 1 Total)</td><td style="text-align: right; color: #0D47A1;">${CurrencyUtils.format(part1Total)}</td></tr>
          </tfoot>
        </table>
      </div>
      <div class="table-box">
        <div class="table-title part2">
          <span>இரண்டாம் பகுதி (நாள் 16 - $totalDays)</span>
          <span>${CurrencyUtils.format(part2Total)}</span>
        </div>
        <table>
          <thead><tr style="background: #f9f9f9;"><th>நாள் (Day)</th><th style="text-align: right;">வசூல் தொகை</th></tr></thead>
          <tbody>
            $part2Rows
          </tbody>
          <tfoot>
            <tr class="footer-row"><td>கூடுதல் (Part 2 Total)</td><td style="text-align: right; color: #2E7D32;">${CurrencyUtils.format(part2Total)}</td></tr>
          </tfoot>
        </table>
      </div>
    </div>
    <div class="grand-total">
      மொத்த மாத வசூல் (Grand Total Month Collection): $collectedTotal
    </div>
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isTamil
              ? "$monthName $curYear மாதாந்திர வசூல் அறிக்கை அச்சிட தயாராக உள்ளது!"
              : "Monthly collection register for $monthName $curYear ready to print!",
        ),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  Widget _tableCell(String text, {bool isHeader = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: isHeader ? Alignment.center : Alignment.centerLeft,
        child: Text(
          text,
          style: TextStyle(
            fontSize: isHeader ? 11 : 10.5,
            fontWeight: isHeader ? FontWeight.bold : FontWeight.w500,
            color: color ?? Colors.black87,
          ),
          textAlign: isHeader ? TextAlign.center : TextAlign.start,
        ),
      ),
    );
  }

  /// Outstanding Table (நிலுவை அட்டவணை):
  /// Columns: Date | received amnt | வசூல் | outstanding
  /// Dynamic Calculation: Outstanding = Previous Outstanding + Received Amnt - Collection (வசூல்)
  Widget _buildOutstandingTable(LoanRepository repo, bool isTamil, [String? activeFy]) {
    final targetFy = activeFy ?? _selectedYearlyFy ?? repo.selectedFinancialYear;
    var allLoans = repo.getLoans(financialYear: targetFy);
    if (allLoans.isEmpty) {
      allLoans = repo.getLoans(financialYear: 'All');
    }

    if (_selectedOutstandingLine != 'All') {
      allLoans = allLoans.where((l) => l.lineCode == _selectedOutstandingLine).toList();
    }

    final allCollections = repo.getCollections().where((col) {
      if (_selectedOutstandingLine != 'All') {
        if (col.lineCode != _selectedOutstandingLine) {
          final loan = repo.getLoans(financialYear: 'All').where((l) => l.id == col.loanId).firstOrNull;
          if (loan?.lineCode != _selectedOutstandingLine) return false;
        }
      }
      if (targetFy != 'All') {
        return repo.isDateInFinancialYear(col.collectionDate, targetFy);
      }
      return true;
    }).toList();

    // Map amounts by date (truncated to day level)
    final Map<DateTime, double> receivedAmntByDate = {};
    final Map<DateTime, double> todayCollByDate = {};
    final Set<DateTime> recordedDates = {};

    for (final l in allLoans) {
      final d = DateTime(l.startDate.year, l.startDate.month, l.startDate.day);
      recordedDates.add(d);
      receivedAmntByDate[d] = (receivedAmntByDate[d] ?? 0) + l.loanAmount;
    }

    for (final c in allCollections) {
      final d = DateTime(c.collectionDate.year, c.collectionDate.month, c.collectionDate.day);
      recordedDates.add(d);
      todayCollByDate[d] = (todayCollByDate[d] ?? 0) + c.amount;
    }

    final sortedDates = recordedDates.toList()..sort();

    // Only include dates where amount was disbursed (receivedAmnt > 0) or collected (todayColl > 0).
    // Days with no amount disbursed or collected are excluded.
    final List<DateTime> displayDates = sortedDates.where((d) {
      final received = receivedAmntByDate[d] ?? 0.0;
      final coll = todayCollByDate[d] ?? 0.0;
      return received > 0 || coll > 0;
    }).toList();

    // Build row data dynamically
    final List<_OutstandingTableRowData> rows = [];
    double runningOutstanding = 0.0;
    double grandTotalReceived = 0.0;
    double grandTotalColl = 0.0;

    for (final d in displayDates) {
      final received = receivedAmntByDate[d] ?? 0.0;
      final coll = todayCollByDate[d] ?? 0.0;
      runningOutstanding = runningOutstanding + received - coll;
      grandTotalReceived += received;
      grandTotalColl += coll;

      final yrStr = d.year.toString();
      final dateStr = "${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${yrStr.length >= 4 ? yrStr.substring(2) : yrStr}";

      rows.add(_OutstandingTableRowData(
        dateStr: dateStr,
        receivedAmnt: received,
        todayCollection: coll,
        outstanding: runningOutstanding,
      ));
    }

    final availableLines = ['All', ...repo.availableLines];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF3949AB), width: 1.5),
            boxShadow: const [
              BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 1)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Title Banner
              Container(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                decoration: const BoxDecoration(
                  color: Color(0xFFE8EAF6),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(Icons.table_chart, color: Color(0xFF1A237E), size: 18),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              isTamil ? "நிலுவை அட்டவணை" : "Outstanding Table",
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF1A237E)),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF4CAF50)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.sync, size: 12, color: Color(0xFF2E7D32)),
                          const SizedBox(width: 4),
                          Text(
                            isTamil ? "நேரடி தரவு (Live)" : "Live Dynamic",
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2E7D32),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Filter Bar: Line Filter Chips
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Row(
                  children: [
                    Text(
                      "${isTamil ? 'வரிசை' : 'Line'}: ",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: availableLines.map((line) {
                            final isSel = _selectedOutstandingLine == line;
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ChoiceChip(
                                label: Text(line == 'All' ? (isTamil ? 'அனைத்தும்' : 'All') : 'Line $line'),
                                selected: isSel,
                                selectedColor: const Color(0xFF3949AB),
                                labelStyle: TextStyle(
                                  color: isSel ? Colors.white : Colors.black87,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                                onSelected: (val) {
                                  if (val) {
                                    setState(() => _selectedOutstandingLine = line);
                                  }
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // KPI Summary Cards
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEDE7F6),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.purple.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              isTamil ? "பெற்ற தொகை (received amnt)" : "received amnt",
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.purple.shade900),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              "₹${grandTotalReceived.toInt()}",
                              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Colors.purple.shade900),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.shade300),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              isTamil ? "மொத்த வசூல்" : "வசூல் (Collection)",
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green.shade900),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              "₹${grandTotalColl.toInt()}",
                              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Colors.green.shade900),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE3F2FD),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade300),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              isTamil ? "தற்போதைய நிலுவை" : "outstanding",
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF0D47A1)),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              "₹${runningOutstanding.toInt()}",
                              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF0D47A1)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 6),

              if (grandTotalReceived == 0 && grandTotalColl == 0)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F8E9),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF81C784)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, size: 14, color: Color(0xFF2E7D32)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          isTamil
                              ? "இன்று வரை பதிவுகள் இல்லை. இன்று புதிய கடன் அல்லது வசூல் சேர்த்தால் உடனடியாக இங்கு தோன்றும்."
                              : "No transaction records yet. Adding a loan or collecting money today will update this table live.",
                          style: const TextStyle(fontSize: 10.5, color: Color(0xFF2E7D32), fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),

              // ================= The Exact 4-Column Table =================
              Padding(
                padding: const EdgeInsets.all(10),
                child: Table(
                  border: TableBorder.all(color: const Color(0xFF9E9E9E), width: 0.9),
                  columnWidths: const {
                    0: FlexColumnWidth(1.2), // Date
                    1: FlexColumnWidth(1.3), // received amnt
                    2: FlexColumnWidth(1.2), // வசூல்
                    3: FlexColumnWidth(1.3), // outstanding
                  },
                  children: [
                    // Header Row matching user request
                    TableRow(
                      decoration: const BoxDecoration(color: Color(0xFFECEFF1)),
                      children: [
                        _schemeCell("Date", isBold: true, color: const Color(0xFF263238)),
                        _schemeCell("received amnt", isBold: true, color: const Color(0xFF4A148C)),
                        _schemeCell(isTamil ? "வசூல்" : "வசூல் (Coll)", isBold: true, color: const Color(0xFF1B5E20)),
                        _schemeCell("outstanding", isBold: true, color: const Color(0xFF0D47A1)),
                      ],
                    ),

                    // Data Rows
                    if (rows.isEmpty)
                      TableRow(
                        children: [
                          _schemeCell("-"),
                          _schemeCell("-"),
                          _schemeCell("-"),
                          _schemeCell("-"),
                        ],
                      )
                    else
                      ...rows.map((row) {
                      return TableRow(
                        children: [
                          _schemeCell(row.dateStr, isBold: true),
                          _schemeCell(
                            row.receivedAmnt > 0 ? "${row.receivedAmnt.toInt()}" : "",
                            isBold: row.receivedAmnt > 0,
                            color: const Color(0xFF4A148C),
                          ),
                          _schemeCell(
                            row.todayCollection > 0 ? "${row.todayCollection.toInt()}" : "",
                            isBold: row.todayCollection > 0,
                            color: const Color(0xFF1B5E20),
                          ),
                          _schemeCell(
                            "${row.outstanding.toInt()}",
                            isBold: true,
                            color: const Color(0xFF0D47A1),
                          ),
                        ],
                      );
                    }),

                    // Total Row at bottom
                    TableRow(
                      decoration: const BoxDecoration(color: Color(0xFFEDE7F6)),
                      children: [
                        _schemeCell("Total", isBold: true, color: Colors.black87),
                        _schemeCell(
                          grandTotalReceived > 0 ? "${grandTotalReceived.toInt()}" : "0",
                          isBold: true,
                          color: const Color(0xFF4A148C),
                        ),
                        _schemeCell(
                          grandTotalColl > 0 ? "${grandTotalColl.toInt()}" : "0",
                          isBold: true,
                          color: const Color(0xFF1B5E20),
                        ),
                        _schemeCell(
                          "${runningOutstanding.toInt()}",
                          isBold: true,
                          color: const Color(0xFF0D47A1),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Formula Explanation Banner matching handwritten note
              Container(
                margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFFE3F2FD),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF90CAF9)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calculate, size: 16, color: Color(0xFF0D47A1)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        isTamil
                            ? "சூத்திரம்: நிலுவை = முந்தைய நிலுவை + received amnt (வழங்கிய கடன்) - வசூல்"
                            : "Formula: Outstanding = Previous Outstanding + received amnt - Collection (வசூல்)",
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0D47A1)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _schemeCell(String text, {bool isBold = false, Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      alignment: Alignment.center,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          text,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: color ?? Colors.black87,
          ),
        ),
      ),
    );
  }
}

class _OutstandingTableRowData {
  final String dateStr;
  final double receivedAmnt;
  final double todayCollection;
  final double outstanding;

  const _OutstandingTableRowData({
    required this.dateStr,
    required this.receivedAmnt,
    required this.todayCollection,
    required this.outstanding,
  });
}

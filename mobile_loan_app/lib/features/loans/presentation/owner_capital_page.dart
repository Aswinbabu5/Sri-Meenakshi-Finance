import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_animations.dart';
import '../../../../core/models/loan_model.dart';
import '../../../../core/services/loan_repository.dart';
import '../../../../core/utils/currency_utils.dart';

class OwnerCapitalPage extends StatefulWidget {
  final LoanRepository repository;

  const OwnerCapitalPage({super.key, required this.repository});

  @override
  State<OwnerCapitalPage> createState() => _OwnerCapitalPageState();
}

class _OwnerCapitalPageState extends State<OwnerCapitalPage> {
  String _selectedLine = 'All';
  late String _selectedFy;
  bool _showDetailedBreakdown = true;

  @override
  void initState() {
    super.initState();
    _selectedFy = widget.repository.selectedFinancialYear;
    widget.repository.addListener(_onRepoChanged);
  }

  @override
  void dispose() {
    widget.repository.removeListener(_onRepoChanged);
    super.dispose();
  }

  void _onRepoChanged() {
    if (mounted) setState(() {});
  }

  void _showLineSelectDialog() {
    final isTamil = widget.repository.isTamil;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isTamil ? "வசூல் லைன் தேர்வு" : "Select Collection Line"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: widget.repository.availableLines.map((line) {
            final isCurrent = widget.repository.selectedLine == line;
            return ListTile(
              title: Text("Line $line"),
              trailing: isCurrent ? const Icon(Icons.check, color: AppColors.primary) : null,
              onTap: () {
                widget.repository.setLine(line);
                Navigator.pop(ctx);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = widget.repository;
    final isTamil = repo.isTamil;
    final allLoans = repo.getLoans(
      lineCode: _selectedLine,
      financialYear: _selectedFy,
    );

    final totalPrincipal = allLoans.fold<double>(0, (sum, l) => sum + l.loanAmount);
    final totalChitFee = allLoans.fold<double>(0, (sum, l) => sum + l.chitFee);
    final totalInterest = allLoans.fold<double>(0, (sum, l) => sum + l.interestAmount);
    final totalTenureDays = allLoans.fold<double>(0, (sum, l) => sum + l.tenureDays);
    final totalExpected = allLoans.fold<double>(0, (sum, l) => sum + l.totalAmount);
    final totalCollected = allLoans.fold<double>(0, (sum, l) => sum + l.collectedAmount);
    final totalBalance = allLoans.fold<double>(0, (sum, l) => sum + l.balanceAmount);

    // Standardized Formula requested:
    // original amunt - (interest amnt + document charges + days)
    // eg. (10000 - (1000 + 100 + 100)) = 10000 - 1200 = 8800 disbursed amount
    final totalDisbursed = totalPrincipal - (totalInterest + totalChitFee + totalTenureDays);

    // Line breakdown
    final Map<String, List<LoanModel>> lineGrouped = {
      'A': repo.getLoans(lineCode: 'A', financialYear: _selectedFy),
      'B': repo.getLoans(lineCode: 'B', financialYear: _selectedFy),
      'C': repo.getLoans(lineCode: 'C', financialYear: _selectedFy),
      'D': repo.getLoans(lineCode: 'D', financialYear: _selectedFy),
    };

    final summary = repo.getDashboardSummary();
    final activeFiltered = allLoans.where((l) => l.status == 'active').toList();
    final double displayOutstanding = (_selectedLine == 'All' && _selectedFy == 'All')
        ? ((summary['totalOutstanding'] as num?)?.toDouble() ?? 0.0)
        : activeFiltered.fold<double>(0, (sum, l) => sum + l.balanceAmount);

    final today = DateTime.now();
    final double displayTodayColl = (_selectedLine == 'All' && _selectedFy == 'All')
        ? ((summary['todayCollection'] as num?)?.toDouble() ?? 0.0)
        : repo.getCollections().where((c) {
            final isToday = c.collectionDate.year == today.year &&
                c.collectionDate.month == today.month &&
                c.collectionDate.day == today.day;
            if (!isToday) return false;
            if (_selectedLine != 'All') {
              final loan = repo.getLoanByBond(c.bondNumber);
              if (loan?.lineCode != _selectedLine) return false;
            }
            if (_selectedFy != 'All') {
              return repo.isDateInFinancialYear(c.collectionDate, _selectedFy);
            }
            return true;
          }).fold<double>(0, (sum, c) => sum + c.amount);

    final double displayActiveLoans = (_selectedLine == 'All' && _selectedFy == 'All')
        ? ((summary['activeLoansCount'] as num?)?.toDouble() ?? 0.0)
        : activeFiltered.length.toDouble();

    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F8),
      appBar: AppBar(
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(isTamil ? "பதிவேடு அறிக்கை" : "Register Reports"),
        ),
        backgroundColor: const Color(0xFF0D47A1),
        actions: [
          IconButton(
            tooltip: isTamil ? "லைன் தேர்வு" : "Line Select",
            icon: const Icon(Icons.alt_route),
            onPressed: _showLineSelectDialog,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top Quick Stat Bar (மொத்த பாக்கி, இன்றைய வசூல், நடப்பு கடன்கள்)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        _buildTopStatCard(
                          title: isTamil ? "மொத்த பாக்கி" : "Total Outst.",
                          numValue: displayOutstanding,
                          isCurrency: true,
                          color: Colors.red.shade700,
                          icon: Icons.account_balance_wallet,
                        ),
                        const SizedBox(width: 8),
                        _buildTopStatCard(
                          title: isTamil ? "இன்றைய வசூல்" : "Today Coll.",
                          numValue: displayTodayColl,
                          isCurrency: true,
                          color: AppColors.success,
                          icon: Icons.payments,
                        ),
                        const SizedBox(width: 8),
                        _buildTopStatCard(
                          title: isTamil ? "நடப்பு கடன்கள்" : "Active Loans",
                          numValue: displayActiveLoans,
                          isCurrency: false,
                          color: Colors.blue.shade700,
                          icon: Icons.people,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Filter Bar (Line & FY)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.blue.shade100),
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          Text(
                            isTamil ? "லைன்: " : "Line: ",
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                          ...['All', ...widget.repository.availableLines].map((line) {
                            final isSel = _selectedLine == line;
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ChoiceChip(
                                label: Text(line == 'All' ? (isTamil ? 'அனைத்தும்' : 'All') : "Line $line"),
                                selected: isSel,
                                selectedColor: const Color(0xFF1565C0),
                                labelStyle: TextStyle(
                                  color: isSel ? Colors.white : Colors.black87,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                                onSelected: (_) => setState(() => _selectedLine = line),
                              ),
                            );
                          }),
                          Container(
                            height: 20,
                            width: 1,
                            color: Colors.grey.shade300,
                            margin: const EdgeInsets.symmetric(horizontal: 6),
                          ),
                          Text(
                            isTamil ? "நிதியாண்டு: " : "FY: ",
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                          ...[...widget.repository.availableFinancialYears, 'All'].map((fy) {
                            final isSel = _selectedFy == fy;
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ChoiceChip(
                                avatar: Icon(Icons.calendar_today, size: 10, color: isSel ? Colors.white : Colors.amber.shade900),
                                label: Text(fy == 'All' ? (isTamil ? 'அனைத்து FY' : 'All FY') : fy),
                                selected: isSel,
                                selectedColor: Colors.amber.shade800,
                                labelStyle: TextStyle(
                                  color: isSel ? Colors.white : Colors.amber.shade900,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                                onSelected: (_) => setState(() => _selectedFy = fy),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ================= Second Image Table: கடன் கணக்கு விபரம் (Acc No, Interest, Document Charge, Total) =================
                  StaggeredEntrance(
                    index: 0,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFFB74D), width: 1.5),
                        boxShadow: const [
                          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 1)),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Header Banner (matching Image 2 exactly)
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                            decoration: const BoxDecoration(
                              color: Color(0xFFFFF3E0),
                              borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.account_balance_wallet, size: 17, color: Color(0xFFE65100)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    isTamil
                                        ? "கடன் கணக்கு விபரம் (Acc No, Interest, Document Charge, Total)"
                                        : "Account Details: Acc No, Interest, Doc Charge & Total",
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFE65100)),
                                  ),
                                ),
                                Text(
                                  "${allLoans.length} ${isTamil ? 'கணக்குகள்' : 'Accounts'}",
                                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                                ),
                              ],
                            ),
                          ),

                          // Table with Acc No, Interest Amnt, Document Charge, Total
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Table(
                              defaultColumnWidth: const IntrinsicColumnWidth(),
                              border: TableBorder.all(color: const Color(0xFFBDBDBD), width: 0.8),
                              children: [
                                // Column Headers
                                TableRow(
                                  decoration: const BoxDecoration(color: Color(0xFFFFE0B2)),
                                  children: [
                                    _schemeCell("S.No", isBold: true),
                                    _schemeCell(isTamil ? "கணக்கு எண் (Acc No)" : "Acc No (Bond)", isBold: true),
                                    _schemeCell(isTamil ? "பெயர் (Name)" : "Customer Name", isBold: true),
                                    _schemeCell(isTamil ? "வட்டித் தொகை (Interest)" : "Interest Amnt", isBold: true, color: Colors.orange.shade900),
                                    _schemeCell(isTamil ? "ஆவணக் கட்டணம் (Doc Charge)" : "Document Charge", isBold: true, color: Colors.purple.shade900),
                                    _schemeCell(isTamil ? "மொத்த தொகை (Total)" : "Total Amount", isBold: true, color: const Color(0xFF0D47A1)),
                                    _schemeCell(isTamil ? "பெற்ற தொகை (Disbursed)" : "Disbursed Amnt", isBold: true, color: const Color(0xFF00695C)),
                                  ],
                                ),

                                // Dynamic Loan Rows from scratch or existing members
                                if (allLoans.isEmpty)
                                  TableRow(
                                    children: [
                                      _schemeCell("-"),
                                      _schemeCell("-"),
                                      _schemeCell(isTamil ? "கணக்குகள் எதுவும் இல்லை" : "No loan accounts created"),
                                      _schemeCell("₹0"),
                                      _schemeCell("₹0"),
                                      _schemeCell("₹0"),
                                      _schemeCell("₹0"),
                                    ],
                                  )
                                else
                                  ...allLoans.asMap().entries.map((entry) {
                                    final index = entry.key + 1;
                                    final loan = entry.value;
                                    // Formula: original amunt - (interest amnt + document charges + days)
                                    // eg. 10000 - (1000 + 100 + 100) = 8800 disbursed amount
                                    final loanDisbursed = loan.disbursedAmount;

                                    return TableRow(
                                      children: [
                                        _schemeCell("$index"),
                                        _schemeCell(loan.bondNumber, isBold: true),
                                        _schemeCell(loan.customerName),
                                        _schemeCell(CurrencyUtils.format(loan.interestAmount), color: Colors.orange.shade900),
                                        _schemeCell(CurrencyUtils.format(loan.chitFee), color: Colors.purple.shade900),
                                        _schemeCell(CurrencyUtils.format(loan.totalAmount), isBold: true, color: const Color(0xFF0D47A1)),
                                        _schemeCell(CurrencyUtils.format(loanDisbursed), isBold: true, color: const Color(0xFF00695C)),
                                      ],
                                    );
                                  }),

                                // Grand Total Row at bottom (all total amnt)
                                TableRow(
                                  decoration: const BoxDecoration(color: Color(0xFFFFECB3)),
                                  children: [
                                    _schemeCell("ALL", isBold: true),
                                    _schemeCell("TOTAL", isBold: true, color: const Color(0xFFE65100)),
                                    _schemeCell("${allLoans.length} Members", isBold: true),
                                    _schemeCell(CurrencyUtils.format(totalInterest), isBold: true, color: Colors.orange.shade900),
                                    _schemeCell(CurrencyUtils.format(totalChitFee), isBold: true, color: Colors.purple.shade900),
                                    _schemeCell(CurrencyUtils.format(totalExpected), isBold: true, color: const Color(0xFF0D47A1)),
                                    _schemeCell(CurrencyUtils.format(totalDisbursed), isBold: true, color: const Color(0xFF00695C)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Comprehensive Detailed Audit Breakdown Card
                  StaggeredEntrance(
                    index: 1,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber.shade400, width: 1.5),
                        boxShadow: const [
                          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade50,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                              border: Border(bottom: BorderSide(color: Colors.amber.shade200)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.receipt_long, color: Color(0xFFE65100), size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    isTamil ? "முழு கணக்கு விவரங்கள் (Total & Document Charges)" : "Detailed Audit: Total Amount & Document Charges",
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFFE65100)),
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(_showDetailedBreakdown ? Icons.expand_less : Icons.expand_more, color: const Color(0xFFE65100)),
                                  onPressed: () => setState(() => _showDetailedBreakdown = !_showDetailedBreakdown),
                                ),
                              ],
                            ),
                          ),

                          AnimatedSize(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                            child: _showDetailedBreakdown
                                ? Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                          Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildAuditRow(
                                  title: isTamil ? "1. வழங்கிய மொத்த கடன் அசல் (Loan Principal)" : "1. Total Loan Principal Disbursed",
                                  value: CurrencyUtils.format(totalPrincipal),
                                  color: Colors.blue.shade900,
                                  isBold: true,
                                ),
                                const Divider(height: 14),
                                _buildAuditRow(
                                  title: isTamil ? "2. ஆவணக் கட்டணம் / சீட்டுக் காசு (Document Charge)" : "2. Total Document Charges (Chit Fee)",
                                  value: CurrencyUtils.format(totalChitFee),
                                  color: Colors.purple.shade800,
                                  badge: isTamil ? "கட்டணம்" : "Doc Fee",
                                ),
                                const Divider(height: 14),
                                _buildAuditRow(
                                  title: isTamil ? "3. வட்டித் தொகை (Total Interest Amount)" : "3. Total Interest Charged",
                                  value: CurrencyUtils.format(totalInterest),
                                  color: Colors.orange.shade900,
                                ),
                                const Divider(height: 14),
                                _buildAuditRow(
                                  title: isTamil ? "4. உறுப்பினர் செலுத்த வேண்டிய மொத்த தொகை (Repayable Total)" : "4. Total Repayable Amount (Paid by Customer)",
                                  value: CurrencyUtils.format(totalExpected),
                                  color: const Color(0xFF0D47A1),
                                  isBold: true,
                                ),
                                const Divider(height: 14),
                                _buildAuditRow(
                                  title: isTamil ? "5. கையில் வழங்கிய தொகை (Disbursed = அசல் - (வட்டி + சீட்டு + நாட்கள்))" : "5. Disbursed Amount = Principal - (Interest + Doc Fee + Days)",
                                  value: CurrencyUtils.format(totalDisbursed),
                                  color: Colors.teal.shade800,
                                  isBold: true,
                                ),
                                const Divider(height: 14),
                                _buildAuditRow(
                                  title: isTamil ? "6. இதுவரை வசூலான தொகை (Collected Amount)" : "6. Total Amount Collected",
                                  value: CurrencyUtils.format(totalCollected),
                                  color: AppColors.success,
                                  isBold: true,
                                ),
                                const Divider(height: 14),
                                _buildAuditRow(
                                  title: isTamil ? "7. மீதமுள்ள பாக்கித் தொகை (Outstanding Balance)" : "7. Outstanding Balance Receivable",
                                  value: CurrencyUtils.format(totalBalance),
                                  color: AppColors.error,
                                  isBold: true,
                                ),
                              ],
                            ),
                          ),

                          const Divider(height: 1),

                          // Line-wise Audit Table
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isTamil ? "லைன் வாரியான நிதி ஒதுக்கீடு & ஆவணக் கட்டணம்:" : "Line-wise Allocation & Document Charges:",
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey.shade200),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(minWidth: 460),
                                      child: Table(
                                        columnWidths: const {
                                          0: FlexColumnWidth(1.2),
                                          1: FlexColumnWidth(1.2),
                                          2: FlexColumnWidth(1.2),
                                          3: FlexColumnWidth(1.4),
                                          4: FlexColumnWidth(1.4),
                                        },
                                        children: [
                                          TableRow(
                                            decoration: BoxDecoration(color: Colors.grey.shade100),
                                            children: [
                                              _tableCell("Line", isHeader: true),
                                              _tableCell(isTamil ? "அசல்" : "Principal", isHeader: true),
                                              _tableCell(isTamil ? "சீட்டுக் கட்டணம்" : "Doc Fee", isHeader: true),
                                              _tableCell(isTamil ? "மொத்த எதிர்பார்ப்பு" : "Total", isHeader: true),
                                              _tableCell(isTamil ? "பாக்கி" : "Balance", isHeader: true),
                                            ],
                                          ),
                                          ...widget.repository.availableLines.map((line) {
                                            final list = lineGrouped[line] ?? [];
                                            final p = list.fold<double>(0, (s, l) => s + l.loanAmount);
                                            final cf = list.fold<double>(0, (s, l) => s + l.chitFee);
                                            final tot = list.fold<double>(0, (s, l) => s + l.totalAmount);
                                            final bal = list.fold<double>(0, (s, l) => s + l.balanceAmount);

                                            return TableRow(
                                              children: [
                                                _tableCell("Line $line (${list.length})"),
                                                _tableCell(CurrencyUtils.format(p)),
                                                _tableCell(CurrencyUtils.format(cf), color: Colors.purple.shade800),
                                                _tableCell(CurrencyUtils.format(tot), color: const Color(0xFF0D47A1)),
                                                _tableCell(CurrencyUtils.format(bal), color: AppColors.error),
                                              ],
                                            );
                                          }),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    : const SizedBox.shrink(),
              ),
                        ],
                      ),
                    ),
                  ),

                ],
              ),
            ),
          ),
        ),
      ),
    );
  }


  Widget _buildAuditRow({required String title, required String value, required Color color, bool isBold = false, String? badge}) {
    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),
              if (badge != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.purple.shade200),
                  ),
                  child: Text(badge, style: TextStyle(fontSize: 9.5, color: Colors.purple.shade800, fontWeight: FontWeight.bold)),
                ),
              ],
            ],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? 14 : 13,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _tableCell(String text, {bool isHeader = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: isHeader ? 11 : 10.5,
          fontWeight: isHeader ? FontWeight.bold : FontWeight.w500,
          color: color ?? Colors.black87,
        ),
        textAlign: isHeader ? TextAlign.center : TextAlign.start,
      ),
    );
  }

  Widget _schemeCell(String text, {bool isBold = false, Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      alignment: Alignment.center,
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          color: color ?? Colors.black87,
        ),
      ),
    );
  }

  Widget _buildTopStatCard({
    required String title,
    String? value,
    num? numValue,
    bool isCurrency = false,
    required Color color,
    required IconData icon,
  }) {
    return Expanded(
      child: HoverScaleCard(
        elevation: 0.5,
        hoverElevation: 2.5,
        hoverScale: 1.02,
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: numValue != null
                        ? AnimatedCountingNumber(
                            value: numValue,
                            isCurrency: isCurrency,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                              color: color,
                            ),
                          )
                        : Text(
                            value ?? '',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                              color: color,
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

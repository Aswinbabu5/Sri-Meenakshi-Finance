import '../../../core/utils/safe_image_provider.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_animations.dart';
import '../../../core/models/loan_model.dart';
import '../../../core/models/collection_model.dart';
import '../../../core/services/loan_repository.dart';
import '../../../core/services/passbook_service.dart';
import '../../../core/services/records_export_service.dart';
import '../../dashboard/presentation/widgets/company_header.dart';

class LoanPassbookPage extends StatefulWidget {
  final LoanModel loan;
  final LoanRepository repository;
  final String? returnPanelTitle; // e.g. "புதிய கடன் பதிவு" or "பாக்கித் தொகை"

  const LoanPassbookPage({
    super.key,
    required this.loan,
    required this.repository,
    this.returnPanelTitle,
  });

  @override
  State<LoanPassbookPage> createState() => _LoanPassbookPageState();
}

class _LoanPassbookPageState extends State<LoanPassbookPage> {
  bool _isDownloading = false;
  bool _isGeneratingPdf = false;
  late LoanModel _currentLoan;

  @override
  void initState() {
    super.initState();
    final fresh = widget.repository.getLoanByBond(widget.loan.bondNumber, widget.loan.lineCode);
    _currentLoan = fresh ?? widget.loan;
  }

  LoanModel get _effectiveLoan =>
      widget.repository.getLoanByBond(_currentLoan.bondNumber, _currentLoan.lineCode) ?? _currentLoan;

  List<CollectionModel> get _ledger {
    final loan = _effectiveLoan;
    return widget.repository.getLedger(loan.bondNumber, loanId: loan.id);
  }

  Future<void> _handleDownload() async {
    setState(() => _isDownloading = true);
    final isTamil = widget.repository.isTamil;

    try {
      final savedPath = await PassbookService.downloadPassbookHtml(
        loan: _effectiveLoan,
        ledger: _ledger,
        isTamil: isTamil,
      );

      setState(() {
        _isDownloading = false;
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isTamil
                      ? 'பாஸ்புக் வெற்றிகரமாக பதிவிறக்கம் செய்யப்பட்டது!'
                      : 'Passbook successfully downloaded!',
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF2E7D32),
          duration: const Duration(seconds: 4),
        ),
      );

      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (ctx) => _buildDownloadSuccessSheet(ctx, savedPath),
      );
    } catch (e) {
      setState(() => _isDownloading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isTamil ? 'பதிவிறக்கம் பிழை: $e' : 'Download Error: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _handleDownloadMemberPdf() async {
    setState(() => _isGeneratingPdf = true);
    final isTamil = widget.repository.isTamil;
    try {
      final savedPath = await RecordsExportService.exportSingleMemberPdf(
        loan: _effectiveLoan,
        collections: _ledger,
        isTamil: isTamil,
      );

      setState(() => _isGeneratingPdf = false);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isTamil
                      ? 'உறுப்பினர் PDF வெற்றிகரமாக பதிவிறக்கப்பட்டது! ($savedPath)'
                      : 'Member PDF downloaded successfully! ($savedPath)',
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF2E7D32),
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      setState(() => _isGeneratingPdf = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isTamil ? 'PDF பிழை: $e' : 'PDF Error: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _handlePrint() async {
    final isTamil = widget.repository.isTamil;
    try {
      await PassbookService.printPassbook(
        loan: _effectiveLoan,
        ledger: _ledger,
        isTamil: isTamil,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isTamil ? 'பிரிண்ட் பிழை: $e' : 'Print Error: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _handleShare() async {
    final isTamil = widget.repository.isTamil;
    try {
      await PassbookService.sharePassbook(
        loan: _effectiveLoan,
        ledger: _ledger,
        isTamil: isTamil,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isTamil ? 'பகிர்வதில் பிழை: $e' : 'Share Error: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _returnBackToPanel() {
    Navigator.of(context).pop();
  }

  void _confirmDeleteLoan() {
    final isTamil = widget.repository.isTamil;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isTamil ? 'கணக்கை நீக்கவா?' : 'Delete Loan?'),
        content: Text(
          isTamil
              ? '${_currentLoan.bondNumber} - ${_currentLoan.customerName} கடன் கணக்கை முழுமையாக நீக்க விரும்புகிறீர்களா?\n\n(இதன் அனைத்து வசூல் பதிவுகளும் நிரந்தரமாக நீக்கப்படும்)'
              : 'Are you sure you want to permanently delete loan ${_currentLoan.bondNumber} - ${_currentLoan.customerName}?\n\n(All associated collections will also be deleted)',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(isTamil ? 'ரத்து' : 'Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await widget.repository.deleteLoan(_currentLoan.id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(isTamil ? 'கடன் கணக்கு வெற்றிகரமாக நீக்கப்பட்டது' : 'Loan deleted successfully'),
                      backgroundColor: Colors.red.shade700,
                    ),
                  );
                  Navigator.pop(context);
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: Text(isTamil ? 'நீக்கு (Delete)' : 'Delete', style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isTamil = widget.repository.isTamil;
    final loan = _effectiveLoan;

    final returnTitle = widget.returnPanelTitle ??
        (isTamil ? "முதன்மை பதிவுக்கு திரும்பு" : "Return to Panel");

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(isTamil ? "கடன் தவணை அட்டை" : "Loan Passbook"),
        ),
        backgroundColor: const Color(0xFF0D47A1),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: returnTitle,
          onPressed: _returnBackToPanel,
        ),
        actions: [
          IconButton(
            icon: _isGeneratingPdf
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Icon(Icons.picture_as_pdf),
            tooltip: isTamil ? "உறுப்பினர் முழு விவர PDF" : "Download Member PDF",
            onPressed: _isGeneratingPdf ? null : _handleDownloadMemberPdf,
          ),
          IconButton(
            icon: const Icon(Icons.print_outlined),
            tooltip: isTamil ? "பிரிண்ட் / PDF" : "Print / PDF",
            onPressed: _handlePrint,
          ),
          if (widget.repository.isAdmin)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.white),
              tooltip: isTamil ? "கணக்கை நீக்கு" : "Delete Loan",
              onPressed: _confirmDeleteLoan,
            ),
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: isTamil ? "பகிர்" : "Share",
            onPressed: _handleShare,
          ),
          IconButton(
            icon: _isDownloading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Icon(Icons.download),
            tooltip: isTamil ? "பதிவிறக்கு" : "Download",
            onPressed: _isDownloading ? null : _handleDownload,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            CompanyHeader(repository: widget.repository, compact: true),

            // Top Return Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.amber.shade100,
              child: Row(
                children: [
                  const Icon(Icons.keyboard_return, size: 20, color: Color(0xFF795548)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isTamil
                          ? "பதிவு செய்த பகுதிக்கு திரும்ப 'திரும்பு' பொத்தானை அழுத்தவும்"
                          : "Press 'Back' to return to loan management",
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF5D4037)),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _returnBackToPanel,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF0D47A1),
                    ),
                    icon: const Icon(Icons.arrow_back, size: 16),
                    label: Text(
                      isTamil ? "திரும்பு" : "Back",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Passbook Brand Header
                        _buildPassbookBrandHeader(isTamil),

                        // Customer Header Card (ID, Name, Photo, Acc)
                        _buildCustomerHeader(loan, isTamil),

                        // Passbook Paper Table
                        _buildPassbookPaperTable(loan, isTamil),

                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Bottom Sticky Action Panel
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, -2)),
                ],
              ),
              child: Row(
                children: [
                  // Return to Panel Button
                  Expanded(
                    flex: 2,
                    child: AnimatedPressable(
                      onTap: _returnBackToPanel,
                      child: OutlinedButton.icon(
                        onPressed: _returnBackToPanel,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: Color(0xFF0D47A1), width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.arrow_back_ios_new, size: 16, color: Color(0xFF0D47A1)),
                        label: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            isTamil ? "திரும்பு" : "Back",
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0D47A1),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Download Passbook Button
                  Expanded(
                    flex: 3,
                    child: AnimatedPressable(
                      onTap: _isDownloading ? null : _handleDownload,
                      child: ElevatedButton.icon(
                        onPressed: _isDownloading ? null : _handleDownload,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2E7D32),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 2,
                        ),
                        icon: _isDownloading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Icon(Icons.download, color: Colors.white),
                        label: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            isTamil ? "பதிவிறக்கம்" : "Download Passbook",
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
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

  Widget _buildPassbookBrandHeader(bool isTamil) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFCBD5E1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            isTamil ? "ஸ்ரீ மீனாட்சி பைனான்ஸ்" : "SRI MEENAKSHI FINANCE",
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0D47A1),
              letterSpacing: 0.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            isTamil ? "SRI MEENAKSHI FINANCE • மதுரை" : "MADURAI • MICRO FINANCE",
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A365D),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFE3F2FD),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFF90CAF9)),
            ),
            child: Text(
              isTamil ? "கடன் தவணை அட்டை (PASSBOOK)" : "LOAN PASSBOOK",
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0D47A1),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerHeader(LoanModel loan, bool isTamil) {
    final cusId = loan.customer?.cusCode ??
        (loan.customerId > 0 ? "CUS-${loan.customerId}" : "ID-${loan.id}");

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFCBD5E1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Photo Box
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  width: 75,
                  height: 85,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    border: Border.all(color: const Color(0xFF1A365D), width: 1.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: getSafeImageWidget(
                    loan.photoPath,
                    fit: BoxFit.cover,
                    placeholder: const Center(
                      child: Icon(Icons.person, size: 44, color: Color(0xFF1A365D)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // ID, Name, Acc, Phone
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _headerFieldRow("ID", cusId),
                    const SizedBox(height: 5),
                    _headerFieldRow(isTamil ? "பெயர்" : "Name", loan.customerName),
                    const SizedBox(height: 5),
                    _headerFieldRow(isTamil ? "தவணை" : "Acc", loan.bondNumber),
                    if (loan.phoneNumber.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      _headerFieldRow(isTamil ? "தொலைபேசி" : "Phone", loan.phoneNumber),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 10),

          // Loan Financial Metrics Grid
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              runSpacing: 8,
              spacing: 8,
              children: [
                _buildPassbookMetric(
                  label: isTamil ? "கடன் தொகை" : "Loan Amount",
                  value: "₹${NumberFormat('#,##0').format(loan.loanAmount)}",
                  color: const Color(0xFF1A365D),
                ),
                _buildPassbookMetric(
                  label: isTamil ? "தவணைத் தொகை" : "Daily Due",
                  value: "₹${NumberFormat('#,##0').format(loan.dailyDueAmount)}",
                  sublabel: "/ ${isTamil ? 'நாள்' : 'day'}",
                  color: const Color(0xFF0D47A1),
                ),
                _buildPassbookMetric(
                  label: isTamil ? "மொத்தத் தொகை" : "Total Amount",
                  value: "₹${NumberFormat('#,##0').format(loan.totalAmount > 0 ? loan.totalAmount : loan.loanAmount)}",
                  color: const Color(0xFF334155),
                ),
                _buildPassbookMetric(
                  label: isTamil ? "வசூலானது" : "Paid",
                  value: "₹${NumberFormat('#,##0').format(loan.collectedAmount)}",
                  color: const Color(0xFF2E7D32),
                ),
                _buildPassbookMetric(
                  label: isTamil ? "மீதி பாக்கி" : "Balance",
                  value: "₹${NumberFormat('#,##0').format(loan.balanceAmount)}",
                  color: const Color(0xFFDC2626),
                  isBold: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPassbookMetric({
    required String label,
    required String value,
    String? sublabel,
    required Color color,
    bool isBold = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isBold ? FontWeight.w900 : FontWeight.bold,
                color: color,
              ),
            ),
            if (sublabel != null)
              Padding(
                padding: const EdgeInsets.only(left: 2),
                child: Text(
                  sublabel,
                  style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.8)),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _headerFieldRow(String label, String value) {
    return Row(
      children: [
        SizedBox(
          width: 55,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF475569),
            ),
          ),
        ),
        const Text(
          ": ",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Color(0xFF475569),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildPassbookPaperTable(LoanModel loan, bool isTamil) {
    final sortedLedger = List<CollectionModel>.from(_ledger)
      ..sort((a, b) => a.collectionDate.compareTo(b.collectionDate));

    final numFormat = NumberFormat('#,##0');
    final decimalFormat = NumberFormat('#,##0.00');

    final totalPrincipal = loan.totalAmount > 0 ? loan.totalAmount : (loan.loanAmount > 0 ? loan.loanAmount : loan.balanceAmount);
    double runningBal = totalPrincipal;
    int currentSlNo = 1;
    double grandTotalColl = 0.0;

    final List<_PassbookUiEntry> entries = [];

    // Opening balance row (Sl. No. 0)
    entries.add(_PassbookUiEntry(
      slNo: 0,
      dateText: DateFormat('dd/MM/yy').format(loan.startDate),
      collAmtText: isTamil ? "ஆரம்ப கடன்" : "Principal",
      bamtText: decimalFormat.format(totalPrincipal),
      type: _PassbookRowType.opening,
    ));

    if (sortedLedger.isNotEmpty) {
      int i = 0;
      while (i < sortedLedger.length) {
        final firstOfGroup = sortedLedger[i];
        final monthKey = "${firstOfGroup.collectionDate.month.toString().padLeft(2, '0')}/${firstOfGroup.collectionDate.year}";
        double monthTotal = 0.0;

        while (i < sortedLedger.length) {
          final col = sortedLedger[i];
          final colMonthKey = "${col.collectionDate.month.toString().padLeft(2, '0')}/${col.collectionDate.year}";
          if (colMonthKey != monthKey) break;

          runningBal -= col.amount;
          monthTotal += col.amount;
          grandTotalColl += col.amount;

          final dateStr = DateFormat('dd/MM/yy').format(col.collectionDate);

          entries.add(_PassbookUiEntry(
            slNo: currentSlNo,
            dateText: dateStr,
            collAmtText: numFormat.format(col.amount),
            bamtText: decimalFormat.format(runningBal),
            type: _PassbookRowType.regular,
          ));

          currentSlNo++;
          i++;
        }

        // Month subtotal entry
        entries.add(_PassbookUiEntry(
          dateText: monthKey,
          collAmtText: decimalFormat.format(monthTotal),
          type: _PassbookRowType.monthSubtotal,
        ));
      }

      // Grand total entry
      entries.add(_PassbookUiEntry(
        collAmtText: decimalFormat.format(grandTotalColl),
        type: _PassbookRowType.grandTotal,
      ));
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFCBD5E1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Indicator: Date and Total Principal
          Padding(
            padding: const EdgeInsets.only(bottom: 6.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Date : ${DateFormat('dd/MM/yy').format(loan.startDate)}",
                  style: const TextStyle(
                    fontFamily: 'Courier',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A365D),
                  ),
                ),
                Text(
                  "Amt. ${NumberFormat('#,##0').format(totalPrincipal)}",
                  style: const TextStyle(
                    fontFamily: 'Courier',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A365D),
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Color(0xFF1A365D), thickness: 1.2, height: 1.2),
          const SizedBox(height: 2),

          // Header Row: Sl. No. | Date | CollAmt | BAMT
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: Color(0xFF1A365D), width: 1.2),
                bottom: BorderSide(color: Color(0xFF1A365D), width: 1.2),
              ),
            ),
            child: const Row(
              children: [
                SizedBox(
                  width: 60,
                  child: Text(
                    "Sl. No.",
                    style: TextStyle(
                      fontFamily: 'Courier',
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5,
                      color: Color(0xFF1A365D),
                    ),
                  ),
                ),
                SizedBox(
                  width: 90,
                  child: Text(
                    "Date",
                    style: TextStyle(
                      fontFamily: 'Courier',
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5,
                      color: Color(0xFF1A365D),
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    "CollAmt",
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontFamily: 'Courier',
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5,
                      color: Color(0xFF1A365D),
                    ),
                  ),
                ),
                SizedBox(width: 20),
                Expanded(
                  child: Text(
                    "BAMT",
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontFamily: 'Courier',
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5,
                      color: Color(0xFF1A365D),
                    ),
                  ),
                ),
              ],
            ),
          ),

          ...entries.map((entry) => _buildRowForEntry(entry)),

          if (sortedLedger.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24.0),
              child: Center(
                child: Text(
                  isTamil ? "வசூல் பதிவுகள் இல்லை (No receipts recorded yet)" : "No collection records recorded yet",
                  style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey.shade600, fontSize: 13),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRowForEntry(_PassbookUiEntry entry) {
    if (entry.type == _PassbookRowType.opening) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          border: Border(bottom: BorderSide(color: Colors.blueGrey.shade200, width: 1.0)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 60,
              child: Text(
                "${entry.slNo ?? 0}",
                style: const TextStyle(
                  fontFamily: 'Courier',
                  fontWeight: FontWeight.bold,
                  fontSize: 13.5,
                  color: Color(0xFF1A365D),
                ),
              ),
            ),
            SizedBox(
              width: 90,
              child: Text(
                entry.dateText ?? '',
                style: const TextStyle(
                  fontFamily: 'Courier',
                  fontWeight: FontWeight.bold,
                  fontSize: 13.5,
                  color: Color(0xFF1A365D),
                ),
              ),
            ),
            Expanded(
              child: Text(
                entry.collAmtText,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontFamily: 'Courier',
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Color(0xFF64748B),
                ),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Text(
                entry.bamtText ?? '',
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontFamily: 'Courier',
                  fontWeight: FontWeight.bold,
                  fontSize: 13.5,
                  color: Color(0xFF0D47A1),
                ),
              ),
            ),
          ],
        ),
      );
    } else if (entry.type == _PassbookRowType.regular) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.blueGrey.shade100, width: 0.8)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 60,
              child: Text(
                "${entry.slNo}",
                style: const TextStyle(
                  fontFamily: 'Courier',
                  fontWeight: FontWeight.bold,
                  fontSize: 13.5,
                  color: Color(0xFF1A365D),
                ),
              ),
            ),
            SizedBox(
              width: 90,
              child: Text(
                entry.dateText ?? '',
                style: const TextStyle(
                  fontFamily: 'Courier',
                  fontWeight: FontWeight.bold,
                  fontSize: 13.5,
                  color: Color(0xFF1A365D),
                ),
              ),
            ),
            Expanded(
              child: Text(
                entry.collAmtText,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontFamily: 'Courier',
                  fontWeight: FontWeight.bold,
                  fontSize: 13.5,
                  color: Color(0xFF1A365D),
                ),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Text(
                entry.bamtText ?? '',
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontFamily: 'Courier',
                  fontWeight: FontWeight.bold,
                  fontSize: 13.5,
                  color: Color(0xFF1A365D),
                ),
              ),
            ),
          ],
        ),
      );
    } else if (entry.type == _PassbookRowType.monthSubtotal) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: Color(0xFF1A365D), width: 1.1),
            bottom: BorderSide(color: Color(0xFF1A365D), width: 1.1),
          ),
        ),
        child: Row(
          children: [
            const SizedBox(width: 60),
            SizedBox(
              width: 90,
              child: Text(
                entry.dateText ?? '',
                style: const TextStyle(
                  fontFamily: 'Courier',
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Color(0xFF00796B),
                ),
              ),
            ),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: Container(
                  padding: const EdgeInsets.only(bottom: 2),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: Color(0xFF00796B), width: 1.4)),
                  ),
                  child: Text(
                    entry.collAmtText,
                    style: const TextStyle(
                      fontFamily: 'Courier',
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Color(0xFF00796B),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 20),
            const Expanded(child: SizedBox()),
          ],
        ),
      );
    } else {
      // Grand Total
      return Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 8),
        child: Row(
          children: [
            const SizedBox(width: 60),
            const SizedBox(width: 90),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      entry.collAmtText,
                      style: const TextStyle(
                        fontFamily: 'Courier',
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Color(0xFF1A365D),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Container(height: 1.5, width: 85, color: const Color(0xFF1A365D)),
                    const SizedBox(height: 1.5),
                    Container(height: 1.5, width: 85, color: const Color(0xFF1A365D)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 20),
            const Expanded(child: SizedBox()),
          ],
        ),
      );
    }
  }

  Widget _buildDownloadSuccessSheet(BuildContext ctx, String filePath) {
    final isTamil = widget.repository.isTamil;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(color: Color(0xFFE8F5E9), shape: BoxShape.circle),
                child: const Icon(Icons.check_circle, color: Color(0xFF2E7D32), size: 32),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isTamil ? "பாஸ்புக் பதிவிறக்கம் செய்யப்பட்டது!" : "Passbook Downloaded!",
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      isTamil ? "கோப்பு உங்களது Downloads அடைவில் சேமிக்கப்பட்டது" : "File saved to your Downloads folder",
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.file_download_done, color: Color(0xFF2E7D32), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    filePath,
                    style: const TextStyle(fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _handleDownloadMemberPdf();
                  },
                  icon: const Icon(Icons.picture_as_pdf, color: Colors.red, size: 18),
                  label: Text(isTamil ? "உறுப்பினர் PDF" : "Member PDF"),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _handlePrint();
                  },
                  icon: const Icon(Icons.print, size: 18),
                  label: Text(isTamil ? "பிரிண்ட் / HTML" : "Print / HTML"),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await PassbookService.downloadPassbookTxt(
                      loan: _currentLoan,
                      ledger: _ledger,
                      isTamil: isTamil,
                    );
                  },
                  icon: const Icon(Icons.description, size: 18),
                  label: Text(isTamil ? "TXT ரசீது" : "TXT Receipt"),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _returnBackToPanel();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D47A1),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            icon: const Icon(Icons.keyboard_return, size: 18, color: Colors.white),
            label: Text(
              isTamil ? "முதன்மை பதிவுக்கு திரும்பு" : "Return to Panel",
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

enum _PassbookRowType { regular, monthSubtotal, grandTotal, opening }

class _PassbookUiEntry {
  final int? slNo;
  final String? dateText;
  final String collAmtText;
  final String? bamtText;
  final _PassbookRowType type;

  _PassbookUiEntry({
    this.slNo,
    this.dateText,
    required this.collAmtText,
    this.bamtText,
    required this.type,
  });
}

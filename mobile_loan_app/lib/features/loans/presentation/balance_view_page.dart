import '../../../core/utils/safe_image_provider.dart';
import 'package:flutter/material.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_animations.dart';
import '../../../core/models/loan_model.dart';
import '../../../core/services/loan_repository.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/utils/date_utils.dart';
import '../../dashboard/presentation/widgets/company_header.dart';
import '../../collections/presentation/daily_collection_page.dart';
import 'loan_passbook_page.dart';
import 'widgets/edit_member_dialog.dart';
import '../../collections/presentation/editing_page.dart';

class BalanceViewPage extends StatefulWidget {
  final LoanRepository repository;

  const BalanceViewPage({super.key, required this.repository});

  @override
  State<BalanceViewPage> createState() => _BalanceViewPageState();
}

class _BalanceViewPageState extends State<BalanceViewPage> {
  String _selectedLine = 'All';
  late String _selectedFy;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // Filters from Image Model (Checking Party / Pending Party)
  bool _filterCheckingParty = false;
  bool _filterPendingParty = false;

  @override
  void initState() {
    super.initState();
    _selectedFy = widget.repository.selectedFinancialYear;
    widget.repository.addListener(_onRepoChanged);
  }

  void _onRepoChanged() {
    if (mounted && _selectedFy != widget.repository.selectedFinancialYear) {
      setState(() {
        _selectedFy = widget.repository.selectedFinancialYear;
      });
    }
  }

  @override
  void dispose() {
    widget.repository.removeListener(_onRepoChanged);
    _searchController.dispose();
    super.dispose();
  }

  // ignore: unused_element
  void _confirmDeleteLoan(LoanModel loan) {
    final isTamil = widget.repository.isTamil;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isTamil ? 'கணக்கை நீக்கவா?' : 'Delete Loan?'),
        content: Text(
          isTamil
              ? '${loan.bondNumber} - ${loan.customerName} கடன் கணக்கை முழுமையாக நீக்க விரும்புகிறீர்களா?\n\n(இதன் தொடர்புடைய அனைத்து வசூல் பதிவுகளும் நிரந்தரமாக நீக்கப்படும்)'
              : 'Are you sure you want to permanently delete loan ${loan.bondNumber} - ${loan.customerName}?\n\n(All associated collections will also be deleted)',
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
                await widget.repository.deleteLoan(loan.id);
                if (mounted) {
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(isTamil ? 'கடன் கணக்கு வெற்றிகரமாக நீக்கப்பட்டது' : 'Loan deleted successfully'),
                      backgroundColor: Colors.red.shade700,
                    ),
                  );
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

  void _openEditMember(LoanModel loan) {
    showDialog(
      context: context,
      builder: (_) => EditMemberDialog(
        loan: loan,
        repository: widget.repository,
        onUpdated: () {
          if (mounted) setState(() {});
        },
      ),
    );
  }

  // ignore: unused_element
  void _showLoanLedgerDialog(LoanModel loan) {
    final isTamil = widget.repository.isTamil;
    final ledger = widget.repository.getLedger(loan.bondNumber);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: ListView(
                controller: scrollController,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      // Photo
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: Colors.grey.shade200,
                        backgroundImage: getSafeImageProvider(loan.photoPath),
                        child: !isValidPhotoPath(loan.photoPath)
                            ? const Icon(Icons.person, color: Colors.grey, size: 28)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "${isTamil ? 'தவணை எண்' : 'Bond'}: ${loan.bondNumber}",
                                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.primary),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: loan.status == 'active' ? AppColors.success : Colors.grey,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    loan.status.toUpperCase(),
                                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              loan.customerName,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            if (loan.fatherOrSpouseName != null && loan.fatherOrSpouseName!.isNotEmpty)
                              Text(
                                "${isTamil ? 'தகப்பனார் / கணவர்' : 'S/o'}: ${loan.fatherOrSpouseName}",
                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Phone & ID Proofs
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Chip(
                        avatar: const Icon(Icons.phone, size: 14),
                        label: Text(loan.phoneNumber, style: const TextStyle(fontSize: 12)),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                      ),
                      if (loan.proofType != null && loan.proofType!.isNotEmpty)
                        Chip(
                          avatar: const Icon(Icons.verified_user_outlined, size: 14, color: Colors.indigo),
                          label: Text(loan.proofType!, style: const TextStyle(fontSize: 11)),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                        ),
                      if (loan.proofFrontPath != null || loan.proofBackPath != null)
                        ActionChip(
                          avatar: const Icon(Icons.image_outlined, size: 14, color: AppColors.primary),
                          label: const Text('சான்று ஆவணம் (ID Proof)', style: TextStyle(fontSize: 11, color: AppColors.primary)),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          onPressed: () => _showProofViewer(context, loan),
                        ),
                    ],
                  ),

                  const Divider(height: 18),
                  // Drawing 1 Table: [ AC | Inter | Close | Total ]
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.blue.shade200),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.blue.shade50.withValues(alpha: 0.3),
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade100,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
                          ),
                          child: Row(
                            children: [
                              Expanded(child: Text(isTamil ? "AC (தவணை)" : "AC (Bond)", textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                              Expanded(child: Text(isTamil ? "Inter (வட்டி)" : "Inter", textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                              Expanded(child: Text(isTamil ? "Close (மீதி)" : "Close (Bal)", textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                              Expanded(child: Text(isTamil ? "Total (மொத்தம்)" : "Total", textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                          child: Row(
                            children: [
                              Expanded(child: Text(loan.bondNumber, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primary))),
                              Expanded(child: Text(CurrencyUtils.format(loan.interestAmount), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
                              Expanded(child: Text(CurrencyUtils.format(loan.balanceAmount), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.error))),
                              Expanded(child: Text(CurrencyUtils.format(loan.totalAmount), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(7)),
                            border: Border(top: BorderSide(color: Colors.amber.shade200)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("All Total = ${CurrencyUtils.format(loan.totalAmount)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.deepOrange)),
                              Text("${loan.customerName} • ₹${loan.loanAmount.toStringAsFixed(0)}", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black54)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Financial Overview
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildLedgerStat(isTamil ? "கடன் தொகை" : "Loan Amt", CurrencyUtils.format(loan.loanAmount)),
                      _buildLedgerStat(isTamil ? "மொத்த பாக்கி" : "Total Outst.", CurrencyUtils.format(loan.totalAmount)),
                      _buildLedgerStat(isTamil ? "வசூலானது" : "Collected", CurrencyUtils.format(loan.collectedAmount), color: AppColors.success),
                      _buildLedgerStat(isTamil ? "மீதி பாக்கி" : "Balance", CurrencyUtils.format(loan.balanceAmount), color: AppColors.error),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Action Buttons Row (Record Collection & Edit Member & Model Details)
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            if (!widget.repository.isAdmin) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    isTamil
                                        ? 'அனுமதி இல்லை: நிர்வாகி மட்டுமே வசூல் செய்ய முடியும்.'
                                        : 'Access Denied: Only Admin can record collections.',
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => DailyCollectionPage(
                                  repository: widget.repository,
                                  initialBondNumber: loan.bondNumber,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.payments, size: 18),
                          label: Text(isTamil ? "வசூல் பதிவு" : "Collection"),
                          style: ElevatedButton.styleFrom(backgroundColor: widget.repository.isAdmin ? AppColors.primary : Colors.grey),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _showLoanDetailsFromPhoto(loan);
                          },
                          icon: const Icon(Icons.display_settings, size: 18),
                          label: Text(isTamil ? "கடன் விபரம் (Model)" : "Loan Details"),
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32), foregroundColor: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _openEditMember(loan);
                          },
                          icon: const Icon(Icons.edit_note, size: 18),
                          label: Text(isTamil ? "உறுப்பினர் திருத்தம்" : "Edit Member"),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF00796B),
                            side: const BorderSide(color: Color(0xFF00796B)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => LoanPassbookPage(
                                  loan: loan,
                                  repository: widget.repository,
                                  returnPanelTitle: isTamil ? "பாக்கித் தொகை பார்வை" : "Balance View",
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.menu_book, size: 18, color: Color(0xFF0D47A1)),
                          label: Text(isTamil ? "பாஸ்புக் (Passbook)" : "Passbook"),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF0D47A1),
                            side: const BorderSide(color: Color(0xFF0D47A1)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  Text(
                    isTamil ? "வசூல் பதிவேடு வரலாறு (Passbook Ledger)" : "Passbook Ledger",
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ledger.isEmpty
                      ? Container(
                          padding: const EdgeInsets.all(20),
                          child: Center(
                            child: Text(
                              isTamil ? "இதுவரை வசூல் பதிவுகள் இல்லை" : "No collection entries yet.",
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: ledger.length,
                          separatorBuilder: (_, index) => const Divider(height: 1),
                          itemBuilder: (context, i) {
                            final col = ledger[i];
                            return ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: CircleAvatar(
                                radius: 14,
                                backgroundColor: Colors.green.shade100,
                                child: Text('${ledger.length - i}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                              title: Text(AppDateUtils.format(col.collectionDate), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              subtitle: Text(
                                "${isTamil ? 'முன் பாக்கி' : 'Prev'}: ${CurrencyUtils.format(col.previousBalance)} → ${isTamil ? 'மீதி' : 'Bal'}: ${CurrencyUtils.format(col.currentBalance)}",
                                style: const TextStyle(fontSize: 11),
                              ),
                              trailing: Text(
                                CurrencyUtils.format(col.amount),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary),
                              ),
                            );
                          },
                        ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Exact replica modal from photo for "Loan Details" / "பாக்கித் தொகை"
  void _showLoanDetailsFromPhoto(LoanModel loan) {
    final isTamil = widget.repository.isTamil;
    final yearStr = "2026 – 2027";

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isChecking = loan.status == 'active';
            final isPending = loan.balanceAmount > 0;

            return Dialog(
              backgroundColor: const Color(0xFFC7D7F0), // Soft classic periwinkle blue window background
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: Color(0xFF4A76A8), width: 2),
              ),
              insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Window Title Bar (Windows classic style header)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        decoration: const BoxDecoration(
                          color: Color(0xFF3B6EAE),
                          borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              isTamil ? "கடன் விவரங்கள் (Loan Details)" : "Loan Details",
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            InkWell(
                              onTap: () => Navigator.pop(ctx),
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade700,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Icon(Icons.close, color: Colors.white, size: 16),
                              ),
                            ),
                          ],
                        ),
                      ),

                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // 1. Company Banner (Header)
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFD6E2F7),
                                border: Border.all(color: const Color(0xFF6B92C9)),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Center(
                                child: Text(
                                  "ஸ்ரீ சண்முகா பைனான்ஸ் – மதுரை. $yearStr",
                                  style: const TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1A3868),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),

                            // 2. தவணை எண் & உறுப்பினர் விவரம் (Photo & Name Added)
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFD6E2F7),
                                border: Border.all(color: const Color(0xFF7F9DB9)),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                children: [
                                  // Customer Photo
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(color: const Color(0xFF3B6EAE), width: 1.5),
                                      color: Colors.white,
                                    ),
                                    child: ClipOval(
                                      child: getSafeImageWidget(
                                        loan.photoPath,
                                        fit: BoxFit.cover,
                                        placeholder: const Icon(Icons.person, size: 28, color: Color(0xFF3B6EAE)),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  // Bond No & Customer Name
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              isTamil ? "தவணை எண்: " : "Bond: ",
                                              style: const TextStyle(
                                                color: Color(0xFFC62828),
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFE8EEF8),
                                                border: Border.all(color: const Color(0xFF7F9DB9)),
                                                borderRadius: BorderRadius.circular(2),
                                              ),
                                              child: Text(
                                                loan.bondNumber,
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF1565C0),
                                                borderRadius: BorderRadius.circular(3),
                                              ),
                                              child: Text(
                                                "Line ${loan.lineCode}",
                                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFE8EEF8),
                                            border: Border.all(color: const Color(0xFF7F9DB9)),
                                            borderRadius: BorderRadius.circular(2),
                                          ),
                                          child: Text(
                                            loan.customerName,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),

                            // 3. Middle Section: Financial Amounts (கடன் தொகை, வசூலான தொகை, பாக்கி) & Action Box
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Left Financials Column
                                Expanded(
                                  flex: 3,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // கடன் தொகை & வசூலான தொகை Headers & Boxes
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  isTamil ? "கடன் தொகை" : "Loan Amount",
                                                  style: const TextStyle(color: Color(0xFFC62828), fontWeight: FontWeight.bold, fontSize: 12),
                                                ),
                                                const SizedBox(height: 4),
                                                Container(
                                                  height: 32,
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFE8EEF8),
                                                    border: Border.all(color: const Color(0xFF7F9DB9)),
                                                  ),
                                                  alignment: Alignment.center,
                                                  child: Text(
                                                    CurrencyUtils.format(loan.totalAmount),
                                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0D47A1)),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  isTamil ? "வசூலான தொகை" : "Collected",
                                                  style: const TextStyle(color: Color(0xFFC62828), fontWeight: FontWeight.bold, fontSize: 12),
                                                ),
                                                const SizedBox(height: 4),
                                                Container(
                                                  height: 32,
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFE8EEF8),
                                                    border: Border.all(color: const Color(0xFF7F9DB9)),
                                                  ),
                                                  alignment: Alignment.center,
                                                  child: Text(
                                                    CurrencyUtils.format(loan.collectedAmount),
                                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1B5E20)),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),

                                      // பாக்கி (Balance) Big Box
                                      Row(
                                        children: [
                                          SizedBox(
                                            width: 70,
                                            child: Text(
                                              isTamil ? "பாக்கி" : "Balance",
                                              style: const TextStyle(color: Color(0xFFC62828), fontWeight: FontWeight.bold, fontSize: 13),
                                            ),
                                          ),
                                          Expanded(
                                            child: Container(
                                              height: 38,
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFE8EEF8),
                                                border: Border.all(color: const Color(0xFF7F9DB9), width: 1.5),
                                              ),
                                              alignment: Alignment.center,
                                              child: Text(
                                                CurrencyUtils.format(loan.balanceAmount),
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Color(0xFFB71C1C)),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),

                                // Right Passbook & Action Buttons Panel (from photo)
                                Expanded(
                                  flex: 2,
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFD3E0F5),
                                      border: Border.all(color: const Color(0xFF88A9D8)),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Column(
                                      children: [
                                        // Pass Book View Button
                                        InkWell(
                                          onTap: () {
                                            Navigator.pop(ctx);
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => LoanPassbookPage(
                                                  loan: loan,
                                                  repository: widget.repository,
                                                  returnPanelTitle: isTamil ? "பாக்கித் தொகை பார்வை" : "Balance View",
                                                ),
                                              ),
                                            );
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF6D4CD),
                                              border: Border.all(color: const Color(0xFFD32F2F).withValues(alpha: 0.4)),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Column(
                                              children: [
                                                Text(
                                                  "தினசரி வசூல்",
                                                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.brown.shade800),
                                                ),
                                                Text(
                                                  "Pass Book View",
                                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red.shade900),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 6),

                                        // Status Indicators: Checking Party & Pending Party
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              isChecking ? Icons.check_box : Icons.check_box_outline_blank,
                                              size: 13,
                                              color: Colors.blue.shade900,
                                            ),
                                            const SizedBox(width: 2),
                                            Text(
                                              "Checking",
                                              style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: Colors.blue.shade900),
                                            ),
                                            const SizedBox(width: 6),
                                            Icon(
                                              isPending ? Icons.check_box : Icons.check_box_outline_blank,
                                              size: 13,
                                              color: Colors.red.shade900,
                                            ),
                                            const SizedBox(width: 2),
                                            Text(
                                              "Pending",
                                              style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: Colors.red.shade900),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),

                                        // Update & Close Buttons (with icons matching photo)
                                        Row(
                                          children: [
                                            Expanded(
                                              child: InkWell(
                                                onTap: () {
                                                  Navigator.pop(ctx);
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (_) => LoanEditDetailPage(
                                                        loan: loan,
                                                        repository: widget.repository,
                                                        onSaved: () {
                                                          if (mounted) setState(() {});
                                                        },
                                                      ),
                                                    ),
                                                  );
                                                },
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFF0F4FA),
                                                    border: Border.all(color: Colors.blueGrey.shade400),
                                                    borderRadius: BorderRadius.circular(3),
                                                  ),
                                                  child: Column(
                                                    children: const [
                                                      Icon(Icons.check, size: 16, color: Colors.blue),
                                                      Text("Update", style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: InkWell(
                                                onTap: () => Navigator.pop(ctx),
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFF0F4FA),
                                                    border: Border.all(color: Colors.blueGrey.shade400),
                                                    borderRadius: BorderRadius.circular(3),
                                                  ),
                                                  child: Column(
                                                    children: const [
                                                      Icon(Icons.block, size: 16, color: Colors.red),
                                                      Text("Close", style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // 4. Detailed Data Grid (Drawing / Photo Lower Section)
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFD6E2F7),
                                border: Border.all(color: const Color(0xFF7F9DB9)),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Left side terms (Loan / Bond No, Starting Date, Ending Date, No. of Days, Loan Amount, Collection Line)
                                  Expanded(
                                    flex: 3,
                                    child: Column(
                                      children: [
                                        _buildPhotoFormRow("Loan / Bond No.", loan.bondNumber),
                                        const SizedBox(height: 4),
                                        _buildPhotoFormRow("Starting Date", AppDateUtils.format(loan.startDate)),
                                        const SizedBox(height: 4),
                                        _buildPhotoFormRow("Ending Date", AppDateUtils.format(loan.endDate)),
                                        const SizedBox(height: 4),
                                        _buildPhotoFormRow("No. of Days", "${loan.tenureDays}"),
                                        const SizedBox(height: 4),
                                        _buildPhotoFormRow("Loan Amount", CurrencyUtils.format(loan.loanAmount)),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            const SizedBox(
                                              width: 90,
                                              child: Text(
                                                "Collection Line",
                                                style: TextStyle(color: Color(0xFFC62828), fontWeight: FontWeight.bold, fontSize: 10.5),
                                              ),
                                            ),
                                            Container(
                                              width: 44,
                                              height: 24,
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFE8EEF8),
                                                border: Border.all(color: const Color(0xFF7F9DB9)),
                                              ),
                                              alignment: Alignment.center,
                                              child: Text(
                                                loan.lineCode,
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        _buildPhotoFormRow("Addl Date / Int", CurrencyUtils.format(loan.interestAmount)),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),

                                  // Right side Name and address 5 lines
                                  Expanded(
                                    flex: 3,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          "Name and address",
                                          style: TextStyle(color: Color(0xFFC62828), fontWeight: FontWeight.bold, fontSize: 11),
                                        ),
                                        const SizedBox(height: 4),
                                        _buildPhotoAddressLine(loan.customerName),
                                        const SizedBox(height: 3),
                                        _buildPhotoAddressLine(loan.fatherOrSpouseName != null && loan.fatherOrSpouseName!.isNotEmpty
                                            ? "S/o ${loan.fatherOrSpouseName}"
                                            : "Phone: ${loan.phoneNumber}"),
                                        const SizedBox(height: 3),
                                        _buildPhotoAddressLine(loan.address ?? ""),
                                        const SizedBox(height: 3),
                                        _buildPhotoAddressLine(loan.city ?? "மதுரை"),
                                        const SizedBox(height: 3),
                                        _buildPhotoAddressLine("Line ${loan.lineCode} • தவணை: ${CurrencyUtils.format(loan.dailyDueAmount)} / நாள்"),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPhotoFormRow(String label, String value) {
    return Row(
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: const TextStyle(color: Color(0xFFC62828), fontWeight: FontWeight.bold, fontSize: 10.5),
          ),
        ),
        Expanded(
          child: Container(
            height: 24,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFE8EEF8),
              border: Border.all(color: const Color(0xFF7F9DB9)),
            ),
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoAddressLine(String text) {
    return Container(
      height: 24,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFE8EEF8),
        border: Border.all(color: const Color(0xFF7F9DB9)),
      ),
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Colors.black87),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildLedgerStat(String label, String value, {Color? color}) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color ?? AppColors.textPrimary)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isTamil = widget.repository.isTamil;
    final currentUser = widget.repository.currentUser;
    var loans = widget.repository.getLoans(
      lineCode: _selectedLine,
      search: _searchQuery,
      financialYear: _selectedFy,
    );

    // If no loans exist in this specific selected FY, but loans exist across all periods,
    // fallback gracefully so newly registered accounts and members are never hidden!
    if (loans.isEmpty && _selectedFy != 'All') {
      final allLoans = widget.repository.getLoans(
        lineCode: _selectedLine,
        search: _searchQuery,
        financialYear: 'All',
      );
      if (allLoans.isNotEmpty) {
        loans = allLoans;
      }
    }

    // Apply Checking Party and Pending Party filters from Image model
    if (_filterCheckingParty) {
      loans = loans.where((l) => l.status == 'active').toList();
    }
    if (_filterPendingParty) {
      loans = loans.where((l) => l.balanceAmount > 0).toList();
    }

    final totalBalance = loans.fold<double>(0, (sum, l) => sum + l.balanceAmount);

    return Scaffold(
      appBar: AppBar(
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            isTamil ? "பாக்கித் தொகை" : "Balance View",
            style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold),
          ),
        ),
        backgroundColor: const Color(0xFF1565C0),
        actions: [
          // Current User Badge & Role
          if (currentUser != null)
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: currentUser.isAdmin ? Colors.amber.shade700 : Colors.teal.shade700,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(currentUser.isAdmin ? Icons.admin_panel_settings : Icons.visibility, color: Colors.white, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    currentUser.role.toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            CompanyHeader(repository: widget.repository, compact: true),

            // Search Bar & Filter Tabs
              Container(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
                color: Colors.white,
                child: Column(
                  children: [
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: isTamil ? "தவணை எண், பெயர் அல்லது சான்று..." : "Bond ID (A001), Name or Proof...",
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                      ),
                      onChanged: (v) => setState(() => _searchQuery = v),
                    ),
                    const SizedBox(height: 8),

                    // Filter Row: Line Chips & Financial Year Chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          // Line Chips
                          ...['All', ...widget.repository.availableLines].map((line) {
                            final isSel = _selectedLine == line;
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ChoiceChip(
                                label: Text(line == 'All' ? (isTamil ? 'அனைத்து Line' : 'All Lines') : "Line $line"),
                                selected: isSel,
                                selectedColor: AppColors.primary,
                                labelStyle: TextStyle(
                                  color: isSel ? Colors.white : AppColors.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11.5,
                                ),
                                onSelected: (_) => setState(() => _selectedLine = line),
                              ),
                            );
                          }),
                          Container(
                            height: 20,
                            width: 1,
                            color: Colors.grey.shade300,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                          ),
                          // Financial Year Filter Chips
                          ...[...widget.repository.availableFinancialYears, 'All'].map((fy) {
                            final isSel = _selectedFy == fy;
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: FilterChip(
                                avatar: Icon(
                                  Icons.calendar_today,
                                  size: 11,
                                  color: isSel ? Colors.white : Colors.amber.shade900,
                                ),
                                label: Text(
                                  fy == 'All' ? (isTamil ? 'அனைத்து FY' : 'All FY') : fy,
                                  style: TextStyle(
                                    color: isSel ? Colors.white : Colors.amber.shade900,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                                selected: isSel,
                                selectedColor: Colors.amber.shade800,
                                backgroundColor: Colors.amber.shade50,
                                side: BorderSide(
                                  color: isSel ? Colors.amber.shade800 : Colors.amber.shade300,
                                ),
                                onSelected: (_) {
                                  setState(() => _selectedFy = fy);
                                  widget.repository.selectFinancialYear(fy);
                                },
                              ),
                            );
                          }),
                          Container(
                            height: 20,
                            width: 1,
                            color: Colors.grey.shade300,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                          ),
                          // Filters from Photo Model: Checking Party & Pending Party
                          FilterChip(
                            avatar: Icon(
                              _filterCheckingParty ? Icons.check_circle : Icons.check_circle_outline,
                              size: 13,
                              color: _filterCheckingParty ? Colors.white : Colors.indigo.shade800,
                            ),
                            label: Text(
                              isTamil ? "Checking Party (செயல்)" : "Checking Party",
                              style: TextStyle(
                                color: _filterCheckingParty ? Colors.white : Colors.indigo.shade900,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                            selected: _filterCheckingParty,
                            selectedColor: Colors.indigo.shade700,
                            backgroundColor: Colors.indigo.shade50,
                            side: BorderSide(
                              color: _filterCheckingParty ? Colors.indigo.shade700 : Colors.indigo.shade200,
                            ),
                            onSelected: (sel) => setState(() => _filterCheckingParty = sel),
                          ),
                          const SizedBox(width: 6),
                          FilterChip(
                            avatar: Icon(
                              _filterPendingParty ? Icons.error : Icons.error_outline,
                              size: 13,
                              color: _filterPendingParty ? Colors.white : Colors.red.shade800,
                            ),
                            label: Text(
                              isTamil ? "Pending Party (பாக்கி)" : "Pending Party",
                              style: TextStyle(
                                color: _filterPendingParty ? Colors.white : Colors.red.shade900,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                            selected: _filterPendingParty,
                            selectedColor: Colors.red.shade700,
                            backgroundColor: Colors.red.shade50,
                            side: BorderSide(
                              color: _filterPendingParty ? Colors.red.shade700 : Colors.red.shade200,
                            ),
                            onSelected: (sel) => setState(() => _filterPendingParty = sel),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Total Balance Summary Banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: const Color(0xFFFFF3E0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "${isTamil ? 'கணக்குகள்' : 'Active Bonds'}: ${loans.length}",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "${isTamil ? 'மொத்த பாக்கி' : 'Total Balance'}: ",
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.deepOrange),
                          ),
                          AnimatedCountingNumber(
                            value: totalBalance,
                            isCurrency: true,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.deepOrange),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Loan List
              Expanded(
                child: loans.isEmpty
                    ? Center(
                        child: AnimatedEmptyState(
                          icon: Icons.folder_open,
                          title: isTamil ? "கடன் பதிவுகள் எதுவும் இல்லை" : "No loan accounts in database.",
                          subtitle: isTamil ? "'புதிய கடன்' பக்கத்தில் புதிய உறுப்பினரை சேர்க்கவும்." : "Add a new member from the 'New Loan' tab.",
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: loans.length,
                        itemBuilder: (context, i) {
                          final loan = loans[i];

                          return StaggeredEntrance(
                            index: i < 15 ? i : 0,
                            delay: const Duration(milliseconds: 25),
                            child: HoverScaleCard(
                              elevation: 1,
                              hoverElevation: 3,
                              hoverScale: 1.01,
                              margin: const EdgeInsets.only(bottom: 10),
                              borderRadius: BorderRadius.circular(12),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => LoanPassbookPage(
                                      loan: loan,
                                      repository: widget.repository,
                                      returnPanelTitle: isTamil ? "பாக்கித் தொகை பார்வை" : "Balance View",
                                    ),
                                  ),
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Customer Photo Avatar
                                        CircleAvatar(
                                          radius: 22,
                                          backgroundColor: Colors.grey.shade100,
                                          backgroundImage: getSafeImageProvider(loan.photoPath),
                                          child: !isValidPhotoPath(loan.photoPath)
                                              ? const Icon(Icons.person, color: Colors.grey, size: 24)
                                              : null,
                                        ),
                                        const SizedBox(width: 10),

                                        // Bond ID & Customer Details
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                    decoration: BoxDecoration(
                                                      color: AppColors.primary,
                                                      borderRadius: BorderRadius.circular(6),
                                                    ),
                                                    child: Text(
                                                      loan.bondNumber,
                                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12.5),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      loan.customerName,
                                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              if (loan.fatherOrSpouseName != null && loan.fatherOrSpouseName!.isNotEmpty)
                                                Text(
                                                  "${isTamil ? 'த/பெ' : 'S/o'}: ${loan.fatherOrSpouseName}",
                                                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                                ),
                                              Text(
                                                "${loan.phoneNumber}${loan.address != null && loan.address!.isNotEmpty ? ' • ${loan.address}' : ''}",
                                                style: const TextStyle(fontSize: 11, color: Colors.black54),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),

                                        // Balance Stat
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              isTamil ? "பாக்கித் தொகை" : "Balance",
                                              style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                                            ),
                                            Text(
                                              CurrencyUtils.format(loan.balanceAmount),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                                color: AppColors.error,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
        ),
      ),
    );
  }

  void _showProofViewer(BuildContext context, LoanModel loan) {
    final isTamil = widget.repository.isTamil;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.badge_outlined, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                loan.proofType ?? (isTamil ? 'அடையாள சான்று' : 'Identity Proof'),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (loan.proofFrontPath != null) ...[
                Text(
                  isTamil ? 'சான்று முன் பக்கம் (Front Side):' : 'Front Side:',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: getSafeImageWidget(
                    loan.proofFrontPath,
                    fit: BoxFit.contain,
                    placeholder: const Icon(Icons.broken_image),
                  ),
                ),
                const SizedBox(height: 14),
              ],
              if (loan.proofBackPath != null) ...[
                Text(
                  isTamil ? 'சான்று பின் பக்கம் (Back Side):' : 'Back Side:',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: getSafeImageWidget(
                    loan.proofBackPath,
                    fit: BoxFit.contain,
                    placeholder: const Icon(Icons.broken_image),
                  ),
                ),
              ],
              if (loan.proofFrontPath == null && loan.proofBackPath == null)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Center(
                    child: Text(isTamil ? 'சான்று படங்கள் இணைக்கப்படவில்லை' : 'No proof documents uploaded'),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(isTamil ? 'மூடு' : 'Close'),
          ),
        ],
      ),
    );
  }
}

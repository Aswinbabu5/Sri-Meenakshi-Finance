import '../../../../core/utils/safe_image_provider.dart';
import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_animations.dart';
import '../../../../core/models/loan_model.dart';
import '../../../../core/models/collection_model.dart';
import '../../../../core/services/loan_repository.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../../core/utils/date_utils.dart';
import '../../dashboard/presentation/widgets/company_header.dart';

class EditingPage extends StatefulWidget {
  final LoanRepository repository;

  const EditingPage({super.key, required this.repository});

  @override
  State<EditingPage> createState() => _EditingPageState();
}

class _EditingPageState extends State<EditingPage> {
  // Mode: 0 = Member / Loan Editing (Drawing 2), 1 = Collection Editing
  int _activeTab = 0;

  // Search input specifically for Bond Number (Drawing 2: "Search input only the bond number")
  final TextEditingController _bondSearchController = TextEditingController();
  String _selectedLineFilter = 'All';

  // Collection edit states
  late String _colLine;
  DateTime _colDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _colLine = widget.repository.selectedLine;
  }

  @override
  void dispose() {
    _bondSearchController.dispose();
    super.dispose();
  }

  // --- Delete loan with confirmation (Drawing 2: "delete the user with conformation") ---
  void _confirmDeleteLoan(LoanModel loan) {
    final isTamil = widget.repository.isTamil;

    if (!widget.repository.isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isTamil ? 'பதிவை நீக்க நிர்வாகி அனுமதி தேவை' : 'Admin access required to delete entries'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isTamil ? 'உறுப்பினரை நீக்கவா?' : 'Delete Member / Loan?',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isTamil
                  ? '${loan.bondNumber} - ${loan.customerName} கணக்கை நீக்க விரும்புகிறீர்களா?'
                  : 'Are you sure you want to delete loan ${loan.bondNumber} - ${loan.customerName}?',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              isTamil
                  ? 'இதன் தொடர்புடைய அனைத்து வசூல் பதிவுகளும் நிரந்தரமாக நீக்கப்படும். இந்த செயல்முறையை மாற்ற முடியாது.'
                  : 'All associated collection entries will also be permanently deleted. This action cannot be undone.',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(isTamil ? 'ரத்து (Cancel)' : 'Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
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
            },
            child: Text(isTamil ? 'நீக்கு (Delete)' : 'Delete'),
          ),
        ],
      ),
    );
  }

  // --- Open full Editing Form for Member & Loan (Drawing 2: "once clicked the editing page should visible") ---
  void _openLoanEditForm(LoanModel loan) {
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
  }

  // --- Collection Editing Dialogs (legacy support) ---
  void _editCollection(CollectionModel col) {
    final isTamil = widget.repository.isTamil;
    if (!widget.repository.isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isTamil ? 'வசூல் தொகையை திருத்த நிர்வாகி அனுமதி தேவை.' : 'Admin access required to edit collections.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    final controller = TextEditingController(text: col.amount.toStringAsFixed(0));

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Text(isTamil ? "வசூல் தொகை திருத்தம்" : "Edit Collected Amount"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("${isTamil ? 'தவணை எண்' : 'Bond'}: ${col.bondNumber}"),
              Text("${isTamil ? 'பெயர்' : 'Name'}: ${col.customerName}"),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: isTamil ? "புதிய வசூல் தொகை (New Amount)" : "New Amount",
                  prefixText: "₹ ",
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(isTamil ? "ரத்து" : "Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
              onPressed: () async {
                final newAmt = double.tryParse(controller.text) ?? 0;
                if (newAmt > 0) {
                  await widget.repository.updateCollection(col.id, newAmt);
                  if (context.mounted) {
                    Navigator.pop(context);
                    setState(() {});
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(isTamil ? "தொகை வெற்றிகரமாக திருத்தப்பட்டது" : "Amount updated successfully"),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  }
                }
              },
              child: Text(isTamil ? "சேமி" : "Update"),
            ),
          ],
        );
      },
    );
  }

  void _deleteCollection(CollectionModel col) {
    final isTamil = widget.repository.isTamil;
    if (!widget.repository.isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isTamil ? 'பதிவை நீக்க நிர்வாகி அனுமதி தேவை' : 'Admin access required to delete entries'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Text(isTamil ? "வசூல் பதிவை நீக்கவா?" : "Delete Entry?"),
          content: Text(
            isTamil
                ? "${col.bondNumber} - ₹${col.amount} பதிவை நீக்கினால் பழைய பாக்கி திரும்ப அமைக்கப்படும்."
                : "Deleting this collection will revert the loan balance.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(isTamil ? "ரத்து" : "Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
              onPressed: () async {
                await widget.repository.deleteCollection(col.id);
                if (context.mounted) {
                  Navigator.pop(context);
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(isTamil ? "பதிவு நீக்கப்பட்டது" : "Collection entry deleted"),
                      backgroundColor: AppColors.warning,
                    ),
                  );
                }
              },
              child: Text(isTamil ? "நீக்கு" : "Delete"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isTamil = widget.repository.isTamil;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallPhone = screenWidth < 360;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F8),
      appBar: AppBar(
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            isTamil ? "பிழை திருத்தம்" : "Editing & Corrections",
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
        ),
        backgroundColor: const Color(0xFF1565C0),
        elevation: 1,
      ),
      body: SafeArea(
        child: Column(
          children: [
            CompanyHeader(repository: widget.repository, compact: true),

            // Top Segmented Bar: Member / Loan Editing vs Collection Editing
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: Colors.white,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1440),
                  child: Row(
                    children: [
                      Expanded(
                        child: AnimatedPressable(
                          onTap: () => setState(() => _activeTab = 0),
                          child: AnimatedContainer(
                            duration: AppAnimations.fast,
                            curve: Curves.easeInOut,
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                            decoration: BoxDecoration(
                              color: _activeTab == 0 ? const Color(0xFF1565C0) : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: _activeTab == 0 ? const Color(0xFF1565C0) : Colors.grey.shade300),
                            ),
                            alignment: Alignment.center,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                isTamil ? "கடன் & உறுப்பினர்" : "Loan & Member",
                                style: TextStyle(
                                  fontSize: isSmallPhone ? 11.5 : 13,
                                  fontWeight: FontWeight.bold,
                                  color: _activeTab == 0 ? Colors.white : Colors.black87,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: AnimatedPressable(
                          onTap: () => setState(() => _activeTab = 1),
                          child: AnimatedContainer(
                            duration: AppAnimations.fast,
                            curve: Curves.easeInOut,
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                            decoration: BoxDecoration(
                              color: _activeTab == 1 ? const Color(0xFF00796B) : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: _activeTab == 1 ? const Color(0xFF00796B) : Colors.grey.shade300),
                            ),
                            alignment: Alignment.center,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                isTamil ? "வசூல் திருத்தம்" : "Collections",
                                style: TextStyle(
                                  fontSize: isSmallPhone ? 11.5 : 13,
                                  fontWeight: FontWeight.bold,
                                  color: _activeTab == 1 ? Colors.white : Colors.black87,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Divider(height: 1),

            // Content according to selected tab
            Expanded(
              child: _activeTab == 0
                  ? _buildLoanMemberEditingView(isTamil, isSmallPhone)
                  : _buildCollectionEditingView(isTamil),
            ),
          ],
        ),
      ),
    );
  }

  // --- Main View matching Drawing 2 ("editing page") ---
  Widget _buildLoanMemberEditingView(bool isTamil, bool isSmallPhone) {
    final query = _bondSearchController.text.trim();
    var loans = widget.repository.getLoans(
      lineCode: _selectedLineFilter,
      search: query,
    );

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1440),
        child: Column(
          children: [
            // Search Input only the Bond Number (Drawing 2: "Search input only the bond number")
            Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
              color: Colors.white,
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _bondSearchController,
                          decoration: InputDecoration(
                            labelText: isTamil ? "தவணை எண் தேடல்" : "Search Bond Number",
                            hintText: isTamil ? "எ.கா: A001 அல்லது 001" : "e.g. A001 or 001",
                            prefixIcon: const Icon(Icons.tag, color: AppColors.primary),
                            suffixIcon: query.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () {
                                      _bondSearchController.clear();
                                      setState(() {});
                                    },
                                  )
                                : null,
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Line filter dropdown
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade400),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedLineFilter,
                            items: ['All', 'A', 'B', 'C', 'D'].map((l) {
                              return DropdownMenuItem(
                                value: l,
                                child: Text(l == 'All' ? (isTamil ? 'அனைத்து' : 'All') : 'Line $l', style: const TextStyle(fontSize: 13)),
                              );
                            }).toList(),
                            onChanged: (v) {
                              if (v != null) setState(() => _selectedLineFilter = v);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      isTamil
                          ? "உறுப்பினர் அட்டையை தொட்டு முழு விபரங்களை திருத்தலாம். சிவப்பு பொத்தான் நீக்க பயன்படும்."
                          : "Tap any member to edit loan particulars. Use delete icon to remove.",
                      style: const TextStyle(fontSize: 11, color: Colors.black54),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // List of Users / Loans (Drawing 2)
            Expanded(
              child: loans.isEmpty
                  ? Center(
                      child: AnimatedEmptyState(
                        icon: Icons.search_off,
                        title: isTamil ? "கடன்கள் எதுவும் கிடைக்கவில்லை" : "No matching loans found",
                        subtitle: isTamil ? "தவணை எண் அல்லது லைன் தேர்வை மாற்றி தேடவும்." : "Try searching with a different bond number or line filter.",
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
                          child: _buildLoanCard(loan, isTamil, isSmallPhone),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // Member Card in Editing List (Drawing 2: photo, details of member, delete user with confirmation)
  Widget _buildLoanCard(LoanModel loan, bool isTamil, bool isSmallPhone) {
    return HoverScaleCard(
      margin: const EdgeInsets.only(bottom: 10),
      borderRadius: BorderRadius.circular(12),
      elevation: 1.5,
      hoverElevation: 3.5,
      hoverScale: 1.01,
      onTap: () => _openLoanEditForm(loan), // Clicked -> opens editing form
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Photo of Member (Drawing 2: "Photo")
            CircleAvatar(
              radius: 24,
              backgroundColor: Colors.blue.shade100,
              backgroundImage: getSafeImageProvider(loan.photoPath),
              child: !isValidPhotoPath(loan.photoPath)
                  ? Text(
                      loan.bondNumber,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                    )
                  : null,
            ),
            const SizedBox(width: 10),

            // Details of Member (Drawing 2: "details member")
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          loan.bondNumber,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          loan.customerName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    "${loan.phoneNumber} • ${isTamil ? 'லைன்' : 'Line'} ${loan.lineCode}",
                    style: const TextStyle(fontSize: 11, color: Colors.black54),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Wrap(
                    spacing: 8,
                    runSpacing: 2,
                    children: [
                      Text(
                        "${isTamil ? 'கடன்' : 'Loan'}: ${CurrencyUtils.format(loan.loanAmount)}",
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        "${isTamil ? 'பாக்கி' : 'Bal'}: ${CurrencyUtils.format(loan.balanceAmount)}",
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.error),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Action icons
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_note, color: Color(0xFF1565C0), size: 22),
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(),
                  visualDensity: VisualDensity.compact,
                  tooltip: isTamil ? "திருத்துக" : "Edit",
                  onPressed: () => _openLoanEditForm(loan),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 22),
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(),
                  visualDensity: VisualDensity.compact,
                  tooltip: isTamil ? "நீக்குக" : "Delete",
                  onPressed: () => _confirmDeleteLoan(loan),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- Collection Editing List (legacy view) ---
  Widget _buildCollectionEditingView(bool isTamil) {
    final sheet = widget.repository.getDailySheet(
      date: _colDate,
      lineCode: _colLine,
    );

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1440),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              color: Colors.blue.shade50,
              child: Row(
                children: [
                  Text(
                    isTamil ? "வசூல் Line:" : "Line:",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: _colLine,
                    items: ['All', 'A', 'B', 'C', 'D'].map((l) {
                      return DropdownMenuItem(value: l, child: Text(l == 'All' ? 'All Lines' : "Line $l"));
                    }).toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _colLine = v);
                    },
                  ),
                  const Spacer(),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _colDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2035),
                      );
                      if (picked != null) setState(() => _colDate = picked);
                    },
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 16, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Text(
                          AppDateUtils.formatSlash(_colDate),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: sheet.isEmpty
                  ? Center(
                      child: AnimatedEmptyState(
                        icon: Icons.calendar_month_outlined,
                        title: isTamil ? "இந்த தேதியில் வசூல் பதிவுகள் இல்லை" : "No entries found for this date & line",
                        subtitle: isTamil ? "தேதி அல்லது லைனை மாற்றி முயற்சிக்கவும்." : "Select another date or line to view recorded collections.",
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: sheet.length,
                      itemBuilder: (context, i) {
                        final col = sheet[i];
                        return StaggeredEntrance(
                          index: i < 15 ? i : 0,
                          delay: const Duration(milliseconds: 20),
                          child: HoverScaleCard(
                            elevation: 1,
                            hoverElevation: 2.5,
                            hoverScale: 1.01,
                            margin: const EdgeInsets.only(bottom: 8),
                            borderRadius: BorderRadius.circular(10),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: AppColors.goldLight,
                                child: Text(
                                  col.bondNumber,
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                                ),
                              ),
                              title: Text(col.customerName, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text("${isTamil ? 'வசூலானது' : 'Amount'}: ${CurrencyUtils.format(col.amount)}  |  ${isTamil ? 'மீதி' : 'Bal'}: ${CurrencyUtils.format(col.currentBalance)}"),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  AnimatedPressable(
                                    onTap: () => _editCollection(col),
                                    child: IconButton(
                                      icon: const Icon(Icons.edit, color: Colors.blue),
                                      onPressed: () => _editCollection(col),
                                    ),
                                  ),
                                  if (widget.repository.isAdmin)
                                    AnimatedPressable(
                                      onTap: () => _deleteCollection(col),
                                      child: IconButton(
                                        icon: const Icon(Icons.delete_outline, color: AppColors.error),
                                        onPressed: () => _deleteCollection(col),
                                      ),
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
}

// ============================================================================
// FULL EDITING FORM SCREEN (Drawing 2: "once clicked the editing page should visible")
// Fields: Line, B NO, Tenure, Chit fee, Loan amt, Int, Date (SD), E Date (ED), Extra amt, change, cancel
// ============================================================================
class LoanEditDetailPage extends StatefulWidget {
  final LoanModel loan;
  final LoanRepository repository;
  final VoidCallback onSaved;

  const LoanEditDetailPage({
    super.key,
    required this.loan,
    required this.repository,
    required this.onSaved,
  });

  @override
  State<LoanEditDetailPage> createState() => _LoanEditDetailPageState();
}

class _LoanEditDetailPageState extends State<LoanEditDetailPage> {
  final _formKey = GlobalKey<FormState>();

  late String _lineCode;
  late TextEditingController _bondNoController;
  late TextEditingController _tenureController;
  late TextEditingController _chitFeeController;
  late TextEditingController _loanAmtController;
  late TextEditingController _interestController;
  late TextEditingController _extraAmtController;
  late TextEditingController _customerNameController;
  late TextEditingController _fatherNameController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  late TextEditingController _cityController;

  late DateTime _startDate;
  late DateTime _endDate;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final l = widget.loan;
    _lineCode = l.lineCode;
    _bondNoController = TextEditingController(text: l.bondNumber);
    _tenureController = TextEditingController(text: l.tenureDays.toString());
    _chitFeeController = TextEditingController(text: l.chitFee.toStringAsFixed(0));
    _loanAmtController = TextEditingController(text: l.loanAmount.toStringAsFixed(0));
    _interestController = TextEditingController(text: l.interestAmount.toStringAsFixed(0));
    _extraAmtController = TextEditingController(text: l.customer?.notes ?? '');
    _customerNameController = TextEditingController(text: l.customerName);
    _fatherNameController = TextEditingController(text: l.fatherOrSpouseName ?? '');
    _phoneController = TextEditingController(text: l.phoneNumber);
    _addressController = TextEditingController(text: l.address ?? '');
    _cityController = TextEditingController(text: l.city ?? 'மதுரை');
    _startDate = l.startDate;
    _endDate = l.endDate;
  }

  @override
  void dispose() {
    _bondNoController.dispose();
    _tenureController.dispose();
    _chitFeeController.dispose();
    _loanAmtController.dispose();
    _interestController.dispose();
    _extraAmtController.dispose();
    _customerNameController.dispose();
    _fatherNameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  void _recalcEndDate() {
    final tenure = int.tryParse(_tenureController.text) ?? 100;
    setState(() {
      _endDate = _startDate.add(Duration(days: tenure));
    });
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
        final tenure = int.tryParse(_tenureController.text) ?? 100;
        _endDate = _startDate.add(Duration(days: tenure));
      });
    }
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate,
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() => _endDate = picked);
    }
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final isTamil = widget.repository.isTamil;

    try {
      final tenure = int.tryParse(_tenureController.text) ?? 100;
      final loanAmt = double.tryParse(_loanAmtController.text) ?? widget.loan.loanAmount;
      final intAmt = double.tryParse(_interestController.text) ?? widget.loan.interestAmount;
      final chitFee = double.tryParse(_chitFeeController.text) ?? widget.loan.chitFee;

      await widget.repository.updateMember(
        loanId: widget.loan.id,
        lineCode: _lineCode,
        bondNumber: _bondNoController.text.trim(),
        customerName: _customerNameController.text.trim(),
        fatherOrSpouseName: _fatherNameController.text.trim().isEmpty ? null : _fatherNameController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
        city: _cityController.text.trim(),
        notes: _extraAmtController.text.trim().isEmpty ? null : _extraAmtController.text.trim(),
        loanAmount: loanAmt,
        interestAmount: intAmt,
        chitFee: chitFee,
        tenureDays: tenure,
        startDate: _startDate,
        endDate: _endDate,
      );

      if (mounted) {
        setState(() => _isSaving = false);
        widget.onSaved();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isTamil ? 'விபரங்கள் வெற்றிகரமாக மாற்றப்பட்டது (Updated)' : 'Changes saved successfully'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTamil = widget.repository.isTamil;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallPhone = screenWidth < 360;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F8),
      appBar: AppBar(
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            isTamil ? "கடன் & உறுப்பினர் திருத்தம்" : "Editing Loan & Member",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
          ),
        ),
        backgroundColor: const Color(0xFF1565C0),
        elevation: 1,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1440),
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isSmallPhone ? 10 : 16,
                vertical: 14,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Card containing all fields from Drawing 2:
                    // Line, B NO, Tenure, Chit fee, Loan amt, Int, Date, E Date, Extra amt
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.blue.shade200),
                        boxShadow: const [
                          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 1)),
                        ],
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.edit_note, color: AppColors.primary, size: 22),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  isTamil ? "கடன் விபரங்கள் திருத்தம்" : "Edit Loan Terms",
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primary),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 20),

                          // Row 1: Line (dropdown) & B NO (Bond No) (Drawing 2: "line v", "B NO")
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: DropdownButtonFormField<String>(
                                  initialValue: widget.repository.availableLines.contains(_lineCode)
                                      ? _lineCode
                                      : (widget.repository.availableLines.isNotEmpty ? widget.repository.availableLines.first : null),
                                  isDense: true,
                                  isExpanded: true,
                                  decoration: InputDecoration(
                                    labelText: isTamil ? "வரிசை" : "Line",
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                    filled: true,
                                    fillColor: Colors.grey.shade50,
                                  ),
                                  items: widget.repository.availableLines.map((l) {
                                    return DropdownMenuItem(value: l, child: Text("Line $l", overflow: TextOverflow.ellipsis));
                                  }).toList(),
                                  onChanged: (v) {
                                    if (v != null) setState(() => _lineCode = v);
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 3,
                                child: TextFormField(
                                  controller: _bondNoController,
                                  decoration: InputDecoration(
                                    labelText: isTamil ? "தவணை எண்" : "Bond No (B NO)",
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                    filled: true,
                                    fillColor: Colors.grey.shade50,
                                  ),
                                  validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Row 2: Tenure & Chit Fee (Drawing 2: "Tenure", "chit fee")
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _tenureController,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    labelText: isTamil ? "தவணை நாட்கள்" : "Tenure Days",
                                    suffixText: isTamil ? "நாள்" : "Days",
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                    isDense: true,
                                    filled: true,
                                    fillColor: Colors.grey.shade50,
                                  ),
                                  onChanged: (_) => _recalcEndDate(),
                                  validator: (v) => (int.tryParse(v ?? '') ?? 0) <= 0 ? 'Invalid' : null,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextFormField(
                                  controller: _chitFeeController,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    labelText: isTamil ? "சீட்டு காசு" : "Chit Fee",
                                    prefixText: "₹ ",
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                    isDense: true,
                                    filled: true,
                                    fillColor: Colors.grey.shade50,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Row 3: Loan Amt & Int (Drawing 2: "loan amt", "Int")
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _loanAmtController,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    labelText: isTamil ? "கடன் தொகை" : "Loan Amount",
                                    prefixText: "₹ ",
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                    isDense: true,
                                    filled: true,
                                    fillColor: Colors.grey.shade50,
                                  ),
                                  validator: (v) => (double.tryParse(v ?? '') ?? 0) <= 0 ? 'Invalid' : null,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextFormField(
                                  controller: _interestController,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    labelText: isTamil ? "வட்டி தொகை" : "Interest Amt (Int)",
                                    prefixText: "₹ ",
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                    isDense: true,
                                    filled: true,
                                    fillColor: Colors.grey.shade50,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Row 4: Date (SD) & E Date (ED) (Drawing 2: "date", "E date")
                          Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: _pickStartDate,
                                  child: InputDecorator(
                                    decoration: InputDecoration(
                                      labelText: isTamil ? "தொடக்க தேதி" : "Start Date",
                                      suffixIconConstraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                                      suffixIcon: const Padding(
                                        padding: EdgeInsets.only(right: 6),
                                        child: Icon(Icons.calendar_month, size: 16),
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                      isDense: true,
                                      filled: true,
                                      fillColor: Colors.grey.shade50,
                                    ),
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text(AppDateUtils.format(_startDate)),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: InkWell(
                                  onTap: _pickEndDate,
                                  child: InputDecorator(
                                    decoration: InputDecoration(
                                      labelText: isTamil ? "முடிவு தேதி" : "End Date",
                                      suffixIconConstraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                                      suffixIcon: const Padding(
                                        padding: EdgeInsets.only(right: 6),
                                        child: Icon(Icons.calendar_month, size: 16),
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                      isDense: true,
                                      filled: true,
                                      fillColor: Colors.grey.shade50,
                                    ),
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text(AppDateUtils.format(_endDate)),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Row 5: Extra Amt / Notes (Drawing 2: "extra amt")
                          TextFormField(
                            controller: _extraAmtController,
                            decoration: InputDecoration(
                              labelText: isTamil ? "கூடுதல் விபரம் / குறிப்பு" : "Extra Amt / Notes",
                              prefixIcon: const Icon(Icons.notes),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Member Details Card
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.green.shade200),
                        boxShadow: const [
                          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 1)),
                        ],
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.person, color: Colors.green, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  isTamil ? "உறுப்பினர் தனிப்பட்ட விபரங்கள்" : "Member Personal Info",
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.green),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 18),
                          TextFormField(
                            controller: _customerNameController,
                            decoration: InputDecoration(
                              labelText: isTamil ? "பெயர் *" : "Name *",
                              prefixIcon: const Icon(Icons.person_outline),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                            ),
                            validator: (v) => v == null || v.trim().isEmpty ? 'Name required' : null,
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: TextFormField(
                                  controller: _fatherNameController,
                                  decoration: InputDecoration(
                                    labelText: isTamil ? "தகப்பனார் / கணவர்" : "Father / Spouse",
                                    filled: true,
                                    fillColor: Colors.grey.shade50,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  controller: _cityController,
                                  decoration: InputDecoration(
                                    labelText: isTamil ? "ஊர்" : "City",
                                    filled: true,
                                    fillColor: Colors.grey.shade50,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            decoration: InputDecoration(
                              labelText: isTamil ? "அலைபேசி எண்" : "Phone Number",
                              prefixIcon: const Icon(Icons.phone),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _addressController,
                            maxLines: 2,
                            decoration: InputDecoration(
                              labelText: isTamil ? "முகவரி" : "Address",
                              prefixIcon: const Icon(Icons.home_outlined),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Change & Cancel Buttons (Drawing 2: "change", "cancel")
                    Row(
                      children: [
                        // Cancel Button (Drawing 2: "cancel")
                        Expanded(
                          flex: 2,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                              side: BorderSide(color: Colors.grey.shade400),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () => Navigator.pop(context),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                isTamil ? "ரத்து" : "Cancel",
                                style: TextStyle(color: Colors.grey.shade800, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Change / Update Button (Drawing 2: "change")
                        Expanded(
                          flex: 3,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1565C0),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              elevation: 3,
                            ),
                            onPressed: _isSaving ? null : _saveChanges,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (_isSaving)
                                    const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  else
                                    const Icon(Icons.check, size: 18),
                                  const SizedBox(width: 6),
                                  Text(
                                    _isSaving
                                        ? (isTamil ? "மாற்றுகிறது..." : "Saving...")
                                        : (isTamil ? "சேமிக்க" : "Save Changes"),
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

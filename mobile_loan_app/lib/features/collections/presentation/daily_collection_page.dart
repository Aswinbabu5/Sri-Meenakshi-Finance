import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_animations.dart';
import '../../../../core/models/loan_model.dart';
import '../../../../core/models/collection_model.dart';
import '../../../../core/services/loan_repository.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../../core/utils/date_utils.dart';
import '../../dashboard/presentation/widgets/company_header.dart';
import '../../dashboard/presentation/widgets/find_bond_dialog.dart';

class DailyCollectionPage extends StatefulWidget {
  final LoanRepository repository;
  final String? initialBondNumber;
  final String receiptType; // 'Note' or 'Chit'

  const DailyCollectionPage({
    super.key,
    required this.repository,
    this.initialBondNumber,
    this.receiptType = 'Note',
  });

  @override
  State<DailyCollectionPage> createState() => _DailyCollectionPageState();
}

class _DailyCollectionPageState extends State<DailyCollectionPage> {
  late String _selectedLine;
  DateTime _collectionDate = DateTime.now();

  late TextEditingController _bondNoController;
  late TextEditingController _cashAmountController;
  late TextEditingController _gpayAmountController;
  late TextEditingController _notesController;
  String _paymentMode = 'Cash'; // 'Cash' or 'Online'

  double get _cashAmount => double.tryParse(_cashAmountController.text.trim()) ?? 0.0;
  double get _gpayAmount => double.tryParse(_gpayAmountController.text.trim()) ?? 0.0;
  double get _totalCollectedAmount => _cashAmount + _gpayAmount;

  LoanModel? _currentLoan;
  CollectionModel? _todayExistingCollection;
  List<CollectionModel> _todayExistingCollections = [];

  @override
  void initState() {
    super.initState();
    _selectedLine = widget.repository.selectedLine;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (_collectionDate.isBefore(today)) {
      _collectionDate = today;
    }

    _bondNoController = TextEditingController();
    _cashAmountController = TextEditingController();
    _gpayAmountController = TextEditingController();
    _notesController = TextEditingController();

    _cashAmountController.addListener(() => setState(() {}));
    _gpayAmountController.addListener(() => setState(() {}));

    if (widget.initialBondNumber != null && widget.initialBondNumber!.isNotEmpty) {
      final bond = widget.initialBondNumber!.trim().toUpperCase();
      if (bond.contains('-')) {
        final parts = bond.split('-');
        _selectedLine = parts[0];
        _bondNoController.text = parts[1];
      } else if (RegExp(r'^[A-Z]').hasMatch(bond)) {
        _selectedLine = bond[0];
        _bondNoController.text = bond.substring(1);
      } else {
        _bondNoController.text = bond;
      }
      _fetchBondDetails();
    }
  }

  @override
  void dispose() {
    _bondNoController.dispose();
    _cashAmountController.dispose();
    _gpayAmountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _fetchBondDetails() {
    final rawBond = _bondNoController.text.trim();
    if (rawBond.isEmpty) {
      setState(() {
        _currentLoan = null;
        _cashAmountController.clear();
        _gpayAmountController.clear();
        _todayExistingCollection = null;
        _todayExistingCollections = [];
      });
      return;
    }

    final fullBond = widget.repository.formatBondNumber(_selectedLine, rawBond);
    final loan = widget.repository.getLoanByBond(fullBond, _selectedLine) ?? widget.repository.getLoanByBond(rawBond, _selectedLine);

    CollectionModel? todayCol;
    List<CollectionModel> todayCols = [];
    if (loan != null) {
      todayCol = widget.repository.getTodayCollectionForLoan(loan.bondNumber, _collectionDate);
      todayCols = widget.repository.getTodayCollectionsForLoan(loan.bondNumber, _collectionDate);
    }

    setState(() {
      _currentLoan = loan;
      _todayExistingCollection = todayCol;
      _todayExistingCollections = todayCols;
      if (loan != null) {
        final dueStr = loan.dailyDueAmount.toStringAsFixed(0);
        if (_paymentMode == 'Online') {
          _gpayAmountController.text = dueStr;
          _cashAmountController.clear();
        } else {
          _cashAmountController.text = dueStr;
          _gpayAmountController.clear();
        }
      } else {
        _cashAmountController.clear();
        _gpayAmountController.clear();
      }
    });
  }

  void _setPaymentMode(String mode) {
    setState(() {
      _paymentMode = mode;
      final dueStr = _currentLoan?.dailyDueAmount.toStringAsFixed(0) ?? '';
      if (mode == 'Cash') {
        if (_cashAmountController.text.isEmpty && _gpayAmountController.text.isNotEmpty) {
          _cashAmountController.text = _gpayAmountController.text;
          _gpayAmountController.clear();
        } else if (_cashAmountController.text.isEmpty && _gpayAmountController.text.isEmpty && dueStr.isNotEmpty) {
          _cashAmountController.text = dueStr;
        }
      } else {
        if (_gpayAmountController.text.isEmpty && _cashAmountController.text.isNotEmpty) {
          _gpayAmountController.text = _cashAmountController.text;
          _cashAmountController.clear();
        } else if (_gpayAmountController.text.isEmpty && _cashAmountController.text.isEmpty && dueStr.isNotEmpty) {
          _gpayAmountController.text = dueStr;
        }
      }
    });
  }

  Future<void> _toggleTargetCustomer(bool value) async {
    if (_currentLoan == null) return;
    try {
      await widget.repository.toggleTargetCustomer(_currentLoan!.bondNumber, value);
      _fetchBondDetails();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value
                ? (widget.repository.isTamil
                    ? "வாடிக்கையாளர் இலக்கு வாடிக்கையாளராக குறிக்கப்பட்டார் (Target Customer)!"
                    : "Marked as Target Customer!")
                : (widget.repository.isTamil
                    ? "இலக்கு வாடிக்கையாளர் குறிப்பு நீக்கப்பட்டது"
                    : "Target Customer mark removed"),
          ),
          duration: const Duration(seconds: 1),
          backgroundColor: value ? Colors.purple.shade700 : Colors.grey.shade700,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _saveCollection({bool advanceNext = false}) async {
    final isTamil = widget.repository.isTamil;
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

    if (_currentLoan == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isTamil
                ? 'செல்லுபடியாகும் தவணை எண்ணை (Bond No) உள்ளிடவும்'
                : 'Please enter a valid Bond Number',
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selectedDay = DateTime(_collectionDate.year, _collectionDate.month, _collectionDate.day);
    if (selectedDay.isBefore(today)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isTamil
                ? 'முந்தைய தேதியில் வசூல் செய்ய முடியாது. இன்றைய அல்லது அடுத்த தேதியை தேர்வு செய்யவும்.'
                : 'Cannot record collection for a previous date. Please choose current date or future date.',
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final cash = _cashAmount;
    final gpay = _gpayAmount;
    final total = _totalCollectedAmount;

    if (total <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isTamil
                ? 'சரியான வசூல் தொகையை ரொக்கம் அல்லது Gpay-ல் உள்ளிடவும்'
                : 'Please enter valid collected amount in Cash or Gpay',
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    try {
      final wasAlreadyPaidToday = _todayExistingCollection != null || _todayExistingCollections.isNotEmpty;
      final effectiveBond = _currentLoan!.bondNumber;
      final notesText = _notesController.text.trim().isEmpty ? null : _notesController.text.trim();
      CollectionModel? lastCol;

      if (cash > 0) {
        lastCol = await widget.repository.recordCollection(
          bondNumber: effectiveBond,
          lineCode: _selectedLine,
          amount: cash,
          collectionDate: _collectionDate,
          receiptType: widget.receiptType,
          paymentMode: 'Cash',
          personName: _currentLoan!.customerName,
          notes: notesText,
        );
      }

      if (gpay > 0) {
        lastCol = await widget.repository.recordCollection(
          bondNumber: effectiveBond,
          lineCode: _selectedLine,
          amount: gpay,
          collectionDate: _collectionDate,
          receiptType: widget.receiptType,
          paymentMode: 'Online',
          personName: _currentLoan!.customerName,
          notes: notesText,
        );
      }

      final col = lastCol!;

      String successMsg;
      if (cash > 0 && gpay > 0) {
        successMsg = isTamil
            ? '${col.customerName} - மொத்த வசூல் ₹${total.toStringAsFixed(0)} (ரொக்கம்: ₹${cash.toStringAsFixed(0)}, Gpay: ₹${gpay.toStringAsFixed(0)}) பதிவானது!${col.currentBalance > 0 ? " (மீதி: ₹${col.currentBalance.toStringAsFixed(0)})" : ""}'
            : '${col.customerName} - Total ₹${total.toStringAsFixed(0)} (Cash: ₹${cash.toStringAsFixed(0)}, Gpay: ₹${gpay.toStringAsFixed(0)}) recorded!${col.currentBalance > 0 ? " (Balance: ₹${col.currentBalance.toStringAsFixed(0)})" : ""}';
      } else if (cash > 0) {
        successMsg = isTamil
            ? (wasAlreadyPaidToday
                ? '${col.customerName} - ரொக்கம் ₹${cash.toStringAsFixed(0)} சேர்க்கப்பட்டது!${col.currentBalance > 0 ? " (மீதி: ₹${col.currentBalance.toStringAsFixed(0)})" : ""}'
                : '${col.customerName} - ரொக்கம் ₹${cash.toStringAsFixed(0)} வசூல் பதிவானது!${col.currentBalance > 0 ? " (மீதி: ₹${col.currentBalance.toStringAsFixed(0)})" : ""}')
            : (wasAlreadyPaidToday
                ? '${col.customerName} - Cash ₹${cash.toStringAsFixed(0)} added!${col.currentBalance > 0 ? " (Balance: ₹${col.currentBalance.toStringAsFixed(0)})" : ""}'
                : '${col.customerName} - Cash ₹${cash.toStringAsFixed(0)} recorded!${col.currentBalance > 0 ? " (Balance: ₹${col.currentBalance.toStringAsFixed(0)})" : ""}');
      } else {
        successMsg = isTamil
            ? (wasAlreadyPaidToday
                ? '${col.customerName} - Gpay ₹${gpay.toStringAsFixed(0)} சேர்க்கப்பட்டது!${col.currentBalance > 0 ? " (மீதி: ₹${col.currentBalance.toStringAsFixed(0)})" : ""}'
                : '${col.customerName} - Gpay ₹${gpay.toStringAsFixed(0)} வசூல் பதிவானது!${col.currentBalance > 0 ? " (மீதி: ₹${col.currentBalance.toStringAsFixed(0)})" : ""}')
            : (wasAlreadyPaidToday
                ? '${col.customerName} - Gpay ₹${gpay.toStringAsFixed(0)} added!${col.currentBalance > 0 ? " (Balance: ₹${col.currentBalance.toStringAsFixed(0)})" : ""}'
                : '${col.customerName} - Gpay ₹${gpay.toStringAsFixed(0)} recorded!${col.currentBalance > 0 ? " (Balance: ₹${col.currentBalance.toStringAsFixed(0)})" : ""}');
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(successMsg),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 2),
        ),
      );

      _notesController.clear();
      if (advanceNext) {
        // Auto-increment bond number (e.g. 001 -> 002)
        final curNum = int.tryParse(_bondNoController.text.trim()) ?? 0;
        if (curNum > 0) {
          _bondNoController.text = (curNum + 1).toString().padLeft(3, '0');
          _fetchBondDetails();
        } else {
          _fetchBondDetails();
        }
      } else {
        _fetchBondDetails();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  void _pickDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final initial = _collectionDate.isBefore(today) ? today : _collectionDate;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: today,
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() {
        _collectionDate = picked;
        _fetchBondDetails();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTamil = widget.repository.isTamil;
    final dailySheet = widget.repository.getDailySheet(
      date: _collectionDate,
      lineCode: _selectedLine,
    );
    final totalSheetAmt = dailySheet.fold<double>(0, (sum, c) => sum + c.amount);
    final dayCollection = totalSheetAmt;

    final receiptTitle = widget.receiptType == 'Chit'
        ? (isTamil ? "தினசரி கைசிட்டை வசூல்" : "Daily Chit Collection")
        : (isTamil ? "தினசரி வசூல்" : "Daily Collection");

    return Scaffold(
      appBar: AppBar(
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(receiptTitle),
        ),
        backgroundColor: const Color(0xFF1565C0),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: isTamil ? "தவணை எண் தேடல்" : "Find Bond",
            onPressed: () => showDialog(
              context: context,
              builder: (_) => FindBondDialog(repository: widget.repository),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            CompanyHeader(repository: widget.repository, compact: true),

            // Top Filter Bar (Line & Collection Date)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: Colors.blue.shade100,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  children: [
                    // Line Picker
                    Text(
                      isTamil ? "வசூல் Line:" : "Line:",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.blue.shade400),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: widget.repository.availableLines.contains(_selectedLine)
                              ? _selectedLine
                              : (widget.repository.availableLines.isNotEmpty ? widget.repository.availableLines.first : 'A'),
                          isDense: true,
                          items: widget.repository.availableLines.map((l) {
                            return DropdownMenuItem(value: l, child: Text("Line $l", style: const TextStyle(fontWeight: FontWeight.bold)));
                          }).toList(),
                          onChanged: (v) {
                            if (v == null) return;
                            setState(() {
                              _selectedLine = v;
                              _fetchBondDetails();
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    // Collection Date Picker
                    Text(
                      isTamil ? "வசூல் தேதி:" : "Date:",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: _pickDate,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.blue.shade400),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today, size: 14, color: AppColors.primary),
                            const SizedBox(width: 6),
                            Text(
                              AppDateUtils.formatSlash(_collectionDate),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Main Entry Section (Scrollable Top Part)
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Fast Collection Entry Card
                      StaggeredEntrance(
                        index: 0,
                        child: HoverScaleCard(
                          elevation: 2,
                          hoverElevation: 4,
                          hoverScale: 1.008,
                          borderRadius: BorderRadius.circular(12),
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Bond Number input
                              TextFormField(
                                controller: _bondNoController,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(6),
                                ],
                                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                                decoration: InputDecoration(
                                  labelText: isTamil ? "தவணை எண் (Bond No)" : "Bond No",
                                  prefixText: "$_selectedLine-",
                                  hintText: '001',
                                  prefixStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary),
                                  suffixIcon: IconButton(
                                    icon: const Icon(Icons.search, size: 20),
                                    onPressed: _fetchBondDetails,
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey.shade50,
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                                ),
                                onChanged: (_) => _fetchBondDetails(),
                              ),
                              const SizedBox(height: 10),

                              // Cash and Gpay Amount Inputs
                              Row(
                                children: [
                                  // Cash (₹) input (ரொக்கம்)
                                  Expanded(
                                    child: TextFormField(
                                      controller: _cashAmountController,
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                        LengthLimitingTextInputFormatter(8),
                                      ],
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1B5E20)),
                                      decoration: InputDecoration(
                                        labelText: isTamil ? "ரொக்கம் (Cash ₹)" : "Cash (₹)",
                                        hintText: '500',
                                        prefixText: "₹ ",
                                        prefixStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1B5E20)),
                                        prefixIcon: const Icon(Icons.payments_outlined, size: 18, color: Color(0xFF1B5E20)),
                                        filled: true,
                                        fillColor: _paymentMode == 'Cash' ? Colors.green.shade50.withValues(alpha: 0.5) : Colors.grey.shade50,
                                        isDense: true,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: BorderSide(
                                            color: _cashAmount > 0 ? const Color(0xFF2E7D32) : Colors.grey.shade300,
                                            width: _cashAmount > 0 ? 1.5 : 1.0,
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: BorderSide(
                                            color: _cashAmount > 0 ? const Color(0xFF2E7D32) : Colors.grey.shade300,
                                            width: _cashAmount > 0 ? 1.5 : 1.0,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Gpay (₹) input (Online UPI)
                                  Expanded(
                                    child: TextFormField(
                                      controller: _gpayAmountController,
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                        LengthLimitingTextInputFormatter(8),
                                      ],
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0D47A1)),
                                      decoration: InputDecoration(
                                        labelText: "Gpay (UPI ₹)",
                                        hintText: '0',
                                        prefixText: "₹ ",
                                        prefixStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0D47A1)),
                                        prefixIcon: const Icon(Icons.phone_android, size: 18, color: Color(0xFF0D47A1)),
                                        filled: true,
                                        fillColor: _paymentMode == 'Online' ? Colors.blue.shade50.withValues(alpha: 0.5) : Colors.grey.shade50,
                                        isDense: true,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: BorderSide(
                                            color: _gpayAmount > 0 ? const Color(0xFF1565C0) : Colors.grey.shade300,
                                            width: _gpayAmount > 0 ? 1.5 : 1.0,
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: BorderSide(
                                            color: _gpayAmount > 0 ? const Color(0xFF1565C0) : Colors.grey.shade300,
                                            width: _gpayAmount > 0 ? 1.5 : 1.0,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),

                              // Dynamic Total Amount Field - Shown when amount given in Cash or Gpay
                              if (_totalCollectedAmount > 0) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [Colors.green.shade50, Colors.teal.shade50],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFF2E7D32), width: 1.5),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.green.shade100.withValues(alpha: 0.4),
                                        blurRadius: 4,
                                        offset: const Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.calculate, color: Color(0xFF1B5E20), size: 20),
                                          const SizedBox(width: 6),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                isTamil ? "மொத்த வசூல் தொகை:" : "Total Collection Amount:",
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12.5,
                                                  color: Color(0xFF1B5E20),
                                                ),
                                              ),
                                              if (_cashAmount > 0 && _gpayAmount > 0)
                                                Text(
                                                  "${isTamil ? 'ரொக்கம்' : 'Cash'}: ₹${_cashAmount.toStringAsFixed(0)} + Gpay: ₹${_gpayAmount.toStringAsFixed(0)}",
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.green.shade900,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      Text(
                                        CurrencyUtils.format(_totalCollectedAmount),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 18,
                                          color: Color(0xFF1B5E20),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 10),
                              ],

                              // Purpose / Notes input (காரணம் / குறிப்பு)
                              TextFormField(
                                controller: _notesController,
                                style: const TextStyle(fontSize: 14),
                                decoration: InputDecoration(
                                  labelText: isTamil ? "காரணம் / குறிப்பு (Purpose / Notes)" : "Purpose / Notes",
                                  hintText: isTamil ? "எ.கா: தவணை, வட்டி, கூடுதல் தொகை..." : "e.g. Installment, Interest, Reason...",
                                  prefixIcon: const Icon(Icons.note_alt_outlined, size: 20, color: AppColors.primary),
                                  filled: true,
                                  fillColor: Colors.grey.shade50,
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Borrower Live Card with AnimatedSwitcher
                              AnimatedSwitcher(
                                duration: AppAnimations.medium,
                                switchInCurve: AppAnimations.entranceCurve,
                                switchOutCurve: Curves.easeOut,
                                child: _currentLoan != null
                                    ? Container(
                                        key: ValueKey(_currentLoan!.id),
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.shade50,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: Colors.blue.shade200),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    "${isTamil ? 'பெயர்' : 'Party'}: ${_currentLoan!.customerName}",
                                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                                  ),
                                                ),
                                                Text(
                                                  _currentLoan!.bondNumber,
                                                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                _buildDetailItem(isTamil ? "கடன் தொகை" : "Loan Amt", CurrencyUtils.format(_currentLoan!.loanAmount)),
                                                _buildDetailItem(isTamil ? "ஆரம்ப தேதி" : "Start Date", AppDateUtils.format(_currentLoan!.startDate)),
                                                _buildDetailItem(
                                                  isTamil ? "பாக்கி" : "Balance",
                                                  CurrencyUtils.format(_currentLoan!.balanceAmount),
                                                  highlight: true,
                                                ),
                                              ],
                                            ),
                                            if (_todayExistingCollection != null) ...[
                                              const SizedBox(height: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                decoration: BoxDecoration(
                                                  color: Colors.amber.shade100,
                                                  borderRadius: BorderRadius.circular(6),
                                                  border: Border.all(color: Colors.amber.shade500),
                                                ),
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.history, size: 16, color: Colors.amber.shade900),
                                                    const SizedBox(width: 6),
                                                    Expanded(
                                                      child: Text(
                                                        isTamil
                                                            ? "இன்று ஏற்கனவே வசூலிக்கப்பட்டது: ${CurrencyUtils.format(_todayExistingCollection!.amount)} (புதிய தொகை இதில் சேர்க்கப்படும்)"
                                                            : "Already paid today: ${CurrencyUtils.format(_todayExistingCollection!.amount)} (New amount will be added)",
                                                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                            const SizedBox(height: 8),
                                            const Divider(height: 1),
                                            const SizedBox(height: 6),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Expanded(
                                                  child: Row(
                                                    children: [
                                                      Icon(
                                                        _currentLoan!.isTargetCustomer ? Icons.stars : Icons.star_border,
                                                        color: _currentLoan!.isTargetCustomer ? Colors.amber.shade800 : Colors.grey,
                                                        size: 18,
                                                      ),
                                                      const SizedBox(width: 5),
                                                      Flexible(
                                                        child: Text(
                                                          isTamil ? "இலக்கு (Target):" : "Target Customer:",
                                                          overflow: TextOverflow.ellipsis,
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            fontWeight: FontWeight.w600,
                                                            color: _currentLoan!.isTargetCustomer ? Colors.purple.shade900 : Colors.grey.shade700,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    if (_currentLoan!.isTargetCustomer)
                                                      Container(
                                                        margin: const EdgeInsets.only(right: 4),
                                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                                        decoration: BoxDecoration(
                                                          color: Colors.purple.shade100,
                                                          borderRadius: BorderRadius.circular(4),
                                                        ),
                                                        child: Text(
                                                          isTamil ? "இலக்கு" : "TARGET",
                                                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.purple.shade900),
                                                        ),
                                                      ),
                                                    Transform.scale(
                                                      scale: 0.8,
                                                      child: Switch(
                                                        value: _currentLoan!.isTargetCustomer,
                                                        activeThumbColor: Colors.purple.shade700,
                                                        onChanged: (val) => _toggleTargetCustomer(val),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      )
                                    : Container(
                                        key: const ValueKey('no_loan_prompt'),
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade100,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Center(
                                          child: Text(
                                            isTamil ? "தவணை எண்ணை உள்ளிட்டதும் வாடிக்கையாளர் விவரம் தோன்றும்" : "Enter Bond No to view borrower particulars",
                                            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                          ),
                                        ),
                                      ),
                              ),
                              const SizedBox(height: 12),

                              // Payment Mode Selector (Cash vs Online Transaction)
                              Text(
                                isTamil ? "கட்டண முறை:" : "Payment Mode:",
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Expanded(
                                    child: AnimatedPressable(
                                      onTap: () => _setPaymentMode('Cash'),
                                      child: AnimatedContainer(
                                        duration: AppAnimations.fast,
                                        curve: Curves.easeInOut,
                                        padding: const EdgeInsets.symmetric(vertical: 9),
                                        decoration: BoxDecoration(
                                          color: _paymentMode == 'Cash' ? const Color(0xFF2E7D32) : Colors.grey.shade100,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: _paymentMode == 'Cash' ? const Color(0xFF1B5E20) : Colors.grey.shade300,
                                            width: _paymentMode == 'Cash' ? 1.5 : 1,
                                          ),
                                        ),
                                        alignment: Alignment.center,
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(Icons.payments, size: 16, color: _paymentMode == 'Cash' ? Colors.white : Colors.black87),
                                              const SizedBox(width: 4),
                                              Text(
                                                isTamil ? "ரொக்கம்" : "Cash",
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: _paymentMode == 'Cash' ? Colors.white : Colors.black87,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: AnimatedPressable(
                                      onTap: () => _setPaymentMode('Online'),
                                      child: AnimatedContainer(
                                        duration: AppAnimations.fast,
                                        curve: Curves.easeInOut,
                                        padding: const EdgeInsets.symmetric(vertical: 9),
                                        decoration: BoxDecoration(
                                          color: _paymentMode == 'Online' ? const Color(0xFF1565C0) : Colors.grey.shade100,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: _paymentMode == 'Online' ? const Color(0xFF0D47A1) : Colors.grey.shade300,
                                            width: _paymentMode == 'Online' ? 1.5 : 1,
                                          ),
                                        ),
                                        alignment: Alignment.center,
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(Icons.phone_android, size: 16, color: _paymentMode == 'Online' ? Colors.white : Colors.black87),
                                              const SizedBox(width: 4),
                                              Text(
                                                "Gpay",
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: _paymentMode == 'Online' ? Colors.white : Colors.black87,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (_paymentMode == 'Online') ...[
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.info_outline, size: 14, color: Color(0xFF1565C0)),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          isTamil
                                              ? "ஆன்லைன் பரிவர்த்தனை தேர்ந்தெடுக்கப்பட்டுள்ளது - தானாகவே இலக்கு வாடிக்கையாளராக மாறும்!"
                                              : "Online selected: Customer will be tagged as Target Customer automatically!",
                                          style: const TextStyle(fontSize: 10.5, color: Color(0xFF0D47A1), fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              const SizedBox(height: 14),

                              // Quick Action Buttons matching legacy workflow
                              Row(
                                children: [
                                  // Save button
                                  Expanded(
                                    child: AnimatedPressable(
                                      onTap: () => _saveCollection(advanceNext: false),
                                      child: ElevatedButton.icon(
                                        onPressed: () => _saveCollection(advanceNext: false),
                                        icon: const Icon(Icons.check, size: 18),
                                        label: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(isTamil ? "சேமி" : "Save"),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.primary,
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Save & Next button (the ultimate speed feature for collectors!)
                                  Expanded(
                                    child: AnimatedPressable(
                                      onTap: () => _saveCollection(advanceNext: true),
                                      child: ElevatedButton.icon(
                                        onPressed: () => _saveCollection(advanceNext: true),
                                        icon: const Icon(Icons.arrow_forward, size: 18),
                                        label: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(isTamil ? "அடுத்தது" : "Save & Next"),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.amber.shade800,
                                          padding: const EdgeInsets.symmetric(vertical: 12),
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
                      const SizedBox(height: 12),

                      // Today's Comprehensive Accounting & Amount Received Card (Total, Cash, Gpay)
                      StaggeredEntrance(
                        index: 1,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F8E9),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.green.shade600, width: 1.5),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Wrap(
                                alignment: WrapAlignment.spaceBetween,
                                runAlignment: WrapAlignment.center,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 10,
                                runSpacing: 8,
                                children: [
                                  // Total Parties
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.people_outline, size: 16, color: AppColors.primaryDark),
                                      const SizedBox(width: 4),
                                      Text(
                                        "${isTamil ? 'நபர்கள்' : 'Parties'}: ",
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                      ),
                                      Text(
                                        "${dailySheet.length}",
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryDark),
                                      ),
                                    ],
                                  ),
                                  // Cash Total
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.payments_outlined, size: 15, color: Color(0xFF1B5E20)),
                                      const SizedBox(width: 4),
                                      Text(
                                        "${isTamil ? 'ரொக்கம்' : 'Cash'}: ",
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF1B5E20)),
                                      ),
                                      AnimatedCountingNumber(
                                        value: dailySheet.where((c) => c.isCash).fold<double>(0, (sum, c) => sum + c.amount),
                                        isCurrency: true,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF1B5E20)),
                                      ),
                                    ],
                                  ),
                                  // Gpay Total
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.phone_android, size: 15, color: Color(0xFF0D47A1)),
                                      const SizedBox(width: 4),
                                      const Text(
                                        "Gpay: ",
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0D47A1)),
                                      ),
                                      AnimatedCountingNumber(
                                        value: dailySheet.where((c) => c.isOnline).fold<double>(0, (sum, c) => sum + c.amount),
                                        isCurrency: true,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF0D47A1)),
                                      ),
                                    ],
                                  ),
                                  // Grand Total
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        "${isTamil ? 'மொத்த வசூல்' : 'Total Coll'}: ",
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFFB71C1C)),
                                      ),
                                      AnimatedCountingNumber(
                                        value: dayCollection,
                                        isCurrency: true,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFFB71C1C)),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Today's Collection Sheet Title
                      Row(
                        children: [
                          const Icon(Icons.receipt_long, size: 18, color: AppColors.primary),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              isTamil ? "இன்றைய பட்டியல் (Sheet)" : "Today's Sheet",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: AppColors.primaryDark,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      SizedBox(
                        height: 280,
                        child: dailySheet.isEmpty
                            ? AnimatedEmptyState(
                                icon: Icons.receipt_long_outlined,
                                title: isTamil ? "இன்று வசூல் பதிவுகள் இல்லை" : "No collections recorded today",
                                subtitle: isTamil ? "மேலே உள்ள படிவத்தை பயன்படுத்தி வசூலை பதிவு செய்யவும்." : "Enter a bond number and amount above to record collection.",
                              )
                            : ListView.separated(
                                itemCount: dailySheet.length,
                                separatorBuilder: (_, index) => const Divider(height: 1),
                                itemBuilder: (context, i) {
                                  final col = dailySheet[i];
                                  final isOnline = col.isOnline;
                                  return StaggeredEntrance(
                                    index: i < 8 ? i : 0,
                                    delay: const Duration(milliseconds: 20),
                                    child: ListTile(
                                      dense: true,
                                      leading: CircleAvatar(
                                        radius: 17,
                                        backgroundColor: AppColors.goldLight,
                                        child: Text(
                                          col.bondNumber.replaceFirst("$_selectedLine-", ""),
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.primaryDark),
                                        ),
                                      ),
                                      title: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              col.customerName,
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                            decoration: BoxDecoration(
                                              color: isOnline ? Colors.blue.shade50 : Colors.green.shade50,
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(color: isOnline ? Colors.blue.shade200 : Colors.green.shade200),
                                            ),
                                            child: Text(
                                              isOnline ? "Gpay" : (isTamil ? "ரொக்கம்" : "Cash"),
                                              style: TextStyle(
                                                fontSize: 9.5,
                                                fontWeight: FontWeight.bold,
                                                color: isOnline ? const Color(0xFF0D47A1) : const Color(0xFF1B5E20),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      subtitle: Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Icon(Icons.calendar_today, size: 11, color: Colors.grey.shade600),
                                                const SizedBox(width: 3),
                                                Text(
                                                  AppDateUtils.formatSlash(col.collectionDate),
                                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                                                ),
                                                if (col.currentBalance > 0) ...[
                                                  const SizedBox(width: 6),
                                                  Flexible(
                                                    child: Text(
                                                      "• ${isTamil ? 'மீதி' : 'Bal'}: ${CurrencyUtils.format(col.currentBalance)}",
                                                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                            if (col.notes != null && col.notes!.trim().isNotEmpty) ...[
                                              const SizedBox(height: 2),
                                              Row(
                                                children: [
                                                  Icon(Icons.edit_note, size: 13, color: Colors.blue.shade700),
                                                  const SizedBox(width: 3),
                                                  Expanded(
                                                    child: Text(
                                                      col.notes!.trim(),
                                                      style: TextStyle(fontSize: 11, color: Colors.blue.shade900, fontStyle: FontStyle.italic),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      trailing: Text(
                                        CurrencyUtils.format(col.amount),
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.success),
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailItem(String label, String value, {bool highlight = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: highlight ? AppColors.error : AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

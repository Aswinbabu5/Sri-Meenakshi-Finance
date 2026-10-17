import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_animations.dart';
import '../../../../core/services/loan_repository.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/web_camera_helper.dart';
import '../../../../core/utils/safe_image_provider.dart';
import '../../../../core/models/loan_model.dart';
import '../../../../core/models/customer_model.dart';
import '../../dashboard/presentation/widgets/company_header.dart';
import '../../dashboard/presentation/widgets/line_and_year_dialogs.dart';
import '../../../../core/services/app_finance_folder_service.dart';
import 'loan_passbook_page.dart';

class LoanFormPage extends StatefulWidget {
  final LoanRepository repository;

  const LoanFormPage({super.key, required this.repository});

  @override
  State<LoanFormPage> createState() => _LoanFormPageState();
}

enum LoanEntryMode {
  newLoan,
  repeatLoan,
  editLoan,
}

class _LoanFormPageState extends State<LoanFormPage> {
  final _formKey = GlobalKey<FormState>();

  // Unified Bond Number Lookup & Mode State
  LoanEntryMode _entryMode = LoanEntryMode.newLoan;
  String? _bondLookupStatus; // 'found', 'not_found', 'repeat_new_bond', or null
  String? _lastSearchedBond;
  LoanModel? _retrievedLoan;
  LoanModel? _sourceMemberLoan;
  CustomerModel? _selectedExistingCustomer;

  late String _selectedLine;
  late TextEditingController _bondNoController;
  late TextEditingController _existingMemberBondController;
  late TextEditingController _tenureDaysController;
  late TextEditingController _loanAmountController;
  late TextEditingController _interestAmountController;
  late TextEditingController _chitFeeController;
  late TextEditingController _partyNameController;
  late TextEditingController _fatherNameController;
  late TextEditingController _addressController;
  late TextEditingController _cityController;
  late TextEditingController _phoneController;
  late TextEditingController _detailsController;

  // Proof Section (Customer Face Photo, Reference Proof Type, Front & Back Photos)
  String? _photoPath;
  String _selectedProofType = 'ஆதார் அட்டை (Aadhaar Card)';
  final Map<String, String?> _proofFrontPaths = {};
  final Map<String, String?> _proofBackPaths = {};
  bool _isSaving = false;

  final ImagePicker _picker = ImagePicker();

  DateTime _startDate = DateTime.now();
  late DateTime _endDate;

  double get _loanAmount => double.tryParse(_loanAmountController.text) ?? 0;
  double get _interestAmount => double.tryParse(_interestAmountController.text) ?? 0;
  int get _tenureDays => int.tryParse(_tenureDaysController.text) ?? 100;
  double get _totalOutstanding => _loanAmount;
  double get _dailyDue => _tenureDays > 0 ? (_totalOutstanding / _tenureDays).roundToDouble() : 0;

  @override
  void initState() {
    super.initState();
    _selectedLine = widget.repository.selectedLine;
    final nextNum = widget.repository.getNextBondNumber(_selectedLine);

    _bondNoController = TextEditingController(text: nextNum);
    _existingMemberBondController = TextEditingController();
    _tenureDaysController = TextEditingController(text: '100');
    _loanAmountController = TextEditingController(text: '10000');
    _interestAmountController = TextEditingController(text: '1000');
    _chitFeeController = TextEditingController(text: '100');
    _partyNameController = TextEditingController();
    _fatherNameController = TextEditingController();
    _addressController = TextEditingController();
    _cityController = TextEditingController(text: 'மதுரை');
    _phoneController = TextEditingController();
    _detailsController = TextEditingController();

    _endDate = _startDate.add(Duration(days: _tenureDays));
  }

  @override
  void dispose() {
    _bondNoController.dispose();
    _existingMemberBondController.dispose();
    _tenureDaysController.dispose();
    _loanAmountController.dispose();
    _interestAmountController.dispose();
    _chitFeeController.dispose();
    _partyNameController.dispose();
    _fatherNameController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _phoneController.dispose();
    _detailsController.dispose();
    super.dispose();
  }

  void _onLineChanged(String? newLine) {
    if (newLine == null) return;
    setState(() {
      _selectedLine = newLine;
      _bondNoController.text = widget.repository.getNextBondNumber(newLine);
      if (_entryMode != LoanEntryMode.repeatLoan) {
        _bondLookupStatus = null;
        _lastSearchedBond = null;
        _retrievedLoan = null;
      }
    });
  }

  void _onBondNumberChanged(String val) {
    final trimmed = val.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _bondLookupStatus = null;
        _lastSearchedBond = null;
        _retrievedLoan = null;
      });
      return;
    }

    _lastSearchedBond = trimmed;

    // Check if user entered bond with line prefix (e.g. A001, B042)
    String lineToUse = _selectedLine;
    String searchNumber = trimmed;
    final upper = trimmed.toUpperCase().replaceAll('-', '').replaceAll(' ', '');
    if (upper.isNotEmpty && RegExp(r'^[A-D]').hasMatch(upper)) {
      lineToUse = upper[0];
      searchNumber = upper.substring(1);
    }

    final fullBond = widget.repository.formatBondNumber(lineToUse, searchNumber);
    final loan = widget.repository.getLoanByBond(fullBond, lineToUse) ??
        widget.repository.getLoanByBond(trimmed, lineToUse);

    if (loan != null) {
      setState(() {
        _bondLookupStatus = 'found';
        _retrievedLoan = loan;
        _selectedLine = loan.lineCode;
        _populateLoanData(loan);
      });
    } else {
      setState(() {
        // If member details were already fetched and user is changing the bond number to a new ID (e.g. A002),
        // PRESERVE the photos, proofs, and customer details for repeat loan creation!
        if ((_retrievedLoan != null || _sourceMemberLoan != null) && _selectedExistingCustomer != null) {
          if (_retrievedLoan != null) {
            _sourceMemberLoan = _retrievedLoan;
            _existingMemberBondController.text = _retrievedLoan!.bondNumber;
          }
          _entryMode = LoanEntryMode.repeatLoan;
          _bondLookupStatus = 'repeat_new_bond';
          _retrievedLoan = null;
        } else if (_entryMode != LoanEntryMode.repeatLoan) {
          if (_retrievedLoan != null) {
            _photoPath = null;
            _proofFrontPaths.clear();
            _proofBackPaths.clear();
          }
          _bondLookupStatus = 'not_found';
          _retrievedLoan = null;
        }
      });
    }
  }

  void _setupRepeatLoanForCurrentMember(LoanModel loan) {
    setState(() {
      _entryMode = LoanEntryMode.repeatLoan;
      _sourceMemberLoan = loan;
      _existingMemberBondController.text = loan.bondNumber;
      _selectedLine = loan.lineCode;
      _bondNoController.text = widget.repository.getNextBondNumber(_selectedLine);
      _bondLookupStatus = 'repeat_new_bond';
      _retrievedLoan = null;

      // Keep member profile, photos, and proofs
      _partyNameController.text = loan.customerName;
      _fatherNameController.text = loan.fatherOrSpouseName ?? '';
      _phoneController.text = loan.phoneNumber;
      _addressController.text = loan.address ?? '';
      _cityController.text = (loan.city != null && loan.city!.isNotEmpty) ? loan.city! : 'மதுரை';
      _photoPath = loan.photoPath;
      if (loan.proofType != null && loan.proofType!.isNotEmpty) {
        _selectedProofType = loan.proofType!;
      }
      if (loan.proofFrontPath != null) {
        _proofFrontPaths[_selectedProofType] = loan.proofFrontPath;
      }
      if (loan.proofBackPath != null) {
        _proofBackPaths[_selectedProofType] = loan.proofBackPath;
      }

      final cust = widget.repository.getCustomerByIdOrCode(loan.customerId.toString());
      if (cust != null) {
        _selectedExistingCustomer = cust;
      }
      _detailsController.text = cust?.notes ?? '';

      // Reset loan amounts to fresh defaults so user can enter the new borrowed amount
      _loanAmountController.text = '10000';
      _interestAmountController.text = '1000';
      _tenureDaysController.text = '100';
      _chitFeeController.text = '100';
      _startDate = DateTime.now();
      _endDate = _startDate.add(Duration(days: _tenureDays));
    });
  }

  void _searchExistingMemberForRepeat(String val) {
    final trimmed = val.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _sourceMemberLoan = null;
      });
      return;
    }

    String lineToUse = _selectedLine;
    String searchNumber = trimmed;
    final upper = trimmed.toUpperCase().replaceAll('-', '').replaceAll(' ', '');
    if (upper.isNotEmpty && RegExp(r'^[A-D]').hasMatch(upper)) {
      lineToUse = upper[0];
      searchNumber = upper.substring(1);
    }

    final fullBond = widget.repository.formatBondNumber(lineToUse, searchNumber);
    final loan = widget.repository.getLoanByBond(fullBond, lineToUse) ??
        widget.repository.getLoanByBond(trimmed, lineToUse);

    if (loan != null) {
      _setupRepeatLoanForCurrentMember(loan);
    } else {
      setState(() {
        _sourceMemberLoan = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.repository.isTamil
                ? "தவணை எண் '$trimmed' காணப்படவில்லை!"
                : "Bond number '$trimmed' not found!",
          ),
          backgroundColor: Colors.amber.shade900,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _switchEntryMode(LoanEntryMode mode) {
    setState(() {
      _entryMode = mode;
      if (mode == LoanEntryMode.newLoan) {
        _bondLookupStatus = null;
        _lastSearchedBond = null;
        _retrievedLoan = null;
        _sourceMemberLoan = null;
        _selectedExistingCustomer = null;
        _existingMemberBondController.clear();
        _bondNoController.text = widget.repository.getNextBondNumber(_selectedLine);
        _partyNameController.clear();
        _fatherNameController.clear();
        _phoneController.clear();
        _addressController.clear();
        _cityController.text = 'மதுரை';
        _detailsController.clear();
        _photoPath = null;
        _proofFrontPaths.clear();
        _proofBackPaths.clear();
        _loanAmountController.text = '10000';
        _interestAmountController.text = '1000';
        _tenureDaysController.text = '100';
        _chitFeeController.text = '100';
      } else if (mode == LoanEntryMode.repeatLoan) {
        if (_retrievedLoan != null) {
          _setupRepeatLoanForCurrentMember(_retrievedLoan!);
        } else {
          _bondNoController.text = widget.repository.getNextBondNumber(_selectedLine);
          _loanAmountController.text = '10000';
          _interestAmountController.text = '1000';
          _tenureDaysController.text = '100';
          _chitFeeController.text = '100';
        }
      } else if (mode == LoanEntryMode.editLoan) {
        _bondLookupStatus = null;
      }
    });
  }

  void _populateLoanData(LoanModel loan) {
    _partyNameController.text = loan.customerName;
    _fatherNameController.text = loan.fatherOrSpouseName ?? '';
    _phoneController.text = loan.phoneNumber;
    _addressController.text = loan.address ?? '';
    _cityController.text = (loan.city != null && loan.city!.isNotEmpty) ? loan.city! : 'மதுரை';
    _loanAmountController.text = loan.loanAmount.toStringAsFixed(0);
    _interestAmountController.text = loan.interestAmount.toStringAsFixed(0);
    _tenureDaysController.text = loan.tenureDays.toString();
    _chitFeeController.text = loan.chitFee.toStringAsFixed(0);
    _startDate = loan.startDate;
    _endDate = loan.endDate;
    _photoPath = loan.photoPath;
    if (loan.proofType != null && loan.proofType!.isNotEmpty) {
      _selectedProofType = loan.proofType!;
    }
    if (loan.proofFrontPath != null) {
      _proofFrontPaths[_selectedProofType] = loan.proofFrontPath;
    }
    if (loan.proofBackPath != null) {
      _proofBackPaths[_selectedProofType] = loan.proofBackPath;
    }

    final cust = widget.repository.getCustomerByIdOrCode(loan.customerId.toString());
    if (cust != null) {
      _selectedExistingCustomer = cust;
    }
    _detailsController.text = cust?.notes ?? '';
  }

  void _clearBondLookup() {
    setState(() {
      _entryMode = LoanEntryMode.newLoan;
      _bondLookupStatus = null;
      _lastSearchedBond = null;
      _retrievedLoan = null;
      _sourceMemberLoan = null;
      _selectedExistingCustomer = null;
      _existingMemberBondController.clear();
      _partyNameController.clear();
      _fatherNameController.clear();
      _phoneController.clear();
      _addressController.clear();
      _cityController.text = 'மதுரை';
      _detailsController.clear();
      _photoPath = null;
      _proofFrontPaths.clear();
      _proofBackPaths.clear();
      _selectedProofType = 'ஆதார் அட்டை (Aadhaar Card)';
      _bondNoController.text = widget.repository.getNextBondNumber(_selectedLine);
      _loanAmountController.text = '10000';
      _interestAmountController.text = '1000';
      _tenureDaysController.text = '100';
      _chitFeeController.text = '100';
      _startDate = DateTime.now();
      _endDate = _startDate.add(Duration(days: _tenureDays));
    });
  }

  void _updateCalculations() {
    setState(() {
      _endDate = _startDate.add(Duration(days: _tenureDays));
    });
  }

  void _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
        _endDate = picked.add(Duration(days: _tenureDays));
      });
    }
  }

  bool _isValidPhoto(String? path) => isValidPhotoPath(path);

  Widget _buildPhotoWidget(String path, {BoxFit fit = BoxFit.cover, double? width, double? height}) {
    return getSafeImageWidget(path, fit: fit, width: width, height: height);
  }

  Future<void> _pickImageForTarget(ImageSource source, String target) async {
    try {
      String? imagePath;

      if (kIsWeb && source == ImageSource.camera) {
        // Direct laptop screen camera capture with live preview dialog!
        imagePath = await captureLaptopWebcamPhoto(isTamil: widget.repository.isTamil);
        if (imagePath == null) return;
      } else {
        final picked = await _picker.pickImage(
          source: source,
          maxWidth: 1200,
          maxHeight: 1200,
          imageQuality: 85,
        );
        if (picked != null) {
          final bytes = await picked.readAsBytes();
          imagePath = 'data:image/jpeg;base64,${base64Encode(bytes)}';
        }
      }

      if (imagePath != null) {
        setState(() {
          if (target == 'customer') _photoPath = imagePath;
          if (target == 'proofFront') _proofFrontPaths[_selectedProofType] = imagePath;
          if (target == 'proofBack') _proofBackPaths[_selectedProofType] = imagePath;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Camera error: $e')),
        );
      }
    }
  }

  void _showImageOptions(String target, String title) {
    final isTamil = widget.repository.isTamil;
    final currentFront = _proofFrontPaths[_selectedProofType];
    final currentBack = _proofBackPaths[_selectedProofType];
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: AppColors.primary),
              title: Text(isTamil ? 'கேமரா மூலம் படம் எடுக்க (Camera)' : 'Take Photo (Camera)'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImageForTarget(ImageSource.camera, target);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.teal),
              title: Text(isTamil ? 'கேலரியில் இருந்து தேர்வு செய்ய (Gallery)' : 'Choose from Gallery'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImageForTarget(ImageSource.gallery, target);
              },
            ),
            if ((target == 'customer' && _photoPath != null) ||
                (target == 'proofFront' && currentFront != null) ||
                (target == 'proofBack' && currentBack != null))
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: Text(isTamil ? 'நீக்கு (Remove Photo)' : 'Remove Photo'),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    if (target == 'customer') _photoPath = null;
                    if (target == 'proofFront') _proofFrontPaths[_selectedProofType] = null;
                    if (target == 'proofBack') _proofBackPaths[_selectedProofType] = null;
                  });
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveLoan() async {
    final isTamil = widget.repository.isTamil;
    if (!widget.repository.isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isTamil
                ? 'அனுமதி இல்லை: நிர்வாகி மட்டுமே புதிய கடன் பதிவு செய்ய முடியும்.'
                : 'Access Denied: Only Admin can create new loans.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    // Validate Member Face Photo
    if (!_isValidPhoto(_photoPath)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isTamil
                ? 'உறுப்பினர் புகைப்படம் தேவை: தயவுசெய்து புகைப்படம் எடுக்கவும் / பதிவேற்றவும்'
                : 'Member photo required: Please take or upload member photo',
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Validate Document Proof Photo (Front Side)
    final selectedFrontProof = _proofFrontPaths[_selectedProofType];
    if (!_isValidPhoto(selectedFrontProof)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isTamil
                ? '$_selectedProofType ஆவண சான்று படம் தேவை: தயவுசெய்து முன் பக்க படத்தை பதிவேற்றவும்'
                : 'Document proof required: Please upload front side photo of $_selectedProofType',
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final selectedBackProof = _proofBackPaths[_selectedProofType];

    setState(() => _isSaving = true);

    try {
      final formattedBond = widget.repository.formatBondNumber(_selectedLine, _bondNoController.text.trim());

      // If New Loan or Repeat Loan: Ensure the new bond number is NOT already taken!
      if (_entryMode == LoanEntryMode.newLoan || _entryMode == LoanEntryMode.repeatLoan) {
        final existingWithNewBond = widget.repository.getLoanByBond(formattedBond, _selectedLine);
        if (existingWithNewBond != null) {
          setState(() => _isSaving = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isTamil
                    ? 'தவணை எண் $formattedBond ஏற்கனவே பயன்பாட்டில் உள்ளது! தயவுசெய்து வேறு எண் உள்ளிடவும்.'
                    : 'Bond number $formattedBond already exists! Please choose another number.',
              ),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }

      LoanModel newLoan;
      if (_entryMode == LoanEntryMode.editLoan && _retrievedLoan != null && _retrievedLoan!.bondNumber == formattedBond) {
        await widget.repository.updateMember(
          loanId: _retrievedLoan!.id,
          customerName: _partyNameController.text.trim(),
          fatherOrSpouseName: _fatherNameController.text.trim().isEmpty ? null : _fatherNameController.text.trim(),
          phoneNumber: _phoneController.text.trim(),
          address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
          city: _cityController.text.trim(),
          photoPath: _photoPath,
          proofType: _selectedProofType,
          proofFrontPath: selectedFrontProof,
          proofBackPath: selectedBackProof,
          notes: _detailsController.text.trim().isEmpty ? null : _detailsController.text.trim(),
          lineCode: _selectedLine,
          bondNumber: formattedBond,
          loanAmount: _loanAmount,
          interestAmount: _interestAmount,
          chitFee: double.tryParse(_chitFeeController.text) ?? 100,
          tenureDays: _tenureDays,
          startDate: _startDate,
          endDate: _endDate,
        );
        newLoan = widget.repository.getLoanByBond(formattedBond, _selectedLine) ?? _retrievedLoan!;
      } else {
        // Creating NEW loan (Repeat Loan for existing member OR Brand New Customer):
        // Old loan is never updated or deleted!
        final customerIdToUse = _selectedExistingCustomer?.id ?? _sourceMemberLoan?.customerId;
        newLoan = await widget.repository.createLoan(
          lineCode: _selectedLine,
          bondNumber: formattedBond,
          customerId: customerIdToUse,
          customerName: _partyNameController.text.trim(),
          fatherOrSpouseName: _fatherNameController.text.trim().isEmpty ? null : _fatherNameController.text.trim(),
          phoneNumber: _phoneController.text.trim(),
          address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
          city: _cityController.text.trim(),
          photoPath: _photoPath,
          proofType: _selectedProofType,
          proofFrontPath: selectedFrontProof,
          proofBackPath: selectedBackProof,
          details: _detailsController.text.trim().isEmpty ? null : _detailsController.text.trim(),
          tenureDays: _tenureDays,
          loanAmount: _loanAmount,
          interestAmount: _interestAmount,
          chitFee: double.tryParse(_chitFeeController.text) ?? 100,
          startDate: _startDate,
        );
      }

      // Automatically store photos, proofs, and member details PDF directly into app-finance folders!
      MemberFilesSaveResult? folderResult;
      try {
        final ledger = widget.repository.getLedger(newLoan.bondNumber, loanId: newLoan.id);
        folderResult = await AppFinanceFolderService.saveMemberFiles(
          loan: newLoan,
          collections: ledger,
          isTamil: isTamil,
        );
      } catch (err) {
        debugPrint('Auto folder save error: $err');
      }

      if (mounted) {
        setState(() => _isSaving = false);
        _showLoanSuccessDialog(newLoan, folderResult);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isTamil ? 'பிழை: $e' : 'Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _resetFormForNextLoan() {
    setState(() {
      _entryMode = LoanEntryMode.newLoan;
      _selectedExistingCustomer = null;
      _bondLookupStatus = null;
      _lastSearchedBond = null;
      _retrievedLoan = null;
      _sourceMemberLoan = null;
      _existingMemberBondController.clear();
      _partyNameController.clear();
      _fatherNameController.clear();
      _phoneController.clear();
      _addressController.clear();
      _detailsController.clear();
      _photoPath = null;
      _proofFrontPaths.clear();
      _proofBackPaths.clear();
      _selectedProofType = 'ஆதார் அட்டை (Aadhaar Card)';
      _bondNoController.text = widget.repository.getNextBondNumber(_selectedLine);
      _loanAmountController.text = '10000';
      _interestAmountController.text = '1000';
      _tenureDaysController.text = '100';
      _chitFeeController.text = '100';
      _startDate = DateTime.now();
      _endDate = _startDate.add(Duration(days: _tenureDays));
    });
  }

  void _previewCurrentPassbook() {
    final formattedBond = widget.repository.formatBondNumber(_selectedLine, _bondNoController.text.trim());
    final loan = LoanModel(
      id: 9999,
      bondNumber: formattedBond,
      lineCode: _selectedLine,
      customerId: _selectedExistingCustomer?.id ?? 0,
      customerName: _partyNameController.text.trim().isEmpty
          ? (widget.repository.isTamil ? 'புதிய வாடிக்கையாளர்' : 'New Customer')
          : _partyNameController.text.trim(),
      fatherOrSpouseName: _fatherNameController.text.trim().isEmpty ? null : _fatherNameController.text.trim(),
      phoneNumber: _phoneController.text.trim().isEmpty ? '98XXXXXXXX' : _phoneController.text.trim(),
      address: _addressController.text.trim().isEmpty ? 'மதுரை' : _addressController.text.trim(),
      city: _cityController.text.trim().isEmpty ? 'மதுரை' : _cityController.text.trim(),
      photoPath: _photoPath,
      proofType: _selectedProofType,
      proofFrontPath: _proofFrontPaths[_selectedProofType],
      proofBackPath: _proofBackPaths[_selectedProofType],
      tenureDays: _tenureDays,
      loanAmount: _loanAmount,
      interestAmount: _interestAmount,
      totalAmount: _totalOutstanding,
      dailyDueAmount: _dailyDue,
      chitFee: double.tryParse(_chitFeeController.text) ?? 100,
      startDate: _startDate,
      endDate: _endDate,
      collectedAmount: 0,
      balanceAmount: _totalOutstanding,
      status: 'active',
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LoanPassbookPage(
          loan: loan,
          repository: widget.repository,
          returnPanelTitle: widget.repository.isTamil ? "புதிய கடன் பதிவு" : "New Loan Entry",
        ),
      ),
    );
  }

  void _showLoanSuccessDialog(LoanModel newLoan, [MemberFilesSaveResult? folderResult]) {
    final isTamil = widget.repository.isTamil;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: Color(0xFF2E7D32), size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isTamil ? "கடன் சேமிக்கப்பட்டது!" : "Loan Created Successfully!",
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Member Summary Card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFE3F2FD),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF90CAF9)),
              ),
              child: Row(
                children: [
                  if (isValidPhotoPath(newLoan.photoPath)) ...[
                    CircleAvatar(
                      radius: 20,
                      backgroundImage: getSafeImageProvider(newLoan.photoPath),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "${isTamil ? 'தவணை எண்' : 'Bond'}: ${newLoan.bondNumber}",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0D47A1)),
                        ),
                        Text(
                          "${isTamil ? 'பெயர்' : 'Party'}: ${newLoan.customerName}",
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: Colors.blue.shade100, borderRadius: BorderRadius.circular(4)),
                    child: Text("Line ${newLoan.lineCode}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ],
              ),
            ),
            if (_sourceMemberLoan != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.green.shade300),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.shield_outlined, size: 16, color: Color(0xFF2E7D32)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        isTamil
                            ? "பழைய கடன் ${_sourceMemberLoan!.bondNumber} பாதுகாப்பாக உள்ளது (நீக்கப்படவில்லை)."
                            : "Previous loan ${_sourceMemberLoan!.bondNumber} remains safe and was not deleted.",
                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF1B5E20), fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),

            // Direct app-finance Storage Confirmation Card
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F8E9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.folder_shared, size: 16, color: Color(0xFF2E7D32)),
                      const SizedBox(width: 6),
                      Text(
                        isTamil ? "app-finance கோப்புறைகளில் நேரடி சேமிப்பு:" : "Stored in app-finance Folders:",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF1B5E20)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isTamil
                        ? "• member-photo/ (புகைப்படம் .jpg)\n• member-proof/ (சான்றுகள் .jpg)\n• member-details/ (விவரங்கள் .pdf)"
                        : "• member-photo/ (Profile Photo .jpg)\n• member-proof/ (ID Proof .jpg)\n• member-details/ (Member Details .pdf)",
                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF33691E), height: 1.4),
                  ),
                  if (folderResult?.rootFolderPath != null) ...[
                    const SizedBox(height: 6),
                    SelectableText(
                      folderResult!.rootFolderPath!,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0D47A1)),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              isTamil
                  ? "வாடிக்கையாளருக்கு பாஸ்புக் பார்க்க மற்றும் பதிவிறக்கம் செய்ய கீழே உள்ள பொத்தானை அழுத்தவும்:"
                  : "View and download the loan passbook card below:",
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
          ],
        ),
        actions: [
          if (!kIsWeb) ...[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => AppFinanceFolderService.openAppFinanceFolder(),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  side: const BorderSide(color: Color(0xFF00796B)),
                  foregroundColor: const Color(0xFF00796B),
                ),
                icon: const Icon(Icons.folder_open, size: 18),
                label: Text(
                  isTamil ? "app-finance கோப்புறையை திறக்க" : "Open app-finance Folder",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 6),
          ],
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(dialogCtx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => LoanPassbookPage(
                      loan: newLoan,
                      repository: widget.repository,
                      returnPanelTitle: isTamil ? "புதிய கடன் பதிவு" : "New Loan Entry",
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D47A1),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              icon: const Icon(Icons.menu_book, color: Colors.white),
              label: Text(
                isTamil ? "பாஸ்புக் பார்க்க & பதிவிறக்க (Passbook)" : "View & Download Passbook",
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pop(dialogCtx);
                    _resetFormForNextLoan();
                  },
                  child: Text(isTamil ? "அடுத்த கடன்" : "Next Loan"),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextButton(
                  onPressed: () {
                    Navigator.pop(dialogCtx);
                    Navigator.pop(context);
                  },
                  child: Text(isTamil ? "முகப்பு (Home)" : "Home"),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = widget.repository;
    final isTamil = repo.isTamil;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallPhone = screenWidth < 360;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F8),
      appBar: AppBar(
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            isTamil ? "புதிய கடன் பதிவு" : "New Loan Entry",
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
        ),
        backgroundColor: const Color(0xFF1565C0),
        elevation: 1,
        actions: [
          IconButton(
            tooltip: isTamil ? "பாஸ்புக் மாதிரி பார்வை" : "Preview Passbook",
            icon: const Icon(Icons.remove_red_eye_outlined),
            onPressed: _previewCurrentPassbook,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            CompanyHeader(repository: repo, compact: true),
            Expanded(
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
                          // Box 1: Bond Number Lookup & Autofill at the top
                          StaggeredEntrance(
                            index: 0,
                            child: _buildTopBondSection(isTamil, isSmallPhone),
                          ),

                          const SizedBox(height: 14),

                          // Box 2: Loan Details
                          StaggeredEntrance(
                            index: 1,
                            child: _buildLoanDetailsSection(isTamil, isSmallPhone),
                          ),

                          const SizedBox(height: 14),

                          // Box 2: Borrower Particulars & Photo (Drawing 3)
                          StaggeredEntrance(
                            index: 2,
                            child: _buildBorrowerDetailsSection(isTamil, isSmallPhone),
                          ),

                          const SizedBox(height: 14),

                          // Box 3: Document Proof (Drawing 3)
                          StaggeredEntrance(
                            index: 3,
                            child: _buildDocumentProofSection(isTamil, isSmallPhone),
                          ),

                          const SizedBox(height: 20),

                          // Bottom Action Buttons: Save Loan & Cancel (Drawing 3)
                          StaggeredEntrance(
                            index: 4,
                            child: _buildBottomActionButtons(isTamil),
                          ),

                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Box 1: Bond Number (3 Modes: New Loan, Repeat Loan / Add ID, Edit Loan) ---
  Widget _buildTopBondSection(bool isTamil, bool isSmallPhone) {
    return _buildSectionCard(
      title: isTamil ? "தவணை எண் (Bond Number)" : "Bond Number",
      subtitle: isTamil
          ? "புதிய கடன், மறு கடன் (Add ID), அல்லது கடன் திருத்த முறையை தேர்வு செய்யவும்"
          : "Choose New Loan, Repeat Loan (Add ID), or Edit Loan",
      color: _entryMode == LoanEntryMode.repeatLoan
          ? const Color(0xFFE8F5E9)
          : (_entryMode == LoanEntryMode.editLoan ? const Color(0xFFFFF3E0) : const Color(0xFFE3F2FD)),
      borderColor: _entryMode == LoanEntryMode.repeatLoan
          ? Colors.green.shade400
          : (_entryMode == LoanEntryMode.editLoan ? Colors.orange.shade300 : const Color(0xFF90CAF9)),
      icon: Icons.confirmation_number_outlined,
      trailing: TextButton.icon(
        onPressed: _clearBondLookup,
        icon: const Icon(Icons.refresh, size: 16, color: Colors.blueGrey),
        label: Text(
          isTamil ? "அழிக்க" : "Reset",
          style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
        ),
        style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
      ),
      children: [
        // Mode Selector: 3 Tabs (New Loan, Repeat Loan / Add ID, Edit Loan)
        Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade300),
          ),
          padding: const EdgeInsets.all(3),
          child: Row(
            children: [
              _buildModeTabItem(
                mode: LoanEntryMode.newLoan,
                label: isTamil ? "புதிய கடன்" : "New Loan",
                icon: Icons.add_circle_outline,
                isTamil: isTamil,
              ),
              _buildModeTabItem(
                mode: LoanEntryMode.repeatLoan,
                label: isTamil ? "மறு கடன் (Add ID)" : "Repeat / Add ID",
                icon: Icons.person_add_alt_1,
                isHighlight: true,
                isTamil: isTamil,
              ),
              _buildModeTabItem(
                mode: LoanEntryMode.editLoan,
                label: isTamil ? "கடன் திருத்து" : "Edit Loan",
                icon: Icons.edit_note,
                isTamil: isTamil,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // --- Mode 1: New Loan ---
        if (_entryMode == LoanEntryMode.newLoan) ...[
          Text(
            isTamil
                ? "புதிய வாடிக்கையாளருக்கு புதிய கடன் பதிவு. வரிசை மற்றும் தவணை எண்ணை உள்ளிடவும்."
                : "Create a new loan for a new member. Select line and enter bond number.",
            style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: _buildLineDropdown(isTamil),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 3,
                child: _buildBondNoTextField(
                  isTamil: isTamil,
                  labelText: isTamil ? "தவணை எண் *" : "Bond No *",
                  hintText: '001',
                  onSearch: () => _onBondNumberChanged(_bondNoController.text),
                  onChanged: (val) => _onBondNumberChanged(val),
                ),
              ),
            ],
          ),

          // Feedback if existing bond is found in New Loan mode
          if (_bondLookupStatus == 'found' && _retrievedLoan != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade400),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.check_circle, color: Color(0xFF2E7D32), size: 22),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "${_retrievedLoan!.bondNumber} - ${_retrievedLoan!.customerName}",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1B5E20)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isTamil
                        ? "ஏற்கனவே உள்ள உறுப்பினர்! மீண்டும் கடன் வாங்க 'மறு கடன் (Add ID)' அழுத்தவும்:"
                        : "Existing member found! To issue another loan without deleting this one, tap Repeat Loan:",
                    style: TextStyle(fontSize: 11.5, color: Colors.green.shade900),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _setupRepeatLoanForCurrentMember(_retrievedLoan!),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2E7D32),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        icon: const Icon(Icons.add_task, size: 16),
                        label: Text(
                          isTamil ? "மறு கடன் வழங்க (Add ID)" : "Issue Repeat Loan (Add ID)",
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            _entryMode = LoanEntryMode.editLoan;
                          });
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          foregroundColor: const Color(0xFF1565C0),
                          side: const BorderSide(color: Color(0xFF1565C0)),
                        ),
                        icon: const Icon(Icons.edit, size: 15),
                        label: Text(
                          isTamil ? "இக்கடனை திருத்து" : "Edit This Loan",
                          style: const TextStyle(fontSize: 11.5),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ] else if (_bondLookupStatus == 'not_found') ...[
            const SizedBox(height: 10),
            _buildNotFoundBanner(isTamil),
          ],
        ],

        // --- Mode 2: Repeat Loan / Add ID (Existing Member borrows again) ---
        if (_entryMode == LoanEntryMode.repeatLoan) ...[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.shade300),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info, color: Color(0xFF2E7D32), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isTamil
                        ? "பழைய தவணை எண்ணை (எ.கா: A001) உள்ளிட்டால் உறுப்பினர் விவரங்கள் வரும். பிறகு புதிய எண் (எ.கா: A002) மற்றும் புதிய கடன் தொகையை உள்ளிட்டு சேமிக்கவும். பழைய கடன் அழியாது."
                        : "Enter existing bond (e.g., A001) to fetch member details. Then set new bond number (e.g., A002) and new borrowed amount. Previous loan will NOT be deleted.",
                    style: TextStyle(fontSize: 11.5, color: Colors.green.shade900, height: 1.35, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Field 1: Existing Member Bond Number
          TextFormField(
            controller: _existingMemberBondController,
            keyboardType: TextInputType.text,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              labelText: isTamil ? "பழைய தவணை எண் (Existing Bond / Member ID) *" : "Existing Bond / Member ID *",
              hintText: 'A001',
              prefixIcon: const Icon(Icons.history_edu, color: Color(0xFF2E7D32), size: 20),
              suffixIcon: IconButton(
                icon: const Icon(Icons.search, color: Color(0xFF2E7D32)),
                tooltip: isTamil ? "உறுப்பினரை தேடு" : "Search Member",
                onPressed: () => _searchExistingMemberForRepeat(_existingMemberBondController.text),
              ),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.green.shade400)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.green.shade300)),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            onFieldSubmitted: (val) => _searchExistingMemberForRepeat(val),
          ),

          // Retrieved Member Badge Card
          if (_sourceMemberLoan != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade400, width: 1.2),
                boxShadow: [
                  BoxShadow(color: Colors.green.withValues(alpha: 0.08), blurRadius: 4, offset: const Offset(0, 2)),
                ],
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      width: 44,
                      height: 48,
                      color: Colors.grey.shade100,
                      child: isValidPhotoPath(_sourceMemberLoan!.photoPath)
                          ? getSafeImageWidget(_sourceMemberLoan!.photoPath, fit: BoxFit.cover)
                          : const Icon(Icons.person, color: Color(0xFF2E7D32), size: 28),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              _sourceMemberLoan!.customerName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1B5E20)),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(4)),
                              child: Text(
                                "Old: ${_sourceMemberLoan!.bondNumber}",
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.green.shade900),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "📞 ${_sourceMemberLoan!.phoneNumber}  •  📍 ${_sourceMemberLoan!.city ?? 'மதுரை'}",
                          style: TextStyle(fontSize: 11.5, color: Colors.grey.shade800),
                        ),
                        Text(
                          isTamil
                              ? "✓ உறுப்பினர் விவரங்கள், புகைப்படம் மற்றும் ஆவணங்கள் இணைக்கப்பட்டன"
                              : "✓ Member details, photo & proofs attached",
                          style: const TextStyle(fontSize: 10.5, color: Color(0xFF2E7D32), fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),

          // Field 2: New Bond Number
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: _buildLineDropdown(isTamil),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 3,
                child: _buildBondNoTextField(
                  isTamil: isTamil,
                  labelText: isTamil ? "புதிய தவணை எண் *" : "New Bond No *",
                  hintText: '002',
                  onChanged: (val) {
                    setState(() {});
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F8E9),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.green.shade300),
            ),
            child: Row(
              children: [
                const Icon(Icons.shield_outlined, size: 16, color: Color(0xFF2E7D32)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    isTamil
                        ? "புதிய கடன் '$_selectedLine${_bondNoController.text.trim()}' உருவாக்கப்படும். பழைய கடன் '${_sourceMemberLoan?.bondNumber ?? _existingMemberBondController.text}' அழியாது."
                        : "New loan '$_selectedLine${_bondNoController.text.trim()}' will be created. Previous loan '${_sourceMemberLoan?.bondNumber ?? _existingMemberBondController.text}' will not be deleted.",
                    style: TextStyle(fontSize: 11, color: Colors.green.shade900, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ],

        // --- Mode 3: Edit Existing Loan ---
        if (_entryMode == LoanEntryMode.editLoan) ...[
          Text(
            isTamil
                ? "ஏற்கனவே உள்ள கடன் விவரங்களை திருத்த, தவணை எண்ணை தேடவும்."
                : "Search existing bond number to edit its loan and member details.",
            style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: _buildLineDropdown(isTamil),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 3,
                child: _buildBondNoTextField(
                  isTamil: isTamil,
                  labelText: isTamil ? "தவணை எண் *" : "Bond No *",
                  hintText: '001',
                  onSearch: () => _onBondNumberChanged(_bondNoController.text),
                  onChanged: (val) => _onBondNumberChanged(val),
                ),
              ),
            ],
          ),
          if (_retrievedLoan != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade300),
              ),
              child: Row(
                children: [
                  const Icon(Icons.edit, color: Colors.orange, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isTamil
                          ? "தவணை எண் '${_retrievedLoan!.bondNumber} - ${_retrievedLoan!.customerName}' திருத்தப்படுகிறது. சேமிக்கும்போது இந்த கடன் புதுப்பிக்கப்படும்."
                          : "Editing '${_retrievedLoan!.bondNumber} - ${_retrievedLoan!.customerName}'. Changes will update this loan.",
                      style: TextStyle(fontSize: 11.5, color: Colors.orange.shade900, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildModeTabItem({
    required LoanEntryMode mode,
    required String label,
    required IconData icon,
    bool isHighlight = false,
    required bool isTamil,
  }) {
    final isSelected = _entryMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => _switchEntryMode(mode),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? (isHighlight ? const Color(0xFF2E7D32) : const Color(0xFF1565C0))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: (isHighlight ? Colors.green : Colors.blue).withValues(alpha: 0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: isSelected ? Colors.white : Colors.grey.shade700,
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? Colors.white : Colors.grey.shade800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLineDropdown(bool isTamil) {
    return DropdownButtonFormField<String>(
      initialValue: widget.repository.availableLines.contains(_selectedLine)
          ? _selectedLine
          : (widget.repository.availableLines.isNotEmpty ? widget.repository.availableLines.first : null),
      isExpanded: true,
      decoration: InputDecoration(
        labelText: isTamil ? "வரிசை (Line)" : "Line",
        prefixIcon: const Icon(Icons.alt_route, size: 18),
        suffixIcon: IconButton(
          icon: const Icon(Icons.tune, size: 16),
          tooltip: isTamil ? "வரிசைகளை நிர்வகி" : "Manage Lines",
          onPressed: () async {
            await showLineManagementDialog(context, widget.repository);
            setState(() {
              if (!widget.repository.availableLines.contains(_selectedLine)) {
                _selectedLine = widget.repository.availableLines.isNotEmpty ? widget.repository.availableLines.first : 'A';
              }
            });
          },
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      ),
      items: widget.repository.availableLines.map((line) {
        return DropdownMenuItem(value: line, child: Text("Line $line"));
      }).toList(),
      onChanged: _onLineChanged,
    );
  }

  Widget _buildBondNoTextField({
    required bool isTamil,
    required String labelText,
    required String hintText,
    VoidCallback? onSearch,
    ValueChanged<String>? onChanged,
  }) {
    return TextFormField(
      controller: _bondNoController,
      keyboardType: TextInputType.text,
      inputFormatters: [
        LengthLimitingTextInputFormatter(10),
      ],
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      decoration: InputDecoration(
        labelText: labelText,
        prefixText: "$_selectedLine ",
        prefixStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primary),
        hintText: hintText,
        suffixIcon: onSearch != null
            ? IconButton(
                icon: const Icon(Icons.search, size: 20),
                tooltip: isTamil ? "தேடு" : "Search",
                onPressed: onSearch,
              )
            : null,
        filled: true,
        fillColor: Colors.grey.shade50,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      ),
      onChanged: onChanged,
      validator: (v) => v == null || v.trim().isEmpty ? (isTamil ? 'தவணை எண் தேவை' : 'Bond No required') : null,
    );
  }

  Widget _buildNotFoundBanner(bool isTamil) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber.shade400),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.amber.shade900, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isTamil
                  ? "தவணை எண் '$_lastSearchedBond' கிடைக்கவில்லை. புதிய கடன் விவரங்களை சாதாரணமாக உள்ளிடலாம்."
                  : "Bond number '$_lastSearchedBond' not found. You can enter new loan details normally.",
              style: TextStyle(fontSize: 11.5, color: Colors.amber.shade900, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  // --- Box 2: Loan Details (Drawing 3) ---
  Widget _buildLoanDetailsSection(bool isTamil, bool isSmallPhone) {
    return _buildSectionCard(
      title: isTamil ? "கடன் விபரங்கள் (Loan Details)" : "Loan Details",
      subtitle: isTamil ? "தொகை, தவணை மற்றும் காலம்" : "Amount, Tenure & Dates",
      color: const Color(0xFFFFF8E1),
      borderColor: Colors.amber.shade300,
      icon: Icons.receipt_long,
      children: [
        // Row 1: Tenure Days & Chit Fee
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _tenureDaysController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(4),
                ],
                decoration: InputDecoration(
                  labelText: isTamil ? "தவணை நாட்கள்" : "Tenure Days",
                  suffixText: isTamil ? "நாள்" : "Days",
                  filled: true,
                  fillColor: Colors.white,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                ),
                onChanged: (_) => _updateCalculations(),
                validator: (v) => (int.tryParse(v ?? '') ?? 0) <= 0 ? (isTamil ? 'தவறானது' : 'Invalid') : null,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: _chitFeeController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(7),
                ],
                decoration: InputDecoration(
                  labelText: isTamil ? "சீட்டு காசு" : "Chit Fee",
                  prefixText: "₹ ",
                  filled: true,
                  fillColor: Colors.white,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                ),
                onChanged: (_) => _updateCalculations(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Row 2: Loan Amount & Interest Amount
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _loanAmountController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(9),
                ],
                decoration: InputDecoration(
                  labelText: isTamil ? "கடன் தொகை" : "Loan Amount",
                  prefixText: "₹ ",
                  filled: true,
                  fillColor: Colors.white,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                ),
                onChanged: (_) => _updateCalculations(),
                validator: (v) => (double.tryParse(v ?? '') ?? 0) <= 0 ? (isTamil ? 'தொகை உள்ளிடவும்' : 'Enter amount') : null,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: _interestAmountController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(8),
                ],
                decoration: InputDecoration(
                  labelText: isTamil ? "வட்டி தொகை" : "Interest Amount",
                  prefixText: "₹ ",
                  filled: true,
                  fillColor: Colors.white,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                ),
                onChanged: (_) => _updateCalculations(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Row 3: Start Date & End Date
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: _pickStartDate,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: isTamil ? "தொடக்க தேதி" : "Start Date",
                    suffixIcon: const Icon(Icons.calendar_month, size: 20, color: AppColors.primary),
                    filled: true,
                    fillColor: Colors.white,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      AppDateUtils.format(_startDate),
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: isTamil ? "முடிவு தேதி" : "End Date",
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    AppDateUtils.format(_endDate),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // --- Box 2: Borrower Particulars & Photo (Drawing 3) ---
  Widget _buildBorrowerDetailsSection(bool isTamil, bool isSmallPhone) {
    return _buildSectionCard(
      title: isTamil ? "உறுப்பினர் விபரங்கள் (Borrower Particulars)" : "Borrower & ID Proof",
      subtitle: isTamil ? "புகைப்படம், பெயர், முகவரி மற்றும் அலைபேசி" : "Photo, Name, Address & Contact",
      color: Colors.white,
      borderColor: Colors.green.shade300,
      icon: Icons.person,
      children: [
        // Member Photo Capture (Drawing 3: "member photo")
        Center(
          child: Column(
            children: [
              Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.primary, width: 2.5),
                      boxShadow: const [
                        BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2)),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 44,
                      backgroundColor: Colors.grey.shade100,
                      backgroundImage: getSafeImageProvider(_photoPath),
                      child: !_isValidPhoto(_photoPath)
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.person, size: 38, color: Colors.grey),
                                Text(
                                  isTamil ? 'புகைப்படம்' : 'Photo',
                                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                                ),
                              ],
                            )
                          : null,
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: InkWell(
                      onTap: () => _showImageOptions(
                        'customer',
                        isTamil ? "உறுப்பினர் புகைப்படம் (Member Photo)" : "Member Photo",
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(Icons.camera_alt, color: Colors.white, size: 17),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              TextButton.icon(
                onPressed: () => _showImageOptions(
                  'customer',
                  isTamil ? "உறுப்பினர் புகைப்படம் (Member Photo)" : "Member Photo",
                ),
                icon: const Icon(Icons.photo_camera, size: 16, color: AppColors.primary),
                label: Text(
                  _photoPath == null
                      ? (isTamil ? "படம் சேர்க்க (Take / Upload)" : "Add Photo")
                      : (isTamil ? "படம் மாற்ற (Change Photo)" : "Change Photo"),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Member Name (Drawing 3)
        TextFormField(
          controller: _partyNameController,
          decoration: InputDecoration(
            labelText: isTamil ? "உறுப்பினர் பெயர் (Member Name) *" : "Member Name *",
            prefixIcon: const Icon(Icons.person_outline),
            filled: true,
            fillColor: Colors.white,
          ),
          validator: (v) => v == null || v.trim().isEmpty ? (isTamil ? 'பெயர் தேவை (Name required)' : 'Name required') : null,
        ),
        const SizedBox(height: 10),

        // Member Father / Spouse Name & City (Drawing 3)
        Row(
          children: [
            Expanded(
              flex: 3,
              child: TextFormField(
                controller: _fatherNameController,
                decoration: InputDecoration(
                  labelText: isTamil ? "தகப்பனார் / கணவர் (Father/Spouse)" : "Father / Spouse Name",
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: _cityController,
                decoration: InputDecoration(
                  labelText: isTamil ? "ஊர் (City)" : "City / Town",
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Phone Number (Drawing 3)
        TextFormField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(10),
          ],
          decoration: InputDecoration(
            labelText: isTamil ? "அலைபேசி எண் (Phone Number) *" : "Phone Number *",
            prefixIcon: const Icon(Icons.phone),
            filled: true,
            fillColor: Colors.white,
          ),
          validator: (v) => v == null || v.trim().length < 8 ? (isTamil ? 'சரியான எண் உள்ளிடவும்' : 'Valid phone required') : null,
        ),
        const SizedBox(height: 10),

        // Address (Drawing 3)
        TextFormField(
          controller: _addressController,
          maxLines: 2,
          decoration: InputDecoration(
            labelText: isTamil ? "முகவரி (Address)" : "Address",
            prefixIcon: const Icon(Icons.home_outlined),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
      ],
    );
  }

  // --- Box 3: Document Proof (Drawing 3) ---
  Widget _buildDocumentProofSection(bool isTamil, bool isSmallPhone) {
    return _buildSectionCard(
      title: isTamil ? "ஆவண சான்றுகள் (Document Proof)" : "Document Proof",
      subtitle: isTamil ? "அடையாள சான்று வகை, முன் & பின் பக்க படங்கள்" : "Proof Type, Front & Back Photos",
      color: Colors.white,
      borderColor: Colors.blue.shade300,
      icon: Icons.verified_user,
      children: [
        // Reference Proof Selector (Drawing 3: "reference proof like Aadhaar, Voter ID, PAN, Ration, Driving")
        DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue: _selectedProofType,
          decoration: InputDecoration(
            labelText: isTamil ? "அடையாள சான்று வகை (Proof Type)" : "Reference Proof Document",
            prefixIcon: const Icon(Icons.badge_outlined),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            filled: true,
            fillColor: Colors.white,
          ),
          items: [
            'ஆதார் அட்டை (Aadhaar Card)',
            'வாக்காளர் அட்டை (Voter ID)',
            'பான் கார்டு (PAN Card)',
            'குடும்ப அட்டை (Ration Card)',
            'ஓட்டுநர் உரிமம் (Driving License)',
          ].map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis))).toList(),
          onChanged: (val) {
            if (val != null) setState(() => _selectedProofType = val);
          },
        ),
        const SizedBox(height: 12),

        // Front & Back Document Photos (Drawing 3: "front side", "back side")
        Row(
          children: [
            Expanded(
              child: _buildProofPhotoCard(
                title: isTamil ? "முன் பக்கம் (Front Side)" : "Front Side",
                photoPath: _proofFrontPaths[_selectedProofType],
                onTap: () => _showImageOptions(
                  'proofFront',
                  isTamil ? "சான்று முன் பக்கம் (Front Side)" : "Proof Front Side",
                ),
                onRemove: () => setState(() => _proofFrontPaths[_selectedProofType] = null),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildProofPhotoCard(
                title: isTamil ? "பின் பக்கம் (Back Side)" : "Back Side",
                photoPath: _proofBackPaths[_selectedProofType],
                onTap: () => _showImageOptions(
                  'proofBack',
                  isTamil ? "சான்று பின் பக்கம் (Back Side)" : "Proof Back Side",
                ),
                onRemove: () => setState(() => _proofBackPaths[_selectedProofType] = null),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Notes / Extra Details
        TextFormField(
          controller: _detailsController,
          decoration: InputDecoration(
            labelText: isTamil ? "கூடுதல் விபரம் / தொழில் (Notes / Occupation)" : "Notes / Occupation",
            prefixIcon: const Icon(Icons.note_alt_outlined),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
      ],
    );
  }

  // --- Bottom Action Buttons (Drawing 3: save loan, cancel) ---
  Widget _buildBottomActionButtons(bool isTamil) {
    return Row(
      children: [
        // Cancel Button (Drawing 3)
        Expanded(
          flex: 2,
          child: AnimatedPressable(
            onTap: () => Navigator.pop(context),
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: BorderSide(color: Colors.grey.shade400),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.pop(context),
              child: Text(
                isTamil ? "ரத்து (Cancel)" : "Cancel",
                style: TextStyle(color: Colors.grey.shade800, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Save Loan Button (Drawing 3)
        Expanded(
          flex: 3,
          child: AnimatedPressable(
            onTap: _isSaving ? null : _saveLoan,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 3,
              ),
              onPressed: _isSaving ? null : _saveLoan,
              icon: _isSaving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.save),
              label: Text(
                _isSaving
                    ? (isTamil ? "சேமிக்கிறது..." : "Saving...")
                    : (isTamil ? "கடன் சேமிக்க (Save Loan)" : "Save Loan"),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionCard({
    required String title,
    String? subtitle,
    required Color color,
    Color? borderColor,
    required IconData icon,
    Widget? trailing,
    required List<Widget> children,
  }) {
    return HoverScaleCard(
      color: color,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: borderColor ?? Colors.grey.shade300, width: 1.2),
      elevation: 1,
      hoverElevation: 3,
      hoverScale: 1.008,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle,
                        style: const TextStyle(fontSize: 11, color: Colors.black54),
                      ),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
          const Divider(height: 18),
          ...children,
        ],
      ),
    );
  }

  Widget _buildProofPhotoCard({
    required String title,
    required String? photoPath,
    required VoidCallback onTap,
    required VoidCallback onRemove,
  }) {
    final hasPhoto = _isValidPhoto(photoPath);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 110,
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: hasPhoto ? AppColors.primary : Colors.grey.shade300,
            width: hasPhoto ? 1.5 : 1,
          ),
        ),
        child: hasPhoto
            ? Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(9),
                    child: _buildPhotoWidget(photoPath!),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: InkWell(
                      onTap: onRemove,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close, color: Colors.white, size: 14),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      color: Colors.black54,
                      child: Text(
                        title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add_a_photo_outlined, color: Colors.grey, size: 28),
                  const SizedBox(height: 6),
                  Text(
                    title,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black87),
                  ),
                  Text(
                    widget.repository.isTamil ? "+ படம் எடுக்க" : "+ Add Photo",
                    style: TextStyle(fontSize: 10, color: Colors.blue.shade700),
                  ),
                ],
              ),
      ),
    );
  }

}

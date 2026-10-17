import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_animations.dart';
import '../../../../core/models/loan_model.dart';
import '../../../../core/services/loan_repository.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../../core/utils/web_camera_helper.dart';
import '../../../../core/utils/safe_image_provider.dart';
import '../../../../core/services/app_finance_folder_service.dart';

class EditMemberDialog extends StatefulWidget {
  final LoanModel loan;
  final LoanRepository repository;
  final VoidCallback onUpdated;

  const EditMemberDialog({
    super.key,
    required this.loan,
    required this.repository,
    required this.onUpdated,
  });

  @override
  State<EditMemberDialog> createState() => _EditMemberDialogState();
}

class _EditMemberDialogState extends State<EditMemberDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _fatherController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  late TextEditingController _cityController;
  late TextEditingController _notesController;

  // Financial fields (Admin editable, Viewer read-only)
  late TextEditingController _loanAmountController;
  late TextEditingController _interestAmountController;
  late TextEditingController _tenureDaysController;

  String? _photoPath;
  String? _selectedProofType;
  final Map<String, String?> _proofFrontPaths = {};
  final Map<String, String?> _proofBackPaths = {};
  DateTime? _startDate;
  bool _isSaving = false;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final l = widget.loan;
    _nameController = TextEditingController(text: l.customerName);
    _fatherController = TextEditingController(text: l.fatherOrSpouseName ?? '');
    _phoneController = TextEditingController(text: l.phoneNumber);
    _addressController = TextEditingController(text: l.address ?? '');
    _cityController = TextEditingController(text: l.city ?? 'மதுரை');
    _notesController = TextEditingController(text: l.customer?.notes ?? '');

    _loanAmountController = TextEditingController(text: l.loanAmount.toStringAsFixed(0));
    _interestAmountController = TextEditingController(text: l.interestAmount.toStringAsFixed(0));
    _tenureDaysController = TextEditingController(text: l.tenureDays.toString());

    _photoPath = l.photoPath;
    _selectedProofType = l.proofType ?? 'ஆதார் அட்டை (Aadhaar Card)';
    if (l.proofFrontPath != null) _proofFrontPaths[_selectedProofType!] = l.proofFrontPath;
    if (l.proofBackPath != null) _proofBackPaths[_selectedProofType!] = l.proofBackPath;
    _startDate = l.startDate;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _fatherController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _notesController.dispose();
    _loanAmountController.dispose();
    _interestAmountController.dispose();
    _tenureDaysController.dispose();
    super.dispose();
  }

  Widget _buildPhotoWidget(String path, {BoxFit fit = BoxFit.cover}) {
    return getSafeImageWidget(path, fit: fit);
  }

  Future<void> _pickImageForTarget(ImageSource source, String target) async {
    try {
      String? imagePath;

      if (kIsWeb && source == ImageSource.camera) {
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
          if (target == 'proofFront' && _selectedProofType != null) _proofFrontPaths[_selectedProofType!] = imagePath;
          if (target == 'proofBack' && _selectedProofType != null) _proofBackPaths[_selectedProofType!] = imagePath;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Photo error: $e')),
        );
      }
    }
  }

  void _showImageOptions(String target, String title) {
    final isTamil = widget.repository.isTamil;
    final currentFront = _selectedProofType != null ? _proofFrontPaths[_selectedProofType!] : null;
    final currentBack = _selectedProofType != null ? _proofBackPaths[_selectedProofType!] : null;
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
                    if (target == 'proofFront') _proofFrontPaths[_selectedProofType!] = null;
                    if (target == 'proofBack') _proofBackPaths[_selectedProofType!] = null;
                  });
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final isTamil = widget.repository.isTamil;

    try {
      await widget.repository.updateMember(
        loanId: widget.loan.id,
        customerName: _nameController.text.trim(),
        fatherOrSpouseName: _fatherController.text.trim().isEmpty ? null : _fatherController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
        city: _cityController.text.trim(),
        photoPath: _photoPath,
        proofType: _selectedProofType,
        proofFrontPath: _selectedProofType != null ? _proofFrontPaths[_selectedProofType!] : null,
        proofBackPath: _selectedProofType != null ? _proofBackPaths[_selectedProofType!] : null,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        // Financial fields
        loanAmount: double.tryParse(_loanAmountController.text),
        interestAmount: double.tryParse(_interestAmountController.text),
        tenureDays: int.tryParse(_tenureDaysController.text),
        startDate: _startDate,
      );

      final updatedLoan = widget.repository.getLoanByBond(widget.loan.bondNumber, widget.loan.lineCode) ?? widget.loan;
      try {
        final collections = widget.repository.getLedger(updatedLoan.bondNumber, loanId: updatedLoan.id);
        await AppFinanceFolderService.saveMemberFiles(
          loan: updatedLoan,
          collections: collections,
          isTamil: widget.repository.isTamil,
        );
      } catch (err) {
        debugPrint('Auto folder sync on member edit: $err');
      }

      if (mounted) {
        widget.onUpdated();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isTamil ? 'உறுப்பினர் விவரங்கள் & app-finance கோப்புறைகள் புதுப்பிக்கப்பட்டன!' : 'Member details & app-finance folders updated!'),
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

  void _confirmDelete() {
    final isTamil = widget.repository.isTamil;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isTamil ? 'கணக்கை நீக்கவா?' : 'Delete Loan?'),
        content: Text(
          isTamil
              ? '${widget.loan.bondNumber} - ${widget.loan.customerName} கடன் கணக்கை முழுமையாக நீக்க விரும்புகிறீர்களா?'
              : 'Are you sure you want to permanently delete loan ${widget.loan.bondNumber}?',
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
                await widget.repository.deleteLoan(widget.loan.id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(isTamil ? 'கடன் கணக்கு வெற்றிகரமாக நீக்கப்பட்டது' : 'Loan deleted successfully'),
                      backgroundColor: Colors.red.shade700,
                    ),
                  );
                  widget.onUpdated();
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
            child: Text(isTamil ? 'நீக்கு' : 'Delete', style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isTamil = widget.repository.isTamil;
    final isAdmin = widget.repository.isAdmin;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 550),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: const BoxDecoration(
                color: Color(0xFF1565C0),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.edit_note, color: Colors.white, size: 24),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isTamil ? 'உறுப்பினர் விவரம் திருத்தம்' : 'Edit Member Details',
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${isTamil ? "தவணை எண்" : "Bond ID"}: ${widget.loan.bondNumber}',
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade700,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'ADMIN',
                        style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Form Body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(18),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Photo Section (Camera)
                      Center(
                        child: Column(
                          children: [
                            Stack(
                              children: [
                                CircleAvatar(
                                  radius: 44,
                                  backgroundColor: Colors.grey.shade200,
                                  backgroundImage: getSafeImageProvider(_photoPath),
                                  child: !isValidPhotoPath(_photoPath)
                                      ? const Icon(Icons.person, size: 50, color: Colors.grey)
                                      : null,
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: InkWell(
                                    onTap: () => _showImageOptions('customer', isTamil ? 'வாடிக்கையாளர் புகைப்படம் (Customer Photo)' : 'Customer Photo'),
                                    child: Container(
                                      padding: const EdgeInsets.all(7),
                                      decoration: const BoxDecoration(
                                        color: AppColors.primary,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.camera_alt, color: Colors.white, size: 18),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            TextButton.icon(
                              onPressed: () => _showImageOptions('customer', isTamil ? 'வாடிக்கையாளர் புகைப்படம் (Customer Photo)' : 'Customer Photo'),
                              icon: const Icon(Icons.photo_camera, size: 16),
                              label: Text(
                                _photoPath == null
                                    ? (isTamil ? 'புகைப்படம் சேர்க்க (Add Photo)' : 'Add Photo')
                                    : (isTamil ? 'புகைப்படம் மாற்ற (Change)' : 'Change Photo'),
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 10),
                      Text(
                        isTamil ? 'தனிப்பட்ட விவரங்கள்' : 'Personal Details',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary),
                      ),
                      const Divider(),

                      // Customer Name
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: isTamil ? 'உறுப்பினர் பெயர் (Customer Name) *' : 'Customer Name *',
                          prefixIcon: const Icon(Icons.person),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter name' : null,
                      ),
                      const SizedBox(height: 10),

                      // Father / Spouse
                      TextFormField(
                        controller: _fatherController,
                        decoration: InputDecoration(
                          labelText: isTamil ? 'தகப்பனார் / கணவர் பெயர்' : 'Father / Spouse Name',
                          prefixIcon: const Icon(Icons.people_outline),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Phone Number
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: isTamil ? 'அலைபேசி எண் (Phone Number) *' : 'Phone Number *',
                          prefixIcon: const Icon(Icons.phone),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter phone' : null,
                      ),
                      const SizedBox(height: 10),

                      // Address & City
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _addressController,
                              decoration: InputDecoration(
                                labelText: isTamil ? 'முகவரி (Address)' : 'Address',
                                prefixIcon: const Icon(Icons.home_outlined),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: _cityController,
                              decoration: InputDecoration(
                                labelText: isTamil ? 'ஊர் (City)' : 'City',
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 18),
                      // Proof Section (Verification Documents)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.verified_user, size: 16, color: AppColors.primary),
                                const SizedBox(width: 6),
                                Text(
                                  isTamil ? 'சான்று ஆவணங்கள் (Document Proofs)' : 'Document Proofs',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            // Reference Proof Type Selector
                            DropdownButtonFormField<String>(
                              initialValue: _selectedProofType,
                              decoration: InputDecoration(
                                labelText: isTamil ? 'அடையாள சான்று வகை (Proof Type)' : 'Reference Proof Document',
                                prefixIcon: const Icon(Icons.badge_outlined),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                              items: [
                                'ஆதார் அட்டை (Aadhaar Card)',
                                'வாக்காளர் அட்டை (Voter ID)',
                                'பான் கார்டு (PAN Card)',
                                'குடும்ப அட்டை (Ration Card)',
                                'ஓட்டுநர் உரிமம் (Driving License)',
                              ].map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 13)))).toList(),
                              onChanged: (val) {
                                if (val != null) setState(() => _selectedProofType = val);
                              },
                            ),
                            const SizedBox(height: 12),

                            // Front & Back Document Photos
                            Row(
                              children: [
                                // Front Side Photo
                                Expanded(
                                  child: _buildProofPhotoCard(
                                    title: isTamil ? 'முன் பக்கம் (Front)' : 'Proof Front',
                                    photoPath: _selectedProofType != null ? _proofFrontPaths[_selectedProofType!] : null,
                                    onTap: () => _showImageOptions('proofFront', isTamil ? 'சான்று முன் பக்கம் (Proof Front)' : 'Proof Front Side'),
                                    onRemove: () => setState(() {
                                      if (_selectedProofType != null) _proofFrontPaths[_selectedProofType!] = null;
                                    }),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                // Back Side Photo
                                Expanded(
                                  child: _buildProofPhotoCard(
                                    title: isTamil ? 'பின் பக்கம் (Back)' : 'Proof Back',
                                    photoPath: _selectedProofType != null ? _proofBackPaths[_selectedProofType!] : null,
                                    onTap: () => _showImageOptions('proofBack', isTamil ? 'சான்று பின் பக்கம் (Proof Back)' : 'Proof Back Side'),
                                    onRemove: () => setState(() {
                                      if (_selectedProofType != null) _proofBackPaths[_selectedProofType!] = null;
                                    }),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 18),
                      // Financial Details Section
                      Row(
                        children: [
                          const Icon(Icons.monetization_on, size: 16, color: AppColors.primary),
                          const SizedBox(width: 6),
                          Text(
                            isTamil ? 'கடன் & நிதி விவரங்கள்' : 'Loan & Financial Terms',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      const Divider(),

                      // Loan Amount & Interest Amount
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _loanAmountController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: isTamil ? 'கடன் தொகை (Loan Amt)' : 'Loan Amount',
                                prefixText: '₹ ',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: _interestAmountController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: isTamil ? 'வட்டி (Interest)' : 'Interest Amount',
                                prefixText: '₹ ',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Tenure & Current Balance Overview
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _tenureDaysController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: isTamil ? 'நாட்கள் (Tenure)' : 'Tenure (Days)',
                                suffixText: isTamil ? 'நாள்' : 'days',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(isTamil ? 'மீதி பாக்கி' : 'Current Balance', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                  Text(
                                    CurrencyUtils.format(widget.loan.balanceAmount),
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.error),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),
                      // Notes
                      TextFormField(
                        controller: _notesController,
                        decoration: InputDecoration(
                          labelText: isTamil ? 'குறிப்புகள் (Notes / Business)' : 'Notes / Business',
                          prefixIcon: const Icon(Icons.note_alt_outlined),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Footer Actions
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  if (isAdmin)
                    IconButton(
                      icon: const Icon(Icons.delete_forever, color: Colors.red),
                      tooltip: isTamil ? 'கணக்கை நீக்கு' : 'Delete Loan',
                      onPressed: _confirmDelete,
                    ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(isTamil ? 'ரத்து' : 'Cancel'),
                  ),
                  const SizedBox(width: 8),
                  AnimatedPressable(
                    onTap: _isSaving ? null : _saveChanges,
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _saveChanges,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                      icon: _isSaving
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.save, size: 18),
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(isTamil ? 'சேமி' : 'Save Changes'),
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

  Widget _buildProofPhotoCard({
    required String title,
    required String? photoPath,
    required VoidCallback onTap,
    required VoidCallback onRemove,
  }) {
    final isTamil = widget.repository.isTamil;
    return HoverScaleCard(
      hoverScale: 1.02,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
        height: 110,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: photoPath != null ? AppColors.primary : Colors.grey.shade400,
            width: photoPath != null ? 1.5 : 1,
          ),
        ),
        child: photoPath != null
            ? Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(7),
                    child: _buildPhotoWidget(photoPath),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      color: Colors.black.withValues(alpha: 0.6),
                      child: Text(
                        title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: InkWell(
                      onTap: onRemove,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                        child: const Icon(Icons.close, size: 12, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add_a_photo_outlined, size: 28, color: AppColors.primary),
                  const SizedBox(height: 6),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                  ),
                  Text(
                    isTamil ? 'படம் சேர்க்க' : 'Upload',
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                  ),
                ],
              ),
        ),
      ),
    );
  }
}

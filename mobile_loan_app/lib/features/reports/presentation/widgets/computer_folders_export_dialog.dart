import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/services/loan_repository.dart';
import '../../../../core/services/records_export_service.dart';
import '../../../../core/services/app_finance_folder_service.dart';

class ComputerFoldersExportDialog extends StatefulWidget {
  final LoanRepository repository;

  const ComputerFoldersExportDialog({super.key, required this.repository});

  static Future<void> show(BuildContext context, LoanRepository repository) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => ComputerFoldersExportDialog(repository: repository),
    );
  }

  @override
  State<ComputerFoldersExportDialog> createState() => _ComputerFoldersExportDialogState();
}

class _ComputerFoldersExportDialogState extends State<ComputerFoldersExportDialog> {
  String _selectedLine = 'ALL';
  bool _isExporting = false;
  double _progress = 0.0;
  String _statusText = '';
  RecordsExportResult? _result;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    final isTamil = widget.repository.isTamil;
    final theme = Theme.of(context);

    final matchingLoans = widget.repository.getLoans(
      lineCode: _selectedLine == 'ALL' ? null : _selectedLine,
      status: 'All',
      financialYear: 'All',
    );

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.folder_special, color: AppColors.primary, size: 26),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isTamil ? 'app-finance கணினி கோப்புறைகள்' : 'app-finance Storage Folders',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: const Color(0xFF0D47A1),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          isTamil
                              ? 'புகைப்படம், சான்றுகள் & உறுப்பினர் PDF-கள் நேரடி சேமிப்பு'
                              : 'Photos, proofs & member details stored directly in folders',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade600,
                            fontSize: 11.5,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _isExporting ? null : () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(height: 20),

              // Folders Explanation Card
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.folder, size: 18, color: Color(0xFF0D47A1)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            isTamil
                                ? 'முக்கிய கோப்புறை: app-finance'
                                : 'Main Folder: app-finance',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildFolderRow(
                      icon: Icons.person_pin,
                      folderName: 'member-photo/',
                      descTamil: 'புகைப்படங்கள் (.jpg)',
                      descEnglish: 'Member photos (.jpg)',
                      color: Colors.blue.shade700,
                    ),
                    const SizedBox(height: 6),
                    _buildFolderRow(
                      icon: Icons.badge,
                      folderName: 'member-proof/',
                      descTamil: 'ஆவண சான்றுகள் (.jpg)',
                      descEnglish: 'Front & back proofs (.jpg)',
                      color: Colors.teal.shade700,
                    ),
                    const SizedBox(height: 6),
                    _buildFolderRow(
                      icon: Icons.picture_as_pdf,
                      folderName: 'member-details/',
                      descTamil: 'உறுப்பினர் விவரங்கள் & பாஸ்புக் (.pdf)',
                      descEnglish: 'Member details & ledger (.pdf)',
                      color: Colors.red.shade700,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Local Folder Connection Card on Web
              if (kIsWeb) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppFinanceFolderService.cachedDirectoryName != null
                        ? const Color(0xFFF0FDF4)
                        : const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppFinanceFolderService.cachedDirectoryName != null
                          ? const Color(0xFF86EFAC)
                          : const Color(0xFFBFDBFE),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        AppFinanceFolderService.cachedDirectoryName != null
                            ? Icons.check_circle
                            : Icons.drive_folder_upload,
                        size: 22,
                        color: AppFinanceFolderService.cachedDirectoryName != null
                            ? const Color(0xFF16A34A)
                            : const Color(0xFF2563EB),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppFinanceFolderService.cachedDirectoryName != null
                                  ? (isTamil
                                      ? 'இணைக்கப்பட்ட கோப்புறை: ${AppFinanceFolderService.cachedDirectoryName}'
                                      : 'Connected: ${AppFinanceFolderService.cachedDirectoryName}')
                                  : (isTamil
                                      ? 'கணினி கோப்புறை (Local Folder) தேர்வு'
                                      : 'Local "app-finance" Folder'),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12.5,
                                color: AppFinanceFolderService.cachedDirectoryName != null
                                    ? const Color(0xFF15803D)
                                    : const Color(0xFF1E40AF),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              AppFinanceFolderService.cachedDirectoryName != null
                                  ? (isTamil
                                      ? 'கோப்புகள் நேரடியாக member-photo, member-proof, member-details இல் சேமிக்கப்படும்'
                                      : 'Files save directly into member-photo, member-proof, and member-details')
                                  : (isTamil
                                      ? 'உங்கள் கணினியில் உள்ள app-finance கோப்புறையை தேர்வு செய்தால் படங்கள் & PDF நேராக சேமிக்கப்படும்'
                                      : 'Select your local app-finance folder to save photos & PDFs directly to disk'),
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          visualDensity: VisualDensity.compact,
                          foregroundColor: AppFinanceFolderService.cachedDirectoryName != null
                              ? const Color(0xFF15803D)
                              : const Color(0xFF1D4ED8),
                          side: BorderSide(
                            color: AppFinanceFolderService.cachedDirectoryName != null
                                ? const Color(0xFF16A34A)
                                : const Color(0xFF2563EB),
                          ),
                        ),
                        icon: const Icon(Icons.folder_open, size: 16),
                        label: Text(
                          AppFinanceFolderService.cachedDirectoryName != null
                              ? (isTamil ? 'மாற்ற' : 'Change')
                              : (isTamil ? 'தேர்வு' : 'Select'),
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                        ),
                        onPressed: _isExporting
                            ? null
                            : () async {
                                final handle = await AppFinanceFolderService.pickAppFinanceDirectory();
                                if (handle != null && mounted) {
                                  setState(() {});
                                }
                              },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Filter Line Selector
              if (!_isExporting && _result == null) ...[
                Row(
                  children: [
                    Text(
                      isTamil ? 'லைன் தேர்வு (Line): ' : 'Select Line: ',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.white,
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedLine,
                            isExpanded: true,
                            items: [
                              DropdownMenuItem(
                                value: 'ALL',
                                child: Text(isTamil ? 'அனைத்து லைன்கள் (All Lines)' : 'All Lines (A, B, C, D)'),
                              ),
                              for (final line in widget.repository.getLines())
                                DropdownMenuItem(
                                  value: line.lineCode,
                                  child: Text('Line ${line.lineCode} - ${line.lineName}'),
                                ),
                            ],
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedLine = val);
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  isTamil
                      ? 'தேர்ந்தெடுக்கப்பட்ட கடன்கள்: ${matchingLoans.length} உறுப்பினர்கள்'
                      : 'Selected: ${matchingLoans.length} member records ready to organize',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 12.5, fontWeight: FontWeight.w500),
                ),
              ],

              // Progress Bar during export
              if (_isExporting) ...[
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: _progress > 0 ? _progress : null,
                  backgroundColor: Colors.blue.shade50,
                  color: AppColors.primary,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 8),
                Text(
                  _statusText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0D47A1)),
                ),
              ],

              // Result Banner
              if (_result != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.green.shade400),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green, size: 22),
                          const SizedBox(width: 8),
                          Text(
                            isTamil ? 'வெற்றிகரமாக சேமிக்கப்பட்டது!' : 'Stored in app-finance Successfully!',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1B5E20), fontSize: 14),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isTamil
                            ? '• ${_result!.photosSaved} புகைப்படங்கள் member-photo/ கோப்புறையில் சேமிக்கப்பட்டது\n• ${_result!.proofsSaved} ஆவணச் சான்றுகள் member-proof/ கோப்புறையில் சேமிக்கப்பட்டது\n• ${_result!.pdfsSaved} உறுப்பினர் PDF-கள் member-details/ கோப்புறையில் சேமிக்கப்பட்டது'
                            : '• ${_result!.photosSaved} Photos saved directly in member-photo/\n• ${_result!.proofsSaved} Proof images saved in member-proof/\n• ${_result!.pdfsSaved} Member PDFs created in member-details/',
                        style: const TextStyle(fontSize: 12, height: 1.5, color: Color(0xFF2E7D32)),
                      ),
                      if (_result!.localDirectoryPath != null) ...[
                        const Divider(height: 16),
                        Text(
                          isTamil ? 'கோப்புறை பாதை (Folder Path):' : 'app-finance Folder Path:',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                        ),
                        SelectableText(
                          _result!.localDirectoryPath!,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0D47A1)),
                        ),
                      ],
                    ],
                  ),
                ),
              ],

              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade300),
                  ),
                  child: Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                ),
              ],

              const SizedBox(height: 18),

              // Action Buttons
              Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  TextButton(
                    onPressed: _isExporting ? null : () => Navigator.pop(context),
                    child: Text(isTamil ? 'மூடு (Close)' : 'Close'),
                  ),
                  if (!kIsWeb)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.folder_open, size: 17),
                      label: Text(isTamil ? 'கோப்புறை திற' : 'Open Folder'),
                      onPressed: () => AppFinanceFolderService.openAppFinanceFolder(),
                    ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D47A1),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: Icon(_result == null ? Icons.save : Icons.replay, size: 17),
                    label: Text(
                      _result == null
                          ? (isTamil ? 'சேமிக்க' : 'Save Folders')
                          : (isTamil ? 'மீண்டும் சேமி' : 'Save Again'),
                    ),
                    onPressed: _isExporting ? null : _startExport,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFolderRow({
    required IconData icon,
    required String folderName,
    required String descTamil,
    required String descEnglish,
    required Color color,
  }) {
    final isTamil = widget.repository.isTamil;
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            folderName,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: color),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            isTamil ? descTamil : descEnglish,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Future<void> _startExport() async {
    setState(() {
      _isExporting = true;
      _errorMessage = null;
      _progress = 0.0;
      _statusText = widget.repository.isTamil ? 'கோப்புறைகளில் சேமிக்கப்படுகிறது...' : 'Saving to app-finance folders...';
    });

    try {
      final res = await RecordsExportService.exportRecords(
        repository: widget.repository,
        lineFilter: _selectedLine,
        onProgress: (current, total, status) {
          if (mounted) {
            setState(() {
              _progress = total > 0 ? (current / total) : 0.0;
              _statusText = '$status ($current / $total)';
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _isExporting = false;
          _result = res;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isExporting = false;
          _errorMessage = e.toString();
        });
      }
    }
  }
}

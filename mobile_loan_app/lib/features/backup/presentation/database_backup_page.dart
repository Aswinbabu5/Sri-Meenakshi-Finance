import 'package:flutter/material.dart';
import '../../../../core/models/backup_model.dart';
import '../../../../core/services/backup_api_service.dart';
import '../../../../core/services/loan_repository.dart';

class DatabaseBackupPage extends StatefulWidget {
  final LoanRepository repository;
  final BackupApiService? apiService;

  const DatabaseBackupPage({super.key, required this.repository, this.apiService});

  @override
  State<DatabaseBackupPage> createState() => _DatabaseBackupPageState();
}

class _DatabaseBackupPageState extends State<DatabaseBackupPage> with SingleTickerProviderStateMixin {
  late final BackupApiService _apiService;
  late TabController _tabController;

  bool _isLoading = true;
  bool _isCreatingBackup = false;
  String? _errorMessage;

  BackupOverviewModel? _overview;
  List<BackupModel> _history = [];
  List<RestoreHistoryModel> _restoreHistory = [];

  @override
  void initState() {
    super.initState();
    _apiService = widget.apiService ?? BackupApiService();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _apiService.loadSavedBaseUrl();
      final overview = await _apiService.getOverview(widget.repository);
      final history = await _apiService.getHistory(widget.repository);
      final restoreHistory = await _apiService.getRestoreHistory(widget.repository);

      if (mounted) {
        setState(() {
          _overview = overview;
          _history = history;
          _restoreHistory = restoreHistory;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleCreateBackup() async {
    setState(() => _isCreatingBackup = true);

    try {
      final newBackup = await _apiService.createBackup(widget.repository);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF1B5E20),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.repository.isTamil
                        ? 'தரவுத்தள காப்பு வெற்றிகரமாக முடிந்தது! (${newBackup.formattedSize})'
                        : 'Database backup created & verified! (${newBackup.formattedSize})',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade800,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            content: Text(
              widget.repository.isTamil ? 'காப்பு தோல்வியடைந்தது: $e' : 'Backup creation failed: $e',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isCreatingBackup = false);
    }
  }

  Future<void> _handleRestore(BackupModel backup) async {
    final isTamil = widget.repository.isTamil;
    bool confirmChecked = false;
    final passwordController = TextEditingController(text: 'admin123');

    final shouldProceed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isTamil ? 'தரவு மீட்டெடுப்பு உறுதிப்படுத்தல்' : 'Confirm Database Restore',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.amber.shade300),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.security, color: Colors.amber.shade900, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isTamil
                            ? 'பாதுகாப்பு உத்தரவாதம்: மீட்டெடுக்கும் முன் தற்போதைய நேரடி தரவின் தானியங்கி காப்பு (Pre-Restore Snapshot) எடுக்கப்படும்.'
                            : 'Safety Guarantee: A safety snapshot of the live database will be created automatically before restoring.',
                          style: TextStyle(fontSize: 12.5, color: Colors.amber.shade900, height: 1.35),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  isTamil ? 'தேர்ந்தெடுக்கப்பட்ட காப்பு விவரங்கள்:' : 'Selected Backup Target:',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 6),
                Text('• ID: ${backup.backupId}', style: const TextStyle(fontSize: 12)),
                Text('• ${isTamil ? "தேதி" : "Date"}: ${backup.formattedDate}', style: const TextStyle(fontSize: 12)),
                Text('• ${isTamil ? "அளவு" : "Size"}: ${backup.formattedSize}', style: const TextStyle(fontSize: 12)),
                const SizedBox(height: 16),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: isTamil ? 'நிர்வாகி கடவுச்சொல் (Admin Password)' : 'Admin Password',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: confirmChecked,
                  onChanged: (val) {
                    setDialogState(() => confirmChecked = val ?? false);
                  },
                  title: Text(
                    isTamil
                        ? 'நான் புரிந்துகொண்டு இந்த காப்பிலிருந்து தரவை மீட்டெடுக்க உறுதி செய்கிறேன்.'
                        : 'I understand and confirm restoring database from this backup.',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(isTamil ? 'ரத்து செய்' : 'Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: confirmChecked
                  ? () => Navigator.pop(ctx, true)
                  : null,
              child: Text(isTamil ? 'மீட்டெடு (Restore)' : 'Restore Now'),
            ),
          ],
        ),
      ),
    );

    if (shouldProceed != true) return;

    // Show Progress
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        content: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                isTamil ? 'தரவுத்தளம் மீட்டெடுக்கப்படுகிறது...' : 'Restoring database from backup...',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                isTamil ? 'பாதுகாப்பு நகல் எடுக்கப்பட்டு சரிபார்க்கப்படுகிறது' : 'Creating safety snapshot & executing restore',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      final res = await _apiService.restoreBackup(
        widget.repository,
        backup.backupId,
        confirm: true,
        adminPassword: passwordController.text,
      );

      if (mounted) Navigator.pop(context); // Close progress dialog

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(isTamil ? 'மீட்டெடுப்பு வெற்றி' : 'Restore Successful'),
                ),
              ],
            ),
            content: Text(
              res['message'] ?? (isTamil ? 'தரவுத்தளம் வெற்றிகரமாக மீட்டெடுக்கப்பட்டது.' : 'Database restored successfully.'),
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _loadData();
                },
                child: Text(isTamil ? 'சரி' : 'OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); // Close progress dialog

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(isTamil ? 'மீட்டெடுப்பு தோல்வி' : 'Restore Failed'),
                ),
              ],
            ),
            content: Text(e.toString()),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(isTamil ? 'சரி' : 'OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  void _showBackupDetails(BackupModel backup) {
    final isTamil = widget.repository.isTamil;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8EAF6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.inventory_2_outlined, color: Color(0xFF1A237E), size: 26),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isTamil ? 'காப்பு விவரங்கள் (Backup Details)' : 'Backup Details',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Text(
                          backup.filename,
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(height: 24),
              _buildDetailRow(isTamil ? 'காப்பு ID (Backup ID)' : 'Backup ID', backup.backupId),
              _buildDetailRow(isTamil ? 'தேதி & நேரம் (Timestamp)' : 'Timestamp', backup.formattedDate),
              _buildDetailRow(isTamil ? 'கோப்பு அளவு (Size)' : 'Size', backup.formattedSize),
              _buildDetailRow(isTamil ? 'நிலை (Status)' : 'Status', backup.status),
              _buildDetailRow(isTamil ? 'சரிபார்ப்பு (Validation)' : 'Validation', backup.validationStatus),
              _buildDetailRow(isTamil ? 'குறியாக்க நிலை (Encryption)' : 'Encryption', backup.isEncrypted ? 'AES-256 Enabled' : 'None'),
              _buildDetailRow('SHA-256 Hash', backup.sha256Checksum, isMonospace: true),
              _buildDetailRow(isTamil ? 'சேமிப்பக இடம் (Storage)' : 'Storage Path', backup.storageLocation, isMonospace: true),
              _buildDetailRow(isTamil ? 'தூண்டுதல் (Trigger)' : 'Trigger Type', backup.triggerType),
              _buildDetailRow(isTamil ? 'உருவாக்கியவர் (Created By)' : 'Created By', backup.createdBy ?? 'System'),
              if (backup.errorMessage != null)
                _buildDetailRow(isTamil ? 'பிழை விவரம் (Error)' : 'Error Message', backup.errorMessage!, isError: true),
              const SizedBox(height: 20),
              if (widget.repository.isAdmin)
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _handleRestore(backup);
                        },
                        icon: const Icon(Icons.settings_backup_restore, size: 18),
                        label: Text(isTamil ? 'இந்த காப்பிலிருந்து மீட்டெடு' : 'Restore from this backup'),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isMonospace = false, bool isError = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          SelectableText(
            value,
            style: TextStyle(
              fontSize: 13,
              fontFamily: isMonospace ? 'Courier' : null,
              color: isError ? Colors.red.shade800 : const Color(0xFF263238),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _showServerSettingsDialog() {
    final controller = TextEditingController(text: _apiService.baseUrl);
    final isTamil = widget.repository.isTamil;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(isTamil ? 'சர்வர் இணைப்பு அமைப்புகள்' : 'Backend Server Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isTamil
                  ? 'Render / கிளவுட் சர்வரின் நேரடி HTTPS URL-ஐ உள்ளிடவும்:'
                  : 'Enter your live Render / Cloud HTTPS URL:',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: isTamil ? 'சர்வர் URL' : 'Server Base URL',
                hintText: 'https://sri-meenakshi-finance.onrender.com',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(isTamil ? 'ரத்து' : 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newUrl = controller.text.trim();
              if (newUrl.isNotEmpty) {
                await _apiService.saveBaseUrl(newUrl);
              }
              if (ctx.mounted) Navigator.pop(ctx);
              _loadData();
            },
            child: Text(isTamil ? 'சேமி' : 'Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isTamil = widget.repository.isTamil;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        title: Text(
          isTamil ? 'தரவுத்தள காப்பு & மீட்பு' : 'Database Backup & Recovery',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        actions: [
          IconButton(
            tooltip: isTamil ? 'சர்வர் அமைப்புகள்' : 'Server Settings',
            icon: const Icon(Icons.settings),
            onPressed: _showServerSettingsDialog,
          ),
          IconButton(
            tooltip: isTamil ? 'புதுப்பி' : 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFFFD54F),
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(text: isTamil ? 'காப்பு வரலாறு' : 'Backup History'),
            Tab(text: isTamil ? 'மீட்பு பதிவுகள்' : 'Recovery Logs'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorView()
              : Column(
                  children: [
                    // Top Overview Card
                    _buildOverviewCard(),
                    // Tab Content
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildBackupHistoryTab(),
                          _buildRestoreHistoryTab(),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildOverviewCard() {
    final isTamil = widget.repository.isTamil;
    final latest = _overview?.latestBackup;
    final isSuccess = latest?.isSuccess ?? false;

    return Container(
      margin: const EdgeInsets.all(14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0D47A1), Color(0xFF1976D2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.schedule, color: Color(0xFFFFD54F), size: 20),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isTamil ? 'தானியங்கி தினசரி காப்பு' : 'Automated Daily Backup',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _overview?.schedulerActive == true ? Colors.green.shade600 : Colors.grey.shade700,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.fiber_manual_record, size: 10, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(
                      _overview?.schedulerActive == true
                          ? (isTamil ? 'செயலில் உள்ளது' : 'ACTIVE')
                          : (isTamil ? 'முடங்கியுள்ளது' : 'DISABLED'),
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            isTamil ? 'தினமும் இரவு 11:59 மணிக்கு தானாகவே இயங்கும்.' : 'Scheduled automatically at 11:59 PM daily.',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const Divider(color: Colors.white24, height: 20),
          Row(
            children: [
              Expanded(
                child: _buildMetric(
                  label: isTamil ? 'கடைசி காப்பு' : 'Latest Backup',
                  value: latest != null ? latest.formattedDate : (isTamil ? 'இல்லை' : 'None'),
                  icon: isSuccess ? Icons.check_circle : Icons.help_outline,
                  color: isSuccess ? Colors.greenAccent : Colors.white70,
                ),
              ),
              Expanded(
                child: _buildMetric(
                  label: isTamil ? 'அளவு & சரிபார்ப்பு' : 'Size & Integrity',
                  value: latest != null ? '${latest.formattedSize} • ${latest.validationStatus}' : '-',
                  icon: Icons.verified_user,
                  color: const Color(0xFFFFD54F),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Action button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFD54F),
                foregroundColor: const Color(0xFF0D47A1),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 2,
              ),
              onPressed: _isCreatingBackup ? null : _handleCreateBackup,
              icon: _isCreatingBackup
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.backup, size: 20),
              label: Text(
                _isCreatingBackup
                    ? (isTamil ? 'காப்பு செய்யப்படுகிறது...' : 'Creating Backup...')
                    : (isTamil ? 'இப்போதே காப்பு செய் (Run Backup Now)' : 'Run Backup Now'),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetric({required String label, required String value, required IconData icon, required Color color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        const SizedBox(height: 3),
        Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                value,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBackupHistoryTab() {
    final isTamil = widget.repository.isTamil;

    if (_history.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              isTamil ? 'காப்பு பதிவுகள் எதுவும் இல்லை' : 'No backups found yet',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _handleCreateBackup,
              icon: const Icon(Icons.backup, size: 16),
              label: Text(isTamil ? 'முதல் காப்பை உருவாக்கு' : 'Create First Backup'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      itemCount: _history.length,
      itemBuilder: (context, index) {
        final item = _history[index];
        final isSuccess = item.isSuccess;

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 1.5,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Icon(
                            isSuccess ? Icons.cloud_done : Icons.error_outline,
                            color: isSuccess ? Colors.green.shade700 : Colors.red.shade700,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              item.formattedDate,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isSuccess ? Colors.green.shade50 : Colors.red.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isSuccess ? Colors.green.shade300 : Colors.red.shade300,
                        ),
                      ),
                      child: Text(
                        item.status.toUpperCase(),
                        style: TextStyle(
                          color: isSuccess ? Colors.green.shade800 : Colors.red.shade800,
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      '• ID: ${item.backupId}',
                      style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        item.triggerType == 'Scheduled'
                            ? (isTamil ? 'தானியங்கி (Daily 11:59 PM)' : 'Scheduled (Daily)')
                            : (isTamil ? 'கையேடு (Manual)' : 'Manual'),
                        style: TextStyle(color: Colors.blue.shade900, fontSize: 10.5, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Text(
                      '• ${item.formattedSize}',
                      style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          item.isVerified ? Icons.verified : Icons.warning_amber,
                          size: 14,
                          color: item.isVerified ? Colors.teal : Colors.orange,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          item.validationStatus,
                          style: TextStyle(
                            fontSize: 11,
                            color: item.isVerified ? Colors.teal.shade800 : Colors.orange.shade900,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const Divider(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => _showBackupDetails(item),
                      icon: const Icon(Icons.info_outline, size: 16),
                      label: Text(isTamil ? 'விவரங்கள்' : 'Details'),
                    ),
                    const SizedBox(width: 8),
                    if (widget.repository.isAdmin)
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade700,
                          foregroundColor: Colors.white,
                          visualDensity: VisualDensity.compact,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: isSuccess ? () => _handleRestore(item) : null,
                        icon: const Icon(Icons.restore, size: 16),
                        label: Text(isTamil ? 'மீட்டெடு' : 'Restore'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRestoreHistoryTab() {
    final isTamil = widget.repository.isTamil;

    if (_restoreHistory.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              isTamil ? 'மீட்டெடுப்பு பதிவுகள் எதுவும் இல்லை' : 'No restoration operations recorded yet',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      itemCount: _restoreHistory.length,
      itemBuilder: (context, index) {
        final item = _restoreHistory[index];
        final isSuccess = item.isSuccess;

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isSuccess ? Icons.check_circle : Icons.error,
                          color: isSuccess ? Colors.green.shade700 : Colors.red.shade700,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          item.formattedDate,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                    Text(
                      item.status.toUpperCase(),
                      style: TextStyle(
                        color: isSuccess ? Colors.green.shade800 : Colors.red.shade800,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text('• Target Backup ID: ${item.backupId}', style: const TextStyle(fontSize: 12)),
                if (item.preRestoreBackupId != null)
                  Text(
                    '• Safety Pre-Snapshot: ${item.preRestoreBackupId}',
                    style: TextStyle(fontSize: 11.5, color: Colors.blue.shade800, fontWeight: FontWeight.w600),
                  ),
                Text('• Restored By: ${item.restoredBy}', style: const TextStyle(fontSize: 12)),
                if (item.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '• Error: ${item.errorMessage}',
                      style: TextStyle(fontSize: 11.5, color: Colors.red.shade800),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildErrorView() {
    final isTamil = widget.repository.isTamil;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off, size: 56, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text(
              isTamil ? 'சர்வர் இணைப்பு தோல்வி' : 'Cannot Connect to Backend Server',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              isTamil
                  ? 'ASP.NET Core சர்வர் (${_apiService.baseUrl}) இயங்குகிறதா என்பதை உறுதிப்படுத்தவும்.'
                  : 'Ensure the ASP.NET Core backend server is running at ${_apiService.baseUrl}.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 20),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _showServerSettingsDialog,
                  icon: const Icon(Icons.settings, size: 16),
                  label: Text(isTamil ? 'அமைப்புகள்' : 'Server Settings'),
                ),
                ElevatedButton.icon(
                  onPressed: _loadData,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: Text(isTamil ? 'மீண்டும் முயற்சி' : 'Retry'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

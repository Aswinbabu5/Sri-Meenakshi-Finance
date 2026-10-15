import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_animations.dart';
import '../../../../core/services/loan_repository.dart';
import '../../../backup/presentation/database_backup_page.dart';
import 'line_and_year_dialogs.dart';

class CompanyHeader extends StatelessWidget {
  final LoanRepository repository;
  final bool compact;

  const CompanyHeader({
    super.key,
    required this.repository,
    this.compact = false,
  });

  void _showUserMenu(BuildContext context) {
    final isTamil = repository.isTamil;
    final user = repository.currentUser;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: Colors.amber.shade700,
                    child: const Icon(
                      Icons.admin_panel_settings,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.name ?? 'Admin',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Text(
                          '${isTamil ? "பங்கு (Role)" : "Role"}: ADMIN',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.amber.shade900,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 20),
              // Current Financial Year tile
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 18, color: Color(0xFF1565C0)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isTamil ? 'நிதியாண்டு (Financial Year)' : 'Financial Year',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                          Text(
                            'FY ${repository.selectedFinancialYear}',
                            style: TextStyle(fontSize: 11, color: Colors.blue.shade900),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _showYearSwitchDialog(context);
                      },
                      child: Text(isTamil ? 'மாற்று' : 'Switch'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // Line Management Tile
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                tileColor: Colors.purple.shade50,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: Colors.purple.shade200),
                ),
                leading: const Icon(Icons.alt_route, color: Color(0xFF6A1B9A)),
                title: Text(
                  isTamil ? 'லைன் மேலாண்மை (A, B, C, D...)' : 'Manage Collection Lines',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                subtitle: Text(
                  isTamil ? 'புதிய லைன் சேர்க்க அல்லது நீக்க' : 'Add new line or delete unwanted lines',
                  style: const TextStyle(fontSize: 11),
                ),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () {
                  Navigator.pop(ctx);
                  showLineManagementDialog(context, repository);
                },
              ),
              const SizedBox(height: 8),
              // Financial Year Management Tile
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                tileColor: Colors.amber.shade50,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: Colors.amber.shade200),
                ),
                leading: const Icon(Icons.calendar_month, color: Color(0xFFE65100)),
                title: Text(
                  isTamil ? 'நிதியாண்டு மேலாண்மை (+ Add Year)' : 'Manage Financial Years',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                subtitle: Text(
                  isTamil ? 'புதிய நிதியாண்டு சேர்க்க அல்லது நீக்க' : 'Add new financial year or delete',
                  style: const TextStyle(fontSize: 11),
                ),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () {
                  Navigator.pop(ctx);
                  showFinancialYearManagementDialog(context, repository);
                },
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                tileColor: Colors.blue.shade50,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: Colors.blue.shade200),
                ),
                leading: const Icon(Icons.cloud_sync, color: Color(0xFF0D47A1)),
                title: Text(
                  isTamil ? 'தரவுத்தள காப்பு & மீட்பு' : 'Database Backup & Recovery',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                subtitle: Text(
                  isTamil ? 'தானியங்கி தினசரி காப்பு & மீட்டெடுப்பு' : 'Automated Daily Backup & Restore',
                  style: const TextStyle(fontSize: 11),
                ),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => DatabaseBackupPage(repository: repository)),
                  );
                },
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  repository.logout();
                },
                icon: const Icon(Icons.logout, size: 18),
                label: Text(isTamil ? 'வெளியேறு (Logout)' : 'Logout'),
              ),
            ],
          ),
        ),
      ),
    );
  }



  void _showYearSwitchDialog(BuildContext context) {
    final isTamil = repository.isTamil;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final allFys = [...repository.availableFinancialYears, 'All'];

          return SafeArea(
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
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isTamil ? "நிதியாண்டு மாற்றம் (Switch FY)" : "Switch Financial Year",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Divider(height: 10),
                  ...allFys.asMap().entries.map((entry) {
                    final i = entry.key;
                    final fy = entry.value;
                    final isSelected = repository.selectedFinancialYear == fy;

                    return StaggeredEntrance(
                      index: i,
                      child: ListTile(
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        leading: Icon(
                          isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                          color: isSelected ? AppColors.primary : Colors.grey,
                          size: 20,
                        ),
                        title: Text(
                          fy == 'All' ? (isTamil ? 'அனைத்து ஆண்டுகள்' : 'All Years') : fy,
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                            fontSize: 14,
                            color: isSelected ? AppColors.primary : AppColors.textPrimary,
                          ),
                        ),
                        subtitle: Text(
                          fy == 'All'
                              ? (isTamil ? 'அனைத்து நிதியாண்டு பதிவுகள்' : 'All Financial Years')
                              : (fy == '2026-Present'
                                  ? (isTamil ? 'நடப்பு ஆண்டு (Active)' : 'Current Active FY')
                                  : (isTamil ? 'நிதியாண்டு $fy' : 'Financial Year $fy')),
                          style: TextStyle(
                            fontSize: 11,
                            color: isSelected ? AppColors.primary.withValues(alpha: 0.8) : Colors.grey.shade600,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.blue.shade50 : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: isSelected ? Colors.blue.shade200 : Colors.grey.shade200),
                              ),
                              child: Text(
                                "${repository.getLoans(financialYear: fy).length} ${isTamil ? 'கடன்கள்' : 'Loans'}",
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? AppColors.primary : Colors.grey.shade700,
                                ),
                              ),
                            ),
                            if (fy != 'All')
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                                tooltip: isTamil ? "நீக்கு" : "Delete Year",
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (c) => AlertDialog(
                                      title: Text(isTamil ? "நிதியாண்டை நீக்கவா?" : "Delete Financial Year?"),
                                      content: Text(
                                        isTamil
                                            ? "$fy நிதியாண்டை நீக்க விரும்புகிறீர்களா?"
                                            : "Are you sure you want to delete financial year $fy?",
                                      ),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(c, false), child: Text(isTamil ? "ரத்து" : "Cancel")),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                          onPressed: () => Navigator.pop(c, true),
                                          child: Text(isTamil ? "நீக்கு" : "Delete", style: const TextStyle(color: Colors.white)),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirm == true) {
                                    await repository.deleteFinancialYear(fy);
                                    setSheetState(() {});
                                  }
                                },
                              ),
                          ],
                        ),
                        onTap: () {
                          repository.selectFinancialYear(fy);
                          Navigator.pop(ctx);
                        },
                      ),
                    );
                  }),
                  const SizedBox(height: 12),
                  // Small buttons to Add New Year & Manage Lines
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFE65100),
                            side: BorderSide(color: Colors.amber.shade700),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          icon: const Icon(Icons.add, size: 16),
                          label: Text(
                            isTamil ? "+ புதிய ஆண்டு" : "+ Add Year",
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          onPressed: () async {
                            Navigator.pop(ctx);
                            await showFinancialYearManagementDialog(context, repository);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF0D47A1),
                            side: BorderSide(color: Colors.blue.shade700),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          icon: const Icon(Icons.alt_route, size: 16),
                          label: Text(
                            isTamil ? "லைன் நிர்வாகம்" : "Manage Lines",
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          onPressed: () async {
                            Navigator.pop(ctx);
                            await showLineManagementDialog(context, repository);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isTamil = repository.isTamil;
    final user = repository.currentUser;

    if (compact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        color: AppColors.primary,
        child: Row(
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.85, end: 1.0),
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutCubic,
              builder: (context, scale, child) => Transform.scale(
                scale: scale,
                child: child,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.asset(
                  'assets/images/app_icon.png',
                  width: 28,
                  height: 28,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const CircleAvatar(
                    radius: 14,
                    backgroundColor: AppColors.gold,
                    child: Icon(Icons.account_balance, color: AppColors.primary, size: 16),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  isTamil ? "ஸ்ரீ மீனாட்சி பைனான்ஸ்" : "Sri Meenakshi Finance",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            if (user != null) ...[
              AnimatedPressable(
                onTap: () => _showUserMenu(context),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.gold, width: 1.5),
                  ),
                  child: CircleAvatar(
                    radius: 14,
                    backgroundColor: user.isAdmin ? Colors.amber.shade800 : Colors.teal.shade700,
                    child: Text(
                      user.name.isNotEmpty ? user.name[0].toUpperCase() : (user.isAdmin ? 'A' : 'L'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF0D47A1),
            Color(0xFF1565C0),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Company Logo with smooth entrance
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.85, end: 1.0),
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
            builder: (context, scale, child) => Transform.scale(
              scale: scale,
              child: child,
            ),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.gold, width: 2),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 4),
                ],
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/images/app_icon.png',
                  width: 44,
                  height: 44,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const CircleAvatar(
                    radius: 22,
                    backgroundColor: AppColors.gold,
                    child: Icon(Icons.account_balance, color: AppColors.primary, size: 24),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          // Company Name
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                isTamil ? "ஸ்ரீ மீனாட்சி பைனான்ஸ்" : "Sri Meenakshi Finance",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: [Shadow(color: Colors.black45, blurRadius: 2)],
                ),
              ),
            ),
          ),
          // Logged In Logo (User Avatar)
          if (user != null) ...[
            AnimatedPressable(
              onTap: () => _showUserMenu(context),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.gold, width: 1.5),
                ),
                child: CircleAvatar(
                  radius: 17,
                  backgroundColor: user.isAdmin ? Colors.amber.shade800 : Colors.teal.shade700,
                  child: Text(
                    user.name.isNotEmpty ? user.name[0].toUpperCase() : (user.isAdmin ? 'A' : 'L'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

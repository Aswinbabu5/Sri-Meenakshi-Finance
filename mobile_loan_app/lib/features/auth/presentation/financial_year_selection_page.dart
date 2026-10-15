import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_animations.dart';
import '../../../../core/services/loan_repository.dart';

class FinancialYearSelectionPage extends StatefulWidget {
  final LoanRepository repository;
  final ValueChanged<String> onYearSelected;

  const FinancialYearSelectionPage({
    super.key,
    required this.repository,
    required this.onYearSelected,
  });

  @override
  State<FinancialYearSelectionPage> createState() => _FinancialYearSelectionPageState();
}

class _FinancialYearSelectionPageState extends State<FinancialYearSelectionPage> {
  String? _selectedYear;

  @override
  void initState() {
    super.initState();
    _selectedYear = widget.repository.selectedFinancialYear;
  }

  void _chooseYear(String year) {
    setState(() {
      _selectedYear = year;
    });
    widget.repository.selectFinancialYear(year);
    widget.onYearSelected(year);
  }

  @override
  Widget build(BuildContext context) {
    final repo = widget.repository;
    final isTamil = repo.isTamil;
    final user = repo.currentUser;

    final List<Map<String, dynamic>> yearsData = repo.availableFinancialYears.map<Map<String, dynamic>>((fy) {
      final isCurrent = fy == repo.selectedFinancialYear || fy.contains('Present');
      final parts = fy.split('-');
      final startYear = parts.isNotEmpty ? parts[0] : '';
      final endYear = parts.length > 1 ? parts[1] : '';
      final dateRange = parts.length > 1 && parts[1].toLowerCase().contains('present')
          ? '01-Apr-$startYear  to  Present'
          : '01-Apr-$startYear  to  31-Mar-$endYear';

      return <String, dynamic>{
        'year': fy,
        'display': fy.replaceAll('-', ' - '),
        'subTamil': isCurrent ? 'நடப்பு நிதியாண்டு (பரிந்துரை)' : 'நிதியாண்டு விவரங்கள்',
        'subEnglish': isCurrent ? 'Current Financial Year (Active)' : 'Financial Year Records',
        'dates': dateRange,
        'tag': isCurrent ? (isTamil ? 'நடப்பு ஆண்டு' : 'Current FY') : (isTamil ? 'நிதியாண்டு' : 'FY'),
        'color': isCurrent ? const Color(0xFF2E7D32) : const Color(0xFF1565C0),
        'icon': isCurrent ? Icons.update : Icons.today,
        'isCurrent': isCurrent,
      };
    }).toList();

    yearsData.add(<String, dynamic>{
      'year': 'All',
      'display': isTamil ? 'அனைத்து ஆண்டுகள்' : 'All Financial Years',
      'subTamil': 'அனைத்து நிதியாண்டு பதிவுகள் (முழு விவரம்)',
      'subEnglish': 'All Historical & Active Records',
      'dates': 'All Periods Combined',
      'tag': isTamil ? 'முழு பதிவுகள்' : 'All Records',
      'color': const Color(0xFFE65100),
      'icon': Icons.all_inclusive,
    });

    final displayedYears = yearsData;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F6FA),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Bar with User Info & Logout
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // User Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: user?.isAdmin == true ? Colors.amber.shade100 : Colors.teal.shade100,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: user?.isAdmin == true ? Colors.amber.shade700 : Colors.teal.shade700,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          user?.isAdmin == true ? Icons.admin_panel_settings : Icons.visibility,
                          size: 16,
                          color: user?.isAdmin == true ? Colors.amber.shade900 : Colors.teal.shade900,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          user?.name ?? (isTamil ? 'பயனர்' : 'User'),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: user?.isAdmin == true ? Colors.amber.shade900 : Colors.teal.shade900,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Language & Logout Buttons
                  Row(
                    children: [
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          backgroundColor: Colors.white,
                        ),
                        onPressed: () {
                          setState(() {
                            repo.toggleLanguage();
                          });
                        },
                        icon: const Icon(Icons.language, size: 16, color: AppColors.primary),
                        label: Text(
                          isTamil ? "English" : "தமிழ்",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primary),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: isTamil ? 'வெளியேறு (Logout)' : 'Logout',
                        icon: const Icon(Icons.logout, color: Colors.red),
                        onPressed: () {
                          repo.logout();
                        },
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Company Header Card
              StaggeredEntrance(
                delay: const Duration(milliseconds: 60),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0D47A1), Color(0xFF1976D2)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4)),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.gold, width: 2),
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/images/app_icon.png',
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => const CircleAvatar(
                              radius: 30,
                              backgroundColor: AppColors.gold,
                              child: Icon(Icons.account_balance, color: AppColors.primary, size: 32),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        isTamil ? "ஸ்ரீ மீனாட்சி பைனான்ஸ்" : "Sri Meenakshi Finance",
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.3,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isTamil ? "மதுரை • வசூல் பதிவேடு" : "Madurai • Daily Loan Register",
                        style: const TextStyle(fontSize: 12, color: AppColors.goldLight),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Title Section
              Text(
                isTamil ? "நிதியாண்டு தேர்வு" : "Select Financial Year",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                isTamil
                    ? "கணக்கு விவரங்களை பார்க்கவும் கையாளவும் விரும்பும் ஆண்டை தேர்ந்தெடுக்கவும்:"
                    : "Choose the financial year period to access ledger & dashboard:",
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              // Financial Year Cards
              ...displayedYears.asMap().entries.map((entry) {
                final i = entry.key;
                final data = entry.value;
                final yearCode = data['year'] as String;
                final isSelected = _selectedYear == yearCode;
                final color = data['color'] as Color;
                final isCur = data['isCurrent'] == true;

                // Query stats for this year
                final loansInYear = repo.getLoans(financialYear: yearCode);
                final totalBalanceInYear = loansInYear.fold<double>(0, (sum, l) => sum + l.balanceAmount);

                return StaggeredEntrance(
                  index: i,
                  child: HoverScaleCard(
                    margin: const EdgeInsets.only(bottom: 16),
                    onTap: () => _chooseYear(yearCode),
                    color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected ? color : Colors.grey.shade300,
                      width: isSelected ? 2.5 : 1,
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(data['icon'] as IconData, color: color, size: 24),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          data['display'] as String,
                                          style: TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.bold,
                                            color: color,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: isCur ? Colors.blue.shade50 : Colors.grey.shade100,
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: isCur ? Colors.blue.shade300 : Colors.grey.shade300),
                                        ),
                                        child: Text(
                                          data['tag'] as String,
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: isCur ? Colors.blue.shade800 : Colors.grey.shade700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    isTamil ? (data['subTamil'] as String) : (data['subEnglish'] as String),
                                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Divider(height: 1),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  const Icon(Icons.date_range, size: 13, color: Colors.grey),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      data['dates'] as String,
                                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    "${loansInYear.length} ${isTamil ? 'கடன்கள்' : 'Loans'} • ",
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
                                  ),
                                  AnimatedCountingNumber(
                                    value: totalBalanceInYear,
                                    isCurrency: true,
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: color,
                              foregroundColor: Colors.white,
                              elevation: isSelected ? 2 : 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            onPressed: () => _chooseYear(yearCode),
                            icon: const Icon(Icons.arrow_forward, size: 16),
                            label: Text(
                              isTamil ? "${data['display']} பார்க்க" : "Open ${data['display']}",
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),

              // Option to view All Years
              Center(
                child: TextButton.icon(
                  onPressed: () => _chooseYear('All'),
                  icon: const Icon(Icons.all_inclusive, size: 16),
                  label: Text(
                    isTamil ? "அனைத்து ஆண்டுகளையும் சேர்த்து பார்க்க" : "View All Years Combined",
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    ),
  ),
);
  }
}

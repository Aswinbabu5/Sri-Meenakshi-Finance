import 'package:flutter/material.dart';
import '../../../../app/theme/app_animations.dart';
import '../../../../core/services/loan_repository.dart';
import 'widgets/company_header.dart';
import '../../loans/presentation/loan_form_page.dart';
import '../../loans/presentation/balance_view_page.dart';
import '../../collections/presentation/daily_collection_page.dart';
import '../../collections/presentation/editing_page.dart';
import '../../reports/presentation/reports_page.dart';
import '../../loans/presentation/bond_search_page.dart';
import '../../loans/presentation/owner_capital_page.dart';
import '../../backup/presentation/database_backup_page.dart';

class DashboardPage extends StatefulWidget {
  final LoanRepository repository;

  const DashboardPage({super.key, required this.repository});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  @override
  void initState() {
    super.initState();
    widget.repository.addListener(_onRepoChanged);
  }

  @override
  void dispose() {
    widget.repository.removeListener(_onRepoChanged);
    super.dispose();
  }

  void _onRepoChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final repo = widget.repository;
    final isTamil = repo.isTamil;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F8),
      body: SafeArea(
        child: Column(
          children: [
            // Company Header Banner (Image 1 Header)
            CompanyHeader(repository: repo),

            // Main Menu Grid matching Image 1 & Image 4
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1440),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Responsive Grid of Action Buttons matching Drawing 4 & Drawing 1
                        // Adapts automatically from small mobile screens to desktop/computer
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final width = constraints.maxWidth;
                            final int crossAxisCount = width >= 1100 ? 5 : (width >= 860 ? 4 : (width >= 560 ? 3 : 2));
                            final double aspectRatio = width < 400 ? 1.12 : (width < 600 ? 1.25 : (width >= 860 ? 1.6 : 1.45));

                            final actionTiles = [
                              // 1: புதிய கடன் / New Loan Entry (Drawing 4 Card 1)
                              _buildActionTile(
                                titleTamil: "புதிய கடன்",
                                titleEnglish: "New Loan Entry",
                                icon: Icons.post_add,
                                color: const Color(0xFFFFD180),
                                textColor: const Color(0xFF4E342E),
                                borderColor: Colors.orange.shade400,
                                isHighlighted: true,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => LoanFormPage(repository: repo)),
                                ),
                              ),
                              // 2: பாக்கித் தொகை / Balance Amt. View (Drawing 4 Card 2)
                              _buildActionTile(
                                titleTamil: "பாக்கித் தொகை",
                                titleEnglish: "Balance Amt. View",
                                icon: Icons.query_builder,
                                color: const Color(0xFFFFD180), // Peach color
                                textColor: const Color(0xFF4E342E),
                                borderColor: Colors.orange.shade400,
                                isHighlighted: true,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => BalanceViewPage(repository: repo)),
                                ),
                              ),
                              // 3: தினசரி வசூல் - கைசிட்டை (Drawing 4 Card 3)
                              _buildActionTile(
                                titleTamil: "தினசரி வசூல்",
                                subtitleTamil: "( கைசிட்டை )",
                                titleEnglish: "Daily Collection Chit",
                                icon: Icons.receipt,
                                color: const Color(0xFFE0F7FA),
                                textColor: const Color(0xFF004D40),
                                borderColor: Colors.teal.shade300,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => DailyCollectionPage(repository: repo, receiptType: 'Chit'),
                                  ),
                                ),
                              ),
                              // 4: தவணை எண் ? / Find Bond No. (Drawing 4 Card 4 -> Drawing 2 Bond NO page)
                              _buildActionTile(
                                titleTamil: "தவணை எண் ? (Bond)",
                                titleEnglish: "Find Bond No. ?",
                                icon: Icons.search,
                                color: const Color(0xFFE0F7FA),
                                textColor: const Color(0xFF004D40),
                                borderColor: Colors.teal.shade300,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => BondSearchPage(repository: repo)),
                                ),
                              ),
                              // 5: பிழை திருத்தம் - Editing (Drawing 4 Card 5 -> Drawing 2 Editing page)
                              _buildActionTile(
                                titleTamil: "பிழை திருத்தம்",
                                subtitleTamil: "- Editing",
                                titleEnglish: "Corrections & Editing",
                                icon: Icons.edit_note,
                                color: const Color(0xFFC8E6C9), // Light green
                                textColor: const Color(0xFF1B5E20),
                                borderColor: Colors.green.shade400,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => EditingPage(repository: repo)),
                                ),
                              ),
                              // 6: பதிவேடு அறிக்கை / Register Reports (Password Protected)
                              _buildActionTile(
                                titleTamil: "பதிவேடு அறிக்கை",
                                subtitleTamil: "( Register Reports )",
                                titleEnglish: "Register Reports",
                                icon: Icons.description,
                                color: const Color(0xFFFFF9C4),
                                textColor: const Color(0xFFF57F17),
                                borderColor: Colors.amber.shade400,
                                isHighlighted: true,
                                onTap: () => _promptRegisterReportPassword(context, repo),
                              ),
                              // 8: பேரேடு - Ledger (31-day matrix & registers)
                              _buildActionTile(
                                titleTamil: "பேரேடு",
                                subtitleTamil: "( Ledger )",
                                titleEnglish: "Ledger",
                                icon: Icons.menu_book,
                                color: const Color(0xFFE0F7FA),
                                textColor: const Color(0xFF004D40),
                                borderColor: Colors.teal.shade300,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => ReportsPage(repository: repo)),
                                ),
                              ),
                              // 9: தரவுத்தள காப்பு & மீட்பு / Database Backup & Recovery
                              _buildActionTile(
                                titleTamil: "தரவுத்தள காப்பு",
                                subtitleTamil: "& மீட்பு (Backup)",
                                titleEnglish: "Database Backup",
                                icon: Icons.cloud_sync,
                                color: const Color(0xFFE8EAF6),
                                textColor: const Color(0xFF1A237E),
                                borderColor: Colors.indigo.shade300,
                                isHighlighted: true,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => DatabaseBackupPage(repository: repo)),
                                ),
                              ),
                            ];

                            return GridView.count(
                              crossAxisCount: crossAxisCount,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              childAspectRatio: aspectRatio,
                              children: [
                                for (int i = 0; i < actionTiles.length; i++)
                                  StaggeredEntrance(
                                    index: i,
                                    child: actionTiles[i],
                                  ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 20),

                        // Center Brand Footer with gentle entrance
                        StaggeredEntrance(
                          delay: const Duration(milliseconds: 320),
                          offset: const Offset(0, 12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Column(
                              children: [
                                Text(
                                  isTamil
                                      ? "Aven schmith"
                                      : "Aven schmith",
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.blue.shade900,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  isTamil
                                      ? "தினசரி கடன் மேலாண்மை மற்றும் வசூல் பதிவேடு"
                                      : "Daily Loan & Collection Management System",
                                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                                ),
                              ],
                            ),
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
      ),
    );
  }

  Widget _buildActionTile({
    required String titleTamil,
    String? subtitleTamil,
    required String titleEnglish,
    required IconData icon,
    required Color color,
    required Color textColor,
    required Color borderColor,
    bool isHighlighted = false,
    required VoidCallback onTap,
  }) {
    return HoverScaleCard(
      onTap: onTap,
      color: color,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(
        color: borderColor,
        width: isHighlighted ? 1.8 : 1.2,
      ),
      hoverScale: 1.025,
      pressScale: 0.975,
      hoverElevation: 5.0,
      elevation: 1.2,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: textColor, size: 22),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              titleTamil,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.bold,
                fontSize: 12.5,
              ),
            ),
          ),
          if (subtitleTamil != null) ...[
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                subtitleTamil,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 10.5,
                ),
              ),
            ),
          ],
          const SizedBox(height: 1),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              titleEnglish,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: textColor.withValues(alpha: 0.75),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _promptRegisterReportPassword(BuildContext context, LoanRepository repo) {
    final isTamil = repo.isTamil;
    final passwordController = TextEditingController();
    String? errorText;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            void submitPassword() {
              const staticPassword = '@ADsmf1';
              if (passwordController.text.trim() == staticPassword) {
                Navigator.pop(dialogCtx);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => OwnerCapitalPage(repository: repo)),
                );
              } else {
                setDialogState(() {
                  errorText = isTamil ? "தவறான கடவுச்சொல்! அணுகல் மறுக்கப்பட்டது." : "Incorrect password! Access denied.";
                });
              }
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.lock, color: Color(0xFFF57F17)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isTamil ? "பதிவேடு அறிக்கை கடவுச்சொல்" : "Register Reports Password",
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                        ? "பதிவேடு அறிக்கையை அணுக நிர்வாக கடவுச்சொல்லை உள்ளிடவும்:"
                        : "Enter Admin Password to access Register Reports:",
                    style: const TextStyle(fontSize: 12.5, color: Colors.black87),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: isTamil ? "நிர்வாக கடவுச்சொல்" : "Admin Password",
                      prefixIcon: const Icon(Icons.key, color: Color(0xFFF57F17)),
                      errorText: errorText,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onSubmitted: (_) => submitPassword(),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: Text(isTamil ? "ரத்து" : "Cancel"),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF57F17),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: submitPassword,
                  child: Text(isTamil ? "உள்நுழை" : "Access"),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

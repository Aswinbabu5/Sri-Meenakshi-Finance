import '../../../../core/utils/safe_image_provider.dart';
import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_animations.dart';
import '../../../../core/models/loan_model.dart';
import '../../../../core/services/loan_repository.dart';
import '../../dashboard/presentation/widgets/company_header.dart';

class BondSearchPage extends StatefulWidget {
  final LoanRepository repository;
  final String? initialQuery;

  const BondSearchPage({
    super.key,
    required this.repository,
    this.initialQuery,
  });

  @override
  State<BondSearchPage> createState() => _BondSearchPageState();
}

class _BondSearchPageState extends State<BondSearchPage> {
  late TextEditingController _searchController;
  String _lineFilter = 'All';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialQuery ?? '');
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isTamil = widget.repository.isTamil;
    final query = _searchController.text.trim();
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallPhone = screenWidth < 360;

    var loans = widget.repository.getLoans(
      lineCode: _lineFilter,
      search: query,
    ).where((l) => l.balanceAmount > 0).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F8),
      appBar: AppBar(
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            isTamil ? "தவணை எண் தேடல்" : "Bond Search",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
          ),
        ),
        backgroundColor: const Color(0xFF1565C0),
        elevation: 1,
      ),
      body: SafeArea(
        child: Column(
          children: [
            CompanyHeader(repository: widget.repository, compact: true),

            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1440),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
                  child: Column(
                    children: [
                      // Search Bar (Drawing 2: "Search")
                      TextField(
                        controller: _searchController,
                        autofocus: widget.initialQuery == null,
                        decoration: InputDecoration(
                          hintText: isTamil ? "தவணை எண் தேடுக (எ.கா: A001, 001)..." : "Search Bond No (e.g. A001, 001)...",
                          labelText: isTamil ? "Bond Search" : "Bond Search",
                          prefixIcon: const Icon(Icons.search, color: AppColors.primary),
                          suffixIcon: query.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {});
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 8),

                      // Filter Chips: Line & Status
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            // Line Filters
                            ...['All', 'A', 'B', 'C', 'D'].map((line) {
                              final isSel = _lineFilter == line;
                              return Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: ChoiceChip(
                                  label: Text(line == 'All' ? (isTamil ? 'அனைத்து' : 'All Lines') : 'Line $line'),
                                  selected: isSel,
                                  onSelected: (selected) {
                                    if (selected) setState(() => _lineFilter = line);
                                  },
                                  selectedColor: AppColors.primary,
                                  labelStyle: TextStyle(
                                    color: isSel ? Colors.white : Colors.black87,
                                    fontSize: 11.5,
                                    fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                                  ),
                                  visualDensity: VisualDensity.compact,
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Divider(height: 1),

            // Pending list / Loans List (Drawing 2: "pending list")
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1440),
                  child: loans.isEmpty
                      ? AnimatedEmptyState(
                          icon: Icons.search_off,
                          title: isTamil
                              ? "தவணை எண்கள் எதுவும் கிடைக்கவில்லை"
                              : "No bonds found",
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: loans.length,
                          itemBuilder: (context, i) {
                            final loan = loans[i];
                            return StaggeredEntrance(
                              index: i < 10 ? i : 0,
                              child: _buildBondCard(loan, isTamil, isSmallPhone),
                            );
                          },
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBondCard(LoanModel loan, bool isTamil, bool isSmallPhone) {
    return HoverScaleCard(
      margin: const EdgeInsets.only(bottom: 10),
      borderRadius: BorderRadius.circular(12),
      elevation: 2,
      hoverElevation: 5,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                // Member photo or bond tag
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0D47A1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              loan.bondNumber,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              loan.customerName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: loan.balanceAmount > 0 ? Colors.red.shade50 : Colors.green.shade50,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: loan.balanceAmount > 0 ? Colors.red.shade200 : Colors.green.shade200),
                            ),
                            child: Text(
                              loan.balanceAmount > 0 ? (isTamil ? 'பாக்கி' : 'PENDING') : (isTamil ? 'முடிவு' : 'CLOSED'),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: loan.balanceAmount > 0 ? Colors.red.shade800 : Colors.green.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        "${loan.phoneNumber} • Line ${loan.lineCode} • ${isTamil ? 'தவணை' : 'Due'}: ₹${loan.dailyDueAmount.toStringAsFixed(0)}/நாள்",
                        style: const TextStyle(fontSize: 11.5, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 16),
            // Financial stats row with smooth counting numbers
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStat(isTamil ? "கடன் தொகை" : "Loan Amt", loan.loanAmount),
                _buildStat(isTamil ? "மொத்தம்" : "Total", loan.totalAmount),
                _buildStat(isTamil ? "வசூலானது" : "Collected", loan.collectedAmount, color: AppColors.success),
                _buildStat(isTamil ? "மீதி பாக்கி" : "Pending Bal", loan.balanceAmount, color: AppColors.error, isBold: true),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(String label, double value, {Color? color, bool isBold = false}) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.black54)),
        const SizedBox(height: 1),
        AnimatedCountingNumber(
          value: value,
          prefix: "₹",
          style: TextStyle(
            fontSize: 12,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: color ?? Colors.black87,
          ),
        ),
      ],
    );
  }
}

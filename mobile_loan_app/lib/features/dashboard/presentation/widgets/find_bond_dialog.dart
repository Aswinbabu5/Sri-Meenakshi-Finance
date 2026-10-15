import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_animations.dart';
import '../../../../core/models/loan_model.dart';
import '../../../../core/services/loan_repository.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../collections/presentation/daily_collection_page.dart';

class FindBondDialog extends StatefulWidget {
  final LoanRepository repository;

  const FindBondDialog({super.key, required this.repository});

  @override
  State<FindBondDialog> createState() => _FindBondDialogState();
}

class _FindBondDialogState extends State<FindBondDialog> {
  final TextEditingController _searchController = TextEditingController();
  LoanModel? _foundLoan;
  bool _searched = false;

  void _performSearch() {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    final loan = widget.repository.getLoanByBond(query);
    setState(() {
      _foundLoan = loan;
      _searched = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isTamil = widget.repository.isTamil;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.search, color: AppColors.primary, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isTamil ? "தவணை எண் தேடல்" : "Find Bond Number",
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                )
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    autofocus: true,
                    keyboardType: TextInputType.text,
                    decoration: InputDecoration(
                      hintText: isTamil ? "எ.கா. A001 அல்லது 001" : "e.g. A001 or 001",
                      labelText: isTamil ? "தவணை எண் (Bond No)" : "Bond Number",
                      prefixIcon: const Icon(Icons.tag),
                    ),
                    onSubmitted: (_) => _performSearch(),
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedPressable(
                  onTap: _performSearch,
                  child: ElevatedButton(
                    onPressed: _performSearch,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    child: Text(isTamil ? "தேடு" : "Search"),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: _foundLoan != null
                  ? StaggeredEntrance(
                      key: ValueKey('found_${_foundLoan!.bondNumber}'),
                      index: 0,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          HoverScaleCard(
                            hoverScale: 1.015,
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.green.shade200),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        "${isTamil ? 'தவணை எண்' : 'Bond'}: ${_foundLoan!.bondNumber}",
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: _foundLoan!.status == 'active' ? Colors.green : Colors.grey,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          _foundLoan!.status.toUpperCase(),
                                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    "${isTamil ? 'பெயர்' : 'Name'}: ${_foundLoan!.customerName}",
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                  ),
                                  if (_foundLoan!.fatherOrSpouseName != null)
                                    Text(
                                      "${isTamil ? 'த/பெ' : 'S/o'}: ${_foundLoan!.fatherOrSpouseName}",
                                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                    ),
                                  const Divider(height: 16),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      _buildStat(isTamil ? "கடன் தொகை" : "Loan Amt", CurrencyUtils.format(_foundLoan!.loanAmount)),
                                      _buildStat(isTamil ? "தவணை" : "Daily Due", CurrencyUtils.format(_foundLoan!.dailyDueAmount)),
                                      _buildStat(
                                        isTamil ? "பாக்கித் தொகை" : "Balance",
                                        CurrencyUtils.format(_foundLoan!.balanceAmount),
                                        numValue: _foundLoan!.balanceAmount,
                                        isHighlighted: true,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    "${isTamil ? 'ஆரம்ப தேதி' : 'Start Date'}: ${AppDateUtils.format(_foundLoan!.startDate)}",
                                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          AnimatedPressable(
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => DailyCollectionPage(
                                    repository: widget.repository,
                                    initialBondNumber: _foundLoan!.bondNumber,
                                  ),
                                ),
                              );
                            },
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => DailyCollectionPage(
                                      repository: widget.repository,
                                      initialBondNumber: _foundLoan!.bondNumber,
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.payments),
                              label: Text(isTamil ? "தினசரி வசூல் செய்ய (Collect)" : "Record Collection"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.success,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : _searched
                      ? StaggeredEntrance(
                          key: const ValueKey('not_found'),
                          index: 0,
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Center(
                              child: Text(
                                isTamil
                                    ? "தவணை எண் காணப்படவில்லை.\nசரியான எண்ணை உள்ளிடவும்."
                                    : "Bond Number not found.\nPlease check and try again.",
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ),
                        )
                      : const SizedBox.shrink(key: ValueKey('empty')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(String label, String value, {num? numValue, bool isHighlighted = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        numValue != null
            ? AnimatedCountingNumber(
                value: numValue,
                isCurrency: true,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isHighlighted ? AppColors.error : AppColors.textPrimary,
                ),
              )
            : Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isHighlighted ? AppColors.error : AppColors.textPrimary,
                ),
              ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/services/loan_repository.dart';

/// Small, user-friendly dialog for manually adding and deleting Financial Years
Future<void> showFinancialYearManagementDialog(
  BuildContext context,
  LoanRepository repository,
) async {
  final isTamil = repository.isTamil;
  final textController = TextEditingController();

  await showDialog(
    context: context,
    builder: (dialogCtx) {
      return StatefulBuilder(
        builder: (context, setState) {
          final years = repository.availableFinancialYears;

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
                  child: const Icon(Icons.calendar_today, color: Color(0xFFE65100), size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isTamil ? "நிதியாண்டு மேலாண்மை" : "Manage Financial Years",
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 380,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      isTamil
                        ? "தற்போதைய நிதியாண்டுகள் (தேவைப்படாததை நீக்கலாம்):"
                        : "Current Financial Years (delete unwanted):",
                      style: const TextStyle(fontSize: 12, color: Colors.black87, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 200),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: years.length,
                        separatorBuilder: (ctx, i) => const Divider(height: 1),
                        itemBuilder: (ctx, i) {
                          final fy = years[i];
                          final isCurrent = repository.selectedFinancialYear == fy;

                          return ListTile(
                            dense: true,
                            visualDensity: VisualDensity.compact,
                            leading: Icon(
                              isCurrent ? Icons.check_circle : Icons.circle_outlined,
                              color: isCurrent ? AppColors.primary : Colors.grey,
                              size: 18,
                            ),
                            title: Text(
                              fy,
                              style: TextStyle(
                                fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                                fontSize: 13,
                              ),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                              tooltip: isTamil ? "நீக்கு" : "Delete",
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
                                  setState(() {});
                                }
                              },
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      isTamil ? "புதிய நிதியாண்டு சேர்க்க:" : "Add New Financial Year:",
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: textController,
                            decoration: InputDecoration(
                              hintText: "e.g. 2026-2027",
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1565C0),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          icon: const Icon(Icons.add, size: 16),
                          label: Text(isTamil ? "சேர்" : "Add"),
                          onPressed: () async {
                            final val = textController.text.trim();
                            if (val.isNotEmpty) {
                              await repository.addFinancialYear(val);
                              textController.clear();
                              setState(() {});
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: Text(isTamil ? "முடிந்தது" : "Done"),
              ),
            ],
          );
        },
      );
    },
  );
  textController.dispose();
}

/// Small, user-friendly dialog for manually adding and deleting Lines (A, B, C, D, E...)
Future<void> showLineManagementDialog(
  BuildContext context,
  LoanRepository repository,
) async {
  final isTamil = repository.isTamil;
  final codeController = TextEditingController();
  final nameController = TextEditingController();

  await showDialog(
    context: context,
    builder: (dialogCtx) {
      return StatefulBuilder(
        builder: (context, setState) {
          final lines = repository.availableLines;

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.alt_route, color: Color(0xFF0D47A1), size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isTamil ? "லைன் மேலாண்மை" : "Manage Collection Lines",
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 380,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      isTamil
                        ? "தற்போதைய லைன்கள் (தேவைப்படாததை நீக்கலாம்):"
                        : "Current Lines (delete unwanted):",
                      style: const TextStyle(fontSize: 12, color: Colors.black87, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 200),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: lines.length,
                        separatorBuilder: (ctx, i) => const Divider(height: 1),
                        itemBuilder: (ctx, i) {
                          final line = lines[i];
                          final isCurrent = repository.selectedLine.toUpperCase() == line.toUpperCase();

                          return ListTile(
                            dense: true,
                            visualDensity: VisualDensity.compact,
                            leading: CircleAvatar(
                              radius: 12,
                              backgroundColor: isCurrent ? AppColors.primary : Colors.grey.shade300,
                              child: Text(
                                line,
                                style: TextStyle(
                                  color: isCurrent ? Colors.white : Colors.black87,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(
                              "Line $line",
                              style: TextStyle(
                                fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                                fontSize: 13,
                              ),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                              tooltip: isTamil ? "நீக்கு" : "Delete",
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (c) => AlertDialog(
                                    title: Text(isTamil ? "லைனை நீக்கவா?" : "Delete Line?"),
                                    content: Text(
                                      isTamil
                                        ? "Line $line -ஐ நீக்க விரும்புகிறீர்களா?"
                                        : "Are you sure you want to delete Line $line?",
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
                                  await repository.deleteLine(line);
                                  setState(() {});
                                }
                              },
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      isTamil ? "புதிய லைன் சேர்க்க:" : "Add New Line:",
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        SizedBox(
                          width: 80,
                          child: TextField(
                            controller: codeController,
                            textCapitalization: TextCapitalization.characters,
                            decoration: InputDecoration(
                              hintText: "e.g. E",
                              labelText: isTamil ? "வரிசை" : "Code",
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: nameController,
                            decoration: InputDecoration(
                              hintText: isTamil ? "பெயர் (விருப்பம்)" : "Name (Optional)",
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2E7D32),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          ),
                          icon: const Icon(Icons.add, size: 16),
                          label: Text(isTamil ? "சேர்" : "Add"),
                          onPressed: () async {
                            final code = codeController.text.trim();
                            if (code.isNotEmpty) {
                              await repository.addLine(code, nameController.text.trim());
                              codeController.clear();
                              nameController.clear();
                              setState(() {});
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: Text(isTamil ? "முடிந்தது" : "Done"),
              ),
            ],
          );
        },
      );
    },
  );
  codeController.dispose();
  nameController.dispose();
}

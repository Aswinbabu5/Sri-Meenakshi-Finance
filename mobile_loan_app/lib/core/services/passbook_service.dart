import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../models/loan_model.dart';
import '../models/collection_model.dart';
import '../utils/file_download_helper.dart';
import '../utils/safe_image_provider.dart';

class PassbookService {
  /// Generates the HTML Passbook content matching the exact finance passbook format:
  /// Header with only ID, Name, Photo, Acc; Addl Date indicator; Sl. No., Date, CollAmt, BAMT columns;
  /// Month subtotals with continuation of serial numbers; Bottom double-underlined Grand Total.
  static String generatePassbookHtml({
    required LoanModel loan,
    required List<CollectionModel> ledger,
    required bool isTamil,
  }) {
    // Process Member Photo to Base64 data URI
    String photoHtml = '';
    final photoUri = getPhotoBase64OrUri(loan.photoPath);
    if (photoUri != null && photoUri.isNotEmpty) {
      photoHtml = '<img src="$photoUri" alt="Customer Photo" style="width: 75px; height: 85px; object-fit: cover; border-radius: 4px; border: 1.5px solid #1A365D;" />';
    }
    if (photoHtml.isEmpty) {
      photoHtml = '<div style="width: 75px; height: 85px; border: 1.5px dashed #90CAF9; border-radius: 4px; display: flex; align-items: center; justify-content: center; font-size: 28px; color: #1A365D; background: #F8FAFC;">👤</div>';
    }

    final cusId = loan.customer?.cusCode ?? (loan.customerId > 0 ? "CUS-${loan.customerId}" : "ID-${loan.id}");

    // Sort chronologically ascending
    final sortedLedger = List<CollectionModel>.from(ledger)
      ..sort((a, b) => a.collectionDate.compareTo(b.collectionDate));

    final totalPrincipal = loan.totalAmount > 0 ? loan.totalAmount : (loan.loanAmount > 0 ? loan.loanAmount : loan.balanceAmount);
    double runningBal = totalPrincipal;
    int currentSlNo = 1;
    double grandTotalColl = 0.0;
    final StringBuffer tableRowsHtml = StringBuffer();

    // Opening balance row
    final openDateStr = DateFormat('dd/MM/yy').format(loan.startDate);
    final openBamtStr = NumberFormat('#,##0.00').format(totalPrincipal);
    tableRowsHtml.write('''
      <tr class="entry-row opening-row" style="background-color: #F8FAFC; font-weight: bold;">
        <td class="col-sl">0</td>
        <td class="col-date">$openDateStr</td>
        <td class="col-collamt" style="color: #64748B; font-size: 11px;">${isTamil ? "ஆரம்ப கடன்" : "Principal"}</td>
        <td class="col-bamt" style="color: #0D47A1;">$openBamtStr</td>
      </tr>
    ''');

    if (sortedLedger.isEmpty) {
      tableRowsHtml.write('''
        <tr>
          <td colspan="4" style="text-align: center; padding: 24px; color: #64748B; font-style: italic;">
            ${isTamil ? "வசூல் பதிவுகள் இல்லை (No receipts recorded yet)" : "No collection records yet"}
          </td>
        </tr>
      ''');
    } else {
      int i = 0;
      while (i < sortedLedger.length) {
        final firstOfGroup = sortedLedger[i];
        final monthKey = "${firstOfGroup.collectionDate.month.toString().padLeft(2, '0')}/${firstOfGroup.collectionDate.year}";
        double monthTotal = 0.0;

        while (i < sortedLedger.length) {
          final col = sortedLedger[i];
          final colMonthKey = "${col.collectionDate.month.toString().padLeft(2, '0')}/${col.collectionDate.year}";
          if (colMonthKey != monthKey) break;

          runningBal -= col.amount;
          monthTotal += col.amount;
          grandTotalColl += col.amount;

          final dateStr = DateFormat('dd/MM/yy').format(col.collectionDate);
          final collAmtStr = NumberFormat('#,##0').format(col.amount);
          final bamtStr = NumberFormat('#,##0.00').format(runningBal);

          tableRowsHtml.write('''
            <tr class="entry-row">
              <td class="col-sl">$currentSlNo</td>
              <td class="col-date">$dateStr</td>
              <td class="col-collamt">$collAmtStr</td>
              <td class="col-bamt">$bamtStr</td>
            </tr>
          ''');

          currentSlNo++;
          i++;
        }

        // Month subtotal row
        final monthTotalStr = NumberFormat('#,##0.00').format(monthTotal);
        tableRowsHtml.write('''
          <tr class="month-subtotal-row">
            <td class="col-sl"></td>
            <td class="col-date month-label">$monthKey</td>
            <td class="col-collamt month-amt"><u>$monthTotalStr</u></td>
            <td class="col-bamt"></td>
          </tr>
        ''');
      }

      // Grand total row
      final grandTotalStr = NumberFormat('#,##0.00').format(grandTotalColl);
      tableRowsHtml.write('''
        <tr class="grand-total-row">
          <td class="col-sl"></td>
          <td class="col-date"></td>
          <td class="col-collamt grand-amt"><span class="double-underline">$grandTotalStr</span></td>
          <td class="col-bamt"></td>
        </tr>
      ''');
    }

    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Passbook - ${loan.bondNumber}</title>
  <style>
    body {
      font-family: 'Courier New', Courier, -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
      margin: 20px;
      color: #1A365D;
      background: #fff;
    }
    .passbook-container {
      max-width: 680px;
      margin: 0 auto;
      background: #FFFFFF;
      padding: 16px 20px;
    }
    .brand-header {
      text-align: center;
      margin-bottom: 16px;
      padding: 12px 16px;
      border: 1px solid #CBD5E1;
      border-radius: 6px;
      background: #FFFFFF;
      border-top: 3.5px solid #0D47A1;
    }
    .brand-title {
      font-size: 21px;
      font-weight: 800;
      color: #0D47A1;
      letter-spacing: 0.5px;
      margin-bottom: 2px;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
    }
    .brand-subtitle {
      font-size: 13.5px;
      font-weight: 700;
      color: #1A365D;
      letter-spacing: 0.8px;
      margin-bottom: 5px;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
    }
    .brand-tag {
      display: inline-block;
      padding: 2px 12px;
      background: #E3F2FD;
      color: #0D47A1;
      font-size: 11px;
      font-weight: bold;
      border-radius: 4px;
      border: 1px solid #90CAF9;
      letter-spacing: 0.5px;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
    }
    .customer-header-card {
      display: flex;
      align-items: center;
      gap: 16px;
      border: 1px solid #CBD5E1;
      border-radius: 6px;
      padding: 12px 16px;
      margin-bottom: 16px;
      background: #F8FAFC;
    }
    .photo-box {
      flex-shrink: 0;
    }
    .details-box {
      flex-grow: 1;
      font-size: 14.5px;
      font-weight: 600;
      line-height: 1.6;
      color: #0F172A;
    }
    .details-box .field-row {
      display: flex;
      margin: 2px 0;
    }
    .details-box .field-label {
      width: 70px;
      color: #475569;
      font-weight: bold;
    }
    .details-box .field-val {
      font-weight: bold;
      color: #0F172A;
    }
    .addl-line {
      font-size: 14px;
      font-weight: bold;
      color: #1A365D;
      padding-bottom: 4px;
      margin-top: 14px;
    }
    .passbook-table {
      width: 100%;
      border-collapse: collapse;
      margin-top: 2px;
      font-size: 13.5px;
      color: #1A365D;
    }
    .passbook-table th {
      padding: 6px 10px;
      text-align: left;
      font-weight: bold;
      font-size: 14px;
      border-top: 1.2px solid #1A365D;
      border-bottom: 1.2px solid #1A365D;
    }
    .passbook-table th.col-collamt, .passbook-table th.col-bamt {
      text-align: right;
    }
    .passbook-table td {
      padding: 5px 10px;
      border-bottom: 0.8px solid #94A3B8;
    }
    .col-sl {
      width: 65px;
      text-align: left;
      font-weight: bold;
    }
    .col-date {
      width: 110px;
      text-align: left;
      font-weight: bold;
    }
    .col-collamt {
      width: 130px;
      text-align: right;
      font-weight: bold;
    }
    .col-bamt {
      width: 150px;
      text-align: right;
      font-weight: bold;
    }
    .month-subtotal-row td {
      border-top: 1.2px solid #1A365D;
      border-bottom: 1.2px solid #1A365D;
      padding: 6px 10px;
    }
    .month-label {
      color: #00796B;
      font-weight: bold;
      font-size: 14px;
    }
    .month-amt {
      color: #00796B;
      font-weight: bold;
      font-size: 14px;
    }
    .grand-total-row td {
      border-bottom: none;
      padding-top: 10px;
    }
    .grand-amt {
      font-size: 15px;
      font-weight: bold;
      color: #1A365D;
    }
    .double-underline {
      border-bottom: 3px double #1A365D;
      padding-bottom: 2px;
      display: inline-block;
    }
    @media print {
      body { margin: 0; }
      .passbook-container { border: none; padding: 10px; }
      .brand-header { border: 1px solid #CBD5E1 !important; border-top: 3.5px solid #0D47A1 !important; }
      .brand-title { color: #0D47A1 !important; }
      .brand-tag { background: #E3F2FD !important; color: #0D47A1 !important; -webkit-print-color-adjust: exact; print-color-adjust: exact; }
    }
  </style>
</head>
<body>
  <div class="passbook-container">
    <!-- Company Brand Name Header -->
    <div class="brand-header">
      <div class="brand-title">${isTamil ? "ஸ்ரீ மீனாட்சி பைனான்ஸ்" : "SRI MEENAKSHI FINANCE"}</div>
      <div class="brand-subtitle">${isTamil ? "SRI MEENAKSHI FINANCE &bull; மதுரை" : "MADURAI &bull; MICRO FINANCE"}</div>
      <div class="brand-tag">${isTamil ? "கடன் தவணை அட்டை (PASSBOOK)" : "LOAN PASSBOOK"}</div>
    </div>

    <!-- Header: ID, Name, Photo, Acc -->
    <div class="customer-header-card">
      <div class="photo-box">
        $photoHtml
      </div>
      <div class="details-box">
        <div class="field-row"><span class="field-label">ID</span><span class="field-val">: $cusId</span></div>
        <div class="field-row"><span class="field-label">Name</span><span class="field-val">: ${loan.customerName}</span></div>
        <div class="field-row"><span class="field-label">Acc</span><span class="field-val">: ${loan.bondNumber}</span></div>
        <div class="field-row"><span class="field-label">Loan</span><span class="field-val">: ₹${NumberFormat('#,##0').format(loan.loanAmount)} (${loan.tenureDays} ${isTamil ? "நாட்கள்" : "days"})</span></div>
        <div class="field-row"><span class="field-label">Due</span><span class="field-val">: ₹${NumberFormat('#,##0').format(loan.dailyDueAmount)} / ${isTamil ? "நாள்" : "day"}</span></div>
        <div class="field-row"><span class="field-label">Bal</span><span class="field-val" style="color: #B91C1C; font-weight: bold;">: ₹${NumberFormat('#,##0.00').format(loan.balanceAmount)}</span></div>
      </div>
    </div>

    <!-- Top Indicator -->
    <div class="addl-line">Date : ${DateFormat('dd/MM/yy').format(loan.startDate)} &nbsp;&bull;&nbsp; Amt. ${NumberFormat('#,##0').format(totalPrincipal)}</div>

    <!-- Table -->
    <table class="passbook-table">
      <thead>
        <tr>
          <th class="col-sl">Sl. No.</th>
          <th class="col-date">Date</th>
          <th class="col-collamt">CollAmt</th>
          <th class="col-bamt">BAMT</th>
        </tr>
      </thead>
      <tbody>
        $tableRowsHtml
      </tbody>
    </table>
  </div>
</body>
</html>
''';
  }

  /// Generates companion TXT receipt format matching the new passbook structure
  static String generatePassbookTxt({
    required LoanModel loan,
    required List<CollectionModel> ledger,
    required bool isTamil,
  }) {
    final cusId = loan.customer?.cusCode ?? (loan.customerId > 0 ? "CUS-${loan.customerId}" : "ID-${loan.id}");
    final sortedLedger = List<CollectionModel>.from(ledger)
      ..sort((a, b) => a.collectionDate.compareTo(b.collectionDate));

    final totalPrincipal = loan.totalAmount > 0 ? loan.totalAmount : (loan.loanAmount > 0 ? loan.loanAmount : loan.balanceAmount);
    double runningBal = totalPrincipal;
    int currentSlNo = 1;
    double grandTotalColl = 0.0;
    final StringBuffer sb = StringBuffer();

    final brandTitle = isTamil ? "ஸ்ரீ மீனாட்சி பைனான்ஸ்" : "SRI MEENAKSHI FINANCE";
    sb.writeln("=====================================================");
    sb.writeln("               $brandTitle");
    sb.writeln("            MADURAI • LOAN PASSBOOK");
    sb.writeln("=====================================================");
    sb.writeln("ID        : $cusId");
    sb.writeln("Name      : ${loan.customerName}");
    sb.writeln("Acc       : ${loan.bondNumber}");
    sb.writeln("Loan Amt  : ₹${NumberFormat('#,##0').format(loan.loanAmount)} (${loan.tenureDays} days)");
    sb.writeln("Daily Due : ₹${NumberFormat('#,##0').format(loan.dailyDueAmount)} / day");
    sb.writeln("Balance   : ₹${NumberFormat('#,##0.00').format(loan.balanceAmount)}");
    sb.writeln("=====================================================");
    sb.writeln("Date : ${DateFormat('dd/MM/yy').format(loan.startDate)}   Amt. ${NumberFormat('#,##0').format(totalPrincipal)}");
    sb.writeln("-----------------------------------------------------");
    sb.writeln("Sl. No.    Date         CollAmt            BAMT");
    sb.writeln("-----------------------------------------------------");
    sb.writeln("${'0'.padRight(10)} ${DateFormat('dd/MM/yy').format(loan.startDate).padRight(12)} ${'Principal'.padRight(15)} ${NumberFormat('#,##0.00').format(totalPrincipal).padLeft(12)}");

    if (sortedLedger.isEmpty) {
      sb.writeln("          No receipts recorded yet");
    } else {
      int i = 0;
      while (i < sortedLedger.length) {
        final firstOfGroup = sortedLedger[i];
        final monthKey = "${firstOfGroup.collectionDate.month.toString().padLeft(2, '0')}/${firstOfGroup.collectionDate.year}";
        double monthTotal = 0.0;

        while (i < sortedLedger.length) {
          final col = sortedLedger[i];
          final colMonthKey = "${col.collectionDate.month.toString().padLeft(2, '0')}/${col.collectionDate.year}";
          if (colMonthKey != monthKey) break;

          runningBal -= col.amount;
          monthTotal += col.amount;
          grandTotalColl += col.amount;

          final dateStr = DateFormat('dd/MM/yy').format(col.collectionDate);
          final collAmtStr = NumberFormat('#,##0').format(col.amount).padLeft(9);
          final bamtStr = NumberFormat('#,##0.00').format(runningBal).padLeft(14);
          final slStr = currentSlNo.toString().padRight(9);

          sb.writeln("$slStr $dateStr  $collAmtStr  $bamtStr");
          currentSlNo++;
          i++;
        }

        final mTotalStr = NumberFormat('#,##0.00').format(monthTotal).padLeft(9);
        sb.writeln("-----------------------------------------------------");
        sb.writeln("          $monthKey  $mTotalStr");
        sb.writeln("-----------------------------------------------------");
      }

      final gTotalStr = NumberFormat('#,##0.00').format(grandTotalColl).padLeft(9);
      sb.writeln("=====================================================");
      sb.writeln("          Total:     $gTotalStr");
      sb.writeln("=====================================================");
    }

    return sb.toString();
  }

  /// Download HTML Passbook directly to device/browser Downloads
  static Future<String> downloadPassbookHtml({
    required LoanModel loan,
    required List<CollectionModel> ledger,
    required bool isTamil,
  }) async {
    final html = generatePassbookHtml(loan: loan, ledger: ledger, isTamil: isTamil);
    final safeBond = loan.bondNumber.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final fileName = 'Passbook_$safeBond.html';

    return await triggerFileDownload(
      content: html,
      fileName: fileName,
      mimeType: 'text/html;charset=utf-8',
    );
  }

  /// Download TXT Passbook directly
  static Future<String> downloadPassbookTxt({
    required LoanModel loan,
    required List<CollectionModel> ledger,
    required bool isTamil,
  }) async {
    final txt = generatePassbookTxt(loan: loan, ledger: ledger, isTamil: isTamil);
    final safeBond = loan.bondNumber.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final fileName = 'Passbook_$safeBond.txt';

    return await triggerFileDownload(
      content: txt,
      fileName: fileName,
      mimeType: 'text/plain;charset=utf-8',
    );
  }

  /// Print or Save as PDF in browser or mobile
  static Future<void> printPassbook({
    required LoanModel loan,
    required List<CollectionModel> ledger,
    required bool isTamil,
  }) async {
    final html = generatePassbookHtml(loan: loan, ledger: ledger, isTamil: isTamil);
    await triggerPrintPassbook(htmlContent: html);
  }

  /// Backwards-compatible save passbook method that triggers download safely
  static Future<String> savePassbookFile({
    required LoanModel loan,
    required List<CollectionModel> ledger,
    required bool isTamil,
  }) async {
    return await downloadPassbookHtml(loan: loan, ledger: ledger, isTamil: isTamil);
  }

  /// Share or Print passbook using system Share sheet or web download
  static Future<void> sharePassbook({
    required LoanModel loan,
    required List<CollectionModel> ledger,
    required bool isTamil,
  }) async {
    if (kIsWeb) {
      // On web, sharing triggers browser print preview and file download
      await printPassbook(loan: loan, ledger: ledger, isTamil: isTamil);
      await downloadPassbookHtml(loan: loan, ledger: ledger, isTamil: isTamil);
      return;
    }

    final html = generatePassbookHtml(loan: loan, ledger: ledger, isTamil: isTamil);
    final safeBond = loan.bondNumber.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final filePath = await saveTempFile(
      content: html,
      fileName: 'Passbook_$safeBond.html',
    );

    // ignore: deprecated_member_use
    await Share.shareXFiles(
      [XFile(filePath, mimeType: 'text/html', name: 'Passbook_${loan.bondNumber}.html')],
      text: 'Sri Meenakshi Finance - Passbook for Bond ${loan.bondNumber}',
      subject: 'Loan Passbook - ${loan.bondNumber} (${loan.customerName})',
    );
  }
}

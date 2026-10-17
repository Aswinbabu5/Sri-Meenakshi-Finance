import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/loan_model.dart';
import '../models/collection_model.dart';
import '../utils/safe_image_provider.dart';

class MemberPdfGenerator {
  /// Generates a complete, beautiful PDF document containing:
  /// - Sri Meenakshi Finance Header
  /// - Member Face Photo and Personal Details
  /// - Proof Type, Front Proof Photo, and Back Proof Photo
  /// - Loan Financial Terms & Amounts (Loan Amount, Interest, Daily Due, Total, Balance, etc.)
  /// - Repayment Ledger & Grand Totals
  /// - Authorization Signatures
  static Future<Uint8List> generateMemberPdf({
    required LoanModel loan,
    required List<CollectionModel> collections,
    required bool isTamil,
  }) async {
    final pdf = pw.Document();

    // Load Tamil Google Font with fallback to Helvetica
    pw.Font fontRegular;
    pw.Font fontBold;
    try {
      fontRegular = await PdfGoogleFonts.notoSansTamilRegular();
      fontBold = await PdfGoogleFonts.notoSansTamilBold();
    } catch (_) {
      fontRegular = pw.Font.helvetica();
      fontBold = pw.Font.helveticaBold();
    }

    // Extract image providers safely with try-catch
    final pw.ImageProvider? photoImage = _safeMemoryImage(getSafeImageBytes(loan.photoPath));
    final pw.ImageProvider? proofFrontImage = _safeMemoryImage(getSafeImageBytes(loan.proofFrontPath));
    final pw.ImageProvider? proofBackImage = _safeMemoryImage(getSafeImageBytes(loan.proofBackPath));

    final cusId = loan.customer?.cusCode ??
        (loan.customerId > 0 ? "CUS-${loan.customerId}" : "ID-${loan.id}");

    // Financial calculations
    final totalPrincipal = loan.totalAmount > 0
        ? loan.totalAmount
        : (loan.loanAmount > 0 ? loan.loanAmount : loan.balanceAmount);

    final currencyFmt = NumberFormat('#,##0');
    final currencyDecimalFmt = NumberFormat('#,##0.00');

    // Sort ledger chronologically
    final sortedLedger = List<CollectionModel>.from(collections)
      ..sort((a, b) => a.collectionDate.compareTo(b.collectionDate));

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        theme: pw.ThemeData.withFont(
          base: fontRegular,
          bold: fontBold,
        ),
        header: (pw.Context context) {
          return pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 12),
            padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: pw.BoxDecoration(
              color: PdfColors.blue900,
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'ஸ்ரீ மீனாட்சி பைனான்ஸ்',
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      'SRI MEENAKSHI FINANCE - DAILY & WEEKLY LOANS',
                      style: const pw.TextStyle(
                        color: PdfColors.blue100,
                        fontSize: 8.5,
                      ),
                    ),
                  ],
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.white,
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Text(
                    'LINE: ${loan.lineCode}  |  BOND: ${loan.bondNumber}',
                    style: pw.TextStyle(
                      color: PdfColors.blue900,
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        build: (pw.Context context) {
          return [
            // Section 1: Member Particulars & Photo
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: pw.BorderRadius.circular(6),
                color: PdfColors.grey50,
              ),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Details Column
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _buildPdfKeyValue('உறுப்பினர் பெயர் (Member Name)', loan.customerName, fontBold),
                        pw.SizedBox(height: 3),
                        _buildPdfKeyValue('தந்தை / கணவர் (Father/Spouse)', loan.fatherOrSpouseName ?? '-', fontBold),
                        pw.SizedBox(height: 3),
                        _buildPdfKeyValue('தொலைபேசி (Phone Number)', loan.phoneNumber, fontBold),
                        pw.SizedBox(height: 3),
                        _buildPdfKeyValue('முகவரி (Address)', '${loan.address ?? '-'}, ${loan.city ?? 'மதுரை'}', fontBold),
                        pw.SizedBox(height: 3),
                        _buildPdfKeyValue('வாடிக்கையாளர் எண் (Customer ID)', cusId, fontBold),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 12),
                  // Member Photo Container
                  pw.Container(
                    width: 75,
                    height: 90,
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.blue800, width: 1.5),
                      borderRadius: pw.BorderRadius.circular(4),
                      color: PdfColors.white,
                    ),
                    child: photoImage != null
                        ? pw.ClipRRect(
                            horizontalRadius: 3,
                            verticalRadius: 3,
                            child: pw.Image(
                              photoImage,
                              fit: pw.BoxFit.cover,
                            ),
                          )
                        : pw.Center(
                            child: pw.Text(
                              'புகைப்படம்\n(Photo)',
                              textAlign: pw.TextAlign.center,
                              style: const pw.TextStyle(color: PdfColors.grey500, fontSize: 8),
                            ),
                          ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 8),

            // Section 2: ID Proof Details & Photos (Front and Back)
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: pw.BorderRadius.circular(6),
                color: PdfColors.white,
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'ஆவணச் சான்று விவரங்கள் (Identity Proof Documents)',
                        style: pw.TextStyle(
                          color: PdfColors.blue900,
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.blue50,
                          borderRadius: pw.BorderRadius.circular(3),
                          border: pw.Border.all(color: PdfColors.blue200),
                        ),
                        child: pw.Text(
                          loan.proofType ?? 'ஆதார் அட்டை (Aadhaar Card)',
                          style: pw.TextStyle(
                            color: PdfColors.blue800,
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 8.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 6),
                  pw.Row(
                    children: [
                      // Proof Front
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('முன் பக்கம் (Proof Front)', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                            pw.SizedBox(height: 3),
                            pw.Container(
                              height: 75,
                              decoration: pw.BoxDecoration(
                                border: pw.Border.all(color: PdfColors.grey400, width: 0.8),
                                borderRadius: pw.BorderRadius.circular(4),
                                color: PdfColors.grey100,
                              ),
                              child: proofFrontImage != null
                                  ? pw.ClipRRect(
                                      horizontalRadius: 3,
                                      verticalRadius: 3,
                                      child: pw.Image(
                                        proofFrontImage,
                                        fit: pw.BoxFit.contain,
                                      ),
                                    )
                                  : pw.Center(
                                      child: pw.Text(
                                        'முன் பக்க படம் இல்லை\n(No Front Photo)',
                                        textAlign: pw.TextAlign.center,
                                        style: const pw.TextStyle(color: PdfColors.grey500, fontSize: 8),
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ),
                      pw.SizedBox(width: 10),
                      // Proof Back
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('பின் பக்கம் (Proof Back)', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                            pw.SizedBox(height: 3),
                            pw.Container(
                              height: 75,
                              decoration: pw.BoxDecoration(
                                border: pw.Border.all(color: PdfColors.grey400, width: 0.8),
                                borderRadius: pw.BorderRadius.circular(4),
                                color: PdfColors.grey100,
                              ),
                              child: proofBackImage != null
                                  ? pw.ClipRRect(
                                      horizontalRadius: 3,
                                      verticalRadius: 3,
                                      child: pw.Image(
                                        proofBackImage,
                                        fit: pw.BoxFit.contain,
                                      ),
                                    )
                                  : pw.Center(
                                      child: pw.Text(
                                        'பின் பக்க படம் இல்லை\n(No Back Photo)',
                                        textAlign: pw.TextAlign.center,
                                        style: const pw.TextStyle(color: PdfColors.grey500, fontSize: 8),
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 8),

            // Section 3: Loan & Financial Amounts Grid
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.blue300),
                borderRadius: pw.BorderRadius.circular(6),
                color: PdfColors.blue50,
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'கடன் விவரங்கள் & கணக்கு நிலவரம் (Loan & Financial Particulars)',
                    style: pw.TextStyle(
                      color: PdfColors.blue900,
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Table(
                    border: pw.TableBorder.all(color: PdfColors.blue200, width: 0.6),
                    children: [
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(color: PdfColors.white),
                        children: [
                          _buildFinancialCell('கடன் தொகை (Loan Amt)', 'Rs. ${currencyFmt.format(loan.loanAmount)}', isBold: true),
                          _buildFinancialCell('வட்டி (Interest)', 'Rs. ${currencyFmt.format(loan.interestAmount)}'),
                          _buildFinancialCell('மொத்த தொகை (Total Amt)', 'Rs. ${currencyFmt.format(totalPrincipal)}', isBold: true, textColor: PdfColors.blue900),
                        ],
                      ),
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(color: PdfColors.white),
                        children: [
                          _buildFinancialCell('தினசரி தவணை (Daily Due)', 'Rs. ${currencyFmt.format(loan.dailyDueAmount)}', isBold: true),
                          _buildFinancialCell('கால அளவு (Tenure)', '${loan.tenureDays} Days'),
                          _buildFinancialCell('சிட் கட்டணம் (Chit Fee)', 'Rs. ${currencyFmt.format(loan.chitFee)}'),
                        ],
                      ),
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(color: PdfColors.white),
                        children: [
                          _buildFinancialCell('தொடக்க தேதி (Start Date)', DateFormat('dd/MM/yyyy').format(loan.startDate)),
                          _buildFinancialCell('செலுத்தியது (Total Paid)', 'Rs. ${currencyFmt.format(loan.collectedAmount)}', textColor: PdfColors.green800, isBold: true),
                          _buildFinancialCell('பாக்கி தொகை (Balance Due)', 'Rs. ${currencyFmt.format(loan.balanceAmount)}', textColor: PdfColors.red800, isBold: true),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 10),

            // Section 4: Collection Ledger Header & Table
            pw.Text(
              'தவணை வசூல் குறிப்பேடு (Daily Collection Passbook Ledger)',
              style: pw.TextStyle(
                color: PdfColors.blue900,
                fontWeight: pw.FontWeight.bold,
                fontSize: 10.5,
              ),
            ),
            pw.SizedBox(height: 4),

            _buildLedgerTable(
              loan: loan,
              sortedLedger: sortedLedger,
              totalPrincipal: totalPrincipal,
              currencyFmt: currencyFmt,
              currencyDecimalFmt: currencyDecimalFmt,
              isTamil: isTamil,
            ),
            pw.SizedBox(height: 14),

            // Section 5: Signatures & Timestamp Footer
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Container(width: 140, height: 1, color: PdfColors.grey500),
                    pw.SizedBox(height: 3),
                    pw.Text('உறுப்பினர் கையொப்பம்\n(Member Signature)', textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 8)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text(
                      'Generated: ${DateFormat('dd/MM/yyyy hh:mm a').format(DateTime.now())}',
                      style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
                    ),
                    pw.Text('Sri Meenakshi Finance', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Container(width: 140, height: 1, color: PdfColors.grey500),
                    pw.SizedBox(height: 3),
                    pw.Text('நிர்வாகி கையொப்பம்\n(Authorized Signature)', textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 8)),
                  ],
                ),
              ],
            ),
          ];
        },
      ),
    );

    return await pdf.save();
  }

  static pw.Widget _buildPdfKeyValue(String label, String value, pw.Font boldFont) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: 155,
          child: pw.Text(
            label,
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
          ),
        ),
        pw.Text(': ', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
        pw.Expanded(
          child: pw.Text(
            value,
            style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColors.grey900),
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildFinancialCell(String label, String val, {bool isBold = false, PdfColor? textColor}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 6),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600)),
          pw.SizedBox(height: 1),
          pw.Text(
            val,
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: textColor ?? PdfColors.grey900,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildLedgerTable({
    required LoanModel loan,
    required List<CollectionModel> sortedLedger,
    required double totalPrincipal,
    required NumberFormat currencyFmt,
    required NumberFormat currencyDecimalFmt,
    required bool isTamil,
  }) {
    final rows = <pw.TableRow>[
      // Table Header
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.blue800),
        children: [
          _buildTableHeaderCell('வ.எண் (Sl)'),
          _buildTableHeaderCell('தேதி (Date)'),
          _buildTableHeaderCell('செலுத்திய தொகை (Paid)'),
          _buildTableHeaderCell('வகை (Mode)'),
          _buildTableHeaderCell('பாக்கி (Balance)'),
        ],
      ),
      // Opening balance row (Sl. No. 0)
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.grey100),
        children: [
          _buildTableDataCell('0', align: pw.TextAlign.center),
          _buildTableDataCell(DateFormat('dd/MM/yy').format(loan.startDate)),
          _buildTableDataCell('ஆரம்ப கடன் (Principal)', align: pw.TextAlign.left),
          _buildTableDataCell('-'),
          _buildTableDataCell('Rs. ${currencyDecimalFmt.format(totalPrincipal)}', isBold: true, color: PdfColors.blue900),
        ],
      ),
    ];

    double runningBal = totalPrincipal;
    int currentSlNo = 1;
    double grandTotalColl = 0.0;

    for (final col in sortedLedger) {
      runningBal -= col.amount;
      grandTotalColl += col.amount;

      final modeText = col.paymentMode.toLowerCase() == 'gpay' ? 'GPay' : 'ரொக்கம் (Cash)';

      rows.add(
        pw.TableRow(
          decoration: pw.BoxDecoration(
            color: currentSlNo % 2 == 0 ? PdfColors.grey50 : PdfColors.white,
          ),
          children: [
            _buildTableDataCell(currentSlNo.toString(), align: pw.TextAlign.center),
            _buildTableDataCell(DateFormat('dd/MM/yy').format(col.collectionDate)),
            _buildTableDataCell('Rs. ${currencyFmt.format(col.amount)}', isBold: true),
            _buildTableDataCell(modeText),
            _buildTableDataCell('Rs. ${currencyDecimalFmt.format(runningBal)}'),
          ],
        ),
      );
      currentSlNo++;
    }

    if (sortedLedger.isEmpty) {
      rows.add(
        pw.TableRow(
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(10),
              child: pw.Center(
                child: pw.Text(
                  'வசூல் பதிவுகள் ஏதுமில்லை (No collection records recorded yet)',
                  style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 8),
                ),
              ),
            ),
            pw.SizedBox(),
            pw.SizedBox(),
            pw.SizedBox(),
            pw.SizedBox(),
          ],
        ),
      );
    } else {
      // Grand Total Row
      rows.add(
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.blue50),
          children: [
            _buildTableDataCell(''),
            _buildTableDataCell('மொத்தம் (Grand Total)', isBold: true),
            _buildTableDataCell('Rs. ${currencyDecimalFmt.format(grandTotalColl)}', isBold: true, color: PdfColors.green900),
            _buildTableDataCell(''),
            _buildTableDataCell('Rs. ${currencyDecimalFmt.format(runningBal)}', isBold: true, color: PdfColors.red900),
          ],
        ),
      );
    }

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.6),
      columnWidths: const {
        0: pw.FlexColumnWidth(1),
        1: pw.FlexColumnWidth(1.6),
        2: pw.FlexColumnWidth(2.2),
        3: pw.FlexColumnWidth(1.6),
        4: pw.FlexColumnWidth(2.2),
      },
      children: rows,
    );
  }

  static pw.Widget _buildTableHeaderCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 5),
      child: pw.Text(
        text,
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 8),
      ),
    );
  }

  static pw.Widget _buildTableDataCell(
    String text, {
    bool isBold = false,
    PdfColor? color,
    pw.TextAlign align = pw.TextAlign.right,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 5),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: 8,
          fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: color ?? PdfColors.grey900,
        ),
      ),
    );
  }

  static pw.ImageProvider? _safeMemoryImage(Uint8List? bytes) {
    if (bytes == null || bytes.isEmpty) return null;
    try {
      return pw.MemoryImage(bytes);
    } catch (_) {
      return null;
    }
  }
}


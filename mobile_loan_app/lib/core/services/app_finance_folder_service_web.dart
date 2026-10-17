import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../models/loan_model.dart';
import '../models/collection_model.dart';
import '../utils/file_download_helper.dart';
import '../utils/safe_image_provider.dart';
import 'loan_repository.dart';
import 'member_pdf_generator.dart';

class MemberFilesSaveResult {
  final bool success;
  final String? photoPath;
  final String? proofFrontPath;
  final String? proofBackPath;
  final String? pdfPath;
  final String? rootFolderPath;
  final String? message;

  const MemberFilesSaveResult({
    required this.success,
    this.photoPath,
    this.proofFrontPath,
    this.proofBackPath,
    this.pdfPath,
    this.rootFolderPath,
    this.message,
  });
}

class AppFinanceExportResult {
  final int totalLoans;
  final int photosSaved;
  final int proofsSaved;
  final int pdfsSaved;
  final String? rootFolderPath;
  final String? photoFolderPath;
  final String? proofFolderPath;
  final String? detailsFolderPath;
  final String? message;

  const AppFinanceExportResult({
    required this.totalLoans,
    required this.photosSaved,
    required this.proofsSaved,
    required this.pdfsSaved,
    this.rootFolderPath,
    this.photoFolderPath,
    this.proofFolderPath,
    this.detailsFolderPath,
    this.message,
  });
}

class AppFinanceFolderService {
  static String sanitizeFileName(String input) {
    return input
        .trim()
        .replaceAll(RegExp(r'[\\/:*?"<>|\s]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
  }

  static Future<String?> getAppFinanceRootPath() async => 'app-finance (Local Browser Database)';
  static Future<String?> getMemberPhotoFolderPath() async => 'app-finance/member-photo';
  static Future<String?> getMemberProofFolderPath() async => 'app-finance/member-proof';
  static Future<String?> getMemberDetailsFolderPath() async => 'app-finance/member-details';

  static Future<MemberFilesSaveResult> saveMemberFiles({
    required LoanModel loan,
    List<CollectionModel>? collections,
    required bool isTamil,
  }) async {
    // On web, images and member details are stored directly in SQLite IndexedDB
    return const MemberFilesSaveResult(
      success: true,
      rootFolderPath: 'app-finance (Database)',
      message: 'Stored directly in database',
    );
  }

  static Future<AppFinanceExportResult> syncAllToFolders({
    required LoanRepository repository,
    String? lineFilter,
    Function(int current, int total, String status)? onProgress,
  }) async {
    final isTamil = repository.isTamil;
    final allLoans = repository.getLoans(
      lineCode: (lineFilter != null && lineFilter.isNotEmpty && lineFilter != 'ALL') ? lineFilter : null,
      status: 'All',
      financialYear: 'All',
    );

    int pdfsCount = 0;
    final total = allLoans.length;

    // On Web, download the clean member details PDFs directly without ZIP
    for (int i = 0; i < total; i++) {
      final loan = allLoans[i];
      final cleanBond = sanitizeFileName(loan.bondNumber);
      final cleanName = sanitizeFileName(loan.customerName);

      onProgress?.call(
        i + 1,
        total,
        isTamil ? 'பதிவிறக்குகிறது: $cleanBond - $cleanName' : 'Exporting: $cleanBond - $cleanName',
      );

      try {
        final collections = repository.getLedger(loan.bondNumber, loanId: loan.id);
        final pdfBytes = await MemberPdfGenerator.generateMemberPdf(
          loan: loan,
          collections: collections,
          isTamil: isTamil,
        );

        final fileName = '${cleanBond}_${cleanName}_details.pdf';
        await triggerBinaryDownload(
          bytes: pdfBytes,
          fileName: fileName,
          mimeType: 'application/pdf',
        );
        pdfsCount++;
      } catch (e) {
        debugPrint('Error generating PDF on web: $e');
      }
    }

    return AppFinanceExportResult(
      totalLoans: total,
      photosSaved: 0,
      proofsSaved: 0,
      pdfsSaved: pdfsCount,
      rootFolderPath: 'Downloads/app-finance',
      photoFolderPath: 'member-photo',
      proofFolderPath: 'member-proof',
      detailsFolderPath: 'member-details',
      message: 'Member details exported as direct PDF files',
    );
  }

  static Future<void> openAppFinanceFolder() async {}
}

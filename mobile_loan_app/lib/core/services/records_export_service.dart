import 'dart:typed_data';
import '../models/loan_model.dart';
import '../models/collection_model.dart';
import '../services/loan_repository.dart';
import '../services/member_pdf_generator.dart';
import '../services/app_finance_folder_service.dart';
import '../utils/file_download_helper.dart';

class RecordsExportResult {
  final int totalLoans;
  final int photosSaved;
  final int proofsSaved;
  final int pdfsSaved;
  final String? localDirectoryPath;
  final String? photoFolderPath;
  final String? proofFolderPath;
  final String? detailsFolderPath;
  final Uint8List? zipBytes;
  final String zipFileName;

  const RecordsExportResult({
    required this.totalLoans,
    required this.photosSaved,
    required this.proofsSaved,
    required this.pdfsSaved,
    this.localDirectoryPath,
    this.photoFolderPath,
    this.proofFolderPath,
    this.detailsFolderPath,
    this.zipBytes,
    this.zipFileName = '',
  });
}

class RecordsExportService {
  /// Sanitizes string for safe filename across macOS, Windows, and Linux
  static String sanitizeFileName(String input) {
    return AppFinanceFolderService.sanitizeFileName(input);
  }

  /// Exports and organizes all records directly into `app-finance/` on disk:
  /// - `app-finance/member-photo/` (Member profile photos .jpg/.jpeg)
  /// - `app-finance/member-proof/` (Front & back ID proof photos .jpg/.jpeg)
  /// - `app-finance/member-details/` (Member details and loan ledger .pdf)
  ///
  /// Replaces the ZIP file model with direct, organized folder storage across all OSes.
  static Future<RecordsExportResult> exportRecords({
    required LoanRepository repository,
    String? lineFilter,
    Function(int current, int total, String status)? onProgress,
  }) async {
    final res = await AppFinanceFolderService.syncAllToFolders(
      repository: repository,
      lineFilter: lineFilter,
      onProgress: onProgress,
    );

    return RecordsExportResult(
      totalLoans: res.totalLoans,
      photosSaved: res.photosSaved,
      proofsSaved: res.proofsSaved,
      pdfsSaved: res.pdfsSaved,
      localDirectoryPath: res.rootFolderPath,
      photoFolderPath: res.photoFolderPath,
      proofFolderPath: res.proofFolderPath,
      detailsFolderPath: res.detailsFolderPath,
    );
  }

  /// Exports a single member's PDF directly to download or disk
  static Future<String> exportSingleMemberPdf({
    required LoanModel loan,
    required List<CollectionModel> collections,
    required bool isTamil,
  }) async {
    final pdfBytes = await MemberPdfGenerator.generateMemberPdf(
      loan: loan,
      collections: collections,
      isTamil: isTamil,
    );

    final cleanBond = sanitizeFileName(loan.bondNumber);
    final cleanName = sanitizeFileName(loan.customerName);
    final fileName = '${cleanBond}_${cleanName}_details.pdf';

    return await triggerBinaryDownload(
      bytes: pdfBytes,
      fileName: fileName,
      mimeType: 'application/pdf',
    );
  }
}

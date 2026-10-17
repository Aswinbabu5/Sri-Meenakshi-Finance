import '../models/loan_model.dart';
import '../models/collection_model.dart';
import 'loan_repository.dart';

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

  static bool get isFileSystemAccessSupported => false;
  static dynamic get cachedDirectoryHandle => null;
  static String? get cachedDirectoryName => null;
  static void clearCachedDirectory() {}
  static Future<dynamic> pickAppFinanceDirectory() async => null;

  static Future<String?> getAppFinanceRootPath() async => null;
  static Future<String?> getMemberPhotoFolderPath() async => null;
  static Future<String?> getMemberProofFolderPath() async => null;
  static Future<String?> getMemberDetailsFolderPath() async => null;

  static Future<MemberFilesSaveResult> saveMemberFiles({
    required LoanModel loan,
    List<CollectionModel>? collections,
    required bool isTamil,
  }) async {
    return const MemberFilesSaveResult(success: false, message: 'Platform not supported');
  }

  static Future<AppFinanceExportResult> syncAllToFolders({
    required LoanRepository repository,
    String? lineFilter,
    Function(int current, int total, String status)? onProgress,
  }) async {
    return const AppFinanceExportResult(
      totalLoans: 0,
      photosSaved: 0,
      proofsSaved: 0,
      pdfsSaved: 0,
      message: 'Platform not supported',
    );
  }

  static Future<void> openAppFinanceFolder() async {}
}

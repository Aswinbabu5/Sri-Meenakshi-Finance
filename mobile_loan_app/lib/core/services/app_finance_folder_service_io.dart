import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
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
  /// Sanitizes string for safe cross-platform file naming
  static String sanitizeFileName(String input) {
    return input
        .trim()
        .replaceAll(RegExp(r'[\\/:*?"<>|\s]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
  }

  /// Determines the main `app-finance` directory across Windows, macOS, Linux, Android, iOS.
  /// - Windows: C:\app-finance (or SystemDrive\app-finance)
  /// - macOS: ~/app-finance (/Users/<user>/app-finance)
  /// - Linux: ~/app-finance
  /// - Android: /storage/emulated/0/app-finance (or app documents fallback)
  /// - iOS: Documents/app-finance
  static Future<Directory> getAppFinanceDirectory() async {
    Directory? baseDir;

    if (Platform.isWindows) {
      final drive = Platform.environment['SystemDrive'] ?? 'C:';
      final winDir = Directory('$drive\\app-finance');
      try {
        if (!winDir.existsSync()) {
          winDir.createSync(recursive: true);
        }
        baseDir = winDir;
      } catch (_) {
        // Fallback to user home directory if root C:\ has strict permissions
        final userProfile = Platform.environment['USERPROFILE'];
        if (userProfile != null && userProfile.isNotEmpty) {
          final fallbackWin = Directory('$userProfile\\app-finance');
          fallbackWin.createSync(recursive: true);
          baseDir = fallbackWin;
        }
      }
    } else if (Platform.isMacOS) {
      // macOS user home directory ~/app-finance
      final home = Platform.environment['HOME'] ?? '';
      if (home.isNotEmpty) {
        final macDir = Directory('$home/app-finance');
        try {
          if (!macDir.existsSync()) {
            macDir.createSync(recursive: true);
          }
          baseDir = macDir;
        } catch (_) {}
      }
      if (baseDir == null) {
        final user = Platform.environment['USER'] ?? '';
        if (user.isNotEmpty) {
          final userDir = Directory('/Users/$user/app-finance');
          try {
            if (!userDir.existsSync()) {
              userDir.createSync(recursive: true);
            }
            baseDir = userDir;
          } catch (_) {}
        }
      }
    } else if (Platform.isLinux) {
      final home = Platform.environment['HOME'] ?? '';
      if (home.isNotEmpty) {
        final linuxDir = Directory('$home/app-finance');
        try {
          if (!linuxDir.existsSync()) {
            linuxDir.createSync(recursive: true);
          }
          baseDir = linuxDir;
        } catch (_) {}
      }
    } else if (Platform.isAndroid) {
      // Direct user visible internal storage /storage/emulated/0/app-finance
      try {
        final androidPublicDir = Directory('/storage/emulated/0/app-finance');
        if (!androidPublicDir.existsSync()) {
          androidPublicDir.createSync(recursive: true);
        }
        baseDir = androidPublicDir;
      } catch (_) {
        try {
          final ext = await getExternalStorageDirectory();
          if (ext != null) {
            final extAppFinance = Directory('${ext.path}/app-finance');
            if (!extAppFinance.existsSync()) {
              extAppFinance.createSync(recursive: true);
            }
            baseDir = extAppFinance;
          }
        } catch (_) {}
      }
    }

    // Ultimate fallback for iOS / restricted desktop
    if (baseDir == null) {
      final docDir = await getApplicationDocumentsDirectory();
      final fallbackDir = Directory('${docDir.path}/app-finance');
      if (!fallbackDir.existsSync()) {
        fallbackDir.createSync(recursive: true);
      }
      baseDir = fallbackDir;
    }

    // Ensure the 3 standardized subfolders exist:
    // 1. member-photo (.jpg / .jpeg)
    // 2. member-proof (.jpg / .jpeg)
    // 3. member-details (.pdf)
    final photoDir = Directory('${baseDir.path}/member-photo');
    final proofDir = Directory('${baseDir.path}/member-proof');
    final detailsDir = Directory('${baseDir.path}/member-details');

    if (!photoDir.existsSync()) photoDir.createSync(recursive: true);
    if (!proofDir.existsSync()) proofDir.createSync(recursive: true);
    if (!detailsDir.existsSync()) detailsDir.createSync(recursive: true);

    return baseDir;
  }

  static Future<String?> getAppFinanceRootPath() async {
    try {
      final dir = await getAppFinanceDirectory();
      return dir.path;
    } catch (_) {
      return null;
    }
  }

  static Future<String?> getMemberPhotoFolderPath() async {
    final root = await getAppFinanceRootPath();
    return root != null ? '$root/member-photo' : null;
  }

  static Future<String?> getMemberProofFolderPath() async {
    final root = await getAppFinanceRootPath();
    return root != null ? '$root/member-proof' : null;
  }

  static Future<String?> getMemberDetailsFolderPath() async {
    final root = await getAppFinanceRootPath();
    return root != null ? '$root/member-details' : null;
  }

  /// Directly stores a member's photo, proofs, and details PDF into `app-finance/` folders.
  /// - `app-finance/member-photo/<bond>_<name>_photo.jpg`
  /// - `app-finance/member-proof/<bond>_<name>_<proofType>_front.jpg`
  /// - `app-finance/member-proof/<bond>_<name>_<proofType>_back.jpg`
  /// - `app-finance/member-details/<bond>_<name>_details.pdf`
  static Future<MemberFilesSaveResult> saveMemberFiles({
    required LoanModel loan,
    List<CollectionModel>? collections,
    required bool isTamil,
  }) async {
    try {
      final rootDir = await getAppFinanceDirectory();
      final cleanBond = sanitizeFileName(loan.bondNumber);
      final cleanName = sanitizeFileName(loan.customerName);
      final cleanProofType = sanitizeFileName(loan.proofType ?? 'ID_Proof');

      final photoDir = Directory('${rootDir.path}/member-photo');
      final proofDir = Directory('${rootDir.path}/member-proof');
      final detailsDir = Directory('${rootDir.path}/member-details');

      String? savedPhotoPath;
      String? savedProofFrontPath;
      String? savedProofBackPath;
      String? savedPdfPath;

      // 1. Member Profile Photo -> member-photo/
      final photoBytes = getSafeImageBytes(loan.photoPath);
      if (photoBytes != null && photoBytes.isNotEmpty) {
        final photoFile = File('${photoDir.path}/${cleanBond}_${cleanName}_photo.jpg');
        await photoFile.writeAsBytes(photoBytes);
        savedPhotoPath = photoFile.path;
      }

      // 2. Member Proof Photos (Front & Back) -> member-proof/
      final proofFrontBytes = getSafeImageBytes(loan.proofFrontPath);
      if (proofFrontBytes != null && proofFrontBytes.isNotEmpty) {
        final frontFile = File('${proofDir.path}/${cleanBond}_${cleanName}_${cleanProofType}_front.jpg');
        await frontFile.writeAsBytes(proofFrontBytes);
        savedProofFrontPath = frontFile.path;
      }

      final proofBackBytes = getSafeImageBytes(loan.proofBackPath);
      if (proofBackBytes != null && proofBackBytes.isNotEmpty) {
        final backFile = File('${proofDir.path}/${cleanBond}_${cleanName}_${cleanProofType}_back.jpg');
        await backFile.writeAsBytes(proofBackBytes);
        savedProofBackPath = backFile.path;
      }

      // 3. Member Details PDF -> member-details/
      try {
        final ledger = collections ?? <CollectionModel>[];
        final pdfBytes = await MemberPdfGenerator.generateMemberPdf(
          loan: loan,
          collections: ledger,
          isTamil: isTamil,
        );
        final pdfFile = File('${detailsDir.path}/${cleanBond}_${cleanName}_details.pdf');
        await pdfFile.writeAsBytes(pdfBytes);
        savedPdfPath = pdfFile.path;
      } catch (pdfErr) {
        debugPrint('Error generating member details PDF: $pdfErr');
      }

      return MemberFilesSaveResult(
        success: true,
        photoPath: savedPhotoPath,
        proofFrontPath: savedProofFrontPath,
        proofBackPath: savedProofBackPath,
        pdfPath: savedPdfPath,
        rootFolderPath: rootDir.path,
        message: 'Saved successfully in ${rootDir.path}',
      );
    } catch (e) {
      debugPrint('Error in AppFinanceFolderService.saveMemberFiles: $e');
      return MemberFilesSaveResult(
        success: false,
        message: e.toString(),
      );
    }
  }

  /// Syncs all loan records (or filtered line) directly into `app-finance/` folders on disk.
  /// No zip file is used.
  static Future<AppFinanceExportResult> syncAllToFolders({
    required LoanRepository repository,
    String? lineFilter,
    Function(int current, int total, String status)? onProgress,
  }) async {
    final rootDir = await getAppFinanceDirectory();
    final isTamil = repository.isTamil;

    final allLoans = repository.getLoans(
      lineCode: (lineFilter != null && lineFilter.isNotEmpty && lineFilter != 'ALL') ? lineFilter : null,
      status: 'All',
      financialYear: 'All',
    );

    int photosCount = 0;
    int proofsCount = 0;
    int pdfsCount = 0;
    final total = allLoans.length;

    for (int i = 0; i < total; i++) {
      final loan = allLoans[i];
      final cleanBond = sanitizeFileName(loan.bondNumber);
      final cleanName = sanitizeFileName(loan.customerName);

      onProgress?.call(
        i + 1,
        total,
        isTamil ? 'சேமிக்கப்படுகிறது: $cleanBond - $cleanName' : 'Saving: $cleanBond - $cleanName',
      );

      final collections = repository.getLedger(loan.bondNumber, loanId: loan.id);
      final res = await saveMemberFiles(
        loan: loan,
        collections: collections,
        isTamil: isTamil,
      );

      if (res.photoPath != null) photosCount++;
      if (res.proofFrontPath != null) proofsCount++;
      if (res.proofBackPath != null) proofsCount++;
      if (res.pdfPath != null) pdfsCount++;
    }

    return AppFinanceExportResult(
      totalLoans: total,
      photosSaved: photosCount,
      proofsSaved: proofsCount,
      pdfsSaved: pdfsCount,
      rootFolderPath: rootDir.path,
      photoFolderPath: '${rootDir.path}/member-photo',
      proofFolderPath: '${rootDir.path}/member-proof',
      detailsFolderPath: '${rootDir.path}/member-details',
      message: 'All records saved in ${rootDir.path}',
    );
  }

  /// Opens the `app-finance` folder in the system file manager (Windows Explorer / macOS Finder)
  static Future<void> openAppFinanceFolder() async {
    try {
      final dir = await getAppFinanceDirectory();
      await openDirectoryInFileManager(dir.path);
    } catch (e) {
      debugPrint('Could not open app-finance folder: $e');
    }
  }
}

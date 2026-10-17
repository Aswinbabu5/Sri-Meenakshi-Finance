// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:convert';
import 'dart:js_interop';
import 'package:flutter/foundation.dart';
import '../models/loan_model.dart';
import '../models/collection_model.dart';
import '../utils/file_download_helper.dart';
import '../utils/safe_image_provider.dart';
import 'loan_repository.dart';
import 'member_pdf_generator.dart';

@JS('eval')
external JSAny? _jsEval(String code);

@JS('AppFinanceStorage.isSupported')
external bool _isSupported();

@JS('AppFinanceStorage.pickDirectory')
external JSPromise<JSObject?> _pickDirectory();

@JS('AppFinanceStorage.saveFile')
external JSPromise<JSBoolean> _saveFile(
  JSObject dirHandle,
  String subDir,
  String fileName,
  String base64Data,
  String mimeType,
);

@JS('AppFinanceStorage.getDirName')
external String _getDirName(JSObject dirHandle);

void _ensureJsBridge() {
  _jsEval(r'''
    if (!window.AppFinanceStorage) {
      window.AppFinanceStorage = {
        isSupported: function() {
          return typeof window.showDirectoryPicker === 'function';
        },
        pickDirectory: async function() {
          try {
            let handle = await window.showDirectoryPicker({ mode: 'readwrite' });
            if (handle && handle.name !== 'app-finance' && !handle.name.toLowerCase().includes('finance')) {
              try {
                handle = await handle.getDirectoryHandle('app-finance', { create: true });
              } catch (_) {}
            }
            return handle;
          } catch (e) {
            console.log('Directory picker cancelled or error:', e);
            return null;
          }
        },
        getDirName: function(handle) {
          return handle ? (handle.name || 'app-finance') : 'app-finance';
        },
        saveFile: async function(dirHandle, subDirName, fileName, base64Data, mimeType) {
          try {
            let targetDir = dirHandle;
            if (subDirName && subDirName.length > 0) {
              targetDir = await dirHandle.getDirectoryHandle(subDirName, { create: true });
            }
            const fileHandle = await targetDir.getFileHandle(fileName, { create: true });
            const writable = await fileHandle.createWritable();
            
            const byteCharacters = atob(base64Data);
            const byteNumbers = new Array(byteCharacters.length);
            for (let i = 0; i < byteCharacters.length; i++) {
              byteNumbers[i] = byteCharacters.charCodeAt(i);
            }
            const byteArray = new Uint8Array(byteNumbers);
            const blob = new Blob([byteArray], { type: mimeType || 'application/octet-stream' });
            
            await writable.write(blob);
            await writable.close();
            return true;
          } catch (err) {
            console.error('Error saving file ' + fileName + ':', err);
            return false;
          }
        }
      };
    }
  ''');
}

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
  static JSObject? _cachedDirectoryHandle;
  static String? _cachedDirectoryName;

  static String sanitizeFileName(String input) {
    return input
        .trim()
        .replaceAll(RegExp(r'[\\/:*?"<>|\s]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
  }

  /// Whether modern Chromium File System Access API (showDirectoryPicker) is supported
  static bool get isFileSystemAccessSupported {
    try {
      _ensureJsBridge();
      return _isSupported();
    } catch (_) {
      return false;
    }
  }

  static dynamic get cachedDirectoryHandle => _cachedDirectoryHandle;
  static String? get cachedDirectoryName => _cachedDirectoryName;

  static void clearCachedDirectory() {
    _cachedDirectoryHandle = null;
    _cachedDirectoryName = null;
  }

  /// Prompts the user with Chrome's native directory picker to select their local `app-finance` folder
  static Future<dynamic> pickAppFinanceDirectory() async {
    if (!isFileSystemAccessSupported) return null;
    try {
      _ensureJsBridge();
      final handle = await _pickDirectory().toDart;
      if (handle != null) {
        _cachedDirectoryHandle = handle;
        _cachedDirectoryName = _getDirName(handle);
        return handle;
      }
    } catch (e) {
      debugPrint('Directory picker cancelled or error: $e');
    }
    return null;
  }

  static Future<String?> getAppFinanceRootPath() async {
    if (_cachedDirectoryName != null) {
      return _cachedDirectoryName;
    }
    return 'app-finance (Local Storage)';
  }

  static Future<String?> getMemberPhotoFolderPath() async =>
      _cachedDirectoryName != null ? '$_cachedDirectoryName/member-photo' : 'app-finance/member-photo';

  static Future<String?> getMemberProofFolderPath() async =>
      _cachedDirectoryName != null ? '$_cachedDirectoryName/member-proof' : 'app-finance/member-proof';

  static Future<String?> getMemberDetailsFolderPath() async =>
      _cachedDirectoryName != null ? '$_cachedDirectoryName/member-details' : 'app-finance/member-details';

  /// Saves a single member's photo, proofs, and details PDF directly into `app-finance/` folders.
  static Future<MemberFilesSaveResult> saveMemberFiles({
    required LoanModel loan,
    List<CollectionModel>? collections,
    required bool isTamil,
  }) async {
    final cleanBond = sanitizeFileName(loan.bondNumber);
    final cleanName = sanitizeFileName(loan.customerName);
    final cleanProofType = sanitizeFileName(loan.proofType ?? loan.customer?.proofType ?? 'ID_Proof');

    if (_cachedDirectoryHandle != null) {
      try {
        _ensureJsBridge();
        String? savedPhotoPath;
        String? savedProofFrontPath;
        String? savedProofBackPath;
        String? savedPdfPath;

        // 1. Photo
        final photoBytes = await getSafeImageBytesAsync(loan.photoPath ?? loan.customer?.photoPath);
        if (photoBytes != null && photoBytes.isNotEmpty) {
          final photoName = '${cleanBond}_${cleanName}_photo.jpg';
          final ok = (await _saveFile(
            _cachedDirectoryHandle!,
            'member-photo',
            photoName,
            base64Encode(photoBytes),
            'image/jpeg',
          ).toDart).toDart;
          if (ok) savedPhotoPath = 'member-photo/$photoName';
        }

        // 2. Proof Front
        final proofFrontBytes = await getSafeImageBytesAsync(loan.proofFrontPath ?? loan.customer?.proofFrontPath);
        if (proofFrontBytes != null && proofFrontBytes.isNotEmpty) {
          final frontName = '${cleanBond}_${cleanName}_${cleanProofType}_front.jpg';
          final ok = (await _saveFile(
            _cachedDirectoryHandle!,
            'member-proof',
            frontName,
            base64Encode(proofFrontBytes),
            'image/jpeg',
          ).toDart).toDart;
          if (ok) savedProofFrontPath = 'member-proof/$frontName';
        }

        // 3. Proof Back
        final proofBackBytes = await getSafeImageBytesAsync(loan.proofBackPath ?? loan.customer?.proofBackPath);
        if (proofBackBytes != null && proofBackBytes.isNotEmpty) {
          final backName = '${cleanBond}_${cleanName}_${cleanProofType}_back.jpg';
          final ok = (await _saveFile(
            _cachedDirectoryHandle!,
            'member-proof',
            backName,
            base64Encode(proofBackBytes),
            'image/jpeg',
          ).toDart).toDart;
          if (ok) savedProofBackPath = 'member-proof/$backName';
        }

        // 4. Details PDF
        try {
          final ledger = collections ?? <CollectionModel>[];
          final pdfBytes = await MemberPdfGenerator.generateMemberPdf(
            loan: loan,
            collections: ledger,
            isTamil: isTamil,
          );
          final pdfName = '${cleanBond}_${cleanName}_details.pdf';
          final ok = (await _saveFile(
            _cachedDirectoryHandle!,
            'member-details',
            pdfName,
            base64Encode(pdfBytes),
            'application/pdf',
          ).toDart).toDart;
          if (ok) savedPdfPath = 'member-details/$pdfName';
        } catch (pdfErr) {
          debugPrint('Error generating PDF on web: $pdfErr');
        }

        final rootName = _cachedDirectoryName ?? 'app-finance';
        return MemberFilesSaveResult(
          success: true,
          photoPath: savedPhotoPath,
          proofFrontPath: savedProofFrontPath,
          proofBackPath: savedProofBackPath,
          pdfPath: savedPdfPath,
          rootFolderPath: rootName,
          message: 'Saved directly into local $rootName folder',
        );
      } catch (e) {
        debugPrint('Error writing single member files to directory: $e');
      }
    }

    return MemberFilesSaveResult(
      success: true,
      rootFolderPath: _cachedDirectoryName ?? 'app-finance (Database)',
      message: 'Stored directly in database',
    );
  }

  /// Syncs all loan records directly into `app-finance/` folders.
  /// Uses Chrome's File System Access API for direct folder writes into `member-photo/`, `member-proof/`, `member-details/`.
  /// If cancelled or not supported, falls back to direct browser downloads.
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

    // If File System Access API is supported and we don't have a cached handle yet,
    // prompt user to select their local folder!
    if (isFileSystemAccessSupported && _cachedDirectoryHandle == null) {
      await pickAppFinanceDirectory();
    }

    final hasDirectFolders = _cachedDirectoryHandle != null;
    if (hasDirectFolders) {
      _ensureJsBridge();
    }

    int photosCount = 0;
    int proofsCount = 0;
    int pdfsCount = 0;
    final total = allLoans.length;

    for (int i = 0; i < total; i++) {
      final loan = allLoans[i];
      final cleanBond = sanitizeFileName(loan.bondNumber);
      final cleanName = sanitizeFileName(loan.customerName);
      final cleanProofType = sanitizeFileName(loan.proofType ?? loan.customer?.proofType ?? 'ID_Proof');

      onProgress?.call(
        i + 1,
        total,
        isTamil
            ? (hasDirectFolders ? 'கோப்புறையில் சேமிக்கிறது: $cleanBond - $cleanName' : 'பதிவிறக்குகிறது: $cleanBond - $cleanName')
            : (hasDirectFolders ? 'Saving to folder: $cleanBond - $cleanName' : 'Exporting: $cleanBond - $cleanName'),
      );

      // Find photo path from loan or customer
      String? photoPath = loan.photoPath;
      if (photoPath == null || photoPath.isEmpty) {
        photoPath = loan.customer?.photoPath;
      }
      if ((photoPath == null || photoPath.isEmpty) && loan.customerId > 0) {
        final cust = repository.getCustomers().where((c) => c.id == loan.customerId).firstOrNull;
        photoPath = cust?.photoPath;
      }

      // 1. Member Profile Photo (.jpg)
      final photoBytes = await getSafeImageBytesAsync(photoPath);
      if (photoBytes != null && photoBytes.isNotEmpty) {
        final photoName = '${cleanBond}_${cleanName}_photo.jpg';
        if (hasDirectFolders) {
          final ok = (await _saveFile(
            _cachedDirectoryHandle!,
            'member-photo',
            photoName,
            base64Encode(photoBytes),
            'image/jpeg',
          ).toDart).toDart;
          if (ok) photosCount++;
        } else {
          await triggerBinaryDownload(bytes: photoBytes, fileName: photoName, mimeType: 'image/jpeg');
          photosCount++;
        }
      }

      // Find proof paths from loan or customer
      String? proofFrontPath = loan.proofFrontPath ?? loan.customer?.proofFrontPath;
      String? proofBackPath = loan.proofBackPath ?? loan.customer?.proofBackPath;
      if ((proofFrontPath == null || proofFrontPath.isEmpty) && loan.customerId > 0) {
        final cust = repository.getCustomers().where((c) => c.id == loan.customerId).firstOrNull;
        proofFrontPath = cust?.proofFrontPath;
        proofBackPath ??= cust?.proofBackPath;
      }

      // 2. Member Proof Front (.jpg)
      final proofFrontBytes = await getSafeImageBytesAsync(proofFrontPath);
      if (proofFrontBytes != null && proofFrontBytes.isNotEmpty) {
        final frontName = '${cleanBond}_${cleanName}_${cleanProofType}_front.jpg';
        if (hasDirectFolders) {
          final ok = (await _saveFile(
            _cachedDirectoryHandle!,
            'member-proof',
            frontName,
            base64Encode(proofFrontBytes),
            'image/jpeg',
          ).toDart).toDart;
          if (ok) proofsCount++;
        } else {
          await triggerBinaryDownload(bytes: proofFrontBytes, fileName: frontName, mimeType: 'image/jpeg');
          proofsCount++;
        }
      }

      // 3. Member Proof Back (.jpg)
      final proofBackBytes = await getSafeImageBytesAsync(proofBackPath);
      if (proofBackBytes != null && proofBackBytes.isNotEmpty) {
        final backName = '${cleanBond}_${cleanName}_${cleanProofType}_back.jpg';
        if (hasDirectFolders) {
          final ok = (await _saveFile(
            _cachedDirectoryHandle!,
            'member-proof',
            backName,
            base64Encode(proofBackBytes),
            'image/jpeg',
          ).toDart).toDart;
          if (ok) proofsCount++;
        } else {
          await triggerBinaryDownload(bytes: proofBackBytes, fileName: backName, mimeType: 'image/jpeg');
          proofsCount++;
        }
      }

      // 4. Member Details & Ledger PDF (.pdf)
      try {
        final collections = repository.getLedger(loan.bondNumber, loanId: loan.id);
        final pdfBytes = await MemberPdfGenerator.generateMemberPdf(
          loan: loan,
          collections: collections,
          isTamil: isTamil,
        );
        final pdfName = '${cleanBond}_${cleanName}_details.pdf';
        if (hasDirectFolders) {
          final ok = (await _saveFile(
            _cachedDirectoryHandle!,
            'member-details',
            pdfName,
            base64Encode(pdfBytes),
            'application/pdf',
          ).toDart).toDart;
          if (ok) pdfsCount++;
        } else {
          await triggerBinaryDownload(bytes: pdfBytes, fileName: pdfName, mimeType: 'application/pdf');
          pdfsCount++;
        }
      } catch (e) {
        debugPrint('Error generating PDF on web: $e');
      }
    }

    final rootPathDisplay = hasDirectFolders
        ? (_cachedDirectoryName != null ? '${_cachedDirectoryName!}/app-finance' : 'app-finance')
        : 'Downloads/app-finance';

    return AppFinanceExportResult(
      totalLoans: total,
      photosSaved: photosCount,
      proofsSaved: proofsCount,
      pdfsSaved: pdfsCount,
      rootFolderPath: rootPathDisplay,
      photoFolderPath: 'member-photo',
      proofFolderPath: 'member-proof',
      detailsFolderPath: 'member-details',
      message: hasDirectFolders
          ? 'Saved directly into your local app-finance folder'
          : 'Saved directly via downloads to Downloads/app-finance',
    );
  }

  static Future<void> openAppFinanceFolder() async {
    if (isFileSystemAccessSupported) {
      await pickAppFinanceDirectory();
    }
  }
}

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';

Future<String> triggerFileDownload({
  required String content,
  required String fileName,
  String mimeType = 'text/html;charset=utf-8',
}) async {
  Directory? targetDir;

  if (Platform.isAndroid) {
    // 1. Check if public /storage/emulated/0/Download is directly writable
    try {
      final publicDownload = Directory('/storage/emulated/0/Download');
      if (publicDownload.existsSync()) {
        final testFile = File('${publicDownload.path}/.access_test_${DateTime.now().millisecondsSinceEpoch}');
        try {
          await testFile.writeAsString('test');
          await testFile.delete();
          targetDir = publicDownload;
        } catch (_) {
          // Modern Android scoped storage prevents direct write; fallback
        }
      }
    } catch (_) {}

    // 2. Try app external downloads directory (always readable/writable without permissions)
    if (targetDir == null) {
      try {
        final extDirs = await getExternalStorageDirectories(type: StorageDirectory.downloads);
        if (extDirs != null && extDirs.isNotEmpty) {
          targetDir = extDirs.first;
        }
      } catch (_) {}
    }
  }

  // 3. Fallback for desktop / iOS / other
  if (targetDir == null) {
    try {
      targetDir = await getDownloadsDirectory();
    } catch (_) {}
  }

  // 4. Guaranteed fallback
  targetDir ??= await getApplicationDocumentsDirectory();

  if (!await targetDir.exists()) {
    await targetDir.create(recursive: true);
  }

  final file = File('${targetDir.path}/$fileName');
  await file.writeAsString(content);
  return file.path;
}

Future<void> triggerPrintPassbook({
  required String htmlContent,
}) async {
  try {
    await Printing.layoutPdf(
      // ignore: deprecated_member_use
      onLayout: (format) async => await Printing.convertHtml(
        format: format,
        html: htmlContent,
      ),
      name: 'Loan_Passbook',
    );
  } catch (e) {
    debugPrint('Error in triggerPrintPassbook: $e');
    rethrow;
  }
}

Future<String> saveTempFile({
  required String content,
  required String fileName,
}) async {
  final tempDir = await getTemporaryDirectory();
  if (!await tempDir.exists()) {
    await tempDir.create(recursive: true);
  }
  final file = File('${tempDir.path}/$fileName');
  await file.writeAsString(content);
  return file.path;
}

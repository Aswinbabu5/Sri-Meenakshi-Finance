import 'dart:typed_data';

Future<String> triggerFileDownload({
  required String content,
  required String fileName,
  String mimeType = 'text/html;charset=utf-8',
}) async {
  throw UnsupportedError('File download not supported on this platform');
}

Future<String> triggerBinaryDownload({
  required Uint8List bytes,
  required String fileName,
  String mimeType = 'application/octet-stream',
}) async {
  throw UnsupportedError('Binary download not supported on this platform');
}

Future<void> openDirectoryInFileManager(String path) async {}

Future<void> triggerPrintPassbook({
  required String htmlContent,
}) async {
  throw UnsupportedError('Print not supported on this platform');
}

Future<String> saveTempFile({
  required String content,
  required String fileName,
}) async {
  throw UnsupportedError('Temp file not supported on this platform');
}


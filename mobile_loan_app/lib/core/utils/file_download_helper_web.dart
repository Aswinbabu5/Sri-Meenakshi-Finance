// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';

Future<String> triggerFileDownload({
  required String content,
  required String fileName,
  String mimeType = 'text/html;charset=utf-8',
}) async {
  final bytes = utf8.encode(content);
  return triggerBinaryDownload(
    bytes: Uint8List.fromList(bytes),
    fileName: fileName,
    mimeType: mimeType,
  );
}

Future<String> triggerBinaryDownload({
  required Uint8List bytes,
  required String fileName,
  String mimeType = 'application/octet-stream',
}) async {
  final blob = html.Blob([bytes], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', fileName)
    ..style.display = 'none';

  html.document.body?.children.add(anchor);
  anchor.click();
  anchor.remove();

  Future.delayed(const Duration(seconds: 4), () {
    html.Url.revokeObjectUrl(url);
  });

  return 'Downloads/$fileName';
}

Future<void> openDirectoryInFileManager(String path) async {
  // Browsers cannot open arbitrary local file manager paths
}

Future<void> triggerPrintPassbook({
  required String htmlContent,
}) async {
  final bytes = utf8.encode(htmlContent);
  final blob = html.Blob([bytes], 'text/html');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.window.open(url, '_blank');
}

Future<String> saveTempFile({
  required String content,
  required String fileName,
}) async {
  return '';
}


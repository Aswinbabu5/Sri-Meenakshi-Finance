// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';
import 'package:flutter/material.dart';

bool isValidPhotoPath(String? path) {
  if (path == null || path.trim().isEmpty) return false;
  return path.startsWith('data:') ||
      path.startsWith('blob:') ||
      path.startsWith('http://') ||
      path.startsWith('https://');
}

Uint8List? getSafeImageBytes(String? path) {
  if (path == null || path.trim().isEmpty) return null;
  final clean = path.trim();
  if (clean.startsWith('data:')) {
    final commaIdx = clean.indexOf(',');
    final b64 = commaIdx != -1 ? clean.substring(commaIdx + 1) : clean;
    try {
      final normalized = b64.replaceAll(RegExp(r'\s+'), '');
      return base64Decode(normalized);
    } catch (_) {}
  } else if (!clean.startsWith('http://') && !clean.startsWith('https://') && !clean.startsWith('blob:')) {
    try {
      final normalized = clean.replaceAll(RegExp(r'\s+'), '');
      if (normalized.length > 50) {
        return base64Decode(normalized);
      }
    } catch (_) {}
  }
  return null;
}

Future<Uint8List?> getSafeImageBytesAsync(String? path) async {
  if (path == null || path.trim().isEmpty) return null;
  final syncBytes = getSafeImageBytes(path);
  if (syncBytes != null) return syncBytes;
  if (path.startsWith('blob:') || path.startsWith('http://') || path.startsWith('https://')) {
    try {
      final req = await html.HttpRequest.request(path, responseType: 'arraybuffer');
      final ByteBuffer buffer = req.response;
      return buffer.asUint8List();
    } catch (_) {}
  }
  return null;
}

ImageProvider? getSafeImageProvider(String? path) {
  if (!isValidPhotoPath(path)) return null;
  if (path!.startsWith('data:')) {
    final bytes = getSafeImageBytes(path);
    if (bytes != null) return MemoryImage(bytes);
  }
  return NetworkImage(path);
}

Widget getSafeImageWidget(
  String? path, {
  BoxFit fit = BoxFit.cover,
  double? width,
  double? height,
  Widget? placeholder,
}) {
  final fallback = placeholder ??
      const Center(child: Icon(Icons.person, color: Colors.grey, size: 28));
  if (!isValidPhotoPath(path)) return fallback;

  if (path!.startsWith('data:')) {
    final bytes = getSafeImageBytes(path);
    if (bytes != null) {
      return Image.memory(
        bytes,
        fit: fit,
        width: width,
        height: height,
        errorBuilder: (context, error, stackTrace) => fallback,
      );
    }
  }

  return Image.network(
    path,
    fit: fit,
    width: width,
    height: height,
    errorBuilder: (context, error, stackTrace) => fallback,
  );
}

String? getPhotoBase64OrUri(String? path) {
  if (!isValidPhotoPath(path)) return null;
  return path;
}

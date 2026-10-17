import 'dart:convert';
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
  if (path.startsWith('data:')) {
    final commaIdx = path.indexOf(',');
    final b64 = commaIdx != -1 ? path.substring(commaIdx + 1) : path;
    try {
      return base64Decode(b64);
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

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

bool isValidPhotoPath(String? path) {
  if (path == null || path.trim().isEmpty) return false;
  if (path.startsWith('data:') ||
      path.startsWith('blob:') ||
      path.startsWith('http://') ||
      path.startsWith('https://')) {
    return true;
  }
  if (kIsWeb) return false;
  try {
    return File(path).existsSync();
  } catch (_) {
    return false;
  }
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
  if (!kIsWeb) {
    try {
      final file = File(path);
      if (file.existsSync()) {
        return file.readAsBytesSync();
      }
    } catch (_) {}
  }
  return null;
}

Future<Uint8List?> getSafeImageBytesAsync(String? path) async {
  return getSafeImageBytes(path);
}

ImageProvider? getSafeImageProvider(String? path) {
  if (path == null || path.trim().isEmpty) return null;
  if (path.startsWith('data:')) {
    final bytes = getSafeImageBytes(path);
    if (bytes != null) return MemoryImage(bytes);
  }
  if (path.startsWith('http://') || path.startsWith('https://')) {
    return NetworkImage(path);
  }
  if (!kIsWeb) {
    try {
      final file = File(path);
      if (file.existsSync()) {
        return FileImage(file);
      }
    } catch (_) {}
  }
  return null;
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
  if (path == null || path.trim().isEmpty) return fallback;

  if (path.startsWith('data:')) {
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

  if (path.startsWith('http://') || path.startsWith('https://')) {
    return Image.network(
      path,
      fit: fit,
      width: width,
      height: height,
      errorBuilder: (context, error, stackTrace) => fallback,
    );
  }

  if (!kIsWeb) {
    try {
      final file = File(path);
      if (file.existsSync()) {
        return Image.file(
          file,
          fit: fit,
          width: width,
          height: height,
          errorBuilder: (context, error, stackTrace) => fallback,
        );
      }
    } catch (_) {}
  }
  return fallback;
}

String? getPhotoBase64OrUri(String? path) {
  if (path == null || path.trim().isEmpty) return null;
  if (path.startsWith('data:') ||
      path.startsWith('blob:') ||
      path.startsWith('http://') ||
      path.startsWith('https://')) {
    return path;
  }
  if (!kIsWeb) {
    try {
      final file = File(path);
      if (file.existsSync()) {
        final bytes = file.readAsBytesSync();
        final b64 = base64Encode(bytes);
        return 'data:image/jpeg;base64,$b64';
      }
    } catch (_) {}
  }
  return null;
}


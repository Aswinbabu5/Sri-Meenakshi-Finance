import 'package:flutter/material.dart';

bool isValidPhotoPath(String? path) {
  if (path == null || path.trim().isEmpty) return false;
  return path.startsWith('data:') ||
      path.startsWith('blob:') ||
      path.startsWith('http://') ||
      path.startsWith('https://');
}

ImageProvider? getSafeImageProvider(String? path) {
  if (!isValidPhotoPath(path)) return null;
  return NetworkImage(path!);
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
  return Image.network(
    path!,
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

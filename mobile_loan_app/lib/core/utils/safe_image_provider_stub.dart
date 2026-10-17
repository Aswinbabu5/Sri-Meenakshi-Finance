import 'dart:typed_data';
import 'package:flutter/widgets.dart';

bool isValidPhotoPath(String? path) => false;

ImageProvider? getSafeImageProvider(String? path) => null;

Widget getSafeImageWidget(
  String? path, {
  BoxFit fit = BoxFit.cover,
  double? width,
  double? height,
  Widget? placeholder,
}) =>
    placeholder ?? const SizedBox.shrink();

String? getPhotoBase64OrUri(String? path) => null;

Uint8List? getSafeImageBytes(String? path) => null;

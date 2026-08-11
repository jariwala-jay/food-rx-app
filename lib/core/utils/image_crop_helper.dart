import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_app/core/widgets/profile_photo_crop_screen.dart';

/// Presents the custom pinch-to-zoom/drag-to-pan crop screen over a picked
/// image and returns the cropped file, or null if the user cancelled.
Future<File?> cropProfilePhoto(BuildContext context, String sourcePath) {
  return Navigator.of(context).push<File?>(
    MaterialPageRoute(
      builder: (context) => ProfilePhotoCropScreen(sourcePath: sourcePath),
      fullscreenDialog: true,
    ),
  );
}

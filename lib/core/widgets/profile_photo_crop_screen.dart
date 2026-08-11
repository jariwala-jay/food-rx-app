import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import 'package:flutter_app/core/utils/app_colors.dart';

/// Full-screen profile-photo cropper: pinch to zoom, drag to reposition,
/// fixed circular 1:1 mask. Returns the cropped JPEG file, or null if the
/// user cancelled.
class ProfilePhotoCropScreen extends StatefulWidget {
  final String sourcePath;

  const ProfilePhotoCropScreen({super.key, required this.sourcePath});

  @override
  State<ProfilePhotoCropScreen> createState() =>
      _ProfilePhotoCropScreenState();
}

class _ProfilePhotoCropScreenState extends State<ProfilePhotoCropScreen> {
  static const double _cropSize = 300;
  static const double _maxUserScale = 4.0;
  static const int _jpegQuality = 85;

  final TransformationController _controller = TransformationController();

  img.Image? _decodedImage;
  double? _baseScale;
  double? _coverWidth;
  double? _coverHeight;
  bool _isSaving = false;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadImage() async {
    try {
      final bytes = await File(widget.sourcePath).readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) {
        if (mounted) setState(() => _loadFailed = true);
        return;
      }

      final baked = img.bakeOrientation(decoded);
      final baseScale = _cropSize /
          (baked.width < baked.height ? baked.width : baked.height);

      if (!mounted) return;
      setState(() {
        _decodedImage = baked;
        _baseScale = baseScale;
        _coverWidth = baked.width * baseScale;
        _coverHeight = baked.height * baseScale;
      });
    } catch (_) {
      if (mounted) setState(() => _loadFailed = true);
    }
  }

  Future<void> _onDone() async {
    final decoded = _decodedImage;
    final baseScale = _baseScale;
    if (decoded == null || baseScale == null || _isSaving) return;

    setState(() => _isSaving = true);

    try {
      // InteractiveViewer's transform for pan+pinch (no rotation) is always
      // screenPoint = scale * childPoint + translation, so a simple affine
      // inverse recovers the visible region without needing full matrix math.
      final matrix = _controller.value;
      final scale = matrix.getMaxScaleOnAxis();
      final translation = matrix.getTranslation();

      final childLeft = (0 - translation.x) / scale;
      final childTop = (0 - translation.y) / scale;
      final childRight = (_cropSize - translation.x) / scale;

      final srcLeft = childLeft / baseScale;
      final srcTop = childTop / baseScale;
      final srcRight = childRight / baseScale;

      final side = (srcRight - srcLeft).clamp(1.0, decoded.width.toDouble());
      final x = srcLeft.clamp(0.0, decoded.width - side);
      final y = srcTop.clamp(0.0, decoded.height - side);

      final cropped = img.copyCrop(
        decoded,
        x: x.round(),
        y: y.round(),
        width: side.round(),
        height: side.round(),
      );

      final jpgBytes = img.encodeJpg(cropped, quality: _jpegQuality);

      final tempDir = await getTemporaryDirectory();
      final outPath =
          '${tempDir.path}/profile_crop_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final outFile = await File(outPath).writeAsBytes(jpgBytes);

      if (!mounted) return;
      Navigator.of(context).pop(outFile);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: Center(
                child: _decodedImage == null
                    ? _loadFailed
                        ? const Text(
                            'Could not load image',
                            style: TextStyle(color: Colors.white),
                          )
                        : const CircularProgressIndicator(
                            color: AppColors.primaryOrange,
                          )
                    : _buildCropViewport(),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton(
            onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
          const Text(
            'Move and Scale',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          TextButton(
            onPressed: _isSaving ? null : _onDone,
            child: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primaryOrange,
                    ),
                  )
                : const Text(
                    'Done',
                    style: TextStyle(
                      color: AppColors.primaryOrange,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCropViewport() {
    return SizedBox(
      width: _cropSize,
      height: _cropSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          InteractiveViewer(
            transformationController: _controller,
            constrained: false,
            boundaryMargin: EdgeInsets.zero,
            minScale: 1.0,
            maxScale: _maxUserScale,
            child: SizedBox(
              width: _coverWidth,
              height: _coverHeight,
              child: Image.file(
                File(widget.sourcePath),
                fit: BoxFit.fill,
              ),
            ),
          ),
          // Dims everything outside the circular crop mask; purely visual,
          // so it must not intercept the gestures InteractiveViewer needs.
          IgnorePointer(
            child: CustomPaint(
              size: const Size.square(_cropSize),
              painter: _CircleMaskPainter(),
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleMaskPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final circlePath = Path()
      ..addOval(rect.deflate(0));
    final overlayPath = Path.combine(
      PathOperation.difference,
      Path()..addRect(rect),
      circlePath,
    );

    canvas.drawPath(overlayPath, Paint()..color = Colors.black54);
    canvas.drawOval(
      rect.deflate(1),
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

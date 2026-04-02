import 'package:flutter/material.dart';

/// Shared empty/error state for tab loads (recipes, goal progress, education, pantry).
///
/// Vertically aligns to a fixed fraction of the **full screen** so the block does not
/// jump when switching tabs that have different header heights.
class TabLoadErrorView extends StatefulWidget {
  static const String standardMessage =
      'Please check your internet connection and try again later.';

  /// Y position of the block’s vertical center, as a fraction of [MediaQuery] height.
  static const double viewportCenterYFraction = 0.46;

  final String title;
  final String message;
  final VoidCallback onRetry;
  final Widget? footer;

  const TabLoadErrorView({
    super.key,
    required this.title,
    this.message = standardMessage,
    required this.onRetry,
    this.footer,
  });

  @override
  State<TabLoadErrorView> createState() => _TabLoadErrorViewState();
}

class _TabLoadErrorViewState extends State<TabLoadErrorView> {
  final GlobalKey _regionKey = GlobalKey();
  final GlobalKey _columnKey = GlobalKey();
  double _top = 0;
  bool _laidOut = false;

  void _positionToViewportCenter() {
    if (!mounted) return;
    final region = _regionKey.currentContext?.findRenderObject() as RenderBox?;
    final column = _columnKey.currentContext?.findRenderObject() as RenderBox?;
    if (region == null ||
        column == null ||
        !region.hasSize ||
        !column.hasSize) {
      return;
    }

    final media = MediaQuery.sizeOf(context);
    final targetCenterY = media.height * TabLoadErrorView.viewportCenterYFraction;
    final regionTop = region.localToGlobal(Offset.zero).dy;
    final columnHeight = column.size.height;
    final newTop = targetCenterY - regionTop - columnHeight / 2;

    if (!_laidOut || (newTop - _top).abs() > 0.5) {
      setState(() {
        _top = newTop;
        _laidOut = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _positionToViewportCenter());
        return SizedBox(
          key: _regionKey,
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              Positioned(
                top: _top,
                left: 0,
                right: 0,
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    key: _columnKey,
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        widget.title,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF333333),
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.message,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: widget.onRetry,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF6A00),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                        child: const Text('Retry'),
                      ),
                      if (widget.footer != null) ...[
                        const SizedBox(height: 16),
                        widget.footer!,
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

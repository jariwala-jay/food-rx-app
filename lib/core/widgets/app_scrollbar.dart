import 'package:flutter/material.dart';

/// A slim, Material 3 scrollbar styled after Gmail, Drive and Files: no
/// permanent track, a thin pill-shaped thumb, with the thumb kept
/// permanently visible as a constant position indicator.
///
/// Wrap any scrollable that shares its [ScrollController] with this widget.
class AppScrollbar extends StatelessWidget {
  const AppScrollbar({
    super.key,
    required this.controller,
    required this.child,
    this.alwaysVisible = true,
  });

  /// The controller shared with the scrollable [child]. Passing it
  /// explicitly (rather than relying on [PrimaryScrollController]
  /// auto-attachment) is what makes dragging the thumb reliable on
  /// desktop/web, where auto-attachment doesn't apply.
  final ScrollController controller;

  /// The scrollable content, typically a `ListView.builder`.
  final Widget child;

  /// Keeps the thumb visible instead of fading in/out with scroll activity.
  final bool alwaysVisible;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ScrollbarTheme(
      data: ScrollbarThemeData(
        // Thin by design (4-6px per the spec) so the bar reads as a
        // position hint, not a UI element competing with list content.
        thickness: const WidgetStatePropertyAll(6),

        // A radius >= half the thickness always fully rounds the thumb's
        // caps, giving the pill shape regardless of the thickness above.
        radius: const Radius.circular(12),

        // No track: a bare thumb is the minimal-distraction look the
        // reference apps (Drive, Gmail, Settings) use.
        trackVisibility: const WidgetStatePropertyAll(false),
        trackColor: const WidgetStatePropertyAll(Colors.transparent),
        trackBorderColor: const WidgetStatePropertyAll(Colors.transparent),

        // Dragging the thumb itself to scroll, as requested.
        interactive: true,

        // Small gap from the viewport edge so the thumb doesn't touch
        // list content, and a floor on thumb length so it stays a usable
        // drag target even in a list with hundreds of pantry items.
        crossAxisMargin: 2,
        minThumbLength: 48,

        // Darker while dragged/hovered so the thumb confirms it's "grabbed".
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.dragged)) {
            return colorScheme.onSurface.withValues(alpha: 0.6);
          }
          if (states.contains(WidgetState.hovered)) {
            return colorScheme.onSurface.withValues(alpha: 0.5);
          }
          return colorScheme.onSurfaceVariant.withValues(alpha: 0.4);
        }),
      ),
      child: Scrollbar(
        controller: controller,
        thumbVisibility: alwaysVisible,
        child: child,
      ),
    );
  }
}

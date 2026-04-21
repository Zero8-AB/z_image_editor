import 'package:flutter/material.dart';

/// Centered card shell shown around the editor on desktop web.
///
/// The card is sized to a comfortable fraction of the viewport rather than
/// filling the full screen, giving a more intentional, windowed feel.
///
/// On narrow viewports (< 620 dp wide) the card fills the entire screen so
/// the layout degrades gracefully on mobile-sized browser windows without
/// affecting the mobile app build at all.
class WebEditorShell extends StatelessWidget {
  final Widget child;

  const WebEditorShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Narrow viewport → full-screen (no card chrome)
        if (constraints.maxWidth < 620) return child;

        final cardWidth = (constraints.maxWidth * 0.82).clamp(0.0, 960.0);
        final cardHeight = (constraints.maxHeight * 0.90).clamp(0.0, 860.0);

        return Container(
          // Dimmed page background visible around the card
          color: Colors.black.withValues(alpha: 0.82),
          child: Center(
            child: SizedBox(
              width: cardWidth,
              height: cardHeight,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.55),
                        blurRadius: 48,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: child,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

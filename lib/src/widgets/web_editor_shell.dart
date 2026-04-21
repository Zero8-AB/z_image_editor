import 'package:flutter/material.dart';

/// Centered shell shown around the editor on desktop web.
///
/// Constrains the editor to a comfortable maximum width while letting it fill
/// the full viewport height. The background on either side matches the
/// editor's own background colour so the whole page looks cohesive.
///
/// On narrow viewports (< 620 dp wide) the shell is skipped entirely so the
/// layout degrades gracefully on mobile-sized browser windows.
class WebEditorShell extends StatelessWidget {
  final Widget child;

  const WebEditorShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Narrow viewport → no shell (full-screen, same as mobile build)
        if (constraints.maxWidth < 620) return child;

        final cardWidth = (constraints.maxWidth * 0.82).clamp(0.0, 960.0);

        return ColoredBox(
          // Match the editor's own background so the side gutters blend in.
          color: const Color(0xFF1C1C1E),
          child: Center(
            child: SizedBox(
              width: cardWidth,
              height: constraints.maxHeight,
              child: child,
            ),
          ),
        );
      },
    );
  }
}

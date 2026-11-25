import 'package:flutter/material.dart';

import '../theme/z_image_editor_theme.dart';

/// The sheets' full-width primary button (48 px, 18 px text); disabled at
/// half opacity when [onTap] is null.
class ZSheetButton extends StatelessWidget {
  final ZImageEditorTheme theme;
  final String label;
  final VoidCallback? onTap;

  const ZSheetButton({
    super.key,
    required this.theme,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onTap != null,
      child: GestureDetector(
        onTap: onTap,
        child: Opacity(
          opacity: onTap == null ? 0.5 : 1,
          child: Container(
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: theme.sheetAccentColor,
              borderRadius: BorderRadius.circular(4),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  label,
                  style: TextStyle(
                    fontFamily: theme.fontFamily,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                    color: theme.primaryButtonTextColor,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../theme/themed_controls.dart';
import '../theme/z_image_editor_theme.dart';
import 'photo_quality.dart';

/// Texts of the photo hints (one is shown at a time).
class ZPhotoHintLabels {
  final String glareTitle;
  final String glareBody;
  final String blurry;
  final String tooDark;
  final String cornersMissing;
  final String retake;
  final String useAnyway;
  final String dismiss;

  const ZPhotoHintLabels({
    this.glareTitle = 'Strong reflection on the glass',
    this.glareBody = 'Step a little to the side and try again. Monogram '
        'straightens the photo afterwards.',
    this.blurry = 'The photo is a bit blurry. Hold still and try again.',
    this.tooDark =
        'It’s quite dark. Turn on a light in the room, not behind you.',
    this.cornersMissing =
        'Part of the frame is outside the photo. Step back a little.',
    this.retake = 'Retake',
    this.useAnyway = 'Use anyway',
    this.dismiss = 'Dismiss',
  });

  /// Bold first line for [issue].
  String title(ZPhotoIssue issue) => switch (issue) {
        ZPhotoIssue.glare => glareTitle,
        ZPhotoIssue.blurry => blurry,
        ZPhotoIssue.tooDark => tooDark,
        ZPhotoIssue.cornersMissing => cornersMissing,
      };

  /// Second line for [issue], if any.
  String? body(ZPhotoIssue issue) =>
      issue == ZPhotoIssue.glare ? glareBody : null;
}

/// The calm hint above the photo: icon, text, Retake / Use anyway and a
/// dismiss cross. Never blocks the step.
class ZPhotoHintBanner extends StatelessWidget {
  final ZImageEditorTheme theme;
  final ZPhotoHintLabels labels;
  final ZPhotoIssue issue;

  /// Null hides Retake (the caller can't retake).
  final VoidCallback? onRetake;
  final VoidCallback onUseAnyway;
  final VoidCallback onDismiss;

  const ZPhotoHintBanner({
    super.key,
    required this.theme,
    this.labels = const ZPhotoHintLabels(),
    required this.issue,
    this.onRetake,
    required this.onUseAnyway,
    required this.onDismiss,
  });

  static ZLineIconKind iconFor(ZPhotoIssue issue) => switch (issue) {
        ZPhotoIssue.glare => ZLineIconKind.hintGlare,
        ZPhotoIssue.blurry => ZLineIconKind.hintBlurry,
        ZPhotoIssue.tooDark => ZLineIconKind.hintDark,
        ZPhotoIssue.cornersMissing => ZLineIconKind.hintCorners,
      };

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final body = labels.body(issue);
    TextStyle text(double size, Color color, [FontWeight? weight]) => TextStyle(
          fontFamily: t.fontFamily,
          fontSize: size,
          color: color,
          fontWeight: weight,
          height: 1.4,
          decoration: TextDecoration.none,
        );
    Widget button(Key key, String label, VoidCallback onTap, bool primary) =>
        Semantics(
          button: true,
          child: GestureDetector(
            key: key,
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Container(
              height: 44,
              padding: EdgeInsets.symmetric(horizontal: primary ? 16 : 8),
              alignment: Alignment.center,
              decoration: primary
                  ? BoxDecoration(
                      color: t.primaryButtonColor,
                      borderRadius: BorderRadius.circular(4),
                    )
                  : null,
              child: Text(
                label,
                maxLines: 1,
                style: text(
                  16,
                  primary ? t.primaryButtonTextColor : t.textColor,
                  primary ? FontWeight.w500 : null,
                ).copyWith(height: 1),
              ),
            ),
          ),
        );

    return Container(
      key: const Key('z_hint_banner'),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.fromLTRB(16, 12, 4, 8),
      decoration: BoxDecoration(
        color: t.hintBannerColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: ZLineIcon(
              iconFor(issue),
              key: Key('z_hint_icon_${issue.name}'),
              color: t.toggleOnColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // The text scrolls when the banner is height-capped (small
                // phones, large text); the buttons stay in view.
                Flexible(
                  child: SingleChildScrollView(
                    key: const Key('z_hint_scroll'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          labels.title(issue),
                          key: const Key('z_hint_title'),
                          style: text(15, t.textColor, FontWeight.w500),
                        ),
                        if (body != null) ...[
                          const SizedBox(height: 4),
                          Text(body,
                              key: const Key('z_hint_body'),
                              style: text(13, t.hintBodyColor)),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    if (onRetake != null)
                      button(const Key('z_hint_retake'), labels.retake,
                          onRetake!, true),
                    button(const Key('z_hint_use_anyway'), labels.useAnyway,
                        onUseAnyway, false),
                  ],
                ),
              ],
            ),
          ),
          Transform.translate(
            offset: const Offset(0, -10),
            child: Semantics(
              button: true,
              label: labels.dismiss,
              child: GestureDetector(
                key: const Key('z_hint_dismiss'),
                behavior: HitTestBehavior.opaque,
                onTap: onDismiss,
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Center(
                    child: ZLineIcon(ZLineIconKind.close,
                        color: t.mutedTextColor, size: 16),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

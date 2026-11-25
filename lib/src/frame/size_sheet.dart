import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/themed_controls.dart';
import '../theme/z_image_editor_theme.dart';
import 'artwork_size.dart';

/// Texts of the size sheet.
class ZSizeSheetLabels {
  final String title;
  final String subtitle;
  final String estimatedShape;
  final String checkHint;
  final String noMatchHint;
  final String commonSizes;
  final String height;
  final String width;
  final String depth;
  final String depthHint;
  final String autoFilledHint;
  final String bestFit;
  final String detailsNote;
  final String howTitle;
  final String howBody;
  final String confirm;
  final String keepEstimate;

  const ZSizeSheetLabels({
    this.title = 'Real size of the artwork',
    this.subtitle =
        'So the photo keeps the right shape, even when taken from the side.',
    this.estimatedShape = 'Estimated shape: ',
    this.checkHint =
        'Check the size. We can’t measure it exactly from a photo.',
    this.noMatchHint =
        'No common size has this shape. Enter one side, and we fill in the other.',
    this.commonSizes = 'Common sizes · height × width (cm)',
    this.height = 'Height (cm)',
    this.width = 'Width (cm)',
    this.depth = 'Depth (cm)',
    this.depthHint = 'Depth: Default 2 cm · change if needed',
    this.autoFilledHint = 'filled in from the shape. ',
    this.bestFit = 'Best fit',
    this.detailsNote =
        'If the size is in the artwork details, it’s used automatically.',
    this.howTitle = 'How sizes are suggested',
    this.howBody =
        'Upright artwork gets upright sizes (50 × 40), wide artwork gets wide '
            'sizes (40 × 50). A common size is only suggested when its shape '
            'matches; otherwise none is shown.',
    this.confirm = 'Confirm',
    this.keepEstimate = 'I don’t know, keep the estimated shape',
  });
}

/// Opens the size sheet. Resolves to the confirmed size, or null when the
/// user keeps the estimated shape or dismisses the sheet.
Future<ZArtworkSize?> showZArtworkSizeSheet(
  BuildContext context, {
  required ZImageEditorTheme theme,
  ZSizeSheetLabels labels = const ZSizeSheetLabels(),
  double? estimatedAspectHW,
  ZArtworkSize? initial,
}) {
  return showModalBottomSheet<ZArtworkSize>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x80000000),
    builder: (context) => ZArtworkSizeSheet(
      theme: theme,
      labels: labels,
      estimatedAspectHW: estimatedAspectHW,
      initial: initial,
      onConfirm: (s) => Navigator.of(context).pop(s),
      onKeepEstimate: () => Navigator.of(context).pop(),
    ),
  );
}

/// "Real size of the artwork": height × width × depth, common sizes that
/// match the photo's shape, depth quick picks.
class ZArtworkSizeSheet extends StatefulWidget {
  final ZImageEditorTheme theme;
  final ZSizeSheetLabels labels;

  /// Height / width of the photographed outline (null = unknown).
  final double? estimatedAspectHW;
  final ZArtworkSize? initial;
  final ValueChanged<ZArtworkSize> onConfirm;
  final VoidCallback onKeepEstimate;

  const ZArtworkSizeSheet({
    super.key,
    required this.theme,
    this.labels = const ZSizeSheetLabels(),
    this.estimatedAspectHW,
    this.initial,
    required this.onConfirm,
    required this.onKeepEstimate,
  });

  @override
  State<ZArtworkSizeSheet> createState() => _ZArtworkSizeSheetState();
}

enum _Field { height, width, depth }

class _ZArtworkSizeSheetState extends State<ZArtworkSizeSheet> {
  final _h = TextEditingController();
  final _w = TextEditingController();
  final _d = TextEditingController();
  final _hFocus = FocusNode();
  final _wFocus = FocusNode();
  final _dFocus = FocusNode();

  /// Values filled in by the sheet (shown with ≈, dashed) rather than typed.
  final _estimated = <_Field>{};
  ZCommonSize? _preset;
  ZCommonSize? _bestFit;

  ZImageEditorTheme get t => widget.theme;
  double? get _aspect => widget.initial?.isExact == true
      ? widget.initial!.aspectHW
      : widget.estimatedAspectHW;

  @override
  void initState() {
    super.initState();
    final aspect = widget.estimatedAspectHW;
    _bestFit = aspect == null ? null : ZCommonSizes.bestFit(aspect);
    final init = widget.initial;
    if (init != null && init.isExact) {
      _h.text = formatCm(init.heightCm);
      _w.text = formatCm(init.widthCm);
    } else if (_bestFit != null) {
      _preset = _bestFit;
      _h.text = formatCm(_bestFit!.heightCm);
      _w.text = formatCm(_bestFit!.widthCm);
    }
    final depth = init?.depthCm;
    if (depth != null) {
      _d.text = formatCm(depth);
    } else {
      _d.text = '≈ ${formatCm(ZDepthPreset.defaultCm)}';
      _estimated.add(_Field.depth);
    }
    for (final f in [_hFocus, _wFocus, _dFocus]) {
      f.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in [_h, _w, _d]) {
      c.dispose();
    }
    for (final f in [_hFocus, _wFocus, _dFocus]) {
      f.dispose();
    }
    super.dispose();
  }

  double? get _height => parseCm(_h.text);
  double? get _width => parseCm(_w.text);
  double get _depth => parseCm(_d.text) ?? ZDepthPreset.defaultCm;
  bool get _valid => _height != null && _width != null;

  void _typed(_Field f, String text) {
    setState(() {
      _estimated.remove(f);
      _preset = null;
      final aspect = _aspect;
      if (aspect == null) return;
      final v = parseCm(text);
      if (f == _Field.height &&
          (_w.text.isEmpty || _estimated.contains(_Field.width))) {
        _w.text = v == null ? '' : '≈ ${formatCm(v / aspect)}';
        if (v != null) _estimated.add(_Field.width);
      } else if (f == _Field.width &&
          (_h.text.isEmpty || _estimated.contains(_Field.height))) {
        _h.text = v == null ? '' : '≈ ${formatCm(v * aspect)}';
        if (v != null) _estimated.add(_Field.height);
      }
    });
  }

  void _pickPreset(ZCommonSize s) {
    setState(() {
      _preset = s;
      _h.text = formatCm(s.heightCm);
      _w.text = formatCm(s.widthCm);
      _estimated
        ..remove(_Field.height)
        ..remove(_Field.width);
    });
  }

  void _pickDepth(ZDepthPreset p) {
    setState(() {
      _d.text = formatCm(p.cm);
      _estimated.remove(_Field.depth);
    });
  }

  void _confirm() {
    if (!_valid) return;
    widget.onConfirm(ZArtworkSize(
      heightCm: _height!,
      widthCm: _width!,
      depthCm: _depth,
      source: ZSizeSource.confirmed,
    ));
  }

  String get confirmLabel => _valid
      ? '${widget.labels.confirm} ${formatCm(_height!)} × ${formatCm(_width!)} × ${formatCm(_depth)} cm'
      : widget.labels.confirm;

  TextStyle _text(double size,
          {Color? color, FontWeight weight = FontWeight.normal}) =>
      TextStyle(
        fontFamily: t.fontFamily,
        fontSize: size,
        color: color ?? t.sheetTextColor,
        fontWeight: weight,
        decoration: TextDecoration.none,
      );

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final keyboard = mq.viewInsets.bottom > 0;
    final l = widget.labels;
    final aspect = widget.estimatedAspectHW;
    final presets = aspect == null || _bestFit == null
        ? const <ZCommonSize>[]
        : ZCommonSizes.forAspect(aspect);

    final info = aspect == null
        ? null
        : Container(
            key: const Key('z_size_info'),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: t.sheetInfoFillColor,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: ZLineIcon(
                    aspect >= 1
                        ? ZLineIconKind.sizeConfirmed
                        : ZLineIconKind.fullPhoto,
                    color: t.sheetAccentColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text.rich(
                        TextSpan(children: [
                          TextSpan(text: l.estimatedShape),
                          TextSpan(
                            text: '${ZCommonSizes.ratioText(aspect)} (H : W)',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ]),
                        style: _text(14),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _bestFit != null ? l.checkHint : l.noMatchHint,
                        style: _text(13, color: t.sheetMutedColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );

    final grid = presets.isEmpty
        ? null
        : Column(
            key: const Key('z_size_presets'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.commonSizes.toUpperCase(),
                  style: _text(12,
                          color: t.sheetMutedColor, weight: FontWeight.w500)
                      .copyWith(letterSpacing: 0.7)),
              const SizedBox(height: 8),
              LayoutBuilder(builder: (context, c) {
                final w = (c.maxWidth - 16) / 3;
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final s in presets)
                      SizedBox(
                        width: w,
                        child: _PresetButton(
                          key: Key('z_size_preset_${s.label}'),
                          theme: t,
                          label: s.label,
                          selected: _preset?.label == s.label,
                          bestFit:
                              _bestFit?.label == s.label ? l.bestFit : null,
                          onTap: () => _pickPreset(s),
                        ),
                      ),
                  ],
                );
              }),
            ],
          );

    final fields = Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(child: _field(_Field.height, l.height, _h, _hFocus)),
        _times(),
        Expanded(child: _field(_Field.width, l.width, _w, _wFocus)),
        _times(),
        Expanded(child: _field(_Field.depth, l.depth, _d, _dFocus)),
      ],
    );

    final autoFilled = _estimated.contains(_Field.width)
        ? '${l.width.split(' ').first} ${l.autoFilledHint}'
        : _estimated.contains(_Field.height)
            ? '${l.height.split(' ').first} ${l.autoFilledHint}'
            : '';
    final depth = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$autoFilled${l.depthHint}',
            style: _text(12, color: t.sheetMutedColor)),
        const SizedBox(height: 4),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final p in ZDepthPreset.all)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _DepthChip(
                    key: Key('z_size_depth_${p.label}'),
                    theme: t,
                    label: '${p.label} ${formatCm(p.cm)}',
                    selected: parseCm(_d.text) == p.cm,
                    onTap: () => _pickDepth(p),
                  ),
                ),
            ],
          ),
        ),
      ],
    );

    final body = <Widget>[
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.title,
            style: TextStyle(
              fontFamily: t.titleFontFamily ?? t.fontFamily,
              fontSize: keyboard ? 28 : 32,
              height: 1,
              color: t.sheetTextColor,
              letterSpacing: 0.6,
              decoration: TextDecoration.none,
            ),
          ),
          if (!keyboard) ...[
            const SizedBox(height: 4),
            Text(l.subtitle, style: _text(14, color: t.sheetMutedColor)),
          ],
        ],
      ),
      if (keyboard) ...[
        fields,
        depth,
        if (grid != null) grid,
      ] else ...[
        if (info != null) info,
        if (grid != null) grid,
        fields,
        depth,
        if (grid != null)
          Text(l.detailsNote,
              textAlign: TextAlign.center,
              style: _text(12, color: t.sheetMutedColor))
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.howTitle.toUpperCase(),
                  style: _text(12,
                          color: t.sheetMutedColor, weight: FontWeight.w500)
                      .copyWith(letterSpacing: 0.7)),
              const SizedBox(height: 8),
              Text(l.howBody, style: _text(13, color: t.sheetMutedColor)),
            ],
          ),
      ],
    ];

    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
        child: Container(
          key: const Key('z_size_sheet'),
          decoration: BoxDecoration(
            color: t.sheetColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 4),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: t.sheetBorderColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  key: const Key('z_size_scroll'),
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < body.length; i++) ...[
                        if (i > 0) const SizedBox(height: 16),
                        body[i],
                      ],
                    ],
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.fromLTRB(
                  24,
                  keyboard ? 8 : 12,
                  24,
                  keyboard ? 8 : 8 + mq.padding.bottom,
                ),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: t.sheetBorderColor)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SheetButton(
                      key: const Key('z_size_confirm'),
                      theme: t,
                      label: confirmLabel,
                      onTap: _valid ? _confirm : null,
                    ),
                    if (!keyboard) ...[
                      const SizedBox(height: 4),
                      GestureDetector(
                        key: const Key('z_size_keep'),
                        behavior: HitTestBehavior.opaque,
                        onTap: widget.onKeepEstimate,
                        child: SizedBox(
                          height: 44,
                          child: Center(
                            child: Text(
                              l.keepEstimate,
                              style: _text(16).copyWith(
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _times() => SizedBox(
        width: 18,
        height: 44,
        child: Center(
            child: Text('×', style: _text(16, color: t.sheetMutedColor))),
      );

  Widget _field(
    _Field f,
    String label,
    TextEditingController c,
    FocusNode focus,
  ) {
    final estimated = _estimated.contains(f);
    final focused = focus.hasFocus;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            maxLines: 1,
            overflow: TextOverflow.fade,
            softWrap: false,
            style: _text(12, color: t.sheetMutedColor)),
        const SizedBox(height: 4),
        CustomPaint(
          foregroundPainter: estimated && !focused
              ? _DashedBorderPainter(t.sheetEstimatedBorderColor)
              : null,
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: estimated && !focused
                  ? t.sheetEstimatedFillColor
                  : t.sheetFieldColor,
              borderRadius: BorderRadius.circular(4),
              border: estimated && !focused
                  ? null
                  : Border.all(
                      color: focused ? t.sheetAccentColor : t.sheetBorderColor,
                      width: focused ? 2 : 1,
                    ),
              boxShadow: focused
                  ? [
                      BoxShadow(
                        color: t.sheetAccentColor.withValues(alpha: 0.18),
                        spreadRadius: 3,
                      ),
                    ]
                  : null,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            alignment: Alignment.centerLeft,
            child: TextField(
              decoration: const InputDecoration.collapsed(hintText: ''),
              key: Key('z_size_field_${f.name}'),
              controller: c,
              focusNode: focus,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,≈ ]')),
              ],
              style: _text(16,
                  color: estimated ? t.sheetMutedColor : t.sheetTextColor),
              cursorColor: t.sheetAccentColor,
              onTap: () {
                if (estimated) {
                  // Start from the number, without the "≈ ".
                  final v = parseCm(c.text);
                  c.text = v == null ? '' : formatCm(v);
                  c.selection = TextSelection.collapsed(offset: c.text.length);
                }
              },
              onChanged: (v) => _typed(f, v),
              textInputAction: f == _Field.depth
                  ? TextInputAction.done
                  : TextInputAction.next,
            ),
          ),
        ),
      ],
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  _DashedBorderPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    drawDashedPath(
      canvas,
      Path()
        ..addRRect(RRect.fromRectAndRadius(
          Offset.zero & size,
          const Radius.circular(4),
        )),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
      dash: 4,
      gap: 3,
    );
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) => old.color != color;
}

class _PresetButton extends StatelessWidget {
  final ZImageEditorTheme theme;
  final String label;
  final bool selected;
  final String? bestFit;
  final VoidCallback onTap;

  const _PresetButton({
    super.key,
    required this.theme,
    required this.label,
    required this.selected,
    required this.bestFit,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: selected ? t.sheetSelectedFillColor : t.sheetFieldColor,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: selected ? t.sheetAccentColor : t.sheetBorderColor,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label,
                    style: TextStyle(
                      fontFamily: t.fontFamily,
                      fontSize: 14,
                      color: t.sheetTextColor,
                      fontWeight:
                          selected ? FontWeight.w500 : FontWeight.normal,
                    )),
                if (bestFit != null)
                  Text(bestFit!,
                      style: TextStyle(
                        fontFamily: t.fontFamily,
                        fontSize: 12,
                        color: t.sheetBestFitColor,
                      )),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DepthChip extends StatelessWidget {
  final ZImageEditorTheme theme;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _DepthChip({
    super.key,
    required this.theme,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          height: 44,
          child: Center(
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? t.sheetSelectedFillColor : t.sheetFieldColor,
                borderRadius: BorderRadius.circular(40),
                border: Border.all(
                  color: selected ? t.sheetAccentColor : t.sheetBorderColor,
                  width: selected ? 1.5 : 1,
                ),
              ),
              child: Text(label,
                  style: TextStyle(
                    fontFamily: t.fontFamily,
                    fontSize: 14,
                    color: t.sheetTextColor,
                    fontWeight: selected ? FontWeight.w500 : FontWeight.normal,
                  )),
            ),
          ),
        ),
      ),
    );
  }
}

class _SheetButton extends StatelessWidget {
  final ZImageEditorTheme theme;
  final String label;
  final VoidCallback? onTap;

  const _SheetButton({
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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/themed_controls.dart';
import '../theme/z_image_editor_theme.dart';
import 'artwork_size.dart';
import 'sheet_parts.dart';

/// Texts of the size sheet.
class ZSizeSheetLabels {
  final String title;
  final String subtitle;
  final String estimatedShape;
  final String checkHint;
  final String noMatchHint;
  final String commonSizes;
  final String dimensions;

  /// Heading of the fields when the size is for an outline inside the
  /// frame (the mat window, the artwork).
  final String dimensionsWithoutFrame;
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
    this.commonSizes = 'Common sizes, height × width (cm)',
    this.dimensions = 'Dimensions, including frame (cm)',
    this.dimensionsWithoutFrame = 'Dimensions, without frame (cm)',
    this.height = 'Height',
    this.width = 'Width',
    this.depth = 'Depth',
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
  bool includesFrame = true,
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
      includesFrame: includesFrame,
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

  /// Whether the size is for the outermost outline (the fields are headed
  /// "including frame") or for one inside the frame ("without frame").
  final bool includesFrame;
  final ValueChanged<ZArtworkSize> onConfirm;
  final VoidCallback onKeepEstimate;

  const ZArtworkSizeSheet({
    super.key,
    required this.theme,
    this.labels = const ZSizeSheetLabels(),
    this.estimatedAspectHW,
    this.initial,
    this.includesFrame = true,
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

  /// The fields row and the depth chips below it: scrolled into view above
  /// the keyboard when a field gets focus or the keyboard opens.
  final _fieldsKey = GlobalKey(debugLabel: 'z_size_fields');
  double _lastInset = 0;

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
    } else if (init != null &&
        (init.heightCm != _bestFit?.heightCm ||
            init.widthCm != _bestFit?.widthCm)) {
      // An estimate that is not this shape's common size (measured against
      // another outline, or no common size has the shape): shown as the
      // estimate it is, so typing one side still fills in the other.
      _h.text = '≈ ${formatCm(init.heightCm)}';
      _w.text = '≈ ${formatCm(init.widthCm)}';
      _estimated.addAll([_Field.height, _Field.width]);
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
      f.addListener(() {
        // Only the field's border changes: the widget tree stays the same,
        // so the focused EditableText is never rebuilt from scratch.
        setState(() {});
        if (f.hasFocus) _revealFields();
      });
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

  bool get _anyFocus =>
      _hFocus.hasFocus || _wFocus.hasFocus || _dFocus.hasFocus;

  /// Scrolls the fields (and the depth chips under them) into view, after
  /// the frame that resized the sheet for the keyboard.
  void _revealFields() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _fieldsKey.currentContext;
      if (!mounted || ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      );
    });
  }

  double? get _height => parseCm(_h.text);
  double? get _width => parseCm(_w.text);
  double get _depth => parseCm(_d.text) ?? ZDepthPreset.defaultCm;
  bool get _valid => _height != null && _width != null;

  /// Common sizes offered for this shape (empty when none matches).
  List<ZCommonSize> get _presets {
    final aspect = widget.estimatedAspectHW;
    return aspect == null || _bestFit == null
        ? const <ZCommonSize>[]
        : ZCommonSizes.forAspect(aspect);
  }

  /// The common size the fields now hold, if any: typing clears the
  /// selection, typing a common size's numbers selects it.
  ZCommonSize? _matchingPreset() {
    final h = _height, w = _width;
    if (h == null || w == null) return null;
    for (final p in _presets) {
      if (p.heightCm == h && p.widthCm == w) return p;
    }
    return null;
  }

  void _typed(_Field f, String text) {
    setState(() {
      _estimated.remove(f);
      _preset = _matchingPreset();
      final aspect = _aspect;
      if (aspect == null || f == _Field.depth) return;
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
      _preset = _matchingPreset();
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
    final inset = mq.viewInsets.bottom;
    final keyboard = inset > 0;
    if (inset != _lastInset) {
      _lastInset = inset;
      if (keyboard && _anyFocus) _revealFields();
    }
    final l = widget.labels;
    final aspect = widget.estimatedAspectHW;
    final presets = _presets;

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
              _heading(l.commonSizes),
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

    final fields = Column(
      key: _fieldsKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading(widget.includesFrame ? l.dimensions : l.dimensionsWithoutFrame,
            key: const Key('z_size_dimensions')),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: _field(_Field.height, l.height, _h, _hFocus)),
            const SizedBox(width: 16),
            Expanded(child: _field(_Field.width, l.width, _w, _wFocus)),
            const SizedBox(width: 16),
            Expanded(child: _field(_Field.depth, l.depth, _d, _dFocus)),
          ],
        ),
      ],
    );

    final estimatedWidth = _estimated.contains(_Field.width);
    final estimatedHeight = _estimated.contains(_Field.height);
    final autoFilled = estimatedWidth == estimatedHeight
        ? '' // neither, or both (the step's estimate, nothing typed yet)
        : estimatedWidth
            ? '${l.width.split(' ').first} ${l.autoFilledHint}'
            : '${l.height.split(' ').first} ${l.autoFilledHint}';
    final depth = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$autoFilled${l.depthHint}',
            key: const Key('z_size_depth_hint'),
            style: _text(14, color: t.sizeHelperColor).copyWith(height: 1.35)),
        const SizedBox(height: 4),
        // All four chips in view (wrapping onto a second line on narrow
        // phones) rather than a sideways scroll that could hide one or
        // scroll under the finger. Chip widths do not depend on the
        // selection, so the wrap never reflows when one is picked.
        Wrap(
          key: const Key('z_size_depths'),
          spacing: 8,
          children: [
            for (final p in ZDepthPreset.all)
              _DepthChip(
                key: Key('z_size_depth_${p.label}'),
                theme: t,
                label: '${p.label} ${formatCm(p.cm)}',
                selected: parseCm(_d.text) == p.cm,
                onTap: () => _pickDepth(p),
              ),
          ],
        ),
      ],
    );

    // One fixed order, keyboard or not. Moving the fields to another place
    // in this list when the keyboard opened recreated them: the focused
    // field was disposed, focus and the keyboard went away, and the sheet
    // jumped back ("blinks, no keyboard"). With the keyboard up the sheet
    // only scrolls the fields into view ([_revealFields]).
    final body = <Widget>[
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.title,
            style: TextStyle(
              fontFamily: t.titleFontFamily ?? t.fontFamily,
              fontSize: 32,
              height: 1,
              color: t.sheetTextColor,
              letterSpacing: 0.6,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 4),
          Text(l.subtitle, style: _text(14, color: t.sheetMutedColor)),
        ],
      ),
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
            _heading(l.howTitle),
            const SizedBox(height: 8),
            Text(l.howBody, style: _text(14, color: t.sizeHelperColor)),
          ],
        ),
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
                    ZSheetButton(
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

  /// Section heading and field label: 18 px in [ZImageEditorTheme.sizeLabelColor].
  Widget _heading(String text, {Key? key}) => Text(
        text,
        key: key,
        maxLines: 1,
        overflow: TextOverflow.fade,
        softWrap: false,
        style: _text(18, color: t.sizeLabelColor).copyWith(height: 1),
      );

  Widget _field(
    _Field f,
    String label,
    TextEditingController c,
    FocusNode focus,
  ) {
    final estimated = _estimated.contains(f);
    final focused = focus.hasFocus;
    final dashed = estimated && !focused;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading(label),
        const SizedBox(height: 4),
        CustomPaint(
          key: Key('z_size_box_${f.name}'),
          foregroundPainter:
              dashed ? _DashedBorderPainter(t.sizeFieldEstimatedColor) : null,
          child: Container(
            height: 48,
            // A 2 px border in every state (in the fill colour when idle),
            // so focusing or estimating never changes the field's size.
            decoration: BoxDecoration(
              color: t.sizeFieldColor,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: focused ? t.sizeFieldFocusColor : t.sizeFieldColor,
                width: 2,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
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
              style: _text(18, color: t.sizeFieldTextColor),
              cursorColor: t.sizeFieldFocusColor,
              onTap: () {
                if (estimated) {
                  // Start from the number, without the "≈ ".
                  // One value update (text + caret); the field itself is
                  // not rebuilt, so it keeps focus.
                  final v = parseCm(c.text);
                  final text = v == null ? '' : formatCm(v);
                  c.value = TextEditingValue(
                    text: text,
                    selection: TextSelection.collapsed(offset: text.length),
                  );
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
        // On the 2 px border: the stroke's middle is 1 px inside.
        ..addRRect(RRect.fromRectAndRadius(
          (Offset.zero & size).deflate(1),
          const Radius.circular(3),
        )),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
      dash: 6,
      gap: 4,
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
    final fill = selected ? t.sizeOptionSelectedColor : t.sizeOptionColor;
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          // Same 1 px border (in the fill colour) and the same text weight
          // in both states: selecting only changes colours, never the size
          // or the label's position.
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: fill),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label,
                    style: TextStyle(
                      fontFamily: t.fontFamily,
                      fontSize: 16,
                      height: 1.15,
                      color: selected
                          ? t.sizeOptionSelectedTextColor
                          : t.sizeOptionTextColor,
                    )),
                if (bestFit != null)
                  Text(bestFit!,
                      style: TextStyle(
                        fontFamily: t.fontFamily,
                        fontSize: 12,
                        height: 1.15,
                        color: selected
                            ? t.sizeOptionBestFitColor
                            : t.sizeOptionTextColor,
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
    final fill = selected ? t.sizeOptionSelectedColor : t.sizeOptionColor;
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          height: 44,
          // widthFactor 1: as wide as the pill, not the whole row (a Wrap
          // gives its children the full width to grow into).
          child: Center(
            widthFactor: 1,
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: fill,
                borderRadius: BorderRadius.circular(40),
                border: Border.all(color: fill),
              ),
              child: Center(
                widthFactor: 1,
                child: Text(label,
                    style: TextStyle(
                      fontFamily: t.fontFamily,
                      fontSize: 16,
                      color: selected
                          ? t.sizeOptionSelectedTextColor
                          : t.sizeOptionTextColor,
                    )),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

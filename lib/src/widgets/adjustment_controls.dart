import 'package:monogram_image_editor/src/controller/image_editor_controller.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:monogram_image_editor/src/widgets/liquid_glass.dart';

enum AdjustmentType {
  brightness,
  contrast,
  saturation,
}

/// Adjustment controls for brightness, contrast, and saturation
class AdjustmentControls extends StatefulWidget {
  final ImageEditorController controller;

  const AdjustmentControls({
    Key? key,
    required this.controller,
  }) : super(key: key);

  @override
  State<AdjustmentControls> createState() => _AdjustmentControlsState();
}

class _AdjustmentControlsState extends State<AdjustmentControls> {
  AdjustmentType _selectedType = AdjustmentType.brightness;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, child) {
        final state = widget.controller.state;

        return Container(
          padding: const EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: 5,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon buttons row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildIconButton(
                    icon: CupertinoIcons.sun_max,
                    label: 'Brightness',
                    type: AdjustmentType.brightness,
                  ),
                  _buildIconButton(
                    icon: CupertinoIcons.circle_lefthalf_fill,
                    label: 'Contrast',
                    type: AdjustmentType.contrast,
                  ),
                  _buildIconButton(
                    icon: CupertinoIcons.drop,
                    label: 'Saturation',
                    type: AdjustmentType.saturation,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Single slider based on selected type
              _buildSlider(state),
            ],
          ),
        );
      },
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required String label,
    required AdjustmentType type,
  }) {
    final isSelected = _selectedType == type;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedType = type;
        });
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GlassContainer(
            width: 48,
            height: 48,
            borderRadius: 50,
            child: Icon(
              icon,
              color: isSelected ? CupertinoColors.systemBlue : Colors.white70,
              size: 20,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white70,
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlider(state) {
    double value;
    double min;
    double max;
    String label;
    ValueChanged<double> onChanged;

    switch (_selectedType) {
      case AdjustmentType.brightness:
        value = state.brightness;
        min = -100;
        max = 100;
        label = 'Brightness';
        onChanged = widget.controller.setBrightness;
        break;
      case AdjustmentType.contrast:
        value = state.contrast;
        min = 0.5;
        max = 2.0;
        label = 'Contrast';
        onChanged = widget.controller.setContrast;
        break;
      case AdjustmentType.saturation:
        value = state.saturation;
        min = 0.0;
        max = 2.0;
        label = 'Saturation';
        onChanged = widget.controller.setSaturation;
        break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          // mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Text(
              value.toStringAsFixed(1),
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
            if (value !=
                (_selectedType == AdjustmentType.brightness
                    ? 0
                    : _selectedType == AdjustmentType.contrast
                        ? 1.0
                        : 1.0)) ...[
              const SizedBox(width: 12),
              GestureDetector(
                  onTap: () {
                    setState(() {
                      switch (_selectedType) {
                        case AdjustmentType.brightness:
                          widget.controller.setBrightness(0);
                          break;
                        case AdjustmentType.contrast:
                          widget.controller.setContrast(1.0);
                          break;
                        case AdjustmentType.saturation:
                          widget.controller.setSaturation(1.0);
                          break;
                      }
                    });
                  },
                  child:
                      const Icon(Icons.undo, color: Colors.white70, size: 20)),
            ]
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: CupertinoColors.systemBlue,
            inactiveTrackColor: Colors.white24,
            thumbColor: Colors.white,
            overlayColor: CupertinoColors.systemBlue.withOpacity(0.2),
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

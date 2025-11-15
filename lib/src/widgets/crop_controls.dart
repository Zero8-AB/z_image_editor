import 'package:monogram_image_editor/monogram_image_editor.dart';
import 'package:monogram_image_editor/src/controller/image_editor_controller.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Crop and rotation controls combined (iOS-style)
class CropControls extends StatefulWidget {
  final ImageEditorController controller;

  const CropControls({
    Key? key,
    required this.controller,
  }) : super(key: key);

  @override
  State<CropControls> createState() => _CropControlsState();
}

class _CropControlsState extends State<CropControls> {
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
              // Fine rotation slider
              Row(
                children: [
                  const Icon(
                    CupertinoIcons.rotate_right,
                    color: Colors.white70,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Angle',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              '${state.fineRotation.toStringAsFixed(0)}°',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        SliderTheme(
                          data: SliderThemeData(
                            activeTrackColor: CupertinoColors.systemBlue,
                            inactiveTrackColor: Colors.white24,
                            thumbColor: Colors.white,
                            overlayColor:
                                CupertinoColors.systemBlue.withOpacity(0.2),
                            trackHeight: 2,
                            thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 6),
                          ),
                          child: Slider(
                            value: state.fineRotation,
                            min: -45,
                            max: 45,
                            onChanged: widget.controller.setFineRotation,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

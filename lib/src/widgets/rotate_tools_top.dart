import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_editor/image_editor.dart';
import 'package:image_editor/src/controller/image_editor_controller.dart';
import 'package:image_editor/src/widgets/liquid_glass.dart';

class RotateTools extends StatelessWidget {
  final ImageEditorController controller;
  final ImageEditorState state;
  const RotateTools({super.key, required this.controller, required this.state});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: GlassContainer(
        height: 45,
        child: Row(
          // move the rotate controls
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            ListenableBuilder(
              listenable: controller,
              builder: (context, child) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(width: 8),
                    _buildActionButton(
                      icon: CupertinoIcons.arrow_left_right,
                      label: 'Flip H',
                      isActive: state.flipHorizontal,
                      onTap: controller.flipHorizontal,
                    ),
                    const SizedBox(width: 24),
                    _buildActionButton(
                      icon: CupertinoIcons.rotate_left,
                      label: 'Rotate',
                      isActive: state.rotation != 0.0,
                      onTap: controller.rotate90,
                    ),
                    const SizedBox(width: 8),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Icon(
          icon,
          color: Colors.white,
          size: 32,
        ),
      ),
    );
  }
}

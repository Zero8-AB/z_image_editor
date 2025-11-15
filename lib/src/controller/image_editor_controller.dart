import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:monogram_image_editor/src/models/image_editor_state.dart';

class ImageEditorController extends ChangeNotifier {
  ImageEditorState _state = const ImageEditorState();

  ImageEditorState get state => _state;

  void _updateState(ImageEditorState newState) {
    _state = newState;
    notifyListeners();
  }

  void initialize({File? imageFile, Uint8List? imageBytes}) {
    _updateState(ImageEditorState(
      imageFile: imageFile,
      imageBytes: imageBytes,
    ));
  }

  void setTab(EditorTab tab) {
    _updateState(_state.copyWith(currentTab: tab));
  }

  // Adjustment controls
  void setBrightness(double value) {
    _updateState(_state.copyWith(brightness: value));
  }

  void setContrast(double value) {
    _updateState(_state.copyWith(contrast: value));
  }

  void setSaturation(double value) {
    _updateState(_state.copyWith(saturation: value));
  }

  // Rotation controls
  void rotate90() {
    final newRotation = (_state.rotation + 90) % 360;
    _updateState(_state.copyWith(rotation: newRotation, fineRotation: 0.0));
  }

  void setFineRotation(double degrees) {
    _updateState(_state.copyWith(fineRotation: degrees));
  }

  void flipHorizontal() {
    _updateState(_state.copyWith(flipHorizontal: !_state.flipHorizontal));
  }

  // Crop controls
  void setCropRect(CropRect rect) {
    _updateState(_state.copyWith(cropRect: rect));
  }

  void resetCrop() {
    _updateState(_state.copyWith(clearCropRect: true));
  }

  // Zoom and pan controls
  void setScale(double scale) {
    _updateState(_state.copyWith(scale: scale));
  }

  void setPanOffset(Offset offset) {
    _updateState(_state.copyWith(panOffset: offset));
  }

  void resetZoom() {
    _updateState(_state.copyWith(scale: 1.0, panOffset: Offset.zero));
  }

  // Reset all adjustments
  void reset() {
    _updateState(ImageEditorState(
      imageFile: _state.imageFile,
      imageBytes: _state.imageBytes,
    ));
  }

  // Get the current image data
  dynamic get currentImage => _state.imageFile ?? _state.imageBytes;
}

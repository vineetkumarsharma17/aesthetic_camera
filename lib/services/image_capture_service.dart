import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/painting.dart';
import 'package:gal/gal.dart';

import '../filters/filter_model.dart';
import '../filters/shader_manager.dart';

/// Captures a full-resolution still and bakes the selected filter into it on
/// the GPU, then saves the result to the device gallery.
///
/// The filter is applied with the exact same fragment shader used for the live
/// preview, so what the user sees is what they get. Pixel work stays on the
/// GPU (a shader pass into a [ui.PictureRecorder]); the only CPU touch is the
/// one-off PNG encode required to hand bytes to the gallery.
class ImageCaptureService {
  const ImageCaptureService({required this.shaderManager});

  final ShaderManager shaderManager;

  static const String _albumName = 'Aesthetic Camera';

  /// Takes a picture, renders it through [filter]'s shader, and returns the
  /// encoded PNG bytes.
  Future<Uint8List> captureFiltered({
    required CameraController controller,
    required FilterModel filter,
  }) async {
    final XFile shot = await controller.takePicture();
    final Uint8List raw = await shot.readAsBytes();

    // Decode honouring EXIF orientation so the still is upright.
    final ui.Image source = await decodeImageFromList(raw);

    try {
      return await _applyShader(source, filter);
    } finally {
      source.dispose();
    }
  }

  /// Runs a single GPU shader pass over [source] and encodes the output.
  Future<Uint8List> _applyShader(ui.Image source, FilterModel filter) async {
    final width = source.width;
    final height = source.height;

    final shader = shaderManager.fragmentShader(filter.shaderAsset)
      ..setFloat(0, width.toDouble())
      ..setFloat(1, height.toDouble())
      ..setFloat(2, 0.0) // static grain for a still
      ..setImageSampler(0, source);

    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawRect(
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      Paint()..shader = shader,
    );
    final ui.Picture picture = recorder.endRecording();

    try {
      final ui.Image filtered = await picture.toImage(width, height);
      try {
        final ByteData? png =
            await filtered.toByteData(format: ui.ImageByteFormat.png);
        if (png == null) {
          throw StateError('Failed to encode captured image.');
        }
        return png.buffer.asUint8List();
      } finally {
        filtered.dispose();
      }
    } finally {
      picture.dispose();
      shader.dispose();
    }
  }

  /// Persists [pngBytes] to the gallery, requesting access if needed.
  Future<void> saveToGallery(Uint8List pngBytes) async {
    if (!await Gal.hasAccess()) {
      final granted = await Gal.requestAccess();
      if (!granted) {
        throw const GalleryAccessDeniedException();
      }
    }
    await Gal.putImageBytes(pngBytes, album: _albumName);
  }
}

/// Thrown when the user declines gallery write access.
class GalleryAccessDeniedException implements Exception {
  const GalleryAccessDeniedException();

  @override
  String toString() => 'Gallery access was denied.';
}

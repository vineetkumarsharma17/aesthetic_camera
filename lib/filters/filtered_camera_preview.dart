import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_shaders/flutter_shaders.dart';

import 'filter_model.dart';
import 'filter_repository.dart';
import 'shader_manager.dart';

/// Renders the live [CameraPreview] with the currently selected fragment shader
/// applied on the GPU.
///
/// How it works:
///  * A [Ticker] advances a [ValueNotifier<double>] time value every frame.
///  * A [ValueListenableBuilder] repaints only the shader layer on each tick
///    (the [CameraPreview] child is captured once and reused — it is never
///    rebuilt, protecting the frame budget).
///  * [AnimatedSampler] snapshots the child into a GPU texture and hands it to
///    the shader as `uTexture`; the shader draws the filtered result.
///
/// The per-frame repaint is what keeps the preview *live* through the sampler
/// and simultaneously animates the film grain.
class FilteredCameraPreview extends ConsumerStatefulWidget {
  const FilteredCameraPreview({required this.controller, super.key});

  final CameraController controller;

  @override
  ConsumerState<FilteredCameraPreview> createState() =>
      _FilteredCameraPreviewState();
}

class _FilteredCameraPreviewState extends ConsumerState<FilteredCameraPreview>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final ValueNotifier<double> _time = ValueNotifier<double>(0);

  ui.FragmentShader? _shader;
  String? _loadedAsset;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      _time.value = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    })..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _shader?.dispose();
    _time.dispose();
    super.dispose();
  }

  /// Lazily (re)creates the [ui.FragmentShader] only when the selected filter
  /// changes, disposing the previous one.
  ui.FragmentShader _shaderFor(ShaderManager manager, FilterModel filter) {
    if (_loadedAsset != filter.shaderAsset) {
      _shader?.dispose();
      _shader = manager.fragmentShader(filter.shaderAsset);
      _loadedAsset = filter.shaderAsset;
    }
    return _shader!;
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(selectedFilterProvider);
    final managerAsync = ref.watch(shaderManagerProvider);

    // Built once per real rebuild (filter change / manager load) — NOT per tick.
    final preview = CameraPreview(widget.controller);

    return managerAsync.maybeWhen(
      data: (manager) {
        final shader = _shaderFor(manager, filter);
        return ValueListenableBuilder<double>(
          valueListenable: _time,
          child: preview,
          builder: (context, time, child) {
            return AnimatedSampler(
              (ui.Image image, Size size, Canvas canvas) {
                shader
                  ..setFloat(0, size.width)
                  ..setFloat(1, size.height)
                  ..setFloat(2, time)
                  ..setImageSampler(0, image);
                canvas.drawRect(
                  Offset.zero & size,
                  Paint()..shader = shader,
                );
              },
              child: child!,
            );
          },
        );
      },
      // Shaders still compiling → show the raw feed so the camera is never blank.
      orElse: () => preview,
    );
  }
}

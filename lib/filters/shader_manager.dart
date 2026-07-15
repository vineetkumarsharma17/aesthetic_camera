import 'dart:ui' as ui;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'filter_repository.dart';

/// Loads and caches compiled [ui.FragmentProgram]s once at startup so that
/// switching filters never pays an asset-load cost on the hot path.
///
/// A [ui.FragmentProgram] is the reusable, compiled shader. Calling
/// [fragmentShader] mints a lightweight [ui.FragmentShader] instance whose
/// uniforms the caller updates every frame.
class ShaderManager {
  ShaderManager._(this._programs);

  final Map<String, ui.FragmentProgram> _programs;

  /// Compiles every shader referenced by [assetKeys] in parallel.
  static Future<ShaderManager> preload(Iterable<String> assetKeys) async {
    final unique = assetKeys.toSet();
    final entries = await Future.wait(
      unique.map(
        (key) async => MapEntry(key, await ui.FragmentProgram.fromAsset(key)),
      ),
    );
    return ShaderManager._(Map.fromEntries(entries));
  }

  /// Creates a fresh [ui.FragmentShader] for [assetKey].
  ///
  /// The caller owns the returned shader: reuse it across frames (just update
  /// uniforms) and call `dispose()` when switching to another filter.
  ui.FragmentShader fragmentShader(String assetKey) {
    final program = _programs[assetKey];
    if (program == null) {
      throw ArgumentError('Shader not preloaded: $assetKey');
    }
    return program.fragmentShader();
  }
}

/// Preloads all filter shaders. The preview waits on this before rendering
/// the shader pipeline; until it resolves it shows the raw camera feed.
final shaderManagerProvider = FutureProvider<ShaderManager>((ref) {
  return ShaderManager.preload(
    FilterRepository.filters.map((f) => f.shaderAsset),
  );
});

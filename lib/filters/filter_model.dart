import 'package:flutter/foundation.dart';

/// An immutable description of a single GPU filter.
///
/// A filter is nothing more than a display name plus the fragment shader asset
/// that renders it. Keeping this data-only makes the filter set trivial to
/// extend — add an entry to the repository and a `.frag` file.
@immutable
class FilterModel {
  const FilterModel({
    required this.id,
    required this.name,
    required this.shaderAsset,
  });

  /// Stable identifier (used as a key / for analytics).
  final String id;

  /// Human-readable label shown in the carousel.
  final String name;

  /// Path to the fragment shader, e.g. `assets/shaders/aesthetic.frag`.
  ///
  /// Every shader shares the same uniform layout:
  ///   float 0,1 → resolution (uSize), float 2 → time (uTime),
  ///   sampler 0 → source texture (uTexture).
  final String shaderAsset;

  @override
  bool operator ==(Object other) =>
      other is FilterModel && other.id == id && other.shaderAsset == shaderAsset;

  @override
  int get hashCode => Object.hash(id, shaderAsset);
}

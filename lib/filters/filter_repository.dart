import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'filter_model.dart';

/// The catalogue of available filters, in carousel order.
///
/// This is the single source of truth for both the shader preloader and the
/// carousel UI, so the two can never drift out of sync.
class FilterRepository {
  const FilterRepository();

  static const List<FilterModel> filters = <FilterModel>[
    FilterModel(
      id: 'original',
      name: 'Original',
      shaderAsset: 'assets/shaders/original.frag',
    ),
    FilterModel(
      id: 'aesthetic',
      name: 'Aesthetic',
      shaderAsset: 'assets/shaders/aesthetic.frag',
    ),
    FilterModel(
      id: 'vintage',
      name: 'Vintage',
      shaderAsset: 'assets/shaders/vintage.frag',
    ),
    FilterModel(
      id: 'cinematic',
      name: 'Cinematic',
      shaderAsset: 'assets/shaders/cinematic.frag',
    ),
  ];
}

/// Index of the currently selected filter. Owned here so the carousel, the
/// preview, and the capture pipeline all read the same selection.
class SelectedFilterNotifier extends Notifier<int> {
  @override
  int build() => 0; // default: Original

  void select(int index) {
    if (index >= 0 && index < FilterRepository.filters.length) {
      state = index;
    }
  }
}

final selectedFilterIndexProvider =
    NotifierProvider<SelectedFilterNotifier, int>(SelectedFilterNotifier.new);

/// The resolved [FilterModel] for the current selection.
final selectedFilterProvider = Provider<FilterModel>((ref) {
  final index = ref.watch(selectedFilterIndexProvider);
  return FilterRepository.filters[index];
});

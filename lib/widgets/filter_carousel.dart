import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../filters/filter_model.dart';
import '../filters/filter_repository.dart';

/// Horizontal, snap-to-center filter picker shown at the bottom of the screen.
///
/// Selection lives in [selectedFilterIndexProvider]; tapping a chip updates it
/// and the preview reacts instantly. The list auto-centers the active chip so
/// the current filter is always in the middle — Snapchat/TikTok style.
class FilterCarousel extends ConsumerStatefulWidget {
  const FilterCarousel({super.key});

  @override
  ConsumerState<FilterCarousel> createState() => _FilterCarouselState();
}

class _FilterCarouselState extends ConsumerState<FilterCarousel> {
  static const double _itemWidth = 76;

  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _centerOn(int index) {
    if (!_scrollController.hasClients) return;
    // With symmetric leading/trailing padding of (viewport - itemWidth)/2, the
    // offset that centers item i is simply i * itemWidth.
    final target = index * _itemWidth;
    final max = _scrollController.position.maxScrollExtent;
    _scrollController.animateTo(
      target.clamp(0.0, max),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  void _select(int index) {
    HapticFeedback.selectionClick();
    ref.read(selectedFilterIndexProvider.notifier).select(index);
  }

  @override
  Widget build(BuildContext context) {
    // Keep the active chip centered whenever selection changes (tap or swipe).
    ref.listen<int>(selectedFilterIndexProvider, (_, next) => _centerOn(next));

    final selected = ref.watch(selectedFilterIndexProvider);
    final width = MediaQuery.sizeOf(context).width;
    final sidePadding = (width - _itemWidth) / 2;

    return SizedBox(
      height: 96,
      child: ListView.builder(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: sidePadding),
        itemCount: FilterRepository.filters.length,
        itemBuilder: (context, index) {
          final filter = FilterRepository.filters[index];
          return SizedBox(
            width: _itemWidth,
            child: _FilterChip(
              filter: filter,
              selected: index == selected,
              onTap: () => _select(index),
            ),
          );
        },
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.filter,
    required this.selected,
    required this.onTap,
  });

  final FilterModel filter;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            width: selected ? 60 : 52,
            height: selected ? 60 : 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: _swatchGradient(filter.id),
              border: Border.all(
                color: selected ? accent : Colors.white24,
                width: selected ? 3 : 1.5,
              ),
              boxShadow: selected
                  ? [BoxShadow(color: accent.withValues(alpha: 0.5), blurRadius: 12)]
                  : null,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            filter.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: selected ? accent : Colors.white70,
              fontSize: 12,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  /// A small representative swatch for each filter (no live thumbnails in MVP).
  LinearGradient _swatchGradient(String id) {
    switch (id) {
      case 'aesthetic':
        return const LinearGradient(
          colors: [Color(0xFFE8CDA5), Color(0xFFB98D5E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case 'vintage':
        return const LinearGradient(
          colors: [Color(0xFFC7A16B), Color(0xFF6E5233)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case 'cinematic':
        return const LinearGradient(
          colors: [Color(0xFF1E6E78), Color(0xFFE28A3D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case 'original':
      default:
        return const LinearGradient(
          colors: [Color(0xFF9E9E9E), Color(0xFF5A5A5A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
    }
  }
}

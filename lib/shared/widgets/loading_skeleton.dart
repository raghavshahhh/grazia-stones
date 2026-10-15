import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Theme-aware skeleton colours: charcoal blocks looked broken on light screens.
Color _base(BuildContext c) =>
    Theme.of(c).brightness == Brightness.dark ? const Color(0xFF1A1A1A) : const Color(0xFFE9E2D2);
Color _highlight(BuildContext c) =>
    Theme.of(c).brightness == Brightness.dark ? const Color(0xFF2A2A2A) : const Color(0xFFF7F2E7);

class LoadingSkeleton extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const LoadingSkeleton({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 12,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: _base(context),
      highlightColor: _highlight(context),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: _base(context),
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

class StoneGridSkeleton extends StatelessWidget {
  const StoneGridSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: _base(context),
      highlightColor: _highlight(context),
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.7,
        ),
        itemCount: 6,
        itemBuilder: (_, _) => Container(
          decoration: BoxDecoration(
            color: _base(context),
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

class CollectionListSkeleton extends StatelessWidget {
  const CollectionListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: _base(context),
      highlightColor: _highlight(context),
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        itemCount: 4,
        itemBuilder: (_, _) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            height: 100,
            decoration: BoxDecoration(
              color: _base(context),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }
}

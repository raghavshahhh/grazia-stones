import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Loading skeleton for product cards
class ProductCardSkeleton extends StatelessWidget {
  const ProductCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image skeleton
          _SkeletonBox(
            height: 200,
            borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
          ),
          
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title skeleton
                _SkeletonBox(height: 16, width: double.infinity),
                const SizedBox(height: 8),
                
                // Subtitle skeleton
                _SkeletonBox(height: 14, width: 150),
                const SizedBox(height: 12),
                
                // Price skeleton
                _SkeletonBox(height: 18, width: 100),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Loading skeleton for list items
class ListItemSkeleton extends StatelessWidget {
  const ListItemSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Leading image
          _SkeletonBox(width: 60, height: 60, borderRadius: BorderRadius.circular(8)),
          const SizedBox(width: 12),
          
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SkeletonBox(height: 16, width: double.infinity),
                const SizedBox(height: 8),
                _SkeletonBox(height: 14, width: 200),
                const SizedBox(height: 8),
                _SkeletonBox(height: 14, width: 100),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Loading skeleton for detailed view
class DetailSkeleton extends StatelessWidget {
  const DetailSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Large image skeleton
          _SkeletonBox(
            height: 300,
            width: double.infinity,
            borderRadius: BorderRadius.circular(12),
          ),
          const SizedBox(height: 24),
          
          // Title
          _SkeletonBox(height: 24, width: double.infinity),
          const SizedBox(height: 12),
          
          // Subtitle
          _SkeletonBox(height: 16, width: 250),
          const SizedBox(height: 24),
          
          // Price
          _SkeletonBox(height: 28, width: 150),
          const SizedBox(height: 32),
          
          // Description lines
          _SkeletonBox(height: 14, width: double.infinity),
          const SizedBox(height: 8),
          _SkeletonBox(height: 14, width: double.infinity),
          const SizedBox(height: 8),
          _SkeletonBox(height: 14, width: 280),
          const SizedBox(height: 24),
          
          // Buttons
          Row(
            children: [
              Expanded(child: _SkeletonBox(height: 48, width: double.infinity)),
              const SizedBox(width: 12),
              Expanded(child: _SkeletonBox(height: 48, width: double.infinity)),
            ],
          ),
        ],
      ),
    );
  }
}

/// Grid skeleton for product grids
class ProductGridSkeleton extends StatelessWidget {
  final int itemCount;
  final int crossAxisCount;

  const ProductGridSkeleton({
    super.key,
    this.itemCount = 6,
    this.crossAxisCount = 2,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: 0.7,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) => const ProductCardSkeleton(),
    );
  }
}

/// List skeleton for list views
class ListViewSkeleton extends StatelessWidget {
  final int itemCount;

  const ListViewSkeleton({
    super.key,
    this.itemCount = 10,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: itemCount,
      itemBuilder: (context, index) => const ListItemSkeleton(),
    );
  }
}

/// Basic skeleton box with shimmer effect
class _SkeletonBox extends StatelessWidget {
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;

  const _SkeletonBox({
    this.width,
    this.height,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: borderRadius ?? BorderRadius.circular(4),
        ),
      ),
    );
  }
}

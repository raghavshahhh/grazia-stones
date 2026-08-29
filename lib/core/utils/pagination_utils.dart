import 'package:flutter/material.dart';

/// Pagination state
class PaginationState<T> {
  final List<T> items;
  final bool isLoading;
  final bool hasMore;
  final int currentPage;
  final String? error;

  const PaginationState({
    this.items = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.currentPage = 0,
    this.error,
  });

  PaginationState<T> copyWith({
    List<T>? items,
    bool? isLoading,
    bool? hasMore,
    int? currentPage,
    String? error,
  }) {
    return PaginationState<T>(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      currentPage: currentPage ?? this.currentPage,
      error: error,
    );
  }
}

/// Pagination controller for infinite scroll
class PaginationController {
  final ScrollController scrollController;
  final VoidCallback onLoadMore;
  final double threshold;

  PaginationController({
    required this.onLoadMore,
    this.threshold = 200.0,
  }) : scrollController = ScrollController() {
    scrollController.addListener(_scrollListener);
  }

  void _scrollListener() {
    if (scrollController.position.pixels >=
        scrollController.position.maxScrollExtent - threshold) {
      onLoadMore();
    }
  }

  void dispose() {
    scrollController.dispose();
  }
}

/// Paginated list view widget
class PaginatedListView<T> extends StatelessWidget {
  final PaginationState<T> state;
  final Widget Function(BuildContext, T, int) itemBuilder;
  final VoidCallback onLoadMore;
  final Widget? loadingWidget;
  final Widget? emptyWidget;
  final Widget Function(String)? errorBuilder;
  final EdgeInsets? padding;
  final ScrollController? scrollController;

  const PaginatedListView({
    super.key,
    required this.state,
    required this.itemBuilder,
    required this.onLoadMore,
    this.loadingWidget,
    this.emptyWidget,
    this.errorBuilder,
    this.padding,
    this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    // Show error
    if (state.error != null && state.items.isEmpty) {
      return errorBuilder?.call(state.error!) ??
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text(state.error!),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: onLoadMore,
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
    }

    // Show loading for first page
    if (state.isLoading && state.items.isEmpty) {
      return loadingWidget ?? const Center(child: CircularProgressIndicator());
    }

    // Show empty state
    if (state.items.isEmpty) {
      return emptyWidget ??
          const Center(
            child: Text('No items found'),
          );
    }

    // Show list with items
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollEndNotification &&
            notification.metrics.pixels >=
                notification.metrics.maxScrollExtent - 200) {
          if (state.hasMore && !state.isLoading) {
            onLoadMore();
          }
        }
        return false;
      },
      child: ListView.builder(
        controller: scrollController,
        padding: padding,
        itemCount: state.items.length + (state.hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          // Show loading indicator at the end
          if (index >= state.items.length) {
            return const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }

          return itemBuilder(context, state.items[index], index);
        },
      ),
    );
  }
}

/// Paginated grid view widget
class PaginatedGridView<T> extends StatelessWidget {
  final PaginationState<T> state;
  final Widget Function(BuildContext, T, int) itemBuilder;
  final VoidCallback onLoadMore;
  final int crossAxisCount;
  final double childAspectRatio;
  final double crossAxisSpacing;
  final double mainAxisSpacing;
  final Widget? loadingWidget;
  final Widget? emptyWidget;
  final EdgeInsets? padding;
  final ScrollController? scrollController;

  const PaginatedGridView({
    super.key,
    required this.state,
    required this.itemBuilder,
    required this.onLoadMore,
    this.crossAxisCount = 2,
    this.childAspectRatio = 1.0,
    this.crossAxisSpacing = 16.0,
    this.mainAxisSpacing = 16.0,
    this.loadingWidget,
    this.emptyWidget,
    this.padding,
    this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    // Show loading for first page
    if (state.isLoading && state.items.isEmpty) {
      return loadingWidget ?? const Center(child: CircularProgressIndicator());
    }

    // Show empty state
    if (state.items.isEmpty) {
      return emptyWidget ??
          const Center(
            child: Text('No items found'),
          );
    }

    // Show grid with items
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollEndNotification &&
            notification.metrics.pixels >=
                notification.metrics.maxScrollExtent - 200) {
          if (state.hasMore && !state.isLoading) {
            onLoadMore();
          }
        }
        return false;
      },
      child: GridView.builder(
        controller: scrollController,
        padding: padding ?? const EdgeInsets.all(16),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          childAspectRatio: childAspectRatio,
          crossAxisSpacing: crossAxisSpacing,
          mainAxisSpacing: mainAxisSpacing,
        ),
        itemCount: state.items.length + (state.hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          // Show loading indicator at the end
          if (index >= state.items.length) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          return itemBuilder(context, state.items[index], index);
        },
      ),
    );
  }
}

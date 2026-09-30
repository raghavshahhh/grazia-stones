import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grazia_stones/features/wishlist/providers/wishlist_provider.dart';
import 'package:grazia_stones/shared/widgets/luxury_toast.dart';

/// Toggles a stone in the wishlist and tells the user what really happened.
Future<void> toggleWishlistWithFeedback(
  BuildContext context,
  WidgetRef ref,
  String stoneId, {
  String? stoneName,
}) async {
  HapticFeedback.lightImpact();
  final result = await ref.read(wishlistProvider.notifier).toggleStone(stoneId);
  if (!context.mounted) return;
  switch (result) {
    case WishlistToggleResult.added:
      LuxuryToast.show(
        context,
        message: '${stoneName ?? 'Design'} saved to Wishlist',
        icon: Icons.favorite_rounded,
        iconColor: const Color(0xFFD4AF37),
      );
    case WishlistToggleResult.removed:
      LuxuryToast.show(
        context,
        message: 'Removed from Wishlist',
        icon: Icons.favorite_border_rounded,
        iconColor: Colors.white60,
      );
    case WishlistToggleResult.needsLogin:
      LuxuryToast.show(context, message: 'Sign in to save designs to your wishlist', icon: Icons.lock_outline_rounded);
    case WishlistToggleResult.failed:
      LuxuryToast.show(context, message: "Couldn't update your wishlist. Please try again.", icon: Icons.error_outline_rounded);
  }
}

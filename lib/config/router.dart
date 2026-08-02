import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/onboarding/presentation/splash_screen.dart';
import '../features/onboarding/presentation/onboarding_screen.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/register_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/search/presentation/search_screen.dart';
import '../features/collections/presentation/collection_list_screen.dart';
import '../features/collections/presentation/collection_detail_screen.dart';
import '../features/stone_detail/presentation/stone_detail_screen.dart';
import '../features/ai_viz/presentation/ai_viz_screen.dart';
import '../features/ar_view/presentation/ar_view_screen.dart';
import '../features/dealer/presentation/dealer_locator_screen.dart';
import '../features/quotes/presentation/quotes_screen.dart';
import '../features/cart/presentation/cart_screen.dart';
import '../features/orders/presentation/orders_screen.dart';
import '../features/live_ai/presentation/live_ai_screen.dart';
import '../features/profile/presentation/profile_screen.dart';
import '../features/wishlist/presentation/wishlist_screen.dart';
import '../features/sample_order/presentation/sample_order_screen.dart';
import '../shared/widgets/grazia_bottom_nav.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();

/// Tab index → route mapping.
const _tabRoutes = [
  '/home',
  '/collections',
  '/live-ai',
  '/cart',
  '/profile',
];

/// Crossfade only — for bottom nav tab switches.
CustomTransitionPage<void> _fadePage(Widget child, GoRouterState state) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionsBuilder: (_, animation, __, child) =>
        FadeTransition(opacity: animation, child: child),
  );
}

/// Slide up + fade — for detail screens pushing onto nav stack.
CustomTransitionPage<void> _slideUpPage(Widget child, GoRouterState state) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionsBuilder: (_, animation, __, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.06),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// Slide from right — for auth / onboarding flows.
CustomTransitionPage<void> _slideRightPage(Widget child, GoRouterState state) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionsBuilder: (_, animation, __, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.3, 0),
          end: Offset.zero,
        ).animate(curved),
        child: FadeTransition(opacity: curved, child: child),
      );
    },
  );
}

/// Scale + fade — for full-screen immersive screens (AR, AI viz).
CustomTransitionPage<void> _scaleFadePage(Widget child, GoRouterState state) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionsBuilder: (_, animation, __, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.95, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// Shell with floating GraziaBottomNav. GoRouter handles all tab state.
class _ShellWithNav extends StatelessWidget {
  final Widget child;
  const _ShellWithNav({required this.child});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    int currentTab = 0;
    for (var i = 0; i < _tabRoutes.length; i++) {
      if (location.startsWith(_tabRoutes[i])) {
        currentTab = i;
        break;
      }
    }

    return Scaffold(
      extendBody: true,
      body: child,
      bottomNavigationBar: GraziaBottomNav(
        currentIndex: currentTab,
        onTap: (i) {
          if (i < _tabRoutes.length) {
            context.go(_tabRoutes[i]);
          }
        },
      ),
    );
  }
}

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    routes: [
      // --- Splash / Onboarding / Auth ---
      GoRoute(
        path: '/',
        pageBuilder: (context, state) =>
            _slideUpPage(const SplashScreen(), state),
      ),
      GoRoute(
        path: '/onboarding',
        pageBuilder: (context, state) =>
            _slideRightPage(const OnboardingScreen(), state),
      ),
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) =>
            _slideRightPage(const LoginScreen(), state),
      ),
      GoRoute(
        path: '/register',
        pageBuilder: (context, state) =>
            _slideRightPage(const RegisterScreen(), state),
      ),

      // --- Bottom nav shell (floating pill + crossfade) ---
      ShellRoute(
        builder: (context, state, child) => _ShellWithNav(child: child),
        routes: [
          GoRoute(
            path: '/home',
            pageBuilder: (context, state) =>
                _fadePage(const HomeScreen(), state),
          ),
          GoRoute(
            path: '/collections',
            pageBuilder: (context, state) =>
                _fadePage(const CollectionListScreen(), state),
          ),
          GoRoute(
            path: '/live-ai',
            pageBuilder: (context, state) =>
                _fadePage(const LiveAIScreen(), state),
          ),
          GoRoute(
            path: '/cart',
            pageBuilder: (context, state) =>
                _fadePage(const CartScreen(), state),
          ),
          GoRoute(
            path: '/profile',
            pageBuilder: (context, state) =>
                _fadePage(const ProfileScreen(), state),
          ),
        ],
      ),

      // --- Detail screens (slide up, no bottom nav) ---
      GoRoute(
        path: '/search',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) =>
            _slideUpPage(const SearchScreen(), state),
      ),
      GoRoute(
        path: '/collections/:id',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => _slideUpPage(
          CollectionDetailScreen(
              collectionId: state.pathParameters['id'] ?? ''),
          state,
        ),
      ),
      GoRoute(
        path: '/stones/:id',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => _slideUpPage(
          StoneDetailScreen(stoneId: state.pathParameters['id'] ?? ''),
          state,
        ),
      ),
      GoRoute(
        path: '/wishlist',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) =>
            _slideUpPage(const WishlistScreen(), state),
      ),
      GoRoute(
        path: '/sample-order',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) =>
            _slideUpPage(const SampleOrderScreen(), state),
      ),
      GoRoute(
        path: '/dealers',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) =>
            _slideUpPage(const DealerLocatorScreen(), state),
      ),
      GoRoute(
        path: '/quotes',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) =>
            _slideUpPage(const QuotesScreen(), state),
      ),
      GoRoute(
        path: '/orders',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) =>
            _slideUpPage(const OrdersScreen(), state),
      ),

      // --- Immersive full-screen (scale + fade, no bottom nav) ---
      GoRoute(
        path: '/ai-viz',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) =>
            _scaleFadePage(const AIScreen(), state),
      ),
      GoRoute(
        path: '/ar-view',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) =>
            _scaleFadePage(const ARViewScreen(), state),
      ),
    ],
  );
});

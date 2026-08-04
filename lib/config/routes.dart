import 'package:flutter/material.dart';
import 'package:grazia_stones/features/onboarding/presentation/splash_screen.dart';
import 'package:grazia_stones/features/onboarding/presentation/onboarding_screen.dart';
import 'package:grazia_stones/features/auth/presentation/login_screen.dart';
import 'package:grazia_stones/features/auth/presentation/register_screen.dart';
import 'package:grazia_stones/features/home/presentation/home_screen.dart';
import 'package:grazia_stones/features/search/presentation/search_screen.dart';
import 'package:grazia_stones/features/collections/presentation/collection_list_screen.dart';
import 'package:grazia_stones/features/collections/presentation/collection_detail_screen.dart';
import 'package:grazia_stones/features/stone_detail/presentation/stone_detail_screen.dart';
import 'package:grazia_stones/features/ai_viz/presentation/ai_viz_screen.dart';
import 'package:grazia_stones/features/ar_view/presentation/ar_view_screen.dart';
import 'package:grazia_stones/features/dealer/presentation/dealer_locator_screen.dart';
import 'package:grazia_stones/features/quotes/presentation/quotes_screen.dart';
import 'package:grazia_stones/features/cart/presentation/cart_screen.dart';
import 'package:grazia_stones/features/orders/presentation/orders_screen.dart';
import 'package:grazia_stones/features/live_ai/presentation/live_ai_screen.dart';
import 'package:grazia_stones/features/profile/presentation/profile_screen.dart';

class AppRoutes {
  AppRoutes._();

  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String register = '/register';
  static const String home = '/home';
  static const String search = '/search';
  static const String collections = '/collections';
  static const String collectionDetail = '/collections/:id';
  static const String stoneDetail = '/stones/:id';
  static const String aiViz = '/ai-viz';
  static const String arView = '/ar-view';
  static const String dealers = '/dealers';
  static const String quotes = '/quotes';
  static const String cart = '/cart';
  static const String orders = '/orders';
  static const String profile = '/profile';
  static const String liveAI = '/live-ai';
  static const String sampleOrder = '/sample-order';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splash:
        return _buildRoute(const SplashScreen(), settings);
      case onboarding:
        return _buildRoute(const OnboardingScreen(), settings);
      case login:
        return _buildRoute(const LoginScreen(), settings);
      case register:
        return _buildRoute(const RegisterScreen(), settings);
      case home:
        return _buildRoute(const HomeScreen(), settings);
      case search:
        return _buildRoute(const SearchScreen(), settings);
      case collections:
        return _buildRoute(const CollectionListScreen(), settings);
      case collectionDetail:
        final id = settings.arguments as String? ?? '';
        return _buildRoute(CollectionDetailScreen(collectionId: id), settings);
      case stoneDetail:
        final id = settings.arguments as String? ?? '';
        return _buildRoute(StoneDetailScreen(stoneId: id), settings);
      case aiViz:
        return _buildRoute(const AIVizScreen(), settings);
      case arView:
        return _buildRoute(const ARViewScreen(), settings);
      case dealers:
        return _buildRoute(const DealerLocatorScreen(), settings);
      case quotes:
        return _buildRoute(const QuotesScreen(), settings);
      case cart:
        return _buildRoute(const CartScreen(), settings);
      case orders:
        return _buildRoute(const OrdersScreen(), settings);
      case profile:
        return _buildRoute(const ProfileScreen(), settings);
      case liveAI:
        return _buildRoute(const LiveAIScreen(), settings);
      default:
        return _buildRoute(const SplashScreen(), settings);
    }
  }

  static PageRouteBuilder _buildRoute(Widget page, RouteSettings settings) {
    return PageRouteBuilder(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
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
      transitionDuration: const Duration(milliseconds: 450),
    );
  }
}

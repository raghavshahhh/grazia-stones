# Flutter Project Structure — Grazia Stones

```
grazia_stones/
├── android/                          # Android native shell
├── ios/                              # iOS native shell
├── lib/
│   ├── main.dart                     # Entry point, app bootstrap
│   ├── app.dart                      # MaterialApp, theme, routing
│   │
│   ├── core/                         # ── FOUNDATION ──
│   │   ├── constants/
│   │   │   ├── app_colors.dart       # Brand palette constants
│   │   │   ├── app_strings.dart      # Static strings, labels
│   │   │   ├── app_dimensions.dart   # Spacing, radius, icon sizes
│   │   │   └── api_endpoints.dart    # Base URLs, route constants
│   │   ├── theme/
│   │   │   ├── grazia_theme.dart     # ThemeData (dark + light)
│   │   │   ├── text_styles.dart      # Font scale (Display → Caption)
│   │   │   └── card_styles.dart      # Elevated, glass, stone card
│   │   ├── utils/
│   │   │   ├── formatters.dart       # Currency, phone, date
│   │   │   ├── validators.dart       # Form field validators
│   │   │   └── helpers.dart          # Snackbars, dialogs, toasts
│   │   ├── extensions/
│   │   │   ├── context_ext.dart      # Theme.of(context) shortcuts
│   │   │   └── string_ext.dart       # Slugify, capitalize
│   │   ├── di/                       # Dependency injection
│   │   │   └── injection.dart        # GetIt / Riverpod provider setup
│   │   └── network/
│   │       ├── api_client.dart       # Dio instance, interceptors
│   │       ├── auth_interceptor.dart # Token attach + refresh
│   │       └── network_info.dart     # Connectivity check
│   │
│   ├── features/                     # ── FEATURE MODULES ──
│   │   ├── auth/
│   │   │   ├── data/
│   │   │   │   ├── auth_repository.dart
│   │   │   │   └── auth_remote_ds.dart
│   │   │   ├── domain/
│   │   │   │   ├── auth_usecase.dart
│   │   │   │   └── auth_entities.dart
│   │   │   └── presentation/
│   │   │       ├── login_screen.dart
│   │   │       ├── register_screen.dart
│   │   │       └── widgets/
│   │   │           └── social_login_buttons.dart
│   │   │
│   │   ├── home/
│   │   │   ├── data/
│   │   │   │   └── home_repository.dart
│   │   │   ├── domain/
│   │   │   │   ├── home_usecase.dart
│   │   │   │   └── home_entities.dart
│   │   │   └── presentation/
│   │   │       ├── home_screen.dart
│   │   │       ├── widgets/
│   │   │       │   ├── hero_banner_carousel.dart
│   │   │       │   ├── collection_card.dart
│   │   │       │   └── quick_actions_grid.dart
│   │   │       └── home_controller.dart
│   │   │
│   │   ├── collections/
│   │   │   ├── data/
│   │   │   │   ├── collection_repository.dart
│   │   │   │   └── collection_remote_ds.dart
│   │   │   ├── domain/
│   │   │   │   ├── collection_usecase.dart
│   │   │   │   └── collection_entities.dart
│   │   │   └── presentation/
│   │   │       ├── collection_list_screen.dart
│   │   │       ├── collection_detail_screen.dart
│   │   │       ├── stone_detail_screen.dart
│   │   │       └── widgets/
│   │   │           ├── stone_grid_tile.dart
│   │   │           ├── stone_hero_image.dart
│   │   │           ├── variant_selector.dart
│   │   │           └── price_badge.dart
│   │   │
│   │   ├── ai_viz/
│   │   │   ├── data/
│   │   │   │   ├── viz_repository.dart
│   │   │   │   └── viz_remote_ds.dart
│   │   │   ├── domain/
│   │   │   │   ├── viz_usecase.dart
│   │   │   │   └── viz_entities.dart
│   │   │   ├── presentation/
│   │   │   │   ├── ai_viz_screen.dart
│   │   │   │   ├── result_preview_screen.dart
│   │   │   │   └── widgets/
│   │   │   │       ├── upload_photo_card.dart
│   │   │   │       ├── stone_selector_strip.dart
│   │   │   │       └── before_after_slider.dart
│   │   │   └── services/
│   │   │       ├── wall_segmentation.dart   # ML Kit / TFLite
│   │   │       └── stone_compositor.dart    # Image blending
│   │   │
│   │   ├── ar_view/
│   │   │   ├── data/
│   │   │   │   └── ar_repository.dart
│   │   │   ├── domain/
│   │   │   │   ├── ar_usecase.dart
│   │   │   │   └── ar_entities.dart
│   │   │   ├── presentation/
│   │   │   │   ├── ar_camera_screen.dart
│   │   │   │   └── widgets/
│   │   │   │       ├── plane_indicator.dart
│   │   │   │       ├── stone_anchor.dart
│   │   │   │       └── ar_controls_overlay.dart
│   │   │   └── services/
│   │   │       ├── ar_session_manager.dart  # ARCore / ARKit
│   │   │       └── plane_detector.dart
│   │   │
│   │   ├── dealer/
│   │   │   ├── data/
│   │   │   ├── domain/
│   │   │   └── presentation/
│   │   │       ├── dealer_locator_screen.dart
│   │   │       ├── dealer_profile_screen.dart
│   │   │       └── widgets/
│   │   │           ├── dealer_map.dart
│   │   │           └── dealer_card.dart
│   │   │
│   │   ├── quotes/
│   │   │   ├── data/
│   │   │   ├── domain/
│   │   │   └── presentation/
│   │   │       ├── quote_request_screen.dart
│   │   │       ├── quote_history_screen.dart
│   │   │       └── widgets/
│   │   │           └── quote_card.dart
│   │   │
│   │   ├── sample_order/
│   │   │   ├── data/
│   │   │   ├── domain/
│   │   │   └── presentation/
│   │   │       ├── sample_cart_screen.dart
│   │   │       └── sample_checkout_screen.dart
│   │   │
│   │   ├── cart/
│   │   │   ├── data/
│   │   │   ├── domain/
│   │   │   └── presentation/
│   │   │       ├── cart_screen.dart
│   │   │       └── widgets/
│   │   │           └── cart_item_tile.dart
│   │   │
│   │   ├── orders/
│   │   │   ├── data/
│   │   │   ├── domain/
│   │   │   └── presentation/
│   │   │       ├── order_list_screen.dart
│   │   │       └── order_detail_screen.dart
│   │   │
│   │   ├── wishlist/
│   │   │   └── presentation/
│   │   │       └── wishlist_screen.dart
│   │   │
│   │   ├── profile/
│   │   │   ├── data/
│   │   │   ├── domain/
│   │   │   └── presentation/
│   │   │       ├── profile_screen.dart
│   │   │       ├── edit_profile_screen.dart
│   │   │       └── settings_screen.dart
│   │   │
│   │   ├── search/
│   │   │   └── presentation/
│   │   │       ├── search_screen.dart
│   │   │       └── widgets/
│   │   │           └── search_bar.dart
│   │   │
│   │   └── onboarding/
│   │       └── presentation/
│   │           ├── splash_screen.dart
│   │           ├── onboarding_screen.dart
│   │           └── widgets/
│   │               └── onboarding_page.dart
│   │
│   ├── shared/                       # ── REUSABLE WIDGETS ──
│   │   ├── widgets/
│   │   │   ├── grazia_button.dart
│   │   │   ├── grazia_text_field.dart
│   │   │   ├── grazia_card.dart
│   │   │   ├── grazia_app_bar.dart
│   │   │   ├── grazia_bottom_nav.dart
│   │   │   ├── stone_chip.dart
│   │   │   ├── loading_skeleton.dart
│   │   │   ├── empty_state.dart
│   │   │   └── shimmer_effect.dart
│   │   └── layouts/
│   │       ├── responsive_scaffold.dart
│   │       └── adaptive_grid.dart
│   │
│   └── config/
│       ├── routes.dart               # GoRouter / AutoRoute config
│       └── env.dart                  # Flavor dev/staging/prod
│
├── assets/
│   ├── images/                       # SVGs, PNGs
│   ├── fonts/                        # Custom .ttf files
│   └── animations/                   # Lottie / Rive files
│
├── test/                             # Unit + widget tests
├── integration_test/                 # E2E tests
├── pubspec.yaml
└── analysis_options.yaml
```

## Key Dependencies

```yaml
dependencies:
  flutter:
    sdk: flutter

  # State Management
  flutter_riverpod: ^2.5.0
  riverpod_annotation: ^2.3.0

  # Navigation
  go_router: ^14.0.0

  # Network
  dio: ^5.4.0
  retrofit: ^4.0.0

  # Database
  drift: ^2.16.0          # Local SQLite cache
  hive_flutter: ^1.1.0    # Key-value storage

  # Firebase
  firebase_core: ^3.0.0
  firebase_auth: ^5.0.0
  cloud_firestore: ^5.0.0
  firebase_messaging: ^15.0.0
  firebase_analytics: ^11.0.0

  # AR
  ar_flutter_plugin: ^0.7.0
  arkit_plugin: ^7.0.0    # iOS ARKit
  arcore_flutter_plugin: ^0.3.0  # Android ARCore

  # AI / ML
  tflite_flutter: ^0.11.0
  google_mlkit_image_labeling: ^0.11.0
  google_mlkit_object_detection: ^0.11.0
  image_picker: ^1.0.0
  image: ^4.1.0

  # UI
  flutter_screenutil: ^5.9.0
  shimmer: ^3.0.0
  lottie: ^3.0.0
  cached_network_image: ^3.3.0
  flutter_svg: ^2.0.0
  glassmorphism: ^3.0.0

  # Search
  meilisearch: ^0.10.0

  # Location
  geolocator: ^12.0.0
  geocoding: ^3.0.0

  # Payments
  razorpay_flutter: ^1.3.0

  # Utilities
  intl: ^0.19.0
  equatable: ^2.0.0
  freezed_annotation: ^2.4.0
  json_annotation: ^4.8.0

dev_dependencies:
  build_runner: ^2.4.0
  riverpod_generator: ^2.4.0
  freezed: ^2.5.0
  json_serializable: ^6.7.0
  retrofit_generator: ^8.0.0
  drift_dev: ^2.16.0
  test: ^1.25.0
  flutter_test:
    sdk: flutter
  mocktail: ^1.0.0
```

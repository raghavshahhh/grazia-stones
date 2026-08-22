import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grazia_stones/core/theme/grazia_theme.dart';
import 'package:grazia_stones/shared/theme/theme_provider.dart';
import 'package:grazia_stones/config/router.dart';

class GraziaApp extends ConsumerWidget {
  const GraziaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final palette = ref.watch(themePaletteProvider);

    final isDark = ref.watch(themePaletteProvider.notifier).isDarkMode;

    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: palette.surface,
      systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
    ));

    return MaterialApp.router(
      title: 'Grazia Stones',
      debugShowCheckedModeBanner: false,
      theme: isDark ? GraziaTheme.dark(palette) : GraziaTheme.light(palette),
      routerConfig: router,
    );
  }
}

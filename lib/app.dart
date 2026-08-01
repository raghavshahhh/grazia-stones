import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:grazia_stones/core/constants/app_colors.dart';
import 'package:grazia_stones/core/theme/grazia_theme.dart';
import 'package:grazia_stones/config/routes.dart';

class GraziaApp extends StatelessWidget {
  const GraziaApp({super.key});

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.charcoal,
      systemNavigationBarIconBrightness: Brightness.light,
    ));

    return MaterialApp(
      title: 'Grazia Stones',
      debugShowCheckedModeBanner: false,
      theme: GraziaTheme.darkTheme,
      onGenerateRoute: AppRoutes.onGenerateRoute,
      initialRoute: AppRoutes.splash,
    );
  }
}

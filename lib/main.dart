import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:grazia_stones/app.dart';
import 'package:grazia_stones/core/providers/cart_provider.dart';
import 'package:grazia_stones/core/providers/quote_provider.dart';
import 'package:grazia_stones/core/providers/auth_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => QuoteProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: const GraziaApp(),
    ),
  );
}

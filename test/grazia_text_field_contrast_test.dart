import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grazia_stones/shared/widgets/grazia_text_field.dart';

void main() {
  // Play's review device showed white fields with white text on Login: the app theme fills inputs with its
  // surface colour (white in the light theme, see GraziaTheme.light). Same input theme here, without its fonts.
  testWidgets('auth field ignores the theme fill and keeps light text', (tester) async {
    final theme = ThemeData(inputDecorationTheme: const InputDecorationTheme(filled: true, fillColor: Colors.white));
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(theme: theme, home: const Scaffold(body: GraziaTextField(label: 'Email', hint: 'you@x.com'))),
    ));
    final decorator = tester.widget<InputDecorator>(find.byType(InputDecorator));
    expect(decorator.decoration.filled, isFalse);
    final field = tester.widget<EditableText>(find.byType(EditableText));
    expect(field.style.color!.computeLuminance(), greaterThan(0.8));
  });
}

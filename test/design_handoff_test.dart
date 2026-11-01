// Product page -> AI Studio / Live AR / Measure handoff: the stone (and the shade on screen) must arrive.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:grazia_stones/core/models/stone.dart';
import 'package:grazia_stones/core/providers/ai_usage_provider.dart';
import 'package:grazia_stones/core/providers/stone_providers.dart' show allStonesProvider;
import 'package:grazia_stones/core/repositories/stone_repository.dart';
import 'package:grazia_stones/core/di.dart';
import 'package:grazia_stones/features/ai_viz/presentation/simple_ai_studio_screen.dart';
import 'package:grazia_stones/features/measure/presentation/measure_screen.dart';
import 'package:grazia_stones/features/auth/providers/auth_riverpod_provider.dart';

const _grey = 'assets/images/mountain_ledge_m08_tex.png';
const _rust = 'assets/images/classic_ledge_07_tex.png';

Stone _stone(String id, String name, {String code = '', List<String> images = const [_grey]}) => Stone(
      id: id,
      name: name,
      productCode: code,
      collection: 'Ledge',
      category: 'Wall',
      pricePerSqFt: 0,
      description: '',
      images: images,
    );

final _catalogue = [
  _stone('a1', 'Classic Ledge Series Grey'),
  _stone('b2', 'Classic Ledge', code: 'CL07', images: [_grey, _rust]),
];

class _Repo extends Fake implements StoneRepository {
  @override
  Future<Stone> getStoneById(String id) async => _catalogue.firstWhere((s) => s.id == id);
}

class _LoggedIn extends StateNotifier<AuthRiverpodState> implements AuthRiverpodNotifier {
  _LoggedIn() : super(AuthRiverpodState(isLoggedIn: true, userId: 'u1'));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('findStone', () {
    test('exact id, code or name wins over an earlier loose name match', () {
      expect(findStone(_catalogue, 'b2')?.id, 'b2');
      expect(findStone(_catalogue, 'cl07')?.id, 'b2');
      // 'Classic Ledge' is contained in the first stone's name too; the exact name must still win.
      expect(findStone(_catalogue, 'classic ledge')?.id, 'b2');
      expect(findStone(_catalogue, 'grey')?.id, 'a1');
    });

    test('no query or no match gives no stone, never an arbitrary one', () {
      expect(findStone(_catalogue, null), isNull);
      expect(findStone(_catalogue, '  '), isNull);
      expect(findStone(_catalogue, 'athena'), isNull);
    });
  });

  testWidgets('AI Studio opens with the stone and the shade picked on the product page', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(2400, 4400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final rust = (await rootBundle.load(_rust)).buffer.asUint8List();

    await tester.pumpWidget(ProviderScope(
      overrides: [
        authRiverpodProvider.overrideWith((ref) => _LoggedIn()),
        stoneRepositoryProvider.overrideWithValue(_Repo()),
        allStonesProvider.overrideWith((ref) async => _catalogue),
        aiUsageProvider.overrideWith((ref) async => null),
      ],
      child: const MaterialApp(home: SimpleAIStudioScreen(preSelectedStoneId: 'b2', preSelectedColour: 1)),
    ));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pumpAndSettle();

    expect(find.textContaining('Classic Ledge'), findsWidgets);
    // The Step 2 card paints the design as a BoxDecoration image.
    bool showsRust(Widget w) {
      final d = w is DecoratedBox ? w.decoration : null;
      final img = d is BoxDecoration ? d.image?.image : null;
      return img is MemoryImage && img.bytes.length == rust.length;
    }
    expect(find.byWidgetPredicate(showsRust), findsWidgets, reason: 'Step 2 shows the second colour, not the default');
  });

  Future<void> pumpMeasure(WidgetTester tester, String? stoneId) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(2400, 6000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final stones = [
      _stone('a1', 'Grande Ledge'),
      _stone('b2', 'Mountain Ledge').copyWith(length: '50 cm', width: '10 cm', sqftPerBox: 7.5),
    ];
    await tester.pumpWidget(ProviderScope(
      overrides: [allStonesProvider.overrideWith((ref) async => stones)],
      child: MaterialApp(home: MeasureScreen(initialStoneId: stoneId)),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('Measure estimates the stone it was opened for, with its real piece size', (tester) async {
    await pumpMeasure(tester, 'b2');
    expect(find.text('Selected Stone: Mountain Ledge'), findsOneWidget);
    expect(find.textContaining('(50×10 cm)'), findsWidgets);
  });

  testWidgets('Measure without a stone does not pretend one was chosen', (tester) async {
    await pumpMeasure(tester, null);
    expect(find.textContaining('Grande Ledge'), findsWidgets); // still offered in the picker
    expect(find.text('Selected Stone: Grande Ledge'), findsNothing);
    expect(find.text('Selected Stone: none yet, choose one below'), findsOneWidget);
  });
}

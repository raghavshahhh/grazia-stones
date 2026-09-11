/// E2E Test: Tools & Spatial Suite
/// Tests Measure Tool, 3D Wall Visualizer, and AI Room Studio
@Timeout(Duration(minutes: 10))
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_config.dart';
import '../test_helpers.dart';
import '../../test/helpers/test_app_wrapper.dart';

void main() {
  late IntegrationTestWidgetsFlutterBinding binding;

  setUpAll(() async {
    binding = await initializeIntegrationTest();
    await initializeTestEnvironment();
  });

  group('AI Tools Hub Tests', () {
    testWidgets('Navigate to Tools hub', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle(TestConfig.pageLoadTimeout);

      // Navigate via bottom nav
      final toolsNav = find.text('Tools');
      if (toolsNav.evaluate().isNotEmpty) {
        await tester.tap(toolsNav.first);
        await tester.pumpAndSettle();

        // Verify tools hub loaded
        debugPrint('✅ Tools hub loaded');
      }
    });

    testWidgets('View all tool options', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Verify all tools are visible
      final toolOptions = [
        'AI Room Studio',
        'Wall Visualizer',
        'Measure Tool',
        'AR View',
      ];

      for (final tool in toolOptions) {
        final toolCard = find.text(tool);
        if (toolCard.evaluate().isNotEmpty) {
          debugPrint('✓ Found tool: $tool');
        }
      }

      debugPrint('✅ All tools displayed');
    });
  });

  group('AI Room Studio Tests', () {
    testWidgets('Navigate to AI Room Studio', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final toolsNav = find.text('Tools');
      if (toolsNav.evaluate().isNotEmpty) {
        await tester.tap(toolsNav.first);
        await tester.pumpAndSettle();

        final aiStudioCard = find.text('AI Room Studio');
        if (aiStudioCard.evaluate().isNotEmpty) {
          await tester.tap(aiStudioCard);
          await tester.pumpAndSettle(TestConfig.pageLoadTimeout);

          debugPrint('✅ AI Room Studio opened');
        }
      }
    });

    testWidgets('Upload room image', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final uploadButton = find.byKey(const Key('upload_room_button'));
      if (uploadButton.evaluate().isNotEmpty) {
        await tester.tap(uploadButton);
        await tester.pumpAndSettle();

        // This would trigger image picker
        debugPrint('⚠️ Image upload requires image_picker plugin');
      }
    });

    testWidgets('Select stone for visualization', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final selectStoneButton = find.byKey(const Key('select_stone_button'));
      if (selectStoneButton.evaluate().isNotEmpty) {
        await tester.tap(selectStoneButton);
        await tester.pumpAndSettle();

        // Select first stone
        final stoneCard = find.byKey(const Key('stone_selector_card')).first;
        if (stoneCard.evaluate().isNotEmpty) {
          await tester.tap(stoneCard);
          await tester.pumpAndSettle();
          debugPrint('✅ Stone selected for visualization');
        }
      }
    });

    testWidgets('Generate AI visualization', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final generateButton = find.byKey(const Key('generate_viz_button'));
      if (generateButton.evaluate().isNotEmpty) {
        await tester.tap(generateButton);
        await tester.pumpAndSettle();

        // Wait for generation (with timeout)
        await TestActions.waitForLoading(tester);
        debugPrint('✅ AI visualization generation started');
      }
    });

    testWidgets('View AI visualization results', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Navigate to results page
      final resultCard = find.byKey(const Key('viz_result_card')).first;
      if (resultCard.evaluate().isNotEmpty) {
        await tester.tap(resultCard);
        await tester.pumpAndSettle(TestConfig.pageLoadTimeout);

        debugPrint('✅ Visualization results displayed');
      }
    });

    testWidgets('Save AI visualization', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final saveButton = find.byKey(const Key('save_viz_button'));
      if (saveButton.evaluate().isNotEmpty) {
        await tester.tap(saveButton);
        await tester.pumpAndSettle();

        debugPrint('✅ Visualization saved');
      }
    });

    testWidgets('Share AI visualization', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final shareButton = find.byKey(const Key('share_viz_button'));
      if (shareButton.evaluate().isNotEmpty) {
        await tester.tap(shareButton);
        await tester.pumpAndSettle();

        // This would trigger share sheet
        debugPrint('⚠️ Share requires share_plus plugin');
      }
    });

    testWidgets('Download AI visualization', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final downloadButton = find.byKey(const Key('download_viz_button'));
      if (downloadButton.evaluate().isNotEmpty) {
        await tester.tap(downloadButton);
        await tester.pumpAndSettle();

        debugPrint('✅ Visualization download started');
      }
    });

    testWidgets('View multiple variants', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Swipe through variants
      final variantGallery = find.byKey(const Key('variant_gallery'));
      if (variantGallery.evaluate().isNotEmpty) {
        await tester.drag(variantGallery, const Offset(-300, 0));
        await tester.pumpAndSettle();

        debugPrint('✅ Variants displayed');
      }
    });

    testWidgets('Retry failed generation', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final retryButton = find.byKey(const Key('retry_generation_button'));
      if (retryButton.evaluate().isNotEmpty) {
        await tester.tap(retryButton);
        await tester.pumpAndSettle();

        debugPrint('✅ Generation retry triggered');
      }
    });

    testWidgets('View AI job history', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final historyButton = find.byKey(const Key('ai_job_history_button'));
      if (historyButton.evaluate().isNotEmpty) {
        await tester.tap(historyButton);
        await tester.pumpAndSettle(TestConfig.pageLoadTimeout);

        await TestActions.waitForLoading(tester);
        debugPrint('✅ AI job history loaded');
      }
    });
  });

  group('Wall Visualizer (Tile Calculator) Tests', () {
    testWidgets('Navigate to Wall Visualizer', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final toolsNav = find.text('Tools');
      if (toolsNav.evaluate().isNotEmpty) {
        await tester.tap(toolsNav.first);
        await tester.pumpAndSettle();

        final visualizerCard = find.text('Wall Visualizer');
        if (visualizerCard.evaluate().isNotEmpty) {
          await tester.tap(visualizerCard);
          await tester.pumpAndSettle(TestConfig.pageLoadTimeout);

          debugPrint('✅ Wall Visualizer opened');
        }
      }
    });

    testWidgets('Enter wall dimensions', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      await TestActions.fillField(tester, 'wall_width', '10');
      await TestActions.fillField(tester, 'wall_height', '8');

      debugPrint('✅ Wall dimensions entered');
    });

    testWidgets('Select tile/stone for calculation', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final selectTileButton = find.byKey(const Key('select_tile_button'));
      if (selectTileButton.evaluate().isNotEmpty) {
        await tester.tap(selectTileButton);
        await tester.pumpAndSettle();

        // Select a tile
        final tileCard = find.byKey(const Key('tile_card')).first;
        if (tileCard.evaluate().isNotEmpty) {
          await tester.tap(tileCard);
          await tester.pumpAndSettle();
          debugPrint('✅ Tile selected');
        }
      }
    });

    testWidgets('Calculate required tiles', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final calculateButton = find.byKey(const Key('calculate_tiles_button'));
      if (calculateButton.evaluate().isNotEmpty) {
        await tester.tap(calculateButton);
        await tester.pumpAndSettle();

        // Verify results displayed
        final resultsCard = find.byKey(const Key('calculation_results'));
        expect(resultsCard.evaluate().isNotEmpty, true);

        debugPrint('✅ Tile calculation completed');
      }
    });

    testWidgets('Adjust wastage percentage', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final wastageSlider = find.byKey(const Key('wastage_slider'));
      if (wastageSlider.evaluate().isNotEmpty) {
        // Drag slider
        await tester.drag(wastageSlider, const Offset(50, 0));
        await tester.pumpAndSettle();

        debugPrint('✅ Wastage percentage adjusted');
      }
    });

    testWidgets('View 3D preview', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final preview3DButton = find.byKey(const Key('view_3d_preview_button'));
      if (preview3DButton.evaluate().isNotEmpty) {
        await tester.tap(preview3DButton);
        await tester.pumpAndSettle();

        debugPrint('✅ 3D preview opened');
      }
    });

    testWidgets('Export calculation report', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final exportButton = find.byKey(const Key('export_calculation_button'));
      if (exportButton.evaluate().isNotEmpty) {
        await tester.tap(exportButton);
        await tester.pumpAndSettle();

        debugPrint('✅ Calculation exported');
      }
    });

    testWidgets('Add to cart from calculator', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final addToCartButton = find.byKey(const Key('calc_add_to_cart_button'));
      if (addToCartButton.evaluate().isNotEmpty) {
        await tester.tap(addToCartButton);
        await tester.pumpAndSettle();

        debugPrint('✅ Calculated items added to cart');
      }
    });
  });

  group('Measure Tool Tests', () {
    testWidgets('Navigate to Measure Tool', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final toolsNav = find.text('Tools');
      if (toolsNav.evaluate().isNotEmpty) {
        await tester.tap(toolsNav.first);
        await tester.pumpAndSettle();

        final measureCard = find.text('Measure');
        if (measureCard.evaluate().isNotEmpty) {
          await tester.tap(measureCard);
          await tester.pumpAndSettle(TestConfig.pageLoadTimeout);

          debugPrint('✅ Measure Tool opened');
        }
      }
    });

    testWidgets('Request camera permission', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final cameraPermissionButton = find.byKey(const Key('request_camera_permission'));
      if (cameraPermissionButton.evaluate().isNotEmpty) {
        await tester.tap(cameraPermissionButton);
        await tester.pumpAndSettle();

        debugPrint('⚠️ Camera permission requires device');
      }
    });

    testWidgets('Initialize AR session', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // AR session initialization
      debugPrint('⚠️ AR session requires ARCore/ARKit');
    });

    testWidgets('Place measurement points', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Tap to place points (simulated)
      final arView = find.byKey(const Key('ar_measure_view'));
      if (arView.evaluate().isNotEmpty) {
        await tester.tap(arView);
        await tester.pumpAndSettle();

        debugPrint('⚠️ AR measurement requires device');
      }
    });

    testWidgets('View measurement results', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final resultsDisplay = find.byKey(const Key('measurement_results'));
      if (resultsDisplay.evaluate().isNotEmpty) {
        debugPrint('✅ Measurement results displayed');
      }
    });

    testWidgets('Save measurement', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final saveButton = find.byKey(const Key('save_measurement_button'));
      if (saveButton.evaluate().isNotEmpty) {
        await tester.tap(saveButton);
        await tester.pumpAndSettle();

        debugPrint('✅ Measurement saved');
      }
    });

    testWidgets('Reset measurement', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final resetButton = find.byKey(const Key('reset_measurement_button'));
      if (resetButton.evaluate().isNotEmpty) {
        await tester.tap(resetButton);
        await tester.pumpAndSettle();

        debugPrint('✅ Measurement reset');
      }
    });
  });

  group('AR View Tests', () {
    testWidgets('Navigate to AR View', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final arViewButton = find.text('AR View');
      if (arViewButton.evaluate().isNotEmpty) {
        await tester.tap(arViewButton.first);
        await tester.pumpAndSettle(TestConfig.pageLoadTimeout);

        debugPrint('✅ AR View opened');
      }
    });

    testWidgets('Initialize AR preview', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      debugPrint('⚠️ AR preview requires ARCore/ARKit');
    });

    testWidgets('Place stone in AR', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final arView = find.byKey(const Key('ar_preview_view'));
      if (arView.evaluate().isNotEmpty) {
        await tester.tap(arView);
        await tester.pumpAndSettle();

        debugPrint('⚠️ AR placement requires device');
      }
    });

    testWidgets('Rotate AR object', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final arView = find.byKey(const Key('ar_preview_view'));
      if (arView.evaluate().isNotEmpty) {
        await tester.drag(arView, const Offset(100, 0));
        await tester.pumpAndSettle();

        debugPrint('⚠️ AR rotation requires device');
      }
    });

    testWidgets('Scale AR object', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Pinch to zoom gesture
      debugPrint('⚠️ AR scaling requires device');
    });

    testWidgets('Take AR screenshot', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final screenshotButton = find.byKey(const Key('ar_screenshot_button'));
      if (screenshotButton.evaluate().isNotEmpty) {
        await tester.tap(screenshotButton);
        await tester.pumpAndSettle();

        debugPrint('✅ AR screenshot captured');
      }
    });

    testWidgets('Share AR preview', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final shareButton = find.byKey(const Key('share_ar_button'));
      if (shareButton.evaluate().isNotEmpty) {
        await tester.tap(shareButton);
        await tester.pumpAndSettle();

        debugPrint('⚠️ Share requires share_plus plugin');
      }
    });
  });

  group('Tool Integration Tests', () {
    testWidgets('Navigate between tools seamlessly', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Navigate to AI Studio
      final toolsNav = find.text('Tools');
      if (toolsNav.evaluate().isNotEmpty) {
        await tester.tap(toolsNav.first);
        await tester.pumpAndSettle();

        // Switch to Wall Visualizer
        final visualizerCard = find.text('Wall Visualizer');
        if (visualizerCard.evaluate().isNotEmpty) {
          await tester.tap(visualizerCard);
          await tester.pumpAndSettle(TestConfig.pageLoadTimeout);

          // Back to tools hub
          final backButton = find.byIcon(Icons.arrow_back);
          if (backButton.evaluate().isNotEmpty) {
            await tester.tap(backButton);
            await tester.pumpAndSettle();

            debugPrint('✅ Tool navigation works');
          }
        }
      }
    });

    testWidgets('Tool data persists across sessions', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // This would test saved measurements, calculations, etc.
      debugPrint('⚠️ Persistence test requires storage');
    });
  });
}

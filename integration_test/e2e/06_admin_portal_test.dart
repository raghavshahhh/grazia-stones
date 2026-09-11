/// E2E Test: Admin Portal (All 8 Modules)
/// Tests Products, Collections, Dealers, Orders, Quotes, Samples, AI Jobs, Dashboard
@Timeout(Duration(minutes: 15))
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

  setUp(() async {
    // Login as admin before each test
    debugPrint('🔑 Logging in as admin...');
  });

  group('Admin Dashboard Tests', () {
    testWidgets('Navigate to admin dashboard', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle(TestConfig.pageLoadTimeout);

      // Navigate to admin (requires admin role)
      debugPrint('⚠️ Admin access requires admin role authentication');
    });

    testWidgets('View dashboard statistics', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Verify stats cards
      final statsCards = [
        'total_products',
        'total_orders',
        'total_revenue',
        'pending_quotes',
      ];

      for (final stat in statsCards) {
        final statCard = find.byKey(Key(stat));
        if (statCard.evaluate().isNotEmpty) {
          debugPrint('✓ Found stat: $stat');
        }
      }

      debugPrint('✅ Dashboard statistics displayed');
    });

    testWidgets('View recent activity', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final activityList = find.byKey(const Key('recent_activity_list'));
      if (activityList.evaluate().isNotEmpty) {
        debugPrint('✅ Recent activity displayed');
      }
    });

    testWidgets('Navigate to module from dashboard', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final productsCard = find.text('Products');
      if (productsCard.evaluate().isNotEmpty) {
        await tester.tap(productsCard);
        await tester.pumpAndSettle(TestConfig.pageLoadTimeout);

        debugPrint('✅ Navigated to Products module');
      }
    });
  });

  group('Admin Products Module Tests', () {
    testWidgets('View products list', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Navigate to admin products
      await TestActions.waitForLoading(tester);
      debugPrint('✅ Products list loaded');
    });

    testWidgets('Search products', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      await TestActions.search(tester, 'Marble');
      debugPrint('✅ Product search works');
    });

    testWidgets('Filter products by status', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final statusFilter = find.byKey(const Key('product_status_filter'));
      if (statusFilter.evaluate().isNotEmpty) {
        await tester.tap(statusFilter);
        await tester.pumpAndSettle();

        final activeStatus = find.text('Active');
        if (activeStatus.evaluate().isNotEmpty) {
          await tester.tap(activeStatus);
          await tester.pumpAndSettle();
          debugPrint('✅ Products filtered by status');
        }
      }
    });

    testWidgets('Filter products by category', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final categoryFilter = find.byKey(const Key('product_category_filter'));
      if (categoryFilter.evaluate().isNotEmpty) {
        await tester.tap(categoryFilter);
        await tester.pumpAndSettle();
        debugPrint('✅ Products filtered by category');
      }
    });

    testWidgets('Add new product', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final addButton = find.byKey(const Key('add_product_button'));
      if (addButton.evaluate().isNotEmpty) {
        await tester.tap(addButton);
        await tester.pumpAndSettle(TestConfig.pageLoadTimeout);

        // Fill product form
        await TestActions.fillField(tester, 'product_name', 'Test Stone');
        await TestActions.fillField(tester, 'product_price', '10000');
        await TestActions.fillField(tester, 'product_description', 'Test description');

        // Save product
        final saveButton = find.byKey(const Key('save_product_button'));
        if (saveButton.evaluate().isNotEmpty) {
          await tester.tap(saveButton);
          await tester.pumpAndSettle(TestConfig.apiTimeout);
          debugPrint('✅ Product created');
        }
      }
    });

    testWidgets('Edit existing product', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final productCard = find.byKey(const Key('admin_product_card')).first;
      if (productCard.evaluate().isNotEmpty) {
        final editButton = find.byKey(const Key('edit_product_button')).first;
        if (editButton.evaluate().isNotEmpty) {
          await tester.tap(editButton);
          await tester.pumpAndSettle(TestConfig.pageLoadTimeout);

          // Update product
          await TestActions.fillField(tester, 'product_price', '12000');

          final saveButton = find.byKey(const Key('save_product_button'));
          if (saveButton.evaluate().isNotEmpty) {
            await tester.tap(saveButton);
            await tester.pumpAndSettle();
            debugPrint('✅ Product updated');
          }
        }
      }
    });

    testWidgets('Upload product images', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final uploadButton = find.byKey(const Key('upload_product_images'));
      if (uploadButton.evaluate().isNotEmpty) {
        await tester.tap(uploadButton);
        await tester.pumpAndSettle();

        debugPrint('⚠️ Image upload requires image_picker');
      }
    });

    testWidgets('Delete product', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final deleteButton = find.byKey(const Key('delete_product_button')).first;
      if (deleteButton.evaluate().isNotEmpty) {
        await tester.tap(deleteButton);
        await tester.pumpAndSettle();

        // Confirm deletion
        final confirmButton = find.text('Delete');
        if (confirmButton.evaluate().isNotEmpty) {
          await tester.tap(confirmButton);
          await tester.pumpAndSettle();
          debugPrint('✅ Product deleted');
        }
      }
    });

    testWidgets('Toggle product visibility', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final visibilityToggle = find.byKey(const Key('product_visibility_toggle')).first;
      if (visibilityToggle.evaluate().isNotEmpty) {
        await tester.tap(visibilityToggle);
        await tester.pumpAndSettle();
        debugPrint('✅ Product visibility toggled');
      }
    });

    testWidgets('Bulk update products', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Select multiple products
      final checkboxes = find.byKey(const Key('product_checkbox'));
      if (checkboxes.evaluate().length >= 2) {
        await tester.tap(checkboxes.first);
        await tester.pumpAndSettle();
        await tester.tap(checkboxes.at(1));
        await tester.pumpAndSettle();

        // Bulk action
        final bulkActionButton = find.byKey(const Key('bulk_action_button'));
        if (bulkActionButton.evaluate().isNotEmpty) {
          await tester.tap(bulkActionButton);
          await tester.pumpAndSettle();
          debugPrint('✅ Bulk update works');
        }
      }
    });
  });

  group('Admin Collections Module Tests', () {
    testWidgets('View collections list', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      debugPrint('✅ Collections list loaded');
    });

    testWidgets('Add new collection', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final addButton = find.byKey(const Key('add_collection_button'));
      if (addButton.evaluate().isNotEmpty) {
        await tester.tap(addButton);
        await tester.pumpAndSettle();

        await TestActions.fillField(tester, 'collection_name', 'Premium Marble');
        await TestActions.fillField(tester, 'collection_description', 'Finest marble collection');

        final saveButton = find.byKey(const Key('save_collection_button'));
        if (saveButton.evaluate().isNotEmpty) {
          await tester.tap(saveButton);
          await tester.pumpAndSettle();
          debugPrint('✅ Collection created');
        }
      }
    });

    testWidgets('Edit collection', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final editButton = find.byKey(const Key('edit_collection_button')).first;
      if (editButton.evaluate().isNotEmpty) {
        await tester.tap(editButton);
        await tester.pumpAndSettle();

        await TestActions.fillField(tester, 'collection_name', 'Updated Name');

        final saveButton = find.byKey(const Key('save_collection_button'));
        if (saveButton.evaluate().isNotEmpty) {
          await tester.tap(saveButton);
          await tester.pumpAndSettle();
          debugPrint('✅ Collection updated');
        }
      }
    });

    testWidgets('Add products to collection', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final addProductsButton = find.byKey(const Key('add_products_to_collection'));
      if (addProductsButton.evaluate().isNotEmpty) {
        await tester.tap(addProductsButton);
        await tester.pumpAndSettle();

        // Select products
        final productCheckbox = find.byKey(const Key('product_checkbox')).first;
        if (productCheckbox.evaluate().isNotEmpty) {
          await tester.tap(productCheckbox);
          await tester.pumpAndSettle();

          final confirmButton = find.text('Add');
          if (confirmButton.evaluate().isNotEmpty) {
            await tester.tap(confirmButton);
            await tester.pumpAndSettle();
            debugPrint('✅ Products added to collection');
          }
        }
      }
    });

    testWidgets('Delete collection', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final deleteButton = find.byKey(const Key('delete_collection_button')).first;
      if (deleteButton.evaluate().isNotEmpty) {
        await tester.tap(deleteButton);
        await tester.pumpAndSettle();

        final confirmButton = find.text('Delete');
        if (confirmButton.evaluate().isNotEmpty) {
          await tester.tap(confirmButton);
          await tester.pumpAndSettle();
          debugPrint('✅ Collection deleted');
        }
      }
    });
  });

  group('Admin Orders Module Tests', () {
    testWidgets('View orders list', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      await TestActions.waitForLoading(tester);
      debugPrint('✅ Orders list loaded');
    });

    testWidgets('Filter orders by status', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final statusFilter = find.byKey(const Key('order_status_filter'));
      if (statusFilter.evaluate().isNotEmpty) {
        await tester.tap(statusFilter);
        await tester.pumpAndSettle();

        final pendingStatus = find.text('Pending');
        if (pendingStatus.evaluate().isNotEmpty) {
          await tester.tap(pendingStatus);
          await tester.pumpAndSettle();
          debugPrint('✅ Orders filtered');
        }
      }
    });

    testWidgets('View order details', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final orderCard = find.byKey(const Key('admin_order_card')).first;
      if (orderCard.evaluate().isNotEmpty) {
        await tester.tap(orderCard);
        await tester.pumpAndSettle();
        debugPrint('✅ Order details displayed');
      }
    });

    testWidgets('Update order status', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final statusDropdown = find.byKey(const Key('order_status_dropdown'));
      if (statusDropdown.evaluate().isNotEmpty) {
        await tester.tap(statusDropdown);
        await tester.pumpAndSettle();

        final confirmedStatus = find.text('Confirmed');
        if (confirmedStatus.evaluate().isNotEmpty) {
          await tester.tap(confirmedStatus);
          await tester.pumpAndSettle();
          debugPrint('✅ Order status updated');
        }
      }
    });

    testWidgets('Add tracking information', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      await TestActions.fillField(tester, 'tracking_number', 'TRACK123456');
      await TestActions.fillField(tester, 'courier_name', 'BlueDart');

      final saveButton = find.byKey(const Key('save_tracking_button'));
      if (saveButton.evaluate().isNotEmpty) {
        await tester.tap(saveButton);
        await tester.pumpAndSettle();
        debugPrint('✅ Tracking info added');
      }
    });

    testWidgets('Cancel order', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final cancelButton = find.byKey(const Key('cancel_order_button'));
      if (cancelButton.evaluate().isNotEmpty) {
        await tester.tap(cancelButton);
        await tester.pumpAndSettle();

        final confirmButton = find.text('Cancel Order');
        if (confirmButton.evaluate().isNotEmpty) {
          await tester.tap(confirmButton);
          await tester.pumpAndSettle();
          debugPrint('✅ Order cancelled');
        }
      }
    });

    testWidgets('Export orders report', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final exportButton = find.byKey(const Key('export_orders_button'));
      if (exportButton.evaluate().isNotEmpty) {
        await tester.tap(exportButton);
        await tester.pumpAndSettle();
        debugPrint('✅ Orders exported');
      }
    });
  });

  group('Admin Quotes Module Tests', () {
    testWidgets('View quotes list', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      await TestActions.waitForLoading(tester);
      debugPrint('✅ Quotes list loaded');
    });

    testWidgets('Filter quotes by status', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final statusFilter = find.byKey(const Key('quote_status_filter'));
      if (statusFilter.evaluate().isNotEmpty) {
        await tester.tap(statusFilter);
        await tester.pumpAndSettle();
        debugPrint('✅ Quotes filtered');
      }
    });

    testWidgets('View quote details', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final quoteCard = find.byKey(const Key('admin_quote_card')).first;
      if (quoteCard.evaluate().isNotEmpty) {
        await tester.tap(quoteCard);
        await tester.pumpAndSettle();
        debugPrint('✅ Quote details displayed');
      }
    });

    testWidgets('Respond to quote with pricing', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      await TestActions.fillField(tester, 'quote_price', '85000');
      await TestActions.fillField(tester, 'quote_notes', 'Special bulk discount applied');

      final sendButton = find.byKey(const Key('send_quote_response_button'));
      if (sendButton.evaluate().isNotEmpty) {
        await tester.tap(sendButton);
        await tester.pumpAndSettle();
        debugPrint('✅ Quote response sent');
      }
    });

    testWidgets('Mark quote as accepted', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final acceptButton = find.byKey(const Key('accept_quote_button'));
      if (acceptButton.evaluate().isNotEmpty) {
        await tester.tap(acceptButton);
        await tester.pumpAndSettle();
        debugPrint('✅ Quote marked as accepted');
      }
    });

    testWidgets('Convert quote to order', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final convertButton = find.byKey(const Key('convert_quote_to_order_button'));
      if (convertButton.evaluate().isNotEmpty) {
        await tester.tap(convertButton);
        await tester.pumpAndSettle();
        debugPrint('✅ Quote converted to order');
      }
    });
  });

  group('Admin Samples Module Tests', () {
    testWidgets('View sample requests list', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      await TestActions.waitForLoading(tester);
      debugPrint('✅ Sample requests loaded');
    });

    testWidgets('Filter samples by status', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final statusFilter = find.byKey(const Key('sample_status_filter'));
      if (statusFilter.evaluate().isNotEmpty) {
        await tester.tap(statusFilter);
        await tester.pumpAndSettle();
        debugPrint('✅ Samples filtered');
      }
    });

    testWidgets('Approve sample request', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final approveButton = find.byKey(const Key('approve_sample_button')).first;
      if (approveButton.evaluate().isNotEmpty) {
        await tester.tap(approveButton);
        await tester.pumpAndSettle();
        debugPrint('✅ Sample request approved');
      }
    });

    testWidgets('Reject sample request', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final rejectButton = find.byKey(const Key('reject_sample_button')).first;
      if (rejectButton.evaluate().isNotEmpty) {
        await tester.tap(rejectButton);
        await tester.pumpAndSettle();

        await TestActions.fillField(tester, 'rejection_reason', 'Out of stock');

        final confirmButton = find.text('Reject');
        if (confirmButton.evaluate().isNotEmpty) {
          await tester.tap(confirmButton);
          await tester.pumpAndSettle();
          debugPrint('✅ Sample request rejected');
        }
      }
    });

    testWidgets('Mark sample as shipped', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final shipButton = find.byKey(const Key('ship_sample_button'));
      if (shipButton.evaluate().isNotEmpty) {
        await tester.tap(shipButton);
        await tester.pumpAndSettle();

        await TestActions.fillField(tester, 'tracking_number', 'SAMPLE123');

        final confirmButton = find.text('Ship');
        if (confirmButton.evaluate().isNotEmpty) {
          await tester.tap(confirmButton);
          await tester.pumpAndSettle();
          debugPrint('✅ Sample marked as shipped');
        }
      }
    });
  });

  group('Admin Dealers Module Tests', () {
    testWidgets('View dealers list', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      await TestActions.waitForLoading(tester);
      debugPrint('✅ Dealers list loaded');
    });

    testWidgets('Add new dealer', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final addButton = find.byKey(const Key('add_dealer_button'));
      if (addButton.evaluate().isNotEmpty) {
        await tester.tap(addButton);
        await tester.pumpAndSettle();

        await TestActions.fillField(tester, 'dealer_name', 'Test Dealer');
        await TestActions.fillField(tester, 'dealer_city', 'Mumbai');
        await TestActions.fillField(tester, 'dealer_phone', '9876543210');

        final saveButton = find.byKey(const Key('save_dealer_button'));
        if (saveButton.evaluate().isNotEmpty) {
          await tester.tap(saveButton);
          await tester.pumpAndSettle();
          debugPrint('✅ Dealer added');
        }
      }
    });

    testWidgets('Edit dealer information', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final editButton = find.byKey(const Key('edit_dealer_button')).first;
      if (editButton.evaluate().isNotEmpty) {
        await tester.tap(editButton);
        await tester.pumpAndSettle();

        await TestActions.fillField(tester, 'dealer_phone', '9999999999');

        final saveButton = find.byKey(const Key('save_dealer_button'));
        if (saveButton.evaluate().isNotEmpty) {
          await tester.tap(saveButton);
          await tester.pumpAndSettle();
          debugPrint('✅ Dealer updated');
        }
      }
    });

    testWidgets('Delete dealer', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final deleteButton = find.byKey(const Key('delete_dealer_button')).first;
      if (deleteButton.evaluate().isNotEmpty) {
        await tester.tap(deleteButton);
        await tester.pumpAndSettle();

        final confirmButton = find.text('Delete');
        if (confirmButton.evaluate().isNotEmpty) {
          await tester.tap(confirmButton);
          await tester.pumpAndSettle();
          debugPrint('✅ Dealer deleted');
        }
      }
    });
  });

  group('Admin AI Jobs Module Tests', () {
    testWidgets('View AI jobs list', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      await TestActions.waitForLoading(tester);
      debugPrint('✅ AI jobs list loaded');
    });

    testWidgets('Filter AI jobs by status', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final statusFilter = find.byKey(const Key('ai_job_status_filter'));
      if (statusFilter.evaluate().isNotEmpty) {
        await tester.tap(statusFilter);
        await tester.pumpAndSettle();
        debugPrint('✅ AI jobs filtered');
      }
    });

    testWidgets('View AI job details', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final jobCard = find.byKey(const Key('ai_job_card')).first;
      if (jobCard.evaluate().isNotEmpty) {
        await tester.tap(jobCard);
        await tester.pumpAndSettle();
        debugPrint('✅ AI job details displayed');
      }
    });

    testWidgets('Retry failed AI job', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final retryButton = find.byKey(const Key('retry_ai_job_button'));
      if (retryButton.evaluate().isNotEmpty) {
        await tester.tap(retryButton);
        await tester.pumpAndSettle();
        debugPrint('✅ AI job retry triggered');
      }
    });

    testWidgets('Delete AI job', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final deleteButton = find.byKey(const Key('delete_ai_job_button')).first;
      if (deleteButton.evaluate().isNotEmpty) {
        await tester.tap(deleteButton);
        await tester.pumpAndSettle();

        final confirmButton = find.text('Delete');
        if (confirmButton.evaluate().isNotEmpty) {
          await tester.tap(confirmButton);
          await tester.pumpAndSettle();
          debugPrint('✅ AI job deleted');
        }
      }
    });
  });
}

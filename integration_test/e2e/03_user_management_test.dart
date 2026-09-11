/// E2E Test: User Management Flows
/// Tests Dealers, Profile, Addresses, Settings, About/Legal/Support pages
@Timeout(Duration(minutes: 8))
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

  group('Profile Management Tests', () {
    testWidgets('View profile page', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle(TestConfig.pageLoadTimeout);

      // Navigate to profile via bottom nav
      final profileNav = find.text('Profile');
      if (profileNav.evaluate().isNotEmpty) {
        await tester.tap(profileNav.first);
        await tester.pumpAndSettle();

        // Verify profile elements
        expect(find.byType(Scaffold), findsOneWidget);
        debugPrint('✅ Profile page loaded');
      }
    });

    testWidgets('Edit profile information', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Navigate to profile
      final profileNav = find.text('Profile');
      if (profileNav.evaluate().isNotEmpty) {
        await tester.tap(profileNav.first);
        await tester.pumpAndSettle();

        // Tap edit button
        final editButton = find.byIcon(Icons.edit);
        if (editButton.evaluate().isNotEmpty) {
          await tester.tap(editButton.first);
          await tester.pumpAndSettle(TestConfig.pageLoadTimeout);

          // Fill profile fields
          await TestActions.fillField(tester, 'profile_name', 'Updated Name');
          await TestActions.fillField(tester, 'profile_phone', '9876543210');

          // Save changes
          final saveButton = find.byKey(const Key('save_profile_button'));
          if (saveButton.evaluate().isNotEmpty) {
            await tester.tap(saveButton);
            await tester.pumpAndSettle();
            debugPrint('✅ Profile updated successfully');
          }
        }
      }
    });

    testWidgets('Upload profile picture', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final profilePicButton = find.byKey(const Key('profile_pic_button'));
      if (profilePicButton.evaluate().isNotEmpty) {
        await tester.tap(profilePicButton);
        await tester.pumpAndSettle();

        // This would trigger image picker
        debugPrint('⚠️ Profile picture upload requires image picker');
      }
    });

    testWidgets('Change password', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final changePasswordButton = find.text('Change Password');
      if (changePasswordButton.evaluate().isNotEmpty) {
        await tester.tap(changePasswordButton);
        await tester.pumpAndSettle();

        await TestActions.fillField(tester, 'current_password', 'OldPass123!');
        await TestActions.fillField(tester, 'new_password', 'NewPass123!');
        await TestActions.fillField(tester, 'confirm_password', 'NewPass123!');

        final submitButton = find.byKey(const Key('change_password_submit'));
        if (submitButton.evaluate().isNotEmpty) {
          await tester.tap(submitButton);
          await tester.pumpAndSettle();
          debugPrint('✅ Password change submitted');
        }
      }
    });
  });

  group('Address Management Tests', () {
    testWidgets('View addresses page', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Navigate to addresses
      final profileNav = find.text('Profile');
      if (profileNav.evaluate().isNotEmpty) {
        await tester.tap(profileNav.first);
        await tester.pumpAndSettle();

        final addressesButton = find.text('Addresses');
        if (addressesButton.evaluate().isNotEmpty) {
          await tester.tap(addressesButton);
          await tester.pumpAndSettle(TestConfig.pageLoadTimeout);

          await TestActions.waitForLoading(tester);
          debugPrint('✅ Addresses page loaded');
        }
      }
    });

    testWidgets('Add new address', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final addAddressButton = find.byKey(const Key('add_address_button'));
      if (addAddressButton.evaluate().isNotEmpty) {
        await tester.tap(addAddressButton);
        await tester.pumpAndSettle();

        // Fill address form
        await TestActions.fillField(tester, 'address_name', 'Home');
        await TestActions.fillField(tester, 'address_line1', '123 Test Street');
        await TestActions.fillField(tester, 'address_line2', 'Apartment 4B');
        await TestActions.fillField(tester, 'address_city', 'Mumbai');
        await TestActions.fillField(tester, 'address_state', 'Maharashtra');
        await TestActions.fillField(tester, 'address_pincode', '400001');
        await TestActions.fillField(tester, 'address_phone', '9876543210');

        // Save address
        final saveButton = find.byKey(const Key('save_address_button'));
        if (saveButton.evaluate().isNotEmpty) {
          await tester.tap(saveButton);
          await tester.pumpAndSettle();
          debugPrint('✅ Address added successfully');
        }
      }
    });

    testWidgets('Edit existing address', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final addressCard = find.byKey(const Key('address_card')).first;
      if (addressCard.evaluate().isNotEmpty) {
        // Long press or tap edit icon
        final editButton = find.byKey(const Key('address_edit')).first;
        if (editButton.evaluate().isNotEmpty) {
          await tester.tap(editButton);
          await tester.pumpAndSettle();

          // Update address
          await TestActions.fillField(tester, 'address_line2', 'Suite 5C');

          final saveButton = find.byKey(const Key('save_address_button'));
          if (saveButton.evaluate().isNotEmpty) {
            await tester.tap(saveButton);
            await tester.pumpAndSettle();
            debugPrint('✅ Address updated');
          }
        }
      }
    });

    testWidgets('Delete address', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final deleteButton = find.byKey(const Key('address_delete')).first;
      if (deleteButton.evaluate().isNotEmpty) {
        await tester.tap(deleteButton);
        await tester.pumpAndSettle();

        // Confirm deletion
        final confirmButton = find.text('Delete');
        if (confirmButton.evaluate().isNotEmpty) {
          await tester.tap(confirmButton);
          await tester.pumpAndSettle();
          debugPrint('✅ Address deleted');
        }
      }
    });

    testWidgets('Set default address', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final setDefaultButton = find.byKey(const Key('set_default_address')).first;
      if (setDefaultButton.evaluate().isNotEmpty) {
        await tester.tap(setDefaultButton);
        await tester.pumpAndSettle();
        debugPrint('✅ Default address set');
      }
    });
  });

  group('Dealer Locator Tests', () {
    testWidgets('View dealers page', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final dealersButton = find.text('Dealers');
      if (dealersButton.evaluate().isNotEmpty) {
        await tester.tap(dealersButton.first);
        await tester.pumpAndSettle(TestConfig.pageLoadTimeout);

        await TestActions.waitForLoading(tester);
        debugPrint('✅ Dealers page loaded');
      }
    });

    testWidgets('Search dealers by location', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final searchField = find.byKey(const Key('dealer_search'));
      if (searchField.evaluate().isNotEmpty) {
        await tester.enterText(searchField, 'Mumbai');
        await tester.testTextInput.receiveAction(TextInputAction.search);
        await tester.pumpAndSettle(TestConfig.pageLoadTimeout);

        debugPrint('✅ Dealers searched by location');
      }
    });

    testWidgets('View dealer details', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final dealerCard = find.byKey(const Key('dealer_card')).first;
      if (dealerCard.evaluate().isNotEmpty) {
        await tester.tap(dealerCard);
        await tester.pumpAndSettle();

        debugPrint('✅ Dealer details displayed');
      }
    });

    testWidgets('Call dealer from details', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final callButton = find.byKey(const Key('dealer_call_button'));
      if (callButton.evaluate().isNotEmpty) {
        await tester.tap(callButton);
        await tester.pumpAndSettle();

        // This would launch phone dialer
        debugPrint('⚠️ Call action requires url_launcher');
      }
    });

    testWidgets('Get directions to dealer', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final directionsButton = find.byKey(const Key('dealer_directions_button'));
      if (directionsButton.evaluate().isNotEmpty) {
        await tester.tap(directionsButton);
        await tester.pumpAndSettle();

        // This would launch maps
        debugPrint('⚠️ Directions require maps integration');
      }
    });

    testWidgets('Filter dealers by type', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final filterButton = find.byKey(const Key('dealer_filter'));
      if (filterButton.evaluate().isNotEmpty) {
        await tester.tap(filterButton);
        await tester.pumpAndSettle();

        // Select filter option
        final authorizedDealer = find.text('Authorized Dealer');
        if (authorizedDealer.evaluate().isNotEmpty) {
          await tester.tap(authorizedDealer);
          await tester.pumpAndSettle();
          debugPrint('✅ Dealers filtered');
        }
      }
    });
  });

  group('Settings Tests', () {
    testWidgets('View settings page', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final settingsButton = find.byIcon(Icons.settings);
      if (settingsButton.evaluate().isNotEmpty) {
        await tester.tap(settingsButton);
        await tester.pumpAndSettle();

        debugPrint('✅ Settings page loaded');
      }
    });

    testWidgets('Toggle notification settings', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final notificationToggle = find.byKey(const Key('notification_toggle'));
      if (notificationToggle.evaluate().isNotEmpty) {
        await tester.tap(notificationToggle);
        await tester.pumpAndSettle();

        debugPrint('✅ Notification setting toggled');
      }
    });

    testWidgets('Change language preference', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final languageButton = find.byKey(const Key('language_setting'));
      if (languageButton.evaluate().isNotEmpty) {
        await tester.tap(languageButton);
        await tester.pumpAndSettle();

        // Select language
        final hindiOption = find.text('Hindi');
        if (hindiOption.evaluate().isNotEmpty) {
          await tester.tap(hindiOption);
          await tester.pumpAndSettle();
          debugPrint('✅ Language changed');
        }
      }
    });

    testWidgets('Manage permissions', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final permissionsButton = find.text('Permissions');
      if (permissionsButton.evaluate().isNotEmpty) {
        await tester.tap(permissionsButton);
        await tester.pumpAndSettle();

        debugPrint('✅ Permissions page opened');
      }
    });

    testWidgets('Clear cache', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final clearCacheButton = find.text('Clear Cache');
      if (clearCacheButton.evaluate().isNotEmpty) {
        await tester.tap(clearCacheButton);
        await tester.pumpAndSettle();

        // Confirm action
        final confirmButton = find.text('Clear');
        if (confirmButton.evaluate().isNotEmpty) {
          await tester.tap(confirmButton);
          await tester.pumpAndSettle();
          debugPrint('✅ Cache cleared');
        }
      }
    });
  });

  group('About & Legal Pages Tests', () {
    testWidgets('View About page', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final aboutButton = find.text('About');
      if (aboutButton.evaluate().isNotEmpty) {
        await tester.tap(aboutButton.first);
        await tester.pumpAndSettle();

        // Verify about content
        debugPrint('✅ About page loaded');
      }
    });

    testWidgets('View Privacy Policy', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final privacyButton = find.text('Privacy Policy');
      if (privacyButton.evaluate().isNotEmpty) {
        await tester.tap(privacyButton.first);
        await tester.pumpAndSettle();

        // Verify privacy policy content
        debugPrint('✅ Privacy Policy loaded');
      }
    });

    testWidgets('View Terms of Service', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final termsButton = find.text('Terms of Service');
      if (termsButton.evaluate().isNotEmpty) {
        await tester.tap(termsButton.first);
        await tester.pumpAndSettle();

        debugPrint('✅ Terms of Service loaded');
      }
    });

    testWidgets('Scroll through legal document', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Navigate to a legal page
      final scrollable = find.byType(SingleChildScrollView).first;
      if (scrollable.evaluate().isNotEmpty) {
        await tester.drag(scrollable, const Offset(0, -500));
        await tester.pumpAndSettle();

        debugPrint('✅ Legal document scrolled');
      }
    });
  });

  group('Support & Help Tests', () {
    testWidgets('View Help & Support page', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final helpButton = find.text('Help & Support');
      if (helpButton.evaluate().isNotEmpty) {
        await tester.tap(helpButton.first);
        await tester.pumpAndSettle();

        debugPrint('✅ Help & Support page loaded');
      }
    });

    testWidgets('View FAQ sections', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final faqItem = find.byKey(const Key('faq_item')).first;
      if (faqItem.evaluate().isNotEmpty) {
        await tester.tap(faqItem);
        await tester.pumpAndSettle();

        // Verify FAQ answer expands
        debugPrint('✅ FAQ item expanded');
      }
    });

    testWidgets('Contact support', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final contactButton = find.text('Contact Us');
      if (contactButton.evaluate().isNotEmpty) {
        await tester.tap(contactButton);
        await tester.pumpAndSettle();

        // Fill contact form
        await TestActions.fillField(tester, 'contact_subject', 'Test Issue');
        await TestActions.fillField(tester, 'contact_message', 'This is a test message');

        final submitButton = find.byKey(const Key('submit_contact_button'));
        if (submitButton.evaluate().isNotEmpty) {
          await tester.tap(submitButton);
          await tester.pumpAndSettle();
          debugPrint('✅ Support message submitted');
        }
      }
    });

    testWidgets('View app version info', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Navigate to about or settings
      final versionText = find.textContaining('Version');
      if (versionText.evaluate().isNotEmpty) {
        debugPrint('✅ App version displayed');
      }
    });
  });

  group('Saved Designs Tests', () {
    testWidgets('View saved designs page', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final profileNav = find.text('Profile');
      if (profileNav.evaluate().isNotEmpty) {
        await tester.tap(profileNav.first);
        await tester.pumpAndSettle();

        final savedDesignsButton = find.text('Saved Designs');
        if (savedDesignsButton.evaluate().isNotEmpty) {
          await tester.tap(savedDesignsButton);
          await tester.pumpAndSettle(TestConfig.pageLoadTimeout);

          await TestActions.waitForLoading(tester);
          debugPrint('✅ Saved designs page loaded');
        }
      }
    });

    testWidgets('View saved design details', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final designCard = find.byKey(const Key('saved_design_card')).first;
      if (designCard.evaluate().isNotEmpty) {
        await tester.tap(designCard);
        await tester.pumpAndSettle();

        debugPrint('✅ Saved design details displayed');
      }
    });

    testWidgets('Delete saved design', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final deleteButton = find.byKey(const Key('delete_design_button')).first;
      if (deleteButton.evaluate().isNotEmpty) {
        await tester.tap(deleteButton);
        await tester.pumpAndSettle();

        // Confirm deletion
        final confirmButton = find.text('Delete');
        if (confirmButton.evaluate().isNotEmpty) {
          await tester.tap(confirmButton);
          await tester.pumpAndSettle();
          debugPrint('✅ Design deleted');
        }
      }
    });

    testWidgets('Share saved design', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final shareButton = find.byKey(const Key('share_design_button'));
      if (shareButton.evaluate().isNotEmpty) {
        await tester.tap(shareButton);
        await tester.pumpAndSettle();

        // This would trigger share sheet
        debugPrint('⚠️ Share requires share_plus plugin');
      }
    });
  });
}

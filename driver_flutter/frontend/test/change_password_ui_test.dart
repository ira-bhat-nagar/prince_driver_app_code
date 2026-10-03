import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gorush_driver/main.dart';
import 'package:gorush_driver/core/demo_controller.dart';
import 'package:gorush_driver/services/app_language_service.dart';
import 'package:gorush_driver/services/driver_backend_service.dart';
import 'package:gorush_driver/services/token_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Change Password UI & Field Behavior Tests', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      AppLanguageService.instance.setLanguage('en');
      await TokenStorageService.instance.init();
      await DriverBackendService.instance.initSession();
      await DriverBackendService.instance.saveSession(
        driverProfile: {
          'name': 'Rohit Sharma',
          'phone': '+91 98765 43210',
          'email': 'rohit@gorush.com',
          'status': 'online',
          'vehicleId': 'DL 01 AB 1234',
        },
      );
    });

    testWidgets('Change Password fields open completely EMPTY with zero bullets initially', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(600, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(const GoRushDriverApp(initialScreen: DemoScreen.driverProfileVehicleSettings));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Open Change Password Sheet
      final changePassTile = find.text('Change Password / PIN');
      expect(changePassTile, findsOneWidget);
      await tester.ensureVisible(changePassTile);
      await tester.tap(changePassTile);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify the sheet opened
      expect(find.text('Update Password'), findsOneWidget);

      // Verify all 3 password fields exist
      final textFields = find.byType(TextField);
      expect(textFields, findsNWidgets(3));

      // Verify each field is completely EMPTY with no pre-filled text or bullet hint
      for (int i = 0; i < 3; i++) {
        final TextField field = tester.widget<TextField>(textFields.at(i));
        expect(field.controller?.text, '', reason: 'Field $i must have completely empty controller text');
        expect(field.decoration?.hintText, '', reason: 'Field $i must not display bullet hints');
        expect(field.obscureText, isTrue, reason: 'Field $i must obscure text by default when user types');
      }

      // CASE 1: Tap Update Password with all fields empty -> Error toast
      await tester.tap(find.text('Update Password'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text('Please enter your current password'), findsOneWidget);

      // CASE 2: Enter only current password -> Error toast for new password
      await tester.enterText(textFields.at(0), 'CurrentPass123');
      await tester.pump();
      await tester.tap(find.text('Update Password'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text('Please enter your new password'), findsOneWidget);

      // CASE 5: Enter mismatched new password and confirm password -> Error toast
      await tester.enterText(textFields.at(1), 'NewPass123');
      await tester.enterText(textFields.at(2), 'DifferentPass999');
      await tester.pump();
      await tester.tap(find.text('Update Password'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text('Passwords do not match'), findsOneWidget);

      // Verify toggle visibility icons work independently
      final eyeIcons = find.byIcon(Icons.visibility_off_outlined);
      expect(eyeIcons, findsNWidgets(3));
      // Tap toggle visibility on field 0
      await tester.tap(eyeIcons.at(0));
      await tester.pump();

      final TextField field0AfterToggle = tester.widget<TextField>(textFields.at(0));
      final TextField field1AfterToggle = tester.widget<TextField>(textFields.at(1));
      expect(field0AfterToggle.obscureText, isFalse, reason: 'Field 0 obscureText should be toggled to false');
      expect(field1AfterToggle.obscureText, isTrue, reason: 'Field 1 obscureText should remain independent');

      // Clear fields and verify they return to completely empty
      await tester.enterText(textFields.at(0), '');
      await tester.enterText(textFields.at(1), '');
      await tester.enterText(textFields.at(2), '');
      await tester.pump();

      for (int i = 0; i < 3; i++) {
        final TextField field = tester.widget<TextField>(textFields.at(i));
        expect(field.controller?.text, '', reason: 'Cleared field $i must be empty');
      }
    });
  });
}

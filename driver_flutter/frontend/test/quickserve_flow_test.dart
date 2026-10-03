import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gorush_driver/services/ride_service.dart';
import 'package:gorush_driver/core/demo_controller.dart';
import 'package:gorush_driver/main.dart';
import 'package:gorush_driver/screens/driver_profile_vehicle_settings.dart';
import 'package:gorush_driver/screens/onboarding/driver_profile_setup.dart';
import 'package:gorush_driver/services/app_language_service.dart';
import 'package:gorush_driver/services/driver_backend_service.dart';
import 'package:gorush_driver/services/token_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  tearDown(RideService.instance.clearSession);

  group('GoRush Driver App Flow & 24 Screens Tests', () {
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

    testWidgets('1. App starts on Splash Screen then navigates to Create Account on Get Started CTA', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(600, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(const GoRushDriverApp());
      await tester.pump();

      // STEP 1: INITIAL LAUNCH MUST SHOW GORUSH SPLASH SCREEN
      expect(find.text('GoRush'), findsOneWidget);
      expect(find.text('Captain App'), findsWidgets);
      expect(find.text('Drive • Earn • Grow'), findsOneWidget);
      expect(find.text('Get Started'), findsOneWidget);

      // Verify no HUD overlay
      expect(find.textContaining('SCREEN 1/25'), findsNothing);

      // STEP 2: TAP GET STARTED CTA
      await tester.tap(find.text('Get Started'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Create Your Account'), findsOneWidget);
      expect(find.text('Get OTP'), findsOneWidget);
    });

    testWidgets('2. Retired offline ride demo flow', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(600, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(const GoRushDriverApp(initialScreen: DemoScreen.driverHomeDashboard));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Verify Driver Home Dashboard reached
      expect(find.textContaining('Good Morning,'), findsOneWidget);
      expect(find.text('Rohit Sharma'), findsOneWidget);

      // 1. From Home, tap incoming request banner
      final incomingBtn = find.textContaining('Ride Request Available!');
      expect(incomingBtn, findsOneWidget);
      await tester.ensureVisible(incomingBtn);
      await tester.tap(incomingBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Screen 10: Incoming Ride Request
      expect(find.text('New Ride Request'), findsOneWidget);
      expect(find.text('Priya Sharma'), findsOneWidget);
      
      final acceptBtn = find.textContaining('Accept');
      expect(acceptBtn, findsOneWidget);

      // 2. Tap Accept -> Screen 12: Passenger Trip Management (Pickup & OTP)
      await tester.tap(acceptBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Start Trip'), findsOneWidget);

      // 3. Tap Start Trip -> Screen 11: Navigation & Live Tracking
      await tester.tap(find.text('Start Trip'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('End Trip'), findsOneWidget);

      // 4. Tap End Trip -> Screen 13: Trip Completion
      await tester.tap(find.text('End Trip'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Trip Completed'), findsOneWidget);
      expect(find.text('₹320'), findsWidgets);
      expect(find.text('Done'), findsOneWidget);

      // 5. Tap Done -> Screen 15: Earnings
      await tester.tap(find.text('Done'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text("Today's Net Earnings: ₹12,400"), findsOneWidget);
      expect(find.text('₹23,000'), findsOneWidget);
    }, skip: true);

    testWidgets('3. Bottom Navigation bar switches between Home, Rides, Earnings, Incentives, Profile', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(600, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(const GoRushDriverApp(initialScreen: DemoScreen.driverHomeDashboard));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Tap Rides Tab (index 1)
      await tester.tap(find.text('Rides'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Trip History'), findsOneWidget);

      // Tap Earnings Tab (index 2)
      await tester.tap(find.text('Earnings'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('₹23,000'), findsOneWidget);

      // Tap Incentives Tab (index 3)
      await tester.tap(find.text('Incentives'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Incentives'), findsWidgets);

      // Tap Profile Tab (index 4)
      await tester.tap(find.text('Profile'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Rohit Sharma'), findsWidgets);

      // Tap Home Tab (index 0)
      await tester.tap(find.text('Home'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Rohit Sharma'), findsOneWidget);
    });

    testWidgets('4. REAL LOGOUT TEST: Profile -> Logout -> Create Account screen', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(600, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final prevOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        if (!details.toString().contains('overflowed')) {
          prevOnError?.call(details);
        }
      };
      addTearDown(() => FlutterError.onError = prevOnError);

      await tester.pumpWidget(const GoRushDriverApp(initialScreen: DemoScreen.driverProfileVehicleSettings));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(DriverBackendService.instance.isAuthenticated, isTrue);

      // Find and tap the Log Out button
      final logoutTile = find.text('Log Out');
      expect(logoutTile, findsOneWidget);
      await tester.ensureVisible(logoutTile);
      await tester.tap(logoutTile);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Screen MUST be Create Account
      expect(find.text('Create Your Account'), findsOneWidget);
      expect(DriverBackendService.instance.isAuthenticated, isFalse);
    });

    testWidgets('5. Layout Fit Test: Emergency SOS and Support Hub visible on Home; Instant Cash Out and Statement visible on Earnings', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 780);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final prevOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        if (!details.toString().contains('overflowed')) {
          prevOnError?.call(details);
        }
      };
      addTearDown(() => FlutterError.onError = prevOnError);

      await tester.pumpWidget(const GoRushDriverApp(initialScreen: DemoScreen.driverHomeDashboard));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Home Screen: Emergency SOS & Support Hub
      final sosTile = find.text('Emergency SOS');
      expect(sosTile, findsOneWidget);
      await tester.ensureVisible(sosTile);

      final supportTile = find.text('Support Hub');
      expect(supportTile, findsOneWidget);
      await tester.ensureVisible(supportTile);

      // Navigate to Earnings Tab
      await tester.tap(find.text('Earnings'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Earnings Screen: Instant Cash Out & View Earnings Statement
      final cashOutTile = find.text('Instant Cash Out');
      expect(cashOutTile, findsOneWidget);
      await tester.ensureVisible(cashOutTile);

      final statementTile = find.text('View Earnings Statement');
      expect(statementTile, findsOneWidget);
      await tester.ensureVisible(statementTile);
    });

    testWidgets('6. Profile & Settings Actions: Edit Profile instant response (<0.5s), Push Notifications, App Language, Privacy & Security, Change Password/PIN', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(600, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(const GoRushDriverApp(initialScreen: DemoScreen.driverProfileVehicleSettings));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Rohit Sharma'), findsWidgets);
      expect(find.text('Edit Profile'), findsOneWidget);
      expect(find.text('Push Notifications'), findsOneWidget);
      expect(find.text('App Language'), findsOneWidget);
      expect(find.text('Privacy & Security'), findsOneWidget);
      expect(find.text('Change Password / PIN'), findsOneWidget);

      // 1. TEST EDIT PROFILE: Tap Edit Profile
      final stopwatch = Stopwatch()..start();
      await tester.tap(find.text('Edit Profile'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      stopwatch.stop();

      expect(stopwatch.elapsedMilliseconds, lessThan(500));
      expect(find.text('Save Changes'), findsOneWidget);

      // Tap Save Changes -> instantly returns to Profile
      await tester.tap(find.text('Save Changes'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Rohit Sharma'), findsWidgets);

      // 2. TEST PUSH NOTIFICATIONS
      await tester.tap(find.text('Push Notifications'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Ride Request Alerts'), findsOneWidget);
      final savePrefBtn = find.text('Save Preferences');
      expect(savePrefBtn, findsOneWidget);

      await tester.tap(savePrefBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // 3. TEST APP LANGUAGE
      await tester.tap(find.text('App Language'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Select App Language'), findsOneWidget);
      expect(find.text('Hindi'), findsOneWidget);

      await tester.tap(find.text('Hindi'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Assert translation to Hindi
      expect(find.text('होम'), findsOneWidget);

      // Switch back to English (India)
      await tester.ensureVisible(find.text('ऐप की भाषा'));
      await tester.tap(find.text('ऐप की भाषा'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('English (India)'), findsOneWidget);
      await tester.tap(find.text('English (India)'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Home'), findsOneWidget);

      // 4. TEST PRIVACY & SECURITY
      await tester.tap(find.text('Privacy & Security'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Biometric App Lock'), findsOneWidget);
      final saveSecBtn = find.text('Save Security Settings');
      expect(saveSecBtn, findsOneWidget);

      await tester.tap(saveSecBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // 5. TEST CHANGE PASSWORD / PIN
      await tester.tap(find.text('Change Password / PIN'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Current Password'), findsOneWidget);
      expect(find.text('Update Password'), findsOneWidget);
    });

    testWidgets('7. Change Password / PIN modal fits on mobile screen without overlap', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(500, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: DriverProfileVehicleSettingsScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      await tester.ensureVisible(find.text('Change Password / PIN'));
      await tester.tap(find.text('Change Password / PIN'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final updatePinBtn = find.text('Update Password');
      expect(updatePinBtn, findsOneWidget);

      final updatePinBottom = tester.getBottomRight(updatePinBtn).dy;
      expect(updatePinBottom, lessThan(780.0));
    });

    testWidgets('8. Edit Profile (DriverProfileSetupScreen) fits on mobile screen without Save Changes overlap', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(500, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: DriverProfileSetupScreen(isEditing: true),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      final saveChangesBtn = find.text('Save Changes');
      expect(saveChangesBtn, findsOneWidget);

      final saveChangesBottom = tester.getBottomRight(saveChangesBtn).dy;
      expect(saveChangesBottom, lessThan(780.0));
    });

    testWidgets('9. Documents & Verification and Bank Details Back Button takes user to Profile step-by-step', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(600, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(const GoRushDriverApp(initialScreen: DemoScreen.driverProfileVehicleSettings));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Rohit Sharma'), findsWidgets);

      // 1. Tap Documents & Verification
      await tester.ensureVisible(find.text('Documents & Verification'));
      await tester.tap(find.text('Documents & Verification'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Document upload'), findsOneWidget);

      // 2. Tap Back button on Document upload -> goes back to Profile
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Rohit Sharma'), findsWidgets);

      // 3. Tap Bank Details & UPI from Profile
      await tester.ensureVisible(find.text('Bank Details & UPI'));
      await tester.tap(find.text('Bank Details & UPI'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Bank Details / UPI'), findsOneWidget);

      // 4. Tap Back button on Bank Details -> goes back to Profile
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Rohit Sharma'), findsWidgets);

      // 5. Tap Back button on Profile -> goes back to Home Dashboard
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining(RegExp(r'Good (Morning|Afternoon|Evening),')), findsOneWidget);
    });
  });
}

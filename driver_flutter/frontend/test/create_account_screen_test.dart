import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gorush_driver/screens/onboarding/driver_login_registration.dart';

void main() {
  testWidgets('Phone entry proceeds to OTP verification', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 850);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const MaterialApp(
        home: DriverLoginRegistrationScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Get OTP'), findsOneWidget);
    expect(find.text('Create Your Account'), findsOneWidget);
    expect(find.text('Enter Mobile Number'), findsOneWidget);
  });

  testWidgets('OTP success form shows Captain account details with phone filled',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 850);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    OtpSession.phoneNumber = '9876543210';
    await tester.pumpWidget(const MaterialApp(
      home: DriverLoginRegistrationScreen(otpVerified: true),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Captain App'), findsOneWidget);
    expect(find.text('Create Your Account'), findsOneWidget);
    expect(find.text('Full Name'), findsOneWidget);
    expect(find.text('Date of Birth (18+ required)'), findsOneWidget);
    expect(find.text('Email Address'), findsOneWidget);
    expect(find.text('Create Password'), findsOneWidget);
    expect(find.text('Vehicle Number'), findsNothing);
    expect(find.text('License Number'), findsNothing);
    expect(find.text('Register'), findsOneWidget);
    expect(
      tester.widgetList<TextField>(find.byType(TextField)).elementAt(2).controller?.text,
      '9876543210',
    );
  });
}

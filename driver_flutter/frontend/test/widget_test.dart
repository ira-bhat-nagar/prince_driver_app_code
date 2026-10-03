import 'package:flutter_test/flutter_test.dart';
import 'package:gorush_driver/main.dart';
import 'package:gorush_driver/core/demo_controller.dart';

void main() {
  testWidgets('GoRush Driver App launches into approved Splash Screen', (WidgetTester tester) async {
    await tester.pumpWidget(const GoRushDriverApp(initialScreen: DemoScreen.splashScreen));
    await tester.pump();

    // Verify approved First Screen (GoRush Driver App Splash)
    expect(find.text('GoRush'), findsOneWidget);
    expect(find.text('Captain App'), findsWidgets);
    expect(find.text('Drive • Earn • Grow'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);

    // Tap Get Started
    await tester.tap(find.text('Get Started'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Navigates to Create Account / Register screen
    expect(find.text('Create Your Account'), findsOneWidget);
    expect(find.text('Get OTP'), findsOneWidget);
  });
}

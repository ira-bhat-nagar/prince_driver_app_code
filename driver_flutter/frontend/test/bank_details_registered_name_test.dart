import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gorush_driver/screens/onboarding/bank_details_screen.dart';
import 'package:gorush_driver/services/token_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('bank account holder defaults to the registered driver name',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await TokenStorageService.instance.saveSession(
      accessToken: 'test-token',
      driverProfile: {
        'name': 'Yuma',
        'bankDetails': {'accountHolderName': 'Outdated Driver Name'},
      },
    );

    await tester.pumpWidget(
      const MaterialApp(home: BankDetailsScreen()),
    );

    final holderField = tester.widget<TextFormField>(
      find.byType(TextFormField).at(1),
    );
    expect(holderField.controller?.text, 'Yuma');
  });
}

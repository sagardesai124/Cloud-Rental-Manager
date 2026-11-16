import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus_platform_interface/connectivity_plus_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:three_zero_two_property/Model/PropertyInsuranceModel.dart';
import 'package:three_zero_two_property/StaffModule/repository/staffpermission_provider.dart';
import 'package:three_zero_two_property/StaffModule/screen/Rental/Properties/Insurance%20Premium/AddEditInsurancePolicy.dart'
    as staff_policy;
import 'package:three_zero_two_property/StaffModule/screen/Rental/Properties/Insurance%20Premium/AddEditInsurancePremium.dart'
    as staff_premium;
import 'package:three_zero_two_property/provider/Plan%20Purchase/plancheckProvider.dart';
import 'package:three_zero_two_property/provider/dateProvider.dart';
import 'package:three_zero_two_property/provider/notification_provider.dart';
import 'package:three_zero_two_property/screens/Rental/Properties/Insurance%20Premium/AddEditInsurancePolicy.dart'
    as admin_policy;
import 'package:three_zero_two_property/screens/Rental/Properties/Insurance%20Premium/AddEditInsurancePremium.dart'
    as admin_premium;
import 'package:three_zero_two_property/services/insurance_edit_changes.dart';

/// Property › Taxes & Insurance › Edit Insurance Premium / Edit Insurance
/// Policy, like web staging (PropDetails.jsx): when editing, the button says
/// Update and stays greyed out until something differs from what was opened;
/// changing it back greys it out again. Adding always says Save and works.

void main() {
  group("web's premium rule", () {
    bool changed(String year, String carrier, String premium) =>
        insurancePremiumChanged(
          year: year,
          carrier: carrier,
          premium: premium,
          originalYear: '2025',
          originalCarrier: 'ABC Insurance',
          originalPremium: '1200',
        );

    test('nothing changed', () {
      expect(changed('2025', 'ABC Insurance', '1200'), isFalse);
      expect(changed('2025', ' ABC Insurance ', '1,200.00'), isFalse,
          reason: 'trimmed carrier, premium compared as a number');
      expect(changed('2025', 'ABC Insurance', r'$1,200'), isFalse);
    });

    test('any real change counts', () {
      expect(changed('2024', 'ABC Insurance', '1200'), isTrue);
      expect(changed('2025', 'XYZ Insurance', '1200'), isTrue);
      expect(changed('2025', 'ABC Insurance', '1200.01'), isTrue);
      expect(changed('2025', 'ABC Insurance', ''), isTrue);
    });

    test('a stored sub-cent premium shown rounded is a change, like web', () {
      expect(
          insurancePremiumChanged(
            year: '2025',
            carrier: 'ABC',
            premium: '15.67',
            originalYear: '2025',
            originalCarrier: 'ABC',
            originalPremium: '15.6666666666',
          ),
          isTrue);
    });
  });

  test("web's policy rule: any field differs", () {
    final original = {'notes': 'n', 'status': 'Active', 'agent_name': null};
    expect(formValuesChanged({...original}, original), isFalse);
    expect(formValuesChanged({...original, 'agent_name': ''}, original), isFalse,
        reason: 'empty and missing are the same');
    expect(formValuesChanged({...original, 'notes': 'n2'}, original), isTrue);
    expect(formValuesChanged({...original, 'status': 'Expired'}, original),
        isTrue);
  });

  group('on the real screens', () {
    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
              const MethodChannel('PonnamKarthik/fluttertoast'),
              (_) async => true);
      ConnectivityPlatform.instance = _Online();
    });

    Future<void> pump(WidgetTester tester, Widget screen) async {
      SharedPreferences.setMockInitialValues(
          {'token': 'tkn', 'adminId': 'ADMIN-1', 'role': 'Admin'});
      tester.view.physicalSize = const Size(1080, 5000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final original = FlutterError.onError;
      FlutterError.onError = (d) {
        if (d.exceptionAsString().contains('overflowed')) return;
        original?.call(d);
      };
      addTearDown(() => FlutterError.onError = original);
      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => DateProvider()),
          ChangeNotifierProvider(create: (_) => NotificationProvider()),
          ChangeNotifierProvider(create: (_) => checkPlanPurchaseProiver()),
          ChangeNotifierProvider(create: (_) => StaffPermissionProvider()),
        ],
        child: MaterialApp(home: screen),
      ));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    final server = MockClient((request) async => http.Response(
        jsonEncode({
          'success': true,
          'data': {'insurance_premiums': []}
        }),
        200,
        headers: {'content-type': 'application/json'}));

    bool enabled(WidgetTester tester, String label) =>
        tester.widget<ElevatedButton>(
                find.widgetWithText(ElevatedButton, label)).onPressed !=
            null;

    Finder box(String hint) => find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.hintText == hint);

    for (final role in ['Admin', 'Staff']) {
      testWidgets('$role Edit Insurance Premium: Update greyed until a change',
          (tester) async {
        await http.runWithClient(() async {
          final data = {
            'year': '2025',
            'carrier': 'ABC Insurance',
            'insurance_premium': 1200,
            'formatted_premium': r'$1,200.00',
          };
          await pump(
              tester,
              role == 'Admin'
                  ? admin_premium.AddEditInsurancePremium(
                      propertyId: 'P1', premiumId: 'IP1', premiumData: data)
                  : staff_premium.AddEditInsurancePremium(
                      propertyId: 'P1', premiumId: 'IP1', premiumData: data));

          expect(find.widgetWithText(ElevatedButton, 'Save'), findsNothing);
          expect(enabled(tester, 'Update'), isFalse,
              reason: 'nothing changed yet, like web');

          await tester.enterText(box('e.g., ABC Insurance'), 'XYZ Insurance');
          await tester.pump();
          expect(enabled(tester, 'Update'), isTrue);

          await tester.enterText(box('e.g., ABC Insurance'), 'ABC Insurance');
          await tester.pump();
          expect(enabled(tester, 'Update'), isFalse,
              reason: 'changed back: greyed out again');

          // The box opens as "1200", like web; "1200.00" is the same amount.
          expect(
              tester.widget<TextField>(box('e.g., 1200.00')).controller!.text,
              '1200');
          await tester.enterText(box('e.g., 1200.00'), '1200.00');
          await tester.pump();
          expect(enabled(tester, 'Update'), isFalse,
              reason: 'same amount written differently');

          await tester.enterText(box('e.g., 1200.00'), '1250');
          await tester.pump();
          expect(enabled(tester, 'Update'), isTrue);

          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(seconds: 1));
        }, () => server);
      });

      testWidgets('$role Add Insurance Premium: Save works as before',
          (tester) async {
        await http.runWithClient(() async {
          await pump(
              tester,
              role == 'Admin'
                  ? const admin_premium.AddEditInsurancePremium(propertyId: 'P1')
                  : const staff_premium.AddEditInsurancePremium(
                      propertyId: 'P1'));
          expect(find.widgetWithText(ElevatedButton, 'Update'), findsNothing);
          expect(enabled(tester, 'Save'), isTrue);
          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(seconds: 1));
        }, () => server);
      });

      testWidgets('$role Edit Insurance Policy: Update greyed until a change',
          (tester) async {
        await http.runWithClient(() async {
          final policy = PropertyInsuranceData(
            id: 'POL1',
            insuranceCompanyName: 'ABC Insurance',
            policyNumber: 'PN-100',
            policyType: 'Homeowners Insurance (HO Policies)',
            formNumber: 'HO-3 (Special Form)',
            namedInsured: 'Pat Owner',
            effectiveDate: '2026-01-01',
            expirationDate: '2027-01-01',
            premiumAmount: 900,
            deductible: 500,
            paymentTerms: 'Annual',
            status: 'Active',
            notes: 'Initial notes',
          );
          await pump(
              tester,
              role == 'Admin'
                  ? admin_policy.AddEditInsurancePolicy(
                      propertyId: 'P1', policyId: 'POL1', policyData: policy)
                  : staff_policy.AddEditInsurancePolicy(
                      propertyId: 'P1', policyId: 'POL1', policyData: policy));

          expect(find.widgetWithText(ElevatedButton, 'Save'), findsNothing);
          expect(enabled(tester, 'Update'), isFalse,
              reason: 'nothing changed yet, like web');

          final notes = box('Enter any additional notes or comments');
          await tester.enterText(notes, 'Updated notes');
          await tester.pump();
          expect(enabled(tester, 'Update'), isTrue);

          await tester.enterText(notes, 'Initial notes');
          await tester.pump();
          expect(enabled(tester, 'Update'), isFalse,
              reason: 'changed back: greyed out again');

          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(seconds: 1));
        }, () => server);
      });

      testWidgets('$role Add Insurance Policy: Save works as before',
          (tester) async {
        await http.runWithClient(() async {
          await pump(
              tester,
              role == 'Admin'
                  ? const admin_policy.AddEditInsurancePolicy(propertyId: 'P1')
                  : const staff_policy.AddEditInsurancePolicy(propertyId: 'P1'));
          expect(find.widgetWithText(ElevatedButton, 'Update'), findsNothing);
          expect(enabled(tester, 'Save'), isTrue);
          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(seconds: 1));
        }, () => server);
      });
    }
  });

  test('all 4 forms use the rule', () {
    for (final path in [
      'lib/screens/Rental/Properties/Insurance Premium/AddEditInsurancePremium.dart',
      'lib/StaffModule/screen/Rental/Properties/Insurance Premium/AddEditInsurancePremium.dart',
      'lib/screens/Rental/Properties/Insurance Premium/AddEditInsurancePolicy.dart',
      'lib/StaffModule/screen/Rental/Properties/Insurance Premium/AddEditInsurancePolicy.dart',
    ]) {
      final src = File(path).readAsStringSync();
      expect(src, contains('onPressed: (_isLoading || !_hasChanges) ? null : _saveForm,'),
          reason: path);
      expect(src, contains("isEditMode ? 'Update' : 'Save',"), reason: path);
    }
  });
}

class _Online extends ConnectivityPlatform with MockPlatformInterfaceMixin {
  @override
  Future<ConnectivityResult> checkConnectivity() async =>
      ConnectivityResult.wifi;
  @override
  Stream<ConnectivityResult> get onConnectivityChanged => const Stream.empty();
}

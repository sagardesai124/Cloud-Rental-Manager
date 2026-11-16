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

/// Property › Annual Expenses › Insurance, like web staging (PropDetails.jsx):
/// the edit forms show a saved amount the way web does.
/// - Edit Insurance Policy, Premium Amount and Deductible: web shows
///   formatCurrencyInput(String(amount)), so 3 is "3" and 1500 is "1,500".
///   The app showed "3.0" and "1500.0".
/// - Edit Insurance Premium: web shows String(roundToCents(premium)), so 2 is
///   "2". The app showed "2.00".

const _formatter = InsuranceAmountInputFormatter();

TextEditingValue _at(String text, [int? cursor]) => TextEditingValue(
    text: text,
    selection: TextSelection.collapsed(offset: cursor ?? text.length));

/// Types [chars] one by one at the end of [start].
TextEditingValue _typeAtEnd(TextEditingValue start, String chars) {
  var value = start;
  for (final ch in chars.split('')) {
    value = _formatter.formatEditUpdate(value, _at(value.text + ch));
  }
  return value;
}

void main() {
  group("Edit Insurance Premium box, like web's String(roundToCents(..))", () {
    test('no trailing zeros, no commas', () {
      expect(insurancePremiumBoxText(2), '2', reason: 'not "2.00"');
      expect(insurancePremiumBoxText(2.0), '2', reason: 'not "2.0"');
      expect(insurancePremiumBoxText('2.00'), '2');
      expect(insurancePremiumBoxText(2.5), '2.5');
      expect(insurancePremiumBoxText(1500), '1500');
      expect(insurancePremiumBoxText(1234.56), '1234.56');
      expect(insurancePremiumBoxText(0), '0');
    });

    test('rounded to cents', () {
      expect(insurancePremiumBoxText(15.6666666666), '15.67');
      expect(insurancePremiumBoxText(0.30000000000000004), '0.3');
      expect(insurancePremiumBoxText(999.999), '1000');
    });

    test('nothing saved is empty; text that is not a number is kept', () {
      expect(insurancePremiumBoxText(null), '');
      expect(insurancePremiumBoxText(''), '');
      expect(insurancePremiumBoxText('abc'), 'abc');
    });
  });

  group("Edit Insurance Policy amount boxes, like web's formatCurrencyInput", () {
    test('no ".0", commas between thousands, at most two decimals', () {
      expect(insurancePolicyAmountBoxText(3.0), '3', reason: 'not "3.0"');
      expect(insurancePolicyAmountBoxText(3), '3');
      expect(insurancePolicyAmountBoxText(3.5), '3.5');
      expect(insurancePolicyAmountBoxText(1500.0), '1,500');
      expect(insurancePolicyAmountBoxText(1234.5), '1,234.5');
      expect(insurancePolicyAmountBoxText(1234567.89), '1,234,567.89');
      expect(insurancePolicyAmountBoxText(15.6666), '15.67');
      expect(insurancePolicyAmountBoxText(999.999), '1,000');
      expect(insurancePolicyAmountBoxText(0), '0');
      expect(insurancePolicyAmountBoxText(0.5), '0.5');
    });

    test('no amount is empty', () {
      expect(insurancePolicyAmountBoxText(null), '');
      expect(insurancePolicyAmountBoxText(double.nan), '');
    });
  });

  group('typing in Premium Amount / Deductible', () {
    test('commas appear as you type, like web', () {
      var value = const TextEditingValue();
      final shown = <String>[];
      for (final ch in '1234567.89'.split('')) {
        value = _typeAtEnd(value, ch);
        shown.add(value.text);
      }
      expect(shown, [
        '1',
        '12',
        '123',
        '1,234',
        '12,345',
        '123,456',
        '1,234,567',
        '1,234,567.',
        '1,234,567.8',
        '1,234,567.89',
      ]);
      expect(value.selection.extentOffset, value.text.length,
          reason: 'cursor stays at the end');
    });

    test('a third decimal, a second "." and letters are refused', () {
      final value = _typeAtEnd(const TextEditingValue(), '12.34');
      expect(_typeAtEnd(value, '5').text, '12.34');
      expect(_typeAtEnd(value, '.').text, '12.34');
      expect(_typeAtEnd(_at('12'), 'a').text, '12');
      expect(_typeAtEnd(_at('12'), '-').text, '12');
    });

    test('no leading zeros, like web; "." gets a 0 in front', () {
      expect(_typeAtEnd(const TextEditingValue(), '05').text, '5');
      expect(_typeAtEnd(const TextEditingValue(), '00').text, '0');
      expect(_typeAtEnd(const TextEditingValue(), '0.5').text, '0.5');
      expect(_typeAtEnd(const TextEditingValue(), '.').text, '0.');
      expect(_typeAtEnd(const TextEditingValue(), '.5').text, '0.5');
    });

    test('editing in the middle keeps the cursor after the same digit', () {
      // "1|,234" + "9" → "19|,234"
      final inserted =
          _formatter.formatEditUpdate(_at('1,234', 1), _at('19,234', 2));
      expect(inserted.text, '19,234');
      expect(inserted.selection.extentOffset, 2);

      // Deleting the "2" of "1,2|34" → "13|4"
      final deleted =
          _formatter.formatEditUpdate(_at('1,234', 3), _at('1,34', 2));
      expect(deleted.text, '134');
      expect(deleted.selection.extentOffset, 1);
    });

    test('pasting with commas works; clearing empties the box', () {
      expect(_formatter.formatEditUpdate(_at(''), _at('1,234,567.8')).text,
          '1,234,567.8');
      expect(_formatter.formatEditUpdate(_at('1,500'), _at('')).text, '');
    });

    test("Insurance Premium stops at web's maximum, 999,999,999.99", () {
      const premium =
          InsuranceAmountInputFormatter(max: insurancePremiumMaxAmount);
      TextEditingValue type(TextEditingValue start, String chars) {
        var value = start;
        for (final ch in chars.split('')) {
          value = premium.formatEditUpdate(value, _at(value.text + ch));
        }
        return value;
      }

      expect(insurancePremiumMaxAmount, 999999999.99);
      final top = type(const TextEditingValue(), '999999999.99');
      expect(top.text, '999,999,999.99', reason: 'the maximum itself is fine');
      expect(type(const TextEditingValue(), '9999999999').text,
          '999,999,999', reason: 'the 10th digit is refused, like web');
      expect(
          premium.formatEditUpdate(_at('1,200'), _at('1000000000')).text,
          '1,200',
          reason: 'pasting more than the maximum is refused');
      expect(_typeAtEnd(const TextEditingValue(), '9999999999').text,
          '9,999,999,999',
          reason: 'the policy boxes have no maximum, as on web');
    });
  });

  group('on the real screens', () {
    late List<http.Request> sent;

    setUp(() {
      sent = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
              const MethodChannel('PonnamKarthik/fluttertoast'),
              (_) async => true);
      ConnectivityPlatform.instance = _Online();
    });

    http.Client server() => MockClient((request) async {
          if (request.method != 'GET') sent.add(request);
          return http.Response(
              jsonEncode({
                'success': true,
                'statusCode': 200,
                'message': 'Updated',
                'data': {'insurance_premiums': []}
              }),
              200,
              headers: {'content-type': 'application/json'});
        });

    Future<void> settle(WidgetTester tester, [int ticks = 20]) async {
      for (var i = 0; i < ticks; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    Future<void> pump(WidgetTester tester, Widget screen) async {
      SharedPreferences.setMockInitialValues({
        'token': 'tkn',
        'adminId': 'ADMIN-1',
        'staff_id': 'STAFF-1',
        'role': 'Admin'
      });
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
      await settle(tester);
    }

    Finder box(String hint) => find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.hintText == hint);

    String shown(WidgetTester tester, String hint) =>
        tester.widget<TextField>(box(hint)).controller!.text;

    bool enabled(WidgetTester tester, String label) =>
        tester.widget<ElevatedButton>(
                find.widgetWithText(ElevatedButton, label)).onPressed !=
            null;

    for (final role in ['Admin', 'Staff']) {
      testWidgets(
          '$role Edit Insurance Policy: amounts show like web; Update sends '
          'plain numbers', (tester) async {
        await http.runWithClient(() async {
          final policy = PropertyInsuranceData(
            id: 'POL1',
            insuranceCompanyName: 'lens',
            policyNumber: '23',
            policyType: 'Landlord or Dwelling Policies (DP Policies)',
            formNumber: 'DP-2 (Broad Form)',
            namedInsured: 'for lens',
            mailingAddress: '813 Howard Street',
            effectiveDate: '2026-01-16',
            expirationDate: '2026-01-17',
            premiumAmount: 3.0,
            deductible: 1500.0,
            paymentTerms: 'Annual',
            status: 'Active',
            notes: 'emiliyyy',
          );
          await pump(
              tester,
              role == 'Admin'
                  ? admin_policy.AddEditInsurancePolicy(
                      propertyId: 'P1', policyId: 'POL1', policyData: policy)
                  : staff_policy.AddEditInsurancePolicy(
                      propertyId: 'P1', policyId: 'POL1', policyData: policy));

          expect(shown(tester, 'Enter premium amount'), '3',
              reason: 'web shows 3, not 3.0');
          expect(shown(tester, 'Enter deductible amount'), '1,500',
              reason: 'web shows 1,500, not 1500.0');
          expect(enabled(tester, 'Update'), isFalse);

          // The same amount typed again is no change.
          await tester.enterText(box('Enter deductible amount'), '1500');
          await tester.pump();
          expect(shown(tester, 'Enter deductible amount'), '1,500');
          expect(enabled(tester, 'Update'), isFalse);

          await tester.enterText(box('Enter premium amount'), '1234.5');
          await tester.pump();
          expect(shown(tester, 'Enter premium amount'), '1,234.5');
          expect(enabled(tester, 'Update'), isTrue);

          final update = find.widgetWithText(ElevatedButton, 'Update');
          await tester.ensureVisible(update);
          await tester.tap(update);
          await settle(tester, 30);

          final put = sent.where((r) => r.method == 'PUT').toList();
          expect(put, hasLength(1), reason: 'Update was sent');
          expect(put.single.url.path, '/api/property-insurance/POL1');
          final body = jsonDecode(put.single.body) as Map<String, dynamic>;
          expect(body['premium_amount'], 1234.5, reason: 'no comma sent');
          expect(body['deductible'], 1500);

          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(seconds: 1));
        }, server);
      });

      testWidgets('$role Add Insurance Policy: typing shows commas like web',
          (tester) async {
        await http.runWithClient(() async {
          await pump(
              tester,
              role == 'Admin'
                  ? const admin_policy.AddEditInsurancePolicy(propertyId: 'P1')
                  : const staff_policy.AddEditInsurancePolicy(
                      propertyId: 'P1'));
          await tester.enterText(box('Enter premium amount'), '1500');
          await tester.enterText(box('Enter deductible amount'), '250.5');
          await tester.pump();
          expect(shown(tester, 'Enter premium amount'), '1,500');
          expect(shown(tester, 'Enter deductible amount'), '250.5');
          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(seconds: 1));
        }, server);
      });

      testWidgets('$role Edit Insurance Premium: the premium shows like web',
          (tester) async {
        await http.runWithClient(() async {
          Widget screen(Map<String, dynamic> data) => role == 'Admin'
              ? admin_premium.AddEditInsurancePremium(
                  propertyId: 'P1', premiumId: 'IP1', premiumData: data)
              : staff_premium.AddEditInsurancePremium(
                  propertyId: 'P1', premiumId: 'IP1', premiumData: data);

          await pump(
              tester,
              screen({
                'year': '2025',
                'carrier': 'insurancee',
                'insurance_premium': 2,
                'formatted_premium': r'$2.00',
              }));
          expect(shown(tester, 'e.g., 1200.00'), '2',
              reason: 'web shows 2, not 2.00');
          expect(enabled(tester, 'Update'), isFalse);

          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(seconds: 1));

          // An old premium with extra decimals opens rounded to cents, and
          // Update is on so it can be corrected, as on web.
          await pump(
              tester,
              screen({
                'year': '2025',
                'carrier': 'insurancee',
                'insurance_premium': 15.6666666666,
                'formatted_premium': r'$15.67',
              }));
          expect(shown(tester, 'e.g., 1200.00'), '15.67');
          expect(enabled(tester, 'Update'), isTrue);

          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(seconds: 1));
        }, server);
      });

      testWidgets(
          '$role Edit Insurance Premium: commas while typing like web; Update '
          'sends a plain number', (tester) async {
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
          final premium = box('e.g., 1200.00');
          expect(shown(tester, 'e.g., 1200.00'), '1200',
              reason: 'opens without commas, as on web');
          expect(enabled(tester, 'Update'), isFalse);

          await tester.enterText(premium, '12000');
          await tester.pump();
          expect(shown(tester, 'e.g., 1200.00'), '12,000');
          expect(enabled(tester, 'Update'), isTrue);

          // Back to the same amount, now shown with a comma: no change.
          await tester.enterText(premium, '1200');
          await tester.pump();
          expect(shown(tester, 'e.g., 1200.00'), '1,200');
          expect(enabled(tester, 'Update'), isFalse);

          // More than web's maximum is refused.
          await tester.enterText(premium, '1000000000');
          await tester.pump();
          expect(shown(tester, 'e.g., 1200.00'), '1,200');

          await tester.enterText(premium, '1500.5');
          await tester.pump();
          expect(shown(tester, 'e.g., 1200.00'), '1,500.5');
          expect(enabled(tester, 'Update'), isTrue);

          await tester.tap(find.widgetWithText(ElevatedButton, 'Update'));
          await settle(tester, 30);
          final put = sent.where((r) => r.method == 'PUT').toList();
          expect(put, hasLength(1), reason: 'Update was sent');
          expect(put.single.url.path,
              '/api/rentals/insurance-premiums/P1/IP1');
          final body = jsonDecode(put.single.body) as Map<String, dynamic>;
          expect(body['insurance_premium'], 1500.5, reason: 'no comma sent');

          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(seconds: 1));
        }, server);
      });

      testWidgets('$role Add Insurance Premium: commas while typing like web',
          (tester) async {
        await http.runWithClient(() async {
          await pump(
              tester,
              role == 'Admin'
                  ? const admin_premium.AddEditInsurancePremium(propertyId: 'P1')
                  : const staff_premium.AddEditInsurancePremium(
                      propertyId: 'P1'));
          await tester.enterText(box('e.g., 1200.00'), '2500');
          await tester.pump();
          expect(shown(tester, 'e.g., 1200.00'), '2,500');
          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(seconds: 1));
        }, server);
      });
    }
  });

  test('all 4 forms use the web display', () {
    for (final path in [
      'lib/screens/Rental/Properties/Insurance Premium/AddEditInsurancePolicy.dart',
      'lib/StaffModule/screen/Rental/Properties/Insurance Premium/AddEditInsurancePolicy.dart',
    ]) {
      final src = File(path).readAsStringSync();
      expect(src, contains('insurancePolicyAmountBoxText(policy.premiumAmount)'),
          reason: path);
      expect(src, contains('insurancePolicyAmountBoxText(policy.deductible)'),
          reason: path);
      expect('InsuranceAmountInputFormatter()'.allMatches(src).length, 2,
          reason: '$path: Premium Amount and Deductible');
    }
    for (final path in [
      'lib/screens/Rental/Properties/Insurance Premium/AddEditInsurancePremium.dart',
      'lib/StaffModule/screen/Rental/Properties/Insurance Premium/AddEditInsurancePremium.dart',
    ]) {
      final src = File(path).readAsStringSync();
      expect(src, contains('insurancePremiumBoxText(premium)'), reason: path);
      expect(src, contains('max: insurancePremiumMaxAmount'), reason: path);
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

import 'dart:convert';

import 'package:connectivity_plus_platform_interface/connectivity_plus_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:three_zero_two_property/StaffModule/repository/staffpermission_provider.dart';
import 'package:three_zero_two_property/StaffModule/screen/Leasing/RentalRoll/Renters%20Insurance/Edit_Renters_insurance.dart'
    as staff;
import 'package:three_zero_two_property/provider/Plan%20Purchase/plancheckProvider.dart';
import 'package:three_zero_two_property/provider/dateProvider.dart';
import 'package:three_zero_two_property/provider/notification_provider.dart';
import 'package:three_zero_two_property/screens/Leasing/RentalRoll/Renters%20Insurance/Edit_Renters_insurance.dart'
    as admin;
import 'package:three_zero_two_property/services/renters_insurance_changes.dart';

/// Lease → Renters Insurance → Edit, like web staging
/// (UpdateInsuranceDialog.jsx): saving with nothing changed shows "No changes
/// detected. Please make at least one change before updating." above the
/// buttons, sends nothing and keeps the form open; the message goes away once
/// something changes, and any real change still saves as before. Before, the
/// app always sent the update and closed the form.

const _policy = {
  '_id': 'X-1',
  'renters_insurance_id': 'RI-1',
  'lease_id': 'L-1',
  'tenants': ['T-1'],
  'insurance_company': 'ABC Insurance',
  'insurance_company_phone_number': '5555555555',
  'policy_id': 'POL-1',
  'effective_date': '2026-01-01T00:00:00.000Z',
  'expiration_date': '2027-01-01T00:00:00.000Z',
  'liability_coverage': 10000,
  'insurance_policy_document': 'policy.pdf',
};

final _saves = <http.Request>[];
final _toasts = <String>[];

http.Response _json(Object body) => http.Response(jsonEncode(body), 200,
    headers: {'content-type': 'application/json'});

final _server = MockClient((request) async {
  final path = request.url.path;
  if (path == '/api/renter-insurance/policy/RI-1') {
    return _json({'statusCode': 200, 'data': _policy});
  }
  if (path == '/api/leases/lease_tenant/L-1') {
    return _json({
      'statusCode': 200,
      'data': {
        'rental_adress': '12 Main St',
        'rental_city': 'Austin',
        'rental_state': 'TX',
        'rental_country': 'USA',
        'rental_zip': '73301',
        'tenants': [
          {
            'tenant_id': 'T-1',
            'tenant_firstName': 'Pat',
            'tenant_lastName': 'Lee',
            'tenant_email': 'pat@example.com',
            'tenant_phoneNumber': '5551112222',
          },
          {
            'tenant_id': 'T-2',
            'tenant_firstName': 'Sam',
            'tenant_lastName': 'Fox',
            'tenant_email': 'sam@example.com',
            'tenant_phoneNumber': '5553334444',
          },
        ],
      },
    });
  }
  if (request.method == 'PUT' &&
      path == '/api/renter-insurance/edit-policy/RI-1') {
    _saves.add(request);
    return _json({
      'statusCode': 200,
      'message': 'Insurance policy updated successfully',
    });
  }
  if (path == '/api/auth') {
    return _json({
      'statusCode': 200,
      'themes': {'format': 'YYYY-MM-DD', 'timeFormat': '24'},
    });
  }
  return _json({'statusCode': 200, 'data': []});
});

Future<void> _settle(WidgetTester tester, [int ticks = 30]) async {
  for (var i = 0; i < ticks; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _tap(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pump();
  await tester.tap(target, warnIfMissed: false);
  await _settle(tester, 10);
}

Finder _box(String hint) => find.byWidgetPredicate(
    (w) => w is TextField && w.decoration?.hintText == hint);

// Admin's button says Update Insurance; Staff's says Save.
Finder _saveButton(bool isStaff) => find.widgetWithText(
    ElevatedButton, isStaff ? 'Save' : 'Update Insurance');

final _message = find.text(rentersInsuranceNoChangesMessage);

/// Opens the real Edit Renters Insurance screen on a saved policy.
Future<void> _open(WidgetTester tester, bool isStaff) async {
  SharedPreferences.setMockInitialValues(isStaff
      ? {
          'token': 'tkn',
          'adminId': 'ADMIN-1',
          'staff_id': 'STAFF-1',
          'role': 'Staffmember',
        }
      : {'token': 'tkn', 'adminId': 'ADMIN-1', 'role': 'Admin'});
  tester.view.physicalSize = const Size(430, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final dates = DateProvider();
  await dates.loadDateFormat();
  final navigator = GlobalKey<NavigatorState>();
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider<DateProvider>.value(value: dates),
      ChangeNotifierProvider(create: (_) => NotificationProvider()),
      ChangeNotifierProvider(create: (_) => checkPlanPurchaseProiver()),
      ChangeNotifierProvider(create: (_) => StaffPermissionProvider()),
    ],
    child: MaterialApp(navigatorKey: navigator, home: const SizedBox()),
  ));
  navigator.currentState!.push(MaterialPageRoute(
      builder: (_) => isStaff
          ? const staff.EditRentersInsurance(
              tenantid: 'T-1', leaseId: 'L-1', renters_insurance_id: 'RI-1')
          : const admin.EditRentersInsurance(
              tenantid: 'T-1', leaseId: 'L-1', renters_insurance_id: 'RI-1')));
  // The saved policy fills the form after a one-second pause.
  await _settle(tester, 50);
  expect(
      tester
          .widget<TextField>(_box('Enter insurance company'))
          .controller!
          .text,
      'ABC Insurance');
}

Future<void> _run(WidgetTester tester, Future<void> Function() body) async {
  final original = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.exceptionAsString().contains('overflowed')) return;
    if (details.library == 'image resource service') return;
    original?.call(details);
  };
  try {
    await http.runWithClient(() async {
      await body();
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
    }, () => _server);
  } finally {
    FlutterError.onError = original;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group("web's rule", () {
    String snap({
      String provider = 'ABC Insurance',
      String phone = '5555555555',
      String policyId = 'POL-1',
      String coverage = '10000',
      String effective = '2026-01-01',
      String expiration = '2027-01-01',
      List<String> tenants = const ['T-1', 'T-2'],
      String document = 'policy.pdf',
    }) =>
        rentersInsuranceFormSnapshot(
          provider: provider,
          phone: phone,
          policyId: policyId,
          coverage: coverage,
          effectiveDate: effective,
          expirationDate: expiration,
          tenants: tenants,
          document: document,
        );

    test("web's message", () {
      expect(rentersInsuranceNoChangesMessage,
          'No changes detected. Please make at least one change before updating.');
    });

    test('the same values written differently are unchanged', () {
      final opened = snap();
      expect(snap(provider: ' ABC Insurance '), opened);
      expect(snap(phone: '(555) 555-5555'), opened,
          reason: 'web compares the phone digits only');
      expect(snap(coverage: '10000.00'), opened, reason: 'the same amount');
      expect(snap(tenants: ['T-2', 'T-1']), opened,
          reason: 'the order of tenants does not matter');
    });

    test('any real change counts', () {
      final opened = snap();
      for (final changed in [
        snap(provider: 'XYZ Insurance'),
        snap(phone: '5555555556'),
        snap(policyId: 'POL-2'),
        snap(coverage: '20000'),
        snap(effective: '2026-02-01'),
        snap(expiration: '2027-02-01'),
        snap(tenants: ['T-1']),
        snap(document: 'new-policy.pdf'),
        snap(document: ''),
      ]) {
        expect(changed, isNot(opened));
      }
    });
  });

  group('on the Edit Renters Insurance screen', () {
    setUp(() {
      _saves.clear();
      _toasts.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
              const MethodChannel('PonnamKarthik/fluttertoast'), (call) async {
        final args = call.arguments;
        if (args is Map && args['msg'] != null) _toasts.add('${args['msg']}');
        return true;
      });
      ConnectivityPlatform.instance = _Online();
    });

    for (final isStaff in [false, true]) {
      final role = isStaff ? 'Staff' : 'Admin';

      testWidgets('$role: an unchanged save is refused like web; a real '
          'change still saves', (tester) async {
        await _run(tester, () async {
          await _open(tester, isStaff);

          // Nothing changed: web's message, nothing sent, the form stays open.
          expect(_message, findsNothing);
          await _tap(tester, _saveButton(isStaff));
          expect(_message, findsOneWidget);
          expect(_saves, isEmpty);
          expect(_saveButton(isStaff), findsOneWidget);

          // Ticking another tenant is a change: the message goes away, and
          // like web it stays away when the tick is undone.
          expect(find.byType(Checkbox), findsNWidgets(2));
          await _tap(tester, find.byType(Checkbox).at(1));
          expect(_message, findsNothing);
          await _tap(tester, find.byType(Checkbox).at(1));
          expect(_message, findsNothing);

          // Back to how it opened: refused again.
          await _tap(tester, _saveButton(isStaff));
          expect(_message, findsOneWidget);
          expect(_saves, isEmpty);

          // A new provider hides the message, and the change saves as before.
          await tester.enterText(_box('Enter insurance company'), 'XYZ Insurance');
          await _settle(tester, 5);
          expect(_message, findsNothing);
          await _tap(tester, _saveButton(isStaff));
          expect(_saves, hasLength(1));
          final sent = jsonDecode(_saves.single.body) as Map<String, dynamic>;
          expect(sent['insurance_company'], 'XYZ Insurance');
          expect(sent['tenants'], ['T-1']);
          expect(sent['insurance_policy_document'], 'policy.pdf');
          expect(_toasts, contains('Insurance policy updated successfully'));
          await _settle(tester, 20); // the closing animation
          expect(_saveButton(isStaff), findsNothing,
              reason: 'the form closes after a save, as before');
        });
      });

      testWidgets('$role: removing the document is a change and saves',
          (tester) async {
        await _run(tester, () async {
          await _open(tester, isStaff);
          final remove = find.descendant(
              of: find
                  .ancestor(of: find.text('policy.pdf'), matching: find.byType(Row))
                  .first,
              matching: find.byIcon(Icons.close));
          await _tap(tester, remove);
          await _tap(tester, _saveButton(isStaff));
          expect(_message, findsNothing);
          expect(_saves, hasLength(1));
          final sent = jsonDecode(_saves.single.body) as Map<String, dynamic>;
          expect(sent['insurance_policy_document'], '');
        });
      });

      testWidgets('$role: the tenant check works as before', (tester) async {
        await _run(tester, () async {
          await _open(tester, isStaff);
          // Untick Pat Lee, the only covered tenant.
          await _tap(tester, find.byType(Checkbox).first);
          await _tap(tester, _saveButton(isStaff));
          expect(_toasts, contains('Please select at least one tenant'));
          expect(_message, findsNothing);
          expect(_saves, isEmpty);
        });
      });
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

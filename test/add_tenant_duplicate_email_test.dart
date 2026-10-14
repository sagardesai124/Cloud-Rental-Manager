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
import 'package:three_zero_two_property/Model/tenants.dart';
import 'package:three_zero_two_property/provider/dateProvider.dart';
import 'package:three_zero_two_property/provider/lease_provider.dart';
import 'package:three_zero_two_property/provider/notification_provider.dart';
import 'package:three_zero_two_property/screens/Leasing/RentalRoll/add_tenant_cosigner_screen.dart';

/// The REAL Add Tenant screen that Add Lease and Edit Lease open (Admin and
/// Staff, phone and tablet): a typed-in tenant whose email is already on the
/// lease shows the message and the form stays open; a new email is added and
/// the screen closes. Before: the duplicate was silently dropped, the screen
/// closed and the typed details were lost.

// Web's tenantEmailDuplicates.js onLeaseConflictMessage.
const _duplicateMessage =
    'ruth@example.com is already used by Pat on this lease. '
    'Tenant email is how renewal notices, late-fee letters, and e-sign '
    'requests are routed, so two tenants on a lease cannot share one address.';

final List<String> _toasts = [];

final _server = MockClient((request) async => http.Response(
    jsonEncode(request.url.path == '/api/auth'
        ? {
            'statusCode': 200,
            'themes': {'format': 'MM/DD/YYYY', 'timeFormat': '12'}
          }
        : {'statusCode': 200, 'data': []}),
    200,
    headers: {'content-type': 'application/json'}));

Finder _field(String hint) => find
    .byWidgetPredicate((w) => w is TextField && w.decoration?.hintText == hint)
    .first;

Future<void> _settle(WidgetTester tester, [int ticks = 16]) async {
  for (var i = 0; i < ticks; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _type(WidgetTester tester, String hint, String text) async {
  await tester.ensureVisible(_field(hint));
  await tester.enterText(_field(hint), text);
  await tester.pump();
}

/// Opens the screen from a launcher (as Add Lease pushes it) with [onLease]
/// already on the lease, fills a new tenant with [email] and taps Add Tenant.
Future<({SelectedTenantsProvider lease, List<Object?> pops})> _addTenant(
    WidgetTester tester, List<Tenant> onLease, String email) async {
  tester.view.physicalSize = const Size(430, 3200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final dates = DateProvider();
  await dates.loadDateFormat();
  final lease = SelectedTenantsProvider();
  for (final t in onLease) {
    lease.addTenant(t);
  }
  final pops = <Object?>[];
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider<DateProvider>.value(value: dates),
      ChangeNotifierProvider(create: (_) => NotificationProvider()),
      ChangeNotifierProvider<SelectedTenantsProvider>.value(value: lease),
    ],
    child: MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () async => pops.add(await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const AddTenantCosignerScreen()))),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await _settle(tester, 20);

  await _type(tester, 'Enter first name', 'Ruth');
  await _type(tester, 'Enter last name', 'Moss');
  await _type(tester, 'Enter phone number', '5551234567');
  await _type(tester, 'Enter email', email);
  await tester.ensureVisible(_field('YYYY-MM-DD'));
  await tester.tap(_field('YYYY-MM-DD'));
  await _settle(tester);
  await tester.tap(find.text('OK'));
  await _settle(tester);

  final add = find.text('Add Tenant').last;
  await tester.ensureVisible(add);
  await tester.pump();
  await tester.tap(add);
  await _settle(tester, 20);
  return (lease: lease, pops: pops);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    _toasts.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('PonnamKarthik/fluttertoast'), (call) async {
      if (call.method == 'showToast') {
        _toasts.add('${(call.arguments as Map)['msg']}');
      }
      return true;
    });
    ConnectivityPlatform.instance = _OnlineConnectivity();
    SharedPreferences.setMockInitialValues(
        {'token': 'tkn', 'adminId': 'ADMIN-1', 'role': 'Admin'});
  });

  Future<void> run(WidgetTester tester, Future<void> Function() body) async {
    final original = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('overflowed')) return;
      original?.call(details);
    };
    try {
      await http.runWithClient(body, () => _server);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
    } finally {
      FlutterError.onError = original;
    }
  }

  testWidgets('an email already on the lease: message shows, form stays open',
      (tester) async {
    await run(tester, () async {
      final r = await _addTenant(
          tester,
          [Tenant(tenantId: 'T-1', tenantFirstName: 'Pat', tenantEmail: 'ruth@example.com')],
          'RUTH@example.com');
      expect(_toasts, contains(_duplicateMessage));
      expect(r.pops, isEmpty, reason: 'Add Tenant screen is still open');
      expect(find.text('Add Tenant'), findsWidgets);
      expect(r.lease.selectedTenants.map((t) => t.tenantId), ['T-1']);
    });
  });

  testWidgets('a new email is added next to the existing tenant and closes',
      (tester) async {
    await run(tester, () async {
      final r = await _addTenant(
          tester,
          [Tenant(tenantId: 'T-1', tenantFirstName: 'Pat', tenantEmail: 'pat@example.com')],
          'ruth@example.com');
      expect(_toasts, isNot(contains(_duplicateMessage)));
      expect(r.pops, [true], reason: 'screen closed once after adding');
      expect(r.lease.selectedTenants.map((t) => t.tenantFirstName),
          ['Pat', 'Ruth']);
    });
  });
}

class _OnlineConnectivity extends ConnectivityPlatform
    with MockPlatformInterfaceMixin {
  @override
  Future<ConnectivityResult> checkConnectivity() async =>
      ConnectivityResult.wifi;
  @override
  Stream<ConnectivityResult> get onConnectivityChanged => const Stream.empty();
}

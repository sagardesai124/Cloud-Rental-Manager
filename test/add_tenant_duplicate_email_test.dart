import 'dart:convert';

import 'dart:async';

import 'package:connectivity_plus_platform_interface/connectivity_plus_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
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

/// The account's tenants and applicants returned by the tenant list
/// (GET /api/tenant/tenants/:admin_id) that the screen checks against.
Map<String, dynamic> _accountRecords = {'tenants': [], 'applicants': []};
bool _accountListFails = false;

/// When set, the account list waits for it before answering.
Completer<void>? _accountListGate;

final _server = MockClient((request) async {
  final path = request.url.path;
  if (path == '/api/auth') {
    return _json({
      'statusCode': 200,
      'themes': {'format': 'MM/DD/YYYY', 'timeFormat': '12'}
    });
  }
  if (path == '/api/tenant/tenants/ADMIN-1') {
    if (_accountListGate != null) await _accountListGate!.future;
    if (_accountListFails) return http.Response('error', 500);
    return _json({'statusCode': 200, 'data': _accountRecords});
  }
  return _json({'statusCode': 200, 'data': []});
});

http.Response _json(Object body) => http.Response(jsonEncode(body), 200,
    headers: {'content-type': 'application/json'});

// Web's tenantEmailDuplicates.js existingRecordConflictMessage.
String _inUseMessage(String name) =>
    'This email address is already in use by $name. '
    'Use "Choose an existing Tenant" to add that record, or enter a '
    'different email address.';

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
    WidgetTester tester, List<Tenant> onLease, String email,
    {bool settleAfterTap = true}) async {
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
  if (settleAfterTap) await _settle(tester, 20);
  return (lease: lease, pops: pops);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    _toasts.clear();
    _accountRecords = {'tenants': [], 'applicants': []};
    _accountListFails = false;
    _accountListGate = null;
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
      // Lets the 4-second message timer finish.
      await tester.pump(const Duration(seconds: 5));
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

  testWidgets(
      'an email used by another tenant in the account: web message, not added',
      (tester) async {
    _accountRecords = {
      'tenants': [
        {
          'tenant_id': 'T-9',
          'tenant_firstName': 'Ruth',
          'tenant_lastName': 'Parker',
          'tenant_email': 'ruth@example.com',
        }
      ],
      'applicants': [],
    };
    await run(tester, () async {
      final r = await _addTenant(tester, [], ' RUTH@Example.com ');
      expect(_toasts, contains(_inUseMessage('Ruth Parker')));
      expect(r.pops, isEmpty, reason: 'Add Tenant screen is still open');
      expect(r.lease.selectedTenants, isEmpty);
    });
  });

  testWidgets('an email used by an applicant in the account: same message',
      (tester) async {
    _accountRecords = {
      'tenants': [],
      'applicants': [
        {
          'applicant_id': 'A-1',
          'applicant_firstName': 'Sam',
          'applicant_lastName': 'Lee',
          'applicant_email': 'ruth@example.com',
        }
      ],
    };
    await run(tester, () async {
      final r = await _addTenant(tester, [], 'ruth@example.com');
      expect(_toasts, contains(_inUseMessage('Sam Lee')));
      expect(r.pops, isEmpty);
      expect(r.lease.selectedTenants, isEmpty);
    });
  });

  testWidgets('while the account is checked, Add Tenant shows a spinner',
      (tester) async {
    _accountRecords = {
      'tenants': [
        {
          'tenant_id': 'T-9',
          'tenant_firstName': 'Ruth',
          'tenant_lastName': null,
          'tenant_email': 'ruth@example.com',
        }
      ],
      'applicants': [],
    };
    _accountListGate = Completer<void>();
    await run(tester, () async {
      final r = await _addTenant(tester, [], 'ruth@example.com',
          settleAfterTap: false);
      await tester.pump();
      expect(find.byType(SpinKitFadingCircle), findsWidgets,
          reason: 'spinner while the account list loads');
      _accountListGate!.complete();
      await _settle(tester, 20);
      // A missing last name is left out of the message, not shown as "null".
      expect(_toasts, contains(_inUseMessage('Ruth')));
      expect(r.lease.selectedTenants, isEmpty);
      expect(find.text('Add Tenant'), findsWidgets, reason: 'button back');
    });
  });

  testWidgets('the account list cannot load: the tenant is added, as on web',
      (tester) async {
    _accountListFails = true;
    await run(tester, () async {
      final r = await _addTenant(tester, [], 'ruth@example.com');
      expect(r.pops, [true]);
      expect(r.lease.selectedTenants.map((t) => t.tenantFirstName), ['Ruth']);
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

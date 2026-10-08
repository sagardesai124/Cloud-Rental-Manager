import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus_platform_interface/connectivity_plus_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:three_zero_two_property/StaffModule/model/staffpermission.dart';
import 'package:three_zero_two_property/StaffModule/repository/staffpermission_provider.dart';
import 'package:three_zero_two_property/StaffModule/screen/Leasing/RentalRoll/lease_table.dart'
    as staff;
import 'package:three_zero_two_property/provider/dateProvider.dart';
import 'package:three_zero_two_property/provider/lease_provider.dart';
import 'package:three_zero_two_property/provider/notification_provider.dart';
import 'package:three_zero_two_property/screens/Leasing/RentalRoll/lease_table.dart'
    as admin;

/// The real Admin and Staff lease lists, driven against a fake server, must
/// delete a lease the way web does (RentRoll.jsx deleteTenant, 2.2 rules):
///   - not started  → "Are you sure?" + Delete, request `{reason}`;
///   - started, Admin → "This lease has already started" + "Override and
///     delete", request `{reason, override: true}`;
///   - started, Staff → no dialog, the web warning, nothing sent.
/// Before this change, a started-but-ended lease was deleted WITHOUT the
/// override (the server now refuses that) and an in-progress lease was
/// blocked outright for everyone.

const _adminId = 'ADMIN-1';

Map<String, dynamic> _lease(String id, String start, String end) => {
      'lease_id': id,
      'admin_id': _adminId,
      'tenant_id': ['T-1'],
      'rental_id': 'R-1',
      'unit_id': 'U-1',
      'lease_type': 'Fixed',
      'start_date': start,
      'end_date': end,
      'amount': 100,
      'rent_cycle': 'Monthly',
      'rent_duedate': start,
      'deposite': 0,
      'recurringCharge': 100,
      'tenantNames': 'Pat Tenant',
      'rental_adress': '1 Test Street',
      'rental_unit': '1',
      'createdAt': '2025-01-01 00:00:00',
      'updatedAt': '2025-01-01 00:00:00',
      'remainingDays': 0,
      'totalBalance': 0,
      'rentalOwner_name': 'Owner',
    };

/// One lease per rule: future (not started), ended (started), running
/// (started).
final _leases = [
  _lease('L-FUTURE', '2032-06-02', '2033-06-02'),
  _lease('L-ENDED', '2025-02-05', '2025-09-24'),
  _lease('L-RUNNING', '2026-02-01', '2027-02-28'),
];

/// Every permission flag the model knows, set to [value] — built from the
/// model's own toJson so the test can't drift from its key names.
Map<String, dynamic> _allPermissions(bool value) {
  final keys = StaffPermission().toJson().keys;
  return {for (final k in keys) k: value};
}

class _Server {
  final List<http.Request> requests = [];
  late final MockClient client = MockClient((request) async {
    requests.add(request);
    final path = request.url.path;
    Object body = {'statusCode': 200, 'data': []};
    if (request.method == 'DELETE' && path.startsWith('/api/leases/leases/')) {
      body = {'statusCode': 200, 'message': 'Lease deleted'};
    } else if (path.startsWith('/api/leases/leases/')) {
      body = {
        'statusCode': 200,
        'data': _leases,
        'pagination': {'totalPages': 1, 'totalItems': _leases.length, 'page': 1}
      };
    } else if (path.contains('/api/permission/permission/')) {
      body = {
        'statusCode': 200,
        'data': {'staff_permission': _allPermissions(true)}
      };
    } else if (path.contains('/api/leases/limitation/')) {
      body = {'statusCode': 200, 'leaseCount': 3, 'leaseCountLimit': 100};
    } else if (path.contains('/api/admin/admin_profile/')) {
      body = {'statusCode': 200, 'data': {'company_name': 'Acme'}};
    }
    return http.Response(jsonEncode(body), 200,
        headers: {'content-type': 'application/json'});
  });

  Iterable<http.Request> get deletes => requests.where((r) => r.method == 'DELETE');
}

Future<void> _settle(WidgetTester tester, [int ticks = 16]) async {
  for (var i = 0; i < ticks; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Pumps the real list (tall viewport so every row is visible) with the
/// providers main.dart supplies, and waits for the fake server replies.
Future<void> _pumpList(WidgetTester tester, Widget list) async {
  tester.view.physicalSize = const Size(1080, 5000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  // In the app the drawer has loaded Staff permissions long before this list
  // opens; the list reads them on its first build. Give the provider the same
  // head start here (its constructor fetch runs against the fake server).
  final permissions = StaffPermissionProvider();
  await permissions.fetchPermissions();
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => DateProvider()),
      ChangeNotifierProvider(create: (_) => NotificationProvider()),
      ChangeNotifierProvider<StaffPermissionProvider>.value(
          value: permissions),
      ChangeNotifierProvider(create: (_) => SelectedTenantsProvider()),
      ChangeNotifierProvider(create: (_) => SelectedCosignersProvider()),
      ChangeNotifierProvider(create: (_) => SelectedApplicantProvider()),
    ],
    child: MaterialApp(home: list),
  ));
  await _settle(tester, 30);
}

/// Expands the row for [tenantLine] and taps its trash icon.
Future<void> _tapDelete(WidgetTester tester, String leaseStart) async {
  // Rows show the rental address; expand the one whose data we want by
  // tapping its row header (address text is the same for all, so use the
  // start-date-bearing "Lease End" cell instead).
  final row = find.text(leaseStart);
  expect(row, findsOneWidget, reason: 'row for lease ending $leaseStart');
  await tester.ensureVisible(row);
  await tester.tap(row);
  await _settle(tester, 6);
  final trash = find.byWidgetPredicate(
      (w) => w is FaIcon && w.icon == FontAwesomeIcons.trashCan);
  expect(trash, findsWidgets, reason: 'expanded row shows the Delete icon');
  await tester.ensureVisible(trash.first);
  await tester.tap(trash.first);
  await _settle(tester, 6);
}

Future<void> _typeReasonAndConfirm(WidgetTester tester, String button) async {
  await tester.enterText(find.widgetWithText(TextField, '').last, 'duplicate');
  await tester.pump();
  final confirm = find.text(button);
  expect(confirm, findsOneWidget, reason: 'dialog button "$button"');
  await tester.tap(confirm);
  await _settle(tester, 10);
}

/// Tears the list down after letting its pending timers (the post-delete
/// reload scheduling, the search debounce) fire, so the test binding does not
/// report them as leaked.
Future<void> _finish(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 2));
  await _settle(tester, 10);
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 2));
}

/// The test font draws every glyph as a full em square, so dense rows
/// overflow here; that layout noise is ignored.
Future<void> _run(_Server server, Future<void> Function() body) async {
  final original = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.exceptionAsString().contains('overflowed')) return;
    original?.call(details);
  };
  try {
    await http.runWithClient(body, () => server.client);
  } finally {
    FlutterError.onError = original;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
        const MethodChannel('PonnamKarthik/fluttertoast'), (_) async => true);
    // connectivity_plus: always online, never emits a change.
    ConnectivityPlatform.instance = _OnlineConnectivity();
  });

  group('Admin list', () {
    setUp(() => SharedPreferences.setMockInitialValues({
          'token': 'tkn',
          'adminId': _adminId,
          'role': 'Admin',
          'companyName': 'Acme'
        }));

    testWidgets('future lease: "Are you sure?" + Delete → {reason}',
        (tester) async {
      final server = _Server();
      await _run(server, () async {
        await _pumpList(tester, admin.Lease_table());
        await _tapDelete(tester, '06/02/2033');
        expect(find.text('Are you sure?'), findsOneWidget);
        expect(find.text('Override and delete'), findsNothing);
        await _typeReasonAndConfirm(tester, 'Delete');
        expect(server.deletes, hasLength(1));
        final d = server.deletes.single;
        expect(d.url.path, '/api/leases/leases/L-FUTURE');
        expect(jsonDecode(d.body), {'reason': 'duplicate'});
        await _finish(tester);
      });
    });

    testWidgets(
        'ended lease (started): override dialog → {reason, override:true}',
        (tester) async {
      final server = _Server();
      await _run(server, () async {
        await _pumpList(tester, admin.Lease_table());
        await _tapDelete(tester, '09/24/2025');
        expect(find.text('This lease has already started'), findsOneWidget);
        await _typeReasonAndConfirm(tester, 'Override and delete');
        expect(server.deletes, hasLength(1));
        final d = server.deletes.single;
        expect(d.url.path, '/api/leases/leases/L-ENDED');
        expect(jsonDecode(d.body), {'reason': 'duplicate', 'override': true});
        await _finish(tester);
      });
    });

    testWidgets('running lease (started): admin may override (was blocked)',
        (tester) async {
      final server = _Server();
      await _run(server, () async {
        await _pumpList(tester, admin.Lease_table());
        await _tapDelete(tester, '02/28/2027');
        expect(find.text('This lease has already started'), findsOneWidget);
        await _typeReasonAndConfirm(tester, 'Override and delete');
        expect(server.deletes.single.url.path, '/api/leases/leases/L-RUNNING');
        expect(jsonDecode(server.deletes.single.body)['override'], true);
        await _finish(tester);
      });
    });
  });

  group('Staff list (with Lease delete permission)', () {
    setUp(() => SharedPreferences.setMockInitialValues({
          'token': 'tkn',
          'adminId': _adminId,
          'role': 'Staffmember',
          'staff_id': 'STAFF-1',
          'companyName': 'Acme',
          // The list reads permissions on its first build, before the fake
          // server has answered; the provider falls back to this cache.
          'staff_permissions_cache_STAFF-1': jsonEncode(_allPermissions(true)),
        }));

    testWidgets('future lease: Delete → {reason} with staff own id',
        (tester) async {
      final server = _Server();
      await _run(server, () async {
        await _pumpList(tester, staff.Lease_table());
        await _tapDelete(tester, '06/02/2033');
        expect(find.text('Are you sure?'), findsOneWidget);
        await _typeReasonAndConfirm(tester, 'Delete');
        expect(server.deletes, hasLength(1));
        expect(jsonDecode(server.deletes.single.body), {'reason': 'duplicate'});
        expect(server.deletes.single.headers['id'], 'CRM STAFF-1');
        await _finish(tester);
      });
    });

    testWidgets('started lease: no dialog, nothing sent (admin only)',
        (tester) async {
      final server = _Server();
      await _run(server, () async {
        await _pumpList(tester, staff.Lease_table());
        await _tapDelete(tester, '09/24/2025');
        expect(find.text('This lease has already started'), findsNothing);
        expect(find.text('Are you sure?'), findsNothing);
        expect(server.deletes, isEmpty);
        await _finish(tester);
      });
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

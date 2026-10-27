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
import 'package:three_zero_two_property/StaffModule/model/staffpermission.dart';
import 'package:three_zero_two_property/StaffModule/repository/staffpermission_provider.dart';
import 'package:three_zero_two_property/StaffModule/screen/Leasing/RentalRoll/lease_table.dart'
    as staff;
import 'package:three_zero_two_property/provider/dateProvider.dart';
import 'package:three_zero_two_property/provider/lease_provider.dart';
import 'package:three_zero_two_property/provider/notification_provider.dart';
import 'package:three_zero_two_property/screens/Leasing/RentalRoll/lease_table.dart'
    as admin;

/// Leases → "Select rental owners" works like web (RentRoll.jsx), QA's steps:
///   - an "All owners" row first, like web's new-look menu: ticked while no
///     owner is picked, and tapping it clears the picks;
///   - the dropdown always lists every rental owner on the account (A–Z,
///     ignoring case), whatever is picked;
///   - picking owners sends their ids to the server (`rentalOwnerIds`), and
///     clearing them sends none, so the server returns every lease;
///   - owners are picked by id, so two owners with the same name stay apart.
/// Before, after picking an owner the list shrank to that owner and stayed
/// that way after the pick was cleared.

const _adminId = 'ADMIN-1';

/// Two owners share the name "Rohith" on purpose; "adam" checks the order.
final _owners = [
  {'rentalowner_id': 'RO-T', 'rentalOwner_name': 'Test'},
  {'rentalowner_id': 'RO-R1', 'rentalOwner_name': 'Rohith'},
  {'rentalowner_id': 'RO-A', 'rentalOwner_name': 'adam'},
  {'rentalowner_id': 'RO-R2', 'rentalOwner_name': 'Rohith'},
];

Map<String, dynamic> _lease(String id, String owner) => {
      'lease_id': id,
      'admin_id': _adminId,
      'tenant_id': ['T-1'],
      'rental_id': 'R-1',
      'unit_id': 'U-1',
      'lease_type': 'Fixed',
      'start_date': '2026-01-01',
      'end_date': '2027-01-01',
      'amount': 100,
      'rent_cycle': 'Monthly',
      'rent_duedate': '2026-01-01',
      'deposite': 0,
      'recurringCharge': 100,
      'tenantNames': 'Pat Tenant',
      'rental_adress': '$id Street',
      'rental_unit': '1',
      'createdAt': '2025-01-01 00:00:00',
      'updatedAt': '2025-01-01 00:00:00',
      'remainingDays': 0,
      'totalBalance': 0,
      'rentalOwner_name': owner,
    };

Map<String, dynamic> _allPermissions(bool value) {
  final keys = StaffPermission().toJson().keys;
  return {for (final k in keys) k: value};
}

class _Server {
  final List<Uri> leaseRequests = [];
  late final MockClient client = MockClient((request) async {
    final path = request.url.path;
    Object body = {'statusCode': 200, 'data': []};
    if (path == '/api/rentals/rental-owners/$_adminId') {
      body = _owners;
    } else if (path.startsWith('/api/leases/leases/')) {
      leaseRequests.add(request.url);
      // Like the server: filter by the owner ids it was given.
      final ids = (request.url.queryParameters['rentalOwnerIds'] ?? '')
          .split(',')
          .where((s) => s.isNotEmpty)
          .toSet();
      final all = [
        _lease('L-1', 'Rohith'),
        _lease('L-2', 'Test'),
      ];
      final ownerOf = {'L-1': 'RO-R1', 'L-2': 'RO-T'};
      final data = ids.isEmpty
          ? all
          : all.where((l) => ids.contains(ownerOf[l['lease_id']])).toList();
      body = {
        'statusCode': 200,
        'data': data,
        'pagination': {'totalPages': 1, 'totalItems': data.length, 'page': 1}
      };
    } else if (path.contains('/api/permission/permission/')) {
      body = {
        'statusCode': 200,
        'data': {'staff_permission': _allPermissions(true)}
      };
    } else if (path.contains('/api/leases/limitation/')) {
      body = {'statusCode': 200, 'leaseCount': 2, 'leaseCountLimit': 100};
    }
    return http.Response(jsonEncode(body), 200,
        headers: {'content-type': 'application/json'});
  });

  String? get lastOwnerIds =>
      leaseRequests.last.queryParameters['rentalOwnerIds'];
}

Future<void> _settle(WidgetTester tester, [int ticks = 16]) async {
  for (var i = 0; i < ticks; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _pumpList(WidgetTester tester, Widget list) async {
  tester.view.physicalSize = const Size(1080, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
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

/// Owner names in the open dropdown menu, top to bottom.
List<String> _menuNames(WidgetTester tester) {
  final names = <String>[];
  for (final cb in tester.widgetList<Checkbox>(find.byType(Checkbox))) {
    final row = find.ancestor(
        of: find.byWidget(cb), matching: find.byType(Row)).first;
    final text = tester
        .widgetList<Text>(find.descendant(of: row, matching: find.byType(Text)))
        .map((t) => t.data ?? '')
        .firstWhere((s) => s.isNotEmpty, orElse: () => '');
    names.add(text);
  }
  return names;
}

Future<void> _openMenu(WidgetTester tester, String buttonText) async {
  final button = find.text(buttonText).first;
  await tester.ensureVisible(button);
  await tester.tap(button);
  await _settle(tester, 10);
}

Future<void> _closeMenu(WidgetTester tester) async {
  await tester.tapAt(const Offset(5, 5));
  await _settle(tester, 10);
}

/// Taps the [index]th checkbox in the open menu.
Future<void> _tick(WidgetTester tester, int index) async {
  await tester.tap(find.byType(Checkbox).at(index));
  await _settle(tester, 12);
}

Future<void> _finish(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 2));
  await _settle(tester, 10);
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 2));
}

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

/// Tick state of each row in the open dropdown menu, top to bottom.
List<bool> _checked(WidgetTester tester) => tester
    .widgetList<Checkbox>(find.byType(Checkbox))
    .map((c) => c.value == true)
    .toList();

/// QA's steps 1–4 on [list], plus web's "All owners" row.
Future<void> _qaSteps(WidgetTester tester, _Server server, Widget list) async {
  const everyOwner = ['All owners', 'adam', 'Rohith', 'Rohith', 'Test'];
  await _pumpList(tester, list);
  expect(server.lastOwnerIds, isNull, reason: 'nothing picked: every lease');
  expect(find.textContaining('L-1 Street'), findsWidgets);
  expect(find.textContaining('L-2 Street'), findsWidgets);

  // 1. "All owners" first and ticked, then every owner, A–Z ignoring case;
  //    same-name owners listed separately.
  await _openMenu(tester, 'Select rental owners');
  expect(_menuNames(tester), everyOwner);
  expect(_checked(tester), [true, false, false, false, false]);

  // 2. Pick the first Rohith: only their id goes to the server, and
  //    "All owners" is no longer ticked.
  await _tick(tester, 2);
  expect(server.lastOwnerIds, 'RO-R1');
  expect(_checked(tester), [false, false, true, false, false]);
  await _closeMenu(tester);
  expect(find.textContaining('L-1 Street'), findsWidgets,
      reason: "Rohith's lease is listed");
  expect(find.textContaining('L-2 Street'), findsNothing,
      reason: "Test's lease is filtered out");

  // 3. Reopen: every owner is still listed (was only "Rohith").
  await _openMenu(tester, 'Rohith');
  expect(_menuNames(tester), everyOwner);

  // Several owners can be picked.
  await _tick(tester, 4);
  expect(server.lastOwnerIds!.split(',').toSet(), {'RO-R1', 'RO-T'});

  // "All owners" clears every pick in one tap.
  await _tick(tester, 0);
  expect(server.lastOwnerIds, isNull);
  expect(_checked(tester), [true, false, false, false, false]);

  // 4. Unticking the last pick ticks "All owners" again; the full list stays.
  await _tick(tester, 4);
  expect(server.lastOwnerIds, 'RO-T');
  await _tick(tester, 4);
  expect(server.lastOwnerIds, isNull);
  expect(_checked(tester), [true, false, false, false, false]);
  await _closeMenu(tester);
  await _openMenu(tester, 'Select rental owners');
  expect(_menuNames(tester), everyOwner);
  await _closeMenu(tester);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('PonnamKarthik/fluttertoast'),
            (_) async => true);
    ConnectivityPlatform.instance = _OnlineConnectivity();
  });

  testWidgets('Admin: owner dropdown keeps every owner, filter by id',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'token': 'tkn',
      'adminId': _adminId,
      'role': 'Admin',
      'companyName': 'Acme'
    });
    final server = _Server();
    await _run(server, () async {
      await _qaSteps(tester, server, admin.Lease_table());
      await _finish(tester);
    });
  });

  testWidgets('Staff: owner dropdown keeps every owner, filter by id',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'token': 'tkn',
      'adminId': _adminId,
      'role': 'Staffmember',
      'staff_id': 'STAFF-1',
      'companyName': 'Acme',
      'staff_permissions_cache_STAFF-1': jsonEncode(_allPermissions(true)),
    });
    final server = _Server();
    await _run(server, () async {
      await _qaSteps(tester, server, staff.Lease_table());
      await _finish(tester);
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

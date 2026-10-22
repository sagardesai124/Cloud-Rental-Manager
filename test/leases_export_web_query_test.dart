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
import 'package:three_zero_two_property/StaffModule/repository/staffpermission_provider.dart';
import 'package:three_zero_two_property/StaffModule/screen/Leasing/RentalRoll/lease_table.dart'
    as staff;
import 'package:three_zero_two_property/provider/dateProvider.dart';
import 'package:three_zero_two_property/provider/lease_provider.dart';
import 'package:three_zero_two_property/provider/notification_provider.dart';
import 'package:three_zero_two_property/screens/Leasing/RentalRoll/lease_table.dart'
    as admin;

/// Leases → Export (Admin and Staff) asks the server for the leases the same
/// way web staging does (RentRoll.jsx fetchAllDataForExport): every lease
/// (limit 0) with the selected status, search and sort. The server decides
/// Active / Expired / Future, so the export holds exactly web's leases in
/// web's order (At Will first, then latest end date first). Before, the
/// export downloaded every lease and picked Active / Expired by dates on the
/// phone, which let unsigned draft leases in and put At Will leases last.
/// The PDF title is also printed on the first page only, like web.

final List<Uri> _leaseRequests = [];

Map<String, dynamic> _lease(String id, String address, String end) => {
      'lease_id': id,
      'admin_id': 'ADMIN-1',
      'rental_id': 'P-$id',
      'rental_adress': address,
      'rental_unit': '',
      'rentalOwner_name': 'Owner One',
      'tenantNames': 'Pat Tenant',
      'start_date': '2026-01-01',
      'end_date': end,
      'lease_type': end == 'At Will' ? 'At-will(month to month)' : 'Fixed',
      'amount': 1500,
      'rent_cycle': 'Monthly',
      'rent_duedate': '1',
      'remainingDays': '100',
      'totalBalance': 0,
      'deposite': 0,
      'recurringCharge': 0,
      'createdAt': '2026-01-01T00:00:00.000Z',
      'updatedAt': '2026-01-01T00:00:00.000Z',
    };

final _server = MockClient((request) async {
  final path = request.url.path;
  Object body = {'statusCode': 200, 'data': []};
  if (path == '/api/auth') {
    body = {
      'statusCode': 200,
      'themes': {'format': 'MM/DD/YYYY', 'timeFormat': '12'}
    };
  } else if (path.startsWith('/api/leases/leases/')) {
    _leaseRequests.add(request.url);
    final rows = request.url.queryParameters['status'] == 'expired'
        ? [
            // An at-will lease the server counts as Expired (web shows it).
            _lease('L-9', '3652 Birch Blvd', 'At Will'),
            _lease('L-3', '1839 Pine Ave', '2026-09-30'),
          ]
        : [
            _lease('L-1', '3578 Valley Blvd', 'At Will'),
            _lease('L-2', '1580 Oak Ave', '2027-10-01'),
          ];
    body = {
      'statusCode': 200,
      'data': rows,
      'pagination': {
        'currentPage': 1,
        'totalPages': 1,
        'totalItems': rows.length,
        'itemsPerPage': 10
      },
    };
  } else if (path.startsWith('/api/leases/limitation/')) {
    body = {'statusCode': 200, 'leaseCount': 2, 'leaseCountLimit': 100};
  } else if (path.startsWith('/api/permission/permission/')) {
    body = {
      'statusCode': 200,
      'data': {
        'staff_permission': {
          'lease_view': true,
          'lease_add': true,
          'lease_edit': true,
          'lease_delete': true,
        }
      }
    };
  }
  return http.Response(jsonEncode(body), 200,
      headers: {'content-type': 'application/json'});
});

Future<void> _settle(WidgetTester tester, [int ticks = 40]) async {
  for (var i = 0; i < ticks; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    _leaseRequests.clear();
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
        const MethodChannel('PonnamKarthik/fluttertoast'), (_) async => true);
    // The PDF is handed to the printing plugin; nothing to show in a test.
    messenger.setMockMethodCallHandler(
        const MethodChannel('net.nfet.printing'), (_) async => true);
    ConnectivityPlatform.instance = _OnlineConnectivity();
  });

  Future<void> exportActive(WidgetTester tester, Widget screen, String role) async {
    tester.view.physicalSize = const Size(430, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({
      'token': 'tkn',
      'adminId': 'ADMIN-1',
      'staff_id': 'STAFF-1',
      'role': role,
    });
    final original = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('overflowed')) return;
      original?.call(details);
    };
    try {
      await http.runWithClient(() async {
        final dates = DateProvider();
        await dates.loadDateFormat();
        final permissions = StaffPermissionProvider();
        await permissions.fetchPermissions();
        await tester.pumpWidget(MultiProvider(
          providers: [
            ChangeNotifierProvider<DateProvider>.value(value: dates),
            ChangeNotifierProvider(create: (_) => NotificationProvider()),
            ChangeNotifierProvider(create: (_) => SelectedTenantsProvider()),
            ChangeNotifierProvider(create: (_) => SelectedCosignersProvider()),
            ChangeNotifierProvider(create: (_) => SelectedApplicantProvider()),
            ChangeNotifierProvider<StaffPermissionProvider>.value(
                value: permissions),
          ],
          child: MaterialApp(home: screen),
        ));
        await _settle(tester);

        // Status → Active.
        await tester.tap(find.text('All').first);
        await _settle(tester, 10);
        await tester.tap(find.text('Active').last);
        await _settle(tester);
        _leaseRequests.clear();

        // Export → PDF.
        await tester.tap(find.text('Export').first);
        await _settle(tester, 10);
        await tester.tap(find.text('Export as PDF').last);
        await _settle(tester, 60);

        expect(_leaseRequests, hasLength(1),
            reason: 'one request for the export, like web');
        final q = _leaseRequests.single.queryParameters;
        expect(q['status'], 'active', reason: 'the selected status');
        expect(q['limit'], '0', reason: 'every lease, like web');
        expect(q['page'], '1');
        expect(q['sortBy'], 'end_date', reason: "web's default sort");
        expect(q['sortOrder'], 'descending');
      }, () => _server);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    } finally {
      FlutterError.onError = original;
    }
  }

  testWidgets('Admin: Export asks the server like web (status, all rows, sort)',
      (tester) async {
    await exportActive(tester, admin.Lease_table(), 'Admin');
  });

  testWidgets('Staff: Export asks the server like web (status, all rows, sort)',
      (tester) async {
    await exportActive(tester, staff.Lease_table(), 'Staffmember');
  });

  Future<void> expiredList(WidgetTester tester, Widget screen, String role) async {
    tester.view.physicalSize = const Size(430, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({
      'token': 'tkn',
      'adminId': 'ADMIN-1',
      'staff_id': 'STAFF-1',
      'role': role,
    });
    final original = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('overflowed')) return;
      original?.call(details);
    };
    try {
      await http.runWithClient(() async {
        final dates = DateProvider();
        await dates.loadDateFormat();
        final permissions = StaffPermissionProvider();
        await permissions.fetchPermissions();
        await tester.pumpWidget(MultiProvider(
          providers: [
            ChangeNotifierProvider<DateProvider>.value(value: dates),
            ChangeNotifierProvider(create: (_) => NotificationProvider()),
            ChangeNotifierProvider(create: (_) => SelectedTenantsProvider()),
            ChangeNotifierProvider(create: (_) => SelectedCosignersProvider()),
            ChangeNotifierProvider(create: (_) => SelectedApplicantProvider()),
            ChangeNotifierProvider<StaffPermissionProvider>.value(
                value: permissions),
          ],
          child: MaterialApp(home: screen),
        ));
        await _settle(tester);
        await tester.tap(find.text('All').first);
        await _settle(tester, 10);
        await tester.tap(find.text('Expired').last);
        await _settle(tester);

        expect(find.textContaining('3652 Birch Blvd', findRichText: true),
            findsWidgets,
            reason: 'the server counts it Expired, so the list shows it, like web');
        expect(find.textContaining('1839 Pine Ave', findRichText: true),
            findsWidgets);
      }, () => _server);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    } finally {
      FlutterError.onError = original;
    }
  }

  testWidgets('Admin: Expired list shows every lease the server sends, like web',
      (tester) async {
    await expiredList(tester, admin.Lease_table(), 'Admin');
  });

  testWidgets('Staff: Expired list shows every lease the server sends, like web',
      (tester) async {
    await expiredList(tester, staff.Lease_table(), 'Staffmember');
  });

  test('PDF title is printed on the first page only, in Admin and Staff', () {
    for (final path in [
      'lib/screens/Leasing/RentalRoll/lease_table.dart',
      'lib/StaffModule/screen/Leasing/RentalRoll/lease_table.dart',
    ]) {
      final src = File(path).readAsStringSync();
      expect(src, contains('context.pageNumber > 1'), reason: path);
      expect(src, contains('repeat: true,'),
          reason: '$path: column headings on every page, like web');
      // The export itself (the on-screen rental-owner branch still fetches
      // the full list, which is separate).
      final start = src.indexOf('Future<List<Lease1>> _fetchAllLeasesForExport()');
      expect(start, greaterThan(0), reason: path);
      final body = src.substring(start, src.indexOf('\n  }\n', start));
      expect(body, contains('limit: 0,'), reason: '$path: every lease, like web');
      expect(body, contains('status: _apiLeaseStatus(),'), reason: path);
      expect(body, isNot(contains("fetchLease('')")),
          reason: '$path: the export no longer downloads every lease');
    }
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

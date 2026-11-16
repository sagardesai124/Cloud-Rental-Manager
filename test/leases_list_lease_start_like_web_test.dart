import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus_platform_interface/connectivity_plus_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
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

/// Leases list (Admin and Staff), like web staging:
///  - classic RentRoll.jsx: a "Lease Start" column that sorts by start_date,
///    and "Rent Cycle" as plain text (no sort); on phone width each card
///    shows Property Address + Lease Start, with Rent Cycle in the details;
///  - new look (leases-v2): "Term" shows the start date and sorts by it.
///  - the sort arrow shows only on the column the list is sorted by
///    (RentRoll.jsx `sortConfig`, default end_date descending → Lease End ▼).
/// Before, the app never showed the start date, its "Rent Cycle" header
/// sorted by start_date, and the arrow always sat on "Lease".

const _adminId = 'ADMIN-1';
const _adminPath = 'lib/screens/Leasing/RentalRoll/lease_table.dart';
const _staffPath = 'lib/StaffModule/screen/Leasing/RentalRoll/lease_table.dart';

Map<String, dynamic> _lease(
        String id, String start, String end, String cycle) =>
    {
      'lease_id': id,
      'admin_id': _adminId,
      'tenant_id': ['T-1'],
      'rental_id': 'R-1',
      'unit_id': 'U-1',
      'lease_type': 'Fixed',
      'start_date': start,
      'end_date': end,
      'amount': 100,
      'rent_cycle': cycle,
      'rent_duedate': start,
      'deposite': 0,
      'recurringCharge': 100,
      'tenantNames': 'Pat Tenant',
      'rental_adress': '1 Test Street',
      'rental_unit': '1',
      'createdAt': '2025-01-01 00:00:00',
      'updatedAt': '2025-01-01 00:00:00',
      'remainingDays': 120,
      'totalBalance': 0,
      'rentalOwner_name': 'Owner',
    };

final _leases = [
  _lease('L-1', '2026-02-01', '2027-02-28', 'Monthly'),
  _lease('L-2', '2025-03-15', '2026-12-31', 'Weekly'),
];

Map<String, dynamic> _allPermissions(bool value) {
  final keys = StaffPermission().toJson().keys;
  return {for (final k in keys) k: value};
}

class _Server {
  _Server({this.totalPages = 1});

  /// How many pages the fake server says there are.
  final int totalPages;
  final List<http.Request> requests = [];
  late final MockClient client = MockClient((request) async {
    requests.add(request);
    final path = request.url.path;
    Object body = {'statusCode': 200, 'data': []};
    if (path == '/api/auth') {
      body = {
        'statusCode': 200,
        'themes': {'format': 'YYYY-MM-DD', 'timeFormat': '24'}
      };
    } else if (path.startsWith('/api/leases/leases/')) {
      body = {
        'statusCode': 200,
        'data': _leases,
        'pagination': {
          'totalPages': totalPages,
          'totalItems': totalPages == 1 ? _leases.length : totalPages * 10,
          'page': int.tryParse(request.url.queryParameters['page'] ?? '') ?? 1,
        }
      };
    } else if (path.contains('/api/permission/permission/')) {
      body = {
        'statusCode': 200,
        'data': {'staff_permission': _allPermissions(true)}
      };
    } else if (path.contains('/api/leases/limitation/')) {
      body = {'statusCode': 200, 'leaseCount': 2, 'leaseCountLimit': 100};
    } else if (path.contains('/api/admin/admin_profile/')) {
      body = {'statusCode': 200, 'data': {'company_name': 'Acme'}};
    }
    return http.Response(jsonEncode(body), 200,
        headers: {'content-type': 'application/json'});
  });

  /// The sort the list asked the server for on its latest load.
  String? get lastSort {
    final loads = requests.where((r) =>
        r.method == 'GET' && r.url.path.startsWith('/api/leases/leases/'));
    if (loads.isEmpty) return null;
    final q = loads.last.url.queryParameters;
    return '${q['sortBy']} ${q['sortOrder']}';
  }

  /// The page (1-based) the list asked for on its latest load.
  String? get lastPage {
    final loads = requests.where((r) =>
        r.method == 'GET' && r.url.path.startsWith('/api/leases/leases/'));
    return loads.isEmpty ? null : loads.last.url.queryParameters['page'];
  }
}

Future<void> _settle(WidgetTester tester, [int ticks = 16]) async {
  for (var i = 0; i < ticks; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

final _up = find.byWidgetPredicate(
    (w) => w is FaIcon && w.icon == FontAwesomeIcons.sortUp);
final _down = find.byWidgetPredicate(
    (w) => w is FaIcon && w.icon == FontAwesomeIcons.sortDown);

/// The tappable header cell holding [label].
Finder _cell(String label) =>
    find.ancestor(of: find.text(label), matching: find.byType(InkWell)).first;

/// Which header shows the sort arrow and which way, e.g. "Lease End ▼".
String _arrowAt() {
  final out = <String>[];
  const headers = {
    'Lease': 'Lease',
    ' Lease Start': 'Lease Start',
    'Lease End': 'Lease End',
  };
  headers.forEach((text, name) {
    if (find.descendant(of: _cell(text), matching: _up).evaluate().isNotEmpty) {
      out.add('$name ▲');
    }
    if (find
        .descendant(of: _cell(text), matching: _down)
        .evaluate()
        .isNotEmpty) {
      out.add('$name ▼');
    }
  });
  return out.join(', ');
}

/// Pumps the real list at [width] with the providers main.dart supplies and
/// waits for the fake server. Overflow reports go to [overflows] (the test
/// font draws every glyph as a full em square, so dense rows overflow here).
Future<void> _pumpList(WidgetTester tester, Widget list, double width,
    List<String> overflows) async {
  tester.view.physicalSize = Size(width, 5000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final dates = DateProvider();
  await dates.loadDateFormat();
  final permissions = StaffPermissionProvider();
  await permissions.fetchPermissions();
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider<DateProvider>.value(value: dates),
      ChangeNotifierProvider(create: (_) => NotificationProvider()),
      ChangeNotifierProvider<StaffPermissionProvider>.value(value: permissions),
      ChangeNotifierProvider(create: (_) => SelectedTenantsProvider()),
      ChangeNotifierProvider(create: (_) => SelectedCosignersProvider()),
      ChangeNotifierProvider(create: (_) => SelectedApplicantProvider()),
    ],
    child: MaterialApp(home: list),
  ));
  await _settle(tester, 30);
}

Future<void> _run(WidgetTester tester, _Server server, List<String> overflows,
    Future<void> Function() body) async {
  final original = FlutterError.onError;
  FlutterError.onError = (d) {
    if (d.exceptionAsString().contains('overflowed')) {
      overflows.add(d.toString());
      return;
    }
    original?.call(d);
  };
  try {
    await http.runWithClient(() async {
      await body();
      await tester.pump(const Duration(seconds: 2));
      await _settle(tester, 10);
    }, () => server.client);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  } finally {
    FlutterError.onError = original;
  }
}

Future<void> _check(WidgetTester tester, Widget list) async {
  final server = _Server();
  final overflows = <String>[];
  await _run(tester, server, overflows, () async {
    await _pumpList(tester, list, 1080, overflows);

    Future<void> tapHeader(String label) async {
      await tester.tap(find.text(label));
      await _settle(tester, 20);
    }

    // Header: Lease | Lease Start | Lease End, like web.
    expect(find.text('Lease'), findsOneWidget);
    expect(find.text(' Lease Start'), findsOneWidget);
    expect(find.text(' Rent Cycle'), findsNothing,
        reason: 'Rent Cycle is no longer a sortable header');
    expect(find.text('Lease End'), findsOneWidget);

    // Default order is web's: Lease End newest first, so only Lease End
    // shows the arrow (it used to sit on "Lease" all the time).
    expect(server.lastSort, 'end_date descending');
    expect(_arrowAt(), 'Lease End ▼');

    // Each row shows its start date in the company format (YYYY-MM-DD),
    // next to the end date.
    expect(find.text('2026-02-01'), findsOneWidget);
    expect(find.text('2025-03-15'), findsOneWidget);
    expect(find.text('2027-02-28'), findsOneWidget);
    expect(find.text('Monthly'), findsNothing,
        reason: 'Rent Cycle is not on the collapsed card any more');

    // Lease Start sorts by start date, and the arrow follows the sort.
    await tapHeader(' Lease Start');
    expect(server.lastSort, 'start_date ascending');
    expect(_arrowAt(), 'Lease Start ▲');
    await tapHeader(' Lease Start');
    expect(server.lastSort, 'start_date descending');
    expect(_arrowAt(), 'Lease Start ▼');

    // The other sorts are unchanged; the arrow moves with them.
    await tapHeader('Lease');
    expect(server.lastSort, 'rental_adress ascending');
    expect(_arrowAt(), 'Lease ▲');
    await tapHeader('Lease End');
    expect(server.lastSort, 'end_date ascending');
    expect(_arrowAt(), 'Lease End ▲');
    await tapHeader('Lease End');
    expect(server.lastSort, 'end_date descending');
    expect(_arrowAt(), 'Lease End ▼');

    // Expanding a lease shows Rent Cycle as plain text, like web.
    await tester.tap(find.text('2026-02-01'));
    await _settle(tester, 8);
    expect(find.text('Rent Cycle:'), findsOneWidget);
    expect(find.text('Monthly'), findsOneWidget);
    expect(find.text('Remaining Days:'), findsOneWidget,
        reason: 'the other card details stay');
  });
}

/// At phone width, with the arrow on Lease Start and on Lease End, no header
/// cell overflows: the label shrinks to fit instead.
Future<void> _checkNarrow(
    WidgetTester tester, Widget list, String path) async {
  final lines = File(path).readAsLinesSync();
  final startIdx = lines.indexWhere((l) => l.contains('Widget _buildHeaders()'));
  expect(startIdx, isNonNegative);
  var endIdx = startIdx + 1;
  while (lines[endIdx] != '  }') {
    endIdx++;
  }
  final at = RegExp('${RegExp.escape(path)}:(\\d+)');
  bool inHeader(String report) {
    final m = at.firstMatch(report);
    if (m == null) return false;
    final line = int.parse(m.group(1)!);
    return line > startIdx && line <= endIdx + 1;
  }

  final server = _Server();
  final overflows = <String>[];
  await _run(tester, server, overflows, () async {
    await _pumpList(tester, list, 375, overflows);
    expect(_arrowAt(), 'Lease End ▼');
    await tester.tap(find.text(' Lease Start'));
    await _settle(tester, 20);
    expect(_arrowAt(), 'Lease Start ▲');
  });
  expect(overflows.where(inHeader), isEmpty,
      reason: 'a header cell overflowed at 375 wide');
}

/// Like web (RentRoll.jsx sortData → setCurrentPage(1)): tapping any sort
/// header from page 2 goes back to page 1 with the new order. Paging itself
/// keeps the current order.
Future<void> _checkSortGoesToPageOne(WidgetTester tester, Widget list) async {
  final server = _Server(totalPages: 2);
  final overflows = <String>[];
  final next = find.byWidgetPredicate(
      (w) => w is FaIcon && w.icon == FontAwesomeIcons.circleChevronRight);

  await _run(tester, server, overflows, () async {
    await _pumpList(tester, list, 1080, overflows);
    expect(find.text('Page 1 of 2'), findsOneWidget);
    expect(server.lastPage, '1');

    Future<void> toPageTwo(String sort) async {
      await tester.ensureVisible(next);
      await tester.tap(next);
      await _settle(tester, 20);
      expect(find.text('Page 2 of 2'), findsOneWidget);
      expect(server.lastPage, '2');
      expect(server.lastSort, sort, reason: 'paging keeps the order');
      await tester.ensureVisible(find.text('Lease End'));
    }

    Future<void> sortFromPageTwo(
        String before, String header, String after, String arrow) async {
      await toPageTwo(before);
      await tester.tap(find.text(header));
      await _settle(tester, 20);
      expect(server.lastPage, '1', reason: '$header from page 2 → page 1');
      expect(server.lastSort, after);
      expect(find.text('Page 1 of 2'), findsOneWidget);
      expect(_arrowAt(), arrow);
    }

    await sortFromPageTwo('end_date descending', ' Lease Start',
        'start_date ascending', 'Lease Start ▲');
    // Tapping the same column again (reversing it) also starts at page 1.
    await sortFromPageTwo('start_date ascending', ' Lease Start',
        'start_date descending', 'Lease Start ▼');
    await sortFromPageTwo(
        'start_date descending', 'Lease', 'rental_adress ascending', 'Lease ▲');
    await sortFromPageTwo(
        'rental_adress ascending', 'Lease End', 'end_date ascending', 'Lease End ▲');
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('PonnamKarthik/fluttertoast'), (_) async => true);
    ConnectivityPlatform.instance = _OnlineConnectivity();
  });

  void signInAdmin() => SharedPreferences.setMockInitialValues({
        'token': 'tkn',
        'adminId': _adminId,
        'role': 'Admin',
        'companyName': 'Acme',
      });

  void signInStaff() => SharedPreferences.setMockInitialValues({
        'token': 'tkn',
        'adminId': _adminId,
        'role': 'Staffmember',
        'staff_id': 'STAFF-1',
        'companyName': 'Acme',
        'staff_permissions_cache_STAFF-1': jsonEncode(_allPermissions(true)),
      });

  testWidgets('Admin Leases list: Lease Start column, sort and arrow, like web',
      (tester) async {
    signInAdmin();
    await _check(tester, admin.Lease_table());
  });

  testWidgets('Staff Leases list: Lease Start column, sort and arrow, like web',
      (tester) async {
    signInStaff();
    await _check(tester, staff.Lease_table());
  });

  testWidgets('Admin Leases: sorting from page 2 goes back to page 1, like web',
      (tester) async {
    signInAdmin();
    await _checkSortGoesToPageOne(tester, admin.Lease_table());
  });

  testWidgets('Staff Leases: sorting from page 2 goes back to page 1, like web',
      (tester) async {
    signInStaff();
    await _checkSortGoesToPageOne(tester, staff.Lease_table());
  });

  testWidgets('Admin Leases header fits at phone width with the arrow',
      (tester) async {
    signInAdmin();
    await _checkNarrow(tester, admin.Lease_table(), _adminPath);
  });

  testWidgets('Staff Leases header fits at phone width with the arrow',
      (tester) async {
    signInStaff();
    await _checkNarrow(tester, staff.Lease_table(), _staffPath);
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

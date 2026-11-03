import 'dart:convert';

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
import 'package:three_zero_two_property/StaffModule/repository/staffpermission_provider.dart';
import 'package:three_zero_two_property/provider/dateProvider.dart';
import 'package:three_zero_two_property/provider/lease_provider.dart';
import 'package:three_zero_two_property/provider/notification_provider.dart';
import 'package:three_zero_two_property/provider/properties_workorders.dart';
import 'package:three_zero_two_property/repository/properties_summery.dart';
import 'package:three_zero_two_property/screens/Dashboard/RentPastDueReport.dart';
import 'package:three_zero_two_property/widgets/dashboard_pagination_footer.dart';

/// Dashboard → Rent Due / Rent Paid / Rent Past Due report, like web: a
/// report with no rows shows only the "No Data Available" picture. The table
/// header (Property / Tenant / Amount) and the page row ("Page 0 of 0") are
/// hidden. With rows, both are there as before, and the page row is the
/// Dashboard's pagination footer.

http.Response _json(Object body) => http.Response(jsonEncode(body), 200,
    headers: {'content-type': 'application/json'});

const _oneRow = {
  'lease_id': 'L-1',
  'rental_data': {'rental_adress': '12 Main St', 'rental_city': 'Austin'},
  'tenant_data': [
    {'tenant_firstName': 'Ana', 'tenant_lastName': 'Lee'}
  ],
  'total': 100,
};

/// Rows the fake server returns for this month's rent due.
List<Map<String, Object?>> _rows = [];
int _totalPages = 1;

/// The query of every report request, oldest first.
final List<Map<String, String>> _requests = [];

final _server = MockClient((request) async {
  final path = request.url.path;
  if (path.startsWith('/api/payment/admin_balance/')) {
    _requests.add(request.url.queryParameters);
    // A search never matches here, like typing a name nobody has.
    final rows =
        request.url.queryParameters.containsKey('search') ? const [] : _rows;
    return _json({
      'statusCode': 200,
      'data': {
        'currentMonthRentDue': 0,
        'currentDueRentCharges': {
          'charges': rows,
          'total': rows.isEmpty ? 0 : 100,
        },
        'pagination': {
          'currentPage': 1,
          'totalPages': rows.isEmpty ? 0 : _totalPages,
          'totalItems': rows.length,
          'itemsPerPage': 10,
        },
      },
    });
  }
  if (path.startsWith('/api/rentals/rental-owners/')) return _json([]);
  if (path == '/api/auth') {
    return _json({
      'statusCode': 200,
      'themes': {'format': 'YYYY-MM-DD', 'timeFormat': '24'},
    });
  }
  return _json({'statusCode': 200, 'data': []});
});

final _emptyPicture =
    find.image(const AssetImage('assets/images/no_data_transparent.png'));

Finder _chevron(IconData icon) =>
    find.byWidgetPredicate((w) => w is FaIcon && w.icon == icon);

Future<void> _settle(WidgetTester tester, [int ticks = 30]) async {
  for (var i = 0; i < ticks; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Opens the real report the way the dashboard's Rent Due card does.
Future<void> _open(WidgetTester tester, bool isStaff) async {
  SharedPreferences.setMockInitialValues(isStaff
      ? {
          'token': 'tkn',
          'adminId': 'ADMIN-1',
          'staff_id': 'STAFF-1',
          'role': 'Staffmember'
        }
      : {'token': 'tkn', 'adminId': 'ADMIN-1', 'role': 'Admin'});
  tester.view.physicalSize = const Size(430, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final dates = DateProvider();
  await dates.loadDateFormat();
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider<DateProvider>.value(value: dates),
      ChangeNotifierProvider(create: (_) => NotificationProvider()),
      ChangeNotifierProvider(create: (_) => StaffPermissionProvider()),
      ChangeNotifierProvider(create: (_) => WorkOrderCountProvider()),
      ChangeNotifierProvider(create: (_) => DropdownProvider()),
      ChangeNotifierProvider(create: (_) => SelectedTenantsProvider()),
      ChangeNotifierProvider(create: (_) => SelectedCosignersProvider()),
    ],
    child: MaterialApp(
      onGenerateRoute: (_) => MaterialPageRoute(
        settings: const RouteSettings(arguments: <String, dynamic>{
          'monthType': 'Current Month',
          'chargeType': 'Charges',
        }),
        builder: (_) =>
            RentPastDueReports(title: 'Rent Due', fromStaffModule: isStaff),
      ),
    ),
  ));
  await _settle(tester);
}

Future<void> _run(WidgetTester tester, Future<void> Function() body) async {
  final original = FlutterError.onError;
  // Layout overflow (test font) and images (no decoding in tests) are noise
  // here.
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

  setUp(() {
    _rows = [];
    _totalPages = 1;
    _requests.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('PonnamKarthik/fluttertoast'), (_) async => true);
    ConnectivityPlatform.instance = _OnlineConnectivity();
  });

  for (final isStaff in [false, true]) {
    final who = isStaff ? 'Staff' : 'Admin';

    testWidgets('$who: an empty report shows only the No Data Available '
        'picture, like web', (tester) async {
      await _run(tester, () async {
        await _open(tester, isStaff);
        expect(find.text('No Data Available'), findsOneWidget);
        expect(_emptyPicture, findsOneWidget);
        expect(find.text('Rent Due'), findsOneWidget,
            reason: 'the Rent Due total line stays, like web');
        expect(find.text('Tenant'), findsNothing, reason: 'no table header');
        expect(find.text('Amount'), findsNothing, reason: 'no table header');
        expect(find.textContaining('Page '), findsNothing,
            reason: 'no "Page 0 of 0" row');
        expect(find.byType(DropdownButton<int>), findsNothing,
            reason: 'no rows-per-page box');
        expect(find.byType(DashboardPaginationFooter), findsNothing);
      });
    });

    testWidgets('$who: with rows, the header and page row are unchanged',
        (tester) async {
      _rows = [_oneRow];
      await _run(tester, () async {
        await _open(tester, isStaff);
        expect(find.text('Tenant'), findsOneWidget);
        expect(find.text('Amount'), findsOneWidget);
        expect(find.text('Page 1 of 1'), findsOneWidget);
        expect(find.byType(DropdownButton<int>), findsOneWidget);
        expect(find.byType(DashboardPaginationFooter), findsOneWidget,
            reason: 'the same pagination design as the Dashboard');
        expect(find.text('No Data Available'), findsNothing);
        expect(_emptyPicture, findsNothing);
      });
    });

    testWidgets('$who: next, previous and page size load the same pages as '
        'before', (tester) async {
      _rows = [_oneRow];
      _totalPages = 2;
      await _run(tester, () async {
        await _open(tester, isStaff);
        expect(find.text('Page 1 of 2'), findsOneWidget);

        await tester.tap(_chevron(FontAwesomeIcons.circleChevronRight));
        await _settle(tester);
        expect(_requests.last['page'], '2');
        expect(find.text('Page 2 of 2'), findsOneWidget);

        await tester.tap(_chevron(FontAwesomeIcons.circleChevronLeft));
        await _settle(tester);
        expect(_requests.last['page'], '1');
        expect(find.text('Page 1 of 2'), findsOneWidget);

        await tester.tap(find.byType(DropdownButton<int>));
        await _settle(tester, 10);
        await tester.tap(find.text('25').last);
        await _settle(tester);
        expect(_requests.last['limit'], '25');
        expect(_requests.last['page'], '1');
      });
    });

    testWidgets('$who: a search that finds nothing keeps No Results Found, '
        'without the header or page row', (tester) async {
      _rows = [_oneRow];
      await _run(tester, () async {
        await _open(tester, isStaff);
        await tester.enterText(find.byType(TextField), 'zzz');
        await _settle(tester); // 400 ms debounce, then the reload
        expect(find.text('No Results Found'), findsOneWidget);
        expect(find.text('No Data Available'), findsNothing);
        expect(find.text('Tenant'), findsNothing, reason: 'no table header');
        expect(find.textContaining('Page '), findsNothing,
            reason: 'no "Page 0 of 0" row');
      });
    });
  }
}

class _OnlineConnectivity extends ConnectivityPlatform
    with MockPlatformInterfaceMixin {
  @override
  Future<ConnectivityResult> checkConnectivity() async =>
      ConnectivityResult.wifi;
  @override
  Stream<ConnectivityResult> get onConnectivityChanged => const Stream.empty();
}

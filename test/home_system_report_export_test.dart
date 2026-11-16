import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:connectivity_plus_platform_interface/connectivity_plus_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:provider/provider.dart';
import 'package:share_plus_platform_interface/share_plus_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:three_zero_two_property/Model/Home_System_Report_model.dart';
import 'package:three_zero_two_property/StaffModule/repository/staffpermission_provider.dart';
import 'package:three_zero_two_property/StaffModule/screen/Reports/ReportScreens/Home_System_Report.dart'
    as staff;
import 'package:three_zero_two_property/provider/dateProvider.dart';
import 'package:three_zero_two_property/provider/notification_provider.dart';
import 'package:three_zero_two_property/screens/Reports/ReportScreens/Home_System_Report.dart'
    as admin;

/// Home Systems Report (Admin and Staff), like web staging
/// (HomeSystemReport.jsx):
/// - every unit header in the Excel and CSV reads "Unit: <number> -
///   <address>" (the summary part said "Unit: <number> - for test");
/// - a unit with no number shows an empty number, never "Unit: null";
/// - an empty Warranty Expiry or Last Maintenance date shows "N/A" (it was a
///   blank cell);
/// - an older maintenance history entry with no images list still loads (the
///   whole report failed to read).

final List<String> _sharedFiles = [];
late Directory _docs;

/// The server's report: unit A1 has an HVAC unit saved with empty Warranty
/// Expiry and Last Maintenance dates and an old history entry without an
/// images list; the second unit has no number.
final Map<String, dynamic> _report = {
  'rental_id': 'R-1',
  'total_units': 2,
  'total_appliances': 1,
  'units': [
    {
      'unit_id': 'U-1',
      'unit_address': '1 Elm St',
      'unit_number': 'A1',
      'total_appliances': 1,
      'appliances': [
        {
          'appliance_id': 'A-1',
          'appliance_name': 'Furnace',
          'appliance_description': 'Main unit',
          'category': 'HVAC',
          'type': 'Gas',
          'brand': 'Carrier',
          'model': 'X1',
          'serial_number': 'SN-9',
          'installed_date': '2026-01-15',
          'warranty_expiry': '',
          'last_maintenance_date': '',
          'status': 'Working',
          'notes': [],
          'maintenance_history': [
            {
              'timestamp': '2026-02-01',
              'admin_name': 'Pat Admin',
              'work_subject': 'Filter change',
              '_id': 'H-1',
            }
          ],
        }
      ],
    },
    {
      'unit_id': 'U-2',
      'unit_address': '2 Elm St',
      'total_appliances': 0,
      'appliances': [],
    },
    // Quotes in the address: the CSV header doubles them, like data cells.
    {
      'unit_id': 'U-3',
      'unit_address': 'Bldg "C"',
      'unit_number': 'C3',
      'total_appliances': 0,
      'appliances': [],
    },
  ],
};

class _FakeShare extends SharePlatform with MockPlatformInterfaceMixin {
  @override
  Future<ShareResult> share(ShareParams params) async {
    _sharedFiles.addAll((params.files ?? []).map((f) => f.path));
    return const ShareResult('ok', ShareResultStatus.success);
  }
}

class _FakePaths extends PathProviderPlatform with MockPlatformInterfaceMixin {
  @override
  Future<String?> getApplicationDocumentsPath() async => _docs.path;
}

class _Online extends ConnectivityPlatform with MockPlatformInterfaceMixin {
  @override
  Future<ConnectivityResult> checkConnectivity() async =>
      ConnectivityResult.wifi;
  @override
  Stream<ConnectivityResult> get onConnectivityChanged => const Stream.empty();
}

http.Response _json(Object body) => http.Response(jsonEncode(body), 200,
    headers: {'content-type': 'application/json'});

final _server = MockClient((request) async {
  final path = request.url.path;
  if (path == '/api/auth') {
    return _json({
      'statusCode': 200,
      'themes': {'format': 'YYYY-MM-DD', 'timeFormat': '12'}
    });
  }
  if (path.startsWith('/api/rentals/rentals/')) {
    return _json({
      'statusCode': 200,
      'data': [
        {'rental_id': 'R-1', 'rental_adress': '1 Elm St'},
        {'rental_id': 'R-2', 'rental_adress': '9 Oak Ave'},
      ]
    });
  }
  if (path.startsWith('/api/appliance/appliance-report/')) {
    return _json({'statusCode': 200, 'data': _report});
  }
  return _json({'statusCode': 200, 'data': []});
});

Future<void> _settle(WidgetTester tester, [int ticks = 30]) async {
  for (var i = 0; i < ticks; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Opens the report screen, runs [body], and closes it.
Future<void> _withScreen(WidgetTester tester, bool isStaff,
    Future<void> Function() body) async {
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
      if (isStaff) await permissions.fetchPermissions();
      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<DateProvider>.value(value: dates),
          ChangeNotifierProvider(create: (_) => NotificationProvider()),
          ChangeNotifierProvider<StaffPermissionProvider>.value(
              value: permissions),
        ],
        child: MaterialApp(
          home: isStaff
              ? staff.HomeSystemReportScreen()
              : admin.HomeSystemReportScreen(),
        ),
      ));
      await _settle(tester);
      await body();
    }, () => _server);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  } finally {
    FlutterError.onError = original;
  }
}

/// Runs the screen's own Excel or CSV export on the report and returns the
/// file it shares.
Future<File> _export(WidgetTester tester, String kind) async {
  final dynamic screen = tester.state(find.byWidgetPredicate((w) =>
      w is admin.HomeSystemReportScreen || w is staff.HomeSystemReportScreen));
  final data = Home_system_report.fromJson(_report);
  await tester.runAsync(() async {
    if (kind == 'CSV') {
      await screen.generateRentersInsuranceCSV(data);
    } else {
      await screen.generateRentersInsuranceExcel(data);
    }
  });
  await tester.pump();
  expect(_sharedFiles, hasLength(1), reason: 'one $kind file shared');
  return File(_sharedFiles.single);
}

/// All the text in the .xlsx (its shared strings).
String _xlsxStrings(File file) {
  final archive = ZipDecoder().decodeBytes(file.readAsBytesSync());
  final part = archive.findFile('xl/sharedStrings.xml');
  expect(part, isNotNull);
  return utf8.decode(part!.content);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    _sharedFiles.clear();
    _docs = Directory.systemTemp.createTempSync('home_system_export_');
    SharePlatform.instance = _FakeShare();
    PathProviderPlatform.instance = _FakePaths();
    ConnectivityPlatform.instance = _Online();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('PonnamKarthik/fluttertoast'), (_) async => true);
  });
  tearDown(() {
    if (_docs.existsSync()) _docs.deleteSync(recursive: true);
  });

  test('an old history entry without images still reads', () {
    final data = Home_system_report.fromJson(_report);
    final history = data.units!.first.appliances!.single.maintenanceHistory!;
    expect(history.single.workSubject, 'Filter change');
    expect(history.single.images, isEmpty);
  });

  for (final isStaff in [false, true]) {
    final role = isStaff ? 'Staff' : 'Admin';

    testWidgets('$role: Run shows a report whose history has no images',
        (tester) async {
      await _withScreen(tester, isStaff, () async {
        await tester.tap(find.text('Select Property').evaluate().isNotEmpty
            ? find.text('Select Property')
            : find.byType(DropdownButtonHideUnderline).first);
        await _settle(tester, 10);
        await tester.tap(find.text('1 Elm St').last);
        await _settle(tester, 10);
        await tester.tap(find
            .byWidgetPredicate(
                (w) => w is FaIcon && w.icon == FontAwesomeIcons.circlePlay)
            .first);
        await _settle(tester, 20);
        expect(find.text('Unit: A1 - 1 Elm St'), findsOneWidget);
        expect(find.text('Unit:  - 2 Elm St'), findsOneWidget,
            reason: 'no "Unit: null"');
        // Open unit A1: its appliance and history show.
        await tester.tap(find
            .byWidgetPredicate(
                (w) => w is FaIcon && w.icon == FontAwesomeIcons.sortDown)
            .first);
        await _settle(tester, 10);
        expect(find.textContaining('Furnace', findRichText: true),
            findsWidgets);
      });
    });

    testWidgets('$role CSV: web unit headers, N/A for empty dates',
        (tester) async {
      await _withScreen(tester, isStaff, () async {
        final csv = (await _export(tester, 'CSV')).readAsStringSync();
        expect(csv, isNot(contains('for test')));
        expect(csv, isNot(contains('Unit: null')));
        // Details and summary both name the unit like web.
        expect('Unit: A1 - 1 Elm St'.allMatches(csv), hasLength(2));
        expect(csv, contains('"Unit:  - 2 Elm St"'));
        expect('"Unit: C3 - Bldg ""C"""'.allMatches(csv), hasLength(2),
            reason: 'quotes doubled, so the header stays one cell');
        final furnace = csv
            .split('\n')
            .firstWhere((l) => l.startsWith('"Furnace","Main unit"'));
        final cells = furnace.trim().split('","');
        expect(cells[8], 'N/A', reason: 'Warranty Expiry');
        expect(cells[9], 'N/A', reason: 'Last Maintenance');
      });
    });

    testWidgets('$role Excel: web unit headers, N/A for empty dates',
        (tester) async {
      await _withScreen(tester, isStaff, () async {
        final strings = _xlsxStrings(await _export(tester, 'Excel'));
        expect(strings, isNot(contains('for test')));
        expect(strings, isNot(contains('Unit: null')));
        expect(strings, contains('Unit: A1 - 1 Elm St'));
        expect(strings, contains('Unit:  - 2 Elm St'));
        // Every other value is filled, so N/A can only be the empty dates.
        expect(strings, contains('N/A'));
      });
    });
  }
}

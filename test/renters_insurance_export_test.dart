import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:connectivity_plus_platform_interface/connectivity_plus_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/intl.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:provider/provider.dart';
import 'package:share_plus_platform_interface/share_plus_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:three_zero_two_property/StaffModule/repository/staffpermission_provider.dart';
import 'package:three_zero_two_property/StaffModule/screen/Reports/ReportScreens/RentersInsurance.dart'
    as staff;
import 'package:three_zero_two_property/provider/dateProvider.dart';
import 'package:three_zero_two_property/provider/notification_provider.dart';
import 'package:three_zero_two_property/screens/Reports/ReportScreens/RentersInsurance.dart'
    as admin;

/// Renter's Insurance → Export, like web staging (QA, Android 1.0.249+252):
/// - CSV: the file used to be empty (0 bytes); it now holds web's columns
///   and values — "Tenant", `$` + the saved amount, dates in the account's
///   format;
/// - XLSX: web's sheet name "Renters Insurance", title block ("Renter's
///   Insurance Report", "Generated on: <today>", blank row) and the "Tenant"
///   column; the rows are unchanged;
/// - PDF: the "Tenant" column, like web.

final List<String> _sharedFiles = [];
late Directory _docs;

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

MockClient _server() => MockClient((request) async {
      final path = request.url.path;
      if (path == '/api/auth') {
        return _json({
          'statusCode': 200,
          'themes': {'format': 'MM/DD/YYYY', 'timeFormat': '12'}
        });
      }
      if (path.startsWith('/api/renter-insurance/report/')) {
        return _json({
          'statusCode': 200,
          'data': [
            {
              '_id': 'R-1',
              'lease_id': 'L-1',
              'tenant_id': 'T-1',
              'tenant_name': 'Smith, John',
              'unit_details': '12 Main St - A1',
              'rentersInsurance': {
                'insurance_company': 'Pwc',
                'policy_id': 'POL-1',
                'liability_coverage': 100000,
                'effective_date': '2026-03-03',
                'expiration_date': '2026-12-20',
              },
            },
            {
              '_id': 'R-2',
              'lease_id': 'L-2',
              'tenant_id': 'T-2',
              'tenant_name': 'Ruth Moss',
              'unit_details': '',
              'rentersInsurance': {
                'insurance_company': 'Lemonade',
                'policy_id': 'POL-2',
                'liability_coverage': 2500.5,
                'effective_date': '2026-01-15',
                'expiration_date': '2027-01-15',
              },
            },
          ],
        });
      }
      return _json({'statusCode': 200, 'data': []});
    });

Future<void> _settle(WidgetTester tester, [int ticks = 16]) async {
  for (var i = 0; i < ticks; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Opens the real report, picks Export → [kind] and returns the shared file.
Future<File> _export(WidgetTester tester, bool isStaff, String kind) async {
  SharedPreferences.setMockInitialValues(isStaff
      ? {
          'token': 'tkn',
          'adminId': 'ADMIN-1',
          'staff_id': 'STAFF-1',
          'role': 'Staffmember'
        }
      : {'token': 'tkn', 'adminId': 'ADMIN-1', 'role': 'Admin'});
  tester.view.physicalSize = const Size(430, 1600);
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
          home: isStaff ? staff.RentersInsurance() : admin.RentersInsurance(),
        ),
      ));
      await _settle(tester, 30);

      await tester.tap(find.text('Export'));
      await _settle(tester, 10);
      await tester.tap(find.text(kind).last);
      // The export writes a real file: alternate test time and real time
      // until it is shared.
      for (var i = 0; i < 20 && _sharedFiles.isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 100)));
      }
    }, _server);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  } finally {
    FlutterError.onError = original;
  }
  expect(_sharedFiles, hasLength(1), reason: 'one file shared');
  return File(_sharedFiles.single);
}

/// The text of one part of the .xlsx (a zip of XML files).
String _xlsxPart(File file, String name) {
  final archive = ZipDecoder().decodeBytes(file.readAsBytesSync());
  final part = archive.findFile(name);
  expect(part, isNotNull, reason: '$name in the workbook');
  return utf8.decode(part!.content);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    _sharedFiles.clear();
    _docs = Directory.systemTemp.createTempSync('ri_export_');
    SharePlatform.instance = _FakeShare();
    PathProviderPlatform.instance = _FakePaths();
    ConnectivityPlatform.instance = _Online();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('PonnamKarthik/fluttertoast'), (_) async => true);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('flutter.baseflow.com/permissions/methods'),
            (call) async => {for (var i = 0; i < 40; i++) i: 1});
  });
  tearDown(() {
    if (_docs.existsSync()) _docs.deleteSync(recursive: true);
  });

  for (final isStaff in [false, true]) {
    final role = isStaff ? 'Staff' : 'Admin';

    testWidgets('$role: CSV holds web\'s columns and values', (tester) async {
      final file = await _export(tester, isStaff, 'CSV');
      expect(file.lengthSync(), greaterThan(0), reason: 'not an empty file');
      expect(file.readAsStringSync().split('\n'), [
        'Unit,Tenant,Insurance Provider,Policy ID,Liability Coverage,'
            'Effective Date,Expiration Date',
        '12 Main St - A1,"Smith, John",Pwc,POL-1,\$100000,03/03/2026,12/20/2026',
        ',Ruth Moss,Lemonade,POL-2,\$2500.5,01/15/2026,01/15/2027',
      ]);
    });

    testWidgets('$role: XLSX has web\'s sheet name, title block and Tenant',
        (tester) async {
      final file = await _export(tester, isStaff, 'XLSX');
      expect(_xlsxPart(file, 'xl/workbook.xml'),
          contains('name="Renters Insurance"'));

      final strings = _xlsxPart(file, 'xl/sharedStrings.xml')
          .replaceAll('&apos;', "'");
      final today = DateFormat('MM/dd/yyyy').format(DateTime.now());
      expect(strings, contains("Renter's Insurance Report"));
      expect(strings, contains('Generated on: $today'));
      expect(strings, contains('<t>Tenant</t>'));
      expect(strings, isNot(contains('Tenant Name')));

      // Title rows 1-2, row 3 blank, headers on row 4, policies from row 5.
      final sheet = _xlsxPart(file, 'xl/worksheets/sheet1.xml');
      expect(sheet, contains('r="A1"'));
      expect(sheet, contains('r="A2"'));
      expect(sheet, isNot(contains('r="A3"')));
      expect(sheet, contains('r="G4"'));
      expect(sheet, contains('r="G6"'));
      expect(sheet, isNot(contains('r="A7"')));
    });
  }

  test('PDF column says "Tenant", like web (Admin and Staff)', () {
    for (final path in [
      'lib/screens/Reports/ReportScreens/RentersInsurance.dart',
      'lib/StaffModule/screen/Reports/ReportScreens/RentersInsurance.dart',
    ]) {
      final live = File(path)
          .readAsLinesSync()
          .where((l) => !l.trimLeft().startsWith('//'))
          .join('\n');
      expect(live, contains("pw.Text('Tenant',"), reason: path);
      expect(live, isNot(contains("pw.Text('Tenant Name'")), reason: path);
    }
  });
}

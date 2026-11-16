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
import 'package:three_zero_two_property/StaffModule/screen/Rental/Properties/applience/Applience_parts.dart'
    as staff_parts;
import 'package:three_zero_two_property/model/unitsummery_propeties.dart';
import 'package:three_zero_two_property/provider/dateProvider.dart';
import 'package:three_zero_two_property/provider/notification_provider.dart';
import 'package:three_zero_two_property/screens/Rental/Properties/applience/Applience_parts.dart'
    as admin_parts;

/// The unit appliance list on a wide screen (Admin and Staff) has a quick
/// edit popup on every row. Like web's edit form, it edits the appliance on
/// the row that was tapped and keeps that appliance's other saved values.
/// Before, it always opened and saved the FIRST appliance, and its update
/// sent only name, description and installed date, so the server (which
/// writes every field it gets, and clears HVAC filters when no category is
/// sent) would have erased type, brand, dates, notes and filters.

const _fridge = {
  'appliance_id': 'A-1',
  'appliance_name': 'Fridge',
  'appliance_description': 'Kitchen',
  'installed_date': '2026-01-15',
  'category_id': 'C-R',
  'category_name': 'Refrigerator',
  'status': 'Working',
  'brand': 'LG',
};

const _furnace = {
  'appliance_id': 'A-2',
  'appliance_name': 'Furnace',
  'appliance_description': 'Main unit',
  'installed_date': '2025-10-01',
  'category_id': 'C-H',
  'category_name': 'HVAC',
  'type': 'Gas',
  'system_type': 'Major System',
  'brand': 'Carrier',
  'model': 'X1',
  'serial_number': 'SN-9',
  'warranty_expiry': '2027-01-01',
  'last_maintenance_date': '2026-06-01',
  'maintenance_notes': 'Yearly service',
  'status': 'Needs Repair',
  'filters': [
    {'filter_id': 'F-1', 'filter_name': 'MERV 8', 'filter_size': '16x20x1'}
  ],
};

// Saved on web without an Installed Date or a description (both optional
// there).
const _heater = {
  'appliance_id': 'A-3',
  'appliance_name': 'Water heater',
  'category_id': 'C-W',
  'category_name': 'Water Heater',
  'status': 'Working',
};

class _Server {
  _Server([this.appliances = const [_fridge, _furnace]]);
  final List<Map<String, Object>> appliances;
  final List<String> paths = [];
  final List<Map<String, String>> saves = [];
  final List<String> deletes = [];
  late final MockClient client = MockClient((request) async {
    final path = request.url.path;
    Object body = {'statusCode': 200, 'data': []};
    if (request.method == 'PUT' && path.startsWith('/api/appliance/appliance/')) {
      paths.add(path);
      saves.add(Map.of(request.bodyFields));
      body = {'statusCode': 200, 'message': 'Appliance updated'};
    } else if (request.method == 'DELETE' &&
        path.startsWith('/api/appliance/appliance/')) {
      deletes.add(path);
      body = {'statusCode': 200, 'message': 'Appliance deleted'};
    } else if (request.method == 'GET' &&
        path.endsWith('/appliance/appliance/U-1')) {
      body = {'statusCode': 200, 'data': appliances};
    }
    return http.Response(jsonEncode(body), 200,
        headers: {'content-type': 'application/json'});
  });
}

Future<void> _settle(WidgetTester tester, [int ticks = 30]) async {
  for (var i = 0; i < ticks; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('PonnamKarthik/fluttertoast'), (_) async => true);
    ConnectivityPlatform.instance = _OnlineConnectivity();
    SharedPreferences.setMockInitialValues({
      'token': 'tkn',
      'adminId': 'ADMIN-1',
      'role': 'Staffmember',
      'staff_id': 'STAFF-1',
    });
  });

  final screens = <String, Widget Function()>{
    'Admin': () => admin_parts.AppliancesPart(
        unit: unit_properties(unitId: 'U-1', rentalId: 'R-1')),
    'Staff': () => staff_parts.AppliancesPart(
        unit: unit_properties(unitId: 'U-1', rentalId: 'R-1')),
  };

  screens.forEach((role, build) {
    testWidgets(
        '$role: quick edit saves the tapped row and keeps its other values',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 3000); // wide layout
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final original = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.exceptionAsString().contains('overflowed')) return;
        original?.call(details);
      };
      final server = _Server();
      try {
        await http.runWithClient(() async {
          final permissions = StaffPermissionProvider();
          await permissions.fetchPermissions();
          await tester.pumpWidget(MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => DateProvider()),
              ChangeNotifierProvider(create: (_) => NotificationProvider()),
              ChangeNotifierProvider<StaffPermissionProvider>.value(
                  value: permissions),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(child: build()),
              ),
            ),
          ));
          await _settle(tester);

          // Edit on the SECOND row (the HVAC furnace).
          final edits = find.byWidgetPredicate(
              (w) => w is FaIcon && w.icon == FontAwesomeIcons.edit);
          expect(edits, findsNWidgets(2), reason: 'one edit per row');
          await tester.tap(edits.at(1));
          await _settle(tester, 10);

          Finder box(String text) => find.byWidgetPredicate(
              (w) => w is TextField && w.controller?.text == text);
          expect(box('Furnace'), findsOneWidget,
              reason: 'the popup shows the tapped row');
          expect(box('Main unit'), findsOneWidget);

          await tester.enterText(box('Furnace'), 'Furnace 2');
          final save = find.widgetWithText(ElevatedButton, 'Save').last;
          await tester.ensureVisible(save);
          await tester.pump();
          await tester.tap(save);
          await _settle(tester);

          expect(server.paths, ['/api/appliance/appliance/A-2'],
              reason: 'saves the tapped appliance, not the first one');
          final f = server.saves.single;
          expect(f['appliance_name'], 'Furnace 2');
          expect(f['appliance_description'], 'Main unit');
          expect(f['installed_date'], '2025-10-01');
          // Everything else is sent back unchanged, like web's edit form.
          expect(f['category_id'], 'C-H');
          expect(f['type'], 'Gas');
          expect(f['system_type'], 'Major System');
          expect(f['brand'], 'Carrier');
          expect(f['model'], 'X1');
          expect(f['serial_number'], 'SN-9');
          expect(f['warranty_expiry'], '2027-01-01');
          expect(f['last_maintenance_date'], '2026-06-01');
          expect(f['maintenance_notes'], 'Yearly service');
          expect(f['status'], 'Needs Repair');
          final filters = jsonDecode(f['filters']!) as List;
          expect(filters, hasLength(1));
          expect(filters.single['filter_name'], 'MERV 8');
          expect(filters.single['filter_size'], '16x20x1');
          expect(f.containsKey('appliance_image'), isFalse,
              reason: 'the photo is left alone');
        }, () => server.client);
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 5));
      } finally {
        FlutterError.onError = original;
      }
    });

    testWidgets('$role: delete removes the tapped row, like web',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 3000); // wide layout
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final original = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.exceptionAsString().contains('overflowed')) return;
        original?.call(details);
      };
      final server = _Server();
      try {
        await http.runWithClient(() async {
          final permissions = StaffPermissionProvider();
          await permissions.fetchPermissions();
          await tester.pumpWidget(MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => DateProvider()),
              ChangeNotifierProvider(create: (_) => NotificationProvider()),
              ChangeNotifierProvider<StaffPermissionProvider>.value(
                  value: permissions),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(child: build()),
              ),
            ),
          ));
          await _settle(tester);

          // Delete on the SECOND row (the furnace), then confirm.
          final trash = find.byWidgetPredicate(
              (w) => w is FaIcon && w.icon == FontAwesomeIcons.trashCan);
          expect(trash, findsNWidgets(2), reason: 'one delete per row');
          await tester.tap(trash.at(1));
          await _settle(tester, 10);
          await tester.tap(find.text('Delete').last);
          await _settle(tester);

          expect(server.deletes, ['/api/appliance/appliance/A-2'],
              reason: 'deletes the tapped appliance, not the first one');
        }, () => server.client);
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 5));
      } finally {
        FlutterError.onError = original;
      }
    });

    testWidgets(
        '$role: wide list shows N/A for a missing date and its quick edit '
        'saves without one, like web', (tester) async {
      final server = _Server(const [_fridge, _furnace, _heater]);
      await _pumpList(tester, build, server, width: 1200, body: () async {
        expect(find.text('N/A'), findsOneWidget,
            reason: 'the heater has no Installed Date');
        final edits = find.byWidgetPredicate(
            (w) => w is FaIcon && w.icon == FontAwesomeIcons.edit);
        expect(edits, findsNWidgets(3));
        await tester.tap(edits.at(2));
        await _settle(tester, 10);

        final name = find.byWidgetPredicate(
            (w) => w is TextField && w.controller?.text == 'Water heater');
        expect(name, findsOneWidget);
        await tester.enterText(name, 'Water heater 2');
        final save = find.widgetWithText(ElevatedButton, 'Save').last;
        await tester.ensureVisible(save);
        await tester.pump();
        await tester.tap(save);
        await _settle(tester);

        expect(find.text('Please fill in all fields correctly.'), findsNothing);
        expect(server.paths, ['/api/appliance/appliance/A-3']);
        final f = server.saves.single;
        expect(f['appliance_name'], 'Water heater 2');
        expect(f['appliance_description'], '');
        expect(f['installed_date'], '');
      });
    });

    testWidgets('$role: phone list shows N/A for a missing date, not "null"',
        (tester) async {
      final server = _Server(const [_fridge, _heater]);
      await _pumpList(tester, build, server, width: 400, body: () async {
        expect(find.textContaining('null', findRichText: true), findsNothing,
            reason: 'no "null" name');
        // The date shows once the row is opened with its arrow (row 2).
        final arrows = find.byWidgetPredicate(
            (w) => w is FaIcon && w.icon == FontAwesomeIcons.sortDown);
        expect(arrows, findsNWidgets(2));
        await tester.tap(arrows.at(1));
        await _settle(tester, 10);
        // On the date line itself (the heater's Brand line shows N/A too).
        expect(find.text('Install Date : N/A', findRichText: true),
            findsOneWidget);
        expect(find.textContaining('null', findRichText: true), findsNothing);
      });
    });

    // Must pass before AND after the missing-date fix: an appliance that has
    // every value shows exactly as it did.
    testWidgets('$role: phone list shows a full appliance the same as before',
        (tester) async {
      final server = _Server(const [_furnace]);
      await _pumpList(tester, build, server, width: 400, body: () async {
        await tester.tap(find.byWidgetPredicate(
            (w) => w is FaIcon && w.icon == FontAwesomeIcons.sortDown));
        await _settle(tester, 10);
        final shownDate = DateProvider().formatCurrentDate('2025-10-01');
        expect(find.textContaining(shownDate, findRichText: true),
            findsWidgets,
            reason: 'the date in the company format, as before');
        expect(find.textContaining('Carrier', findRichText: true),
            findsWidgets);
        expect(find.textContaining('Furnace', findRichText: true),
            findsWidgets);
        expect(find.textContaining('N/A', findRichText: true), findsNothing);
      });
    });
  });
}

/// Shows the unit appliance list at [width] (over 500 is the wide table) and
/// runs [body] while the fake server answers.
Future<void> _pumpList(WidgetTester tester, Widget Function() build,
    _Server server,
    {required double width, required Future<void> Function() body}) async {
  tester.view.physicalSize = Size(width, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final original = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.exceptionAsString().contains('overflowed')) return;
    original?.call(details);
  };
  try {
    await http.runWithClient(() async {
      final permissions = StaffPermissionProvider();
      await permissions.fetchPermissions();
      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => DateProvider()),
          ChangeNotifierProvider(create: (_) => NotificationProvider()),
          ChangeNotifierProvider<StaffPermissionProvider>.value(
              value: permissions),
        ],
        child: MaterialApp(
          home: Scaffold(body: SingleChildScrollView(child: build())),
        ),
      ));
      await _settle(tester);
      await body();
    }, () => server.client);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  } finally {
    FlutterError.onError = original;
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

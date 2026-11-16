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
import 'package:three_zero_two_property/Model/unit.dart';
import 'package:three_zero_two_property/StaffModule/repository/staffpermission_provider.dart';
import 'package:three_zero_two_property/StaffModule/screen/Rental/Properties/applience/Add_applience.dart'
    as staff_add;
import 'package:three_zero_two_property/StaffModule/screen/Rental/Properties/applience/edit_appliences.dart'
    as staff_edit;
import 'package:three_zero_two_property/model/unitsummery_propeties.dart';
import 'package:three_zero_two_property/provider/dateProvider.dart';
import 'package:three_zero_two_property/provider/notification_provider.dart';
import 'package:three_zero_two_property/screens/Rental/Properties/applience/Add_applience.dart'
    as admin_add;
import 'package:three_zero_two_property/screens/Rental/Properties/applience/edit_appliences.dart'
    as admin_edit;

/// Add / Edit Appliance (Admin and Staff), HVAC: every filter needs a name
/// and a size, like web staging (PropDetails.jsx: "Filter name and size are
/// required for all filters", and nothing is saved; a blank filter row
/// counts too). Before, Add saved a filter with only a name or only a size,
/// and Edit saved any row, even a blank one.
///
/// Like web and the server, a category is HVAC when its name contains "hvac"
/// in any case, so a category named "Hvac System" gets the filters and this
/// rule too (the app only matched the exact name "HVAC").

const _message = 'Filter name and size are required for all filters';

const _hvac = {'category_id': 'C-H', 'name': 'HVAC', 'brands': ['Carrier']};
const _hvacSystem = {
  'category_id': 'C-HS',
  'name': 'Hvac System',
  'brands': ['Carrier']
};
const _refrigerator = {
  'category_id': 'C-R',
  'name': 'Refrigerator',
  'brands': ['LG']
};

class _Server {
  _Server([this.categories = const [_hvac]]);
  final List<Map<String, Object>> categories;
  final List<String> saves = [];
  late final MockClient client = MockClient((request) async {
    final path = request.url.path;
    Object body = {'statusCode': 200, 'data': []};
    if ((request.method == 'POST' || request.method == 'PUT') &&
        path.startsWith('/api/appliance/appliance')) {
      saves.add('${request.method} $path');
      body = {'statusCode': 200, 'message': 'Appliance saved'};
    } else if (path.contains('/api/settings/allCategories/')) {
      body = {'statusCode': 200, 'data': categories};
    }
    return http.Response(jsonEncode(body), 200,
        headers: {'content-type': 'application/json'});
  });
}

unit_appliance _furnace({String categoryId = 'C-H'}) => unit_appliance(
      applianceId: 'A-1',
      applianceName: 'Furnace',
      applianceDescription: 'Main unit',
      categoryId: categoryId,
      status: 'Working',
      brand: 'Carrier', // Edit Appliance requires a brand
      installedDate: '2026-01-15',
      filters: [
        {'filter_id': 'F-1', 'filter_name': 'MERV 8', 'filter_size': ''}
      ],
    );

unit_appliance _furnaceWithoutFilters() => unit_appliance(
      applianceId: 'A-1',
      applianceName: 'Furnace',
      applianceDescription: 'Main unit',
      categoryId: 'C-H',
      status: 'Working',
      brand: 'Carrier',
      installedDate: '2026-01-15',
      filters: [],
    );

unit_appliance _fridge() => unit_appliance(
      applianceId: 'A-1',
      applianceName: 'Fridge',
      applianceDescription: 'Kitchen',
      categoryId: 'C-R',
      status: 'Working',
      brand: 'LG',
      installedDate: '2026-01-15',
    );

Finder _box(String hint) => find.byWidgetPredicate(
    (w) => w is TextField && w.decoration?.hintText == hint);

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

  // "Add" here is the Add screen opened on a saved appliance (Appliance
  // Summary → Edit), so it updates (PUT); a new appliance (POST) is below.
  final screens = <String, Widget Function(unit_appliance)>{
    'Admin Add': (a) => admin_add.AddApplience(
        unit: unit_properties(unitId: 'U-1'), appliance: a),
    'Staff Add': (a) => staff_add.AddApplience(
        unit: unit_properties(unitId: 'U-1'), appliance: a),
    'Admin Edit': (a) => admin_edit.Edit_applience(
        unit: unit_properties(unitId: 'U-1'), appliance: a),
    'Staff Edit': (a) => staff_edit.Edit_applience(
        unit: unit_properties(unitId: 'U-1'), appliance: a),
  };
  const hvacCategories = {'HVAC': _hvac, 'Hvac System': _hvacSystem};

  screens.forEach((name, build) {
   hvacCategories.forEach((categoryName, category) {
    testWidgets(
        categoryName == 'HVAC'
            ? '$name: HVAC filters need a name and a size, like web'
            : '$name: a "$categoryName" category is HVAC too, like web',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 6000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final original = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.exceptionAsString().contains('overflowed')) return;
        original?.call(details);
      };
      final server = _Server([category]);
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
                home: build(_furnace(
                    categoryId: category['category_id'] as String))),
          ));
          await _settle(tester);
          final save = find.widgetWithText(ElevatedButton, 'Save');

          Future<void> tapSave() async {
            // Let an earlier message bar go first, so it can't cover Save.
            tester
                .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger))
                .clearSnackBars();
            await _settle(tester, 10);
            await tester.ensureVisible(save);
            await tester.pump();
            await tester.tap(save);
            await _settle(tester);
          }

          // "MERV 8" with no size: web's message, nothing saved.
          expect(_box('Filter Name'), findsOneWidget);
          await tapSave();
          expect(find.text(_message), findsWidgets);
          expect(server.saves, isEmpty);

          // Size filled, but a blank filter row added: still refused.
          await tester.enterText(_box('Filter Size (e.g., 16x20x1)'), '16x20x1');
          final addFilter = find.widgetWithText(ElevatedButton, 'Add Filter');
          await tester.ensureVisible(addFilter);
          await tester.pump();
          await tester.tap(addFilter);
          await _settle(tester, 10);
          expect(_box('Filter Name'), findsNWidgets(2));
          await tapSave();
          expect(server.saves, isEmpty, reason: 'a blank row counts, like web');

          // Every filter complete: it saves.
          await tester.enterText(_box('Filter Name').last, 'MERV 11');
          await tester.enterText(
              _box('Filter Size (e.g., 16x20x1)').last, '20x25x1');
          await tapSave();
          expect(server.saves, ['PUT /api/appliance/appliance/A-1']);
        }, () => server.client);
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 5));
      } finally {
        FlutterError.onError = original;
      }
    });
   });
  });

  // A new appliance from Infrastructure → + Add (POST): pick Type, an HVAC
  // category and the Installed Date, add a filter with only a name.
  final newForms = <String, Widget Function()>{
    'Admin': () => admin_add.AddApplience(unit: unit_properties(unitId: 'U-1')),
    'Staff': () => staff_add.AddApplience(unit: unit_properties(unitId: 'U-1')),
  };
  newForms.forEach((role, build) {
    testWidgets('$role Add, new appliance (POST): HVAC filters need a name '
        'and a size, like web', (tester) async {
      tester.view.physicalSize = const Size(1080, 6000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final original = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.exceptionAsString().contains('overflowed')) return;
        original?.call(details);
      };
      final server = _Server(const [_hvac, _refrigerator]);
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
            child: MaterialApp(home: build()),
          ));
          await _settle(tester);

          Future<void> pick(String hint, String option) async {
            await tester.ensureVisible(find.text(hint));
            await tester.pump();
            await tester.tap(find.text(hint));
            await _settle(tester, 10);
            await tester.tap(find.text(option).last);
            await _settle(tester, 10);
          }

          await tester.enterText(_box('Enter Name'), 'Furnace');
          await pick('Select Type', 'Major System');
          await pick('Select Category', 'HVAC');
          // Installed Date: the date picker, today.
          await tester.ensureVisible(_box('Select Installed Date'));
          await tester.pump();
          await tester.tap(_box('Select Installed Date'), warnIfMissed: false);
          await _settle(tester, 10);
          await tester.tap(find.text('OK'));
          await _settle(tester, 10);
          expect(
              tester
                  .widget<TextField>(_box('Select Installed Date'))
                  .controller!
                  .text,
              isNotEmpty);

          final addFilter = find.widgetWithText(ElevatedButton, 'Add Filter');
          await tester.ensureVisible(addFilter);
          await tester.pump();
          await tester.tap(addFilter);
          await _settle(tester, 10);
          await tester.enterText(_box('Filter Name'), 'MERV 8');

          final save = find.widgetWithText(ElevatedButton, 'Save');
          Future<void> tapSave() async {
            tester
                .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger))
                .clearSnackBars();
            await _settle(tester, 10);
            await tester.ensureVisible(save);
            await tester.pump();
            await tester.tap(save);
            await _settle(tester);
          }

          await tapSave();
          expect(find.text(_message), findsWidgets);
          expect(server.saves, isEmpty, reason: 'no size: refused, like web');

          await tester.enterText(_box('Filter Size (e.g., 16x20x1)'), '16x20x1');
          await tapSave();
          expect(find.text(_message), findsNothing);
          expect(server.saves, ['POST /api/appliance/appliance']);
        }, () => server.client);
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 5));
      } finally {
        FlutterError.onError = original;
      }
    });
  });

  // Filters stay optional, like web (PropDetails.jsx checks them "only if
  // filters are provided"): an HVAC appliance with no filters saves, and
  // other categories are not checked at all.
  final forms = <String, Widget Function(unit_appliance)>{
    'Admin Add': (a) =>
        admin_add.AddApplience(unit: unit_properties(unitId: 'U-1'), appliance: a),
    'Staff Add': (a) =>
        staff_add.AddApplience(unit: unit_properties(unitId: 'U-1'), appliance: a),
    'Admin Edit': (a) => admin_edit.Edit_applience(
        unit: unit_properties(unitId: 'U-1'), appliance: a),
    'Staff Edit': (a) => staff_edit.Edit_applience(
        unit: unit_properties(unitId: 'U-1'), appliance: a),
  };
  final appliances = <String, unit_appliance Function()>{
    'HVAC with no filters': _furnaceWithoutFilters,
    'Refrigerator (not HVAC)': _fridge,
  };

  forms.forEach((name, build) {
    appliances.forEach((kind, appliance) {
      testWidgets('$name: $kind saves as before', (tester) async {
        tester.view.physicalSize = const Size(1080, 6000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        final original = FlutterError.onError;
        FlutterError.onError = (details) {
          if (details.exceptionAsString().contains('overflowed')) return;
          original?.call(details);
        };
        final server = _Server(const [_hvac, _refrigerator]);
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
              child: MaterialApp(home: build(appliance())),
            ));
            await _settle(tester);

            expect(_box('Filter Name'), findsNothing, reason: 'no filter rows');
            final save = find.widgetWithText(ElevatedButton, 'Save');
            await tester.ensureVisible(save);
            await tester.pump();
            await tester.tap(save);
            await _settle(tester);

            expect(find.text(_message), findsNothing);
            expect(server.saves, hasLength(1), reason: 'it saves');
          }, () => server.client);
          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(seconds: 5));
        } finally {
          FlutterError.onError = original;
        }
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

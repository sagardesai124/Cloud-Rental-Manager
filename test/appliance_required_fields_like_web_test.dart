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
import 'package:three_zero_two_property/widgets/clearable_date_suffix.dart';

/// Appliance forms (Admin and Staff), like web staging (PropDetails.jsx: the
/// form's schema requires only Type and Category, plus a custom brand when
/// "Other" is picked on a new appliance; the server requires only the
/// category). Before:
/// - Edit Home Systems (Units tab) also required Name, Description,
///   Installed Date, Brand and Status;
/// - Add/Edit Infrastructure also required Name, Installed Date and Status
///   (Staff did not require Type), and the custom brand when editing too.
/// Installed Date is optional now, so its picker offers Clear like the other
/// dates, and its label and the name's lose the "*".

const _message = 'Please fill in all fields correctly.';
const _fridgeCategory = {
  'category_id': 'C-R',
  'name': 'Refrigerator',
  'brands': ['LG']
};

class _Server {
  final List<String> saves = [];
  final List<Map<String, String>> bodies = [];
  late final MockClient client = MockClient((request) async {
    final path = request.url.path;
    Object body = {'statusCode': 200, 'data': []};
    if ((request.method == 'POST' || request.method == 'PUT') &&
        path.startsWith('/api/appliance/appliance')) {
      saves.add('${request.method} $path');
      bodies.add(Map.of(request.bodyFields));
      body = {'statusCode': 200, 'message': 'Appliance saved'};
    } else if (path.contains('/api/settings/allCategories/')) {
      body = {
        'statusCode': 200,
        'data': [_fridgeCategory]
      };
    }
    return http.Response(jsonEncode(body), 200,
        headers: {'content-type': 'application/json'});
  });
}

Finder _box(String hint) => find.byWidgetPredicate(
    (w) => w is TextField && w.decoration?.hintText == hint);

Future<void> _settle(WidgetTester tester, [int ticks = 30]) async {
  for (var i = 0; i < ticks; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Shows [screen], runs [body] while the fake server answers.
Future<void> _run(WidgetTester tester, Widget screen, _Server server,
    Future<void> Function() body) async {
  tester.view.physicalSize = const Size(1080, 6000);
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
        child: MaterialApp(home: screen),
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

Future<void> _tapSave(WidgetTester tester) async {
  final save = find.widgetWithText(ElevatedButton, 'Save');
  await tester.ensureVisible(save);
  await tester.pump();
  await tester.tap(save);
  await _settle(tester);
}

Future<void> _pick(WidgetTester tester, String hint, String option) async {
  await tester.ensureVisible(find.text(hint));
  await tester.pump();
  await tester.tap(find.text(hint));
  await _settle(tester, 10);
  await tester.tap(find.text(option).last);
  await _settle(tester, 10);
}

/// The Installed Date box offers Clear, like the other optional dates.
void _expectInstalledDateClearable(WidgetTester tester) {
  final controller =
      tester.widget<TextField>(_box('Select Installed Date')).controller;
  expect(
      find.byWidgetPredicate(
          (w) => w is ClearableDateSuffix && w.controller == controller),
      findsOneWidget,
      reason: 'Installed Date can be cleared');
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

  final unit = unit_properties(unitId: 'U-1', rentalId: 'R-1');
  final editHomeSystems = <String, Widget Function(unit_appliance)>{
    'Admin': (a) => admin_edit.Edit_applience(unit: unit, appliance: a),
    'Staff': (a) => staff_edit.Edit_applience(unit: unit, appliance: a),
  };
  final addInfrastructure = <String, Widget Function([unit_appliance?])>{
    'Admin': ([a]) => admin_add.AddApplience(unit: unit, appliance: a),
    'Staff': ([a]) => staff_add.AddApplience(unit: unit, appliance: a),
  };

  editHomeSystems.forEach((role, build) {
    testWidgets(
        '$role Edit Home Systems: saves with only Type and Category, like web',
        (tester) async {
      final server = _Server();
      // Saved on web with no name, description, date, brand or status.
      await _run(
          tester,
          build(unit_appliance(applianceId: 'A-1', categoryId: 'C-R')),
          server, () async {
        _expectInstalledDateClearable(tester);
        await _tapSave(tester);
        expect(find.text(_message), findsNothing);
        expect(server.saves, ['PUT /api/appliance/appliance/A-1']);
        expect(server.bodies.single['category_id'], 'C-R');
      });
    });
  });

  addInfrastructure.forEach((role, build) {
    testWidgets('$role Add Infrastructure: only Type and Category, like web',
        (tester) async {
      final server = _Server();
      await _run(tester, build(), server, () async {
        // Web's labels: no "*" on the name and Installed Date.
        expect(find.text('Infrastructure Name'), findsOneWidget);
        expect(find.text('Installed Date'), findsOneWidget);
        expect(find.text('Infrastructure Name *'), findsNothing);
        expect(find.text('Installed Date *'), findsNothing);
        expect(find.text('Type *'), findsOneWidget);
        expect(find.text('Category *'), findsOneWidget);
        _expectInstalledDateClearable(tester);

        // Nothing picked: refused, Type and Category are still required.
        await _tapSave(tester);
        expect(find.text(_message), findsOneWidget);
        expect(server.saves, isEmpty);

        // Type and Category only: it saves (no name, no Installed Date).
        await _pick(tester, 'Select Type', 'Appliance');
        await _pick(tester, 'Select Category', 'Refrigerator');
        await _tapSave(tester);
        expect(server.saves, ['POST /api/appliance/appliance']);
        expect(server.bodies.single['installed_date'], '');
        expect(server.bodies.single['category_id'], 'C-R');
      });
    });

    // Like web, the three dates are independent: Warranty Expiry opens
    // without an Installed Date, and a warranty earlier than the Installed
    // Date saves (web has no order rule).
    testWidgets('$role Add Infrastructure: dates are independent, like web',
        (tester) async {
      final server = _Server();
      await _run(tester, build(), server, () async {
        await _pick(tester, 'Select Type', 'Appliance');
        await _pick(tester, 'Select Category', 'Refrigerator');

        await tester.ensureVisible(_box('Select Warranty Expiry'));
        await tester.pump();
        await tester.tap(_box('Select Warranty Expiry'));
        await _settle(tester, 10);
        expect(find.text('Please select Installed Date first'), findsNothing);
        expect(find.text('OK'), findsOneWidget, reason: 'the picker opened');
        await tester.tap(find.text('Cancel').last); // the picker's
        await _settle(tester, 10);

        String? field(String hint) =>
            tester.widget<TextField>(_box(hint)).controller!.text;
        tester.widget<TextField>(_box('Select Installed Date')).controller!
            .text = '2026-02-01';
        tester.widget<TextField>(_box('Select Warranty Expiry')).controller!
            .text = '2026-01-01';
        await tester.pump();
        expect(field('Select Warranty Expiry'), '2026-01-01');
        await _tapSave(tester);
        expect(find.text('Please correct the date validation errors'),
            findsNothing);
        expect(server.saves, ['POST /api/appliance/appliance']);
        expect(server.bodies.single['installed_date'], '2026-02-01');
        expect(server.bodies.single['warranty_expiry'], '2026-01-01');
      });
    });

    testWidgets(
        '$role Add Infrastructure: "Other" brand needs its name on a new one',
        (tester) async {
      final server = _Server();
      await _run(tester, build(), server, () async {
        await _pick(tester, 'Select Type', 'Appliance');
        await _pick(tester, 'Select Category', 'Refrigerator');
        await _pick(tester, 'Select Brand', 'Other');
        await _tapSave(tester);
        expect(server.saves, isEmpty, reason: 'custom brand missing');
        await tester.enterText(_box('Enter custom brand name'), 'Acme');
        await _tapSave(tester);
        expect(server.saves, ['POST /api/appliance/appliance']);
        expect(server.bodies.single['brand'], 'Acme');
      });
    });

    testWidgets(
        '$role Edit Infrastructure: an "Other" brand left empty saves, like web',
        (tester) async {
      final server = _Server();
      await _run(
          tester,
          build(unit_appliance(
              applianceId: 'A-1',
              applianceName: 'Fridge',
              categoryId: 'C-R',
              brand: 'Acme', // not in the list: shown as Other + "Acme"
              status: 'Working',
              installedDate: '2026-01-15')),
          server, () async {
        await tester.enterText(_box('Enter custom brand name'), '');
        await _tapSave(tester);
        expect(find.text(_message), findsNothing);
        expect(server.saves, ['PUT /api/appliance/appliance/A-1']);
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

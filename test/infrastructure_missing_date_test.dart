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
import 'package:three_zero_two_property/StaffModule/screen/Rental/Properties/infrastracture.dart'
    as staff_infra;
import 'package:three_zero_two_property/model/properties.dart';
import 'package:three_zero_two_property/model/unitsummery_propeties.dart';
import 'package:three_zero_two_property/provider/dateProvider.dart';
import 'package:three_zero_two_property/provider/notification_provider.dart';
import 'package:three_zero_two_property/screens/Rental/Properties/infrastracture.dart'
    as admin_infra;

/// The property Infrastructure list (Admin and Staff). On web an appliance
/// can be saved without an Installed Date (or a description), and web shows
/// "N/A" for it. Before, the wide table crashed on such an appliance (it
/// used `!` on the date, name and description) and the phone card showed a
/// blank date. Existing dates must look exactly as before.
///
/// Also like web: a missing category shows "N/A" on the phone card (it showed
/// "null"), and switching to another unit starts the list on page 1 (the
/// wide table stayed on page 2 and crashed when the new unit had fewer rows).

const _furnace = {
  'appliance_id': 'A-2',
  'appliance_name': 'Furnace',
  'appliance_description': 'Main unit',
  'installed_date': '2025-10-01',
  'category_id': 'C-H',
  'category_name': 'HVAC',
  'brand': 'Carrier',
  'status': 'Working',
};

// Saved on web without an Installed Date or a description.
const _heater = {
  'appliance_id': 'A-3',
  'appliance_name': 'Water heater',
  'category_id': 'C-W',
  'category_name': 'Water Heater',
  'status': 'Working',
};

// Saved without a category.
const _boiler = {
  'appliance_id': 'A-4',
  'appliance_name': 'Boiler',
  'installed_date': '2025-10-01',
  'status': 'Working',
};

class _Server {
  _Server(this.appliances, [this.secondUnit = const []]);
  final List<Map<String, Object>> appliances;
  final List<Map<String, Object>> secondUnit;
  late final MockClient client = MockClient((request) async {
    Object body = {'statusCode': 200, 'data': []};
    if (request.method == 'GET' &&
        request.url.path.endsWith('/appliance/appliance/U-1')) {
      body = {'statusCode': 200, 'data': appliances};
    } else if (request.method == 'GET' &&
        request.url.path.endsWith('/appliance/appliance/U-2')) {
      body = {'statusCode': 200, 'data': secondUnit};
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

Future<void> _pumpList(WidgetTester tester, Widget Function() build,
    _Server server,
    {required double width, required Future<void> Function() body}) async {
  await _pumpListOf(tester, build, server, width: width, body: body);
}

Future<void> _pumpListOf(WidgetTester tester, Widget Function() build,
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

Finder get _arrows => find.byWidgetPredicate(
    (w) => w is FaIcon && w.icon == FontAwesomeIcons.sortDown);

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
  final screens = <String, Widget Function()>{
    'Admin': () => admin_infra.InfrastructurePart(
        units: [unit], properties: Rentals(rentalId: 'R-1')),
    'Staff': () => staff_infra.InfrastructurePart(
        units: [unit], properties: Rentals(rentalId: 'R-1')),
  };

  _unitSwitchTests();
  _unitsReplacedTest();

  screens.forEach((role, build) {
    testWidgets('$role: wide list shows N/A for a missing date, no crash',
        (tester) async {
      await _pumpList(tester, build, _Server(const [_furnace, _heater]),
          width: 1200, body: () async {
        expect(tester.takeException(), isNull);
        expect(find.text('Water heater'), findsOneWidget);
        expect(find.text('N/A'), findsOneWidget,
            reason: 'the heater has no Installed Date, like web');
        expect(find.text('10/01/2025'), findsOneWidget,
            reason: 'the furnace date looks as before');
      });
    });

    testWidgets('$role: phone card shows N/A for a missing date',
        (tester) async {
      await _pumpList(tester, build, _Server(const [_furnace, _heater]),
          width: 400, body: () async {
        expect(_arrows, findsNWidgets(2));
        await tester.tap(_arrows.at(1)); // open the heater
        await _settle(tester, 10);
        expect(find.textContaining('N/A', findRichText: true), findsWidgets);
        expect(find.textContaining('null', findRichText: true), findsNothing);
      });
    });

    testWidgets('$role: phone card shows N/A for a missing category, not "null"',
        (tester) async {
      await _pumpList(tester, build, _Server(const [_boiler]), width: 400,
          body: () async {
        await tester.tap(_arrows.first);
        await _settle(tester, 10);
        expect(find.text('N/A'), findsOneWidget, reason: 'Category, like web');
        expect(find.textContaining('null', findRichText: true), findsNothing);
      });
    });

    // Must pass before AND after the fix: a full appliance looks the same.
    testWidgets('$role: phone card shows a full appliance the same as before',
        (tester) async {
      await _pumpList(tester, build, _Server(const [_furnace]), width: 400,
          body: () async {
        await tester.tap(_arrows.first);
        await _settle(tester, 10);
        final shown = DateProvider().formatCurrentDate('10/01/2025');
        expect(find.textContaining(shown, findRichText: true), findsWidgets);
        expect(find.textContaining('N/A', findRichText: true), findsNothing);
      });
    });
  });
}

/// Eleven appliances: two pages of 10 on the wide table.
final _eleven = [
  for (var i = 1; i <= 11; i++)
    <String, Object>{
      'appliance_id': 'A1-$i',
      'appliance_name': 'Item $i',
      'appliance_description': 'Unit A1',
      'installed_date': '2025-10-01',
      'category_id': 'C-H',
      'category_name': 'HVAC',
      'status': 'Working',
    }
];

void _unitSwitchTests() {
  final units = [
    unit_properties(unitId: 'U-1', rentalId: 'R-1', rentalunit: 'A1'),
    unit_properties(unitId: 'U-2', rentalId: 'R-1', rentalunit: 'B2'),
  ];
  final screens = <String, Widget Function()>{
    'Admin': () => admin_infra.InfrastructurePart(
        units: units, properties: Rentals(rentalId: 'R-1')),
    'Staff': () => staff_infra.InfrastructurePart(
        units: units, properties: Rentals(rentalId: 'R-1')),
  };
  screens.forEach((role, build) {
    testWidgets('$role: wide list starts on page 1 after a unit switch',
        (tester) async {
      await _pumpListOf(tester, build, _Server(_eleven, const [_furnace]),
          width: 1200, body: () async {
        expect(find.text('Page 1 of 2'), findsOneWidget);
        await tester.tap(find.byWidgetPredicate((w) =>
            w is FaIcon && w.icon == FontAwesomeIcons.circleChevronRight));
        await _settle(tester, 10);
        expect(find.text('Page 2 of 2'), findsOneWidget);

        await tester.tap(find.text('A1').first);
        await _settle(tester, 10);
        await tester.tap(find.text('B2').last);
        await _settle(tester, 10);
        expect(tester.takeException(), isNull, reason: 'no RangeError');
        expect(find.text('Page 1 of 1'), findsOneWidget);
        expect(find.text('Furnace'), findsOneWidget);
      });
    });
  });
}

/// Staff only: its list also reacts when the screen gets a new units list
/// (Admin has no such path).
void _unitsReplacedTest() {
  testWidgets('Staff: a new units list starts the wide list on page 1',
      (tester) async {
    final units = ValueNotifier<List<unit_properties>>(
        [unit_properties(unitId: 'U-1', rentalId: 'R-1', rentalunit: 'A1')]);
    await _pumpListOf(
        tester,
        () => ValueListenableBuilder<List<unit_properties>>(
            valueListenable: units,
            builder: (_, list, __) => staff_infra.InfrastructurePart(
                units: list, properties: Rentals(rentalId: 'R-1'))),
        _Server(_eleven, const [_furnace]),
        width: 1200, body: () async {
      expect(find.text('Page 1 of 2'), findsOneWidget);
      await tester.tap(find.byWidgetPredicate((w) =>
          w is FaIcon && w.icon == FontAwesomeIcons.circleChevronRight));
      await _settle(tester, 10);
      expect(find.text('Page 2 of 2'), findsOneWidget);

      units.value = [
        unit_properties(unitId: 'U-2', rentalId: 'R-1', rentalunit: 'B2')
      ];
      await _settle(tester, 20);
      expect(tester.takeException(), isNull, reason: 'no RangeError');
      expect(find.text('Page 1 of 1'), findsOneWidget);
      expect(find.text('Furnace'), findsOneWidget);
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

import 'dart:async';
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
import 'package:three_zero_two_property/model/unitsummery_propeties.dart';
import 'package:three_zero_two_property/StaffModule/screen/Rental/Properties/applience/Add_applience.dart'
    as staff;
import 'package:three_zero_two_property/provider/dateProvider.dart';
import 'package:three_zero_two_property/provider/notification_provider.dart';
import 'package:three_zero_two_property/screens/Rental/Properties/applience/Add_applience.dart'
    as admin;

/// QA: Add Appliance opened with an empty Status marked required ("Status *")
/// and Save was blocked until one was picked. Web (PropDetails.jsx, staging
/// and production) starts a new appliance as "Working" and treats Status as
/// optional. Editing (Appliance Summary → Edit opens this same screen)
/// must still show the appliance's saved status.

final _client = MockClient((request) async {
  Object body = {'statusCode': 200, 'data': []};
  if (request.url.path.contains('/api/settings/allCategories/')) {
    body = {
      'statusCode': 200,
      'data': [
        {'category_id': 'C-1', 'name': 'Refrigerator', 'brands': []}
      ]
    };
  }
  return http.Response(jsonEncode(body), 200,
      headers: {'content-type': 'application/json'});
});

Future<void> _pump(WidgetTester tester, Widget screen) async {
  tester.view.physicalSize = const Size(1080, 5000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final permissions = StaffPermissionProvider();
  await permissions.fetchPermissions();
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => DateProvider()),
      ChangeNotifierProvider(create: (_) => NotificationProvider()),
      ChangeNotifierProvider<StaffPermissionProvider>.value(value: permissions),
    ],
    child: MaterialApp(home: screen),
  ));
  for (var i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _run(Future<void> Function() body) async {
  final original = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.exceptionAsString().contains('overflowed')) return;
    original?.call(details);
  };
  try {
    await http.runWithClient(body, () => _client);
  } finally {
    FlutterError.onError = original;
  }
}

Future<void> _finish(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 2));
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

  final screens = <String, Widget Function({unit_appliance? appliance})>{
    // The app always opens this screen from a unit.
    'Admin': ({unit_appliance? appliance}) => admin.AddApplience(
        unit: unit_properties(unitId: 'U-1'), appliance: appliance),
    'Staff': ({unit_appliance? appliance}) => staff.AddApplience(
        unit: unit_properties(unitId: 'U-1'), appliance: appliance),
  };

  screens.forEach((role, build) {
    testWidgets('$role Add: Status starts as Working and is optional',
        (tester) async {
      await _run(() async {
        await _pump(tester, build());
        expect(find.text('Working'), findsOneWidget,
            reason: 'pre-selected like web');
        expect(find.text('Status *'), findsNothing);
        expect(find.text('Status'), findsOneWidget);
        await _finish(tester);
      });
    });

    testWidgets('$role edit (Appliance Summary → Edit): keeps the saved status',
        (tester) async {
      await _run(() async {
        await _pump(
            tester,
            build(
                appliance: unit_appliance(
                    applianceName: 'Fridge',
                    categoryId: 'C-1',
                    status: 'Needs Repair')));
        expect(find.text('Needs Repair'), findsOneWidget);
        expect(find.text('Working'), findsNothing);
        await _finish(tester);
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

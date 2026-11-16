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
import 'package:three_zero_two_property/StaffModule/screen/Rental/Properties/applience/edit_appliences.dart'
    as staff_edit;
import 'package:three_zero_two_property/model/unitsummery_propeties.dart';
import 'package:three_zero_two_property/provider/dateProvider.dart';
import 'package:three_zero_two_property/provider/notification_provider.dart';
import 'package:three_zero_two_property/screens/Rental/Properties/applience/edit_appliences.dart'
    as admin_edit;

/// Edit Appliance (Admin and Staff, opened from the appliance parts screen)
/// saves an appliance with no Warranty Expiry, no Last Maintenance Date and
/// no photo, like web staging (PropDetails.jsx sends those dates as "" and
/// leaves the photo out). Before, they went out as nulls in the form body,
/// which can't be encoded: the save stopped with "type 'Null' is not a
/// subtype of type 'String'".

class _Server {
  final List<Map<String, String>> saves = [];
  late final MockClient client = MockClient((request) async {
    final path = request.url.path;
    Object body = {'statusCode': 200, 'data': []};
    if (request.method == 'PUT' && path == '/api/appliance/appliance/A-1') {
      saves.add(Map.of(request.bodyFields));
      body = {'statusCode': 200, 'message': 'Appliance updated'};
    } else if (path.contains('/api/settings/allCategories/')) {
      body = {
        'statusCode': 200,
        'data': [
          {'category_id': 'C-1', 'name': 'Refrigerator', 'brands': ['LG']}
        ]
      };
    }
    return http.Response(jsonEncode(body), 200,
        headers: {'content-type': 'application/json'});
  });
}

unit_appliance _fridge() => unit_appliance(
      applianceId: 'A-1',
      applianceName: 'Fridge',
      applianceDescription: 'Kitchen',
      categoryId: 'C-1',
      status: 'Working',
      brand: 'LG',
      installedDate: '2026-01-15',
      // No warranty, no maintenance date, no photo.
    );

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
    'Admin': () => admin_edit.Edit_applience(
        unit: unit_properties(unitId: 'U-1'), appliance: _fridge()),
    'Staff': () => staff_edit.Edit_applience(
        unit: unit_properties(unitId: 'U-1'), appliance: _fridge()),
  };

  screens.forEach((role, build) {
    testWidgets('$role Edit: saves with no warranty, maintenance date or photo',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 6000);
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
            child: MaterialApp(home: build()),
          ));
          await _settle(tester);

          final save = find.widgetWithText(ElevatedButton, 'Save');
          await tester.ensureVisible(save);
          await tester.pump();
          await tester.tap(save);
          await _settle(tester);

          expect(find.textContaining("type 'Null'"), findsNothing);
          expect(server.saves, hasLength(1), reason: 'the update is sent');
          final fields = server.saves.single;
          expect(fields['warranty_expiry'], '');
          expect(fields['last_maintenance_date'], '');
          expect(fields.containsKey('appliance_image'), isFalse,
              reason: 'no photo field, like web');
          expect(fields['appliance_name'], 'Fridge');
        }, () => server.client);
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 5));
      } finally {
        FlutterError.onError = original;
      }
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

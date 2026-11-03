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
import 'package:three_zero_two_property/StaffModule/repository/staffpermission_provider.dart';
import 'package:three_zero_two_property/StaffModule/screen/Maintenance/Workorder/Add_workorder.dart'
    as staff_add;
import 'package:three_zero_two_property/StaffModule/screen/Maintenance/Workorder/Edit_workorders.dart'
    as staff_edit;
import 'package:three_zero_two_property/provider/Plan%20Purchase/plancheckProvider.dart';
import 'package:three_zero_two_property/provider/dateProvider.dart';
import 'package:three_zero_two_property/provider/notification_provider.dart';
import 'package:three_zero_two_property/screens/Maintenance/Workorder/Add_workorder.dart'
    as admin_add;
import 'package:three_zero_two_property/screens/Maintenance/Workorder/Edit_workorders.dart'
    as admin_edit;

/// Add / Edit Work Order (Admin and Staff, phone and wide layouts) label the
/// parts section "Parts and Labor" and the notes field "Vendor Notes", like
/// web staging's AddWorkorder.jsx (which both roles open for add and edit).
/// Staff's phone forms read "Parts And Labour :" / "Vendors Note"; every wide
/// form read "Parts And Labour" / "Vendors Note *" (the field is optional, as
/// on web, so no star).

/// No category, vendor or staff picked: the fake server returns no lists for
/// them, and a dropdown value missing from its list would stop the form. The
/// property is required by the Edit forms, so the server lists it.
final _workOrder = {
  'workOrder_id': 'WO-1',
  'ticket_number': '1001',
  'admin_id': 'ADMIN-1',
  'work_subject': 'Leaky tap',
  'status': 'In Progress',
  'priority': 'High',
  'date': '2026-10-30',
  'entry_allowed': true,
  'is_billable': false,
  'rental_id': 'P-1',
  'vendor_id': '',
  'staff_data': {'_id': 'S-1', 'firstname': 'Pat', 'lastname': 'Staff'},
  'property_data': {
    '_id': 'P-1',
    'property_name': 'Main St',
    'rental_adress': '123 Main St',
    'rental_city': 'Austin',
    'rental_state': 'TX',
    'rental_country': 'USA',
    'rental_postcode': '73301',
    'rental_image': '',
  },
  'unit_data': {
    '_id': 'U-1',
    'rental_unit_adress': '123 Main St',
    'rental_unit': 'A1',
    'unit_id': 'U-1',
  },
  'vendor_data': {'_id': 'V-1', 'vendor_name': 'Fixit Co'},
  'tenant_data': {'_id': 'T-1', 'tenant_firstName': 'Ruth', 'tenant_lastName': 'Moss'},
  'work_performed': 'Unit',
  'vendor_notes': '',
  'workorder_updates': [],
  'partsandcharge_data': [],
  'workOrder_images': [],
};

final _server = MockClient((request) async {
  Object body = {'statusCode': 200, 'data': []};
  final path = request.url.path;
  if (path.startsWith('/api/work-order/workorder_details/')) {
    body = {'statusCode': 200, 'data': _workOrder};
  } else if (path.startsWith('/api/rentals/rentals/')) {
    body = {
      'statusCode': 200,
      'data': [
        {'rental_id': 'P-1', 'rental_adress': '123 Main St'}
      ]
    };
  }
  return http.Response(jsonEncode(body), 200,
      headers: {'content-type': 'application/json'});
});

Future<void> _settle(WidgetTester tester, [int ticks = 40]) async {
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
  });

  Future<void> check(WidgetTester tester, Widget form, String role,
      {required bool wide}) async {
    tester.view.physicalSize = Size(wide ? 800 : 430, 9000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({
      'token': 'tkn',
      'adminId': 'ADMIN-1',
      'staff_id': 'S-1',
      'role': role,
    });
    final original = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('overflowed')) return;
      original?.call(details);
    };
    try {
      await http.runWithClient(() async {
        await tester.pumpWidget(MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => DateProvider()),
            ChangeNotifierProvider(create: (_) => NotificationProvider()),
            ChangeNotifierProvider(create: (_) => checkPlanPurchaseProiver()),
            ChangeNotifierProvider(create: (_) => StaffPermissionProvider()),
          ],
          child: MaterialApp(home: Scaffold(body: form)),
        ));
        await _settle(tester);

        // Web's wording; the phone layout keeps its " :" style (like the
        // Admin phone form), and the wide layout has no star on the notes.
        expect(find.text(wide ? 'Parts and Labor ' : 'Parts and Labor :'),
            findsOneWidget);
        expect(find.text(wide ? 'Vendor Notes' : 'Vendor Notes '),
            findsOneWidget);
        expect(find.textContaining('Parts And Labour'), findsNothing);
        expect(find.textContaining('Vendors Note'), findsNothing);
      }, () => _server);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    } finally {
      FlutterError.onError = original;
    }
  }

  testWidgets('Admin Add, phone', (t) async =>
      check(t, admin_add.AddWorkOrderForMobile(), 'Admin', wide: false));
  testWidgets('Admin Add, wide', (t) async =>
      check(t, admin_add.AddWorkOrderForTablet(), 'Admin', wide: true));
  testWidgets('Admin Edit, phone', (t) async => check(
      t, admin_edit.EditWorkOrderForMobile(workorderId: 'WO-1'), 'Admin',
      wide: false));
  testWidgets('Admin Edit, wide', (t) async => check(
      t, admin_edit.EditWorkOrderForTablet(workorderId: 'WO-1'), 'Admin',
      wide: true));
  testWidgets('Staff Add, phone', (t) async =>
      check(t, staff_add.AddWorkOrderForMobile(), 'Staffmember', wide: false));
  testWidgets('Staff Add, wide', (t) async =>
      check(t, staff_add.AddWorkOrderForTablet(), 'Staffmember', wide: true));
  testWidgets('Staff Edit, phone', (t) async => check(
      t, staff_edit.EditWorkOrderForMobile(workorderId: 'WO-1'), 'Staffmember',
      wide: false));
  testWidgets('Staff Edit, wide', (t) async => check(
      t, staff_edit.EditWorkOrderForTablet(workorderId: 'WO-1'), 'Staffmember',
      wide: true));
}

class _OnlineConnectivity extends ConnectivityPlatform
    with MockPlatformInterfaceMixin {
  @override
  Future<ConnectivityResult> checkConnectivity() async =>
      ConnectivityResult.wifi;
  @override
  Stream<ConnectivityResult> get onConnectivityChanged => const Stream.empty();
}

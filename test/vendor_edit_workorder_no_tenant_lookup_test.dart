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
import 'package:three_zero_two_property/VendorModule/screen/work_order/Edit_workorders.dart';
import 'package:three_zero_two_property/provider/dateProvider.dart';
import 'package:three_zero_two_property/provider/notification_provider.dart';

/// Vendor → Work Orders → Edit opens without looking up the property's
/// tenants, like web staging (the vendor form never asks for them; the server
/// keeps GET /api/leases/get_tenants to Admin/Staff and refuses a vendor).
/// Before, every open made that request and showed "Failed to fetch tenants:
/// Failed to load data". Saving still sends the work order's own tenant.

final _workOrder = {
  'workOrder_id': 'WO-1',
  'admin_id': 'ADMIN-1',
  'vendor_id': 'V-1',
  'tenant_id': 'T-1',
  'work_subject': 'Leaky tap',
  'work_category': 'Plumbing',
  'work_performed': 'Unit',
  'status': 'In Progress',
  'priority': 'High',
  'date': '2026-10-30',
  'entry_allowed': true,
  'is_billable': true,
  'staffmember_id': 'S-1',
  'rental_id': 'P-1',
  'unit_id': 'U-1',
  'property_data': {
    '_id': 'P-1',
    'property_name': 'Main St',
    'rental_adress': '123 Main St',
    'rental_id': 'P-1',
  },
  'unit_data': {'_id': 'U-1', 'unit_no': 'A1'},
  'staff_data': {
    '_id': 'S-1',
    'staffmember_id': 'S-1',
    'staffmember_name': 'Pat Staff',
    'role': 'staff',
  },
  'vendor_data': {'_id': 'V-1', 'vendor_name': 'Fixit Co', 'vendor_type': 'Plumbing'},
  'tenant_data': {
    '_id': 'T-1',
    'tenant_name': 'Ruth Moss',
    'email': 'ruth@example.com',
    'phone_number': '5551234567',
  },
  'vendor_notes': 'Bring a wrench',
  'workorder_updates': [],
  'partsandcharge_data': [],
  'workOrder_images': [],
};

class _Server {
  final List<String> paths = [];
  final List<Map<String, dynamic>> saves = [];

  late final MockClient client = MockClient((request) async {
    final path = request.url.path;
    paths.add(path);
    Object body = {'statusCode': 200, 'data': []};
    var status = 200;
    if (path.startsWith('/api/leases/get_tenants/')) {
      // What staging answers a vendor.
      status = 403;
      body = {'statusCode': 403, 'message': 'Forbidden'};
    } else if (request.method == 'PUT' &&
        path == '/api/work-order/work-order/WO-1') {
      saves.add(jsonDecode(request.body) as Map<String, dynamic>);
      body = {'statusCode': 200, 'message': 'Work Order updated'};
    } else if (path == '/api/auth') {
      body = {
        'statusCode': 200,
        'themes': {'format': 'MM/DD/YYYY', 'timeFormat': '12'}
      };
    } else if (path.startsWith('/api/work-order/workorder_details/')) {
      body = {'statusCode': 200, 'data': _workOrder};
    } else if (path.startsWith('/api/settings/allCategories/')) {
      body = {
        'statusCode': 200,
        'data': [
          {'category_id': 'C-1', 'name': 'Plumbing', 'brands': []},
        ]
      };
    } else if (path.startsWith('/api/unit/rental_unit/')) {
      body = {
        'statusCode': 200,
        'data': [
          {'unit_id': 'U-1', 'rental_unit': 'A1'}
        ]
      };
    }
    return http.Response(jsonEncode(body), status,
        headers: {'content-type': 'application/json'});
  });
}

Future<void> _settle(WidgetTester tester, [int ticks = 50]) async {
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
      'vendor_id': 'V-1',
      'role': 'Vendor',
    });
  });

  Future<void> check(WidgetTester tester, double width) async {
    tester.view.physicalSize = Size(width, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final original = FlutterError.onError;
    FlutterError.onError = (details) {
      // The test font draws every glyph as a full em square, so dense rows
      // overflow at phone width; that layout noise is ignored.
      if (details.exceptionAsString().contains('overflowed')) return;
      original?.call(details);
    };
    final server = _Server();
    try {
      await http.runWithClient(() async {
        final dates = DateProvider();
        await dates.loadDateFormat();
        await tester.pumpWidget(MultiProvider(
          providers: [
            ChangeNotifierProvider<DateProvider>.value(value: dates),
            ChangeNotifierProvider(create: (_) => NotificationProvider()),
          ],
          child: MaterialApp(home: Edit_Workorder(workorderId: 'WO-1')),
        ));
        await _settle(tester);

        // The work order loaded, without any tenant lookup or message.
        expect(find.text('Leaky tap'), findsWidgets);
        expect(
            server.paths.where((p) => p.startsWith('/api/leases/get_tenants/')),
            isEmpty,
            reason: 'like web, the vendor form never asks for tenants');
        expect(find.textContaining('Failed to fetch tenants'), findsNothing);
        expect(find.text('Tenant'), findsNothing, reason: 'no Tenant field, like web');

        // Saving still sends the work order's own tenant.
        final notes = find.byWidgetPredicate(
            (w) => w is EditableText && w.controller.text == 'Bring a wrench');
        await tester.ensureVisible(notes);
        await tester.pump();
        await tester.enterText(notes, 'Bring two wrenches');
        await _settle(tester, 10);
        final update = find.ancestor(
            of: find.text('Update Work Order'),
            matching: find.byWidgetPredicate((w) => w is ButtonStyleButton));
        await tester.ensureVisible(update);
        await tester.pump();
        await tester.tap(update);
        await _settle(tester);
        expect(server.saves, hasLength(1));
        final workOrder = server.saves.single['workOrder'] as Map;
        expect(workOrder['tenant_id'], 'T-1');
        expect(workOrder['vendor_notes'], 'Bring two wrenches');
      }, () => server.client);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    } finally {
      FlutterError.onError = original;
    }
  }

  testWidgets('phone layout: opens and saves without a tenant lookup',
      (tester) => check(tester, 430));
  testWidgets('wide layout: opens and saves without a tenant lookup',
      (tester) => check(tester, 900));
}

class _OnlineConnectivity extends ConnectivityPlatform
    with MockPlatformInterfaceMixin {
  @override
  Future<ConnectivityResult> checkConnectivity() async =>
      ConnectivityResult.wifi;
  @override
  Stream<ConnectivityResult> get onConnectivityChanged => const Stream.empty();
}

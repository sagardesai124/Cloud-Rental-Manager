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
import 'package:three_zero_two_property/TenantsModule/repository/permission_provider.dart';
import 'package:three_zero_two_property/TenantsModule/screen/work_order/edit_workorder.dart'
    as tenant_edit;
import 'package:three_zero_two_property/TenantsModule/screen/work_order/workorder_summery.dart'
    as tenant;
import 'package:three_zero_two_property/VendorModule/repository/vendor_permission.dart';
import 'package:three_zero_two_property/VendorModule/screen/work_order/Edit_workorders.dart'
    as vendor_edit;
import 'package:three_zero_two_property/VendorModule/screen/work_order/workorder_summery.dart'
    as vendor;
import 'package:three_zero_two_property/provider/Plan%20Purchase/plancheckProvider.dart';
import 'package:three_zero_two_property/provider/dateProvider.dart';
import 'package:three_zero_two_property/provider/notification_provider.dart';

/// Like web WorkOrderDetails, the Tenant and Vendor Work Order details screen
/// shows an Edit pencil next to "Work Order : #N" only with Work Orders → Edit
/// permission, and the pencil opens that role's Edit Work Order form.
///
/// Also like web (live staging), "Address: <property address>" shows under
/// the work order number, above the tabs, and "Address: N/A" when the
/// property has no address.

final _workOrder = {
  'workOrder_id': 'WO-1',
  'ticket_number': '1001',
  'admin_id': 'ADMIN-1',
  'work_subject': 'Leaky tap',
  'work_category': 'Plumbing',
  'status': 'In Progress',
  'priority': 'High',
  'date': '2026-10-30',
  'entry_allowed': true,
  'property_data': {
    '_id': 'P-1',
    'rental_adress': '123 Main St',
    'rental_image': '',
  },
  'unit_data': {'_id': 'U-1', 'rental_unit': 'A1', 'unit_id': 'U-1'},
  'vendor_data': {'_id': 'V-1', 'vendor_name': 'Fixit Co'},
  'tenant_data': {'_id': 'T-1', 'tenant_firstName': 'Ruth', 'tenant_lastName': 'Moss'},
  'work_performed': 'Unit',
  'vendor_notes': '',
  'workorder_updates': [],
  'partsandcharge_data': [],
  'workOrder_images': [],
};

MockClient _server(bool canEdit, {String address = '123 Main St'}) =>
    MockClient((request) async {
      final path = request.url.path;
      Object body = {'statusCode': 200, 'data': []};
      if (path.startsWith('/api/work-order/workorder_details/')) {
        body = {
          'statusCode': 200,
          'data': {
            ..._workOrder,
            'property_data': {
              ...(_workOrder['property_data'] as Map),
              'rental_adress': address,
            },
          },
        };
      } else if (path.startsWith('/api/permission/permission/')) {
        final perms = {
          'property_view': true,
          'financial_view': true,
          'financial_add': true,
          'financial_edit': true,
          'workorder_view': true,
          'workorder_add': true,
          'workorder_edit': canEdit,
          'documents_view': true,
          'documents_add': true,
          'documents_edit': true,
        };
        body = {
          'statusCode': 200,
          'data': {'tenant_permission': perms, 'vendor_permission': perms},
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

final _pencil = find.byKey(const Key('workorder_details_edit_pencil'));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('PonnamKarthik/fluttertoast'), (_) async => true);
    ConnectivityPlatform.instance = _OnlineConnectivity();
  });

  Future<void> open(WidgetTester tester, String role, bool canEdit,
      {Type? editScreen, String address = '123 Main St'}) async {
    tester.view.physicalSize = const Size(390, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({
      'token': 'tkn',
      'adminId': 'ADMIN-1',
      'tenant_id': 'T-1',
      'vendor_id': 'V-1',
      'role': role,
    });
    final original = FlutterError.onError;
    // Layout warnings from other rows are not this test's concern.
    FlutterError.onError = (d) {
      if (d.exceptionAsString().contains('overflowed')) return;
      original?.call(d);
    };
    try {
      await http.runWithClient(() async {
        final dates = DateProvider();
        await dates.loadDateFormat();
        final tenantPerms = PermissionProvider();
        await tenantPerms.fetchPermissions();
        final vendorPerms = VendorPermission();
        await vendorPerms.fetchPermissions();
        await tester.pumpWidget(MultiProvider(
          providers: [
            ChangeNotifierProvider<DateProvider>.value(value: dates),
            ChangeNotifierProvider(create: (_) => NotificationProvider()),
            ChangeNotifierProvider(create: (_) => checkPlanPurchaseProiver()),
            ChangeNotifierProvider<VendorPermission>.value(value: vendorPerms),
            ChangeNotifierProvider<PermissionProvider>.value(value: tenantPerms),
          ],
          child: MaterialApp(
            home: role == 'Tenant'
                ? tenant.Workorder_summery(workorder_id: 'WO-1')
                : vendor.Workorder_summery(workorder_id: 'WO-1'),
          ),
        ));
        await _settle(tester);

        expect(find.text('Work Order : #1001'), findsOneWidget);
        // The address line, under the number and above the tabs, like web.
        final addressLine =
            find.text('Address: ${address.isEmpty ? 'N/A' : address}');
        expect(addressLine, findsOneWidget, reason: role);
        expect(tester.getTopLeft(addressLine).dy,
            greaterThan(tester.getTopLeft(find.text('Work Order : #1001')).dy));
        expect(tester.getTopLeft(addressLine).dy,
            lessThan(tester.getTopLeft(find.text('Summary').first).dy));
        expect(_pencil, canEdit ? findsOneWidget : findsNothing,
            reason: '$role edit=$canEdit');

        if (canEdit && editScreen != null) {
          await tester.tap(_pencil);
          await _settle(tester, 60);
          expect(find.byType(editScreen), findsOneWidget,
              reason: '$role pencil opens Edit Work Order');
        }
      }, () => _server(canEdit, address: address));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    } finally {
      FlutterError.onError = original;
    }
  }

  testWidgets('Tenant with edit permission sees the pencil and it opens Edit',
      (t) => open(t, 'Tenant', true, editScreen: tenant_edit.Edit_Workorder));
  testWidgets('Tenant without edit permission sees no pencil',
      (t) => open(t, 'Tenant', false));
  testWidgets('Vendor with edit permission sees the pencil and it opens Edit',
      (t) => open(t, 'Vendor', true, editScreen: vendor_edit.Edit_Workorder));
  testWidgets('Vendor without edit permission sees no pencil',
      (t) => open(t, 'Vendor', false));
  testWidgets('Tenant: a property with no address shows "Address: N/A"',
      (t) => open(t, 'Tenant', false, address: ''));
  testWidgets('Vendor: a property with no address shows "Address: N/A"',
      (t) => open(t, 'Vendor', false, address: ''));
}

class _OnlineConnectivity extends ConnectivityPlatform
    with MockPlatformInterfaceMixin {
  @override
  Future<ConnectivityResult> checkConnectivity() async =>
      ConnectivityResult.wifi;
  @override
  Stream<ConnectivityResult> get onConnectivityChanged => const Stream.empty();
}

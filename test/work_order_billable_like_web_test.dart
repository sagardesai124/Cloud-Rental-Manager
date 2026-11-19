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
import 'package:three_zero_two_property/services/work_order_billable.dart';

/// Add / Edit Work Order (Admin and Staff, phone and wide): like web staging
/// (AddWorkorder.jsx with utils/workOrderBillable.js), a work order can't be
/// billed to a tenant on a property nobody can be billed for. With Billable
/// To Tenant ticked, the property's (or unit's) tenants are looked up; when
/// that answers with nobody and the work order has no tenant, web's message
/// shows under Billable To Tenant and Save stops. It doesn't block while the
/// lookup is running or after it failed, or an edit that already has its
/// billed tenant. Before, the app only looked tenants up once a unit was
/// picked, so on a property with no units it never did, and Save went
/// through with nobody to bill.

/// What the fake server answers for /api/leases/get_tenants/...
enum _Tenants { none, one, fails }

class _Server {
  _Server({this.tenants = _Tenants.none, this.workOrderTenant = ''});

  final _Tenants tenants;
  final String workOrderTenant;
  final List<String> lookups = [];
  final List<String> writes = [];

  late final MockClient client = MockClient((request) async {
    final path = request.url.path;
    // Work order saves only (the app also posts /api/auth on its own).
    if (request.method != 'GET' && path.contains('work-order')) {
      writes.add('${request.method} $path');
    }
    Object body = {'statusCode': 200, 'data': []};
    var status = 200;
    if (path.startsWith('/api/leases/get_tenants/')) {
      lookups.add(path);
      if (tenants == _Tenants.fails) {
        status = 500;
        body = {'statusCode': 500, 'message': 'Server error'};
      } else if (tenants == _Tenants.one) {
        body = {
          'statusCode': 200,
          'data': [
            {'tenant_id': 'T-9', 'tenant_firstName': 'Ann', 'tenant_lastName': 'Lee'}
          ]
        };
      }
    } else if (path.startsWith('/api/rentals/rentals/')) {
      body = {
        'statusCode': 200,
        'data': [
          {'rental_id': 'P-1', 'rental_adress': '9 Vacant Rd'}
        ]
      };
    } else if (path.startsWith('/api/staffmember/staff_member/')) {
      body = {
        'statusCode': 200,
        'data': [
          {'staffmember_id': 'S-1', 'staffmember_name': 'Pat Staff'}
        ]
      };
    } else if (path.startsWith('/api/work-order/workorder_details/')) {
      body = {
        'statusCode': 200,
        'data': {
          'workOrder_id': 'WO-1',
          'admin_id': 'ADMIN-1',
          'work_subject': 'Leaky tap',
          'status': 'In Progress',
          'priority': 'High',
          'date': '2026-10-30',
          'entry_allowed': true,
          'is_billable': true,
          'work_charge_to': 'Tenant',
          'rental_id': 'P-1',
          'unit_id': '',
          'tenant_id': workOrderTenant,
          'staffmember_id': 'S-1',
          'vendor_id': '',
          'vendor_notes': 'Check the valve',
          'work_performed': 'Unit',
          'workorder_updates': [],
          'partsandcharge_data': [],
          'workOrder_images': [],
        },
      };
    }
    return http.Response(jsonEncode(body), status,
        headers: {'content-type': 'application/json'});
  });
}

Future<void> _settle(WidgetTester tester, [int ticks = 40]) async {
  for (var i = 0; i < ticks; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

final List<String> _toasts = [];

Finder _billableBox() => find.descendant(
      of: find.ancestor(
          of: find.text('Billable To Tenant'), matching: find.byType(Row)),
      matching: find.byType(Checkbox),
    );

Future<_Server> _onForm(WidgetTester tester, Widget form,
    {required bool wide,
    String role = 'Admin',
    _Tenants tenants = _Tenants.none,
    String workOrderTenant = '',
    Future<void> Function(_Server server)? then}) async {
  final server = _Server(tenants: tenants, workOrderTenant: workOrderTenant);
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
      if (then != null) await then(server);
    }, () => server.client);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  } finally {
    FlutterError.onError = original;
  }
  return server;
}

Future<void> _tickBillable(WidgetTester tester) async {
  await tester.ensureVisible(_billableBox());
  await tester.tap(_billableBox());
  await _settle(tester);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    _toasts.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('PonnamKarthik/fluttertoast'),
            (call) async {
      final args = call.arguments;
      if (args is Map && args['msg'] != null) _toasts.add('${args['msg']}');
      return true;
    });
    ConnectivityPlatform.instance = _OnlineConnectivity();
  });

  group("web's rule (utils/workOrderBillable.js)", () {
    bool blocks({
      bool isBillable = true,
      String? rentalId = 'P-1',
      String? tenantId = '',
      TenantLookup lookup = TenantLookup.loaded,
      int tenantCount = 0,
    }) =>
        hasNoBillableTenant(
          isBillable: isBillable,
          rentalId: rentalId,
          tenantId: tenantId,
          lookup: lookup,
          tenantCount: tenantCount,
        );

    test('blocks a billable work order on a property whose lookup returned no tenants',
        () => expect(blocks(), isTrue));
    test('does not block when Billable To Tenant is unticked',
        () => expect(blocks(isBillable: false), isFalse));
    test('does not block before a property is chosen', () {
      expect(blocks(rentalId: null), isFalse);
      expect(blocks(rentalId: '  '), isFalse);
    });
    test('does not block while the tenant lookup is in flight or after it failed', () {
      expect(blocks(lookup: TenantLookup.loading), isFalse);
      expect(blocks(lookup: TenantLookup.idle), isFalse);
    });
    test('does not block when the property has tenants to pick from',
        () => expect(blocks(tenantCount: 1), isFalse));
    test('does not block an edit that already carries its billed tenant',
        () => expect(blocks(tenantId: 'T-1'), isFalse));
    test("web's message", () {
      expect(kNoBillableTenantMessage,
          'This property has no active lease or tenant to bill. Uncheck "Billable To Tenant" to save the work order.');
    });
    test('looks up the unit once one is picked, otherwise the whole property', () {
      expect(tenantLookupPath('P-1', 'U-1'), 'leases/get_tenants/P-1/U-1');
      expect(tenantLookupPath('P-1', ''), 'leases/get_tenants/P-1');
      expect(tenantLookupPath('P-1', null), 'leases/get_tenants/P-1');
    });
  });

  group('on a vacant property, the message shows under Billable To Tenant', () {
    Future<void> addForm(WidgetTester tester, Widget form,
        {required bool wide, String role = 'Admin'}) async {
      await _onForm(tester, form, wide: wide, role: role, then: (server) async {
        expect(find.text(kNoBillableTenantMessage), findsNothing,
            reason: 'not before Billable To Tenant is ticked');
        await _tickBillable(tester);
        expect(server.lookups, ['/api/leases/get_tenants/P-1'],
            reason: 'no unit picked, so the whole property is looked up');
        expect(find.text(kNoBillableTenantMessage), findsOneWidget);

        // Unticking it takes the message away, like web.
        await _tickBillable(tester);
        expect(find.text(kNoBillableTenantMessage), findsNothing);
      });
    }

    Future<void> editForm(WidgetTester tester, Widget form,
        {required bool wide, String role = 'Admin'}) async {
      await _onForm(tester, form, wide: wide, role: role, then: (server) async {
        expect(server.lookups, contains('/api/leases/get_tenants/P-1'));
        expect(find.text(kNoBillableTenantMessage), findsOneWidget);
      });
    }

    testWidgets('Admin Add, phone', (t) async =>
        addForm(t, admin_add.AddWorkOrderForMobile(rentalid: 'P-1'), wide: false));
    testWidgets('Admin Add, wide', (t) async =>
        addForm(t, admin_add.AddWorkOrderForTablet(rentalid: 'P-1'), wide: true));
    testWidgets('Staff Add, phone', (t) async => addForm(
        t, staff_add.AddWorkOrderForMobile(rentalid: 'P-1'),
        wide: false, role: 'Staffmember'));
    testWidgets('Staff Add, wide', (t) async => addForm(
        t, staff_add.AddWorkOrderForTablet(rentalid: 'P-1'),
        wide: true, role: 'Staffmember'));
    testWidgets('Admin Edit, phone', (t) async => editForm(
        t, admin_edit.EditWorkOrderForMobile(workorderId: 'WO-1'), wide: false));
    testWidgets('Admin Edit, wide', (t) async => editForm(
        t, admin_edit.EditWorkOrderForTablet(workorderId: 'WO-1'), wide: true));
    testWidgets('Staff Edit, phone', (t) async => editForm(
        t, staff_edit.EditWorkOrderForMobile(workorderId: 'WO-1'),
        wide: false, role: 'Staffmember'));
    testWidgets('Staff Edit, wide', (t) async => editForm(
        t, staff_edit.EditWorkOrderForTablet(workorderId: 'WO-1'),
        wide: true, role: 'Staffmember'));
  });

  group('no message, like web', () {
    testWidgets('the property has a tenant to bill: the Tenant picker shows',
        (t) async {
      await _onForm(t, admin_add.AddWorkOrderForMobile(rentalid: 'P-1'),
          wide: false, tenants: _Tenants.one, then: (server) async {
        await _tickBillable(t);
        expect(find.text(kNoBillableTenantMessage), findsNothing);
        expect(find.text('Tenant'), findsWidgets);
      });
    });

    testWidgets('the tenant lookup failed: not taken as "nobody"', (t) async {
      await _onForm(t, admin_add.AddWorkOrderForMobile(rentalid: 'P-1'),
          wide: false, tenants: _Tenants.fails, then: (server) async {
        await _tickBillable(t);
        expect(server.lookups, isNotEmpty);
        expect(find.text(kNoBillableTenantMessage), findsNothing);
      });
    });

    for (final staff in [false, true]) {
      testWidgets(
          '${staff ? 'Staff' : 'Admin'} Edit: the work order already has its '
          'billed tenant', (t) async {
        await _onForm(
            t,
            staff
                ? staff_edit.EditWorkOrderForMobile(workorderId: 'WO-1')
                : admin_edit.EditWorkOrderForMobile(workorderId: 'WO-1'),
            wide: false,
            role: staff ? 'Staffmember' : 'Admin',
            workOrderTenant: 'T-1', then: (server) async {
          expect(find.text(kNoBillableTenantMessage), findsNothing);
        });
      });
    }
  });

  group('Save stops with web\'s message and nothing is sent', () {
    Future<void> updateBlocked(WidgetTester tester, Widget form,
        {required bool wide, String role = 'Admin'}) async {
      await _onForm(tester, form, wide: wide, role: role, then: (server) async {
        expect(find.text(kNoBillableTenantMessage), findsOneWidget);
        // A change, so Update Work Order can be tapped.
        await tester.enterText(find.widgetWithText(TextField, 'Leaky tap').first,
            'Leaky tap, kitchen');
        await _settle(tester, 10);
        final update = find.text('Update Work Order').last;
        await tester.ensureVisible(update);
        await tester.tap(update);
        await _settle(tester);

        expect(_toasts, contains(kNoBillableTenantMessage));
        expect(server.writes, isEmpty, reason: 'the work order is not saved');
      });
    }

    testWidgets('Admin Edit, phone', (t) async => updateBlocked(
        t, admin_edit.EditWorkOrderForMobile(workorderId: 'WO-1'), wide: false));
    testWidgets('Admin Edit, wide', (t) async => updateBlocked(
        t, admin_edit.EditWorkOrderForTablet(workorderId: 'WO-1'), wide: true));
    testWidgets('Staff Edit, phone', (t) async => updateBlocked(
        t, staff_edit.EditWorkOrderForMobile(workorderId: 'WO-1'),
        wide: false, role: 'Staffmember'));
    testWidgets('Staff Edit, wide', (t) async => updateBlocked(
        t, staff_edit.EditWorkOrderForTablet(workorderId: 'WO-1'),
        wide: true, role: 'Staffmember'));

    // Control: the same update with the billed tenant on it is sent as before.
    testWidgets('Admin Edit, phone, with its billed tenant: saved as before',
        (t) async {
      await _onForm(t, admin_edit.EditWorkOrderForMobile(workorderId: 'WO-1'),
          wide: false, workOrderTenant: 'T-1', then: (server) async {
        await t.enterText(find.widgetWithText(TextField, 'Leaky tap').first,
            'Leaky tap, kitchen');
        await _settle(t, 10);
        final update = find.text('Update Work Order').last;
        await t.ensureVisible(update);
        await t.tap(update);
        await _settle(t);
        expect(_toasts, isNot(contains(kNoBillableTenantMessage)));
        expect(server.writes, isNotEmpty, reason: 'the update is sent');
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

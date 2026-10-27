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
import 'package:three_zero_two_property/TenantsModule/model/workorder_model.dart';
import 'package:three_zero_two_property/TenantsModule/repository/permission_provider.dart';
import 'package:three_zero_two_property/TenantsModule/screen/work_order/workorder_table.dart';
import 'package:three_zero_two_property/provider/dateProvider.dart';
import 'package:three_zero_two_property/provider/notification_provider.dart';

/// Tenant → Work Orders list: "Assigned" shows the staff name, or "-" when
/// nobody is assigned, like live staging web (TenantWork.jsx label "Assigned",
/// `staffmember_name || "-"`). Before, the phone row read "Assign : N/A", the
/// wide column showed "N/A", and searching "n/a" matched unassigned rows.

final _server = MockClient((request) async {
  Object body = {'statusCode': 200, 'data': []};
  if (request.url.path == '/api/permission/permission/ADMIN-1') {
    // The screen reads permissions!.workorderAdd in build.
    body = {
      'statusCode': 200,
      'data': {
        'tenant_permission': {
          'property_view': true,
          'financial_view': true,
          'financial_add': true,
          'financial_edit': true,
          'workorder_view': true,
          'workorder_add': true,
          'workorder_edit': true,
          'documents_view': true,
          'documents_add': true,
          'documents_edit': true,
        }
      }
    };
  } else if (request.url.path == '/api/work-order/tenant_work/T-1') {
    body = {
      'statusCode': 200,
      'data': [
        {
          'workOrder_id': 'WO-1',
          'work_subject': 'Leaky tap',
          'work_category': 'Plumbing',
          'status': 'New',
          'rental_adress': '123 Main St',
          'rental_unit': '101',
          'staffmember_name': 'Pat Staff',
          'createdAt': '2026-10-01',
          'date': '2026-10-30',
        },
        {
          // Just created: nobody assigned yet (no staffmember_name).
          'workOrder_id': 'WO-2',
          'work_subject': 'Broken fence',
          'work_category': 'General',
          'status': 'New',
          'rental_adress': '9 Oak Ave',
          'rental_unit': '',
          'createdAt': '2026-10-02',
          'date': '2026-10-31',
        },
      ],
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
    SharedPreferences.setMockInitialValues({
      'token': 'tkn',
      'tenant_id': 'T-1',
      'adminId': 'ADMIN-1',
      'role': 'Tenant',
    });
  });

  test('helper: staff name, or "-" when nobody is assigned', () {
    expect(workOrderAssignedLine(WorkOrder(staffMemberName: 'Pat Staff')),
        'Pat Staff');
    expect(workOrderAssignedLine(WorkOrder()), '-');
    expect(workOrderAssignedLine(WorkOrder(staffMemberName: '  ')), '-');
    expect(
        WorkOrder.fromJson({'workOrder_id': 'X'}).staffMemberName, isNull,
        reason: 'no "N/A" placeholder stored in the model');
  });

  Future<void> run(WidgetTester tester, double width,
      Future<void> Function() body) async {
    tester.view.physicalSize = Size(width, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final original = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('overflowed')) return;
      original?.call(details);
    };
    try {
      await http.runWithClient(() async {
        final dates = DateProvider();
        await dates.loadDateFormat();
        // Login/Splash await this before opening a tenant screen; the screen
        // reads permissions! in build.
        final perms = PermissionProvider();
        await perms.fetchPermissions();
        await tester.pumpWidget(MultiProvider(
          providers: [
            ChangeNotifierProvider<DateProvider>.value(value: dates),
            ChangeNotifierProvider<PermissionProvider>.value(value: perms),
            ChangeNotifierProvider(create: (_) => NotificationProvider()),
          ],
          child: MaterialApp(home: Scaffold(body: WorkOrderTable())),
        ));
        await _settle(tester);
        await body();
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 5));
      }, () => _server);
    } finally {
      FlutterError.onError = original;
    }
  }

  testWidgets('phone layout: expanded row reads "Assigned : -", like web',
      (tester) async {
    await run(tester, 430, () async {
      final row = find.text('Broken fence').first;
      await tester.ensureVisible(row);
      await tester.pump();
      await tester.tap(row);
      await _settle(tester, 10);
      expect(find.text('Assigned :'), findsOneWidget);
      expect(find.text('Assign :'), findsNothing);
      expect(find.text('N/A'), findsNothing);
      expect(find.text('-'), findsWidgets);

      final other = find.text('Leaky tap').first;
      await tester.ensureVisible(other);
      await tester.pump();
      await tester.tap(other);
      await _settle(tester, 10);
      expect(find.text('Pat Staff'), findsOneWidget);
    });
  });

  testWidgets('wide layout: Assigned column shows "-" and the name',
      (tester) async {
    await run(tester, 900, () async {
      expect(find.text('Pat Staff'), findsOneWidget);
      expect(find.text('N/A'), findsNothing);
      expect(find.text('-'), findsWidgets);
    });
  });

  testWidgets('search "n/a" no longer matches unassigned rows, like web',
      (tester) async {
    await run(tester, 430, () async {
      final search = find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.hintText == 'Search here...');
      await tester.enterText(search.first, 'n/a');
      await _settle(tester, 10);
      expect(find.text('Broken fence'), findsNothing);
      expect(find.text('Leaky tap'), findsNothing);
      await tester.enterText(search.first, 'pat');
      await _settle(tester, 10);
      expect(find.text('Leaky tap'), findsOneWidget,
          reason: 'searching the staff name still works');
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

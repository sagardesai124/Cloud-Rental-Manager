import 'dart:convert';

import 'package:connectivity_plus_platform_interface/connectivity_plus_platform_interface.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:three_zero_two_property/TenantsModule/model/workorder_summery_model.dart'
    as tenant_model;
import 'package:three_zero_two_property/TenantsModule/screen/work_order/update_workorder.dart';
import 'package:three_zero_two_property/VendorModule/model/workorder_summery_model.dart'
    as vendor_model;
import 'package:three_zero_two_property/VendorModule/screen/work_order/update_workorder.dart';
import 'package:three_zero_two_property/provider/dateProvider.dart';
import 'package:three_zero_two_property/provider/notification_provider.dart';

/// Tenant + Vendor → Work Order → Update: Save stays disabled until something
/// changes, like web (WorkOrderDetails.jsx: the Update button handler sets the
/// baseline, and the button is `disabled={... || !hasFormChanges}`). Web
/// counts a changed status, assignee or due date, a typed note (spaces don't
/// count), or a picked photo. Before, Save was always enabled, so saving an
/// untouched form added a duplicate Update History row and sent the admin a
/// "Work order has been updated" notification.

final _workOrder = <String, dynamic>{
  'workOrder_id': 'WO-1',
  'admin_id': 'ADMIN-1',
  'work_subject': 'Leaky tap',
  'status': 'In Progress',
  'date': '2026-10-30',
  'staffmember_id': 'S-1',
  'staff_data': {
    '_id': 'S-1',
    'staffmember_id': 'S-1',
    'staffmember_name': 'Pat Staff',
  },
  'workorder_updates': [],
  'partsandcharge_data': [],
};

final _server = MockClient((request) async {
  Object body = {'statusCode': 200, 'data': []};
  if (request.url.path.startsWith('/api/staffmember/staff_member/')) {
    body = {
      'statusCode': 200,
      'data': [
        {'staffmember_id': 'S-1', 'staffmember_name': 'Pat Staff'},
        {'staffmember_id': 'S-2', 'staffmember_name': 'Sam Other'},
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

bool _saveEnabled(WidgetTester tester) => tester
    .widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Save'))
    .onPressed !=
    null;

// Build order on both screens: Assigned first, then Status.
DropdownButton2<String> _assigned(WidgetTester tester) => tester
    .widget<DropdownButton2<String>>(find.byType(DropdownButton2<String>).at(0));
DropdownButton2<String> _status(WidgetTester tester) => tester
    .widget<DropdownButton2<String>>(find.byType(DropdownButton2<String>).at(1));

Future<void> _pickNewDueDate(WidgetTester tester) async {
  final field = find.text('2026-10-30');
  await tester.ensureVisible(field);
  await tester.pump();
  await tester.tap(field);
  await _settle(tester, 10);
  final picker = find.byType(DatePickerDialog);
  expect(picker, findsOneWidget);
  // The picker opens on the current month; any 1st differs from 2026-10-30.
  await tester.tap(find.descendant(of: picker, matching: find.text('1')).first);
  await tester.pump();
  await tester.tap(find.text('OK'));
  await _settle(tester, 10);
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
      'tenant_id': 'T-1',
      'vendor_id': 'V-1',
    });
  });

  Future<void> run(WidgetTester tester, Widget screen,
      Future<void> Function() body) async {
    tester.view.physicalSize = const Size(430, 2400);
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
        await tester.pumpWidget(MultiProvider(
          providers: [
            ChangeNotifierProvider<DateProvider>.value(value: dates),
            ChangeNotifierProvider(create: (_) => NotificationProvider()),
          ],
          child: MaterialApp(home: screen),
        ));
        await _settle(tester);
        await body();
      }, () => _server);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    } finally {
      FlutterError.onError = original;
    }
  }

  final tenantScreen = UpdateWorkOrderTenant(
      workorderId: 'WO-1',
      summery: tenant_model.WorkOrderData_summery.fromJson(_workOrder));
  final vendorScreen = UpdateWorkOrderVendor(
      workorderId: 'WO-1',
      summery: vendor_model.WorkOrderData_summery.fromJson(_workOrder));

  for (final c in [
    (name: 'Tenant', screen: tenantScreen as Widget, notes: 1),
    (name: 'Vendor', screen: vendorScreen as Widget, notes: 2),
  ]) {
    group('${c.name} Update Work Order', () {
      testWidgets('opens with Save disabled', (tester) async {
        await run(tester, c.screen, () async {
          expect(find.text('In Progress'), findsWidgets,
              reason: 'opens with the current status');
          expect(_saveEnabled(tester), isFalse,
              reason: 'nothing changed yet, like web');
        });
      });

      testWidgets('a note enables Save; spaces alone do not', (tester) async {
        await run(tester, c.screen, () async {
          final notes = find.byType(TextField);
          expect(notes, findsNWidgets(c.notes));
          for (var i = 0; i < c.notes; i++) {
            await tester.enterText(notes.at(i), '   ');
            await tester.pump();
            expect(_saveEnabled(tester), isFalse, reason: 'spaces only');
            await tester.enterText(notes.at(i), 'Just a note');
            await tester.pump();
            expect(_saveEnabled(tester), isTrue, reason: 'note $i typed');
            await tester.enterText(notes.at(i), '');
            await tester.pump();
            expect(_saveEnabled(tester), isFalse, reason: 'note $i cleared');
          }
        });
      });

      testWidgets('a new status enables Save; changing it back disables it',
          (tester) async {
        await run(tester, c.screen, () async {
          _status(tester).onChanged!('Completed');
          await tester.pump();
          expect(_saveEnabled(tester), isTrue);
          _status(tester).onChanged!('In Progress');
          await tester.pump();
          expect(_saveEnabled(tester), isFalse,
              reason: 'back to what it opened with');
        });
      });

      testWidgets('a new assignee enables Save', (tester) async {
        await run(tester, c.screen, () async {
          expect(_assigned(tester).value, 'S-1');
          _assigned(tester).onChanged!('S-2');
          await tester.pump();
          expect(_saveEnabled(tester), isTrue);
        });
      });

      testWidgets('a new due date enables Save', (tester) async {
        await run(tester, c.screen, () async {
          await _pickNewDueDate(tester);
          expect(find.text('2026-10-30'), findsNothing,
              reason: 'the picked date replaced the old one');
          expect(_saveEnabled(tester), isTrue);
        });
      });
    });
  }
}

class _OnlineConnectivity extends ConnectivityPlatform
    with MockPlatformInterfaceMixin {
  @override
  Future<ConnectivityResult> checkConnectivity() async =>
      ConnectivityResult.wifi;
  @override
  Stream<ConnectivityResult> get onConnectivityChanged => const Stream.empty();
}

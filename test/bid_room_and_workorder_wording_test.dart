import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus_platform_interface/connectivity_plus_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:three_zero_two_property/provider/dateProvider.dart';
import 'package:three_zero_two_property/provider/notification_provider.dart';
import 'package:three_zero_two_property/screens/BidRoom/bid_room_table.dart';

/// Wording parity with live staging web:
/// - Bid Room → a bid room with no vendor bids says "No submissions yet"
///   (BidRequests.jsx), not "No submissions available". Admin and Staff share
///   this screen.
/// - Work Orders list (Admin and Staff): the billable filter checkbox reads
///   "Show Billable" (Workorder.jsx), not "Billable To Tenants".

/// A bid room with no submissions.
final _server = MockClient((request) async {
  final path = request.url.path;
  Object body = {'statusCode': 200, 'data': []};
  final bidRequest = {
    'bid_request_id': 'BR-1',
    'bid_request_no': 2,
    'admin_id': 'ADMIN-1',
    'work_category': 'Plumbing',
    'description': 'test',
    'status': 'Open',
  };
  if (path.endsWith('/bid-request/bid-request/BR-1')) {
    body = {
      'statusCode': 200,
      'data': {...bidRequest, 'submissions': []}
    };
  } else if (path.contains('bid-request')) {
    body = {
      'statusCode': 200,
      'data': [bidRequest],
      'pagination': {'total': 1, 'page': 1, 'limit': 10000, 'pages': 1},
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
    SharedPreferences.setMockInitialValues(
        {'token': 'tkn', 'adminId': 'ADMIN-1', 'role': 'Admin'});
  });

  testWidgets('Bid Room: no vendor bids → "No submissions yet", like web',
      (tester) async {
    tester.view.physicalSize = const Size(430, 4000);
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
          child: const MaterialApp(home: Scaffold(body: BidRoomTable())),
        ));
        await _settle(tester);
        final row = find.text('BR2').first;
        await tester.ensureVisible(row);
        await tester.pump();
        await tester.tap(row);
        await _settle(tester);
        expect(find.text('No submissions yet'), findsOneWidget);
        expect(find.text('No submissions available'), findsNothing);
      }, () => _server);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    } finally {
      FlutterError.onError = original;
    }
  });

  test('Work Orders list: billable filter reads "Show Billable" (Admin + Staff)',
      () {
    for (final p in [
      'lib/screens/Maintenance/Workorder/Workorder_table.dart',
      'lib/StaffModule/screen/Maintenance/Workorder/Workorder_table.dart',
    ]) {
      final s = File(p).readAsStringSync();
      expect(s, contains('"Show Billable"'), reason: p);
      expect(s, isNot(contains('"Billable To Tenants"')), reason: p);
    }
  });

  test('Add/Edit Work Order forms: checkbox reads "Billable To Tenant" (Admin + Staff)',
      () {
    // web AddWorkorder.jsx / AddStaffWorkorder.jsx
    for (final p in [
      'lib/screens/Maintenance/Workorder/Add_workorder.dart',
      'lib/screens/Maintenance/Workorder/Edit_workorders.dart',
      'lib/StaffModule/screen/Maintenance/Workorder/Add_workorder.dart',
      'lib/StaffModule/screen/Maintenance/Workorder/Edit_workorders.dart',
      'lib/VendorModule/screen/work_order/Edit_workorders.dart',
    ]) {
      final s = File(p).readAsStringSync();
      expect(s, isNot(contains('Billable To Tenants')), reason: p);
    }
    for (final p in [
      'lib/screens/Maintenance/Workorder/Add_workorder.dart',
      'lib/screens/Maintenance/Workorder/Edit_workorders.dart',
      'lib/StaffModule/screen/Maintenance/Workorder/Add_workorder.dart',
      'lib/StaffModule/screen/Maintenance/Workorder/Edit_workorders.dart',
    ]) {
      expect(File(p).readAsStringSync(), contains('"Billable To Tenant"'),
          reason: p);
    }
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

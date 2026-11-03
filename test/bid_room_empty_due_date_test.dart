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
import 'package:three_zero_two_property/provider/dateProvider.dart';
import 'package:three_zero_two_property/provider/notification_provider.dart';
import 'package:three_zero_two_property/screens/BidRoom/bid_room_table.dart';

/// Bid Room (Admin and Staff share this screen): a bid room without a due
/// date shows Due Date "-", like web staging (BidRequests.jsx: `rental?.date
/// ? moment(...).format(dateFormat) : "-"`). It showed "N/A".

Map<String, dynamic> _bid(int no, String address, String dueDate) => {
      '_id': 'B-$no',
      'bid_request_id': 'BR-$no',
      'bid_request_no': no,
      'admin_id': 'ADMIN-1',
      'work_category': 'Plumbing',
      'description': 'Fix sink $no',
      'status': 'Open',
      'due_date': dueDate,
      'createdAt': '2026-10-23 13:18:41',
      'rental': {'rental_id': 'R-$no', 'rental_adress': address},
    };

final _server = MockClient((request) async {
  Object body = {'statusCode': 200, 'data': []};
  if (request.url.path.contains('bid-request')) {
    body = {
      'statusCode': 200,
      'data': [
        _bid(1, '12 Oak St', ''),
        _bid(2, '34 Elm St', '2026-10-30'),
      ],
      'pagination': {'total': 2, 'page': 1, 'limit': 10000, 'pages': 1},
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

/// Expands the row for [address] and returns the value under "Due Date:".
Future<String> _dueDateOf(WidgetTester tester, String address) async {
  final title = find.text(address).first;
  await tester.ensureVisible(title);
  await tester.tap(title, warnIfMissed: false);
  await _settle(tester, 10);
  final cell = find
      .ancestor(of: find.text('Due Date:').first, matching: find.byType(Column))
      .first;
  return tester
      .widgetList<Text>(find.descendant(of: cell, matching: find.byType(Text)))
      .map((t) => t.data ?? '')
      .firstWhere((s) => s != 'Due Date:');
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

  testWidgets('empty Due Date shows "-"; a set one is formatted as before',
      (tester) async {
    tester.view.physicalSize = const Size(430, 3000);
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

        // QA's case: no due date.
        expect(await _dueDateOf(tester, '12 Oak St'), '-');

        // A due date still shows in the account date format.
        await tester.tap(find.text('12 Oak St').first, warnIfMissed: false);
        await _settle(tester, 10);
        expect(await _dueDateOf(tester, '34 Elm St'),
            dates.formatCurrentDate('2026-10-30'));
      }, () => _server);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    } finally {
      FlutterError.onError = original;
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

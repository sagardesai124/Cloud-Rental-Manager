import 'dart:convert';

import 'package:connectivity_plus_platform_interface/connectivity_plus_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/intl.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:three_zero_two_property/VendorModule/screen/bid_room/vendor_bid_room_table.dart';
import 'package:three_zero_two_property/provider/dateProvider.dart';
import 'package:three_zero_two_property/provider/notification_provider.dart';

/// Vendor → Bid Room → Created On / Due Date work like web staging's Vendor
/// portal (VendorBidRequests.jsx): Created On is the createdAt_iso moment
/// (else createdAt) in the viewer's local time, as "<account date format>
/// HH:mm:ss"; Due Date uses the account date format; both "-" when empty.
/// Before, Created On printed the server's raw clock time (5h 30m behind in
/// India) as yyyy-MM-dd, and Due Date was always yyyy-MM-dd.

const _iso = '2026-10-23T13:18:41.000Z';

Map<String, dynamic> _bid(int no, String subject,
        {String? iso, String createdAt = '2026-10-23 13:18:41', String due = ''}) =>
    {
      '_id': 'B-$no',
      'bid_request_id': 'BR-$no',
      'bid_request_no': no,
      'admin_id': 'ADMIN-1',
      'work_category': 'Plumbing',
      'description': subject,
      'due_date': due,
      'status': 'Open',
      'createdAt': createdAt,
      if (iso != null) 'createdAt_iso': iso,
      'has_submitted': false,
    };

final _server = MockClient((request) async {
  final path = request.url.path;
  Object body = {'statusCode': 200, 'data': []};
  if (path == '/api/auth') {
    body = {
      'statusCode': 200,
      'themes': {'format': 'MM/DD/YYYY', 'timeFormat': '12'}
    };
  } else if (path == '/api/bid-request/bid-requests/vendor/V-1') {
    body = {
      'statusCode': 200,
      'data': [
        _bid(1, 'Test by qa work bidding', iso: _iso),
        _bid(2, 'Older API', createdAt: '2026-10-20 09:05:07', due: '2026-10-30'),
      ],
      'pagination': {'currentPage': 1, 'totalPages': 1, 'totalItems': 2},
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

/// Expands the row titled [subject] and returns the texts next to
/// "Created On :" and "Due Date :".
Future<(String, String)> _openRow(WidgetTester tester, String subject) async {
  final title = find.text(subject).first;
  await tester.ensureVisible(title);
  await tester.tap(title, warnIfMissed: false);
  await _settle(tester, 10);
  String valueAfter(String label) {
    final row = find
        .ancestor(of: find.text(label).first, matching: find.byType(Row))
        .first;
    return tester
        .widgetList<Text>(find.descendant(of: row, matching: find.byType(Text)))
        .map((t) => t.data ?? '')
        .where((s) => s != label)
        .join(' ')
        .trim();
  }

  return (valueAfter('Created On :'), valueAfter('Due Date :'));
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

  testWidgets('Created On = local time in the account date format; Due Date too',
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
          child: const MaterialApp(home: VendorBidRoomTable()),
        ));
        await _settle(tester);

        // QA's bid room: the createdAt_iso moment in local time, MM/dd/yyyy.
        final (created, due) = await _openRow(tester, 'Test by qa work bidding');
        expect(created,
            DateFormat('MM/dd/yyyy HH:mm:ss').format(DateTime.parse(_iso).toLocal()));
        expect(created, isNot(contains('2026-10-23')),
            reason: 'account date format, not year-first');
        expect(due, '-', reason: 'no due date: "-" like web');

        // Older API without createdAt_iso: falls back to createdAt, like web.
        final (created2, due2) = await _openRow(tester, 'Older API');
        expect(created2, '10/20/2026 09:05:07');
        expect(due2, '10/30/2026');
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

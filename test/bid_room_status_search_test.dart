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
import 'package:three_zero_two_property/VendorModule/screen/bid_room/vendor_bid_room_table.dart';
import 'package:three_zero_two_property/provider/dateProvider.dart';
import 'package:three_zero_two_property/provider/notification_provider.dart';
import 'package:three_zero_two_property/screens/BidRoom/bid_room_table.dart';

/// Bid Room search matches the status too, like web staging: web's search
/// (BidRequests.jsx / VendorBidRequests.jsx → BidRequest.js) matches
/// description, category, status, address and unit, case-insensitive and
/// partial. QA: searching "Closed" listed the closed rooms on web but showed
/// "No Results Found" on the phone. Admin and Staff share BidRoomTable.

Map<String, dynamic> _bid(int no, String description, String status) => {
      '_id': 'B-$no',
      'bid_request_id': 'BR-$no',
      'bid_request_no': no,
      'admin_id': 'ADMIN-1',
      'work_category': 'Plumbing',
      'description': description,
      'status': status,
      'createdAt': '2026-10-23 13:18:41',
      'has_submitted': false,
    };

http.Response _json(Object body) => http.Response(jsonEncode(body), 200,
    headers: {'content-type': 'application/json'});

final _adminServer = MockClient((request) async {
  if (request.url.path.contains('bid-request')) {
    return _json({
      'statusCode': 200,
      'data': [
        _bid(1, 'Fix sink', 'Open'),
        _bid(2, 'Paint hall', 'Awarded'),
        _bid(3, 'Roof repair', 'Closed'),
      ],
      'pagination': {'total': 3, 'page': 1, 'limit': 10000, 'pages': 1},
    });
  }
  return _json({'statusCode': 200, 'data': []});
});

final _vendorServer = MockClient((request) async {
  if (request.url.path == '/api/bid-request/bid-requests/vendor/V-1') {
    return _json({
      'statusCode': 200,
      'data': [
        _bid(1, 'Fix sink', 'Open'),
        _bid(2, 'Roof repair', 'Closed'),
      ],
      'pagination': {'currentPage': 1, 'totalPages': 1, 'totalItems': 2},
    });
  }
  return _json({'statusCode': 200, 'data': []});
});

Future<void> _settle(WidgetTester tester, [int ticks = 40]) async {
  for (var i = 0; i < ticks; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _search(WidgetTester tester, String text) async {
  await tester.enterText(
      find.byWidgetPredicate((w) =>
          w is TextField && w.decoration?.hintText == 'Search here...'),
      text);
  await _settle(tester, 10);
}

/// Pumps [screen] against [server] and runs [body] on it.
Future<void> _onScreen(WidgetTester tester, Widget screen, MockClient server,
    Future<void> Function() body) async {
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
        child: MaterialApp(home: screen),
      ));
      await _settle(tester);
      await body();
    }, () => server);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  } finally {
    FlutterError.onError = original;
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

  testWidgets('Admin/Staff Bid Room: search finds rooms by status, like web',
      (tester) async {
    SharedPreferences.setMockInitialValues(
        {'token': 'tkn', 'adminId': 'ADMIN-1', 'role': 'Admin'});
    await _onScreen(tester, const Scaffold(body: BidRoomTable()), _adminServer,
        () async {
      for (final no in ['BR1', 'BR2', 'BR3']) {
        expect(find.text(no), findsWidgets, reason: '$no listed at start');
      }

      // QA's case.
      await _search(tester, 'Closed');
      expect(find.text('BR3'), findsWidgets);
      expect(find.text('BR1'), findsNothing);
      expect(find.text('BR2'), findsNothing);
      expect(find.text('No Results Found'), findsNothing);

      // Case-insensitive and partial, like web's regex search.
      await _search(tester, 'open');
      expect(find.text('BR1'), findsWidgets);
      expect(find.text('BR3'), findsNothing);
      await _search(tester, 'award');
      expect(find.text('BR2'), findsWidgets);
      expect(find.text('BR1'), findsNothing);

      // The fields it already matched still work.
      await _search(tester, 'roof');
      expect(find.text('BR3'), findsWidgets);
      expect(find.text('BR1'), findsNothing);
      await _search(tester, 'plumb');
      for (final no in ['BR1', 'BR2', 'BR3']) {
        expect(find.text(no), findsWidgets, reason: 'category: $no');
      }
      await _search(tester, 'zzz');
      expect(find.text('No Results Found'), findsWidgets);
    });
  });

  testWidgets('Vendor Bid Room: search finds rooms by status, like web',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'token': 'tkn',
      'adminId': 'ADMIN-1',
      'vendor_id': 'V-1',
      'role': 'Vendor',
    });
    await _onScreen(tester, const VendorBidRoomTable(), _vendorServer,
        () async {
      expect(find.text('Fix sink'), findsWidgets);
      expect(find.text('Roof repair'), findsWidgets);

      await _search(tester, 'Closed');
      expect(find.text('Roof repair'), findsWidgets);
      expect(find.text('Fix sink'), findsNothing);
      expect(find.text('No Results Found'), findsNothing);

      await _search(tester, 'OPEN');
      expect(find.text('Fix sink'), findsWidgets);
      expect(find.text('Roof repair'), findsNothing);

      await _search(tester, 'sink');
      expect(find.text('Fix sink'), findsWidgets);
      expect(find.text('Roof repair'), findsNothing);
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

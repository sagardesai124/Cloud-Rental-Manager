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

/// Admin → Bid Room → submission card "Submitted At": like web
/// (BidRequests.jsx shows submitted_at, else createdAt). A bid saved without
/// submitted_at (e.g. from an older phone build) showed "N/A" on mobile but
/// the server's createdAt time on web.

const _createdAt = '2026-10-22T11:04:20.000Z'; // 16:34:20 IST
const _submittedAt = '2026-10-22T09:00:00.000Z'; // 14:30:00 IST

Map<String, dynamic> _submission(Map<String, dynamic> extra) => {
      'submission_id': 'S-1',
      'bid_request_id': 'BR-1',
      'vendor_id': 'V-1',
      'vendor_name': 'RMS Plumbing Services',
      'price_breakdown': 'Labour 100',
      'total_price': 100,
      'status': 'Submitted',
      ...extra,
    };

MockClient _server(Map<String, dynamic> submission) =>
    MockClient((request) async {
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
          'data': {
            ...bidRequest,
            'submissions': [submission]
          }
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
    SharedPreferences.setMockInitialValues({
      'token': 'tkn',
      'adminId': 'ADMIN-1',
      'role': 'Admin',
    });
  });

  Future<void> openSubmission(
      WidgetTester tester, Map<String, dynamic> submission) async {
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
        expect(find.text('RMS Plumbing Services'), findsWidgets,
            reason: 'the submission card is showing');
      }, () => _server(submission));
    } finally {
      FlutterError.onError = original;
    }
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  }

  testWidgets('no submitted_at: shows createdAt, like web', (tester) async {
    await openSubmission(tester, _submission({'createdAt': _createdAt}));
    expect(find.textContaining('16:34:20'), findsOneWidget);
    // Other empty card fields also read N/A; only those 3 remain.
    expect(find.text('N/A'), findsNWidgets(3));
    await close(tester);
  });

  testWidgets('submitted_at present: it wins over createdAt', (tester) async {
    await openSubmission(tester,
        _submission({'submitted_at': _submittedAt, 'createdAt': _createdAt}));
    expect(find.textContaining('14:30:00'), findsOneWidget);
    expect(find.textContaining('16:34:20'), findsNothing);
    await close(tester);
  });

  testWidgets('neither: still N/A', (tester) async {
    await openSubmission(tester, _submission({}));
    // The 3 other empty fields + Submitted At.
    expect(find.text('N/A'), findsNWidgets(4));
    await close(tester);
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

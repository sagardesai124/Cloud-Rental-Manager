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
import 'package:three_zero_two_property/Model/bid_request.dart';
import 'package:three_zero_two_property/VendorModule/screen/bid_room/vendor_submit_bid_screen.dart';
import 'package:three_zero_two_property/provider/notification_provider.dart';

/// Vendor → Bid Room → Submit Bid sends the vendor's FULL name, like web
/// (VendorBidRequests.jsx passes accessType.vendor_name to the modal). The
/// server stores submission.vendor_name as sent and the admin's Bid Room shows
/// it, so the phone used to show "Acme Plumbing" for "Acme Plumbing Services
/// LLC" (login kept only the first two words).

Map<String, dynamic>? _sentSubmission;

final _server = MockClient((request) async {
  if (request.url.path == '/api/bid-request/bid-submission') {
    _sentSubmission =
        (jsonDecode(request.body) as Map<String, dynamic>)['submission'];
  }
  return http.Response(
      jsonEncode({'statusCode': 200, 'message': 'ok', 'data': []}), 200,
      headers: {'content-type': 'application/json'});
});

Finder _field(String hint) => find.byWidgetPredicate(
    (w) => w is TextField && w.decoration?.hintText == hint);

Future<void> _settle(WidgetTester tester, [int ticks = 30]) async {
  for (var i = 0; i < ticks; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    _sentSubmission = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('PonnamKarthik/fluttertoast'), (_) async => true);
    ConnectivityPlatform.instance = _OnlineConnectivity();
  });

  Future<String?> submitWith(
      WidgetTester tester, Map<String, Object> prefs) async {
    SharedPreferences.setMockInitialValues({
      'token': 'tkn',
      'vendor_id': 'V-1',
      'role': 'Vendor',
      ...prefs,
    });
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
        await tester.pumpWidget(ChangeNotifierProvider(
          create: (_) => NotificationProvider(),
          child: MaterialApp(
            home: VendorSubmitBidScreen(
              bidRequest: BidRequest(bidRequestId: 'BR-1', adminId: 'ADMIN-1'),
            ),
          ),
        ));
        await _settle(tester);
        await tester.enterText(
            _field('Enter detailed price breakdown...'), 'Labour 100');
        await tester.enterText(_field('Enter total price'), '100');
        final submit = find.text('Submit Bid').last;
        await tester.ensureVisible(submit);
        await tester.pump();
        await tester.tap(submit);
        await _settle(tester);
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 5));
      }, () => _server);
    } finally {
      FlutterError.onError = original;
    }
    expect(_sentSubmission, isNotNull, reason: 'the bid was submitted');
    return _sentSubmission!['vendor_name'] as String?;
  }

  testWidgets('sends the full vendor_name saved at login', (tester) async {
    final name = await submitWith(tester, {
      'vendor_name': 'Acme Plumbing Services LLC',
      'first_name': 'Acme',
      'last_name': 'Plumbing',
    });
    expect(name, 'Acme Plumbing Services LLC');
  });

  testWidgets('single-word name is sent as-is', (tester) async {
    final name = await submitWith(tester, {
      'vendor_name': 'RMS',
      'first_name': 'RMS',
      'last_name': '',
    });
    expect(name, 'RMS');
  });

  testWidgets('sends submitted_at as a UTC ISO time, like web',
      (tester) async {
    final before = DateTime.now().toUtc().subtract(const Duration(seconds: 1));
    await submitWith(tester, {'vendor_name': 'Acme Plumbing Services LLC'});
    final sent = _sentSubmission!['submitted_at'] as String?;
    expect(sent, isNotNull, reason: 'admin card shows N/A without it');
    // Same shape as JS toISOString(): 2026-10-22T11:06:00.123Z
    expect(sent, matches(RegExp(r'^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d\.\d{3}Z$')));
    final at = DateTime.parse(sent!);
    expect(at.isAfter(before), isTrue);
    expect(at.isBefore(DateTime.now().toUtc().add(const Duration(minutes: 1))),
        isTrue);
  });

  testWidgets('session from before this build: falls back to first + last',
      (tester) async {
    final name = await submitWith(tester, {
      'first_name': 'Acme',
      'last_name': 'Plumbing',
    });
    expect(name, 'Acme Plumbing');
  });

  testWidgets('no name at all: still sends "Vendor"', (tester) async {
    final name = await submitWith(tester, {});
    expect(name, 'Vendor');
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

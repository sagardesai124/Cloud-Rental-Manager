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
import 'package:three_zero_two_property/screens/Reports/ReportScreens/ReopenWorkorder.dart';

/// Reports → Reopen Work Orders: search matches the same 10 fields as live
/// staging web (ReopenWorkOrderReport.jsx filterWorkOrdersBySearch): ticket #,
/// subject, category, priority, staff, address, unit, due date, reopen date
/// and created date. Before, mobile matched only the first two plus address
/// and staff, so "Plumbing" or "High" found nothing. Admin and Staff share
/// this screen.

Map<String, dynamic> _row(String ticket, Map<String, dynamic> extra) => {
      'workOrder_id': 'WO-$ticket',
      'ticket_number': ticket,
      'work_subject': 'Subject $ticket',
      'work_category': 'General',
      'priority': 'Low',
      'status': 'New',
      'date': '2026-01-01',
      'reopen_date': '2026-01-02',
      'created_at': '2026-01-03',
      'rental_adress': '1 Elm St',
      'rental_unit': 'A',
      'staffmember_name': 'Pat',
      ...extra,
    };

final _rows = [
  _row('AA111', {'work_category': 'Plumbing'}),
  _row('BB222', {'priority': 'High'}),
  _row('CC333', {'rental_unit': '101'}),
  _row('DD444', {'date': '2026-09-07'}),
  _row('EE555', {'reopen_date': '2026-09-08'}),
  _row('FF666', {'created_at': '2026-09-09'}),
  _row('GG777', {'work_subject': 'Leaky tap'}),
  _row('HH888', {'rental_adress': '9 Oak Ave'}),
  _row('II999', {'staffmember_name': 'Sam Rivers'}),
];

final _server = MockClient((request) async {
  Object body = {'statusCode': 200, 'data': []};
  if (request.url.path.toLowerCase().contains('reopen')) {
    body = {'statusCode': 200, 'data': _rows};
  }
  return http.Response(jsonEncode(body), 200,
      headers: {'content-type': 'application/json'});
});

Future<void> _settle(WidgetTester tester, [int ticks = 30]) async {
  for (var i = 0; i < ticks; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Finder get _search => find.byWidgetPredicate(
    (w) => w is TextField && w.decoration?.hintText == 'Search here ...');

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

  Future<void> run(WidgetTester tester, Future<void> Function() body) async {
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
          child: const MaterialApp(home: ReopenWorkorder()),
        ));
        await _settle(tester);
        expect(find.text('AA111'), findsOneWidget, reason: 'report loaded');
        await body();
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 5));
      }, () => _server);
    } finally {
      FlutterError.onError = original;
    }
  }

  /// Types [term] and returns which of the 7 tickets are still listed.
  Future<Set<String>> shown(WidgetTester tester, String term) async {
    await tester.enterText(_search, term);
    await _settle(tester, 10);
    return _rows
        .map((r) => r['ticket_number'] as String)
        .where((t) => find.text(t).evaluate().isNotEmpty)
        .toSet();
  }

  testWidgets('search matches category, priority, unit and dates, like web',
      (tester) async {
    await run(tester, () async {
      expect(await shown(tester, 'plumbing'), {'AA111'});
      expect(await shown(tester, 'high'), {'BB222'});
      expect(await shown(tester, '101'), {'CC333'});
      expect(await shown(tester, '2026-09-07'), {'DD444'});
      expect(await shown(tester, '2026-09-08'), {'EE555'});
      expect(await shown(tester, '2026-09-09'), {'FF666'});
    });
  });

  testWidgets('existing fields still match and no match shows nothing',
      (tester) async {
    await run(tester, () async {
      expect(await shown(tester, 'leaky'), {'GG777'});
      expect(await shown(tester, 'gg777'), {'GG777'});
      expect(await shown(tester, 'oak ave'), {'HH888'});
      expect(await shown(tester, 'rivers'), {'II999'});
      expect(await shown(tester, 'zzz-none'), isEmpty);
      expect(await shown(tester, ''), hasLength(9));
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

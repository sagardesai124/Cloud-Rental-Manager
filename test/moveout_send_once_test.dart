import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus_platform_interface/connectivity_plus_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:three_zero_two_property/model/LeaseSummary.dart';
import 'package:three_zero_two_property/provider/dateProvider.dart';
import 'package:three_zero_two_property/provider/notification_provider.dart';
import 'package:three_zero_two_property/screens/Leasing/RentalRoll/Move_out_lease/Moveout_lease.dart';
import 'package:three_zero_two_property/screens/Rental/Properties/moveout/lease_end_decision.dart';
import 'package:three_zero_two_property/screens/Rental/Properties/moveout/moveout_form_ui.dart';

/// Move Out follows web's rules before sending (LeaseTenantsTab.jsx
/// handleMoveout): a tenant must be ticked and each ticked tenant needs both
/// dates. Once sent, Move Out shows a spinner and further taps are ignored
/// until the server answers, so a quick double tap sends one move-out.

const _required =
    '"Notice Given Date" and "Move-Out Date" are required for all selected tenants';

final List<String> _toasts = [];

class _Server {
  final List<http.Request> requests = [];

  /// Holds the move-out reply until [answer] is called.
  final Completer<void> _reply = Completer<void>();
  void answer() => _reply.complete();

  late final MockClient client = MockClient((request) async {
    requests.add(request);
    final path = request.url.path;
    if (path == '/api/auth') {
      return _json({
        'statusCode': 200,
        'themes': {'format': 'MM/DD/YYYY', 'timeFormat': '12'}
      });
    }
    if (path.startsWith('/api/moveout/lease_multiplemoveout/')) {
      await _reply.future;
      return _json({'statusCode': 200, 'message': 'Moveout process completed.'});
    }
    return _json({'statusCode': 200, 'data': []});
  });

  List<http.Request> get moveouts => requests
      .where((r) => r.url.path.startsWith('/api/moveout/lease_multiplemoveout/'))
      .toList();
}

http.Response _json(Object body) => http.Response(jsonEncode(body), 200,
    headers: {'content-type': 'application/json'});

LeaseTenant _tenant(String id, String first) => LeaseTenant(
      leaseId: 'L-1',
      tenantId: id,
      adminId: 'ADMIN-1',
      rentalId: 'R-1',
      moveoutNoticeGivenDate: '',
      moveoutDate: '',
      unitId: 'U-1',
      leaseType: 'Fixed',
      startDate: '2026-10-01',
      endDate: '2027-09-30',
      tenantFirstName: first,
      tenantLastName: 'Tenant',
      tenantPhoneNumber: '',
      tenantEmail: '$first@example.com',
      rentalAddress: '1 Test Street',
      rentalUnit: '',
    );

Future<void> _settle(WidgetTester tester, [int ticks = 16]) async {
  for (var i = 0; i < ticks; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _openMoveOut(WidgetTester tester, List<LeaseTenant> tenants,
    void Function(Object?) onPop) async {
  tester.view.physicalSize = const Size(430, 3200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final dates = DateProvider();
  await dates.loadDateFormat();
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider<DateProvider>.value(value: dates),
      ChangeNotifierProvider(create: (_) => NotificationProvider()),
    ],
    child: MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () async => onPop(await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => MoveoutScreen(
                            tenant: tenants.first,
                            tenants: tenants,
                            enddate: tenants.first.endDate,
                            moveOutDate: '',
                            leaseId: 'L-1',
                          )))),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await _settle(tester, 20);
}

Future<void> _tapSubmit(WidgetTester tester) async {
  final f = find.byKey(const Key('moveout-submit'));
  await tester.ensureVisible(f);
  await tester.pump();
  await tester.tap(f, warnIfMissed: false);
  await _settle(tester, 6);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Staging behaviour: no lease-end question in the way.
  setUpAll(() => debugLeaseEndQuestionEnabled = false);
  tearDownAll(() => debugLeaseEndQuestionEnabled = null);

  group('moveoutDatesMissing (web rule)', () {
    test('both dates for every ticked tenant: ok', () {
      expect(moveoutDatesMissing(['10/13/2026'], ['09/30/2027']), isFalse);
    });
    test('no tenant ticked: missing', () {
      expect(moveoutDatesMissing([], []), isTrue);
    });
    test('a ticked tenant without a move-out date: missing', () {
      expect(
          moveoutDatesMissing(
              ['10/13/2026', '10/13/2026'], ['09/30/2027', '  ']),
          isTrue);
    });
    test('a ticked tenant without a notice date: missing', () {
      expect(moveoutDatesMissing([''], ['09/30/2027']), isTrue);
    });
  });

  group('moveoutPickerInitialDate', () {
    test('opens on the date the field shows', () {
      expect(moveoutPickerInitialDate('2027-09-30'), DateTime(2027, 9, 30));
    });
    test('empty or unreadable: today', () {
      final today = DateTime.now();
      for (final shown in ['', 'not a date']) {
        final d = moveoutPickerInitialDate(shown);
        expect([d.year, d.month, d.day], [today.year, today.month, today.day]);
      }
    });
  });

  group('lease move-out page (MoveoutScreen)', () {
    setUp(() {
      _toasts.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
              const MethodChannel('PonnamKarthik/fluttertoast'), (call) async {
        if (call.method == 'showToast') {
          _toasts.add('${(call.arguments as Map)['msg']}');
        }
        return true;
      });
      ConnectivityPlatform.instance = _OnlineConnectivity();
      SharedPreferences.setMockInitialValues(
          {'token': 'tkn', 'adminId': 'ADMIN-1', 'role': 'Admin'});
    });

    Future<void> run(WidgetTester tester, _Server server,
        Future<void> Function() body) async {
      final original = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.exceptionAsString().contains('overflowed')) return;
        original?.call(details);
      };
      try {
        await http.runWithClient(body, () => server.client);
        await tester.pump(const Duration(seconds: 2));
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 2));
      } finally {
        FlutterError.onError = original;
      }
    }

    testWidgets('no tenant ticked: web\'s message shows, nothing is sent',
        (tester) async {
      final server = _Server();
      await run(tester, server, () async {
        Object? popped = 'not popped';
        await _openMoveOut(tester, [_tenant('T-1', 'Pat')], (r) => popped = r);
        await tester.tap(find.byType(Checkbox).first);
        await _settle(tester, 4);
        await _tapSubmit(tester);
        expect(_toasts, contains(_required));
        expect(server.moveouts, isEmpty);
        expect(popped, 'not popped', reason: 'form stays open');
        expect(find.byType(SpinKitFadingCircle), findsNothing);
        server.answer();
      });
    });

    testWidgets('a quick double tap sends one move-out, with a spinner',
        (tester) async {
      final server = _Server();
      await run(tester, server, () async {
        final pops = <Object?>[];
        await _openMoveOut(tester, [_tenant('T-1', 'Pat')], pops.add);
        await _tapSubmit(tester);
        expect(find.byType(SpinKitFadingCircle), findsOneWidget,
            reason: 'Move Out shows the spinner while sending');
        await _tapSubmit(tester);
        await _tapSubmit(tester);
        expect(server.moveouts, hasLength(1));

        server.answer();
        await _settle(tester, 20);
        expect(server.moveouts, hasLength(1));
        expect(pops, [true], reason: 'page closes once after the move-out');
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

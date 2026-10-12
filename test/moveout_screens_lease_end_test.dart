import 'dart:async';
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
import 'package:three_zero_two_property/model/LeaseSummary.dart';
import 'package:three_zero_two_property/model/properties.dart';
import 'package:three_zero_two_property/model/properties_summery.dart';
import 'package:three_zero_two_property/provider/dateProvider.dart';
import 'package:three_zero_two_property/provider/notification_provider.dart';
import 'package:three_zero_two_property/screens/Leasing/RentalRoll/Move_out_lease/Moveout_lease.dart';
import 'package:three_zero_two_property/screens/Rental/Properties/moveout/Moveout_properties.dart';
import 'package:three_zero_two_property/screens/Rental/Properties/moveout/lease_end_decision.dart';

/// The REAL Admin move-out pages, driven against a fake server, ask the web
/// 2.2 "Does the lease end?" question exactly when web does
/// (Client/src/utils/moveoutLeaseEnd.js shouldAskLeaseEnd), refuse to submit
/// until it is answered, send the answer as `leaseEnd`, and send every date
/// to the API as yyyy-MM-dd whatever the company display format is.
///
/// Also the regression proof for the build-once fix: a page rebuild used to
/// reset every tenant's checkbox and picked dates to the defaults.

const _adminId = 'ADMIN-1';
const _askText =
    'This move-out leaves no tenant on the lease. Does it end the lease?';
const _unansweredMessage =
    'Say whether this move-out ends the lease, or whether the tenant stays '
    'responsible through the lease term.';
const _leaseEnd = '2027-09-30';
const _fixed = 'Fixed';
const _atWill = 'At-will(month to month)';

String get _todayApi => DateFormat('yyyy-MM-dd').format(DateTime.now());

class _Server {
  _Server({this.dateFormat = 'MM/DD/YYYY'});

  /// What /api/auth returns as the company date format (DateProvider).
  final String dateFormat;
  final List<http.Request> requests = [];

  late final MockClient client = MockClient((request) async {
    requests.add(request);
    final path = request.url.path;
    Object body = {'statusCode': 200, 'data': []};
    if (path == '/api/auth') {
      body = {
        'statusCode': 200,
        'themes': {'format': dateFormat, 'timeFormat': '12'}
      };
    } else if (path.startsWith('/api/moveout/lease_multiplemoveout/')) {
      body = {'statusCode': 200, 'message': 'Moveout process completed.'};
    }
    return http.Response(jsonEncode(body), 200,
        headers: {'content-type': 'application/json'});
  });

  List<http.Request> get moveouts => requests
      .where((r) =>
          r.method == 'POST' &&
          r.url.path.startsWith('/api/moveout/lease_multiplemoveout/'))
      .toList();
}

/// The `data` field of a multipart body, decoded.
Map<String, dynamic> _multipartData(http.Request r) {
  final m = RegExp(r'name="data"\r\n\r\n(.*?)\r\n--', dotAll: true)
      .firstMatch(r.body);
  expect(m, isNotNull, reason: 'multipart body has a data field');
  return jsonDecode(m!.group(1)!) as Map<String, dynamic>;
}

LeaseTenant _leaseTenant(String id, String first,
        {String leaseType = _fixed, String end = _leaseEnd}) =>
    LeaseTenant(
      leaseId: 'L-1',
      tenantId: id,
      adminId: _adminId,
      rentalId: 'R-1',
      moveoutNoticeGivenDate: '',
      moveoutDate: '',
      unitId: 'U-1',
      leaseType: leaseType,
      startDate: '2026-10-01',
      endDate: end,
      tenantFirstName: first,
      tenantLastName: 'Tenant',
      tenantPhoneNumber: '',
      tenantEmail: '$first@example.com',
      rentalAddress: '1 Test Street',
      rentalUnit: '',
    );

TenantData _rentalTenant(String id, String first,
        {String leaseType = _fixed,
        String end = _leaseEnd,
        String lease = 'L-1'}) =>
    TenantData(
      tenantId: [id],
      adminId: _adminId,
      firstName: first,
      lastName: 'Tenant',
      leaseId: lease,
      rentalId: 'R-1',
      unitId: 'U-1',
      leaseType: leaseType,
      startDate: '2026-10-01',
      endDate: end,
    );

Future<void> _settle(WidgetTester tester, [int ticks = 16]) async {
  for (var i = 0; i < ticks; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Opens [page] from a launcher route (as the summary pages push it), with
/// the providers main.dart supplies, on a phone-width, very tall viewport.
/// [onPop] receives what the page popped with.
Future<void> _open(WidgetTester tester, Widget Function() page,
    void Function(Object?) onPop) async {
  tester.view.physicalSize = const Size(430, 3200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  // The company date format is loaded from the server before the page opens
  // (in the app it is loaded at login).
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
                  context, MaterialPageRoute(builder: (_) => page()))),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await _settle(tester, 20);
  expect(find.text('Move Out'), findsOneWidget, reason: 'move-out page open');
}

/// The page's outer padding follows the screen width (narrower under 500),
/// so a width change proves the page build() ran again.
EdgeInsetsGeometry _pagePadding(WidgetTester tester) =>
    tester.widget<Padding>(find.byKey(const Key('moveout-page'))).padding;

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pump();
  await tester.tap(f);
  await _settle(tester, 10);
}

Future<void> _tapMoveOut(WidgetTester tester) =>
    _tap(tester, find.text('Move Out'));

bool _checked(WidgetTester tester, int i) =>
    tester.widget<Checkbox>(find.byType(Checkbox).at(i)).value ?? false;

/// The page's date fields, in tree order: per tenant Notice Given, Move-Out.
List<String> _dateFieldTexts(WidgetTester tester) => tester
    .widgetList<TextField>(find.byType(TextField))
    .map((f) => f.controller?.text ?? '')
    .toList();

/// Lets pending timers fire and tears the page down.
Future<void> _finish(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 2));
  await _settle(tester, 10);
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 2));
}

/// The test font draws every glyph as a full em square, so dense rows
/// overflow at phone width; that layout noise is ignored.
Future<void> _run(_Server server, Future<void> Function() body) async {
  final original = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.exceptionAsString().contains('overflowed')) return;
    original?.call(details);
  };
  try {
    await http.runWithClient(body, () => server.client);
  } finally {
    FlutterError.onError = original;
  }
}

final List<String> _toasts = [];

void main() {
  // These cases are about the question itself, whatever server the build uses.
  setUpAll(() => debugLeaseEndQuestionEnabled = true);
  tearDownAll(() => debugLeaseEndQuestionEnabled = null);

  TestWidgetsFlutterBinding.ensureInitialized();

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
        {'token': 'tkn', 'adminId': _adminId, 'role': 'Admin'});
  });

  group('Admin lease move-out page (MoveoutScreen)', () {
    MoveoutScreen page(List<LeaseTenant> tenants) => MoveoutScreen(
          tenant: tenants.first,
          tenants: tenants,
          enddate: tenants.first.endDate,
          moveOutDate: '',
          leaseId: 'L-1',
        );

    testWidgets(
        '(1) one tenant, fixed term, move-out = lease end: the box is shown',
        (tester) async {
      final server = _Server();
      await _run(server, () async {
        final tenants = [_leaseTenant('T-1', 'Pat')];
        await _open(tester, () => page(tenants), (_) {});
        expect(_checked(tester, 0), isTrue, reason: 'clicked tenant ticked');
        expect(_dateFieldTexts(tester)[1], '09/30/2027',
            reason: 'move-out defaults to the lease end');
        expect(find.text(_askText), findsOneWidget);
        expect(find.byKey(const Key('lease-end-yes')), findsOneWidget);
        expect(find.byKey(const Key('lease-end-no')), findsOneWidget);
        expect(
            find.text(
                'No, the tenant remains responsible through 09/30/2027'),
            findsOneWidget);
        await _finish(tester);
      });
    });

    testWidgets(
        '(2) two active tenants, only the clicked one ticked: no box; '
        'ticking the second shows it', (tester) async {
      final server = _Server();
      await _run(server, () async {
        final tenants = [_leaseTenant('T-1', 'Pat'), _leaseTenant('T-2', 'Sam')];
        await _open(tester, () => page(tenants), (_) {});
        expect(_checked(tester, 0), isTrue);
        expect(_checked(tester, 1), isFalse);
        expect(find.text(_askText), findsNothing,
            reason: 'Sam stays on the lease');
        await _tap(tester, find.byType(Checkbox).at(1));
        expect(_checked(tester, 1), isTrue);
        expect(find.text(_askText), findsOneWidget,
            reason: 'nobody is left on the lease');
        // Unticking again hides it.
        await _tap(tester, find.byType(Checkbox).at(1));
        expect(find.text(_askText), findsNothing);
        await _finish(tester);
      });
    });

    testWidgets('(3) Move Out without answering: nothing is sent',
        (tester) async {
      final server = _Server();
      await _run(server, () async {
        Object? popped = 'not popped';
        final tenants = [_leaseTenant('T-1', 'Pat')];
        await _open(tester, () => page(tenants), (r) => popped = r);
        await _tapMoveOut(tester);
        expect(server.moveouts, isEmpty);
        expect(_toasts, contains(_unansweredMessage));
        expect(popped, 'not popped', reason: 'page stays open');
        expect(find.text(_askText), findsOneWidget);
        await _finish(tester);
      });
    });

    testWidgets(
        '(4) answer No, Move Out: data carries leaseEnd {ends_lease:false}, '
        'dates as yyyy-MM-dd', (tester) async {
      final server = _Server();
      await _run(server, () async {
        Object? popped = 'not popped';
        final tenants = [_leaseTenant('T-1', 'Pat')];
        await _open(tester, () => page(tenants), (r) => popped = r);
        await _tap(tester, find.byKey(const Key('lease-end-no')));
        await _tapMoveOut(tester);
        expect(server.moveouts, hasLength(1));
        final r = server.moveouts.single;
        expect(r.url.path, '/api/moveout/lease_multiplemoveout/L-1');
        expect(r.headers['id'], 'CRM $_adminId');
        expect(_multipartData(r), {
          'moveoutTenants': [
            {
              'admin_id': _adminId,
              'tenant_id': 'T-1',
              'lease_id': 'L-1',
              'moveout_notice_given_date': _todayApi,
              'moveout_date': '2027-09-30',
            }
          ],
          'descriptions': <String>[],
          'leaseEnd': {'ends_lease': false},
        });
        await _settle(tester, 20);
        expect(popped, isTrue, reason: 'page closes with true on success');
        await _finish(tester);
      });
    });

    testWidgets('(5) at-will lease: no box, and no leaseEnd in the request',
        (tester) async {
      final server = _Server();
      await _run(server, () async {
        final tenants = [_leaseTenant('T-1', 'Pat', leaseType: _atWill)];
        await _open(tester, () => page(tenants), (_) {});
        expect(find.text(_askText), findsNothing);
        await _tapMoveOut(tester);
        expect(server.moveouts, hasLength(1));
        final data = _multipartData(server.moveouts.single);
        expect(data.containsKey('leaseEnd'), isFalse);
        expect(data, {
          'moveoutTenants': [
            {
              'admin_id': _adminId,
              'tenant_id': 'T-1',
              'lease_id': 'L-1',
              'moveout_notice_given_date': _todayApi,
              'moveout_date': '2027-09-30',
            }
          ],
          'descriptions': <String>[],
        });
        await _finish(tester);
      });
    });

    testWidgets(
        '(6) a page rebuild keeps the ticked tenant and the picked date '
        '(build-once regression)', (tester) async {
      final server = _Server();
      await _run(server, () async {
        final tenants = [_leaseTenant('T-1', 'Pat'), _leaseTenant('T-2', 'Sam')];
        await _open(tester, () => page(tenants), (_) {});
        // Tick Sam and pick the 15th of this month as his move-out date.
        await _tap(tester, find.byType(Checkbox).at(1));
        expect(_checked(tester, 1), isTrue);
        await _tap(tester, find.byIcon(Icons.calendar_today_outlined).at(3));
        await tester.tap(find.text('15'));
        await tester.pump();
        await tester.tap(find.text('OK'));
        await _settle(tester, 10);
        final now = DateTime.now();
        final picked = DateTime(now.year, now.month, 15);
        final pickedShown = DateFormat('MM/dd/yyyy').format(picked);
        expect(_dateFieldTexts(tester)[3], pickedShown);

        // Rebuild the whole page: a MediaQuery change re-runs the State's
        // build() and therefore buildMoveout() (the old code re-applied the
        // defaults there: Sam unticked, his date back to the lease end).
        final paddingBefore = _pagePadding(tester);
        tester.view.physicalSize = const Size(600, 3200);
        await _settle(tester, 4);
        final paddingAfter = _pagePadding(tester);
        expect(paddingAfter, isNot(paddingBefore),
            reason: 'proof that the page build() ran again');

        expect(_checked(tester, 0), isTrue);
        expect(_checked(tester, 1), isTrue, reason: 'Sam still ticked');
        expect(_dateFieldTexts(tester)[3], pickedShown,
            reason: "Sam's picked date kept");
        expect(_dateFieldTexts(tester)[1], '09/30/2027');
        expect(find.text(_askText), findsOneWidget);

        // And what is sent is what is on screen.
        await _tap(tester, find.byKey(const Key('lease-end-no')));
        await _tapMoveOut(tester);
        final sent = _multipartData(server.moveouts.single)['moveoutTenants']
            as List;
        expect(sent.map((t) => [t['tenant_id'], t['moveout_date']]), [
          ['T-1', '2027-09-30'],
          ['T-2', DateFormat('yyyy-MM-dd').format(picked)],
        ]);
        await _finish(tester);
      });
    });

    testWidgets(
        '(8) staging build: no box and no leaseEnd, the rest unchanged',
        (tester) async {
      debugLeaseEndQuestionEnabled = null; // decide from Api_url (staging)
      addTearDown(() => debugLeaseEndQuestionEnabled = true);
      final server = _Server();
      await _run(server, () async {
        final tenants = [_leaseTenant('T-1', 'Pat')];
        await _open(tester, () => page(tenants), (_) {});
        expect(find.text(_askText), findsNothing);
        await _tapMoveOut(tester);
        expect(server.moveouts, hasLength(1));
        final data = _multipartData(server.moveouts.single);
        expect(data.containsKey('leaseEnd'), isFalse);
        expect((data['moveoutTenants'] as List).single['moveout_date'],
            '2027-09-30');
        await _finish(tester);
      });
    });

    testWidgets(
        '(7) company format YYYY-MMM-DD: screen shows 2027-Sep-30, API gets '
        '2027-09-30 (moveout_date and ends_on)', (tester) async {
      final server = _Server(dateFormat: 'YYYY-MMM-DD');
      await _run(server, () async {
        final tenants = [_leaseTenant('T-1', 'Pat')];
        await _open(tester, () => page(tenants), (_) {});
        expect(_dateFieldTexts(tester)[1], '2027-Sep-30');
        expect(
            find.text(
                'No, the tenant remains responsible through 2027-Sep-30'),
            findsOneWidget);
        await _tap(tester, find.byKey(const Key('lease-end-yes')));
        // The box's date defaults to the latest move-out, shown in the
        // company format.
        expect(
            find.descendant(
                of: find.byKey(const Key('lease-end-date')),
                matching: find.text('2027-Sep-30')),
            findsOneWidget);
        await _tapMoveOut(tester);
        expect(server.moveouts, hasLength(1));
        final data = _multipartData(server.moveouts.single);
        expect((data['moveoutTenants'] as List).single, {
          'admin_id': _adminId,
          'tenant_id': 'T-1',
          'lease_id': 'L-1',
          'moveout_notice_given_date': _todayApi,
          'moveout_date': '2027-09-30',
        });
        expect(data['leaseEnd'],
            {'ends_lease': true, 'ends_on': '2027-09-30', 'reason': ''});
        await _finish(tester);
      });
    });
  });

  group('Admin property move-out page (Moveout_properties)', () {
    Moveout_properties page(List<TenantData> tenants) => Moveout_properties(
          properties: Rentals(rentalId: 'R-1', rentalAddress: '1 Test Street'),
          tenants: tenants,
          tenant: tenants.first,
          moveOutDate: '',
          leaseId: 'L-1',
        );

    testWidgets(
        '(P1) one tenant, fixed term: box shown; unanswered blocks; '
        'Yes sends leaseEnd {ends_lease:true, ends_on}', (tester) async {
      final server = _Server();
      await _run(server, () async {
        Object? popped = 'not popped';
        final tenants = [_rentalTenant('T-1', 'Pat')];
        await _open(tester, () => page(tenants), (r) => popped = r);
        expect(_checked(tester, 0), isTrue);
        expect(find.text(_askText), findsOneWidget);

        await _tapMoveOut(tester);
        expect(server.moveouts, isEmpty);
        expect(_toasts, contains(_unansweredMessage));

        await _tap(tester, find.byKey(const Key('lease-end-yes')));
        await _tapMoveOut(tester);
        expect(server.moveouts, hasLength(1));
        final r = server.moveouts.single;
        expect(r.url.path, '/api/moveout/lease_multiplemoveout/L-1');
        expect(jsonDecode(r.body), {
          'moveoutTenants': [
            {
              'admin_id': _adminId,
              'tenant_id': 'T-1',
              'lease_id': 'L-1',
              'moveout_notice_given_date': _todayApi,
              'moveout_date': '2027-09-30',
            }
          ],
          'leaseEnd': {
            'ends_lease': true,
            'ends_on': '2027-09-30',
            'reason': '',
          },
        });
        await _settle(tester, 20);
        expect(popped, isTrue);
        await _finish(tester);
      });
    });

    testWidgets('(P2) at-will lease: no box, body has no leaseEnd',
        (tester) async {
      final server = _Server();
      await _run(server, () async {
        final tenants = [_rentalTenant('T-1', 'Pat', leaseType: _atWill)];
        await _open(tester, () => page(tenants), (_) {});
        expect(find.text(_askText), findsNothing);
        await _tapMoveOut(tester);
        expect(server.moveouts, hasLength(1));
        expect(jsonDecode(server.moveouts.single.body), {
          'moveoutTenants': [
            {
              'admin_id': _adminId,
              'tenant_id': 'T-1',
              'lease_id': 'L-1',
              'moveout_notice_given_date': _todayApi,
              'moveout_date': '2027-09-30',
            }
          ],
        });
        await _finish(tester);
      });
    });

    testWidgets(
        '(P3) two tenants on the lease, only the clicked one ticked: no box; '
        'a page rebuild keeps the second tick', (tester) async {
      final server = _Server();
      await _run(server, () async {
        final tenants = [_rentalTenant('T-1', 'Pat'), _rentalTenant('T-2', 'Sam')];
        await _open(tester, () => page(tenants), (_) {});
        expect(find.text(_askText), findsNothing);
        await _tap(tester, find.byType(Checkbox).at(1));
        expect(find.text(_askText), findsOneWidget);
        final paddingBefore = _pagePadding(tester);
        tester.view.physicalSize = const Size(600, 3200);
        await _settle(tester, 4);
        expect(_pagePadding(tester), isNot(paddingBefore));
        expect(_checked(tester, 1), isTrue, reason: 'Sam still ticked');
        expect(find.text(_askText), findsOneWidget);
        await _finish(tester);
      });
    });

    testWidgets(
        '(P4) rental with two leases: asks about the clicked lease only and '
        'posts to that lease, not the last listed one', (tester) async {
      final server = _Server();
      await _run(server, () async {
        final tenants = [
          _rentalTenant('T-1', 'Pat'),
          _rentalTenant('T-9', 'Kim', lease: 'L-2', end: '2028-06-30'),
        ];
        await _open(tester, () => page(tenants), (_) {});
        // Kim is on another lease, so Pat leaving empties lease L-1.
        expect(find.text(_askText), findsOneWidget);
        await _tap(tester, find.byKey(const Key('lease-end-no')));
        await _tapMoveOut(tester);
        expect(server.moveouts, hasLength(1));
        expect(server.moveouts.single.url.path,
            '/api/moveout/lease_multiplemoveout/L-1');
        expect(jsonDecode(server.moveouts.single.body)['leaseEnd'],
            {'ends_lease': false});
        await _finish(tester);
      });
    });

    testWidgets(
        '(P5) picking an earlier move-out date updates the question: Yes '
        'defaults to that date and asks for a reason', (tester) async {
      final server = _Server();
      await _run(server, () async {
        final tenants = [_rentalTenant('T-1', 'Pat')];
        await _open(tester, () => page(tenants), (_) {});
        // Move-Out Date is the second date field.
        await _tap(tester, find.byIcon(Icons.calendar_today_outlined).at(1));
        await tester.tap(find.text('15'));
        await tester.pump();
        await tester.tap(find.text('OK'));
        await _settle(tester, 10);
        final now = DateTime.now();
        final picked = DateTime(now.year, now.month, 15);

        await _tap(tester, find.byKey(const Key('lease-end-yes')));
        expect(
            find.descendant(
                of: find.byKey(const Key('lease-end-date')),
                matching: find.text(DateFormat('MM/dd/yyyy').format(picked))),
            findsOneWidget);
        expect(find.text('Reason the lease ends before 09/30/2027'),
            findsOneWidget);
        await _tapMoveOut(tester);
        expect(server.moveouts, isEmpty);
        expect(_toasts,
            contains('Choose the reason the lease ends before its written term.'));
        await _finish(tester);
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

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
import 'package:three_zero_two_property/StaffModule/repository/staffpermission_provider.dart';
import 'package:three_zero_two_property/StaffModule/screen/Leasing/RentalRoll/RenewLease.dart'
    as staff;
import 'package:three_zero_two_property/provider/color_theme.dart';
import 'package:three_zero_two_property/provider/dateProvider.dart';
import 'package:three_zero_two_property/provider/notification_provider.dart';
import 'package:three_zero_two_property/screens/Leasing/RentalRoll/RenewLease.dart';
import 'package:three_zero_two_property/services/app_date_format.dart';

/// The REAL Renew Lease pages (Admin and Staff), against a fake server, open
/// with web's default term (utils/renewalTerm.js, live on staging): the day
/// after the current term ends (the latest renewal's end, else the lease's)
/// for a year, in the company's date format. Before, mobile started ON the
/// end date (which the server refuses as an overlap) and ran one month.
///
/// Admin's End Date picker also moved the Start Date to the picked day; now
/// it sets only the end date, like web and Staff.

const _adminId = 'ADMIN-1';
final _today = DateTime.now();
final _leaseEnd = DateTime(_today.year, _today.month, _today.day + 20);

/// A renewal ending later than the lease; the term must start the day after
/// it (never on a Feb 29, so the expected year is plain date maths).
final DateTime _renewalEnd = () {
  var end = DateTime(_today.year, _today.month, _today.day + 100);
  final next = DateTime(end.year, end.month, end.day + 1);
  if (next.month == 2 && next.day == 29) end = next;
  return end;
}();
String _api(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
final _shown = DateFormat('MM/dd/yyyy');

class _Server {
  final List<http.Request> requests = [];
  late final MockClient client = MockClient((request) async {
    requests.add(request);
    final path = request.url.path;
    Object body = {'statusCode': 200, 'data': []};
    if (path == '/api/auth') {
      body = {
        'statusCode': 200,
        'themes': {'format': 'MM/DD/YYYY', 'timeFormat': '12'}
      };
    } else if (path.endsWith('/lease_summary/L-1')) {
      body = {
        'statusCode': 200,
        'data': {
          'lease_id': 'L-1',
          'tenant_id': ['T-1'],
          'admin_id': _adminId,
          'rental_id': 'R-1',
          'lease_type': 'Fixed',
          'start_date': _api(DateTime(_today.year - 1, 1, 1)),
          'end_date': _api(_leaseEnd),
          'amount': 1000,
          'rent_cycle': 'Monthly',
          'tenant_data': [],
          'renewLeases': [
            {
              'renew_id': 'RN-1',
              'lease_id': 'L-1',
              'start_date': _api(DateTime(_leaseEnd.year, _leaseEnd.month,
                  _leaseEnd.day + 1)),
              'end_date': _api(_renewalEnd),
              'is_renewed': true,
            }
          ],
        },
      };
    }
    return http.Response(jsonEncode(body), 200,
        headers: {'content-type': 'application/json'});
  });
}

Future<void> _settle(WidgetTester tester, [int ticks = 16]) async {
  for (var i = 0; i < ticks; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

List<String> _boxes(WidgetTester tester) => tester
    .widgetList<TextField>(find.byType(TextField))
    .map((f) => f.controller?.text ?? '')
    .toList();

Future<void> _open(WidgetTester tester, Widget page) async {
  tester.view.physicalSize = const Size(430, 3200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final dates = DateProvider();
  await dates.loadDateFormat();
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider<DateProvider>.value(value: dates),
      ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ChangeNotifierProvider(create: (_) => NotificationProvider()),
      ChangeNotifierProvider(create: (_) => StaffPermissionProvider()),
    ],
    child: MaterialApp(home: page),
  ));
  await _settle(tester, 40);
}

/// Opens the [i]th date field's calendar, reads its first day and the day it
/// opens on, and closes it.
Future<({DateTime first, DateTime initial})> _calendar(
    WidgetTester tester, int i) async {
  final icon = find.byIcon(Icons.date_range_rounded).at(i);
  await tester.ensureVisible(icon);
  await tester.pump();
  await tester.tap(icon);
  await _settle(tester, 10);
  final dialog = tester.widget<DatePickerDialog>(find.byType(DatePickerDialog));
  DateTime day(DateTime d) => DateTime(d.year, d.month, d.day);
  final result =
      (first: day(dialog.firstDate), initial: day(dialog.initialDate!));
  await tester.tap(find.descendant(
      of: find.byType(DatePickerDialog), matching: find.text('Cancel')));
  await _settle(tester, 10);
  return result;
}

Future<void> _run(_Server server, Future<void> Function() body) async {
  final original = FlutterError.onError;
  FlutterError.onError = (details) {
    // The test font draws every glyph as a full em square, so dense rows
    // overflow at phone width; that layout noise is ignored.
    if (details.exceptionAsString().contains('overflowed')) return;
    original?.call(details);
  };
  try {
    await http.runWithClient(body, () => server.client);
  } finally {
    FlutterError.onError = original;
  }
}

Future<void> _finish(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 2));
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 5));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('PonnamKarthik/fluttertoast'), (_) async => true);
    ConnectivityPlatform.instance = _OnlineConnectivity();
    SharedPreferences.setMockInitialValues(
        {'token': 'tkn', 'adminId': _adminId, 'role': 'Admin'});
  });

  tearDown(() => AppDateFormat.set(kDefaultAppDateFormat));

  final start =
      DateTime(_renewalEnd.year, _renewalEnd.month, _renewalEnd.day + 1);
  final end = DateTime(start.year + 1, start.month, start.day - 1);

  for (final (role, page) in [
    ('Admin', () => Renewlease(leaseId: 'L-1', enddate: _api(_leaseEnd)) as Widget),
    ('Staff', () => staff.Renewlease(leaseId: 'L-1', enddate: _api(_leaseEnd)) as Widget),
  ]) {
    testWidgets(
        '$role Renew Lease opens on web\'s term: day after the latest '
        'renewal, for a year', (tester) async {
      final server = _Server();
      await _run(server, () async {
        await _open(tester, page());
        expect(_boxes(tester),
            containsAllInOrder([_shown.format(start), _shown.format(end)]));
      });
      await _finish(tester);
    });
  }

  for (final (role, page) in [
    ('Admin', () => Renewlease(leaseId: 'L-1', enddate: _api(_leaseEnd)) as Widget),
    ('Staff', () => staff.Renewlease(leaseId: 'L-1', enddate: _api(_leaseEnd)) as Widget),
  ]) {
    testWidgets(
        '$role Renew Lease calendars: Start from the day after the lease '
        'end, End from the day after the start (web minDate)', (tester) async {
      final server = _Server();
      await _run(server, () async {
        await _open(tester, page());
        // Start Date calendar (the first calendar button).
        final startCal = await _calendar(tester, 0);
        expect(startCal.first,
            DateTime(_leaseEnd.year, _leaseEnd.month, _leaseEnd.day + 1));
        expect(startCal.initial, start, reason: 'opens on the box date');
        // End Date calendar (the second one).
        final endCal = await _calendar(tester, 1);
        expect(endCal.first, DateTime(start.year, start.month, start.day + 1));
        expect(endCal.initial, end, reason: 'opens on the box date');
      });
      await _finish(tester);
    });
  }

  testWidgets('Admin End Date picker sets only the end date (Start stays)',
      (tester) async {
    final server = _Server();
    await _run(server, () async {
      await _open(tester, Renewlease(leaseId: 'L-1', enddate: _api(_leaseEnd)));
      final startShown = _shown.format(start);
      expect(_boxes(tester), contains(startShown));

      // The End Date field's calendar button (the second one).
      final endIcon = find.byIcon(Icons.date_range_rounded).at(1);
      await tester.ensureVisible(endIcon);
      await tester.pump();
      await tester.tap(endIcon);
      await _settle(tester, 10);
      // The calendar opens on the End box's month (web: on the value).
      final pickDay = end.day == 20 ? 21 : 20;
      await tester.tap(find
          .descendant(
              of: find.byType(DatePickerDialog), matching: find.text('$pickDay'))
          .first);
      await tester.pump();
      await tester.tap(find.descendant(
          of: find.byType(DatePickerDialog), matching: find.text('OK')));
      await _settle(tester, 10);

      final picked = DateTime(end.year, end.month, pickDay);
      expect(_boxes(tester),
          containsAllInOrder([startShown, _shown.format(picked)]),
          reason: 'Start Date unchanged, End Date = the picked day');
    });
    await _finish(tester);
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

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
import 'package:three_zero_two_property/StaffModule/screen/Leasing/RentalRoll/SummeryPageLease.dart'
    as staff;
import 'package:three_zero_two_property/provider/color_theme.dart';
import 'package:three_zero_two_property/provider/dateProvider.dart';
import 'package:three_zero_two_property/provider/notification_provider.dart';
import 'package:three_zero_two_property/screens/Leasing/RentalRoll/SummeryPageLease.dart';
import 'package:three_zero_two_property/services/app_date_format.dart';

/// The lease summary's Move out popup (Admin and Staff; the wide layout,
/// over 600 wide; phones open the Move Out screen instead), driven against a
/// fake server: its date boxes show the company's date format, like web's
/// DatePicker (dateFormat={dateFormat}) and the Move Out screen, and the
/// request carries the same days as yyyy-MM-dd.
///
/// Before, the popup wrote picked dates (and Staff's notice default) as
/// dd-MM-yyyy. With a custom MM-DD-YYYY company format the save read
/// "05-10-2026" back as May 10, so days 1-12 were sent swapped.

const _adminId = 'ADMIN-1';
const _intlOf = {'MM-DD-YYYY': 'MM-dd-yyyy', 'MM/DD/YYYY': 'MM/dd/yyyy'};

final _today = DateTime.now();
final _leaseStart = DateTime(_today.year - 1, 1, 1);
final _leaseEnd = DateTime(_today.year + 1, 9, 30);
String _api(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

/// A day this month that reads differently day-first and month-first
/// ("05-10-2026"), and is not today, so a swap or a missed pick shows.
DateTime get _pickTarget {
  final day = [5, 6, 7, 3, 4]
      .firstWhere((d) => d != _today.month && d != _today.day);
  return DateTime(_today.year, _today.month, day);
}

class _Server {
  _Server(this.format);

  /// What /api/auth returns as the company date format (DateProvider).
  final String format;
  final List<http.Request> requests = [];

  late final MockClient client = MockClient((request) async {
    requests.add(request);
    final path = request.url.path;
    Object body = {'statusCode': 200, 'data': []};
    if (path == '/api/auth') {
      body = {
        'statusCode': 200,
        'themes': {'format': format, 'timeFormat': '12'}
      };
    } else if (path.endsWith('/lease_summary/L-1')) {
      body = {
        'statusCode': 200,
        'data': {
          'lease_id': 'L-1',
          'tenant_id': ['T-1'],
          'admin_id': _adminId,
          'rental_id': 'R-1',
          'unit_id': 'U-1',
          'lease_type': 'At-will(month to month)',
          'start_date': _api(_leaseStart),
          'end_date': _api(_leaseEnd),
          'rental_adress': '1 Test Street',
          'rental_unit': '',
          'amount': 1000,
          'rent_cycle': 'Monthly',
          'tenant_data': [],
        },
      };
    } else if (path.endsWith('/lease-charges/L-1')) {
      body = {'statusCode': 200, 'data': {}};
    } else if (path == '/api/tenant/leases/L-1') {
      body = {
        'statusCode': 200,
        'data': [
          {
            'lease_id': 'L-1',
            'tenant_id': 'T-1',
            'admin_id': _adminId,
            'rental_id': 'R-1',
            'unit_id': 'U-1',
            // At-will: no "Does the lease end?" question in the way.
            'lease_type': 'At-will(month to month)',
            'start_date': _api(_leaseStart),
            'end_date': _api(_leaseEnd),
            'tenant_firstName': 'Pat',
            'tenant_lastName': 'Tenant',
            'tenant_phoneNumber': '',
            'tenant_email': 'pat@example.com',
            'moveout_notice_given_date': '',
            'moveout_date': '',
            'rental_adress': '1 Test Street',
            'rental_unit': '',
            'is_evicted': false,
          }
        ],
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

/// Every value of [key] anywhere in the sent JSON.
List<Object?> _sent(http.Request r, String key) {
  final found = <Object?>[];
  void walk(Object? node) {
    if (node is Map) {
      node.forEach((k, v) {
        if (k == key) found.add(v);
        walk(v);
      });
    } else if (node is List) {
      node.forEach(walk);
    }
  }

  walk(jsonDecode(r.body));
  return found;
}

Future<void> _settle(WidgetTester tester, [int ticks = 16]) async {
  for (var i = 0; i < ticks; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pump();
  await tester.tap(f);
  await _settle(tester, 12);
}

Finder get _popup => find.byType(Dialog);

/// The popup's date boxes, in tree order: Notice Given (and Admin's
/// Move-Out).
List<String> _boxes(WidgetTester tester) => tester
    .widgetList<TextField>(
        find.descendant(of: _popup, matching: find.byType(TextField)))
    .map((f) => f.controller?.text ?? '')
    .toList();

Future<void> _pickNotice(WidgetTester tester, DateTime day) async {
  await _tap(
      tester,
      find
          .descendant(
              of: _popup, matching: find.byIcon(Icons.calendar_today_outlined))
          .first);
  await tester.tap(find
      .descendant(
          of: find.byType(DatePickerDialog), matching: find.text('${day.day}'))
      .first);
  await tester.pump();
  await tester.tap(find.descendant(
      of: find.byType(DatePickerDialog), matching: find.text('OK')));
  await _settle(tester, 10);
}

/// Opens the lease summary's Tenant tab (from the tab dropdown) and its
/// Move out popup, with the company date format loaded first (in the app it
/// is loaded at login).
Future<void> _openPopup(WidgetTester tester, Widget page) async {
  // The popup is the wide layout's Move out (isTablet: over 600 wide).
  tester.view.physicalSize = const Size(1024, 2400);
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
  await _tap(tester, find.text('Summary').first);
  await _tap(tester, find.text('Tenant').last);
  await _settle(tester, 20);
  await _tap(tester, find.text('Move out').first);
  expect(_popup, findsOneWidget, reason: 'Move out popup open');
}

Future<void> _run(_Server server, Future<void> Function() body) async {
  final original = FlutterError.onError;
  FlutterError.onError = (details) {
    // The test font draws every glyph as a full em square, so dense rows
    // overflow; and the wide layout's Lease History table sits in an
    // Expanded inside a scroll view (a debug-only check, drawn fine in
    // release). That existing layout noise is ignored.
    final error = details.exceptionAsString();
    if (error.contains('overflowed') ||
        error.contains('Incorrect use of ParentDataWidget')) {
      return;
    }
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
  await _settle(tester, 10);
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

  for (final format in ['MM-DD-YYYY', 'MM/DD/YYYY']) {
    final shown = DateFormat(_intlOf[format]);

    testWidgets(
        'Admin lease Move out popup, company $format: boxes in that format, '
        'request in yyyy-MM-dd', (tester) async {
      final server = _Server(format);
      await _run(server, () async {
        await _openPopup(tester, SummeryPageLease(leaseId: 'L-1'));

        // Notice = today, Move-Out = the lease end, both as web shows them.
        expect(_boxes(tester), [shown.format(_today), shown.format(_leaseEnd)]);

        await _pickNotice(tester, _pickTarget);
        expect(_boxes(tester).first, shown.format(_pickTarget));

        await _tap(tester, find.text('Move Out'));
        await _settle(tester, 20);
      });
      expect(server.moveouts, hasLength(1));
      final request = server.moveouts.single;
      expect(_sent(request, 'moveout_notice_given_date'),
          contains(_api(_pickTarget)),
          reason: 'the picked day, not day and month swapped');
      expect(_sent(request, 'moveout_date'), contains(_api(_leaseEnd)));
      await _finish(tester);
    });

    testWidgets(
        'Staff lease Move out popup, company $format: notice in that format, '
        'request in yyyy-MM-dd', (tester) async {
      final server = _Server(format);
      await _run(server, () async {
        await _openPopup(tester, staff.SummeryPageLease(leaseId: 'L-1'));

        // Notice defaults to today, as web shows it (was dd-MM-yyyy).
        expect(_boxes(tester), [shown.format(_today)]);
        expect(find.descendant(of: _popup, matching: find.text(shown.format(_leaseEnd))),
            findsOneWidget,
            reason: 'Move-Out Date shows the lease end in the same format');

        await _pickNotice(tester, _pickTarget);
        expect(_boxes(tester), [shown.format(_pickTarget)]);

        await _tap(tester, find.text('Move Out'));
        await _settle(tester, 20);
      });
      expect(server.moveouts, hasLength(1));
      final request = server.moveouts.single;
      expect(_sent(request, 'moveout_notice_given_date'),
          contains(_api(_pickTarget)),
          reason: 'the picked day, not day and month swapped');
      expect(_sent(request, 'moveout_date'), contains(_api(_leaseEnd)));
      await _finish(tester);
    });
  }
}

class _OnlineConnectivity extends ConnectivityPlatform
    with MockPlatformInterfaceMixin {
  @override
  Future<ConnectivityResult> checkConnectivity() async =>
      ConnectivityResult.wifi;
  @override
  Stream<ConnectivityResult> get onConnectivityChanged => const Stream.empty();
}

import 'dart:convert';
import 'dart:io';

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
import 'package:three_zero_two_property/StaffModule/screen/Leasing/RentalRoll/Move_out_lease/Moveout_lease.dart'
    as staff;
import 'package:three_zero_two_property/StaffModule/screen/Rental/Properties/moveout/Moveout_properties.dart'
    as staff_property;
import 'package:three_zero_two_property/model/LeaseSummary.dart';
import 'package:three_zero_two_property/model/properties.dart';
import 'package:three_zero_two_property/model/properties_summery.dart';
import 'package:three_zero_two_property/provider/dateProvider.dart';
import 'package:three_zero_two_property/provider/notification_provider.dart';
import 'package:three_zero_two_property/screens/Leasing/RentalRoll/Move_out_lease/Moveout_lease.dart';
import 'package:three_zero_two_property/screens/Rental/Properties/moveout/Moveout_properties.dart';
import 'package:three_zero_two_property/screens/Rental/Properties/moveout/moveout_form_ui.dart';

/// Move Out Tenants like live staging web:
/// - Address / Unit shows "address - unit" (web makeRentalAddress) on every
///   move-out screen, lease and property, Admin and Staff.
/// - The lease move-out calendars are limited like web LeaseTenantsTab /
///   RentRollDetail: Notice Given Date from lease start to lease end,
///   Move-Out Date from the notice date (else lease start) to lease end. The
///   property move-out keeps open calendars, as web PropDetails does.

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);
final _today = _day(DateTime.now());
final _leaseStart = _today.subtract(const Duration(days: 30));
final _leaseEnd = _today.add(const Duration(days: 300));
String _api(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

LeaseTenant _leaseTenant({String unit = '10'}) => LeaseTenant(
      leaseId: 'L-1',
      tenantId: 'T-1',
      adminId: 'ADMIN-1',
      rentalId: 'R-1',
      moveoutNoticeGivenDate: '',
      moveoutDate: '',
      unitId: 'U-1',
      leaseType: 'Fixed',
      startDate: _api(_leaseStart),
      endDate: _api(_leaseEnd),
      tenantFirstName: 'Pat',
      tenantLastName: 'Tenant',
      tenantPhoneNumber: '',
      tenantEmail: 'pat@example.com',
      rentalAddress: '1 Test Street',
      rentalUnit: unit,
    );

final _server = MockClient((request) async {
  Object body = {'statusCode': 200, 'data': []};
  if (request.url.path == '/api/auth') {
    body = {
      'statusCode': 200,
      'themes': {'format': 'YYYY-MM-DD', 'timeFormat': '12'}
    };
  }
  return http.Response(jsonEncode(body), 200,
      headers: {'content-type': 'application/json'});
});

Future<void> _settle(WidgetTester tester, [int ticks = 16]) async {
  for (var i = 0; i < ticks; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _open(WidgetTester tester, Widget Function() page) async {
  tester.view.physicalSize = const Size(430, 3200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final dates = DateProvider();
  await dates.loadDateFormat();
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider<DateProvider>.value(value: dates),
      ChangeNotifierProvider(create: (_) => NotificationProvider()),
      ChangeNotifierProvider(create: (_) => StaffPermissionProvider()),
    ],
    child: MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => page())),
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

/// Opens the [i]-th date field's calendar and returns its range, then closes
/// it without picking.
Future<(DateTime, DateTime)> _calendarRange(WidgetTester tester, int i) async {
  final icon = find.byIcon(Icons.calendar_today_outlined).at(i);
  await tester.ensureVisible(icon);
  await tester.pump();
  await tester.tap(icon);
  await _settle(tester, 10);
  final dialog = tester.widget<DatePickerDialog>(find.byType(DatePickerDialog));
  final range = (_day(dialog.firstDate), _day(dialog.lastDate));
  await tester.tap(find.descendant(
      of: find.byType(DatePickerDialog), matching: find.text('Cancel')));
  await _settle(tester, 10);
  return range;
}

Future<void> _run(Future<void> Function() body) async {
  final original = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.exceptionAsString().contains('overflowed')) return;
    original?.call(details);
  };
  try {
    await http.runWithClient(body, () => _server);
  } finally {
    FlutterError.onError = original;
  }
}

Future<void> _finish(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 2));
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

  group('moveoutAddressLine (web makeRentalAddress)', () {
    test('address and unit → "address - unit"', () {
      expect(moveoutAddressLine('2596 Watson Street', '10'),
          '2596 Watson Street - 10');
    });
    test('no unit → address alone', () {
      for (final u in [null, '', '  ', '-', 'null', 'undefined']) {
        expect(moveoutAddressLine('2596 Watson Street', u), '2596 Watson Street',
            reason: 'unit "$u"');
      }
    });
    test('unit that already holds the address is shown as is', () {
      expect(moveoutAddressLine('12 Main St', '12 Main St Apt 4'),
          '12 Main St Apt 4');
    });
    test('no address → empty, as web', () {
      expect(moveoutAddressLine(null, '10'), '');
      expect(moveoutAddressLine('', '10'), '');
    });
  });

  group('property Address / Unit (web PropDetails getStreetLine + unit)', () {
    // Expected values produced by running web's own getStreetLine
    // (Client/src/utils/propertyAddress.js) on these inputs.
    const web = {
      '562 E Wheatland Rd, Duncanville, TX 75137, USA': '562 E Wheatland Rd',
      '2596 Watson Street': '2596 Watson Street',
      '123 Main St, Apt 4, TX 75137, USA': '123 Main St, Apt 4',
      '10 Downing St, London': '10 Downing St, London',
      'PO Box 12, Austin, TX 78701-1234, United States': 'PO Box 12',
      '1 A St, Springfield, IL 62701': '1 A St',
      '5 Oak Ave, Suite 200, Dallas, TX 75201, US': '5 Oak Ave, Suite 200',
      '77 Pine Rd, , ': '77 Pine Rd',
      '9 Elm St, Plano, Texas 75023, USA': '9 Elm St, Plano, Texas 75023',
      '': '',
    };
    test('street line matches web on every sample', () {
      web.forEach((input, out) =>
          expect(moveoutStreetLine(input), out, reason: input));
    });
    test('street line, then "- unit" when the lease has one', () {
      expect(
          moveoutPropertyAddressLine(
              '562 E Wheatland Rd, Duncanville, TX 75137, USA', '4'),
          '562 E Wheatland Rd - 4');
      expect(moveoutPropertyAddressLine('2596 Watson Street', '10'),
          '2596 Watson Street - 10');
      for (final u in [null, '', '-', 'null']) {
        expect(moveoutPropertyAddressLine('2596 Watson Street', u),
            '2596 Watson Street',
            reason: 'unit "$u"');
      }
    });
  });

  group('moveoutPickerRange (web lease move-out limits)', () {
    test('limits to the given bounds and opens on the shown date', () {
      final r = moveoutPickerRange('2026-11-15',
          minDate: '2026-02-01', maxDate: '2027-02-28');
      expect(r.first, DateTime(2026, 2, 1));
      expect(r.last, DateTime(2027, 2, 28));
      expect(r.initial, DateTime(2026, 11, 15));
    });
    test('a shown date outside the range opens on the nearest end', () {
      expect(
          moveoutPickerRange('2026-01-10',
                  minDate: '2026-02-01', maxDate: '2027-02-28')
              .initial,
          DateTime(2026, 2, 1));
      expect(
          moveoutPickerRange('2028-05-01',
                  minDate: '2026-02-01', maxDate: '2027-02-28')
              .initial,
          DateTime(2027, 2, 28));
    });
    test('no bounds → open calendar, as before', () {
      final r = moveoutPickerRange('2026-11-15');
      expect(r.first, DateTime(2000));
      expect(r.last, DateTime(2101));
    });
    test('a start after the end never breaks the calendar', () {
      final r = moveoutPickerRange('2026-11-15',
          minDate: '2027-03-10', maxDate: '2027-02-28');
      expect(r.first, DateTime(2027, 2, 28));
      expect(r.last, DateTime(2027, 2, 28));
      expect(r.initial, DateTime(2027, 2, 28));
    });
    test('earliest move-out = notice date, else lease start', () {
      expect(moveoutMinMoveOutDate('2026-10-27', '2026-02-01'), '2026-10-27');
      expect(moveoutMinMoveOutDate('', '2026-02-01'), '2026-02-01');
    });
  });

  for (final (role, build) in [
    (
      'Admin',
      () => MoveoutScreen(
            tenant: _leaseTenant(),
            tenants: [_leaseTenant()],
            enddate: _api(_leaseEnd),
            moveOutDate: '',
            leaseId: 'L-1',
          ) as Widget
    ),
    (
      'Staff',
      () => staff.MoveoutScreen(
            tenant: _leaseTenant(),
            tenants: [_leaseTenant()],
            enddate: _api(_leaseEnd),
            moveOutDate: '',
            leaseId: 'L-1',
          ) as Widget
    ),
  ]) {
    testWidgets(
        '$role lease move-out: "address - unit" and web date limits',
        (tester) async {
      await _run(() async {
        await _open(tester, build);
        expect(find.text('1 Test Street - 10'), findsOneWidget);

        // Notice Given Date: lease start to lease end.
        final notice = await _calendarRange(tester, 0);
        expect(notice, (_leaseStart, _leaseEnd));

        // Move-Out Date: the notice date (today by default) to lease end.
        final moveOut = await _calendarRange(tester, 1);
        expect(moveOut, (_today, _leaseEnd));

        // Pick another Notice date: the Move-Out calendar now starts there.
        final newNotice = _today.day == 1
            ? _today.add(const Duration(days: 1))
            : DateTime(_today.year, _today.month, 1);
        await _pickDay(tester, 0, newNotice);
        expect(await _calendarRange(tester, 1), (newNotice, _leaseEnd));
      });
      await _finish(tester);
    });
  }

  for (final (role, build) in [
    ('Admin', (TenantData t) => Moveout_properties(
          properties: Rentals(
              rentalId: 'R-1',
              rentalAddress: '562 E Wheatland Rd, Duncanville, TX 75137, USA'),
          tenants: [t],
          tenant: t,
          moveOutDate: '',
          leaseId: 'L-1',
        ) as Widget),
    ('Staff', (TenantData t) => staff_property.Moveout_properties(
          properties: Rentals(
              rentalId: 'R-1',
              rentalAddress: '562 E Wheatland Rd, Duncanville, TX 75137, USA'),
          tenants: [t],
          tenant: t,
          moveOutDate: '',
          leaseId: 'L-1',
        ) as Widget),
  ]) {
    testWidgets(
        '$role property move-out: street line - unit, calendars open like web',
        (tester) async {
      await _run(() async {
        final t = TenantData(
          tenantId: ['T-1'],
          adminId: 'ADMIN-1',
          firstName: 'Pat',
          lastName: 'Tenant',
          leaseId: 'L-1',
          rentalId: 'R-1',
          unitId: 'U-1',
          leaseType: 'Fixed',
          startDate: _api(_leaseStart),
          endDate: _api(_leaseEnd),
          rentalUnit: '4',
        );
        await _open(tester, () => build(t));
        expect(find.text('562 E Wheatland Rd - 4'), findsOneWidget);
        expect(
            await _calendarRange(tester, 0), (DateTime(2000), DateTime(2101)));
      });
      await _finish(tester);
    });
  }

  test('every move-out screen passes the right address, unit and limits', () {
    // The source with comments dropped and whitespace collapsed, so the
    // checks read the real arguments at each call site.
    String flat(String p) => File(p)
        .readAsStringSync()
        .replaceAll(RegExp(r'//[^\n]*'), '')
        .replaceAll(RegExp(r'\s+'), ' ');
    const leasePages = [
      'lib/screens/Leasing/RentalRoll/Move_out_lease/Moveout_lease.dart',
      'lib/StaffModule/screen/Leasing/RentalRoll/Move_out_lease/Moveout_lease.dart',
    ];
    const adminPopup = 'lib/screens/Leasing/RentalRoll/SummeryPageLease.dart';
    const staffPopup =
        'lib/StaffModule/screen/Leasing/RentalRoll/SummeryPageLease.dart';
    const propertyPages = [
      'lib/screens/Rental/Properties/moveout/Moveout_properties.dart',
      'lib/StaffModule/screen/Rental/Properties/moveout/Moveout_properties.dart',
    ];

    for (final p in [...leasePages, adminPopup, staffPopup]) {
      final s = flat(p);
      expect(s,
          contains('address: moveoutAddressLine(tenant.rentalAddress, tenant.rentalUnit)'),
          reason: p);
      expect(
          s,
          contains('final range = moveoutPickerRange(controller.text, '
              'minDate: minDate?.call(), maxDate: maxDate); '
              'DateTime? pickedDate = await showDatePicker( context: context, '
              'initialDate: range.initial, firstDate: range.first, '
              'lastDate: range.last,'),
          reason: p);
    }
    for (final p in propertyPages) {
      expect(
          flat(p),
          contains('address: moveoutPropertyAddressLine( '
              'widget.properties.rentalAddress, tenant.rentalUnit)'),
          reason: p);
    }
    // Lease page + Admin popup: both calendars get web's limits.
    for (final p in [...leasePages, adminPopup]) {
      final s = flat(p);
      expect(
          s,
          contains('noticeField: buildDateField( '
              'startDateControllers[tenant.tenantId]!, '
              'enabled: tenant.isSelected!, '
              'minDate: () => leaseTenant.startDate, '
              'maxDate: leaseTenant.endDate,'),
          reason: '$p notice limits');
      expect(
          s,
          contains('moveOutField: buildDateField( '
              'moveoutDateControllers[tenant.tenantId]!, '
              'enabled: tenant.isSelected!, '
              'minDate: () => moveoutMinMoveOutDate( '
              'startDateControllers[tenant.tenantId]!.text, '
              'leaseTenant.startDate), '
              'maxDate: leaseTenant.endDate,'),
          reason: '$p move-out limits');
    }
    // Staff popup: its Move-Out date is a fixed field; the Notice calendar
    // gets web's limits.
    expect(
        flat(staffPopup),
        contains('noticeField: buildDateField(startdateController, '
            'minDate: () => tenant.startDate, maxDate: tenant.endDate),'),
        reason: 'Staff popup notice limits');
  });
}

/// Opens the [i]-th date field's calendar and picks [day] (in the month the
/// calendar opens on).
Future<void> _pickDay(WidgetTester tester, int i, DateTime day) async {
  final icon = find.byIcon(Icons.calendar_today_outlined).at(i);
  await tester.ensureVisible(icon);
  await tester.pump();
  await tester.tap(icon);
  await _settle(tester, 10);
  await tester.tap(find
      .descendant(
          of: find.byType(DatePickerDialog), matching: find.text('${day.day}'))
      .first);
  await tester.pump();
  await tester.tap(find.descendant(
      of: find.byType(DatePickerDialog), matching: find.text('OK')));
  await _settle(tester, 10);
}

class _OnlineConnectivity extends ConnectivityPlatform
    with MockPlatformInterfaceMixin {
  @override
  Future<ConnectivityResult> checkConnectivity() async =>
      ConnectivityResult.wifi;
  @override
  Stream<ConnectivityResult> get onConnectivityChanged => const Stream.empty();
}

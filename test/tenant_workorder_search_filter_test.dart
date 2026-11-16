import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus_platform_interface/connectivity_plus_platform_interface.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:three_zero_two_property/TenantsModule/model/workorder_model.dart';
import 'package:three_zero_two_property/TenantsModule/repository/permission_provider.dart';
import 'package:three_zero_two_property/TenantsModule/screen/work_order/workorder_table.dart';
import 'package:three_zero_two_property/provider/dateProvider.dart';
import 'package:three_zero_two_property/provider/notification_provider.dart';

/// Tenant → Work Orders list search and status filter, like web staging
/// (TenantWork.jsx): the search box matches the subject, category, status,
/// "address unit", assigned staff, priority and work order number; the
/// status filter is All, Open, New, In Progress, On Hold, Completed,
/// Over Due, Closed, where "Open" is everything not Completed or Closed and
/// "Over Due" is due before today and not finished. The phone and wide
/// layouts behave the same. Before, the number, priority and unit weren't
/// searchable, "Open" was missing, the wide layout searched only the subject
/// and address, and its "Over Due" always showed nothing.

const _webOrder = [
  'All',
  'Open',
  'New',
  'In Progress',
  'On Hold',
  'Completed',
  'Over Due',
  'Closed',
];

final _today = DateTime(2026, 11, 16, 15, 30);

WorkOrder _wo({
  String subject = 'Subject',
  String category = 'General',
  String status = 'New',
  String priority = 'Low',
  String number = '1',
  String address = '1 Main St',
  String unit = '',
  String? staff,
  String date = '',
  bool billable = false,
  String createdAt = '2026-10-01',
}) =>
    WorkOrder(
      workSubject: subject,
      workCategory: category,
      status: status,
      priority: priority,
      ticketNumber: number,
      rentalAddress: address,
      rentalUnit: unit,
      staffMemberName: staff,
      date: date,
      isBillable: billable,
      createdAt: createdAt,
    );

void main() {
  group('helpers, like web', () {
    test('status options are web\'s, in web\'s order, with "Open"', () {
      expect(tenantWorkOrderStatusOptions, _webOrder);
    });

    test('search matches every field web searches, ignoring case', () {
      final w = _wo(
        subject: 'Leaky tap',
        category: 'Plumbing',
        status: 'In Progress',
        priority: 'High',
        number: '1003',
        address: '123 Main St',
        unit: 'B2',
        staff: 'Pat Staff',
      );
      for (final q in [
        '1003', // work order number
        'high', // priority
        'b2', // unit
        '123 main st b2', // "address unit", as web joins them
        'leaky', // subject
        'plumb', // category
        'progress', // status
        'main st', // address
        'pat', // assigned staff
      ]) {
        expect(workOrderMatchesSearch(w, q), isTrue, reason: q);
      }
      expect(workOrderMatchesSearch(w, ''), isTrue, reason: 'no search');
      expect(workOrderMatchesSearch(w, 'roof'), isFalse);
    });

    test('search no longer matches what web does not search', () {
      final w = _wo(billable: true, createdAt: '2026-10-01');
      expect(workOrderMatchesSearch(w, 'true'), isFalse,
          reason: 'billable flag');
      expect(workOrderMatchesSearch(w, '2026-10-01'), isFalse,
          reason: 'created date');
      expect(workOrderMatchesSearch(_wo(), 'n/a'), isFalse,
          reason: 'nobody assigned');
    });

    test('"Open" is everything not Completed or Closed', () {
      bool open(String status) =>
          workOrderMatchesStatus(_wo(status: status), 'Open', today: _today);
      expect(open('New'), isTrue);
      expect(open('In Progress'), isTrue);
      expect(open('On Hold'), isTrue);
      expect(open('Completed'), isFalse);
      expect(open('Closed'), isFalse);
      expect(open(' Closed '), isFalse, reason: 'web trims the status');
    });

    test('"Over Due" is due before today and not finished', () {
      bool overdue(String date, [String status = 'New']) =>
          workOrderMatchesStatus(_wo(date: date, status: status), 'Over Due',
              today: _today);
      expect(overdue('2026-11-15'), isTrue, reason: 'yesterday');
      expect(overdue('2026-11-16'), isFalse, reason: 'due today');
      expect(overdue('2026-11-17'), isFalse, reason: 'tomorrow');
      expect(overdue('2026-11-15', 'Completed'), isFalse);
      expect(overdue('2026-11-15', 'Closed'), isFalse);
      expect(overdue('2026-11-15', 'On Hold'), isTrue);
      expect(overdue(''), isFalse, reason: 'no due date');
      expect(overdue('not a date'), isFalse);
      expect(overdue('2026-11-15T00:00:00.000Z'), isTrue,
          reason: 'read as the calendar day, not shifted by time zone');
      expect(overdue('11/15/2026'), isTrue);
      expect(overdue('2026/11/15'), isTrue);
    });

    test('a due date that does not exist is not a date', () {
      expect(workOrderDueDay('2026-02-30'), isNull);
      expect(workOrderDueDay('2026-11-15'), DateTime(2026, 11, 15));
      expect(workOrderDueDay(null), isNull);
    });

    test('other statuses, "All" and no choice', () {
      final w = _wo(status: 'In Progress');
      expect(workOrderMatchesStatus(w, 'In Progress', today: _today), isTrue);
      expect(workOrderMatchesStatus(w, 'New', today: _today), isFalse);
      expect(workOrderMatchesStatus(w, 'All', today: _today), isTrue);
      expect(workOrderMatchesStatus(w, null, today: _today), isTrue);
    });

    test('the status filter and the search work together', () {
      final list = [
        _wo(subject: 'Leaky tap', status: 'New'),
        _wo(subject: 'Leaky pipe', status: 'Closed'),
        _wo(subject: 'Door', status: 'New'),
      ];
      final result = filterTenantWorkOrders(list,
          status: 'Open', search: 'leaky', today: _today);
      expect(result.map((w) => w.workSubject), ['Leaky tap']);
    });
  });

  test('both layouts use the same web filter and search', () {
    final src = File('lib/TenantsModule/screen/work_order/workorder_table.dart')
        .readAsStringSync();
    expect('filterTenantWorkOrders('.allMatches(src).length, 2,
        reason: 'phone and wide lists');
    expect(src, isNot(contains('property.status == selectedValue')),
        reason: '"Over Due" was matched as a status name on wide screens');
    expect(src, contains('items = tenantWorkOrderStatusOptions'));
  });

  group('on the tenant Work Orders screen', () {
    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
              const MethodChannel('PonnamKarthik/fluttertoast'),
              (_) async => true);
      ConnectivityPlatform.instance = _Online();
      SharedPreferences.setMockInitialValues({
        'token': 'tkn',
        'tenant_id': 'T-1',
        'adminId': 'ADMIN-1',
        'role': 'Tenant',
      });
    });

    for (final width in [430.0, 900.0]) {
      final layout = width < 500 ? 'phone' : 'wide';

      testWidgets('$layout: search by number, priority and unit; web\'s '
          'status options; Open and Over Due', (tester) async {
        await _run(tester, width, () async {
          // Web's options, in web's order.
          final dropdown = tester.widget<DropdownButton2<String>>(
              find.byType(DropdownButton2<String>));
          expect(dropdown.items!.map((i) => i.value).toList(), _webOrder);

          final search = find
              .byWidgetPredicate((w) =>
                  w is TextField && w.decoration?.hintText == 'Search here...')
              .first;
          Future<void> searchFor(String text) async {
            await tester.enterText(search, text);
            await _settle(tester, 10);
          }

          void shows(List<String> visible) {
            for (final s in _subjects) {
              expect(find.text(s),
                  visible.contains(s) ? findsWidgets : findsNothing,
                  reason: '$layout: $s');
            }
          }

          shows(_subjects);
          await searchFor('1003');
          shows(['Door squeak']);
          await searchFor('high');
          shows(['Leaky tap']);
          await searchFor('b2');
          shows(['Door squeak']);
          await searchFor('');
          shows(_subjects);

          Future<void> choose(String status) async {
            tester
                .widget<DropdownButton2<String>>(
                    find.byType(DropdownButton2<String>))
                .onChanged!(status);
            await _settle(tester, 10);
          }

          await choose('Open');
          shows(['Leaky tap', 'Door squeak']);
          await choose('Over Due');
          shows(['Leaky tap'],);
          await choose('Closed');
          shows(['Window crack']);
          await choose('All');
          shows(_subjects);

          // Filter and search together.
          await choose('Open');
          await searchFor('door');
          shows(['Door squeak']);
        });
      });
    }
  });
}

const _subjects = ['Leaky tap', 'Broken fence', 'Door squeak', 'Window crack'];

final _server = MockClient((request) async {
  Object body = {'statusCode': 200, 'data': []};
  if (request.url.path == '/api/permission/permission/ADMIN-1') {
    body = {
      'statusCode': 200,
      'data': {
        // The screen reads permissions!.workorderAdd in build, and the
        // permission model needs every key.
        'tenant_permission': {
          'property_view': true,
          'financial_view': true,
          'financial_add': true,
          'financial_edit': true,
          'workorder_view': true,
          'workorder_add': true,
          'workorder_edit': true,
          'documents_view': true,
          'documents_add': true,
          'documents_edit': true,
        }
      }
    };
  } else if (request.url.path == '/api/work-order/tenant_work/T-1') {
    body = {
      'statusCode': 200,
      'data': [
        {
          'workOrder_id': 'WO-1',
          'ticket_number': '1001',
          'work_subject': 'Leaky tap',
          'work_category': 'Plumbing',
          'priority': 'High',
          'status': 'New',
          'rental_adress': '123 Main St',
          'rental_unit': '101',
          'staffmember_name': 'Pat Staff',
          'createdAt': '2020-01-01',
          'date': '2020-01-10', // long past and still New: overdue
        },
        {
          'workOrder_id': 'WO-2',
          'ticket_number': '1002',
          'work_subject': 'Broken fence',
          'work_category': 'General',
          'priority': 'Low',
          'status': 'Completed',
          'rental_adress': '9 Oak Ave',
          'rental_unit': '',
          'createdAt': '2020-01-02',
          'date': '2020-01-10', // past, but finished: not overdue
        },
        {
          'workOrder_id': 'WO-3',
          'ticket_number': '1003',
          'work_subject': 'Door squeak',
          'work_category': 'Carpentry',
          'priority': 'Medium',
          'status': 'In Progress',
          'rental_adress': '77 Pine Rd',
          'rental_unit': 'B2',
          'createdAt': '2020-01-03',
          'date': '2099-01-01', // not due yet
        },
        {
          'workOrder_id': 'WO-4',
          'ticket_number': '1004',
          'work_subject': 'Window crack',
          'work_category': 'General',
          'priority': 'Low',
          'status': 'Closed',
          'rental_adress': '5 Elm St',
          'rental_unit': '',
          'createdAt': '2020-01-04',
          'date': '2020-01-10',
        },
      ],
    };
  }
  return http.Response(jsonEncode(body), 200,
      headers: {'content-type': 'application/json'});
});

Future<void> _run(WidgetTester tester, double width,
    Future<void> Function() body) async {
  tester.view.physicalSize = Size(width, 4000);
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
      final perms = PermissionProvider();
      await perms.fetchPermissions();
      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<DateProvider>.value(value: dates),
          ChangeNotifierProvider<PermissionProvider>.value(value: perms),
          ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ],
        child: MaterialApp(home: Scaffold(body: WorkOrderTable())),
      ));
      await _settle(tester);
      await body();
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    }, () => _server);
  } finally {
    FlutterError.onError = original;
  }
}

Future<void> _settle(WidgetTester tester, [int ticks = 40]) async {
  for (var i = 0; i < ticks; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

class _Online extends ConnectivityPlatform with MockPlatformInterfaceMixin {
  @override
  Future<ConnectivityResult> checkConnectivity() async =>
      ConnectivityResult.wifi;
  @override
  Stream<ConnectivityResult> get onConnectivityChanged => const Stream.empty();
}

import 'dart:async';
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
import 'package:three_zero_two_property/StaffModule/repository/staffpermission_provider.dart';
import 'package:three_zero_two_property/StaffModule/screen/Rental/Properties/Property Tax/Property_tax_Table.dart'
    as staff_tax;
import 'package:three_zero_two_property/StaffModule/screen/Rental/mortgage/mortgageTable.dart'
    as staff_list;
import 'package:three_zero_two_property/StaffModule/screen/Rental/mortgage/property_mortgage_table.dart'
    as staff_prop;
import 'package:three_zero_two_property/provider/dateProvider.dart';
import 'package:three_zero_two_property/provider/notification_provider.dart';
import 'package:three_zero_two_property/screens/Rental/Properties/Property Tax/Property_tax_Table.dart'
    as admin_tax;
import 'package:three_zero_two_property/screens/Rental/mortgage/mortgageTable.dart'
    as admin_list;
import 'package:three_zero_two_property/screens/Rental/mortgage/mortgage_summery.dart';
import 'package:three_zero_two_property/screens/Rental/mortgage/property_mortgage_table.dart'
    as admin_prop;

/// When the Mortgage and Property Tax screens can't load, web (staging and
/// production: Mortgage.jsx, PropDetails.jsx, MortgageDetails.jsx) shows an
/// empty list and an error — never made-up rows. These screens used to fill
/// the list with sample mortgages ("Test Bank", "City Bank") and sample tax
/// rows on any failure, so a user could take them for real data.

const _realLender = 'Real Lender';

/// How the fake server answers every request.
enum _Mode { ok, serverError, expiredSession, brokenReply }

class _Server {
  _Server(this.mode);
  final _Mode mode;

  late final MockClient client = MockClient((request) async {
    switch (mode) {
      case _Mode.serverError:
        return http.Response('{}', 500);
      case _Mode.expiredSession:
        return http.Response('{"message":"Unauthorized"}', 401);
      case _Mode.brokenReply:
        return http.Response('<html>gateway error</html>', 200);
      case _Mode.ok:
        break;
    }
    final path = request.url.path;
    Object body = {'statusCode': 200, 'success': true, 'data': []};
    if (path.startsWith('/api/mortgage/details/')) {
      // The details call returns the properties expanded.
      body = {
        'statusCode': 200,
        'success': true,
        'data': {
          ..._mortgage,
          'properties': [
            {'rental_id': 'R-1', 'rental_adress': '1 Test Street'}
          ],
        }
      };
    } else if (path.startsWith('/api/mortgage/')) {
      body = {
        'statusCode': 200,
        'success': true,
        'data': [_mortgage]
      };
    } else if (path.startsWith('/api/taxes/')) {
      body = {
        'statusCode': 200,
        'success': true,
        'data': [
          {
            '_id': 'TAX-1',
            'rental_id': 'R-1',
            'tax_year': '2021',
            'amount': 1234,
            'status': 'paid',
          }
        ]
      };
    }
    return http.Response(jsonEncode(body), 200,
        headers: {'content-type': 'application/json'});
  });
}

final _mortgage = {
  '_id': 'M-1',
  'properties': ['R-1'],
  'bank_name': _realLender,
  'mortgage_no': '5959',
  'borrower_first_name': 'Pat',
  'borrower_last_name': 'Realowner',
  'loan_amount': 100,
  'interest_rate': 1,
  'status': 'active',
  'remaining_balance': 5,
  'start_date': '2026-01-01T00:00:00.000Z',
  'end_date': '2030-01-01T00:00:00.000Z',
};

Future<void> _settle(WidgetTester tester, [int ticks = 20]) async {
  for (var i = 0; i < ticks; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _pump(WidgetTester tester, Widget screen) async {
  tester.view.physicalSize = const Size(1080, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final permissions = StaffPermissionProvider();
  await permissions.fetchPermissions();
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => DateProvider()),
      ChangeNotifierProvider(create: (_) => NotificationProvider()),
      ChangeNotifierProvider<StaffPermissionProvider>.value(value: permissions),
    ],
    child: MaterialApp(home: Scaffold(body: screen)),
  ));
  await _settle(tester, 30);
}

/// Lets snack bars and pending timers finish before teardown.
Future<void> _finish(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
  await _settle(tester, 10);
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 2));
}

/// The test font draws every glyph as a full em square, so dense rows
/// overflow here; that layout noise is ignored.
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

void _expectNoSampleRows() {
  expect(find.textContaining('Test Bank'), findsNothing);
  expect(find.textContaining('City Bank'), findsNothing);
  expect(find.textContaining('3322332'), findsNothing); // sample mortgage no.
}

class _Case {
  const _Case(this.name, this.prefs, this.build, this.emptyText, this.realText);
  final String name;
  final Map<String, Object> prefs;
  final Widget Function() build;
  final String emptyText;
  final String realText;
}

const Map<String, Object> _adminPrefs = {
  'token': 'tkn',
  'adminId': 'ADMIN-1',
  'role': 'Admin',
};

const Map<String, Object> _staffPrefs = {
  'token': 'tkn',
  'adminId': 'ADMIN-1',
  'role': 'Staffmember',
  'staff_id': 'STAFF-1',
};

final _cases = <_Case>[
  _Case('Admin Mortgages list', _adminPrefs, () => const admin_list.MortgageTable(),
      'No mortgages found', _realLender),
  _Case('Staff Mortgages list', _staffPrefs, () => const staff_list.MortgageTable(),
      'No mortgages found', _realLender),
  _Case('Admin property Mortgage tab', _adminPrefs,
      () => const admin_prop.PropertyMortgageTable(propertyId: 'R-1'),
      'No mortgages found for this property', 'Realowner'),
  _Case('Staff property Mortgage tab', _staffPrefs,
      () => const staff_prop.PropertyMortgageTable(propertyId: 'R-1'),
      'No mortgages found for this property', 'Realowner'),
  _Case('Admin property Tax tab', _adminPrefs,
      () => const admin_tax.Property_tax_Table(propertyId: 'R-1'),
      'No tax records available.', '2021'),
  _Case('Staff property Tax tab', _staffPrefs,
      () => const staff_tax.Property_tax_Table(propertyId: 'R-1'),
      'No tax records available.', '2021'),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('PonnamKarthik/fluttertoast'), (_) async => true);
    ConnectivityPlatform.instance = _OnlineConnectivity();
  });

  for (final c in _cases) {
    group(c.name, () {
      for (final mode in [
        _Mode.serverError,
        _Mode.expiredSession,
        _Mode.brokenReply
      ]) {
        testWidgets('${mode.name}: empty list, no made-up rows',
            (tester) async {
          SharedPreferences.setMockInitialValues(c.prefs);
          await _run(_Server(mode), () async {
            await _pump(tester, c.build());
            _expectNoSampleRows();
            expect(find.textContaining(c.emptyText), findsOneWidget,
                reason: 'web shows its empty-list line');
            await _finish(tester);
          });
        });
      }

      testWidgets('loads normally: real data shows', (tester) async {
        SharedPreferences.setMockInitialValues(c.prefs);
        await _run(_Server(_Mode.ok), () async {
          await _pump(tester, c.build());
          expect(find.textContaining(c.realText), findsWidgets);
          expect(find.textContaining(c.emptyText), findsNothing);
          _expectNoSampleRows();
          await _finish(tester);
        });
      });
    });
  }

  group('Mortgage Summary', () {
    testWidgets('failed load: error message, no made-up mortgage',
        (tester) async {
      SharedPreferences.setMockInitialValues(_adminPrefs);
      await _run(_Server(_Mode.brokenReply), () async {
        await _pump(tester, MortgageSummary(mortgageData: {'_id': 'M-1'}));
        _expectNoSampleRows();
        expect(find.text('Error loading mortgage details. Please try again.'),
            findsOneWidget);
        expect(find.text('No mortgage data available'), findsOneWidget);
        await _finish(tester);
      });
    });

    testWidgets('loads normally: the real mortgage shows', (tester) async {
      SharedPreferences.setMockInitialValues(_adminPrefs);
      await _run(_Server(_Mode.ok), () async {
        await _pump(tester, MortgageSummary(mortgageData: {'_id': 'M-1'}));
        expect(find.textContaining(_realLender), findsWidgets);
        _expectNoSampleRows();
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

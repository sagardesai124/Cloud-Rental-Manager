import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus_platform_interface/connectivity_plus_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:three_zero_two_property/Model/Recurring_Payments_Configuration_model.dart';
import 'package:three_zero_two_property/StaffModule/repository/staffpermission_provider.dart';
import 'package:three_zero_two_property/StaffModule/screen/Reports/ReportScreens/Recurring_Payments_Configuration_table.dart'
    as s_rec;
import 'package:three_zero_two_property/provider/dateProvider.dart';
import 'package:three_zero_two_property/provider/notification_provider.dart';
import 'package:three_zero_two_property/screens/Reports/ReportScreens/Recurring_Payments_Configuration_table.dart'
    as a_rec;
import 'package:three_zero_two_property/services/recurring_payments_search.dart';

/// The Recurring Payments Configuration search did nothing: typing never
/// narrowed the list (Admin and Staff). It now searches like web
/// (Recurring-Payment-Report/Report.jsx handleSearch).

Map<String, dynamic> _property(String address, String unit, String tenant,
        {int day = 5, num amount = 100, String account = 'xxxx4242'}) =>
    {
      'rental_id': 'R-$address',
      'rental_adress': address,
      'rentalSubtotal': amount,
      'leases': [
        {
          'lease_id': 'L-$address',
          'end_date': '2027-02-28',
          'rental_adress': address,
          'rental_unit': unit,
          'tenants': [
            {
              'tenant_id': 'T-$tenant',
              'tenant_name': tenant,
              'recurrings': [
                {
                  'date': day,
                  'amount': amount,
                  'account': account,
                  'card_type': 'Visa',
                }
              ],
            }
          ],
        }
      ],
    };

final _reply = {
  'statusCode': 200,
  'grandTotal': 112.5,
  'data': [
    _property('2596 Watson Street', 'A1', 'Ruth Parker'),
    _property('18 Oak Lane', 'B2', 'Sam Lee',
        day: 17, amount: 12.5, account: 'xxxx9999'),
  ],
};

List<Data> get _data => Recurring_Payments_Configuration.fromJson(
        jsonDecode(jsonEncode(_reply)) as Map<String, dynamic>)
    .data!;

List<String> _found(String search) => filterRecurringPayments(_data, search)
    .map((p) => p.rentalAdress!)
    .toList();

void main() {
  group("web's search fields", () {
    test('property address and unit', () {
      expect(_found('watson'), ['2596 Watson Street']);
      expect(_found('B2'), ['18 Oak Lane']);
    });

    test('tenant name, case-insensitive, trimmed', () {
      expect(_found('  RUTH  '), ['2596 Watson Street']);
      expect(_found('sam lee'), ['18 Oak Lane']);
    });

    test("recurring payment's day, account and amount", () {
      expect(_found('17'), ['18 Oak Lane']);
      expect(_found('9999'), ['18 Oak Lane']);
      expect(_found('12.5'), ['18 Oak Lane']);
      // Whole amounts read like web's (100, not 100.0).
      expect(_found('100'), ['2596 Watson Street']);
      expect(_found('100.0'), isEmpty);
    });

    test('empty search keeps everything; no match keeps nothing', () {
      expect(_found(''), hasLength(2));
      expect(_found('   '), hasLength(2));
      expect(_found('zzzz'), isEmpty);
    });
  });

  for (final path in [
    'lib/screens/Reports/ReportScreens/Recurring_Payments_Configuration_table.dart',
    'lib/StaffModule/screen/Reports/ReportScreens/Recurring_Payments_Configuration_table.dart',
  ]) {
    test('screen wiring: $path', () {
      final src = File(path).readAsStringSync();
      expect(src, isNot(contains('// searchvalue = value;')));
      expect(src, contains('searchvalue = value;'));
      expect(src, contains('children: _visibleData'));
      expect(
          RegExp(r'if \(_visibleData\.isEmpty\)\s*kNoSearchResults\(context\),')
              .hasMatch(src),
          isTrue);
      // Export keeps the full list, like web.
      expect(src, contains('recurringPaymentsConfiguration!.data!, dateProvider'));
    });
  }

  group('on the screen', () {
    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
              const MethodChannel('PonnamKarthik/fluttertoast'),
              (_) async => true);
      ConnectivityPlatform.instance = _OnlineConnectivity();
    });

    for (final staff in [false, true]) {
      testWidgets('${staff ? 'Staff' : 'Admin'}: typing narrows the list',
          (tester) async {
        SharedPreferences.setMockInitialValues({
          'token': 'tkn',
          'adminId': 'ADMIN-1',
          'role': staff ? 'Staffmember' : 'Admin',
          if (staff) 'staff_id': 'STAFF-1',
        });
        final server = MockClient((request) async {
          final body = request.url.path.contains('recurring-payment-configuration')
              ? _reply
              : {'statusCode': 200, 'success': true, 'data': []};
          return http.Response(jsonEncode(body), 200,
              headers: {'content-type': 'application/json'});
        });
        await http.runWithClient(() async {
          tester.view.physicalSize = const Size(1080, 4000);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);
          final permissions = StaffPermissionProvider();
          await permissions.fetchPermissions();
          final original = FlutterError.onError;
          FlutterError.onError = (d) {
            if (d.exceptionAsString().contains('overflowed')) return;
            original?.call(d);
          };
          addTearDown(() => FlutterError.onError = original);
          await tester.pumpWidget(MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => DateProvider()),
              ChangeNotifierProvider(create: (_) => NotificationProvider()),
              ChangeNotifierProvider<StaffPermissionProvider>.value(
                  value: permissions),
            ],
            child: MaterialApp(
                home: Scaffold(
                    body: staff
                        ? const s_rec.Recurring_Payments_Configuration_Report()
                        : const a_rec.Recurring_Payments_Configuration_Report())),
          ));
          for (var i = 0; i < 40; i++) {
            await tester.pump(const Duration(milliseconds: 50));
          }
          final watson = find.textContaining('Watson');
          final oak = find.textContaining('Oak Lane');
          expect(watson, findsWidgets);
          expect(oak, findsWidgets);

          final box = find.byType(TextField).first;
          await tester.enterText(box, 'ruth');
          await tester.pump();
          expect(watson, findsWidgets);
          expect(oak, findsNothing);

          await tester.enterText(box, 'zzzz');
          await tester.pump();
          expect(watson, findsNothing);
          expect(oak, findsNothing);
          expect(find.text('No Results Found'), findsOneWidget);
          // The grand total stays the report's total, like web.
          expect(find.text(r'$112.50'), findsOneWidget);

          await tester.enterText(box, '');
          await tester.pump();
          expect(watson, findsWidgets);
          expect(oak, findsWidgets);

          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(seconds: 2));
        }, () => server);
      });
    }
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

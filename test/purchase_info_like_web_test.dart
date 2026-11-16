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
import 'package:three_zero_two_property/model/properties.dart';
import 'package:three_zero_two_property/StaffModule/repository/staffpermission_provider.dart';
import 'package:three_zero_two_property/StaffModule/screen/Rental/Properties/summery_page.dart'
    as staff;
import 'package:three_zero_two_property/provider/dateProvider.dart';
import 'package:three_zero_two_property/provider/lease_provider.dart';
import 'package:three_zero_two_property/provider/notification_provider.dart';
import 'package:three_zero_two_property/provider/properties_workorders.dart';
import 'package:three_zero_two_property/repository/properties_summery.dart';
import 'package:three_zero_two_property/screens/Rental/Properties/summery_page.dart'
    as admin;
import 'package:three_zero_two_property/services/purchase_info_check.dart';

/// Property → Purchase Information → Edit, like web staging (PropDetails.jsx
/// handlePurchaseInfoSave): with every field empty, "Please fill in at least
/// one field."; with nothing changed, "No changes to save."; either way
/// nothing is sent and the window stays open. An empty Purchase Price is
/// sent empty, not as 0. Before, Save always sent, and an empty price was
/// saved as 0 (the Mortgage report then showed "$0.00").

http.Response _json(Object body) => http.Response(jsonEncode(body), 200,
    headers: {'content-type': 'application/json'});

const _property = {
  '_id': 'R-1',
  'rental_id': 'P-1',
  'admin_id': 'ADMIN-1',
  'rental_adress': '12 Main St',
  'rental_city': 'Austin',
  'rental_state': 'TX',
  'rental_country': 'USA',
  'rental_postcode': '73301',
  'purchase_date': '2025-05-01',
  'purchase_price': 1500,
  'parcel_number': '123',
};

final _saves = <http.Request>[];
final _toasts = <String>[];

final _server = MockClient((request) async {
  final path = request.url.path;
  if (request.method == 'PUT' && path.endsWith('/purchase_info')) {
    _saves.add(request);
    final sent = jsonDecode(request.body) as Map<String, dynamic>;
    return _json({
      'statusCode': 200,
      'data': {..._property, ...sent},
      'message': 'Purchase information updated successfully',
    });
  }
  if (path.startsWith('/api/rentals/rental_summary/')) {
    return _json({
      'statusCode': 200,
      'data': [_property],
    });
  }
  if (path == '/api/auth') {
    return _json({
      'statusCode': 200,
      'themes': {'format': 'YYYY-MM-DD', 'timeFormat': '24'},
    });
  }
  return _json({'statusCode': 200, 'data': []});
});

Future<void> _settle(WidgetTester tester, [int ticks = 30]) async {
  for (var i = 0; i < ticks; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Opens the real property summary and its Purchase Information editor.
Future<void> _openEditor(WidgetTester tester, bool isStaff) async {
  SharedPreferences.setMockInitialValues(isStaff
      ? {
          'token': 'tkn',
          'adminId': 'ADMIN-1',
          'staff_id': 'STAFF-1',
          'role': 'Staffmember'
        }
      : {'token': 'tkn', 'adminId': 'ADMIN-1', 'role': 'Admin'});
  tester.view.physicalSize = const Size(430, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final property = Rentals.fromJson(_property);
  final dates = DateProvider();
  await dates.loadDateFormat();
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider<DateProvider>.value(value: dates),
      ChangeNotifierProvider(create: (_) => NotificationProvider()),
      ChangeNotifierProvider(create: (_) => StaffPermissionProvider()),
      ChangeNotifierProvider(create: (_) => WorkOrderCountProvider()),
      ChangeNotifierProvider(create: (_) => DropdownProvider()),
      ChangeNotifierProvider(create: (_) => SelectedTenantsProvider()),
      ChangeNotifierProvider(create: (_) => SelectedCosignersProvider()),
    ],
    child: MaterialApp(
      home: isStaff
          ? staff.Summery_page(properties: property)
          : admin.Summery_page(properties: property),
    ),
  ));
  await _settle(tester, 40);

  final heading = find.text('Purchase Information').first;
  await tester.ensureVisible(heading);
  await _settle(tester, 5);
  final edit = find.descendant(
      of: find.ancestor(of: heading, matching: find.byType(Row)).first,
      matching: find.widgetWithText(ElevatedButton, 'Edit'));
  expect(edit, findsOneWidget, reason: 'the Purchase Information Edit');
  await tester.tap(edit);
  await _settle(tester, 10);
  expect(find.text('Edit Purchase Information'), findsOneWidget);
}

Finder _inDialog(Finder f) =>
    find.descendant(of: find.byType(AlertDialog), matching: f);

Finder _box(String hint) => _inDialog(find.byWidgetPredicate(
    (w) => w is TextField && w.decoration?.hintText == hint));

Future<void> _save(WidgetTester tester) async {
  await tester.tap(_inDialog(find.widgetWithText(ElevatedButton, 'Save')));
  await _settle(tester, 15);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('helpers, like web', () {
    test("web's messages", () {
      expect(purchaseInfoEmptyMessage, 'Please fill in at least one field.');
      expect(purchaseInfoNoChangesMessage, 'No changes to save.');
    });

    test('every field empty is refused', () {
      expect(
          purchaseInfoSaveProblem(date: '', price: ' ', parcel: ''),
          purchaseInfoEmptyMessage);
      expect(
          purchaseInfoSaveProblem(date: '', price: '.', parcel: ''),
          purchaseInfoEmptyMessage,
          reason: 'a lone "." is not a price');
    });

    test('nothing changed is refused; any change is allowed', () {
      String? check({
        String date = '2025-05-01',
        String price = '1500',
        String parcel = '123',
      }) =>
          purchaseInfoSaveProblem(
              date: date,
              price: price,
              parcel: parcel,
              savedDate: '2025-05-01T00:00:00.000Z',
              savedPrice: 1500,
              savedParcel: '123');
      expect(check(), purchaseInfoNoChangesMessage);
      expect(check(price: '1500.00'), purchaseInfoNoChangesMessage,
          reason: 'the same price');
      expect(check(date: '2025-05-02'), isNull);
      expect(check(price: '1600'), isNull);
      expect(check(parcel: '124'), isNull);
      expect(check(price: ''), isNull, reason: 'removing the price');
    });

    test('one field is enough, like web', () {
      expect(purchaseInfoSaveProblem(date: '', price: '', parcel: '9'),
          isNull);
      expect(purchaseInfoSaveProblem(date: '', price: '0', parcel: ''),
          isNull,
          reason: 'web counts a typed 0 as filled in');
    });

    test('an empty price is sent empty, not 0', () {
      expect(purchasePriceForSave(''), '');
      expect(purchasePriceForSave('  '), '');
      expect(purchasePriceForSave('2500'), 2500.0);
      expect(purchasePriceForSave('2500.5'), 2500.5);
    });

    test('the box shows a saved price like web', () {
      expect(purchasePriceBoxText(1500.0), '1500', reason: 'not "1500.0"');
      expect(purchasePriceBoxText(1500.25), '1500.25');
      expect(purchasePriceBoxText(null), '');
      expect(purchasePriceBoxText(0), '',
          reason: 'web: purchase_price || ""');
    });
  });

  group('on the property summary', () {
    setUp(() {
      _saves.clear();
      _toasts.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
              const MethodChannel('PonnamKarthik/fluttertoast'), (call) async {
        final args = call.arguments;
        if (args is Map && args['msg'] != null) _toasts.add('${args['msg']}');
        return true;
      });
      ConnectivityPlatform.instance = _OnlineConnectivity();
    });

    for (final isStaff in [false, true]) {
      final role = isStaff ? 'Staff' : 'Admin';
      testWidgets(
          '$role: unchanged and empty saves are refused like web; an empty '
          'price is saved empty', (tester) async {
        final original = FlutterError.onError;
        FlutterError.onError = (details) {
          if (details.exceptionAsString().contains('overflowed')) return;
          if (details.library == 'image resource service') return;
          original?.call(details);
        };
        try {
          await http.runWithClient(() async {
            await _openEditor(tester, isStaff);

            // The saved price shows like web: 1500, not 1500.0.
            final price = _box('Enter purchase price');
            expect(tester.widget<TextField>(price).controller!.text, '1500');

            // Nothing changed: refused, the window stays open.
            await _save(tester);
            expect(_toasts, contains('No changes to save.'));
            expect(_saves, isEmpty);
            expect(find.text('Edit Purchase Information'), findsOneWidget);

            // Every field empty: refused.
            await tester.tap(_inDialog(find.byTooltip('Clear date')));
            await _settle(tester, 5);
            await tester.enterText(price, '');
            await tester.enterText(_box('Enter parcel number'), '');
            await _settle(tester, 5);
            await _save(tester);
            expect(_toasts, contains('Please fill in at least one field.'));
            expect(_saves, isEmpty);
            expect(find.text('Edit Purchase Information'), findsOneWidget);

            // One field is enough; the empty price is sent empty, not 0.
            await tester.enterText(_box('Enter parcel number'), '777');
            await _settle(tester, 5);
            await _save(tester);
            expect(_saves, hasLength(1));
            final sent =
                jsonDecode(_saves.single.body) as Map<String, dynamic>;
            expect(sent['purchase_price'], '',
                reason: 'empty, not 0, like web');
            expect(sent['purchase_date'], '');
            expect(sent['parcel_number'], '777');
            expect(_saves.single.url.path,
                '/api/rentals/rental/P-1/purchase_info',
                reason: 'the same save request as before');
            expect(_toasts,
                contains('Purchase information updated successfully'));
            expect(find.text('Edit Purchase Information'), findsNothing);

            await tester.pumpWidget(const SizedBox());
            await tester.pump(const Duration(seconds: 2));
          }, () => _server);
        } finally {
          FlutterError.onError = original;
        }
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

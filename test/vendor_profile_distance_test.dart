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
import 'package:three_zero_two_property/StaffModule/repository/staffpermission_provider.dart';
import 'package:three_zero_two_property/VendorModule/screen/profile.dart'
    as vendor;
import 'package:three_zero_two_property/provider/Plan%20Purchase/plancheckProvider.dart';
import 'package:three_zero_two_property/provider/dateProvider.dart';
import 'package:three_zero_two_property/provider/notification_provider.dart';

/// Vendor › Profile › service area "Distance (Miles)", like web's
/// VendorProfile.jsx: yup number().required("Distance is required")
/// .min(1, "Distance must be at least 1 mile"), typed in a number box, so
/// decimals such as 2.5 are saved. Before, the app saved 0 and refused ".".

const _file = 'lib/VendorModule/screen/profile.dart';

void main() {
  test('the old digits-only Distance box and messages are gone', () {
    final src = File(_file).readAsStringSync();
    expect(src, isNot(contains("return 'Numbers only'")));
    expect(src, contains("'Distance is required'"));
    expect(src, contains("'Distance must be at least 1 mile'"));
    final at = src.indexOf("hint: 'Enter distance'");
    expect(at, isNonNegative);
    final end = src.indexOf(']', src.indexOf('inputFormatters:', at)) + 1;
    final field = src.substring(at, end);
    expect(field.length, lessThan(600), reason: 'just the Distance field');
    expect(field, isNot(contains('digitsOnly')));
    expect(field, contains('inputFormatters: [_distanceFormatter]'));
    expect(field, contains('numberWithOptions(decimal: true)'));
  });

  group('on the Vendor profile screen', () {
    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
              const MethodChannel('PonnamKarthik/fluttertoast'),
              (_) async => true);
      ConnectivityPlatform.instance = _Online();
    });

    testWidgets('Distance must be at least 1, and decimals like 2.5 save',
        (tester) async {
      SharedPreferences.setMockInitialValues(
          {'token': 'tkn', 'vendor_id': 'V-1', 'role': 'Vendor'});
      final saves = <http.Request>[];
      final server = MockClient((request) async {
        final path = request.url.path;
        if (path.startsWith('/api/vendor/update_vendor/')) {
          saves.add(request);
          return _json({'statusCode': 200, 'data': _vendor});
        }
        if (path.startsWith('/api/vendor/get_vendor/')) {
          return _json({'statusCode': 200, 'data': _vendor});
        }
        return _json({'statusCode': 200, 'data': []});
      });

      tester.view.physicalSize = const Size(1080, 6000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final original = FlutterError.onError;
      FlutterError.onError = (d) {
        if (d.exceptionAsString().contains('overflowed')) return;
        original?.call(d);
      };
      addTearDown(() => FlutterError.onError = original);

      await http.runWithClient(() async {
        await tester.pumpWidget(MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => DateProvider()),
            ChangeNotifierProvider(create: (_) => NotificationProvider()),
            ChangeNotifierProvider(create: (_) => checkPlanPurchaseProiver()),
            ChangeNotifierProvider(create: (_) => StaffPermissionProvider()),
          ],
          child: const MaterialApp(home: vendor.Profile_screen()),
        ));
        await _settle(tester, 60);

        final distance = find
            .byWidgetPredicate((w) =>
                w is TextField && w.decoration?.hintText == 'Enter distance')
            .first;
        TextField box() => tester.widget<TextField>(distance);
        expect(box().controller!.text, '10', reason: 'loaded from the profile');
        expect(box().keyboardType,
            const TextInputType.numberWithOptions(decimal: true),
            reason: 'the iPhone keyboard shows "."');
        expect(box().decoration?.errorMaxLines, 2,
            reason: 'the message wraps instead of being cut off');
        // Every other box on the screen keeps its one-line message.
        final others = tester
            .widgetList<TextField>(find.byType(TextField))
            .where((t) => t.decoration?.hintText != 'Enter distance');
        expect(others, isNotEmpty);
        for (final t in others) {
          expect(t.decoration?.errorMaxLines, isNull,
              reason: '${t.decoration?.hintText}');
        }

        Future<void> update() async {
          await tester.ensureVisible(find.text('Update Profile'));
          await tester.tap(find.text('Update Profile'));
          await _settle(tester, 12);
        }

        // The second service area row ("Distance (Miles) 2") has the same
        // rule: under 1 mile is refused there too, and it accepts decimals.
        final second = find
            .byWidgetPredicate((w) =>
                w is TextField && w.decoration?.hintText == 'Enter distance')
            .at(1);
        TextField box2() => tester.widget<TextField>(second);
        expect(box2().controller!.text, '20', reason: 'loaded from the profile');
        expect(box2().decoration?.errorMaxLines, 2);
        await tester.enterText(second, '0.5');
        expect(box2().controller!.text, '0.5');
        await update();
        expect(find.text('Distance must be at least 1 mile'), findsOneWidget,
            reason: 'row 2');
        expect(saves, isEmpty, reason: 'row 2 under 1 mile is not saved');
        await tester.enterText(second, '20');

        // 0 and anything under 1 mile can't be saved, like web.
        for (final small in ['0', '0.5', '00']) {
          await tester.enterText(distance, small);
          expect(box().controller!.text, small);
          await update();
          expect(find.text('Distance must be at least 1 mile'), findsOneWidget,
              reason: small);
          expect(saves, isEmpty, reason: small);
        }

        // Empty, or a lone ".", is required, like web.
        for (final empty in ['', '.']) {
          await tester.enterText(distance, empty);
          await update();
          expect(find.text('Distance is required'), findsOneWidget,
              reason: '"$empty"');
          expect(saves, isEmpty);
        }

        // A decimal point can be typed; a second one, letters or other
        // characters are refused and the text stays as it was.
        await tester.enterText(distance, '2.5');
        expect(box().controller!.text, '2.5');
        for (final refused in ['2.5.1', '2.5a', '-2.5', '2,5', '2.5 ']) {
          await tester.enterText(distance, refused);
          expect(box().controller!.text, '2.5', reason: refused);
        }

        // Exactly 1, and decimals like 2.5, are saved as typed.
        await update();
        expect(find.text('Distance must be at least 1 mile'), findsNothing);
        expect(find.text('Distance is required'), findsNothing);
        expect(saves, hasLength(1));
        final body = jsonDecode(saves.single.body) as Map<String, dynamic>;
        final regions = (body['region_covered'] as List).cast<Map>();
        expect(regions.first['distance_miles'], '2.5');
        expect(regions.last['distance_miles'], '20', reason: '2nd row as is');

        await tester.enterText(distance, '1');
        await update();
        expect(saves, hasLength(2), reason: '1 mile is allowed, like web');

        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 5));
      }, () => server);
    });
  });
}

const _vendor = {
  '_id': 'V-1',
  'vendor_id': 'V-1',
  'vendor_name': 'Test Vendor',
  'vendor_email': 'vendor@example.com',
  'vendor_phoneNumber': '5551234567',
  'contact_cell_number': '5551234567',
  'vendor_address': '1 Test Street',
  'vendor_city': 'Austin',
  'vendor_state': 'Texas',
  'vendor_zip': '12345',
  'vendor_country': 'United States',
  'licenses_permits': 'License 123',
  'contact_info': [
    {
      'contact_name': 'Pat Contact',
      'contact_number': '5551234567',
      'contact_email': 'pat@example.com',
    }
  ],
  'trade': 'General',
  'region_covered': [
    {'zip_code': '12345', 'distance_miles': '10'},
    {'zip_code': '67890', 'distance_miles': '20'},
  ],
};

http.Response _json(Object body) => http.Response(jsonEncode(body), 200,
    headers: {'content-type': 'application/json'});

Future<void> _settle(WidgetTester tester, int ticks) async {
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

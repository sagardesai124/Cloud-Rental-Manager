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
import 'package:three_zero_two_property/services/zip_code.dart';

/// Vendor › Profile zip fields (the vendor's own Zip Code and each service
/// area's Zip Code), like web's VendorProfile.jsx: digits only with the ZIP+4
/// hyphen added as typed, required ("Zip code is required"), 5 digits or
/// ZIP+4 ("Zip code must be 5 digits or 5+4 format"), placeholder "Enter zip
/// code", and service-area rows numbered from the 2nd ("Zip Code 2 *").

const _file = 'lib/VendorModule/screen/profile.dart';

void main() {
  test("web's checks for a required zip", () {
    expect(validateZipCode('', required: true), 'Zip code is required');
    expect(validateZipCode('  ', required: true), 'Zip code is required');
    for (final bad in ['1', '12', '1234', '123456']) {
      expect(validateZipCode(bad, required: true),
          'Zip code must be 5 digits or 5+4 format',
          reason: bad);
    }
    expect(validateZipCode('12345', required: true), isNull);
    expect(validateZipCode('12345-6789', required: true), isNull);
    expect(validateZipCode('12345-6', required: true), isNull,
        reason: "web's rule allows a partial +4");
  });

  test('both zip fields use the shared helper; the old check is gone', () {
    final src = File(_file).readAsStringSync();
    expect(src, isNot(contains('_validateZipUS')));
    expect(src, isNot(contains('Enter valid US zip')));
    expect(src, isNot(contains("'e.g. 12345 or 12345-6789'")));
    expect('inputFormatters: [zipCodeFormatter]'.allMatches(src).length, 2);
    expect(
        RegExp(r'validateZipCode\(\s*v,\s*required: true\)')
            .allMatches(src)
            .length,
        2);
    expect("hint: 'Enter zip code'".allMatches(src).length, 2);
  });

  group('on the Vendor profile screen', () {
    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
              const MethodChannel('PonnamKarthik/fluttertoast'),
              (_) async => true);
      ConnectivityPlatform.instance = _Online();
    });

    testWidgets(
        'short or empty zip blocks Update Profile; ZIP+4 is saved; rows numbered',
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

        // Two service-area rows: the 2nd is numbered, like web.
        expect(find.text('Zip Code 2 *'), findsOneWidget);
        expect(find.text('Distance (Miles) 2 *'), findsOneWidget);

        final zip = find
            .byWidgetPredicate((w) =>
                w is TextField && w.decoration?.hintText == 'Enter zip code')
            .first;
        TextEditingController ctrl() =>
            tester.widget<TextField>(zip).controller!;
        expect(ctrl().text, '12345', reason: 'loaded from the profile');

        Future<void> update() async {
          await tester.ensureVisible(find.text('Update Profile'));
          await tester.tap(find.text('Update Profile'));
          await _settle(tester, 12);
        }

        // Letters are dropped; a 1-digit zip can't be saved.
        await tester.enterText(zip, 'ab1');
        expect(ctrl().text, '1');
        await update();
        expect(find.text('Zip code must be 5 digits or 5+4 format'),
            findsOneWidget);
        expect(saves, isEmpty);

        // Empty: required, like web.
        await tester.enterText(zip, '');
        await update();
        expect(find.text('Zip code is required'), findsOneWidget);
        expect(saves, isEmpty);

        // ZIP+4 is formatted as typed and saved.
        await tester.enterText(zip, '123456789');
        expect(ctrl().text, '12345-6789');
        await update();
        expect(saves, hasLength(1));
        expect(saves.single.body, contains('12345-6789'));

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

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
import 'package:three_zero_two_property/VendorModule/screen/profile.dart'
    as vendor;
import 'package:three_zero_two_property/provider/Plan%20Purchase/plancheckProvider.dart';
import 'package:three_zero_two_property/provider/dateProvider.dart';
import 'package:three_zero_two_property/provider/notification_provider.dart';

/// Vendor › Profile error messages, like web staging (VendorProfile.jsx
/// validationSchema). Formik turns an empty box into no value, so web shows
/// each field's "... is required" for an empty box and its format message
/// only for a filled-in one. The app used to say just "Required".

void main() {
  group('on the Vendor profile screen', () {
    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
              const MethodChannel('PonnamKarthik/fluttertoast'),
              (_) async => true);
      ConnectivityPlatform.instance = _Online();
    });

    testWidgets('empty boxes show web\'s "... is required" messages',
        (tester) async {
      // No trade saved, so the Trade/Service Type has no value either.
      final vendorNoTrade = Map<String, dynamic>.from(_vendor)..remove('trade');
      final saves = <Map<String, dynamic>>[];
      await _withScreen(tester, vendorNoTrade, saves, () async {
        for (final hint in [
          'Enter company name',
          'Enter company email',
          '(xxx) xxx-xxxx',
          'Start typing your address...',
          'Enter city',
          'Enter zip code',
          'Enter country',
          'Enter contact name',
          'Enter contact email',
          'Enter distance',
          'Please provide details of your licenses and permits...',
        ]) {
          final boxes = _box(hint);
          expect(boxes, findsWidgets, reason: hint);
          for (var i = 0; i < tester.widgetList(boxes).length; i++) {
            await tester.enterText(boxes.at(i), '');
          }
        }
        await tester.pump();
        await _update(tester);

        expect(saves, isEmpty, reason: 'nothing is saved');
        for (final message in [
          'Vendor name is required',
          'Email is required',
          'Phone number is required',
          'Contact number is required',
          'Address is required',
          'City is required',
          'Country is required',
          'Contact name is required',
          'Contact email is required',
          'Trade/Service type is required',
          'Distance is required',
          'License/permit information is required',
        ]) {
          expect(find.text(message), findsOneWidget, reason: message);
        }
        expect(find.text('Zip code is required'), findsNWidgets(2),
            reason: 'the address zip and the service area zip');
        expect(find.text('Required'), findsNothing,
            reason: 'every box has its own message, like web');
      });
    });

    testWidgets('filled-in but wrong values show web\'s format messages',
        (tester) async {
      final saves = <Map<String, dynamic>>[];
      await _withScreen(tester, _vendor, saves, () async {
        final phones = _box('(xxx) xxx-xxxx');
        await tester.enterText(phones.at(0), '55512');
        await tester.enterText(phones.at(1), '5551');
        await tester.enterText(_box('Enter company email'), 'not-an-email');
        await tester.enterText(_box('Enter contact email'), 'pat@');
        await tester.pump();
        await _update(tester);

        expect(saves, isEmpty, reason: 'nothing is saved');
        for (final message in [
          'Phone number must be in the format (xxx) xxx-xxxx',
          'Contact number must be in the format (xxx) xxx-xxxx',
          'Please enter a valid email address',
          'Please enter a valid contact email address',
        ]) {
          expect(find.text(message), findsOneWidget, reason: message);
        }
        expect(find.text('Phone number must be 10 digits'), findsNothing);
        expect(find.text('Enter a valid email address'), findsNothing);

        // Fixed values save as before.
        await tester.enterText(phones.at(0), '5551112222');
        await tester.enterText(phones.at(1), '5553334444');
        await tester.enterText(
            _box('Enter company email'), 'vendor@example.com');
        await tester.enterText(_box('Enter contact email'), 'pat@example.com');
        await tester.pump();
        await _update(tester);
        expect(saves, hasLength(1));
      });
    });
  });
}

const _vendor = {
  '_id': 'V-1',
  'vendor_id': 'V-1',
  'vendor_name': 'Test Vendor',
  'vendor_email': 'vendor@example.com',
  'vendor_phoneNumber': '5551112222',
  'vendor_address': '1 Test Street',
  'vendor_city': 'Austin',
  'vendor_state': 'Texas',
  'vendor_zip': '12345',
  'vendor_country': 'United States',
  'licenses_permits': 'License 123',
  'contact_info': [
    {
      'contact_name': 'Pat Contact',
      'contact_number': '5553334444',
      'contact_email': 'pat@example.com',
    }
  ],
  'trade': 'general',
  'region_covered': [
    {'zip_code': '12345', 'distance_miles': '10'},
  ],
};

Finder _box(String hint) => find.byWidgetPredicate(
    (w) => w is TextField && w.decoration?.hintText == hint);

Widget _app(Widget home) => MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => DateProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => checkPlanPurchaseProiver()),
        ChangeNotifierProvider(create: (_) => StaffPermissionProvider()),
      ],
      child: MaterialApp(home: home),
    );

/// Opens the Vendor Profile screen against a fake server that returns
/// [vendorData] and records each save in [saves], runs [body], then closes
/// the screen and lets its timers finish.
Future<void> _withScreen(WidgetTester tester, Map<String, dynamic> vendorData,
    List<Map<String, dynamic>> saves, Future<void> Function() body) async {
  SharedPreferences.setMockInitialValues(
      {'token': 'tkn', 'vendor_id': 'V-1', 'role': 'Vendor'});
  final server = MockClient((request) async {
    final path = request.url.path;
    if (path.startsWith('/api/vendor/update_vendor/')) {
      saves.add(jsonDecode(request.body) as Map<String, dynamic>);
      return _json(
          {'statusCode': 200, 'message': 'Vendor Updated Successfully'});
    }
    if (path.startsWith('/api/vendor/get_vendor/')) {
      return _json({'statusCode': 200, 'data': vendorData});
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
    await tester.pumpWidget(_app(const vendor.Profile_screen()));
    await _settle(tester, 60);
    await body();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  }, () => server);
}

Future<void> _update(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Update Profile'));
  await tester.tap(find.text('Update Profile'));
  await _settle(tester, 30);
}

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

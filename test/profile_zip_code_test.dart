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
import 'package:three_zero_two_property/provider/Plan%20Purchase/plancheckProvider.dart';
import 'package:three_zero_two_property/provider/dateProvider.dart';
import 'package:three_zero_two_property/provider/notification_provider.dart';
import 'package:three_zero_two_property/screens/Profile/Profile_screen.dart';
import 'package:three_zero_two_property/services/zip_code.dart';

/// Admin › My Profile Zip Code, like web staging (Profile.jsx): labelled
/// "Zip Code", only digits can be entered (ZIP+4 hyphen added as typed, at
/// most 9 digits), and on Update anything but empty, 5 digits or ZIP+4 is
/// blocked with web's message. QA (Android 1.0.246+249): "ab12" and "12"
/// were accepted and the field said "Postal Code".

String _type(String text, {String from = ''}) => zipCodeFormatter
    .formatEditUpdate(TextEditingValue(text: from),
        TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length)))
    .text;

void main() {
  group('typing, like web', () {
    test('only digits are kept', () {
      expect(_type('ab12'), '12');
      expect(_type('1'), '1');
      expect(_type('a'), '');
      expect(_type('abc'), '');
      expect(_type('1 2-3a45'), '12345');
    });

    test('ZIP+4: the hyphen is added after the 5th digit, 9 digits max', () {
      expect(_type('12345'), '12345');
      expect(_type('123456'), '12345-6');
      expect(_type('123456789'), '12345-6789');
      expect(_type('1234567890'), '12345-6789');
      expect(_type('12345-6789'), '12345-6789', reason: 'pasted ZIP+4');
    });

    test('deleting back to 5 digits drops the hyphen', () {
      expect(_type('12345-', from: '12345-6'), '12345');
    });
  });

  group("web's check on Update", () {
    test('empty is allowed (the field is optional)', () {
      expect(validateZipCode(''), isNull);
      expect(validateZipCode(null), isNull);
    });

    test('5 digits or ZIP+4 pass', () {
      expect(validateZipCode('12345'), isNull);
      expect(validateZipCode('12345-6789'), isNull);
      expect(validateZipCode('12345-6'), isNull,
          reason: "web's rule allows a partial +4");
    });

    test('anything else is blocked with web\'s message', () {
      for (final bad in ['1', '12', '123', '1234', 'ab12', '123456', '12345-67890']) {
        expect(validateZipCode(bad),
            'Zip code must be 5 digits or 5+4 format',
            reason: bad);
      }
    });
  });

  test('the screen wires it up: label, digits, number keyboard, check', () {
    final src =
        File('lib/screens/Profile/Profile_screen.dart').readAsStringSync();
    expect(src, isNot(contains("'Postal Code'")));
    expect(RegExp(r"const Text\(\s*'Zip Code',").hasMatch(src), isTrue);
    final start = src.indexOf("buildTextField(\n"
        "                                        'Zip Code',");
    expect(start, isNonNegative);
    final call = src.substring(start, src.indexOf('),', start));
    expect(call, contains('validateZipCode'));
    expect(call, contains('isRequired: true'),
        reason: 'buildTextField only runs a check when isRequired is set');
    expect(call, contains('inputFormatters: [zipCodeFormatter]'));
    expect(call, contains('keyboardType: TextInputType.number'));
  });

  group('on the My Profile screen', () {
    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
              const MethodChannel('PonnamKarthik/fluttertoast'),
              (_) async => true);
      ConnectivityPlatform.instance = _Online();
    });

    testWidgets('a short zip blocks Update; a valid ZIP+4 is saved',
        (tester) async {
      SharedPreferences.setMockInitialValues(
          {'token': 'tkn', 'adminId': 'ADMIN-1', 'role': 'Admin'});
      final saves = <http.Request>[];
      final server = MockClient((request) async {
        final path = request.url.path;
        if (path.startsWith('/api/admin/admin_edit/')) {
          saves.add(request);
          return _json({'statusCode': 200, 'data': _profile});
        }
        if (path.startsWith('/api/admin/admin_profile/')) {
          return _json({'statusCode': 200, 'data': _profile});
        }
        if (path.startsWith('/api/2fa/2fa-status/')) {
          return _json({
            'statusCode': 200,
            'data': {'enabled': false, 'method': ''}
          });
        }
        if (path.startsWith('/api/backup-codes/backup-codes/')) {
          return _json({
            'statusCode': 200,
            'data': {'codes': []}
          });
        }
        return _json({'statusCode': 200, 'data': []});
      });

      tester.view.physicalSize = const Size(1080, 4800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final original = FlutterError.onError;
      FlutterError.onError = (d) {
        if (d.exceptionAsString().contains('overflowed')) return;
        original?.call(d);
      };
      addTearDown(() => FlutterError.onError = original);

      await http.runWithClient(() async {
        final permissions = StaffPermissionProvider();
        await tester.pumpWidget(MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => DateProvider()),
            ChangeNotifierProvider(create: (_) => NotificationProvider()),
            ChangeNotifierProvider(create: (_) => checkPlanPurchaseProiver()),
            ChangeNotifierProvider<StaffPermissionProvider>.value(
                value: permissions),
          ],
          child: const MaterialApp(home: Profile_screen()),
        ));
        await _settle(tester, 60);

        final zip = find.byWidgetPredicate(
            (w) => w is TextField && w.decoration?.hintText == 'Zip Code');
        expect(zip, findsOneWidget);
        expect(find.text('Zip Code'), findsWidgets, reason: 'label');
        expect(find.text('Postal Code'), findsNothing);

        // QA's steps: letters are dropped, and "12" can't be saved.
        await tester.enterText(zip, 'ab12');
        expect(tester.widget<TextField>(zip).controller!.text, '12');
        await tester.ensureVisible(find.text('Update'));
        await tester.tap(find.text('Update'));
        await _settle(tester, 10);
        expect(find.text('Zip code must be 5 digits or 5+4 format'),
            findsOneWidget);
        expect(saves, isEmpty, reason: 'nothing sent with a short zip');

        // A ZIP+4 is formatted like web and saved.
        await tester.enterText(zip, '123456789');
        expect(tester.widget<TextField>(zip).controller!.text, '12345-6789');
        await tester.tap(find.text('Update'));
        await _settle(tester, 20);
        expect(saves, hasLength(1));
        expect(saves.single.body, contains('12345-6789'));

        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 5));
      }, () => server);
    });
  });
}

const _profile = {
  '_id': 'P-1',
  'admin_id': 'ADMIN-1',
  'first_name': 'Pat',
  'last_name': 'Owner',
  'email': 'pat@example.com',
  'phone_number': '5551234567',
  'company_name': 'Test Co',
  'company_address': '',
  'postal_code': '',
  'city': '',
  'state': '',
  'country': '',
  'createdAt': '2026-09-22T16:16:04.328Z',
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

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
import 'package:three_zero_two_property/StaffModule/screen/Rental/Properties/add_rentalowners.dart'
    as staff;
import 'package:three_zero_two_property/provider/Plan%20Purchase/plancheckProvider.dart';
import 'package:three_zero_two_property/provider/dateProvider.dart';
import 'package:three_zero_two_property/provider/notification_provider.dart';
import 'package:three_zero_two_property/screens/Rental/Properties/add_rentalowners.dart'
    as admin;
import 'package:three_zero_two_property/services/letters_only.dart';

/// Rental owner names, cities and countries, like web staging:
///  * Add/Edit Property › Add Rental Owner (Rentals.jsx): Contact Name, City
///    and Country take letters and spaces only;
///  * Property Owners › Add/Edit (ManageRentalOnwer.jsx): Name only (City and
///    Country there take anything on web, so they stay as they are).
/// QA: typing `John3#`, `Austin12#` and `USA1` keeps only the letters.

String _typeEachKey(String keys) {
  var value = TextEditingValue.empty;
  for (final ch in keys.split('')) {
    final next = value.text + ch;
    value = typedLettersAndSpacesOnly.formatEditUpdate(
        value,
        TextEditingValue(
            text: next,
            selection: TextSelection.collapsed(offset: next.length)));
  }
  return value.text;
}

const _propertyOwnerForms = [
  'lib/screens/Rental/Properties/add_rentalowners.dart',
  'lib/StaffModule/screen/Rental/Properties/add_rentalowners.dart',
];
const _ownerPages = [
  'lib/screens/Rental/Rentalowner/Add_RentalOwners.dart',
  'lib/screens/Rental/Rentalowner/Edit_RentalOwners.dart',
  'lib/StaffModule/screen/Rental/Rentalowner/Add_RentalOwners.dart',
  'lib/StaffModule/screen/Rental/Rentalowner/Edit_RentalOwners.dart',
];

String _box(String src, String controller) {
  final at = src.indexOf('controller: $controller,');
  expect(at, isNonNegative, reason: controller);
  final start = src.lastIndexOf('TextField(', at);
  return src.substring(start, src.indexOf('decoration:', at));
}

void main() {
  test("QA's examples keep only the letters, like web", () {
    expect(_typeEachKey('John3#'), 'John');
    expect(_typeEachKey('Austin12#'), 'Austin');
    expect(_typeEachKey('USA1'), 'USA');
    expect(_typeEachKey('Mary Ann'), 'Mary Ann', reason: 'spaces are fine');
  });

  for (final path in _propertyOwnerForms) {
    test('$path: Contact Name, City and Country take letters only', () {
      final src = File(path).readAsStringSync();
      expect(src, contains(
          "import 'package:three_zero_two_property/services/letters_only.dart';"));
      for (final c in ['firstname', 'city2', 'county2']) {
        expect(_box(src, c), contains('inputFormatters: [typedLettersAndSpacesOnly]'),
            reason: c);
      }
    });
  }

  for (final path in _ownerPages) {
    test('$path: Name takes letters only; City/Country unchanged like web', () {
      final src = File(path).readAsStringSync();
      expect(_box(src, 'name'), contains('inputFormatters: [typedLettersAndSpacesOnly]'));
      for (final c in ['city2', 'county2']) {
        if (src.contains('controller: $c,')) {
          expect(_box(src, c), isNot(contains('typedLettersAndSpacesOnly')),
              reason: 'web takes anything in the owner page $c');
        }
      }
    });
  }

  group('on the real Add Property › Add Rental Owner screen', () {
    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
              const MethodChannel('PonnamKarthik/fluttertoast'),
              (_) async => true);
      ConnectivityPlatform.instance = _Online();
    });

    for (final role in ['Admin', 'Staff']) {
      testWidgets('$role: John3#, Austin12# and USA1 keep only the letters',
          (tester) async {
        SharedPreferences.setMockInitialValues(
            {'token': 'tkn', 'adminId': 'ADMIN-1', 'role': role});
        final server = MockClient((request) async => http.Response(
            jsonEncode({'statusCode': 200, 'data': []}), 200,
            headers: {'content-type': 'application/json'}));

        tester.view.physicalSize = const Size(1080, 9000);
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
            child: MaterialApp(
              home: role == 'Admin'
                  ? admin.AddRentalowners()
                  : staff.AddRentalowners(),
            ),
          ));
          for (var i = 0; i < 20; i++) {
            await tester.pump(const Duration(milliseconds: 50));
          }

          Finder box(String hint) => find.byWidgetPredicate(
              (w) => w is TextField && w.decoration?.hintText == hint);

          Future<String> typeEachKey(String hint, String keys) async {
            final field = box(hint);
            expect(field, findsOneWidget, reason: hint);
            for (final ch in keys.split('')) {
              final now = tester.widget<TextField>(field).controller!.text;
              await tester.enterText(field, now + ch);
              await tester.pump();
            }
            return tester.widget<TextField>(field).controller!.text;
          }

          expect(await typeEachKey('Enter name', 'John3#'), 'John');
          expect(await typeEachKey('Enter city', 'Austin12#'), 'Austin');
          expect(await typeEachKey('Enter country', 'USA1'), 'USA');

          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(seconds: 5));
        }, () => server);
      });
    }
  });
}

class _Online extends ConnectivityPlatform with MockPlatformInterfaceMixin {
  @override
  Future<ConnectivityResult> checkConnectivity() async =>
      ConnectivityResult.wifi;
  @override
  Stream<ConnectivityResult> get onConnectivityChanged => const Stream.empty();
}

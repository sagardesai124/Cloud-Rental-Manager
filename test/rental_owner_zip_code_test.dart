import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:three_zero_two_property/StaffModule/repository/staffpermission_provider.dart';
import 'package:three_zero_two_property/StaffModule/screen/Rental/Rentalowner/Add_RentalOwners.dart'
    as staff;
import 'package:three_zero_two_property/provider/Plan%20Purchase/plancheckProvider.dart';
import 'package:three_zero_two_property/provider/dateProvider.dart';
import 'package:three_zero_two_property/provider/notification_provider.dart';
import 'package:three_zero_two_property/screens/Rental/Rentalowner/Add_RentalOwners.dart'
    as admin;
import 'package:three_zero_two_property/services/zip_code.dart';

/// Rental Owner › Add/Edit Zip Code, like web staging
/// (ManageRentalOnwer.jsx): optional, digits only with the ZIP+4 hyphen
/// added as typed (9 digits max), and on save anything but empty, 5 digits
/// or 5+4 shows "Zip code must be 5 digits or 5+4 format".

const _msg = 'Zip code must be 5 digits or 5+4 format';

String _type(String text) => zipCodeFormatter
    .formatEditUpdate(
        TextEditingValue.empty,
        TextEditingValue(
            text: text,
            selection: TextSelection.collapsed(offset: text.length)))
    .text;

const _forms = [
  'lib/screens/Rental/Rentalowner/Add_RentalOwners.dart',
  'lib/screens/Rental/Rentalowner/Edit_RentalOwners.dart',
  'lib/StaffModule/screen/Rental/Rentalowner/Add_RentalOwners.dart',
  'lib/StaffModule/screen/Rental/Rentalowner/Edit_RentalOwners.dart',
];

void main() {
  test("the report's examples behave like web", () {
    expect(validateZipCode('123'), _msg);
    expect(validateZipCode('1234567'), _msg);
    expect(_type('1234567'), '12345-67', reason: 'web adds the hyphen');
    expect(_type('123456789'), '12345-6789');
    expect(_type('1234567890'), '12345-6789', reason: '9 digits max');
    expect(validateZipCode('12345-6789'), isNull);
    expect(validateZipCode('12345'), isNull);
    expect(validateZipCode(''), isNull, reason: 'optional, like web');
  });

  for (final path in _forms) {
    test('$path uses web zip typing and checks it on save', () {
      final src = File(path).readAsStringSync();
      final box = src.indexOf('controller: code2,');
      expect(box, isNonNegative);
      final field = src.substring(box, src.indexOf('decoration:', box));
      expect(field, contains('zipCodeFormatter'));
      expect(field, isNot(contains('digitsOnly')));
      expect(src, contains('validateZipCode(code2.text)'));
      if (path.contains('Add_')) {
        expect(RegExp(r'!officenumerror &&\s*!code2error').hasMatch(src),
            isTrue,
            reason: 'a bad zip must stop the save');
      } else {
        expect(src, contains('if (zipError != null) isFormValid = false;'));
      }
    });
  }

  for (final role in ['Admin', 'Staff']) {
    testWidgets('$role Add Rental Owner: zip types and is checked like web',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
              const MethodChannel('PonnamKarthik/fluttertoast'),
              (_) async => true);
      tester.view.physicalSize = const Size(1080, 9000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
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
          ChangeNotifierProvider(create: (_) => checkPlanPurchaseProiver()),
          ChangeNotifierProvider(create: (_) => StaffPermissionProvider()),
        ],
        child: MaterialApp(
            home: role == 'Admin'
                ? const admin.Add_rentalowners()
                : const staff.Add_rentalowners()),
      ));
      await tester.pump(const Duration(seconds: 1));

      final zip = find.byWidgetPredicate((w) =>
          w is TextField && w.decoration?.hintText == 'Enter zip code');
      expect(zip, findsOneWidget);
      TextEditingController ctl() => tester.widget<TextField>(zip).controller!;

      await tester.enterText(zip, '1234567');
      expect(ctl().text, '12345-67');
      await tester.enterText(zip, '12345-6789');
      expect(ctl().text, '12345-6789', reason: 'ZIP+4 can be entered');

      // "123" shows web's message on save.
      await tester.enterText(zip, '123');
      final save = find.text('Add Rental Owner').last;
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(_msg), findsOneWidget);

      // A valid zip clears it.
      await tester.enterText(zip, '12345');
      await tester.tap(save);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(_msg), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    });
  }
}

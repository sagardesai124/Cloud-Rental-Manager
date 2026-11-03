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
import 'package:three_zero_two_property/StaffModule/screen/Maintenance/Vendor/edit_vendor.dart'
    as staff;
import 'package:three_zero_two_property/provider/Plan%20Purchase/plancheckProvider.dart';
import 'package:three_zero_two_property/provider/dateProvider.dart';
import 'package:three_zero_two_property/provider/notification_provider.dart';
import 'package:three_zero_two_property/screens/Maintenance/Vendor/edit_vendor.dart'
    as admin;

/// Edit Vendor (Admin and Staff): the submit button reads "Update Vendor",
/// like web staging (AddVendor.jsx, which both roles open: `vendor_id ?
/// "Update Vendor" : "Add Vendor"`); the page heading stays "Edit Vendor",
/// also like web. Staff read "Edit Vendor" on both layouts, Admin on the
/// wide one.

const _vendor = {
  '_id': 'V-1',
  'vendor_id': 'V-1',
  'vendor_name': 'Fixit Co',
  'vendor_email': 'fixit@example.com',
  'vendor_phoneNumber': '5551234567',
  'trade': 'Plumbing',
  'is_1099': false,
};

final _server = MockClient((request) async {
  Object body = {'statusCode': 200, 'data': []};
  if (request.url.path.startsWith('/api/vendor/get_vendor/')) {
    body = {'statusCode': 200, 'data': _vendor};
  }
  return http.Response(jsonEncode(body), 200,
      headers: {'content-type': 'application/json'});
});

Future<void> _settle(WidgetTester tester, [int ticks = 40]) async {
  for (var i = 0; i < ticks; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('PonnamKarthik/fluttertoast'), (_) async => true);
    ConnectivityPlatform.instance = _OnlineConnectivity();
  });

  Future<void> check(
      WidgetTester tester, Widget screen, String role, double width) async {
    tester.view.physicalSize = Size(width, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({
      'token': 'tkn',
      'adminId': 'ADMIN-1',
      'staff_id': 'S-1',
      'role': role,
    });
    final original = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('overflowed')) return;
      original?.call(details);
    };
    try {
      await http.runWithClient(() async {
        await tester.pumpWidget(MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => DateProvider()),
            ChangeNotifierProvider(create: (_) => NotificationProvider()),
            ChangeNotifierProvider(create: (_) => checkPlanPurchaseProiver()),
            ChangeNotifierProvider(create: (_) => StaffPermissionProvider()),
          ],
          child: MaterialApp(home: screen),
        ));
        await _settle(tester);

        final why = '$role at ${width.toInt()} wide';
        expect(find.text('Fixit Co'), findsWidgets, reason: '$why: loaded');
        expect(find.text('Update Vendor'), findsOneWidget, reason: why);
        // "Edit Vendor" is only the page heading now, like web.
        final editTexts = tester
            .widgetList<Text>(find.text('Edit Vendor'))
            .where((t) => find
                .ancestor(
                    of: find.byWidget(t),
                    matching: find.byWidgetPredicate((w) => w is ButtonStyleButton))
                .evaluate()
                .isNotEmpty);
        expect(editTexts, isEmpty, reason: '$why: no "Edit Vendor" button');
      }, () => _server);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    } finally {
      FlutterError.onError = original;
    }
  }

  for (final width in [430.0, 800.0]) {
    testWidgets('Admin Edit Vendor @$width', (tester) async {
      await check(tester, admin.edit_vendor(vender_id: 'V-1'), 'Admin', width);
    });
    testWidgets('Staff Edit Vendor @$width', (tester) async {
      await check(
          tester, staff.edit_vendor(vender_id: 'V-1'), 'Staffmember', width);
    });
  }
}

class _OnlineConnectivity extends ConnectivityPlatform
    with MockPlatformInterfaceMixin {
  @override
  Future<ConnectivityResult> checkConnectivity() async =>
      ConnectivityResult.wifi;
  @override
  Stream<ConnectivityResult> get onConnectivityChanged => const Stream.empty();
}

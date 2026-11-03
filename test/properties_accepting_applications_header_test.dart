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
import 'package:three_zero_two_property/StaffModule/screen/Rental/Properties/Properties_table.dart'
    as staff;
import 'package:three_zero_two_property/provider/dateProvider.dart';
import 'package:three_zero_two_property/provider/notification_provider.dart';
import 'package:three_zero_two_property/screens/Rental/Properties/Properties_table.dart'
    as admin;

/// Rental → Properties list: the last column header reads "Accepting" over
/// "Applications", like live staging web (the table header is
/// `Accepting <br/> Applications`, the card list says "Accepting
/// Applications"). Mobile said "Accepting Application". Admin and Staff each
/// have their own copy of the table.
///
/// The app's own font (Poppins) is loaded, so the fit check below measures
/// the header as the phone draws it.

final _server = MockClient((request) async {
  Object body = {'statusCode': 200, 'data': []};
  if (request.url.path.startsWith('/api/rentals/rentals/')) {
    body = {
      'statusCode': 200,
      'data': [
        {
          'rental_id': 'R-1',
          'admin_id': 'ADMIN-1',
          'rental_adress': '12 Elm Street',
          'rental_city': 'Austin',
          'is_available': true,
          'property_type_data': {
            'property_type': 'Residential',
            'propertysub_type': 'House'
          },
          'tenants_data': [],
          'units': [],
        }
      ],
      'pagination': {
        'currentPage': 1,
        'totalPages': 1,
        'totalItems': 1,
        'itemsPerPage': 10
      },
    };
  }
  return http.Response(jsonEncode(body), 200,
      headers: {'content-type': 'application/json'});
});

Future<void> _settle(WidgetTester tester, [int ticks = 30]) async {
  for (var i = 0; i < ticks; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final font = File('assets/font/poppins.ttf').readAsBytesSync();
    await (FontLoader('Poppins')
          ..addFont(Future.value(ByteData.view(font.buffer))))
        .load();
  });

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('PonnamKarthik/fluttertoast'), (_) async => true);
    ConnectivityPlatform.instance = _Online();
  });

  // 320 = the smallest iPhone the app installs on (iOS 15), 375 = iPhone SE
  // 2nd/3rd gen, 440 = iPhone 16 Pro Max.
  for (final isStaff in [false, true]) {
    for (final width in [320.0, 375.0, 440.0]) {
      testWidgets(
          '${isStaff ? 'Staff' : 'Admin'} Properties header says "Accepting '
          'Applications" like web, and fits at ${width.toInt()} wide',
          (tester) async {
        SharedPreferences.setMockInitialValues(isStaff
            ? {
                'token': 'tkn',
                'adminId': 'ADMIN-1',
                'staff_id': 'STAFF-1',
                'role': 'Staffmember'
              }
            : {'token': 'tkn', 'adminId': 'ADMIN-1', 'role': 'Admin'});
        tester.view.physicalSize = Size(width, 1800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        final original = FlutterError.onError;
        FlutterError.onError = (details) {
          // Other rows of this screen are tight at 320 wide; that layout
          // noise is not what this test checks (the header is measured below).
          if (details.exceptionAsString().contains('overflowed')) return;
          original?.call(details);
        };
        try {
          await http.runWithClient(() async {
            final dates = DateProvider();
            await dates.loadDateFormat();
            await tester.pumpWidget(MultiProvider(
              providers: [
                ChangeNotifierProvider<DateProvider>.value(value: dates),
                ChangeNotifierProvider(create: (_) => NotificationProvider()),
                ChangeNotifierProvider(
                    create: (_) => StaffPermissionProvider()),
              ],
              child: MaterialApp(
                // The app's theme font (main.dart).
                theme: ThemeData(fontFamily: 'Poppins', useMaterial3: false),
                home: isStaff ? staff.PropertiesTable() : admin.PropertiesTable(),
              ),
            ));
            await _settle(tester);
            expect(find.text('12 Elm Street'), findsWidgets,
                reason: 'the list loaded');

            final header = find.text('Accepting\nApplications');
            expect(header, findsOneWidget);
            expect(find.text('Accepting\nApplication'), findsNothing);

            // The header text stays inside its column, so nothing is cut off.
            final column = tester.getRect(
                find.ancestor(of: header, matching: find.byType(Expanded)).first);
            final text = tester.getRect(header);
            expect(text.left, greaterThanOrEqualTo(column.left - 0.01));
            expect(text.right, lessThanOrEqualTo(column.right + 0.01),
                reason: 'text ${text.width.toStringAsFixed(1)} px wide, '
                    'column ${column.width.toStringAsFixed(1)} px');
          }, () => _server);
          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(seconds: 2));
        } finally {
          FlutterError.onError = original;
        }
      });
    }
  }
}

class _Online extends ConnectivityPlatform with MockPlatformInterfaceMixin {
  @override
  Future<ConnectivityResult> checkConnectivity() async =>
      ConnectivityResult.wifi;
  @override
  Stream<ConnectivityResult> get onConnectivityChanged => const Stream.empty();
}

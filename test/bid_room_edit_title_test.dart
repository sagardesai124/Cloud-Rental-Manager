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
import 'package:three_zero_two_property/Model/bid_request.dart';
import 'package:three_zero_two_property/StaffModule/repository/staffpermission_provider.dart';
import 'package:three_zero_two_property/provider/dateProvider.dart';
import 'package:three_zero_two_property/provider/notification_provider.dart';
import 'package:three_zero_two_property/screens/BidRoom/create_bid_room.dart';
import 'package:three_zero_two_property/widgets/titleBar.dart';

/// Bid Room → pencil (edit): the screen heading reads "Edit Bid Room", like
/// live staging web (AddBidRequest: `isEditMode ? "Edit Bid Room" : "Create
/// Bid Room"`). Only the submit button says "Update Bid Room", on web and on
/// the phone. Admin and Staff open the same form.

final _server = MockClient((request) async {
  Object body = {'statusCode': 200, 'data': []};
  if (request.url.path.startsWith('/api/rentals/rentals/')) {
    body = {
      'statusCode': 200,
      'data': [
        {'rental_id': 'R-1', 'rental_adress': '12 Elm Street'}
      ],
    };
  }
  return http.Response(jsonEncode(body), 200,
      headers: {'content-type': 'application/json'});
});

final _existing = BidRequest(
  bidRequestId: 'BR-1',
  rentalId: 'R-1',
  description: 'Fix the roof',
  status: 'Open',
  dueDate: '2026-12-01',
  selectedVendorIds: const [],
  bidRequestImages: const [],
);

Future<void> _settle(WidgetTester tester, [int ticks = 30]) async {
  for (var i = 0; i < ticks; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Finder _heading(String text) =>
    find.descendant(of: find.byType(titleBar), matching: find.text(text));
Finder _button(String text) =>
    find.descendant(of: find.byType(ElevatedButton), matching: find.text(text));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('PonnamKarthik/fluttertoast'), (_) async => true);
    ConnectivityPlatform.instance = _Online();
  });

  Future<void> open(WidgetTester tester,
      {required bool isStaff, required bool edit}) async {
    SharedPreferences.setMockInitialValues(isStaff
        ? {
            'token': 'tkn',
            'adminId': 'ADMIN-1',
            'staff_id': 'STAFF-1',
            'role': 'Staffmember'
          }
        : {'token': 'tkn', 'adminId': 'ADMIN-1', 'role': 'Admin'});
    tester.view.physicalSize = const Size(430, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final dates = DateProvider();
    await dates.loadDateFormat();
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<DateProvider>.value(value: dates),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => StaffPermissionProvider()),
      ],
      child: MaterialApp(
        home: CreateBidRoom(
          useStaffLayout: isStaff,
          existingBidRequest: edit ? _existing : null,
        ),
      ),
    ));
    await _settle(tester);
  }

  Future<void> run(WidgetTester tester, Future<void> Function() body) async {
    final original = FlutterError.onError;
    FlutterError.onError = (details) {
      // The test font draws every glyph as a full em square, so dense rows
      // overflow at phone width; that layout noise is ignored.
      if (details.exceptionAsString().contains('overflowed')) return;
      original?.call(details);
    };
    try {
      await http.runWithClient(body, () => _server);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
    } finally {
      FlutterError.onError = original;
    }
  }

  for (final isStaff in [false, true]) {
    final role = isStaff ? 'Staff' : 'Admin';

    testWidgets('$role edit: heading "Edit Bid Room", button "Update Bid Room"',
        (tester) async {
      await run(tester, () async {
        await open(tester, isStaff: isStaff, edit: true);
        expect(find.text('Fix the roof'), findsOneWidget,
            reason: 'the edit form opened with the bid room filled in');
        expect(_heading('Edit Bid Room'), findsOneWidget);
        expect(_button('Update Bid Room'), findsOneWidget,
            reason: 'the submit button keeps web\'s "Update Bid Room"');
        expect(find.text('Update Bid Room'), findsOneWidget,
            reason: 'only the button says Update');
        expect(find.text('Create Bid Room'), findsNothing);
      });
    });

    testWidgets('$role create: heading and button stay "Create Bid Room"',
        (tester) async {
      await run(tester, () async {
        await open(tester, isStaff: isStaff, edit: false);
        expect(_heading('Create Bid Room'), findsOneWidget);
        expect(_button('Create Bid Room'), findsOneWidget);
        expect(find.text('Edit Bid Room'), findsNothing);
        expect(find.text('Update Bid Room'), findsNothing);
      });
    });
  }
}

class _Online extends ConnectivityPlatform with MockPlatformInterfaceMixin {
  @override
  Future<ConnectivityResult> checkConnectivity() async =>
      ConnectivityResult.wifi;
  @override
  Stream<ConnectivityResult> get onConnectivityChanged => const Stream.empty();
}

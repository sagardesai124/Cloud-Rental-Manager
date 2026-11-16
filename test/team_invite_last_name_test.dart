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
import 'package:three_zero_two_property/provider/Plan%20Purchase/plancheckProvider.dart';
import 'package:three_zero_two_property/provider/dateProvider.dart';
import 'package:three_zero_two_property/provider/notification_provider.dart';
import 'package:three_zero_two_property/screens/Team_Access/add_admin_screen.dart';
import 'package:three_zero_two_property/screens/Team_Access/add_staff_screen.dart';

/// Team & Access › Add Admin / Add Staff, like web staging
/// (InviteUserModal.jsx, used by both "Add Administrator" and "Add Staff"):
/// Last name is required. A blank (or spaces-only) Last Name shows
/// "Last name is required." and nothing is sent to the server — before,
/// the app sent the invite and showed the server's raw refusal as a toast.

const _msg = 'Last name is required.';

class _Case {
  const _Case(this.name, this.screen, this.firstHint, this.lastHint,
      this.button, this.endpoint, this.sentName);
  final String name;
  final Widget screen;
  final String firstHint;
  final String lastHint;
  final String button;
  final String endpoint;
  final String sentName; // what the server must receive once filled in
}

const _cases = [
  _Case('Add Admin', AddAdminScreen(), 'Enter first name', 'Enter last name',
      'Send Invite', '/api/admin/team/invite-coadmin', '"last_name":"Owner"'),
  _Case('Add Staff', AddStaffScreen(), 'First name', 'Last name', 'Add Staff',
      '/api/admin/team/invite-staff', '"staffmember_name":"Pat Owner"'),
];

void main() {
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('PonnamKarthik/fluttertoast'),
            (_) async => true);
    ConnectivityPlatform.instance = _Online();
  });

  for (final c in _cases) {
    testWidgets(
        '${c.name}: blank Last Name is stopped like web; filled in, it sends',
        (tester) async {
      SharedPreferences.setMockInitialValues(
          {'token': 'tkn', 'adminId': 'ADMIN-1', 'role': 'Admin'});
      final invites = <http.Request>[];
      final server = MockClient((request) async {
        if (request.url.path == c.endpoint) {
          invites.add(request);
          return _json({'statusCode': 200, 'message': 'Invitation sent.'});
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
        await tester.pumpWidget(MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => DateProvider()),
            ChangeNotifierProvider(create: (_) => NotificationProvider()),
            ChangeNotifierProvider(create: (_) => checkPlanPurchaseProiver()),
            ChangeNotifierProvider(create: (_) => StaffPermissionProvider()),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (ctx) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.of(ctx)
                      .push(MaterialPageRoute(builder: (_) => c.screen)),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ));
        await tester.tap(find.text('open'));
        await _settle(tester, 20);

        Finder box(String hint) => find.byWidgetPredicate(
            (w) => w is TextField && w.decoration?.hintText == hint);

        // The label shows the required star, like web.
        expect(
            find.byWidgetPredicate((w) =>
                w is RichText && w.text.toPlainText() == 'Last Name *'),
            findsOneWidget);

        await tester.enterText(box(c.firstHint), 'Pat');
        await tester.enterText(box('Enter email'), 'pat@example.com');

        // Blank Last Name: web's message, nothing sent.
        await tester.tap(find.text(c.button));
        await _settle(tester, 10);
        expect(find.text(_msg), findsOneWidget);
        expect(invites, isEmpty);

        // Only spaces: still blank, like web's trim().
        await tester.enterText(box(c.lastHint), '   ');
        await tester.tap(find.text(c.button));
        await _settle(tester, 10);
        expect(find.text(_msg), findsOneWidget);
        expect(invites, isEmpty);

        // Typing a last name clears the message; then it sends.
        await tester.enterText(box(c.lastHint), 'Owner');
        await tester.pump();
        expect(find.text(_msg), findsNothing);
        await tester.tap(find.text(c.button));
        await _settle(tester, 30);
        expect(invites, hasLength(1));
        expect(invites.single.body, contains(c.sentName));
        expect(find.text('open'), findsOneWidget,
            reason: 'screen closes after the invite is sent');

        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 5));
      }, () => server);
    });
  }
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

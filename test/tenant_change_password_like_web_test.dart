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
import 'package:three_zero_two_property/TenantsModule/screen/change_password.dart';
import 'package:three_zero_two_property/provider/notification_provider.dart';

/// Tenant portal → Change Password reads like web staging
/// (TenantPassChange.jsx): "Please enter current password" (spaces alone
/// count as empty), "Password is required.", "Please confirm your new
/// password", "Passwords do not match", and the "Enter Your New Password" /
/// "Confirm Password" placeholders. The password rules and the save request
/// are unchanged.

class _Server {
  final List<http.Request> puts = [];
  late final MockClient client = MockClient((request) async {
    if (request.method == 'PUT') {
      puts.add(request);
      return http.Response(
          jsonEncode({'message': 'Current password is incorrect'}), 400,
          headers: {'content-type': 'application/json'});
    }
    return http.Response(jsonEncode({'statusCode': 200, 'data': []}), 200,
        headers: {'content-type': 'application/json'});
  });
}

Future<void> _settle(WidgetTester tester, [int ticks = 20]) async {
  for (var i = 0; i < ticks; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// The phone form's box showing [hint].
Finder _box(String hint) => find.byWidgetPredicate(
    (w) => w is TextField && w.decoration?.hintText == hint,
    description: 'box with hint "$hint"');

Future<void> _tapChangePassword(WidgetTester tester) async {
  final button = find.text('Change Password').last;
  await tester.ensureVisible(button);
  await tester.tap(button);
  await _settle(tester);
}

Future<void> _onScreen(
    WidgetTester tester, Future<void> Function(_Server server) body) async {
  // Phone width: the live form with Current, New and Confirm Password.
  tester.view.physicalSize = const Size(430, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final original = FlutterError.onError;
  FlutterError.onError = (details) {
    // The test font draws every glyph as a full em square, so dense rows
    // overflow at phone width; that layout noise is ignored.
    if (details.exceptionAsString().contains('overflowed')) return;
    original?.call(details);
  };
  final server = _Server();
  try {
    await http.runWithClient(() async {
      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ],
        child: const MaterialApp(home: Change_password()),
      ));
      await _settle(tester);
      await body(server);
    }, () => server.client);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
  } finally {
    FlutterError.onError = original;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('PonnamKarthik/fluttertoast'), (_) async => true);
    ConnectivityPlatform.instance = _Online();
    SharedPreferences.setMockInitialValues({
      'token': 'tkn',
      'tenant_id': 'T-1',
      'adminId': 'ADMIN-1',
      'role': 'Tenant',
      'email': 'tenant@example.com',
    });
  });

  testWidgets("the boxes use web's placeholders", (tester) async {
    await _onScreen(tester, (server) async {
      expect(_box('Current Password'), findsOneWidget);
      expect(_box('Enter Your New Password'), findsOneWidget);
      expect(_box('Confirm Password'), findsOneWidget);
      expect(_box('New Password'), findsNothing);
      expect(_box('Confirm password'), findsNothing);
    });
  });

  testWidgets("empty boxes show web's messages", (tester) async {
    await _onScreen(tester, (server) async {
      await _tapChangePassword(tester);

      expect(find.text('Please enter current password'), findsOneWidget);
      expect(find.text('Password is required.'), findsOneWidget);
      expect(find.text('Please confirm your new password'), findsOneWidget);
      for (final old in [
        'Current password is required',
        'Password is required',
        'Confirm password is required',
      ]) {
        expect(find.text(old), findsNothing, reason: old);
      }
      expect(server.puts, isEmpty);
    });
  });

  testWidgets('a Current Password of only spaces counts as empty, like web',
      (tester) async {
    await _onScreen(tester, (server) async {
      await tester.enterText(_box('Current Password'), '   ');
      await tester.enterText(_box('Enter Your New Password'), 'Abcdefg#1234');
      await tester.enterText(_box('Confirm Password'), 'Abcdefg#1234');
      await _tapChangePassword(tester);

      expect(find.text('Please enter current password'), findsOneWidget);
      expect(server.puts, isEmpty);
    });
  });

  testWidgets('different new passwords show "Passwords do not match"',
      (tester) async {
    await _onScreen(tester, (server) async {
      await tester.enterText(_box('Current Password'), 'OldPass#2024');
      await tester.enterText(_box('Enter Your New Password'), 'Abcdefg#1234');
      await tester.enterText(_box('Confirm Password'), 'Abcdefg#9999');
      await _tapChangePassword(tester);

      expect(find.text('Passwords do not match'), findsOneWidget);
      expect(find.text('Both passwords do not match'), findsNothing);
      expect(server.puts, isEmpty);
    });
  });

  testWidgets('the password rules and the save request are unchanged',
      (tester) async {
    await _onScreen(tester, (server) async {
      await tester.enterText(_box('Current Password'), 'OldPass#2024');
      await tester.enterText(_box('Enter Your New Password'), 'Ab#1');
      await tester.enterText(_box('Confirm Password'), 'Ab#1');
      await _tapChangePassword(tester);
      expect(find.text('Password must have at least 8 characters'),
          findsOneWidget);
      expect(server.puts, isEmpty);

      await tester.enterText(_box('Enter Your New Password'), 'Abcdefg#1234');
      await tester.enterText(_box('Confirm Password'), 'Abcdefg#1234');
      await _tapChangePassword(tester);

      expect(server.puts, hasLength(1));
      final put = server.puts.single;
      expect(put.url.path, '/api/tenant/reset_password_v2');
      expect(put.bodyFields['currentPassword'], 'OldPass#2024');
      expect(put.bodyFields['password'], 'Abcdefg#1234');
      // The server's answer still shows under Current Password.
      expect(find.text('Current password is incorrect'), findsOneWidget);
    });
  });
}

class _Online extends ConnectivityPlatform with MockPlatformInterfaceMixin {
  @override
  Future<ConnectivityResult> checkConnectivity() async =>
      ConnectivityResult.wifi;
  @override
  Stream<ConnectivityResult> get onConnectivityChanged => const Stream.empty();
}

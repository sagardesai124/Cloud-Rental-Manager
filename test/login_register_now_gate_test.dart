import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:three_zero_two_property/constant/constant.dart';
import 'package:three_zero_two_property/screens/Login/login_screen.dart';

/// Sign-up is closed on the server, so the Login screen's "Register now" row
/// shows only when GET /api/admin/signup-enabled answers data.enabled == true,
/// the same rule as web (Login.jsx signupStatus.enabled === true,
/// signupGateway.js isPublicSignupOpen, development-2.3). Closed, an error,
/// a missing route or no answer within 8 s all keep it hidden.
///
/// The sign-up screens say "free account", never "trial", like web
/// (TrialLogin.jsx, commit 13c6a4f10).

const _wide = Size(1024, 2000);
const _phone = Size(390, 2000);

const _staging =
    '{"statusCode":200,"data":{"enabled":false},"message":"New account signups are temporarily unavailable. Please contact support@cloudrentalmanager.com."}';

final _trial = RegExp('trial', caseSensitive: false);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final probes = <http.Request>[];

  setUp(() {
    probes.clear();
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('PonnamKarthik/fluttertoast'), (_) async => true);
  });

  http.Response body(String b, [int status = 200]) => http.Response(b, status);

  Future<void> pumpLogin(
    WidgetTester tester,
    Size size,
    Future<http.Response> Function(http.Request) server,
    Future<void> Function() check,
  ) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    // The test font draws every glyph as a full square, so some rows overflow
    // in tests only; that is not what is checked here.
    final original = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('overflowed')) return;
      original?.call(details);
    };
    try {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: Login_Screen()));
        await check();
        await tester.pumpWidget(const SizedBox());
      }, () => MockClient((r) async {
            if (r.url.path.endsWith('/api/admin/signup-enabled')) probes.add(r);
            return server(r);
          }));
    } finally {
      FlutterError.onError = original;
    }
  }

  Future<void> settleProbe(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  for (final layout in {'tablet': _wide, 'phone': _phone}.entries) {
    testWidgets(
        '${layout.key}: sign-up open -> Register now shows and opens sign-up',
        (tester) async {
      await pumpLogin(tester, layout.value,
          (_) async => body('{"statusCode":200,"data":{"enabled":true}}'),
          () async {
        await settleProbe(tester);
        expect(find.text('Register now'), findsOneWidget);

        // One check, to the right URL, without login headers (nobody is
        // signed in yet), like web's probe (credentials: 'omit').
        expect(probes, hasLength(1));
        expect(probes.single.url.toString(), '$Api_url/api/admin/signup-enabled');
        expect(probes.single.headers.containsKey('Authorization'), isFalse);
        expect(probes.single.headers.containsKey('id'), isFalse);

        // Open sign-up. The test font pushes the phone row past the screen
        // edge, so call the row's onTap rather than tapping a coordinate.
        final row = tester.widget<GestureDetector>(find
            .ancestor(
                of: find.text('Register now'),
                matching: find.byType(GestureDetector))
            .first);
        row.onTap!();
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(find.text('Sign up for a free account'), findsOneWidget);
        expect(find.text('Create your free account'), findsOneWidget);
        expect(find.text('Customize Account'), findsOneWidget);
        expect(find.textContaining(_trial), findsNothing);
      });
    });

    testWidgets('${layout.key}: staging says closed -> no Register now',
        (tester) async {
      await pumpLogin(tester, layout.value, (_) async => body(_staging),
          () async {
        await settleProbe(tester);
        expect(find.text('Register now'), findsNothing);
        expect(find.textContaining("Don't have an account"), findsNothing);
        expect(find.text('Login'), findsWidgets, reason: 'sign-in still shown');
      });
    });
  }

  testWidgets('route missing (404) -> no Register now', (tester) async {
    await pumpLogin(tester, _phone,
        (_) async => body('{"statusCode":404}', 404), () async {
      await settleProbe(tester);
      expect(find.text('Register now'), findsNothing);
    });
  });

  testWidgets('network error -> no Register now', (tester) async {
    await pumpLogin(tester, _wide, (_) async => throw Exception('offline'),
        () async {
      await settleProbe(tester);
      expect(find.text('Register now'), findsNothing);
    });
  });

  testWidgets('no answer within 8 s -> stays hidden, even if a late answer says open',
      (tester) async {
    await pumpLogin(tester, _phone, (_) async {
      await Future<void>.delayed(const Duration(seconds: 10));
      return body('{"data":{"enabled":true}}');
    }, () async {
      await tester.pump(const Duration(seconds: 7));
      expect(find.text('Register now'), findsNothing);
      await tester.pump(const Duration(seconds: 2)); // past the 8 s limit
      expect(find.text('Register now'), findsNothing);
      await tester.pump(const Duration(seconds: 2)); // the late answer lands
      await tester.pump();
      expect(find.text('Register now'), findsNothing);
    });
  });

  test('no "trial" text left in the sign-up screens (like web 13c6a4f10)', () {
    // Covers text the widget test cannot reach, such as the dialog shown after
    // a successful sign-up. Only string literals in code are checked, not
    // comments or class names.
    // A "double" or 'single' quoted string on one line.
    final literal =
        RegExp(r'"(?:[^"\\\n]|\\.)*"' '|' r"'(?:[^'\\\n]|\\.)*'");
    final found = <String>[];
    for (final path in [
      'lib/screens/Signup/signup_screen.dart',
      'lib/screens/Signup/signup2_screen.dart',
    ]) {
      final lines = File(path).readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (lines[i].trimLeft().startsWith('//')) continue;
        for (final m in literal.allMatches(lines[i])) {
          if (_trial.hasMatch(m.group(0)!)) {
            found.add('$path:${i + 1} ${m.group(0)}');
          }
        }
      }
    }
    expect(found, isEmpty);
  });
}

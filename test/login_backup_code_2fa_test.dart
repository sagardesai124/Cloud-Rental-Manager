import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:three_zero_two_property/screens/Login/login_screen.dart';

/// Backup-code sign-in, matched to web (Login.jsx, development-2.2) and the
/// 2.2 server (Login.js):
/// - the 205 challenge carries otp_id, user_id, user_type and has_backup_codes;
/// - "Use backup code instead" is offered from has_backup_codes — the old
///   pre-login GET /backup-codes/backup-codes/:user_id now needs a session;
/// - verify sends otp_id in BOTH modes plus the challenge's user_id/user_type
///   (a backup code is only accepted against that pending sign-in);
/// - a code must be 6 digits in both modes (backup codes are 6-digit numbers).

class _FakeServer {
  _FakeServer({
    required this.role,
    required this.userType,
    required this.hasBackupCodes,
    this.oldServer = false,
  });

  /// A server older than the 2026-10-05 release (staging, as of 2026-10-07):
  /// the challenge has no has_backup_codes, and the backup-code lookup still
  /// answers without a session.
  final bool oldServer;

  /// Role the account picker (check-credentials) reports.
  final String role;

  /// user_type the 205 challenge names.
  final String userType;
  final bool hasBackupCodes;

  final List<http.Request> requests = [];
  Map<String, dynamic>? verifyBody;

  static http.Response _json(Object body, [int status = 200]) => http.Response(
      jsonEncode(body), status,
      headers: {'content-type': 'application/json'});

  Future<http.Response> handle(http.Request r) async {
    requests.add(r);
    final path = r.url.path;
    if (path.endsWith('/api/auth/check-credentials')) {
      return _json({
        'shouldLogin': true,
        'data': [
          {
            'role': role,
            'admin_id': 'ADMIN-1',
            'user_id': 'PICKER-USER',
            'userName': 'Pat',
            'company_name': 'Acme',
          }
        ],
      });
    }
    if (path.contains('/api/admin/check_company/')) {
      return _json({
        'statusCode': 200,
        'data': {'admin_id': 'ADMIN-1'},
      });
    }
    if (path.endsWith('/api/auth/login')) {
      return _json({
        'statusCode': 205,
        'message': 'Verification code sent to your email',
        'data': {
          'requires2FA': true,
          'method': 'email',
          'otp_id': 'OTP-1',
          'user_id': 'SRV-USER',
          'user_type': userType,
          if (!oldServer) 'has_backup_codes': hasBackupCodes,
        },
      });
    }
    if (path.contains('/api/backup-codes/')) {
      if (oldServer) {
        return hasBackupCodes
            ? _json({'statusCode': 200, 'data': {'codes': []}})
            : _json({'statusCode': 404, 'message': 'No backup codes found'}, 404);
      }
      // 2.2: verifyToken + requireSelf — the login screen has no session yet.
      return _json({'statusCode': 401, 'message': 'Unauthorized'}, 401);
    }
    if (path.endsWith('/api/auth/verify-login-2fa')) {
      verifyBody = jsonDecode(r.body) as Map<String, dynamic>;
      // Reject, so the test stops before post-login navigation.
      return _json({'statusCode': 400, 'message': 'Code not accepted'});
    }
    return _json({'statusCode': 404, 'message': 'unexpected $path'}, 404);
  }

  Iterable<http.Request> get backupCodeLookups =>
      requests.where((r) => r.url.path.contains('/api/backup-codes/'));
}

Finder _field(String hint) => find.byWidgetPredicate(
    (w) => w is TextField && w.decoration?.hintText == hint);

/// Lets the fake network replies and the resulting setState calls land.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
}

/// Pumps the real login screen at [size] and signs in up to the 2FA challenge.
Future<void> _reachChallenge(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(const MaterialApp(home: Login_Screen()));
  await tester.pump();
  await tester.enterText(_field('Email Address'), 'pat@example.com');
  await tester.enterText(_field('Password'), 'Secret#123');
  await _tap(tester, find.text('Login').last);
  await _settle(tester);
  expect(find.text('Verify & Login'), findsOneWidget,
      reason: 'the 2FA challenge should be showing');
}

/// Disposes the screen so its 2FA countdown timer is cancelled.
Future<void> _finish(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
}

const _wide = Size(1024, 2000); // first layout copy (maxWidth > 500)
const _phone = Size(390, 2000); // second layout copy

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // Fluttertoast talks to a platform channel; answer it so toasts no-op.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('PonnamKarthik/fluttertoast'), (_) async => true);
  });

  /// Runs [body] against [server]. The test font draws every glyph as a full
  /// em square, so rows that fit on a device overflow here; that layout noise
  /// is ignored — only what the screen sends and offers is under test.
  Future<void> run(_FakeServer server, Future<void> Function() body) async {
    final original = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('overflowed')) return;
      original?.call(details);
    };
    try {
      await http.runWithClient(body, () => MockClient(server.handle));
    } finally {
      FlutterError.onError = original;
    }
  }

  testWidgets(
      'Admin: backup code verifies against the pending sign-in (wide layout)',
      (tester) async {
    final server =
        _FakeServer(role: 'admin', userType: 'admin', hasBackupCodes: true);
    await run(server, () async {
      await _reachChallenge(tester, _wide);
      expect(server.backupCodeLookups, isEmpty,
          reason: 'no pre-login backup-code lookup (2.2 refuses it)');

      await _tap(tester, find.text('Use backup code instead'));
      await tester.pump();
      await tester.enterText(_field('Enter backup code'), '123456');
      await _tap(tester, find.text('Verify & Login'));
      await _settle(tester);

      expect(server.verifyBody, isNotNull);
      expect(server.verifyBody!['code'], '123456');
      expect(server.verifyBody!['is_backup_code'], true);
      expect(server.verifyBody!['otp_id'], 'OTP-1');
      expect(server.verifyBody!['user_id'], 'SRV-USER');
      expect(server.verifyBody!['user_type'], 'admin');
      await _finish(tester);
    });
  });

  testWidgets(
      'Staff: backup code sends user_type "staff" from the challenge (phone layout)',
      (tester) async {
    final server = _FakeServer(
        role: 'staffmember', userType: 'staff', hasBackupCodes: true);
    await run(server, () async {
      await _reachChallenge(tester, _phone);
      expect(server.backupCodeLookups, isEmpty);

      await _tap(tester, find.text('Use backup code instead'));
      await tester.pump();
      await tester.enterText(_field('Enter backup code'), '654321');
      await _tap(tester, find.text('Verify & Login'));
      await _settle(tester);

      expect(server.verifyBody, isNotNull);
      expect(server.verifyBody!['is_backup_code'], true);
      expect(server.verifyBody!['otp_id'], 'OTP-1');
      expect(server.verifyBody!['user_id'], 'SRV-USER');
      expect(server.verifyBody!['user_type'], 'staff');
      await _finish(tester);
    });
  });

  testWidgets('Tenant: backup code sends user_type "tenant" from the challenge',
      (tester) async {
    final server =
        _FakeServer(role: 'tenant', userType: 'tenant', hasBackupCodes: true);
    await run(server, () async {
      await _reachChallenge(tester, _phone);
      expect(server.backupCodeLookups, isEmpty);

      await _tap(tester, find.text('Use backup code instead'));
      await tester.pump();
      await tester.enterText(_field('Enter backup code'), '112233');
      await _tap(tester, find.text('Verify & Login'));
      await _settle(tester);

      expect(server.verifyBody, isNotNull);
      expect(server.verifyBody!['is_backup_code'], true);
      expect(server.verifyBody!['otp_id'], 'OTP-1');
      expect(server.verifyBody!['user_id'], 'SRV-USER');
      expect(server.verifyBody!['user_type'], 'tenant');
      await _finish(tester);
    });
  });

  testWidgets('Older server (staging): backup codes offered via the old lookup',
      (tester) async {
    final server = _FakeServer(
        role: 'staffmember',
        userType: 'staff',
        hasBackupCodes: true,
        oldServer: true);
    await run(server, () async {
      await _reachChallenge(tester, _phone);
      expect(server.backupCodeLookups, hasLength(1));
      final lookup = server.backupCodeLookups.single.url;
      expect(lookup.path, '/api/backup-codes/backup-codes/PICKER-USER');
      expect(lookup.queryParameters['user_type'], 'staff');

      await _tap(tester, find.text('Use backup code instead'));
      await tester.pump();
      await tester.enterText(_field('Enter backup code'), '135790');
      await _tap(tester, find.text('Verify & Login'));
      await _settle(tester);

      expect(server.verifyBody, isNotNull);
      expect(server.verifyBody!['is_backup_code'], true);
      expect(server.verifyBody!['otp_id'], 'OTP-1');
      expect(server.verifyBody!['user_id'], 'SRV-USER');
      expect(server.verifyBody!['user_type'], 'staff');
      await _finish(tester);
    });
  });

  testWidgets('Older server (staging), no backup codes: option not offered',
      (tester) async {
    final server = _FakeServer(
        role: 'admin',
        userType: 'admin',
        hasBackupCodes: false,
        oldServer: true);
    await run(server, () async {
      await _reachChallenge(tester, _wide);
      expect(server.backupCodeLookups, hasLength(1));
      expect(find.text('Use backup code instead'), findsNothing);
      await _finish(tester);
    });
  });

  testWidgets('No unused backup codes: the backup option is not offered',
      (tester) async {
    final server =
        _FakeServer(role: 'admin', userType: 'admin', hasBackupCodes: false);
    await run(server, () async {
      await _reachChallenge(tester, _wide);
      expect(find.text('Use backup code instead'), findsNothing);
      await _finish(tester);
    });
  });

  testWidgets('Backup code must be 6 digits, as on web', (tester) async {
    final server =
        _FakeServer(role: 'admin', userType: 'admin', hasBackupCodes: true);
    await run(server, () async {
      await _reachChallenge(tester, _phone);
      await _tap(tester, find.text('Use backup code instead'));
      await tester.pump();
      await tester.enterText(_field('Enter backup code'), '12345');
      await _tap(tester, find.text('Verify & Login'));
      await _settle(tester);

      expect(server.verifyBody, isNull, reason: 'nothing sent for 5 digits');
      expect(find.text('Please enter the complete 6-digit code'), findsOneWidget);
      await _finish(tester);
    });
  });

  testWidgets('Emailed/texted code path is unchanged', (tester) async {
    final server =
        _FakeServer(role: 'admin', userType: 'admin', hasBackupCodes: true);
    await run(server, () async {
      await _reachChallenge(tester, _wide);
      await tester.enterText(_field('Enter 6 digit code'), '246810');
      await _tap(tester, find.text('Verify & Login'));
      await _settle(tester);

      expect(server.verifyBody, isNotNull);
      expect(server.verifyBody!['code'], '246810');
      expect(server.verifyBody!['is_backup_code'], false);
      expect(server.verifyBody!['otp_id'], 'OTP-1');
      await _finish(tester);
    });
  });
}

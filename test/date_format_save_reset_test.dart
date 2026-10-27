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
import 'package:three_zero_two_property/provider/color_theme.dart';
import 'package:three_zero_two_property/provider/dateProvider.dart';
import 'package:three_zero_two_property/provider/notification_provider.dart';
import 'package:three_zero_two_property/screens/Profile/Settings_screen.dart';

/// Settings → Date Format works like web staging (DateFormatSection.jsx):
/// - picking a time format only changes the screen; nothing is saved;
/// - Save Changes and Reset are greyed out (do nothing) until the date or
///   time choice differs from what is saved;
/// - Save stores the choice; Reset goes back to YYYY-MM-DD + 24-hour and
///   saves that, with web's "Date and time format reset".
/// Before: tapping 12-hour/24-hour saved straight away, both buttons were
/// always active, and Reset reloaded the last saved choice.

/// Every save (POST /api/themes/date-format) the screen sends.
final List<Map<String, dynamic>> _saves = [];
final List<String> _toasts = [];

final _server = MockClient((request) async {
  final path = request.url.path;
  Object body = {'statusCode': 200, 'data': []};
  if (path == '/api/auth') {
    body = {
      'statusCode': 200,
      'themes': {'format': 'MM/DD/YYYY', 'timeFormat': '24'}
    };
  } else if (path == '/api/themes/date-format') {
    _saves.add(jsonDecode(request.body) as Map<String, dynamic>);
    body = {'statusCode': 200, 'message': 'ok'};
  }
  return http.Response(jsonEncode(body), 200,
      headers: {'content-type': 'application/json'});
});

Future<void> _settle(WidgetTester tester, [int ticks = 30]) async {
  for (var i = 0; i < ticks; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

GestureDetector _button(WidgetTester tester, String label) => tester.widget(
    find.ancestor(of: find.text(label), matching: find.byType(GestureDetector)).first);

Future<void> _tap(WidgetTester tester, String label) async {
  final target = find.text(label).last;
  await tester.ensureVisible(target);
  await tester.pump();
  await tester.tap(target, warnIfMissed: false);
  await _settle(tester, 20);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    _saves.clear();
    _toasts.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('PonnamKarthik/fluttertoast'), (call) async {
      if (call.method == 'showToast') {
        _toasts.add('${(call.arguments as Map)['msg']}');
      }
      return true;
    });
    ConnectivityPlatform.instance = _OnlineConnectivity();
    SharedPreferences.setMockInitialValues(
        {'token': 'tkn', 'adminId': 'ADMIN-1', 'role': 'Admin'});
  });

  testWidgets('Date Format: Save/Reset greyed until a change; time picks save only on Save; Reset = web defaults',
      (tester) async {
    tester.view.physicalSize = const Size(430, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final original = FlutterError.onError;
    FlutterError.onError = (details) {
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
            ChangeNotifierProvider(create: (_) => ThemeProvider()),
            ChangeNotifierProvider(create: (_) => NotificationProvider()),
          ],
          child: const MaterialApp(home: TabBarExample()),
        ));
        await _settle(tester, 40);

        // Open Settings → Date Format.
        await _tap(tester, 'Date Format');
        await _settle(tester, 20);
        expect(find.text('Manage Date & Time Format'), findsOneWidget);

        // Nothing changed yet: both buttons do nothing.
        expect(_button(tester, 'Save Changes').onTap, isNull);
        expect(_button(tester, 'Reset').onTap, isNull);

        // Picking 12-hour only changes the screen.
        await _tap(tester, '12-hour format');
        expect(_saves, isEmpty, reason: 'not saved until Save Changes');
        expect(_button(tester, 'Save Changes').onTap, isNotNull);
        expect(_button(tester, 'Reset').onTap, isNotNull);

        // Picking 24-hour again = back to what is saved: greyed out again.
        await _tap(tester, '24-hour format');
        expect(_saves, isEmpty);
        expect(_button(tester, 'Save Changes').onTap, isNull);

        // Change and Save: stored, then nothing left to save.
        await _tap(tester, '12-hour format');
        await _tap(tester, 'Save Changes');
        await _settle(tester, 20);
        expect(_saves, hasLength(1));
        expect(_saves.single['timeFormat'], '12');
        expect(_saves.single['format'], 'MM/DD/YYYY');
        expect(_toasts, contains('Date and time format updated'),
            reason: "web's save message");
        expect(_button(tester, 'Save Changes').onTap, isNull,
            reason: 'saved, nothing left to save');

        // Reset (after a change): web defaults, saved.
        await _tap(tester, 'YYYY-MMM-DD');
        expect(_button(tester, 'Reset').onTap, isNotNull);
        await _tap(tester, 'Reset');
        await _settle(tester, 20);
        expect(_saves, hasLength(2));
        expect(_saves.last['format'], 'YYYY-MM-DD');
        expect(_saves.last['timeFormat'], '24');
        expect(_toasts, contains('Date and time format reset'));
        expect(_button(tester, 'Reset').onTap, isNull);
      }, () => _server);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    } finally {
      FlutterError.onError = original;
    }
  });
}

class _OnlineConnectivity extends ConnectivityPlatform
    with MockPlatformInterfaceMixin {
  @override
  Future<ConnectivityResult> checkConnectivity() async =>
      ConnectivityResult.wifi;
  @override
  Stream<ConnectivityResult> get onConnectivityChanged => const Stream.empty();
}

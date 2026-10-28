import 'dart:convert';

import 'package:connectivity_plus_platform_interface/connectivity_plus_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/intl.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:three_zero_two_property/provider/color_theme.dart';
import 'package:three_zero_two_property/provider/dateProvider.dart';
import 'package:three_zero_two_property/provider/notification_provider.dart';
import 'package:three_zero_two_property/screens/Profile/Settings_screen.dart';

/// QA (Android 1.0.245+248): a company saved with a custom date format
/// (web: Custom "DD/MMM/YYYY") shows as MM/DD/YYYY in the app, which cannot
/// show custom formats yet. Changing only the time and tapping Save Changes
/// used to send format "MM/DD/YYYY" and replace the custom format.
/// Like web (Settings.jsx setDateFormat re-sends the format it loaded), a
/// time-only save now sends the date format back exactly as it is saved;
/// picking another date option still saves that option.
///
/// Also like web: Save no longer rewrites the custom box (it kept showing the
/// last saved preset as the Custom sample), an empty custom format is refused
/// instead of being swapped for another format, and a time-only save made
/// right after a date save sends the new date format, not the old one.

/// The company's saved theme the fake server returns from /api/auth. Saves
/// are applied to it, like the real server.
Map<String, String> _theme = {};

/// Every save (POST /api/themes/date-format) the screen sends.
final List<Map<String, dynamic>> _saves = [];
final List<String> _toasts = [];

/// When true, /api/auth answers 3 s late (a slow reload after a save).
bool _slowAuth = false;

/// When true, the server refuses date-format saves (e.g. Staff → 403).
bool _failSaves = false;

final _server = MockClient((request) async {
  final path = request.url.path;
  Object body = {'statusCode': 200, 'data': []};
  if (path == '/api/auth') {
    if (_slowAuth) await Future<void>.delayed(const Duration(seconds: 3));
    body = {'statusCode': 200, 'themes': Map.of(_theme)};
  } else if (path == '/api/themes/date-format') {
    final sent = jsonDecode(request.body) as Map<String, dynamic>;
    _saves.add(sent);
    if (_failSaves) {
      return http.Response(
          jsonEncode({'statusCode': 403, 'message': 'Forbidden'}), 403,
          headers: {'content-type': 'application/json'});
    }
    _theme = {
      'format': '${sent['format'] ?? _theme['format']}',
      'timeFormat': '${sent['timeFormat'] ?? _theme['timeFormat']}',
    };
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

Future<void> _tap(WidgetTester tester, String label) async {
  final target = find.text(label).last;
  await tester.ensureVisible(target);
  await tester.pump();
  await tester.tap(target, warnIfMissed: false);
  await _settle(tester, 20);
}

/// Taps without waiting, for back-to-back taps.
Future<void> _quickTap(WidgetTester tester, String label) async {
  final target = find.text(label).last;
  await tester.ensureVisible(target);
  await tester.tap(target, warnIfMissed: false);
  await tester.pump(const Duration(milliseconds: 100));
}

GestureDetector _button(WidgetTester tester, String label) => tester.widget(
    find
        .ancestor(of: find.text(label), matching: find.byType(GestureDetector))
        .first);

/// The custom format box (the only text field in the section).
Finder get _customBox => find.byType(TextField);

String get _customSample =>
    DateFormat('dd/MMM/yyyy').format(DateTime.now()); // e.g. 28/Oct/2026

/// Opens Settings → Date Format for a company saved with [format] and
/// [time], runs [body], and tears down.
Future<void> _withDateFormat(WidgetTester tester, String format, String time,
    Future<void> Function() body) async {
  _theme = {'format': format, 'timeFormat': time};
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
      await _tap(tester, 'Date Format');
      await _settle(tester, 20);
      expect(find.text('Manage Date & Time Format'), findsOneWidget);
      await body();
    }, () => _server);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  } finally {
    FlutterError.onError = original;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    _saves.clear();
    _toasts.clear();
    _slowAuth = false;
    _failSaves = false;
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

  group('time-only save keeps the saved date format, like web', () {
    testWidgets(
        'custom DD/MMM/YYYY: opens with Save greyed; changing only the time keeps it',
        (tester) async {
      await _withDateFormat(tester, 'DD/MMM/YYYY', '12', () async {
        expect(_button(tester, 'Save Changes').onTap, isNull,
            reason: 'nothing changed yet');
        await _tap(tester, '24-hour format');
        await _tap(tester, 'Save Changes');
        await _settle(tester, 20);
        expect(_saves, hasLength(1));
        expect(_saves.single, {
          'format': 'DD/MMM/YYYY',
          'timeFormat': '24',
          'admin_id': 'ADMIN-1'
        });
        expect(_button(tester, 'Save Changes').onTap, isNull,
            reason: 'saved, nothing left to save');
      });
    });

    testWidgets('M/D/YYYY (custom on web): a time-only save keeps it',
        (tester) async {
      await _withDateFormat(tester, 'M/D/YYYY', '24', () async {
        await _tap(tester, '12-hour format');
        await _tap(tester, 'Save Changes');
        await _settle(tester, 20);
        expect(_saves, hasLength(1));
        expect(_saves.single['format'], 'M/D/YYYY');
        expect(_saves.single['timeFormat'], '12');
      });
    });

    testWidgets('preset YYYY-MMM-DD: a time-only save keeps it, as before',
        (tester) async {
      await _withDateFormat(tester, 'YYYY-MMM-DD', '24', () async {
        await _tap(tester, '12-hour format');
        await _tap(tester, 'Save Changes');
        await _settle(tester, 20);
        expect(_saves, hasLength(1));
        expect(_saves.single['format'], 'YYYY-MMM-DD');
        expect(_saves.single['timeFormat'], '12');
      });
    });

    testWidgets(
        'custom format: picking another option and back, then the time, keeps it',
        (tester) async {
      await _withDateFormat(tester, 'DD/MMM/YYYY', '12', () async {
        await _tap(tester, 'YYYY-MM-DD');
        await _tap(tester, 'MM/DD/YYYY');
        await _tap(tester, '24-hour format');
        await _tap(tester, 'Save Changes');
        await _settle(tester, 20);
        expect(_saves, hasLength(1));
        expect(_saves.single['format'], 'DD/MMM/YYYY');
        expect(_saves.single['timeFormat'], '24');
      });
    });

    testWidgets('custom format + picking YYYY-MM-DD: the picked format is saved',
        (tester) async {
      await _withDateFormat(tester, 'DD/MMM/YYYY', '12', () async {
        await _tap(tester, 'YYYY-MM-DD');
        await _tap(tester, '24-hour format');
        await _tap(tester, 'Save Changes');
        await _settle(tester, 20);
        expect(_saves, hasLength(1));
        expect(_saves.single['format'], 'YYYY-MM-DD');
        expect(_saves.single['timeFormat'], '24');
      });
    });

    testWidgets('custom format + Reset: web defaults YYYY-MM-DD and 24-hour',
        (tester) async {
      await _withDateFormat(tester, 'DD/MMM/YYYY', '12', () async {
        await _tap(tester, '24-hour format');
        await _tap(tester, 'Reset');
        await _settle(tester, 20);
        expect(_saves, hasLength(1));
        expect(_saves.single['format'], 'YYYY-MM-DD');
        expect(_saves.single['timeFormat'], '24');
      });
    });
  });

  testWidgets(
      'a time-only save right after a date save sends the new date format',
      (tester) async {
    await _withDateFormat(tester, 'DD/MMM/YYYY', '24', () async {
      // The reload after each save is slow, so the second Save happens
      // before the first save's reload comes back.
      _slowAuth = true;
      await _quickTap(tester, 'YYYY-MM-DD');
      await _quickTap(tester, 'Save Changes');
      await _quickTap(tester, '12-hour format');
      await _quickTap(tester, 'Save Changes');
      await _settle(tester, 100);
      expect(_saves, hasLength(2));
      expect(_saves[0]['format'], 'YYYY-MM-DD');
      expect(_saves[1]['format'], 'YYYY-MM-DD',
          reason: 'not the old DD/MMM/YYYY');
      expect(_saves[1]['timeFormat'], '12');
      expect(_theme['format'], 'YYYY-MM-DD');
    });
  });

  group('success messages only when the save works, like web', () {
    testWidgets(
        'a refused Save shows no success message and stays unsaved',
        (tester) async {
      await _withDateFormat(tester, 'YYYY-MM-DD', '24', () async {
        _failSaves = true;
        await _tap(tester, '12-hour format');
        await _tap(tester, 'Save Changes');
        await _settle(tester, 20);
        expect(_saves, hasLength(1), reason: 'the save was tried once');
        expect(_toasts, contains('Failed to save date format'));
        expect(_toasts, isNot(contains('Date and time format updated')));
        expect(_button(tester, 'Save Changes').onTap, isNotNull,
            reason: 'not saved, so it can be tried again');
      });
    });

    testWidgets('a refused Reset shows no reset message and stays unsaved',
        (tester) async {
      await _withDateFormat(tester, 'YYYY-MMM-DD', '12', () async {
        _failSaves = true;
        await _tap(tester, '24-hour format');
        await _tap(tester, 'Reset');
        await _settle(tester, 20);
        expect(_saves, hasLength(1));
        expect(_toasts, contains('Failed to save date format'));
        expect(_toasts, isNot(contains('Date and time format reset')));
        expect(_button(tester, 'Reset').onTap, isNotNull);
      });
    });

    testWidgets(
        'after a refused date save, back on the saved option a time save keeps it',
        (tester) async {
      await _withDateFormat(tester, 'DD/MMM/YYYY', '12', () async {
        _failSaves = true;
        await _tap(tester, 'YYYY-MM-DD');
        await _tap(tester, 'Save Changes');
        await _settle(tester, 20);
        _failSaves = false;
        await _tap(tester, 'MM/DD/YYYY');
        await _tap(tester, '24-hour format');
        await _tap(tester, 'Save Changes');
        await _settle(tester, 20);
        expect(_saves, hasLength(2));
        expect(_saves.last['format'], 'DD/MMM/YYYY',
            reason: 'the refused YYYY-MM-DD was never saved');
        expect(_saves.last['timeFormat'], '24');
        expect(_toasts, contains('Date and time format updated'));
      });
    });
  });

  group('Custom option after a save, like web', () {
    testWidgets(
        'saving another format leaves the Custom box at DD/MMM/YYYY',
        (tester) async {
      await _withDateFormat(tester, 'YYYY-MM-DD', '24', () async {
        await _tap(tester, '12-hour format');
        await _tap(tester, 'Save Changes');
        await _settle(tester, 20);
        expect(_saves, hasLength(1));
        // The Custom card's sample still uses DD/MMM/YYYY …
        expect(find.text(_customSample), findsOneWidget);
        // … and picking Custom starts from DD/MMM/YYYY.
        await _tap(tester, 'Custom (DD/MMM/YYYY)');
        expect(tester.widget<TextField>(_customBox).controller?.text,
            'DD/MMM/YYYY');
      });
    });

    testWidgets('a typed custom format is saved, then a new one replaces it',
        (tester) async {
      await _withDateFormat(tester, 'YYYY-MM-DD', '24', () async {
        await _tap(tester, 'Custom (DD/MMM/YYYY)');
        await _tap(tester, 'Save Changes');
        await _settle(tester, 20);
        expect(_saves.last['format'], 'DD/MMM/YYYY');
        await tester.enterText(_customBox, 'DD-MM-YYYY');
        await _settle(tester, 10);
        await _tap(tester, 'Save Changes');
        await _settle(tester, 20);
        expect(_saves, hasLength(2));
        expect(_saves.last['format'], 'DD-MM-YYYY');
        expect(tester.widget<TextField>(_customBox).controller?.text,
            'DD-MM-YYYY',
            reason: 'the box keeps what was typed, like web');
      });
    });

    testWidgets(
        'an empty custom format is refused with web\'s message, nothing saved',
        (tester) async {
      await _withDateFormat(tester, 'DD/MMM/YYYY', '12', () async {
        await _tap(tester, 'Custom (DD/MMM/YYYY)');
        await tester.enterText(_customBox, '');
        await _settle(tester, 10);
        await _tap(tester, '24-hour format');
        expect(_button(tester, 'Save Changes').onTap, isNotNull,
            reason: 'like web, Save stays active and explains on tap');
        await _tap(tester, 'Save Changes');
        await _settle(tester, 20);
        expect(_saves, isEmpty, reason: 'the custom format is not replaced');
        expect(_toasts, contains(kInvalidCustomDateFormatMessage));
        expect(_toasts, isNot(contains('Date and time format updated')));
      });
    });
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

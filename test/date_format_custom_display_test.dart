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
import 'package:three_zero_two_property/services/app_date_format.dart';

/// A company saved with a custom date format (or M/D/YYYY) is shown like
/// staging web (Settings.jsx): Settings → Date Format opens on Custom with
/// the saved text, Save/Reset greyed, and every date in the app formats in
/// that format. Before, any non-preset was shown as MM/DD/YYYY.

Map<String, String> _theme = {};
final List<Map<String, dynamic>> _saves = [];

final _server = MockClient((request) async {
  final path = request.url.path;
  Object body = {'statusCode': 200, 'data': []};
  if (path == '/api/auth') {
    body = {'statusCode': 200, 'themes': Map.of(_theme)};
  } else if (path == '/api/themes/date-format') {
    final sent = jsonDecode(request.body) as Map<String, dynamic>;
    _saves.add(sent);
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

GestureDetector _button(WidgetTester tester, String label) => tester.widget(
    find
        .ancestor(of: find.text(label), matching: find.byType(GestureDetector))
        .first);

Finder get _customBox => find.byType(TextField);

Future<void> _open(WidgetTester tester, String format, String time,
    Future<void> Function(DateProvider dates) body) async {
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
      expect(find.text('Date & Time Format'), findsOneWidget);
      await body(dates);
    }, () => _server);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  } finally {
    FlutterError.onError = original;
  }
}

/// The selected date card's radio index, read from the Custom box being
/// shown (only visible while Custom is selected).
bool _customSelected() => _customBox.evaluate().isNotEmpty;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    _saves.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('PonnamKarthik/fluttertoast'), (_) async => true);
    ConnectivityPlatform.instance = _OnlineConnectivity();
    SharedPreferences.setMockInitialValues(
        {'token': 'tkn', 'adminId': 'ADMIN-1', 'role': 'Admin'});
  });

  tearDown(() => AppDateFormat.set(kDefaultAppDateFormat));

  testWidgets('custom DD/MMM/YYYY: opens on Custom with the saved text, Save greyed',
      (tester) async {
    await _open(tester, 'DD/MMM/YYYY', '12', (dates) async {
      expect(_customSelected(), isTrue, reason: 'Custom option selected');
      expect(tester.widget<TextField>(_customBox).controller?.text,
          'DD/MMM/YYYY');
      expect(_button(tester, 'Save').onTap, isNull, reason: 'nothing changed');
      expect(_button(tester, 'Reset').onTap, isNull);
      // Dates app-wide use the custom format, like web.
      expect(dates.dateFormat, 'dd/MMM/yyyy');
      expect(dates.formatCurrentDate('2026-10-28'), '28/Oct/2026');
      expect(AppDateFormat.current, 'dd/MMM/yyyy');
      // The preview shows it too.
      final sample = DateFormat('dd/MMM/yyyy').format(DateTime.now());
      expect(find.textContaining(sample), findsWidgets);
    });
  });

  testWidgets('M/D/YYYY (custom on web): opens on Custom, Save greyed, shown as M/D/YYYY',
      (tester) async {
    await _open(tester, 'M/D/YYYY', '24', (dates) async {
      expect(_customSelected(), isTrue);
      expect(tester.widget<TextField>(_customBox).controller?.text, 'M/D/YYYY');
      expect(_button(tester, 'Save').onTap, isNull,
          reason: 'before, Save was active on open for M/D/YYYY');
      expect(dates.formatCurrentDate('2026-03-07'), '3/7/2026');
    });
  });

  testWidgets('custom company: a time-only save keeps the custom format',
      (tester) async {
    await _open(tester, 'DD/MMM/YYYY', '12', (dates) async {
      await _tap(tester, '24-hour format (14:00)');
      await _tap(tester, 'Save');
      await _settle(tester, 20);
      expect(_saves, hasLength(1));
      expect(_saves.single['format'], 'DD/MMM/YYYY');
      expect(_saves.single['timeFormat'], '24');
    });
  });

  testWidgets('custom company: picking MM/DD/YYYY now saves MM/DD/YYYY (was impossible)',
      (tester) async {
    await _open(tester, 'DD/MMM/YYYY', '24', (dates) async {
      await _tap(tester, 'MM/DD/YYYY');
      expect(_button(tester, 'Save').onTap, isNotNull);
      await _tap(tester, 'Save');
      await _settle(tester, 20);
      expect(_saves, hasLength(1));
      expect(_saves.single['format'], 'MM/DD/YYYY');
    });
  });

  testWidgets('preset company still opens on its preset', (tester) async {
    await _open(tester, 'YYYY-MMM-DD', '24', (dates) async {
      expect(_customSelected(), isFalse);
      expect(_button(tester, 'Save').onTap, isNull);
      expect(dates.formatCurrentDate('2026-10-28'), '2026-Oct-28');
    });
  });

  testWidgets('day-of-year custom format shows like web\'s moment',
      (tester) async {
    await _open(tester, 'DDD/YYYY', '24', (dates) async {
      expect(_customSelected(), isTrue);
      expect(dates.formatCurrentDate('2026-10-28'), '301/2026');
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

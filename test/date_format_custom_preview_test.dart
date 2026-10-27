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

/// Settings → Date Format → Custom works like web staging
/// (DateFormatSection.jsx): "HOW IT APPEARS" follows the custom format while
/// it is typed, and shows "—" for a format web would reject
/// (Settings.jsx isValidDateFormat). Before, the preview kept showing the
/// saved format until Save.

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

Future<void> _tap(WidgetTester tester, String label) async {
  final target = find.text(label).last;
  await tester.ensureVisible(target);
  await tester.pump();
  await tester.tap(target, warnIfMissed: false);
  await _settle(tester, 20);
}

/// The "HOW IT APPEARS" text: the only Text ending in a seconds time.
String _preview(WidgetTester tester) {
  final texts = tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data ?? '')
      .where((s) => s == '—' || RegExp(r'\d \d{2}:\d{2}:\d{2}$').hasMatch(s))
      .toList();
  expect(texts, hasLength(1), reason: 'one preview line: $texts');
  return texts.single;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('isValidCustomDateFormat (web isValidDateFormat)', () {
    test('accepts Y, M and D with / - or space', () {
      for (final f in [
        'DD-MM-YYYY',
        'DD/MMM/YYYY',
        'YYYY MM DD',
        'MM/DD/YYYY',
        'YMD',
      ]) {
        expect(isValidCustomDateFormat(f), isTrue, reason: f);
      }
    });

    test('rejects what web and the server reject', () {
      for (final f in [
        '',
        'INVALIDFORMAT',
        'DD-MM', // no year
        'DD.MM.YYYY', // dot separator
        'DD-MM-YYYY HH', // other letters
        'dd-mm-yyyy', // lower case (web upper-cases first)
        'D-M-${'Y' * 30}', // over 32 characters
      ]) {
        expect(isValidCustomDateFormat(f), isFalse, reason: f);
      }
    });
  });

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

  testWidgets('Custom: preview follows the typed format, "—" when invalid, nothing saved',
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

        await _tap(tester, 'Date Format');
        await _settle(tester, 20);
        final now = DateTime.now();
        final saved = DateFormat('MM/dd/yyyy').format(now);
        expect(_preview(tester), startsWith('$saved '));

        // Like web: the Custom option is labelled with web's starting format
        // and shows a sample date in it.
        final webDefault = DateFormat('dd/MMM/yyyy').format(now);
        expect(find.text(webDefault), findsOneWidget);
        await _tap(tester, 'Custom (DD/MMM/YYYY)');
        final field = find.widgetWithText(
            TextFormField, 'Custom format (e.g. DD-MM-YYYY)');
        expect(field, findsOneWidget);
        expect(_preview(tester), startsWith('$webDefault '));

        // A valid custom format shows straight away, in the preview and on
        // the Custom option.
        await tester.enterText(field, 'DD-MM-YYYY');
        await _settle(tester, 5);
        expect(_preview(tester),
            startsWith('${DateFormat('dd-MM-yyyy').format(now)} '));
        expect(find.text(DateFormat('dd-MM-yyyy').format(now)), findsOneWidget);

        // Lower case is read as upper case, as web does.
        await tester.enterText(field, 'yyyy/mm/dd');
        await _settle(tester, 5);
        expect(_preview(tester),
            startsWith('${DateFormat('yyyy/MM/dd').format(now)} '));

        // A format web rejects shows "—"; the Custom option falls back to
        // web's starting format, as on web.
        await tester.enterText(field, 'INVALIDFORMAT');
        await _settle(tester, 5);
        expect(_preview(tester), '—');
        expect(find.text(webDefault), findsOneWidget);

        // Empty field: back to the saved format.
        await tester.enterText(field, '');
        await _settle(tester, 5);
        expect(_preview(tester), startsWith('$saved '));

        expect(_saves, isEmpty, reason: 'typing never saves');
      }, () => _server);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    } finally {
      FlutterError.onError = original;
    }
  });

  testWidgets('Custom: typed like web, invalid blocks Save, saved body = web\'s',
      (tester) async {
    tester.view.physicalSize = const Size(430, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final original = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('overflowed')) return;
      original?.call(details);
    };
    GestureDetector saveButton() => tester.widget(find
        .ancestor(
            of: find.text('Save Changes'),
            matching: find.byType(GestureDetector))
        .first);
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
        await _tap(tester, 'Custom (DD/MMM/YYYY)');
        final field = find.widgetWithText(
            TextFormField, 'Custom format (e.g. DD-MM-YYYY)');
        String typed() => tester
            .widget<EditableText>(
                find.descendant(of: field, matching: find.byType(EditableText)))
            .controller
            .text;

        // Like web: the box starts with DD/MMM/YYYY, and picking Custom is a
        // change, so Save Changes turns on.
        expect(typed(), kDefaultCustomDateFormat);
        expect(saveButton().onTap, isNotNull);

        // The phone keyboard must not change the format ("dd." → "did.").
        final editable = tester.widget<EditableText>(
            find.descendant(of: field, matching: find.byType(EditableText)));
        expect(editable.autocorrect, isFalse);
        expect(editable.enableSuggestions, isFalse);

        // Like web's handleCustomDateChange: only letters, / and -, capitals.
        await tester.enterText(field, 'dd.mm 1yyyy');
        await _settle(tester, 5);
        expect(typed(), 'DDMMYYYY');
        await tester.enterText(field, 'dd/mmm-yyyy');
        await _settle(tester, 5);
        expect(typed(), 'DD/MMM-YYYY');

        // Invalid: web's red message, Save greyed out, nothing sent.
        await tester.enterText(field, 'INVALIDFORMAT');
        await _settle(tester, 5);
        expect(find.text(kInvalidCustomDateFormatMessage), findsOneWidget);
        expect(saveButton().onTap, isNull);
        expect(_saves, isEmpty);

        // Valid again: message gone, Save sends what web sends.
        await tester.enterText(field, 'dd-mm-yyyy');
        await _settle(tester, 5);
        expect(find.text(kInvalidCustomDateFormatMessage), findsNothing);
        expect(saveButton().onTap, isNotNull);
        await _tap(tester, 'Save Changes');
        await _settle(tester, 20);
        expect(_saves, hasLength(1));
        expect(_saves.single, {
          'format': 'DD-MM-YYYY',
          'timeFormat': '24',
          'admin_id': 'ADMIN-1',
        });
        expect(_toasts, contains('Date and time format updated'),
            reason: "web's save message");
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

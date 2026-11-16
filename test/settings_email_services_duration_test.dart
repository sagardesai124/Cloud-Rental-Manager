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
import 'package:three_zero_two_property/provider/color_theme.dart';
import 'package:three_zero_two_property/provider/dateProvider.dart';
import 'package:three_zero_two_property/provider/notification_provider.dart';
import 'package:three_zero_two_property/screens/Profile/Settings_screen.dart';

/// Settings → Email Services, like web staging (MailServiceSection.jsx):
/// - while the Rent Due reminder is on, Duration is required (the browser's
///   "Please fill out this field." on web) and nothing is saved without it;
/// - Duration takes digits and one decimal point (`/^\d*\.?\d*$/`);
/// - once settings are saved, Update stays greyed out until something
///   changes (`disabled={mailData && !hasMailSettingsChanged()}`); the very
///   first save is always allowed.
/// Before: an empty Duration was "saved" (the server ignored it and kept the
/// old one), any text could be pasted, and Save was always active.

const _required = 'Please fill out this field.';

/// Web's own rule for what the Duration box accepts.
bool _webAccepts(String text) => RegExp(r'^\d*\.?\d*$').hasMatch(text);

String _typed(String from, String to) => reminderDurationFormatter
    .formatEditUpdate(
        TextEditingValue(
            text: from, selection: TextSelection.collapsed(offset: from.length)),
        TextEditingValue(
            text: to, selection: TextSelection.collapsed(offset: to.length)))
    .text;

final List<http.Request> _puts = [];
final List<http.Request> _posts = [];

/// [saved] is the company's stored mail setting, or null when none exists.
MockClient _server(Map<String, dynamic>? saved) => MockClient((request) async {
      final path = request.url.path;
      Object body = {'statusCode': 200, 'data': []};
      if (path == '/api/auth') {
        body = {
          'statusCode': 200,
          'themes': {'format': 'MM/DD/YYYY', 'timeFormat': '24'}
        };
      } else if (path.startsWith('/api/mail_permission')) {
        if (request.method == 'PUT') {
          _puts.add(request);
          body = {'statusCode': 200, 'message': 'ok'};
        } else if (request.method == 'POST') {
          _posts.add(request);
          body = {'statusCode': 200, 'message': 'ok'};
        } else {
          body = saved == null
              ? {'statusCode': 201, 'message': 'No mail permission found'}
              : {'statusCode': 200, 'data': saved};
        }
      }
      return http.Response(jsonEncode(body), 200,
          headers: {'content-type': 'application/json'});
    });

Future<void> _settle(WidgetTester tester, [int ticks = 30]) async {
  for (var i = 0; i < ticks; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

GestureDetector _save(WidgetTester tester) => tester.widget(find
    .ancestor(of: find.text('Save Changes'), matching: find.byType(GestureDetector))
    .first);

Finder get _duration => find.byWidgetPredicate(
    (w) => w is TextField && w.decoration?.hintText == '1');

Finder get _replyTo => find.byWidgetPredicate(
    (w) => w is TextField && w.decoration?.hintText == 'Enter email');

Finder get _reminderSwitch => find
    .descendant(
        of: find
            .ancestor(
                of: find.text('Rent Due Reminder Email'),
                matching: find.byType(Row))
            .first,
        matching: find.byType(Switch))
    .first;

Future<void> _tapSave(WidgetTester tester) async {
  final target = find.text('Save Changes');
  await tester.ensureVisible(target);
  await tester.pump();
  await tester.tap(target, warnIfMissed: false);
  await _settle(tester, 20);
}

Future<void> _openEmailServices(
    WidgetTester tester, Map<String, dynamic>? saved, Future<void> Function() body) async {
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
      final item = find.text('Email Services').last;
      await tester.ensureVisible(item);
      await tester.pump();
      await tester.tap(item, warnIfMissed: false);
      await _settle(tester, 20);
      expect(find.text('RENT DUE REMINDER'), findsOneWidget);
      await body();
    }, () => _server(saved));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  } finally {
    FlutterError.onError = original;
  }
}

Map<String, dynamic> _bodyOf(http.Request r) =>
    jsonDecode(r.body) as Map<String, dynamic>;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Duration rule, same as web', () {
    test('typing: digits and one decimal point, like web', () {
      const cases = [
        ['', '1'], ['1', '12'], ['12', '12.'], ['12.', '12.5'],
        ['12.5', '12.5.'], ['3', '3a'], ['3', '-3'], ['3', '3,5'],
        ['', 'abc'], ['', '2.5'], ['', '.5'], ['3', '3 '], ['3', ''],
      ];
      for (final c in cases) {
        expect(_typed(c[0], c[1]), _webAccepts(c[1]) ? c[1] : c[0],
            reason: '${c[0]} -> ${c[1]}');
      }
    });

    test('required only while the reminder is on', () {
      expect(reminderDurationProblem(reminderOn: true, text: ''), _required);
      expect(reminderDurationProblem(reminderOn: true, text: '  '), _required);
      expect(reminderDurationProblem(reminderOn: true, text: '.'), _required);
      expect(reminderDurationProblem(reminderOn: true, text: '3'), isNull);
      expect(reminderDurationProblem(reminderOn: true, text: '2.5'), isNull);
      expect(reminderDurationProblem(reminderOn: true, text: '0'), isNull,
          reason: 'web accepts 0');
      expect(reminderDurationProblem(reminderOn: false, text: ''), isNull,
          reason: 'off: the box is hidden and 0 is saved');
    });

    test('the Duration box and Save use the rule', () {
      final src =
          File('lib/screens/Profile/Settings_screen.dart').readAsStringSync();
      expect(src, contains('inputFormatters: [reminderDurationFormatter]'));
      expect(src, contains('onTap: !canSaveMail'));
      expect(src, contains('final bool canSaveMail = !mailupdate || _hasMailChanges();'));
      expect(src, isNot(contains('int.tryParse(durationmail.text.trim())')),
          reason: 'the first save keeps decimals too');
      expect(src, contains("durationmail = TextEditingController(text: '0')"),
          reason: 'starts at 0, like web');
    });
  });

  setUp(() {
    _puts.clear();
    _posts.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('PonnamKarthik/fluttertoast'), (_) async => true);
    ConnectivityPlatform.instance = _OnlineConnectivity();
    SharedPreferences.setMockInitialValues(
        {'token': 'tkn', 'adminId': 'ADMIN-1', 'role': 'Admin'});
  });

  testWidgets(
      'saved settings: Save greyed until a change; empty Duration blocked; '
      '2.5 saves; reminder off saves 0', (tester) async {
    await _openEmailServices(tester, {
      '_id': 'M-1',
      'admin_id': 'ADMIN-1',
      'remindermail': true,
      'duration': 3,
      'reply_to': 'owner@example.com',
    }, () async {
      TextField duration() => tester.widget<TextField>(_duration);
      expect(duration().controller!.text, '3', reason: 'loaded');
      expect(duration().keyboardType,
          const TextInputType.numberWithOptions(decimal: true),
          reason: 'iPhone keyboard shows "."');

      // Nothing changed yet: Save is greyed out and does nothing.
      expect(_save(tester).onTap, isNull);

      // Only digits and one "." go in, like web.
      await tester.enterText(_duration, '2.5');
      expect(duration().controller!.text, '2.5');
      for (final refused in ['2.5.1', 'abc', '-1', '2,5']) {
        await tester.enterText(_duration, refused);
        expect(duration().controller!.text, '2.5', reason: refused);
      }

      // Back to the saved value: greyed out again.
      await tester.enterText(_duration, '3');
      await tester.pump();
      expect(_save(tester).onTap, isNull);

      // Empty Duration (and a bad Reply-To): web's required message first,
      // nothing saved.
      await tester.enterText(_duration, '');
      await tester.enterText(_replyTo, 'abc@test');
      await tester.pump();
      expect(_save(tester).onTap, isNotNull, reason: 'something changed');
      await _tapSave(tester);
      expect(find.text(_required), findsOneWidget);
      expect(_puts, isEmpty);

      // Typing a Duration clears its message; the Reply-To check still runs.
      await tester.enterText(_duration, '2.5');
      await tester.pump();
      expect(find.text(_required), findsNothing);
      await _tapSave(tester);
      expect(find.text(kInvalidReplyToEmailMessage), findsOneWidget);
      expect(_puts, isEmpty);

      // Correcting the Reply-To clears its message straight away, like web.
      await tester.enterText(_replyTo, 'owner@example.com');
      await tester.pump();
      expect(find.text(kInvalidReplyToEmailMessage), findsNothing,
          reason: 'editing Reply-To clears its message, like web');

      // A good Reply-To with an empty Duration: only the Duration message.
      await tester.enterText(_duration, '');
      await _tapSave(tester);
      expect(find.text(_required), findsOneWidget);
      expect(find.text(kInvalidReplyToEmailMessage), findsNothing,
          reason: 'no old Reply-To message under a valid address');
      expect(_puts, isEmpty);
      await tester.enterText(_duration, '2.5');

      // Valid: saved as typed, then nothing left to save.
      await _tapSave(tester);
      expect(_puts, hasLength(1));
      expect(_bodyOf(_puts.single)['duration'], 2.5);
      expect(_bodyOf(_puts.single)['remindermail'], true);
      expect(find.text('Email Updated Successfully'), findsOneWidget);
      await _settle(tester, 10);
      expect(_save(tester).onTap, isNull, reason: 'saved, greyed out again');

      // Reminder off: the Duration box goes away and 0 is saved, like web.
      await tester.ensureVisible(_reminderSwitch);
      await tester.tap(_reminderSwitch);
      await _settle(tester, 6);
      expect(_duration, findsNothing);
      expect(_save(tester).onTap, isNotNull);
      await _tapSave(tester);
      expect(_puts, hasLength(2));
      expect(_bodyOf(_puts.last)['duration'], 0);
      expect(_bodyOf(_puts.last)['remindermail'], false);
    });
  });

  testWidgets(
      'first save (nothing stored yet): Save active, Duration required, '
      'decimals kept', (tester) async {
    await _openEmailServices(tester, null, () async {
      // Like web's "Save" for a new setting: active right away.
      expect(_save(tester).onTap, isNotNull);

      // Like web (duration starts at 0): turning the reminder on shows 0,
      // and one tap on Save stores it.
      await tester.ensureVisible(_reminderSwitch);
      await tester.tap(_reminderSwitch);
      await _settle(tester, 6);
      expect(tester.widget<TextField>(_duration).controller!.text, '0');
      await _tapSave(tester);
      expect(find.text(_required), findsNothing);
      expect(_posts, hasLength(1));
      expect(_bodyOf(_posts.single)['duration'], 0);
      expect(_bodyOf(_posts.single)['remindermail'], true);

      // This fake server still has nothing stored, so the next save is a
      // first save again: an empty Duration is blocked, decimals are kept.
      await tester.enterText(_duration, '');
      await _tapSave(tester);
      expect(find.text(_required), findsOneWidget);
      expect(_posts, hasLength(1));

      await tester.enterText(_duration, '4.5');
      await _tapSave(tester);
      expect(_posts, hasLength(2));
      expect(_bodyOf(_posts.last)['duration'], 4.5);
      expect(_bodyOf(_posts.last)['remindermail'], true);
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

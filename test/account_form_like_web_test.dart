import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus_platform_interface/connectivity_plus_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:three_zero_two_property/provider/color_theme.dart';
import 'package:three_zero_two_property/provider/dateProvider.dart';
import 'package:three_zero_two_property/provider/notification_provider.dart';
import 'package:three_zero_two_property/screens/Profile/Settings_screen.dart';
import 'package:three_zero_two_property/widgets/account_form_web_rules.dart';

/// Settings › Accounts and the "Add account" pop-ups in Add/Edit/Renew
/// Lease, like web staging (one form on web: AccountDialog.jsx):
///  * Account Type: Income, Liability Account, Non Operating Income;
///    Fund Type: Operating, Reserve;
///  * the optional box is "Notes";
///  * tapping Add/Update with an empty required field turns it red, with
///    "Account name is required" and "Please correct the red boxes above";
///  * the buttons are "Add" / "Update";
///  * a server refusal shows only the server's message.

final List<http.Request> _posts = [];
final List<http.Request> _puts = [];
final List<String> _toasts = [];
var _postStatus = 409;

final _server = MockClient((request) async {
  final path = request.url.path;
  if (request.method == 'POST' && path == '/api/accounts/accounts') {
    _posts.add(request);
    if (_postStatus == 409) {
      return _json({
        'statusCode': 409,
        'message': 'An account with this name already exists'
      }, 409);
    }
    return _json({'statusCode': 200, 'message': 'New account added'});
  }
  if (request.method == 'PUT' && path == '/api/accounts/accounts/A1') {
    _puts.add(request);
    return _json({'statusCode': 200, 'message': 'Account updated'});
  }
  if (request.method == 'GET' && path == '/api/accounts/accounts/ADMIN-1') {
    return _json({
      'statusCode': 200,
      'data': [
        {
          'account_id': 'A1',
          'admin_id': 'ADMIN-1',
          'account': 'Rent Income',
          'account_type': 'Income',
          'fund_type': 'Operating',
          'charge_type': '',
          'notes': '',
        }
      ]
    });
  }
  if (path == '/api/auth') {
    return _json({
      'statusCode': 200,
      'themes': {'format': 'MM/DD/YYYY', 'timeFormat': '24'}
    });
  }
  return _json({'statusCode': 200, 'data': []});
});

http.Response _json(Object body, [int status = 200]) => http.Response(
    jsonEncode(body), status,
    headers: {'content-type': 'application/json'});

Future<void> _settle(WidgetTester tester, [int ticks = 30]) async {
  for (var i = 0; i < ticks; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Finder get _dialog => find.byType(Dialog);
Finder _inDialog(Finder f) => find.descendant(of: _dialog, matching: f);
Finder _box(String hint) => _inDialog(find.byWidgetPredicate(
    (w) => w is TextField && w.decoration?.hintText == hint));

List<List<String?>> _dropdownOptions(WidgetTester tester) => tester
    .widgetList<DropdownButton<String>>(
        _inDialog(find.byType(DropdownButton<String>)))
    .map((d) => d.items!.map((e) => e.value).toList())
    .toList();

int _redBoxes(WidgetTester tester) => tester
    .widgetList<InputDecorator>(_inDialog(find.byType(InputDecorator)))
    .where((d) {
  final border = d.decoration.enabledBorder;
  return border is OutlineInputBorder &&
      border.borderSide.color == kAccountErrorRed;
}).length;

bool _hasLabel(WidgetTester tester, String text) => tester
    .widgetList<RichText>(_inDialog(find.byType(RichText)))
    .any((r) => r.text.toPlainText() == text);

Future<void> _tapText(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pump();
  await tester.tap(f, warnIfMissed: false);
  await _settle(tester, 20);
}

Future<void> _pick(WidgetTester tester, int dropdown, String option) async {
  await _tapText(
      tester, _inDialog(find.byType(DropdownButton<String>)).at(dropdown));
  await _tapText(tester, find.text(option).last);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test("web's options, in web's order", () {
    expect(kAccountTypeOptions,
        ['Income', 'Liability Account', 'Non Operating Income']);
    expect(kFundTypeOptions, ['Operating', 'Reserve']);
  });

  test("a refused new account shows web's message", () {
    http.Response r(int status, Object body) =>
        http.Response(jsonEncode(body), status);
    expect(
        accountAddFailureMessage(
            r(409, {'message': 'An account with this name already exists'})),
        'An account with this name already exists');
    expect(accountAddFailureMessage(r(409, {})),
        'An account with this name already exists');
    expect(accountAddFailureMessage(r(400, {'message': 'x'})),
        'Account already exists');
    expect(accountAddFailureMessage(r(500, {'message': 'boom'})),
        'Failed to add account');
  });

  group('Settings › Accounts', () {
    setUp(() {
      _posts.clear();
      _puts.clear();
      _toasts.clear();
      _postStatus = 409;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
              const MethodChannel('PonnamKarthik/fluttertoast'), (call) async {
        if (call.method == 'showToast') {
          _toasts.add('${(call.arguments as Map)['msg']}');
        }
        return true;
      });
      ConnectivityPlatform.instance = _Online();
      SharedPreferences.setMockInitialValues(
          {'token': 'tkn', 'adminId': 'ADMIN-1', 'role': 'Admin'});
    });

    testWidgets('Add and Edit account work like web', (tester) async {
      tester.view.physicalSize = const Size(430, 3200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final original = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.exceptionAsString().contains('overflowed')) return;
        original?.call(details);
      };
      addTearDown(() => FlutterError.onError = original);

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
        await _tapText(tester, find.text('Accounts').first);
        await _settle(tester, 30);

        // ---- Add ----
        await _tapText(tester, find.text('Add Account').first);
        expect(_dialog, findsOneWidget);
        expect(_dropdownOptions(tester), [
          ['Income', 'Liability Account', 'Non Operating Income'],
          ['Operating', 'Reserve'],
        ]);
        expect(_hasLabel(tester, 'Notes'), isTrue);
        expect(_hasLabel(tester, 'Note'), isFalse);
        expect(_inDialog(find.text('Add account')), findsOneWidget,
            reason: "web's title");
        expect(_inDialog(find.text('Add')), findsOneWidget,
            reason: 'the button says Add, like web');
        expect(_inDialog(find.text('Add Account')), findsNothing);

        // Nothing red until Add is tapped.
        expect(_redBoxes(tester), 0);
        expect(find.text(kAccountFixRedBoxesMessage), findsNothing);

        // Add with everything empty: web's red boxes and messages.
        await _tapText(tester, _inDialog(find.text('Add')));
        expect(_redBoxes(tester), 3, reason: 'name, account type, fund type');
        expect(find.text(kAccountNameRequiredMessage), findsOneWidget);
        expect(find.text(kAccountFixRedBoxesMessage), findsOneWidget);
        expect(find.text('Please fill all fields'), findsNothing);
        expect(_posts, isEmpty);

        // Typing a name clears its box; the dropdowns stay red.
        await tester.enterText(_box('Enter account name'), 'Rent Income');
        await _settle(tester, 5);
        expect(find.text(kAccountNameRequiredMessage), findsNothing);
        expect(_redBoxes(tester), 2);
        expect(find.text(kAccountFixRedBoxesMessage), findsOneWidget);

        await _pick(tester, 0, 'Liability Account');
        await _pick(tester, 1, 'Reserve');
        expect(_redBoxes(tester), 0);
        expect(find.text(kAccountFixRedBoxesMessage), findsNothing);

        // Duplicate name: only the server's message; the form stays open.
        await _tapText(tester, _inDialog(find.text('Add')));
        await _settle(tester, 20);
        expect(_posts, hasLength(1));
        final sent = jsonDecode(_posts.single.body) as Map<String, dynamic>;
        expect(sent['account'], 'Rent Income');
        expect(sent['account_type'], 'Liability Account');
        expect(sent['fund_type'], 'Reserve');
        expect(_toasts, contains('An account with this name already exists'));
        expect(_dialog, findsOneWidget);
        expect(find.text('Please fill all fields'), findsNothing);
        expect(find.text(kAccountFixRedBoxesMessage), findsNothing);

        // A new name saves and closes.
        _postStatus = 200;
        await tester.enterText(_box('Enter account name'), 'Deposits');
        await _tapText(tester, _inDialog(find.text('Add')));
        await _settle(tester, 30);
        expect(_posts, hasLength(2));
        expect(_dialog, findsNothing);

        // ---- Edit ----
        await _tapText(tester, find.text('Rent Income').first);
        await _tapText(
            tester,
            find
                .byWidgetPredicate(
                    (w) => w is FaIcon && w.icon == FontAwesomeIcons.edit)
                .first);
        expect(_dialog, findsOneWidget);
        expect(_hasLabel(tester, 'Notes'), isTrue);
        expect(_inDialog(find.text('Edit account')), findsOneWidget);
        expect(_inDialog(find.text('Update')), findsOneWidget);
        expect(_inDialog(find.text('Update Account')), findsNothing);

        await tester.enterText(_box('Enter account name'), '');
        await _settle(tester, 5);
        await _tapText(tester, _inDialog(find.text('Update')));
        expect(find.text(kAccountNameRequiredMessage), findsOneWidget);
        expect(find.text(kAccountFixRedBoxesMessage), findsOneWidget);
        expect(_redBoxes(tester), 1);
        expect(_puts, isEmpty);

        await tester.enterText(_box('Enter account name'), 'Rent');
        await _settle(tester, 5);
        expect(find.text(kAccountFixRedBoxesMessage), findsNothing);
        await _tapText(tester, _inDialog(find.text('Update')));
        await _settle(tester, 30);
        expect(_puts, hasLength(1));
        expect((jsonDecode(_puts.single.body) as Map)['account'], 'Rent');

        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 5));
      }, () => _server);
    });
  });

  // ---- the Add account pop-ups inside Add / Edit / Renew Lease ----
  const leaseFiles = {
    'lib/screens/Leasing/RentalRoll/newAddLease.dart': 2,
    'lib/screens/Leasing/RentalRoll/edit_lease.dart': 2,
    'lib/screens/Leasing/RentalRoll/RenewLease.dart': 1,
    'lib/StaffModule/screen/Leasing/RentalRoll/newAddLease.dart': 2,
    'lib/StaffModule/screen/Leasing/RentalRoll/edit_lease.dart': 2,
    'lib/StaffModule/screen/Leasing/RentalRoll/RenewLease.dart': 1,
  };
  String live(String path) => File(path)
      .readAsLinesSync()
      .where((l) => !l.trimLeft().startsWith('//'))
      .join('\n');

  for (final entry in leaseFiles.entries) {
    test('${entry.key}: Add account pop-ups match web', () {
      final src = live(entry.key);
      final popups = entry.value;
      expect("'We store this information '".allMatches(src).length, popups);
      expect(src, isNot(contains('We stores')));
      expect(RegExp(r"'Account Type \*',").allMatches(src).length, popups);
      expect(RegExp(r"'Fund Type \*',").allMatches(src).length, popups);
      expect(src, isNot(contains("'Reverse'")),
          reason: 'Fund Type said Reverse instead of Reserve');
      expect(src, isNot(contains("'Non Operating Income '")),
          reason: 'stray space after Non Operating Income');
      expect(src, contains('List<String> accountTypeItems = List.of(kAccountTypeOptions);'));
      expect(src, contains('List<String> fundTypeItems = List.of(kFundTypeOptions);'));
      expect(src, isNot(contains("'Please enter Notes'")),
          reason: 'Notes is optional on web');
      // Notes box: optional, like web.
      final notesBoxes = RegExp(r"optional: true,[\s\S]{0,600}?hintText:\s*'Enter Notes'")
          .allMatches(src)
          .length;
      expect(notesBoxes, popups);
      expect(src, isNot(contains("Text('Failed to add account')")),
          reason: "server refusals show web's message");
      if (entry.key.contains('RenewLease')) {
        expect(src, isNot(contains('_notesController.text.isEmpty)')));
      }
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

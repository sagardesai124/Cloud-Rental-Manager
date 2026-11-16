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
import 'package:three_zero_two_property/StaffModule/repository/staffpermission_provider.dart';
import 'package:three_zero_two_property/VendorModule/screen/profile.dart'
    as vendor;
import 'package:three_zero_two_property/provider/Plan%20Purchase/plancheckProvider.dart';
import 'package:three_zero_two_property/provider/dateProvider.dart';
import 'package:three_zero_two_property/provider/notification_provider.dart';

/// Vendor › Profile › Contact Cell Number, like web staging
/// (VendorProfile.jsx): the box is the first contact's number,
/// contact_info[0].contact_number. The server (vendorUpdateAllowlist.js)
/// keeps the number only there and drops anything else, so a changed number
/// must be sent there to be saved and still show after a reload. Removing
/// Contact 1 makes the next contact the first one, so the box shows its
/// number, like web.

const _file = 'lib/VendorModule/screen/profile.dart';

void main() {
  test('the box loads from and saves to the first contact\'s number', () {
    final src = File(_file).readAsStringSync();
    expect(src, isNot(contains('contact_cell_number')),
        reason: 'the server neither keeps nor returns this key');
    expect("'contact_info': _contactInfoBody(),".allMatches(src).length, 2,
        reason: 'both the change check and the PUT use it');
  });

  group('on the Vendor profile screen', () {
    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
              const MethodChannel('PonnamKarthik/fluttertoast'),
              (_) async => true);
      ConnectivityPlatform.instance = _Online();
    });

    testWidgets(
        'a changed Contact Cell Number is saved, sent like web, and stays '
        'after reload and when coming back', (tester) async {
      final server = _FakeServer(_vendor);
      await _withScreen(tester, server, () async {
        expect(_shown(tester), '5553334444',
            reason: "loaded from the first contact's number");

        await tester.enterText(_contactCell, '5559998888');
        await tester.pump();
        final typed = _shown(tester);
        expect(typed.replaceAll(RegExp(r'\D'), ''), '5559998888');

        await _update(tester);

        expect(server.saves, hasLength(1));
        final sent = server.saves.single;
        expect(sent.containsKey('contact_cell_number'), isFalse);
        final firstContact = (sent['contact_info'] as List).first as Map;
        expect(firstContact['contact_number'], typed,
            reason: 'the new number goes where the server keeps it');
        expect(firstContact['contact_name'], 'Pat Contact');
        expect(firstContact['contact_email'], 'pat@example.com');

        // The same request web sends: the fields VendorProfile.jsx submits,
        // plus the two values web's request code (axiosInstance.js) adds to
        // every save; the server reads user_active_recently to keep the
        // login session alive.
        expect(sent.keys.toSet(), {
          'vendor_name',
          'vendor_email',
          'vendor_phoneNumber',
          'vendor_address',
          'vendor_city',
          'vendor_state',
          'vendor_zip',
          'vendor_country',
          'contact_info',
          'trade',
          'region_covered',
          'licenses_permits',
          'user_active_recently',
          'is_web',
        });
        expect(sent['user_active_recently'], isTrue);
        expect(sent['is_web'], isTrue);

        // The rest of the profile goes back as it was.
        expect(sent['vendor_name'], 'Test Vendor');
        expect(sent['vendor_email'], 'vendor@example.com');
        expect(sent['vendor_phoneNumber'], '5551112222',
            reason: 'Cell Phone Number is unchanged');
        expect(sent['vendor_address'], '1 Test Street');
        expect(sent['vendor_city'], 'Austin');
        expect(sent['vendor_state'], 'Texas');
        expect(sent['vendor_zip'], '12345');
        expect(sent['vendor_country'], 'United States');
        expect(sent['trade'], 'general');
        expect(sent['licenses_permits'], 'License 123');
        expect(sent['region_covered'], [
          {'zip_code': '12345', 'distance_miles': '10'}
        ]);

        // After the save the screen reloads: the new number stays.
        expect(_shown(tester), typed);

        // Leave Profile and come back (the Vendor tabs build it again): it
        // loads from the server again and still shows the new number.
        final loadsBefore = server.loads;
        await tester.pumpWidget(_app(const SizedBox()));
        await _settle(tester, 5);
        expect(_phoneBoxes, findsNothing, reason: 'Profile was left');
        await tester.pumpWidget(_app(const vendor.Profile_screen()));
        await _settle(tester, 60);
        expect(server.loads, greaterThan(loadsBefore),
            reason: 'loaded again from the server');
        expect(_shown(tester), typed);
      });
    });

    testWidgets(
        "removing Contact 1 shows the next contact's number, like web; "
        'removing another contact leaves the box as it is', (tester) async {
      final server = _FakeServer({
        ..._vendor,
        'contact_info': [
          {
            'contact_name': 'Pat Contact',
            'contact_number': '5553334444',
            'contact_email': 'pat@example.com',
          },
          {
            'contact_name': 'Sam Second',
            'contact_number': '5557778888',
            'contact_email': 'sam@example.com',
          },
          {
            'contact_name': 'Cy Third',
            'contact_number': '',
            'contact_email': 'cy@example.com',
          },
        ],
      });
      await _withScreen(tester, server, () async {
        final remove = find.byIcon(Icons.remove_circle_outline);
        expect(remove, findsNWidgets(3), reason: 'one per contact');
        expect(_shown(tester), '5553334444');

        // Removing Contact 3 doesn't touch the Contact Cell Number.
        await tester.tap(remove.last);
        await tester.pump();
        expect(remove, findsNWidgets(2));
        expect(_shown(tester), '5553334444');

        // Removing Contact 1: Contact 2 is now the first contact, so the box
        // shows its number (web: contact_info[0].contact_number).
        await tester.tap(remove.first);
        await tester.pump();
        expect(remove, findsNothing, reason: 'one contact left');
        expect(_shown(tester), '5557778888');

        await _update(tester);
        expect(server.saves, hasLength(1));
        expect(server.saves.single['contact_info'], [
          {
            'contact_name': 'Sam Second',
            'contact_number': '5557778888',
            'contact_email': 'sam@example.com',
          }
        ], reason: "Contact 1's number didn't move to Contact 2");
        expect(_shown(tester), '5557778888', reason: 'after the reload');
      });
    });

    testWidgets(
        'removing Contact 1 when the next contact has no number asks for '
        'one before saving, like web', (tester) async {
      final server = _FakeServer({
        ..._vendor,
        'contact_info': [
          {
            'contact_name': 'Pat Contact',
            'contact_number': '5553334444',
            'contact_email': 'pat@example.com',
          },
          {
            'contact_name': 'Sam Second',
            'contact_number': '',
            'contact_email': 'sam@example.com',
          },
        ],
      });
      await _withScreen(tester, server, () async {
        expect(_shown(tester), '5553334444');
        await tester.tap(find.byIcon(Icons.remove_circle_outline).first);
        await tester.pump();
        expect(_shown(tester), '', reason: 'Contact 2 has no number yet');

        // Web requires a number for the first contact, so nothing is saved.
        await _update(tester);
        expect(server.saves, isEmpty);
        expect(find.text('Contact number is required'), findsOneWidget,
            reason: "web's message for the Contact Cell Number");

        await tester.enterText(_contactCell, '5552223333');
        await tester.pump();
        await _update(tester);
        expect(server.saves, hasLength(1));
        final contacts = server.saves.single['contact_info'] as List;
        expect(contacts, hasLength(1));
        final first = contacts.single as Map;
        expect(first['contact_name'], 'Sam Second');
        expect(first['contact_email'], 'sam@example.com');
        expect(
            (first['contact_number'] as String).replaceAll(RegExp(r'\D'), ''),
            '5552223333');
      });
    });
  });
}

const _vendor = {
  '_id': 'V-1',
  'vendor_id': 'V-1',
  'vendor_name': 'Test Vendor',
  'vendor_email': 'vendor@example.com',
  'vendor_phoneNumber': '5551112222',
  // A leftover value must not win over the first contact's number, like web.
  'contact_cell_number': '5550000000',
  'vendor_address': '1 Test Street',
  'vendor_city': 'Austin',
  'vendor_state': 'Texas',
  'vendor_zip': '12345',
  'vendor_country': 'United States',
  'licenses_permits': 'License 123',
  'contact_info': [
    {
      'contact_name': 'Pat Contact',
      'contact_number': '5553334444',
      'contact_email': 'pat@example.com',
    }
  ],
  // The stored trade value, as the server keeps it.
  'trade': 'general',
  'region_covered': [
    {'zip_code': '12345', 'distance_miles': '10'},
  ],
};

// Cell Phone Number is the 1st phone box, Contact Cell Number the 2nd.
final _phoneBoxes = find.byWidgetPredicate(
    (w) => w is TextField && w.decoration?.hintText == '(xxx) xxx-xxxx');
final _contactCell = _phoneBoxes.at(1);

String _shown(WidgetTester tester) =>
    tester.widget<TextField>(_contactCell).controller!.text;

/// Behaves like the real server (vendorUpdateAllowlist.js): keeps only the
/// profile fields it allows, and get_vendor returns what it kept.
class _FakeServer {
  _FakeServer(Map<String, dynamic> vendor)
      : stored = jsonDecode(jsonEncode(vendor)) as Map<String, dynamic>;

  final Map<String, dynamic> stored;
  final saves = <Map<String, dynamic>>[];
  int loads = 0;

  static const _kept = [
    'vendor_name',
    'vendor_phoneNumber',
    'vendor_address',
    'vendor_city',
    'vendor_state',
    'vendor_zip',
    'vendor_country',
    'trade',
    'licenses_permits',
    'contact_info',
    'region_covered',
  ];

  late final http.Client client = MockClient((request) async {
    final path = request.url.path;
    if (path.startsWith('/api/vendor/update_vendor/')) {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      saves.add(body);
      for (final key in _kept) {
        if (body.containsKey(key)) stored[key] = body[key];
      }
      return _json(
          {'statusCode': 200, 'message': 'Vendor Updated Successfully'});
    }
    if (path.startsWith('/api/vendor/get_vendor/')) {
      loads++;
      return _json({'statusCode': 200, 'data': stored});
    }
    return _json({'statusCode': 200, 'data': []});
  });
}

Widget _app(Widget home) => MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => DateProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => checkPlanPurchaseProiver()),
        ChangeNotifierProvider(create: (_) => StaffPermissionProvider()),
      ],
      child: MaterialApp(home: home),
    );

/// Opens the Vendor Profile screen against [server], runs [body], then
/// closes it and lets its timers finish.
Future<void> _withScreen(WidgetTester tester, _FakeServer server,
    Future<void> Function() body) async {
  SharedPreferences.setMockInitialValues(
      {'token': 'tkn', 'vendor_id': 'V-1', 'role': 'Vendor'});
  tester.view.physicalSize = const Size(1080, 6000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final original = FlutterError.onError;
  FlutterError.onError = (d) {
    if (d.exceptionAsString().contains('overflowed')) return;
    original?.call(d);
  };
  addTearDown(() => FlutterError.onError = original);

  await http.runWithClient(() async {
    await tester.pumpWidget(_app(const vendor.Profile_screen()));
    await _settle(tester, 60);
    await body();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  }, () => server.client);
}

Future<void> _update(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Update Profile'));
  await tester.tap(find.text('Update Profile'));
  await _settle(tester, 30);
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

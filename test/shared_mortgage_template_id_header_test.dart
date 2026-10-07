import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:three_zero_two_property/StaffModule/repository/staffpermission_provider.dart';
import 'package:three_zero_two_property/provider/dateProvider.dart';
import 'package:three_zero_two_property/provider/notification_provider.dart';
import 'package:three_zero_two_property/screens/Profile/manage_template.dart';
import 'package:three_zero_two_property/screens/Rental/mortgage/Addmortgage.dart';
import 'package:three_zero_two_property/screens/Rental/mortgage/mortgage_summery.dart';

/// Shared screens Staff reach from their own menus — the Mortgage Summary and
/// its Edit form (Admin AddMortgageScreen), and Settings > Templates — must
/// send the logged-in user's OWN id in the `id` header, like web's axios
/// interceptor. The production server only honours adminId with an admin
/// token; staging (older rules) accepts the staff id too. An Admin must keep
/// sending adminId even when an earlier Staff session left staff_id behind.

const _adminId = 'ADMIN-1';
const _staffId = 'STAFF-1';

const Map<String, Object> _staff = {
  'token': 'tkn',
  'adminId': _adminId,
  'role': 'Staffmember',
  'staff_id': _staffId,
};

const Map<String, Object> _adminWithStaleStaffId = {
  'token': 'tkn',
  'adminId': _adminId,
  'role': 'Admin',
  'staff_id': 'STALE-STAFF',
};

const _mortgage = {
  '_id': 'M-1',
  'properties': ['R-9'],
  'bank_name': 'First Bank',
  'mortgage_no': 'LN-1',
  'mortgage_type': 'floating_rate',
  'start_date': '2024-01-01',
  'end_date': '2054-01-01',
  'loan_amount': 250000,
  'remaining_balance': 240000,
  'monthly_principal': 800,
  'monthly_interest': 400,
};

class _Server {
  final List<http.Request> requests = [];

  late final MockClient client = MockClient((request) async {
    requests.add(request);
    final path = request.url.path;
    Object body = {'statusCode': 200, 'data': []};
    if (path == '/api/mortgage/details/M-1') {
      // The details endpoint returns property OBJECTS (getMortgageDetails).
      body = {
        'statusCode': 200,
        'data': {
          ..._mortgage,
          'properties': [
            {'rental_id': 'R-9', 'address': '9 Real Street'}
          ],
        },
      };
    } else if (path.startsWith('/api/templates/settings/')) {
      body = {'statusCode': 200, 'templates': []};
    } else if (path == '/api/mortgage/properties/list') {
      body = {
        'statusCode': 200,
        'data': [
          {'rental_id': 'R-9', 'address': '9 Real Street'}
        ]
      };
    } else if (request.method == 'PUT' || request.method == 'POST') {
      // Refuse saves so screens stay put; only the request is under test.
      return http.Response(jsonEncode({'statusCode': 400, 'message': 'test'}),
          400, headers: {'content-type': 'application/json'});
    }
    return http.Response(jsonEncode(body), 200,
        headers: {'content-type': 'application/json'});
  });

  Iterable<http.Request> where(String pathPrefix) =>
      requests.where((r) => r.url.path.startsWith(pathPrefix));
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Pumps [screen] against a fake server with the app's providers. The test
/// font draws every glyph as a full em square, so rows that fit on a device
/// overflow here; that layout noise is ignored.
Future<void> _run(WidgetTester tester, _Server server, Widget screen,
    Future<void> Function() body) async {
  tester.view.physicalSize = const Size(1080, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final original = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.exceptionAsString().contains('overflowed')) return;
    original?.call(details);
  };
  try {
    await http.runWithClient(() async {
      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => DateProvider()),
          ChangeNotifierProvider(create: (_) => NotificationProvider()),
          ChangeNotifierProvider(create: (_) => StaffPermissionProvider()),
        ],
        child: MaterialApp(home: screen),
      ));
      await _settle(tester);
      await body();
      await tester.pumpWidget(const SizedBox());
    }, () => server.client);
  } finally {
    FlutterError.onError = original;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final sessions = <String, (Map<String, Object>, String)>{
    'Staff sends staff_id': (_staff, 'CRM $_staffId'),
    'Admin (stale staff_id left behind) sends adminId':
        (_adminWithStaleStaffId, 'CRM $_adminId'),
  };

  sessions.forEach((name, session) {
    final (prefs, expected) = session;

    group(name, () {
      testWidgets('Mortgage Summary', (tester) async {
        SharedPreferences.setMockInitialValues(prefs);
        final server = _Server();
        await _run(tester, server,
            const MortgageSummary(mortgageData: {'_id': 'M-1'}), () async {
          final details = server.where('/api/mortgage/details/M-1').toList();
          expect(details, isNotEmpty);
          for (final r in details) {
            expect(r.headers['id'], expected);
          }
        });
      });

      testWidgets('Edit form: property list, duplicate check and Update',
          (tester) async {
        SharedPreferences.setMockInitialValues(prefs);
        final server = _Server();
        await _run(
            tester,
            server,
            const AddMortgageScreen(mortgageId: 'M-1', mortgageData: _mortgage),
            () async {
          final update = find.text('Update');
          await tester.ensureVisible(update);
          await tester.pump();
          await tester.tap(update);
          await _settle(tester);

          final list = server.where('/api/mortgage/properties/list').toList();
          final dupCheck = server.requests
              .where((r) => r.method == 'GET' && r.url.path == '/api/mortgage/')
              .toList();
          final save = server.requests
              .where((r) => r.method == 'PUT' && r.url.path == '/api/mortgage/M-1')
              .toList();
          expect(list, hasLength(1));
          expect(dupCheck, hasLength(1));
          expect(save, hasLength(1));
          for (final r in [...list, ...dupCheck, ...save]) {
            expect(r.headers['id'], expected, reason: '${r.method} ${r.url.path}');
          }
          // The company still scopes the data: unchanged URL and body.
          expect(jsonDecode(save.single.body)['properties'], ['R-9']);
        });
      });

      testWidgets('Settings > Templates list', (tester) async {
        SharedPreferences.setMockInitialValues(prefs);
        final server = _Server();
        await _run(tester, server, const Scaffold(body: manage_templates()),
            () async {
          final list = server.where('/api/templates/settings/').toList();
          expect(list, hasLength(1));
          expect(list.single.url.path, '/api/templates/settings/$_adminId');
          expect(list.single.headers['id'], expected);
        });
      });
    });
  });
}

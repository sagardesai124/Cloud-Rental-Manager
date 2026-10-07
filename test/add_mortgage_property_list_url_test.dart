import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:three_zero_two_property/constant/constant.dart';
import 'package:three_zero_two_property/provider/dateProvider.dart';
import 'package:three_zero_two_property/provider/notification_provider.dart';
import 'package:three_zero_two_property/screens/Rental/mortgage/Addmortgage.dart';

/// Admin Add Mortgage loads its property dropdown from
/// GET /api/mortgage/properties/list. It was hardcoded to the staging server,
/// so production builds sent their login to staging, got a 401 and showed the
/// screen's built-in test properties instead. It must use the app's server
/// (Api_url) like every other call — and like web, which calls the same path
/// on its own API base.

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Admin Add Mortgage loads properties from the app server',
      (tester) async {
    SharedPreferences.setMockInitialValues(
        {'token': 'tkn', 'adminId': 'ADMIN-1', 'role': 'Admin'});
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      final data = request.url.path == '/api/mortgage/properties/list'
          ? [
              {'rental_id': 'R-1', 'address': '1 Real Street'}
            ]
          : [];
      return http.Response(jsonEncode({'statusCode': 200, 'data': data}), 200,
          headers: {'content-type': 'application/json'});
    });

    // The test font draws every glyph as a full em square, so rows that fit
    // on a device overflow here; only the request is under test.
    final original = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('overflowed')) return;
      original?.call(details);
    };
    try {
      await http.runWithClient(() async {
        // The same providers main.dart supplies that this screen reads.
        await tester.pumpWidget(MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => DateProvider()),
            ChangeNotifierProvider(create: (_) => NotificationProvider()),
          ],
          child: const MaterialApp(home: AddMortgageScreen()),
        ));
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }

        final propertyLists = requests
            .where((r) => r.url.path == '/api/mortgage/properties/list')
            .toList();
        expect(propertyLists, hasLength(1));
        expect(propertyLists.single.url.origin, Uri.parse(Api_url).origin,
            reason: 'must go to the configured server, not a hardcoded one');
        expect(propertyLists.single.headers['id'], 'CRM ADMIN-1');

        await tester.pumpWidget(const SizedBox());
      }, () => client);
    } finally {
      FlutterError.onError = original;
    }
  });
}

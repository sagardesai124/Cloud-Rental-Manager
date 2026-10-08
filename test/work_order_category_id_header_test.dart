import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:three_zero_two_property/repository/fetch_allcategories.dart';

/// Lou's trace (10/6): the Tenant and Vendor work-order Category dropdowns
/// load `/api/settings/allCategories/{adminId}` with `id: CRM <adminId>`. On
/// development-2.2 hosts (staging/newdev) that route checks the session, and
/// the server honours adminId only with an admin token, so the dropdowns come
/// back empty. Each role must send its own id (tenant_id / vendor_id, as
/// Staff already sends staff_id); the company id stays in the URL. Admin is
/// unchanged, even with ids left behind by an earlier login of another role.

const _adminId = 'ADMIN-1';

Future<http.Request> _fetch(Map<String, Object> prefs) async {
  SharedPreferences.setMockInitialValues(prefs);
  final sent = <http.Request>[];
  final client = MockClient((request) async {
    sent.add(request);
    return http.Response(
        jsonEncode({
          'statusCode': 200,
          'data': [
            {'category_id': 'C-1', 'admin_id': _adminId, 'name': 'Plumbing'}
          ]
        }),
        200,
        headers: {'content-type': 'application/json'});
  });
  final categories = await http.runWithClient(
      () => FetchAllcategories().fetchAllCategories(), () => client);
  expect(categories, hasLength(1), reason: 'the list still parses');
  expect(sent, hasLength(1));
  final r = sent.single;
  expect(r.url.path, '/api/settings/allCategories/$_adminId',
      reason: 'company id stays in the URL');
  return r;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Tenant sends its own tenant_id', () async {
    final r = await _fetch({
      'token': 'tkn',
      'adminId': _adminId,
      'role': 'Tenant',
      'tenant_id': 'TENANT-1',
    });
    expect(r.headers['id'], 'CRM TENANT-1');
  });

  test('Vendor sends its own vendor_id', () async {
    final r = await _fetch({
      'token': 'tkn',
      'adminId': _adminId,
      'role': 'Vendor',
      'vendor_id': 'VENDOR-1',
    });
    expect(r.headers['id'], 'CRM VENDOR-1');
  });

  test('Staff still sends staff_id (unchanged)', () async {
    final r = await _fetch({
      'token': 'tkn',
      'adminId': _adminId,
      'role': 'Staffmember',
      'staff_id': 'STAFF-1',
    });
    expect(r.headers['id'], 'CRM STAFF-1');
  });

  test('Admin still sends adminId, ignoring ids left by other roles',
      () async {
    final r = await _fetch({
      'token': 'tkn',
      'adminId': _adminId,
      'role': 'Admin',
      'staff_id': 'STALE-STAFF',
      'tenant_id': 'STALE-TENANT',
      'vendor_id': 'STALE-VENDOR',
    });
    expect(r.headers['id'], 'CRM $_adminId');
  });

  test('a Tenant session without a stored tenant_id falls back to adminId',
      () async {
    final r = await _fetch(
        {'token': 'tkn', 'adminId': _adminId, 'role': 'Tenant'});
    expect(r.headers['id'], 'CRM $_adminId');
  });
}

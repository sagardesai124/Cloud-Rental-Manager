import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:three_zero_two_property/TenantsModule/screen/Payment/nmi_keys_service.dart';

/// Tenant wallet checkout (Apple Pay / Google Pay) reads the company's
/// merchant settings from GET /api/nmi-keys/nmi-keys/:admin_id. The server only
/// honours adminId in the `id` header with an admin token (VerifyToken.js,
/// development-2.2), so a tenant must send its own tenant_id — the same
/// identity the web's axios interceptor sends for every tenant request — while
/// the company id stays in the URL. For a tenant the server strips the secret
/// keys and still returns merchant_id, which is all checkout needs.

const _adminId = 'ADMIN-1';
const _tenantId = 'TENANT-1';
const _reply =
    '{"statusCode":200,"data":{"merchant_id":"M-1","public_key":"P-1"}}';

Future<(http.Request, Map<String, dynamic>)> _fetch(
    Map<String, Object> prefs) async {
  SharedPreferences.setMockInitialValues(prefs);
  final sent = <http.Request>[];
  final client = MockClient((request) async {
    sent.add(request);
    return http.Response(_reply, 200,
        headers: {'content-type': 'application/json'});
  });
  final keys = await http.runWithClient(
      () => NmiKeysService().fetchNmiKeys(), () => client);
  expect(sent, hasLength(1));
  return (sent.single, keys);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Tenant sends its own tenant_id; company id stays in the URL', () async {
    final (request, keys) = await _fetch({
      'token': 'tkn',
      'adminId': _adminId,
      'role': 'Tenant',
      'tenant_id': _tenantId,
    });
    expect(request.headers['id'], 'CRM $_tenantId');
    expect(request.url.path, '/api/nmi-keys/nmi-keys/$_adminId');
    expect(keys['merchant_id'], 'M-1');
  });

  test('Non-tenant session keeps sending adminId (stale tenant_id ignored)',
      () async {
    final (request, keys) = await _fetch({
      'token': 'tkn',
      'adminId': _adminId,
      'role': 'Admin',
      // Left behind by an earlier Tenant session; must be ignored.
      'tenant_id': 'STALE-TENANT',
    });
    expect(request.headers['id'], 'CRM $_adminId');
    expect(request.url.path, '/api/nmi-keys/nmi-keys/$_adminId');
    expect(keys['merchant_id'], 'M-1');
  });
}

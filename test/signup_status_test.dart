import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:three_zero_two_property/services/signup_status.dart';

/// Sign-up is shown only when the server says `data.enabled == true`,
/// same rule as web (signupGateway.js isPublicSignupOpen).
void main() {
  const base = 'https://staging.example.com';

  Future<bool> probe(http.Client c, {Duration? timeout}) => isPublicSignupOpen(
      client: c, apiBase: base, timeout: timeout ?? signupProbeTimeout);

  test('open only when data.enabled is true', () async {
    final c = MockClient((req) async {
      expect(req.url.toString(), '$base/api/admin/signup-enabled');
      expect(req.headers.containsKey('Authorization'), isFalse);
      return http.Response('{"statusCode":200,"data":{"enabled":true}}', 200);
    });
    expect(await probe(c), isTrue);
  });

  test('closed when staging answers enabled false', () async {
    final c = MockClient((_) async => http.Response(
        '{"statusCode":200,"data":{"enabled":false},"message":"New account signups are temporarily unavailable."}',
        200));
    expect(await probe(c), isFalse);
  });

  test('closed when the route is missing (404)', () async {
    final c = MockClient((_) async => http.Response('{"statusCode":404}', 404));
    expect(await probe(c), isFalse);
  });

  test('closed on network error', () async {
    final c = MockClient((_) async => throw Exception('offline'));
    expect(await probe(c), isFalse);
  });

  test('closed when the server is too slow', () async {
    final c = MockClient((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      return http.Response('{"data":{"enabled":true}}', 200);
    });
    expect(await probe(c, timeout: const Duration(milliseconds: 20)), isFalse);
  });

  test('only a real true counts', () {
    expect(parseSignupEnabled('{"data":{"enabled":"true"}}'), isFalse);
    expect(parseSignupEnabled('{"enabled":true}'), isFalse);
    expect(parseSignupEnabled('not json'), isFalse);
    expect(parseSignupEnabled('{"data":{"enabled":true}}'), isTrue);
  });

  test('trailing slash on the API base is fine', () async {
    final c = MockClient((req) async {
      expect(req.url.toString(), '$base/api/admin/signup-enabled');
      return http.Response('{"data":{"enabled":true}}', 200);
    });
    expect(await isPublicSignupOpen(client: c, apiBase: '$base/'), isTrue);
  });
}

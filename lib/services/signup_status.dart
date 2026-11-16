import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../constant/constant.dart';

/// How long the Login screen waits for the sign-up check before treating
/// sign-up as closed. Same as web (signupGateway.js SIGNUP_PROBE_TIMEOUT_MS).
const Duration signupProbeTimeout = Duration(seconds: 8);

/// True only when the server body is `{"data": {"enabled": true}}`.
/// Anything else (false, missing, not JSON) counts as closed, like web.
bool parseSignupEnabled(String body) {
  try {
    final json = jsonDecode(body);
    if (json is Map && json['data'] is Map) {
      return json['data']['enabled'] == true;
    }
  } catch (_) {}
  return false;
}

/// Is public sign-up open? GET <api>/api/admin/signup-enabled.
///
/// Matches web (isPublicSignupOpen): a failed, unreadable or slow answer
/// counts as closed, so users never see a sign-up that cannot complete.
/// Sent without login headers, because nobody is signed in yet.
Future<bool> isPublicSignupOpen({
  http.Client? client,
  String? apiBase,
  Duration timeout = signupProbeTimeout,
}) async {
  final base = (apiBase ?? Api_url).replaceAll(RegExp(r'/+$'), '');
  final c = client ?? http.Client();
  try {
    final res = await c
        .get(Uri.parse('$base/api/admin/signup-enabled'),
            headers: const {'Accept': 'application/json'})
        .timeout(timeout);
    if (res.statusCode < 200 || res.statusCode >= 300) return false;
    return parseSignupEnabled(res.body);
  } catch (_) {
    return false;
  } finally {
    if (client == null) c.close();
  }
}

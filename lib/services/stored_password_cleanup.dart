import 'package:shared_preferences/shared_preferences.dart';

/// Keys older builds saved the signed-in user's password under, in plain
/// text, on every login (one per role). Nothing reads them any more: the
/// change-password screens send the current password the user types and the
/// server checks it.
const legacySessionPasswordKeys = [
  'password',
  'staffmember_password',
  'tenant_password',
  'vendor_password',
];

/// Deletes any copy an older build left on the device. Runs at every launch;
/// a failure here must never stop the app from starting.
Future<void> purgeStoredSessionPasswords() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    for (final key in legacySessionPasswordKeys) {
      if (prefs.containsKey(key)) await prefs.remove(key);
    }
  } catch (_) {}
}

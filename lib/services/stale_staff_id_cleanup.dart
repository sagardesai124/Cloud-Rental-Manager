import 'package:shared_preferences/shared_preferences.dart';

/// Removes a `staff_id` left over from an earlier Staff sign-in when the
/// current session is not a Staff one.
///
/// Web sends the CURRENT role's own id in the `id` header (its request
/// interceptor reads that role's `activeSession_<role>`), so a staff id never
/// reaches an Admin call there. Here `staff_id` is written on Staff sign-in
/// and only removed by the menu logout's `prefs.clear()`; a Staff session that
/// ended any other way (expired token, app closed, signing in as another role)
/// left it behind. The screens Admin and Staff share send `staff_id` whenever
/// it is set, so an Admin then got 401 "User does not exist or is not active."
/// on them (Settings: "Failed to fetch vendors").
///
/// Runs after every Admin / Tenant / Vendor sign-in and at every launch; a
/// failure here must never stop either.
Future<void> dropStaleStaffId() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString('role') != 'Staffmember' &&
        prefs.containsKey('staff_id')) {
      await prefs.remove('staff_id');
    }
  } catch (_) {}
}

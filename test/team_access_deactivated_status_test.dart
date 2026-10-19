
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:three_zero_two_property/Model/team_member.dart';

/// Settings → Team & Access shows a member an admin turned off as
/// "Deactivated" (grey) and lists them after pending and active members, like
/// web (TeamAccess.jsx: `status === "deactivate"` → "Deactivated"; sort pending
/// → active → deactivated). Before, the model never read `status`, so a
/// deactivated member still showed a green "Active".




void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(
        {'token': 'tkn', 'adminId': 'ADMIN-1', 'role': 'Admin'});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('PonnamKarthik/fluttertoast'), (_) async => true);
  });

  test('model reads status: deactivate is Deactivated, pending never is', () {
    expect(TeamAdmin.fromJson({'status': 'deactivate'}).isDeactivated, isTrue);
    expect(TeamAdmin.fromJson({'status': 'activate'}).isDeactivated, isFalse);
    expect(TeamAdmin.fromJson({}).isDeactivated, isFalse);
    expect(
        TeamAdmin.fromJson({'status': 'deactivate', 'is_pending': true})
            .isDeactivated,
        isFalse);
    expect(TeamStaff.fromJson({'status': 'deactivate'}).isDeactivated, isTrue);
  });
}

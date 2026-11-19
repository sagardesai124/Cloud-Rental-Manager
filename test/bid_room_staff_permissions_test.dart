import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:three_zero_two_property/StaffModule/model/staffpermission.dart';
import 'package:three_zero_two_property/screens/BidRoom/bid_room_table.dart';

/// Staff Bid Room showed Add, Edit and Delete to every staff member. Web
/// (BidRequests.jsx) gates them: `admin || permissions.workorder_add/edit/
/// delete`.
void main() {
  test('Admin sees every action, like web', () {
    final a = BidRoomActions.of(isStaff: false);
    expect([a.add, a.edit, a.delete], [true, true, true]);
  });

  test('QA 1: staff with Work Order View only sees no Add, Edit or Delete',
      () {
    final a = BidRoomActions.of(
        isStaff: true,
        permissions: StaffPermission(
            workorderView: true,
            workorderAdd: false,
            workorderEdit: false,
            workorderDelete: false));
    expect([a.add, a.edit, a.delete], [false, false, false]);
  });

  test('QA 2: staff with Add, Edit and Delete sees all three', () {
    final a = BidRoomActions.of(
        isStaff: true,
        permissions: StaffPermission(
            workorderView: true,
            workorderAdd: true,
            workorderEdit: true,
            workorderDelete: true));
    expect([a.add, a.edit, a.delete], [true, true, true]);
  });

  test('each action follows its own permission', () {
    final a = BidRoomActions.of(
        isStaff: true,
        permissions: StaffPermission(
            workorderAdd: false, workorderEdit: true, workorderDelete: false));
    expect([a.add, a.edit, a.delete], [false, true, false]);
  });

  test('staff permissions not loaded yet: nothing shown, like web', () {
    final a = BidRoomActions.of(isStaff: true);
    expect([a.add, a.edit, a.delete], [false, false, false]);
  });

  test('screen gates Add and both layouts\' Edit and Delete', () {
    final src =
        File('lib/screens/BidRoom/bid_room_table.dart').readAsStringSync();
    expect('if (_actions.add)'.allMatches(src).length, 1);
    expect('if (_actions.edit)'.allMatches(src).length, 4);
    expect('if (_actions.delete)'.allMatches(src).length, 4);
  });
}

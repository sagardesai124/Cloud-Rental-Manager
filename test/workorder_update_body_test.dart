import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:three_zero_two_property/constant/constant.dart';

void main() {
  test('matches the shape web sends (WorkOrderDetails.js:664-669)', () {
    // Exactly what the Admin Update screen builds today.
    final values = <String, dynamic>{
      "date": "2026-09-16",
      "message": "Fixed the leak",
      "status": "Completed",
      "statusUpdatedBy": "Admin",
      "staffmember_id": "SM-1",
      "notificationTime": "2026-09-16 14:32:11",
    };

    final body = workOrderUpdateBody(values);
    print(const JsonEncoder.withIndent('  ').convert(body));

    // 1. the server reads req.body.notificationTime - it must be on the envelope
    expect(body['notificationTime'], "2026-09-16 14:32:11");
    // 2. and NOT left inside the box
    expect((body['workOrder'] as Map).containsKey('notificationTime'), isFalse);
    // 3. every other field is untouched
    expect(body['workOrder'], {
      "date": "2026-09-16",
      "message": "Fixed the leak",
      "status": "Completed",
      "statusUpdatedBy": "Admin",
      "staffmember_id": "SM-1",
    });
    // 4. the caller's own map is not mutated
    expect(values.containsKey('notificationTime'), isTrue);
  });

  test('Vendor sent nothing - helper fills in a valid time', () {
    final body = workOrderUpdateBody({"status": "In Progress"});
    final t = body['notificationTime'] as String;
    print('vendor notificationTime -> $t');
    // same format web uses: moment().format("YYYY-MM-DD HH:mm:ss")
    expect(RegExp(r'^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$').hasMatch(t), isTrue);
  });
}

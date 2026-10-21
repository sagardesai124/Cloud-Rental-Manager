import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:three_zero_two_property/Model/template_model.dart';

/// Send E-mail (Admin and Staff) fills in the template the same way web does
/// (SendMails.jsx fetchTemplate): the account's own ACTIVE template, else the
/// shared default that is active, else none — in which case Subject and Body
/// are cleared and web's warning is shown. Before, the screen took whichever
/// template came first and threw (`Bad state: No element`) on an event with
/// no template, leaving the previous event's Subject and Body on screen.

Template _t(String name, {String adminId = '', bool active = false}) => Template(
    id: 'ID-$name',
    name: name,
    subject: 'Subject $name',
    body: '<p>$name</p>',
    adminId: adminId,
    isActive: active);

void main() {
  group('activeTemplateFor', () {
    test('prefers the account\'s own active template', () {
      final picked = activeTemplateFor([
        _t('Default', active: true),
        _t('Mine', adminId: 'ADMIN-1', active: true),
        _t('Other company', adminId: 'ADMIN-2', active: true),
      ], 'ADMIN-1');
      expect(picked?.name, 'Mine');
    });

    test('falls back to the shared default that is active', () {
      final picked = activeTemplateFor([
        _t('Mine but off', adminId: 'ADMIN-1'),
        _t('Default', active: true),
      ], 'ADMIN-1');
      expect(picked?.name, 'Default');
    });

    test('ignores the first template when it is not active', () {
      final picked = activeTemplateFor([
        _t('First, off'),
        _t('Second, on', active: true),
      ], 'ADMIN-1');
      expect(picked?.name, 'Second, on');
    });

    test('none when the event has no template, or none active', () {
      expect(activeTemplateFor([], 'ADMIN-1'), isNull);
      expect(activeTemplateFor([_t('Off'), _t('Also off', adminId: 'ADMIN-1')],
          'ADMIN-1'), isNull);
    });
  });

  test('Template reads admin_id and is_active from the server', () {
    final mine = Template.fromJson({
      'template_id': 'T-1',
      'name': 'Welcome',
      'subject': 'Hi',
      'body': '<p>hi</p>',
      'admin_id': 'ADMIN-1',
      'is_active': true,
    });
    expect(mine.adminId, 'ADMIN-1');
    expect(mine.isActive, isTrue);

    final shared = Template.fromJson({
      'template_id': 'T-2',
      'name': 'Default',
      'subject': 'Hi',
      'body': '<p>hi</p>',
      'admin_id': '',
      'is_active': 'true',
    });
    expect(shared.adminId, '');
    expect(shared.isActive, isTrue);

    final legacy = Template.fromJson(
        {'template_id': 'T-3', 'name': 'Old', 'subject': 's', 'body': 'b'});
    expect(legacy.adminId, '');
    expect(legacy.isActive, isFalse);
  });

  test('web wording for the no-template warning', () {
    expect(
        kNoActiveTemplateMessage,
        'No active template found for this Event Type. Edit the Subject and '
        'Body manually, or activate a template in Settings → Templates.');
  });

  test('both Send E-mail screens use the shared pick and never .first', () {
    for (final path in [
      'lib/screens/Communications/Send E-mail/send_mail.dart',
      'lib/StaffModule/screen/Communications/Send E-mail/send_mail.dart',
    ]) {
      final src = File(path).readAsStringSync();
      expect(src, isNot(contains('templateList.first;')), reason: path);
      expect(src, contains('activeTemplateFor(templateList, adminId)'),
          reason: path);
      expect(src, contains('Fluttertoast.showToast(msg: kNoActiveTemplateMessage)'),
          reason: path);
      expect(src, contains('_htmlEditorController.clear()'), reason: path);
    }
  });
}

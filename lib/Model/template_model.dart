class Template {
  final String id;
  final String name;
  final String subject;
  final String body;
  /// Owner account ("" for the shared defaults) and whether this is the one
  /// Send E-mail starts from — the two things web's fetchTemplate checks.
  final String adminId;
  final bool isActive;

  Template({
    required this.id,
    required this.name,
    required this.subject,
    required this.body,
    this.adminId = '',
    this.isActive = false,
  });

  factory Template.fromJson(Map<String, dynamic> json) {
    return Template(
      id: json['template_id'],
      name: json['name'],
      subject: json['subject'],
      body: json['body'],
      adminId: (json['admin_id'] ?? '').toString(),
      isActive: json['is_active'] == true || '${json['is_active']}' == 'true',
    );
  }
}

/// Shown when an event has no active template (web's wording).
const String kNoActiveTemplateMessage =
    'No active template found for this Event Type. Edit the Subject and Body '
    'manually, or activate a template in Settings → Templates.';

/// The template Send E-mail fills in for an event, like web
/// (SendMails.jsx fetchTemplate): the account's own active one, else the
/// shared default that is active, else none.
Template? activeTemplateFor(List<Template> templates, String? adminId) {
  for (final t in templates) {
    if (t.isActive && t.adminId == (adminId ?? '')) return t;
  }
  for (final t in templates) {
    if (t.isActive && t.adminId == '') return t;
  }
  return null;
}

/// Web's email rule for the tenant form (tenantFormConfig.js `EMAIL_REGEX`,
/// used by Add Tenant and Edit Tenant on web): letters, numbers and
/// `. _ % + -` before the @, then a domain with a 2+ letter ending.
final RegExp webEmailRegex =
    RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');

/// Web's message when an email doesn't match [webEmailRegex].
const String webInvalidEmailMessage = 'Invalid email address';

bool isWebEmail(String value) => webEmailRegex.hasMatch(value);

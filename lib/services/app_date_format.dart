import 'package:intl/intl.dart';

/// The company's date format, shared app-wide, like web's `themes.format`.
///
/// Web stores the format in moment tokens ("DD/MMM/YYYY") and shows every
/// date and date field in it (DatePicker `dateFormat={dateFormat}`). The app
/// shows dates with intl, whose tokens differ in case ("dd/MMM/yyyy"), and
/// reads a date field's text back to the server's `yyyy-MM-dd` on save.
/// [DateProvider] keeps this in step with the saved theme; everything that
/// parses a shown date tries [AppDateFormat.current] first, so a custom format
/// such as "DD/MMM/YYYY" or "MM-DD-YYYY" round-trips exactly like web.

/// Default when nothing is saved yet, in intl tokens (web default MM/DD/YYYY).
const String kDefaultAppDateFormat = 'MM/dd/yyyy';

/// Web's three preset options, in web (moment) tokens.
const List<String> kPresetWebDateFormats = [
  'MM/DD/YYYY',
  'YYYY-MM-DD',
  'YYYY-MMM-DD',
];

class AppDateFormat {
  AppDateFormat._();

  static String _current = kDefaultAppDateFormat;

  /// The company's date format in intl tokens, e.g. "dd/MMM/yyyy".
  static String get current => _current;

  /// Set by [DateProvider] whenever the saved format loads or changes.
  static void set(String intlFormat) {
    final f = intlFormat.trim();
    _current = f.isEmpty ? kDefaultAppDateFormat : f;
  }

  /// Web (moment) tokens → intl tokens. Day and year change case; month
  /// stays. Moment's `DDD`/`DDDD` is the day of the year and `MMMMM` is
  /// month name + day of year (moment's own quirk); intl has no match for
  /// those, so they are mapped to the nearest tokens and [format] handles
  /// the day-of-year by hand.
  static String toIntl(String webFormat) {
    return webFormat.replaceAllMapped(RegExp(r'[DY]'), (m) {
      return m.group(0) == 'D' ? 'd' : 'y';
    });
  }

  /// intl tokens → web (moment) tokens, for the Settings box and the save
  /// body. Month tokens are already upper case in both.
  static String toWeb(String intlFormat) {
    return intlFormat.replaceAllMapped(RegExp(r'[dy]'), (m) {
      return m.group(0) == 'd' ? 'D' : 'Y';
    });
  }

  /// True when the saved web format is one of web's three preset options.
  static bool isPreset(String webFormat) =>
      kPresetWebDateFormats.contains(webFormat.trim());

  /// Formats [date] in [intlFormat] (default: the company format) exactly as
  /// web's `moment(date).format(webFormat)` would. intl differs from moment on
  /// `ddd`/`dddd` (moment: day of the year, intl: zero-padded day), so those
  /// runs are rendered by hand; everything else is plain intl.
  static String format(DateTime date, [String? intlFormat]) {
    final f = intlFormat ?? _current;
    final dayOfYear = _dayOfYear(date);
    // Replace runs of 3+ d's with placeholders that intl leaves alone
    // (quoted literals), then fill them in.
    var pattern = f;
    final fills = <String, String>{};
    var i = 0;
    pattern = pattern.replaceAllMapped(RegExp(r'd{3,}'), (m) {
      final key = "'\u0001$i\u0001'";
      final run = m.group(0)!;
      fills[key] = run.length == 3
          ? dayOfYear.toString().padLeft(3, '0')
          : dayOfYear.toString().padLeft(4, '0');
      i++;
      return key;
    });
    var out = DateFormat(pattern).format(date);
    fills.forEach((key, value) {
      out = out.replaceAll(key.replaceAll("'", ''), value);
    });
    return out;
  }

  static int _dayOfYear(DateTime d) =>
      d.difference(DateTime(d.year, 1, 1)).inDays + 1;

  /// Reads [shown] (a date as this app displays it) back to `yyyy-MM-dd`, or
  /// null when it is not a date in the company format. Strict, so a date in
  /// another format is never misread (e.g. "05-10-2026" day/month swapped).
  static String? parseShownToApi(String shown) {
    final s = shown.trim();
    if (s.isEmpty) return null;
    final d = _parseStrict(s, _current);
    return d == null ? null : DateFormat('yyyy-MM-dd').format(d);
  }

  /// Like [parseShownToApi] but tries the server's own `yyyy-MM-dd` (with or
  /// without a time part) first, since many fields hold the raw server value
  /// before the user picks a date.
  static String? parseToApi(String shown) {
    final s = shown.trim();
    if (s.isEmpty) return null;
    final iso = RegExp(r'^(\d{4}-\d{2}-\d{2})').firstMatch(s);
    if (iso != null) {
      final d = DateTime.tryParse(iso.group(1)!);
      if (d != null) return iso.group(1);
    }
    return parseShownToApi(s);
  }

  /// A stored date read as a calendar day, with no timezone shift, like web's
  /// parseCalendarDate (utils/renewalTerm.js, DATE_FORMATS): "YYYY-MM-DD" (a
  /// time part after it is ignored), "MM/DD/YYYY" or "M/D/YYYY". With
  /// [dayFirstToo], "DD/MM/YYYY" is tried last, as web's refund modal does for
  /// legacy values. Null when unreadable.
  static DateTime? parseCalendarDate(String? value,
      {bool dayFirstToo = false}) {
    final s = (value ?? '').trim();
    final iso = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(s);
    if (iso != null) {
      return _calendarDay(int.parse(iso.group(1)!), int.parse(iso.group(2)!),
          int.parse(iso.group(3)!));
    }
    final slash = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$').firstMatch(s);
    if (slash == null) return null;
    final first = int.parse(slash.group(1)!);
    final second = int.parse(slash.group(2)!);
    final year = int.parse(slash.group(3)!);
    return _calendarDay(year, first, second) ??
        (dayFirstToo ? _calendarDay(year, second, first) : null);
  }

  static DateTime? _calendarDay(int year, int month, int day) {
    if (month < 1 || month > 12 || day < 1) return null;
    final date = DateTime(year, month, day);
    return date.month == month && date.day == day ? date : null;
  }

  static DateTime? _parseStrict(String s, String intlFormat) {
    try {
      // Day-of-year runs cannot be parsed by intl; read them by hand.
      if (RegExp(r'd{3,}').hasMatch(intlFormat)) {
        return _parseWithDayOfYear(s, intlFormat);
      }
      return DateFormat(intlFormat).parseStrict(s);
    } catch (_) {
      return null;
    }
  }

  /// Parses a format that holds a day-of-year run (moment `DDD`/`DDDD`): the
  /// year must also be present; the month is ignored because the day of the
  /// year already fixes it.
  static DateTime? _parseWithDayOfYear(String s, String intlFormat) {
    final yearMatch = RegExp(r'y+').firstMatch(intlFormat);
    if (yearMatch == null) return null;
    // Build a regex from the format: tokens → digit/word groups, rest literal.
    final buffer = StringBuffer('^');
    final groups = <String>[];
    final tokenRe = RegExp(r'y+|M+|d+');
    var last = 0;
    for (final m in tokenRe.allMatches(intlFormat)) {
      buffer.write(RegExp.escape(intlFormat.substring(last, m.start)));
      final t = m.group(0)!;
      groups.add(t);
      if (t.startsWith('y')) {
        buffer.write(r'(\d{2,4})');
      } else if (t.startsWith('M')) {
        buffer.write(t.length >= 3 ? r'([A-Za-z]+)' : r'(\d{1,2})');
      } else {
        buffer.write(r'(\d{1,4})');
      }
      last = m.end;
    }
    buffer.write(RegExp.escape(intlFormat.substring(last)));
    buffer.write(r'$');
    final match = RegExp(buffer.toString()).firstMatch(s);
    if (match == null) return null;
    int? year;
    int? dayOfYear;
    for (var i = 0; i < groups.length; i++) {
      final t = groups[i];
      final v = match.group(i + 1)!;
      if (t.startsWith('y')) {
        year = int.tryParse(v);
        if (year != null && v.length == 2) year += 2000;
      } else if (t.startsWith('d')) {
        dayOfYear = int.tryParse(v);
      }
    }
    if (year == null || dayOfYear == null || dayOfYear < 1) return null;
    final date = DateTime(year, 1, 1).add(Duration(days: dayOfYear - 1));
    if (date.year != year) return null;
    return date;
  }
}

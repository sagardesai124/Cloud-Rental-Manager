// import 'dart:convert';
//
// import 'package:flutter/material.dart';
// import 'package:intl/intl.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:http/http.dart'as http;
import 'package:three_zero_two_property/services/app_log.dart';
import 'package:three_zero_two_property/services/api_helpers.dart';
//
// import '../constant/constant.dart';
//
// class DateProvider with ChangeNotifier {
//   DateTime _currentDate = DateTime.now();
//   String _dateFormat = 'MM-dd-yyyy';
//   int dateformateselect = 0;// default date format
//
//   DateTime get currentDate => _currentDate;
//   String get dateFormat => _dateFormat;
//   int get _dateformateselect => dateformateselect;
//
//   DateProvider() {
//    _loadDateFormat();
//   }
//
//
//   // Future<void> _loadDateFormat() async {
//   //   final prefs = await SharedPreferences.getInstance();
//   //   final dateFormat = prefs.getString('dateFormat');
//   //   final _dateformateselect = prefs.getInt('dateformateselect');
//   //
//   //   if (dateFormat != null && _dateformateselect != null) {
//   //     _dateFormat = dateFormat;
//   //     dateformateselect = _dateformateselect;
//   //   }
//   // }
//
//   Future<void> _loadDateFormat() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     String? id = prefs.getString("adminId");
//     String? token = prefs.getString('token');
//    //  final response = await apiPost(
//    //    Uri.parse('${Api_url}/api/themes/date-format'),
//    //    headers: {
//    //      "authorization": "CRM $token",
//    //      "id": "CRM $id",
//    //    },
//    //    body: jsonEncode({
//    //      'admin_id': id,
//    //    }),
//    //  );
//    // print('date formate ${response.body}');
//    //  var responseData = json.decode(response.body);
//    //  if (responseData["statusCode"] == 200) {
//    //    final jsonData = jsonDecode(response.body);
//    //
//    //    _dateFormat = jsonData['format'].toString();
//    //   // dateformateselect = jsonData['formatIndex'];
//    //    dateformateselect = _dateformateselect;
//    //    checkToken(jsonData["token"]);
//    //    notifyListeners();
//    //  } else {
//    //
//    //  }
//     checkToken(token!);
//   }
//
//   Future<void> _saveDateFormat() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     String? id = prefs.getString("adminId");
//     String? token = prefs.getString('token');
//     final response = await apiPost(
//       Uri.parse('${Api_url}/api/themes/date-format'),
//       headers: {
//         "authorization": "CRM $token",
//         "id": "CRM $id",
//       },
//       body: jsonEncode({
//         'format': _dateFormat,
//         'admin_id': id,
//       }),
//     );
//
//     if (response.statusCode != 200) {
//       final jsonData = jsonDecode(response.body);
//       // checkToken(jsonData["token"]);
//      print("hello");
//     }else{
//       final jsonData = jsonDecode(response.body);
//       checkToken(jsonData["token"]);
//     }
//   }
//
//   // Future<void> _saveDateFormat() async {
//   //   final prefs = await SharedPreferences.getInstance();
//   //   await prefs.setString('dateFormat', _dateFormat);
//   //   await prefs.setInt('dateformateselect', dateformateselect);
//   // }
//
//   void updateDateFormat(String newFormat,selectindex) {
//     _dateFormat = newFormat;
//     dateformateselect = selectindex;
//     _saveDateFormat();
//     print(_dateFormat);
//     notifyListeners();
//   }
//
//   String formatCurrentDate(String dateTime) {
//
//       //print(dateTime);
//       List<String> dateFormats = [
//         'yyyy-MM-dd',
//         'yyyy-M-d',
//         'dd-MM-yyyy',
//         'd-M-yyyy',
//         'M/d/yyyy',
//         'MM/dd/yyyy',
//         'M/d/yyyy, h:mm:ss a',
//         'M/d/yyyy, h:mm a'        // 05032024 (no separators)
//       ];
//
//       DateTime? parsedDate;
//
//       for (String format in dateFormats) {
//         //  print(dateTime);
//         try {
//           parsedDate = DateFormat(format).parse(dateTime);
//           //  print(parsedDate);
//           break;
//         } catch (e) {
//           continue;
//         }
//       }
//
//       if (parsedDate == null) {
//         return dateTime;
//         //  throw FormatException("Date format not recognized: $dateTime");
//       }
//       // print(parsedDate);
//
//
//     return DateFormat(_dateFormat).format(parsedDate);
//   }
//
//   Future<void> checkToken(String token) async {
//     try {
//       final prefs = await SharedPreferences.getInstance();
//       final adminId = prefs.getString("adminId");
//
//       final response = await apiPost(
//         Uri.parse('${Api_url}/api/auth'),
//         headers: {
//           "authorization": "CRM $token",
//           "id": "CRM $adminId",
//           "Content-Type": "application/json"
//         },
//         body: json.encode({"token": token}),
//       );
//         print(' token ${response.body}');
//       if (response.statusCode == 200) {
//         final jsonData = jsonDecode(response.body);
//         if (jsonData["statusCode"] == 200) {
//
//           _dateFormat = jsonData['format'].toString();
//           dateformateselect = _dateformateselect;
//           notifyListeners();
//         } else {
//
//         }
//       } else {
//
//       }
//     } catch (e) {
//
//     }
//   }
// }

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:three_zero_two_property/services/api_helpers.dart';
import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:three_zero_two_property/services/app_date_format.dart';
import 'package:intl/intl.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '../constant/constant.dart';

class DateProvider with ChangeNotifier {
  DateTime _currentDate = DateTime.now();
  String _dateFormat = 'MM/dd/yyyy';
  int dateformateselect = 0; // default date format
  String _timeFormat = '24'; // default time format (24-hour)
  int timeformateselect = 0; // default time format selection

  /// The date format exactly as the company has it saved (e.g. a custom
  /// "DD/MMM/YYYY" the app does not show yet and displays as MM/DD/YYYY).
  String? _savedServerFormat;

  /// True once the server has answered with the company's saved formats, so
  /// a blank [savedServerFormat] then means the company never saved a Date
  /// Format (rather than "not loaded yet").
  bool _serverFormatLoaded = false;

  DateTime get currentDate => _currentDate;
  String get dateFormat => _dateFormat;
  String get timeFormat => _timeFormat;
  String? get savedServerFormat => _savedServerFormat;
  DateProvider() {
    loadDateFormat();
  }
  String fixDateFormat(String customdate) {
    return customdate.replaceAllMapped(
      RegExp(r'[DY]'),
      (match) {
        if (match.group(0) == 'D') {
          return 'd';
        } else if (match.group(0) == 'Y') {
          return 'y';
        }
        return match
            .group(0)!; // Return the character unchanged if it doesn't match
      },
    );
  }

  Future<void> loadDateFormat() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');

    if (token != null) {
      await checkToken(token);
    } else {
      // If no token, set to default
      _dateFormat = 'MM/dd/yyyy';
      dateformateselect = 0;
      AppDateFormat.set(_dateFormat);
      notifyListeners();
    }
  }

  /// Saves the date and time format. True once the server has accepted it;
  /// the saved theme is then reloaded in the background.
  Future<bool> _saveDateFormat({bool keepSavedDate = false}) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString("adminId");
    String? token = prefs.getString('token');
    final saved = _savedServerFormat?.trim() ?? '';
    if (token == null) return false;
    try {
      final response = await apiPost(
        Uri.parse('${Api_url}/api/themes/date-format'),
        headers: {
          "authorization": "CRM $token",
          "id": "CRM $id",
          "Content-Type": "application/json"
        },
        body: jsonEncode({
          'format': keepSavedDate && saved.isNotEmpty
              ? saved
              : _dateFormat.toUpperCase(),
          'timeFormat': _timeFormat,
          'admin_id': id,
        }),
      );
      if (response.statusCode == 200) {
        unawaited(checkToken(token));
        return true;
      }
    } catch (e) {
      logError("Error saving date format: $e");
    }
    Fluttertoast.showToast(
      msg: 'Failed to save date format',
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.black87,
      textColor: Colors.white,
      fontSize: 16.0,
    );
    return false;
  }

  /// Saves [newFormat] (and the current time format); true once the server
  /// has accepted it.
  Future<bool> updateDateFormat(String newFormat, selectIndex) async {
    _dateFormat = newFormat;
    dateformateselect = selectIndex;
    AppDateFormat.set(_dateFormat);
    // What the company will have once this save lands, so a time-only save
    // made before the reload comes back does not send the old one. Put back
    // if the save fails.
    final before = _savedServerFormat;
    final sending = newFormat.toUpperCase();
    _savedServerFormat = sending;
    _saveSelectedDateFormat();
    notifyListeners();
    final ok = await _saveDateFormat();
    if (!ok && _savedServerFormat == sending) _savedServerFormat = before;
    return ok;
  }

  void updateDateFormatLocally(String newFormat, selectIndex) {
    _dateFormat = newFormat;
    dateformateselect = selectIndex;
    AppDateFormat.set(_dateFormat);
    _saveSelectedDateFormat();
    notifyListeners();
  }

  void updateTimeFormat(String newTimeFormat, selectIndex) {
    _timeFormat = newTimeFormat;
    timeformateselect = selectIndex;
    _saveDateFormat();
    _saveSelectedTimeFormat();
    notifyListeners();
  }

  /// Saves a new time format and sends the date format back exactly as the
  /// company has it saved, a custom one included, like web (which re-sends
  /// its loaded format). Used when only the time was changed. True once the
  /// server has accepted it.
  Future<bool> updateTimeFormatKeepingDate(
      String newTimeFormat, int selectIndex) {
    _timeFormat = newTimeFormat;
    timeformateselect = selectIndex;
    _saveSelectedTimeFormat();
    notifyListeners();
    return _saveDateFormat(keepSavedDate: true);
  }

  void updateTimeFormatLocally(String newTimeFormat, selectIndex) {
    _timeFormat = newTimeFormat;
    timeformateselect = selectIndex;
    _saveSelectedTimeFormat();
    notifyListeners();
  }

  String formatCurrentDate(String dateTime) {
    dateTime = dateTime.trim();

    // Handle special cases
    if (dateTime == "At Will" || dateTime == "---") {
      return dateTime;
    }

    List<String> dateFormats = [
      'yyyy-MM-dd',
      'yyyy-M-d',
      'dd-MM-yyyy',
      'd-M-yyyy',
      'M/d/yyyy',
      'MM/dd/yyyy',
      'M/d/yyyy, h:mm:ss a',
      'M/d/yyyy, h:mm a'
    ];

    DateTime? parsedDate;

    for (String format in dateFormats) {
      try {
        parsedDate = DateFormat(format).parse(dateTime);
        break;
      } catch (e) {
        continue;
      }
    }

    if (parsedDate == null) {
      return dateTime; // Return original string if parsing fails
    }

    // Convert the parsed date to 'yyyy-MM-dd' format first
    String standardizedDate = DateFormat('yyyy-MM-dd').format(parsedDate);

    // Format the standardized date using _dateFormat (web's moment tokens,
    // day-of-year included, via AppDateFormat).
    return AppDateFormat.format(DateTime.parse(standardizedDate), _dateFormat);
  }

  String formatCurrentDateTime(String dateTime) {
    dateTime = dateTime.trim();

    // Handle special cases
    if (dateTime == "At Will" || dateTime == "---") {
      return dateTime;
    }

    DateTime? parsedDate;

    // Parse the ISO 8601 format (2025-05-26T11:59:24.867Z)
    try {
      parsedDate = DateTime.parse(dateTime);
    } catch (e) {
      // If DateTime.parse fails, try with specific formats as fallback
      List<String> dateTimeFormats = [
        'yyyy-MM-dd HH:mm:ss',
        'yyyy-MM-dd HH:mm',
        'yyyy-M-d HH:mm:ss',
        'yyyy-M-d HH:mm',
        'dd-MM-yyyy HH:mm:ss',
        'dd-MM-yyyy HH:mm',
        'd-M-yyyy HH:mm:ss',
        'd-M-yyyy HH:mm',
        'M/d/yyyy HH:mm:ss',
        'M/d/yyyy HH:mm',
        'MM/dd/yyyy HH:mm:ss',
        'MM/dd/yyyy HH:mm',
        'yyyy-MM-dd',
        'yyyy-M-d',
        'dd-MM-yyyy',
        'd-M-yyyy',
        'M/d/yyyy',
        'MM/dd/yyyy'
      ];

      for (String format in dateTimeFormats) {
        try {
          parsedDate = DateFormat(format).parse(dateTime);
          break;
        } catch (e) {
          continue;
        }
      }
    }

    if (parsedDate == null) {
      return dateTime; // Return original string if parsing fails
    }

    // Convert to match web timezone (assuming web shows UTC+5:30 for IST)
    // Adjust the offset based on your web application's timezone
    DateTime webTimezoneDate = parsedDate.add(Duration(hours: 5, minutes: 30));

    // Create a datetime format that includes time based on time format preference
    String timeFormatPattern = _timeFormat == '24' ? 'HH:mm:ss' : 'h:mm:ss a';
    String dateTimeFormat = '$_dateFormat $timeFormatPattern';

    // Debug print to see what's happening

    // Format the date using the combined format
    String result = DateFormat(dateTimeFormat).format(webTimezoneDate);
    return result;
  }

  /// Formats [dateTime] in the device's local time with the saved Date & Time
  /// Format — the mobile twin of web's `formatDateTime` (moment, local time).
  /// Unlike [formatCurrentDateTime] it applies no fixed +5:30 shift.
  String formatLocalDateTime(DateTime dateTime) {
    String timeFormatPattern = _timeFormat == '24' ? 'HH:mm:ss' : 'h:mm:ss a';
    return DateFormat('$_dateFormat $timeFormatPattern')
        .format(dateTime.toLocal());
  }

  /// Exactly web's `formatDateTime` (TenantDetailPage.jsx): the date in the
  /// company Date Format, a space, then `HH:mm:ss`, or `hh:mm:ss A` when the
  /// Time Format is 12-hour (hour zero-padded, e.g. "06:22:35 PM"), in local
  /// time like moment. E.g. "2026-07-15 18:22:35" / "07/15/2026 06:22:35 PM".
  ///
  /// When the company never saved a Date Format, that page falls back to
  /// "YYYY-MM-DD" (`themes.format || "YYYY-MM-DD"`), not the MM/DD/YYYY the
  /// rest of the app uses (like web Settings), so the same happens here.
  String formatWebDateTime(DateTime dateTime) => webDateTime(dateTime,
      dateFormat: webDateFormat, timeFormat: _timeFormat);

  /// Web's `themes.format || "YYYY-MM-DD"` in intl tokens: the company Date
  /// Format, or yyyy-MM-dd when the company never saved one.
  String get webDateFormat =>
      _serverFormatLoaded && (_savedServerFormat ?? '').trim().isEmpty
          ? 'yyyy-MM-dd'
          : _dateFormat;

  /// A date-only value shown like web's list pages (e.g. PendingLeases.jsx
  /// `formatDate`): in [webDateFormat], or "N/A" when missing or invalid.
  String formatWebDate(String? raw) => webDate(raw, dateFormat: webDateFormat);

  /// Exactly web's `moment(raw, DATE_FORMATS)` then `.format(...)`, where
  /// DATE_FORMATS is ["YYYY-MM-DD", "MM/DD/YYYY", "M/D/YYYY"]: reads the
  /// date at the start of [raw] (so an ISO timestamp keeps its calendar day,
  /// with no time-zone shift), and returns "N/A" for an empty, "At Will" or
  /// impossible date instead of "Invalid date".
  static String webDate(String? raw, {required String dateFormat}) {
    final s = (raw ?? '').trim();
    if (s.isEmpty) return 'N/A';
    int y, m, d;
    final iso = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})').firstMatch(s);
    final us = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})').firstMatch(s);
    if (iso != null) {
      y = int.parse(iso.group(1)!);
      m = int.parse(iso.group(2)!);
      d = int.parse(iso.group(3)!);
    } else if (us != null) {
      m = int.parse(us.group(1)!);
      d = int.parse(us.group(2)!);
      y = int.parse(us.group(3)!);
    } else {
      return 'N/A';
    }
    final date = DateTime.utc(y, m, d);
    if (date.year != y || date.month != m || date.day != d) return 'N/A';
    return AppDateFormat.format(date, dateFormat);
  }

  /// [formatWebDateTime] for a given format pair: [dateFormat] in intl tokens
  /// (as [dateFormat] holds it), [timeFormat] "12" or "24" (anything but "12"
  /// is 24-hour, like web).
  static String webDateTime(DateTime dateTime,
      {required String dateFormat, required String timeFormat}) {
    final local = dateTime.toLocal();
    final time = timeFormat == '12' ? 'hh:mm:ss a' : 'HH:mm:ss';
    return '${AppDateFormat.format(local, dateFormat)} '
        '${DateFormat(time).format(local)}';
  }

  // Future<void> checkToken(String token) async {
  //   try {
  //     final prefs = await SharedPreferences.getInstance();
  //     final adminId = prefs.getString("adminId");
  //
  //     final response = await apiPost(
  //       Uri.parse('${Api_url}/api/auth'),
  //       headers: {
  //         "authorization": "CRM $token",
  //         "id": "CRM $adminId",
  //         "Content-Type": "application/json"
  //       },
  //       body: json.encode({"token": token}),
  //     );
  //     print("date formate calling ${response.body}");
  //     if (response.statusCode == 200) {
  //       final jsonData = jsonDecode(response.body);
  //       if (jsonData["statusCode"] == 200) {
  //         _dateFormat = jsonData['format'].toString();
  //         dateformateselect = _dateformateselect;
  //         notifyListeners();
  //       } else {
  //         // Handle invalid token case
  //         _dateFormat = 'MM-dd-yyyy'; // Reset to default
  //         dateformateselect = 0;
  //         notifyListeners();
  //       }
  //     } else {
  //       // Handle error
  //       _dateFormat = 'MM-dd-yyyy'; // Reset to default
  //     }
  //   } catch (e) {
  //     // Handle error
  //   }
  // }
  Future<void> checkToken(String? token) async {
    if (token == null || token.isEmpty) {
      return;
    }

    // Proceed with token validation
    try {
      final prefs = await SharedPreferences.getInstance();
      // Send the logged-in user's OWN id (same as the web client) so the
      // server resolves the correct user branch; adminId is only correct
      // for admins and 401s for staff at multi-co-admin companies.
      final role = prefs.getString("role");
      String? headerId;
      if (role == "Staffmember") {
        headerId = prefs.getString("staff_id");
      } else if (role == "Tenant") {
        headerId = prefs.getString("tenant_id");
      } else if (role == "Vendor") {
        headerId = prefs.getString("vendor_id");
      }
      headerId ??= prefs.getString("adminId");

      final response = await apiPost(
        Uri.parse('${Api_url}/api/auth'),
        headers: {
          "authorization": "CRM $token",
          "id": "CRM $headerId",
          "Content-Type": "application/json"
        },
        body: json.encode({"token": token}),
      );

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        String? serverFormat = jsonData['themes']?['format']?.toString();
        String? serverTimeFormat =
            jsonData['themes']?['timeFormat']?.toString();
        _savedServerFormat = serverFormat;
        _serverFormatLoaded = true;

        // Like web (Settings.jsx): the three presets select their option;
        // any other saved format, M/D/YYYY included, is the Custom option
        // and is shown as saved. Nothing saved → web's default MM/DD/YYYY.
        final saved = (serverFormat ?? '').trim();
        if (saved == "YYYY-MM-DD") {
          dateformateselect = 1;
          _dateFormat = 'yyyy-MM-dd';
        } else if (saved == "YYYY-MMM-DD") {
          dateformateselect = 2;
          _dateFormat = 'yyyy-MMM-dd';
        } else if (saved == "MM/DD/YYYY" || saved.isEmpty) {
          dateformateselect = 0;
          _dateFormat = 'MM/dd/yyyy';
        } else {
          dateformateselect = 3;
          _dateFormat = AppDateFormat.toIntl(saved);
        }

        // Handle time format
        if (serverTimeFormat == "24") {
          timeformateselect = 0;
          _timeFormat = '24';
        } else if (serverTimeFormat == "12") {
          timeformateselect = 1;
          _timeFormat = '12';
        } else {
          // Default to 24-hour format
          timeformateselect = 0;
          _timeFormat = '24';
        }

        _dateFormat = fixDateFormat(_dateFormat);
        AppDateFormat.set(_dateFormat);
        notifyListeners();
      } else {
        // Set default format on error
        _dateFormat = 'MM/dd/yyyy';
        dateformateselect = 0;
        AppDateFormat.set(_dateFormat);
        notifyListeners();
      }
    } catch (e) {
      logError("Error in checkToken: $e");
    }
  }

  Future<void> _saveSelectedDateFormat() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selectedDateFormat', _dateFormat);
    await prefs.setInt('selectedDateIndex', dateformateselect);
  }

  Future<void> _saveSelectedTimeFormat() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selectedTimeFormat', _timeFormat);
    await prefs.setInt('selectedTimeIndex', timeformateselect);
  }

  /// [dateFormat] previews a format that is not saved yet (Custom being typed).
  String getFormattedDateTimePreview({String? dateFormat}) {
    DateTime now = DateTime.now();
    // Same as web's "HOW IT APPEARS" preview (DateFormatSection.jsx):
    // seconds included, and a leading zero on 12-hour times.
    String timeFormatPattern = _timeFormat == '24' ? 'HH:mm:ss' : 'hh:mm:ss a';
    // Date part through AppDateFormat so moment-only tokens (DDD day of the
    // year) render as web does; time part is plain intl.
    final datePart = AppDateFormat.format(now, dateFormat ?? _dateFormat);
    return '$datePart ${DateFormat(timeFormatPattern).format(now)}';
  }
}

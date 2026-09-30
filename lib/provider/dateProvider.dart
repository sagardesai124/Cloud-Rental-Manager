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
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '../constant/constant.dart';

class DateProvider with ChangeNotifier {
  DateTime _currentDate = DateTime.now();
  String _dateFormat = 'MM/dd/yyyy';
  int dateformateselect = 0; // default date format
  String _timeFormat = '24'; // default time format (24-hour)
  int timeformateselect = 0; // default time format selection

  DateTime get currentDate => _currentDate;
  String get dateFormat => _dateFormat;
  String get timeFormat => _timeFormat;
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
      notifyListeners();
    }
  }

  Future<void> _saveDateFormat() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString("adminId");
    String? token = prefs.getString('token');
    if (token != null) {
      final response = await apiPost(
        Uri.parse('${Api_url}/api/themes/date-format'),
        headers: {
          "authorization": "CRM $token",
          "id": "CRM $id",
          "Content-Type": "application/json"
        },
        body: jsonEncode({
          'format': _dateFormat.toUpperCase(),
          'timeFormat': _timeFormat,
          'admin_id': id,
        }),
      );
      if (response.statusCode != 200) {
        // Handle error
        Fluttertoast.showToast(
          msg: 'Failed to save date format',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.black87,
          textColor: Colors.white,
          fontSize: 16.0,
        );
      } else {
        final jsonData = jsonDecode(response.body);
        await checkToken(token);
      }
    }
  }

  void updateDateFormat(String newFormat, selectIndex) {
    _dateFormat = newFormat;
    dateformateselect = selectIndex;
    _saveDateFormat();
    _saveSelectedDateFormat();
    notifyListeners();
  }

  void updateDateFormatLocally(String newFormat, selectIndex) {
    _dateFormat = newFormat;
    dateformateselect = selectIndex;
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

    // Format the standardized date using _dateFormat
    return DateFormat(_dateFormat).format(DateTime.parse(standardizedDate));
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

        if (serverFormat == "YYYY-MM-DD") {
          dateformateselect = 1;
          _dateFormat = 'yyyy-MM-dd';
        } else if (serverFormat == "YYYY-MMM-DD") {
          dateformateselect = 2;
          _dateFormat = 'yyyy-MMM-dd';
        } else if (serverFormat == "MM/DD/YYYY") {
          dateformateselect = 0;
          _dateFormat = 'MM/dd/yyyy';
        } else if (serverFormat == "M/D/YYYY") {
          dateformateselect = 0;
          _dateFormat = 'M/d/yyyy';
        } else {
          // Handle custom case or default
          dateformateselect = 0;
          _dateFormat = 'MM/dd/yyyy'; // Default to MM/dd/yyyy
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
        notifyListeners();
      } else {
        // Set default format on error
        _dateFormat = 'MM/dd/yyyy';
        dateformateselect = 0;
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

  String getFormattedDateTimePreview() {
    DateTime now = DateTime.now();
    String timeFormatPattern = _timeFormat == '24' ? 'HH:mm' : 'h:mm a';
    String dateTimeFormat = '$_dateFormat $timeFormatPattern';
    return DateFormat(dateTimeFormat).format(now);
  }
}

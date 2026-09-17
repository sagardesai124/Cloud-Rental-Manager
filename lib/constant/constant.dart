import 'package:three_zero_two_property/services/app_log.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:video_player/video_player.dart';
import 'package:zxcvbn/zxcvbn.dart';

String image_url =
    "https://staging.cloudrentalmanager.com/api/images/get-file/";
//String image_url = "http://192.168.1.37:4000/api/images/get-file/";
//String image_url = "https://saas.cloudrentalmanager.com/api/images/get-file/";

//String Api_url = "http://192.168.39.1:4000";
//String Api_url = "http://192.168.1.33:4000";

//String Api_url = "https://saas.cloudrentalmanager.com";
String Api_url = "https://staging.cloudrentalmanager.com";
//String Api_url = "https://development.cloudrentalmanager.com";

//String image_upload_url = "https://saas.cloudrentalmanager.com";
String image_upload_url = "https://staging.cloudrentalmanager.com";

// ===================== Safe JSON coercion helpers =====================r
// The backend is loosely typed — the same field can arrive as a String on one
// environment and a number/bool on another (e.g. a phone number as "(555)…" on
// staging but 5551234567 on production). A direct cast like
// `String? x = json['x']` then throws a TypeError and the whole parse — and
// often the screen — dies. Use these in EVERY `fromJson` instead of casting:
//
//   name   = asStr(json['name']);      // any value -> String ("" if null)
//   active = asBool(json['active']);   // bool / 1-0 / "true" -> bool
//   count  = asInt(json['count']);     // num / "12" -> int
//   items  = asObjectList(json['items']).map(Item.fromJson).toList();

/// Any value → String. Returns [fallback] (default "") for null.
String asStr(dynamic value, [String fallback = '']) =>
    value == null ? fallback : value.toString();

/// Any value → bool. Accepts real bools, 1/0 numbers, "true"/"1"/"yes" strings.
bool asBool(dynamic value, [bool fallback = false]) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final v = value.trim().toLowerCase();
    return v == 'true' || v == '1' || v == 'yes';
  }
  return fallback;
}

/// Any value → int. Handles num and numeric strings; [fallback] (default 0)
/// otherwise. Doubles are truncated.
int asInt(dynamic value, [int fallback = 0]) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim()) ?? fallback;
  return fallback;
}

/// Any value → double. Handles num and numeric strings; [fallback] (default 0)
/// otherwise.
double asDouble(dynamic value, [double fallback = 0]) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value.trim()) ?? fallback;
  return fallback;
}

/// Nullable, type-preserving numeric parse for model `fromJson`.
/// Keeps null as null (does NOT coerce to 0), keeps int as int and double as
/// double (so payload round-trips are unchanged), and parses a numeric String
/// to num. Use for `num?` fields so a decimal/int/string from the API can't
/// throw "type 'X' is not a subtype of type 'int?'".
num? asNumN(dynamic value) {
  if (value == null) return null;
  if (value is num) return value;
  if (value is String) return num.tryParse(value.trim());
  return null;
}

/// Nullable variants for `double?` / `int?` fields: null stays null, any present
/// value (int, double, or numeric String) is coerced safely to the field type.
double? asDoubleN(dynamic value) => value == null ? null : asDouble(value);
int? asIntN(dynamic value) => value == null ? null : asInt(value);

/// A loose value → Map<String, dynamic> (empty map if it isn't a map).
Map<String, dynamic> asObject(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

/// A loose value → list of JSON objects. Tolerates null / non-list inputs and
/// skips non-object entries, so a malformed array can't crash a parse.
List<Map<String, dynamic>> asObjectList(dynamic value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList();
}
// ======================================================================

// formatDate(String dateTime) {
//   //print(dateTime);
//   List<String> dateFormats = [
//     'yyyy-MM-dd',
//     'yyyy-M-d',
//     'dd-MM-yyyy',
//     'd-M-yyyy',
//     'M/d/yyyy',
//     'MM/dd/yyyy',
//     'M/d/yyyy, h:mm:ss a',
//     'M/d/yyyy, h:mm a' // 05032024 (no separators)
//   ];
//
//   DateTime? parsedDate;
//
//   for (String format in dateFormats) {
//     //  print(dateTime);
//     try {
//       parsedDate = DateFormat(format).parse(dateTime);
//       //  print(parsedDate);
//       break;
//     } catch (e) {
//       continue;
//     }
//   }
//
//   if (parsedDate == null) {
//     return dateTime;
//     //  throw FormatException("Date format not recognized: $dateTime");
//   }
//   // print(parsedDate);
//   return DateFormat('yyyy-MM-dd').format(parsedDate);
// }

// String formatDate4(String dateTime) {
//   DateTime parsedDate = DateFormat('yyyy-MM-dd').parse(dateTime);0
//   return DateFormat('dd-MM-yyyy').format(parsedDate);
// }

formatDate(String dateTime) {
  // If already in correct format, return as is
  if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(dateTime.trim())) {
    return dateTime;
  }

  List<String> dateFormats = [
    'yyyy-MM-dd',
    'yyyy-M-d',
    'yyyy-MMM-dd', // e.g. 2025-Jan-01
    'yyyy-MMM-d', // e.g. 2025-Jan-1
    'dd-MM-yyyy',
    'd-M-yyyy',
    'd-MMM-yyyy', // e.g. 1-Jan-2025
    'dd-MMM-yyyy', // e.g. 01-Jan-2025
    'M/d/yyyy',
    'MM/dd/yyyy',
    'M/d/yyyy, h:mm:ss a',
    'M/d/yyyy, h:mm a',
    'dd/MMMM/yyyy', // e.g. 01/August/2032
    'd/MMMM/yyyy', // e.g. 1/August/2032
    'dd/MMM/yyyy', // e.g. 01/Aug/2032
    'd/MMM/yyyy', // e.g. 1/Aug/2032
  ];

  DateTime? parsedDate;

  for (String format in dateFormats) {
    try {
      parsedDate = DateFormat(format).parse(dateTime);
      break;
    } catch (e) {
      logError(
          "formatDate failed to parse '$dateTime' with format '$format': $e");
      continue;
    }
  }

  if (parsedDate == null) {
    return dateTime;
  }

  String result = DateFormat('yyyy-MM-dd').format(parsedDate);
  return result;
}

String formatDate4(String dateTime) {
  if (dateTime.isEmpty) {
    return ""; // Handle empty or invalid date input
  }

  try {
    DateTime parsedDate = DateFormat('yyyy-MM-dd').parse(dateTime);
    return DateFormat('dd-MM-yyyy').format(parsedDate);
  } catch (e) {
    return ""; // Return this if parsing fails
  }
}

String formatDate3(String dateStr) {
  DateTime dateTime = DateTime.parse(dateStr);
  return DateFormat('dd-MM-yyyy').format(dateTime);
}

// String reverseFormatDate(String formattedDate) {
//   print(formattedDate);
//   DateTime dateTime = DateFormat('dd-MM-yyyy').parse(formattedDate);
//   return DateFormat('yyyy-MM-dd').format(dateTime);
// }
String reverseFormatDate(String formattedDate) {
  // Check if the formattedDate is empty or invalid
  if (formattedDate.isEmpty) {
    return ""; // Return an empty string if the date is empty
  }

  try {
    // Clean the input string - remove any extra whitespace
    String cleanDate = formattedDate.trim();

    // If the date is already in yyyy-MM-dd format, return it as is
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(cleanDate)) {
      return cleanDate;
    }

    // Special handling for yyyy-MM-dd format that might have extra characters
    if (RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(cleanDate)) {
      String extractedDate = cleanDate.substring(0, 10);
      return extractedDate;
    }

    // List of possible date formats that DateProvider might return
    // Prioritize dd-MM-yyyy format first since it's the most common UI format
    List<String> dateFormats = [
      'dd-MM-yyyy',
      'd-M-yyyy',
      'yyyy-MM-dd',
      'yyyy-M-d',
      'MM/dd/yyyy',
      'M/d/yyyy',
      'MM-dd-yyyy',
      'M-d-yyyy',
      'dd/MM/yyyy',
      'd/M/yyyy',
      // Month-name format ("2026-Jul-29"). DateProvider sets this whenever the
      // admin picks YYYY-MMM-DD; without it the parse fell through and this
      // function returned "", sending an empty date to the API. Appended last
      // so it can only catch inputs every earlier pattern already rejected.
      'yyyy-MMM-dd',
      'yyyy-MMM-d',
    ];

    DateTime? parsedDate;

    // Try to parse the date using different formats
    for (String format in dateFormats) {
      try {
        parsedDate = DateFormat(format).parse(cleanDate);
        break;
      } catch (e) {
        logError("Failed to parse with format $format: $e");
        continue;
      }
    }

    // If parsing failed, try manual parsing for common formats
    if (parsedDate == null) {
      if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(cleanDate)) {
        // yyyy-MM-dd format
        List<String> parts = cleanDate.split('-');
        if (parts.length == 3) {
          int year = int.tryParse(parts[0]) ?? 0;
          int month = int.tryParse(parts[1]) ?? 0;
          int day = int.tryParse(parts[2]) ?? 0;
          if (year > 0 && month > 0 && month <= 12 && day > 0 && day <= 31) {
            parsedDate = DateTime(year, month, day);
          }
        }
      } else if (RegExp(r'^\d{2}-\d{2}-\d{4}$').hasMatch(cleanDate)) {
        // dd-MM-yyyy format
        List<String> parts = cleanDate.split('-');
        if (parts.length == 3) {
          int day = int.tryParse(parts[0]) ?? 0;
          int month = int.tryParse(parts[1]) ?? 0;
          int year = int.tryParse(parts[2]) ?? 0;
          if (year > 0 && month > 0 && month <= 12 && day > 0 && day <= 31) {
            parsedDate = DateTime(year, month, day);
          }
        }
      }
    }

    if (parsedDate == null) {
      return ""; // Return empty string if parsing fails
    }

    // Return the formatted date in 'yyyy-MM-dd' format for API
    String result = DateFormat('yyyy-MM-dd').format(parsedDate);
    return result;
  } catch (e) {
    logError("Error while formatting date: $e");
    return ""; // Return an empty string if there is an error
  }
}

/// Shared insurance date-range rule (web parity): the expiration date must be
/// strictly AFTER the effective date — equal dates are an error.
/// Returns an error message when the range is invalid, or null when valid.
/// Callers show the returned message themselves (toast/snackbar).
String? validateInsuranceDateRange(DateTime? effective, DateTime? expiration) {
  if (effective == null || expiration == null) {
    return "Please select both Effective Date and Expiration Date";
  }
  if (expiration.isBefore(effective) ||
      expiration.isAtSameMomentAs(effective)) {
    return "Expiration Date must be after Effective Date";
  }
  return null;
}

Color blueColor = Color.fromRGBO(21, 43, 81, 1);
Color blueColorDisabled = blueColor.withOpacity(0.6);
//Color blueColor = Color.fromRGBO(21, 43, 70, .5);

Color greyColor = Color.fromRGBO(73, 81, 96, 1);
Color grey = Color.fromRGBO(21, 43, 83, .5);

// ===== Unified mobile palette (Work Order + shared screens) =====
const Color navyClr = Color(0xFF1C2D4E); // primary navy
const Color navyHoverClr = Color(0xFF16243F); // pressed/hover
const Color tintBg = Color(0xFFEEF2F8); // card header / alt row
const Color tint2 = Color(0xFFE1E9F4); // nested sub-cards
const Color pageBg = Color(0xFFF4F6F9); // app background
const Color borderClr = Color(0xFFE4E8EF); // outer card border
const Color innerBdClr = Color(0xFFD8DDE6); // inner divider
const Color outlineClr = Color(0xFFD3DAE5); // outlined button border
const Color checkOffClr = Color(0xFFB6BFCD); // unchecked checkbox border
const Color mutedClr = Color(0xFF6B7A90); // secondary text / labels
const Color subjectClr = Color(0xFF5A86B8); // subject / unit accent
const Color greenClr = Color(0xFF1F9D55); // success / New / Completed
const Color greenBg = Color(0xFFDCFCE7); // green pill bgR
const Color orangeClr = Color(0xFFD97706); // in-progress / charge
const Color orangeBg = Color(0xFFFEF3C7); // orange pill bg
const Color statusBlue = Color(0xFF2868A0); // New status / view icon
const Color statusBlueBg = Color(0xFFE8F0FA); // view button bg
const Color closedClr = Color(0xFF6B7A90); // closed status
const Color redClr = Color(0xFFDC3545); // delete / error
const Color redDotClr = Color(0xFFE62E2E); // notification dot
TableRow buildTableRow(
    String leftLabel, String leftValue, String rightLabel, String rightValue) {
  return TableRow(
    children: [
      TableCell(
        child: Padding(
          padding: EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                leftLabel,
                style: TextStyle(fontWeight: FontWeight.bold, color: blueColor),
              ),
              SizedBox(height: 4.0), // Space between label and value
              Text(
                leftValue,
                style: TextStyle(color: grey),
              ),
            ],
          ),
        ),
      ),
      TableCell(
        child: Padding(
          padding: EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                rightLabel,
                style: TextStyle(fontWeight: FontWeight.bold, color: blueColor),
              ),
              SizedBox(height: 4.0), // Space between label and value
              Text(
                rightValue,
                style: TextStyle(color: grey),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

String getDisplayValue(String? value) {
  // Return 'N/A' if the value is null or empty, otherwise return the value
  return (value == null || value.trim().isEmpty) ? 'N/A' : value;
}

// Payments may already be processed server-side when the connection drops,
// so the message must not claim a definitive failure.
const String paymentNetworkErrorMessage =
    'Payment status unknown — the connection was lost. Please check the ledger before trying again.';

const String networkErrorMessage =
    'No internet connection. Please check your network and try again.';

const String paymentUnknownOutcomeMessage =
    'Payment status unknown — the server did not confirm the result. Please check the ledger before trying again.';

const List<String> _networkErrorMarkers = [
  'socketexception',
  'clientexception',
  'handshakeexception',
  'httpexception',
  'certificateexception',
  'tlsexception',
  'timeoutexception',
  'connection abort',
  'failed host lookup',
  'connection refused',
  'connection reset',
  'connection closed',
  'network is unreachable',
  'connection timed out',
  'no address associated with hostname',
];

// True when the error is a transport-level failure, meaning the request's
// outcome on the server is unknown (it may still have been processed).
bool isNetworkError(Object? error) {
  final lower = (error?.toString() ?? '').toLowerCase();
  return _networkErrorMarkers.any(lower.contains);
}

// Server-side failures that also leave the outcome undecided: a gateway/proxy
// error may hide a completed payment, and a 409 means the first attempt is
// still running. An idempotency key must be kept across these.
const List<String> _outcomeUnknownMarkers = [
  'currently being processed',
  'status unknown',
  'bad gateway',
  'gateway timeout',
  'service unavailable',
];

bool isOutcomeUnknown(Object? error) {
  if (isNetworkError(error)) return true;
  final lower = (error?.toString() ?? '').toLowerCase();
  return _outcomeUnknownMarkers.any(lower.contains);
}

String newIdempotencyKey() => const Uuid().v4();

/// Title for the dialog shown when a payment attempt throws.
///
/// When the outcome is unknown — the connection dropped mid-request — the
/// payment may well have completed server-side, so the title must not assert
/// failure. Saying "Failed" there is what makes users retry and double-pay.
String paymentAlertTitle(Object? error) =>
    isOutcomeUnknown(error) ? 'Payment Status Unknown' : 'Payment Failed!';

// Anything that would expose internals rather than inform the user: a URI or
// hostname, a parser/programming-error dump, or an absent server message.
const List<String> _unsafeMessageMarkers = [
  'uri=',
  'http://',
  'https://',
  'hostname',
  'os error',
  'errno',
  'formatexception',
  'at character',
  '<html',
  'is not a subtype of',
  'nosuchmethoderror',
  'rangeerror',
  'argumenterror',
  'stateerror',
  'typeerror',
];

String friendlyErrorMessage(
  Object? error, {
  String networkMessage = networkErrorMessage,
  String fallbackMessage = 'Something went wrong. Please try again.',
}) {
  final raw = error?.toString() ?? '';
  if (isNetworkError(raw)) return networkMessage;
  // Dart Errors are programming faults, never user-facing information.
  if (error is Error) return fallbackMessage;
  var message = raw;
  if (message.contains('Exception:')) {
    message = message.split('Exception:').last;
  }
  message = message.trim();
  final lower = message.toLowerCase();
  if (message.isEmpty ||
      lower == 'null' ||
      _unsafeMessageMarkers.any(lower.contains)) {
    return fallbackMessage;
  }
  return message;
}

// Common currency formatting function for US-centric format
String formatCurrency(double? amount) {
  if (amount == null) return '\$0.00';

  final formatter = NumberFormat.currency(
    locale: 'en_US',
    symbol: '\$',
    decimalDigits: 2,
  );

  return formatter.format(amount);
}

/// Display formatter for any money value, wherever it comes from.
///
/// Accepts a number, a numeric string, or an already-decorated string such as
/// "\$1,200.50", and always returns grouped en-US currency — "\$1,200.50",
/// "-\$45.00", and "\$0.00" for null/unparsable input. Mirrors the web app's
/// `formatUSD` helper (TenantDashBoard.jsx), which coerces the same shapes so a
/// figure can never surface as a bare number.
///
/// Use for every on-screen amount; API payloads keep their raw values.
/// Round to whole cents, half-up — web parity with `roundCurrency` in
/// plugins/helpers.jsx (`Math.round((n + Number.EPSILON) * 100) / 100`).
///
/// Payment screens must round a surcharge ONCE with this and build every
/// other figure (displayed total, payload) from that rounded value. Rounding
/// the raw surcharge into the total separately is what made the on-screen
/// Total disagree with the charged amount by a cent on half-cent fees.
double roundCurrency(num value) {
  final double v = value.toDouble();
  if (!v.isFinite) return 0;
  return ((v + 2.220446049250313e-16) * 100).round() / 100;
}

/// True for the payment methods that record money ALREADY RECEIVED.
///
/// Web parity — `AddPayment.jsx` (CRM-4270) splits the methods into the same
/// two groups: "A manual payment records money already received — it can't be
/// dated in the future." Card/ACH is the mirror image: it collects money later,
/// so it may be scheduled forward but not back-dated.
///
/// Matching is whitespace- and case-tolerant on purpose: legacy records hold
/// "Cashier 's Check" with a stray space (the same quirk Edit Payment already
/// works around), and Admin/Staff swap in "ACH (not available)" when ACH is
/// switched off — that variant must stay in the card/ACH group, not fall into
/// this one.
bool isManualPaymentMethod(String? method) {
  if (method == null) return false;
  final normalized = method
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(" 's", "'s")
      .trim()
      .toLowerCase();
  return const {
    'cash',
    'check',
    'manual',
    'money order',
    "cashier's check",
  }.contains(normalized);
}

DateTime _todayDateOnly() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

/// Earliest date selectable for a payment, per [isManualPaymentMethod].
/// Manual methods may be back-dated (a cheque received last week must carry
/// last week's date); card/ACH may not.
DateTime paymentFirstSelectableDate(String? method) =>
    isManualPaymentMethod(method) ? DateTime(2000) : _todayDateOnly();

/// Latest date selectable for a payment. Manual methods cannot be dated in the
/// future (the server rejects it); card/ACH can, which is how a scheduled
/// payment is created.
DateTime paymentLastSelectableDate(String? method) =>
    isManualPaymentMethod(method) ? _todayDateOnly() : DateTime(2101);

String formatMoney(dynamic amount) {
  if (amount is num) return formatCurrency(amount.toDouble());
  final cleaned = amount?.toString().replaceAll(RegExp(r'[^0-9.-]'), '') ?? '';
  return formatCurrency(double.tryParse(cleaned) ?? 0.0);
}

/// Accounting-style variant of [formatMoney] — a negative renders in
/// parentheses ("(\$110.00)") instead of with a minus sign ("-\$110.00").
///
/// Mirrors the web app's shared `currencyFormatter` (plugins/helpers.jsx),
/// which is built with `currencySign: "accounting"`. Web uses it for every
/// money cell in a table, list or export, so use this wherever a figure sits
/// in a column.
///
/// The two balance *badges* — Tenant Summary and the lease Financial tab —
/// deliberately append the word "Credit" on top of this shape
/// ("(\$110.00) Credit"), matching web's LeaseBalanceDisplay.jsx and
/// TenantDetailPage.jsx. Tables never carry that word.
String formatMoneyAccounting(dynamic amount) {
  if (_isZeroMoney(amount)) return formatCurrency(0);
  final formatted = formatMoney(amount);
  return formatted.startsWith('-') ? '(${formatted.substring(1)})' : formatted;
}

/// Numeric value behind any of the shapes [formatMoney] accepts.
double _moneyValue(dynamic amount) {
  if (amount is num) return amount.toDouble();
  final cleaned = amount?.toString().replaceAll(RegExp(r'[^0-9.-]'), '') ?? '';
  return double.tryParse(cleaned) ?? 0.0;
}

/// True when a value is zero for display purposes.
///
/// Web applies the same guard before its accounting formatter
/// (`Math.abs(value) < 1e-10`, RentRoll.jsx). A ledger balance is a running
/// sum of charges and payments, so a settled row often lands on negative zero
/// or a speck of floating-point dust — which the accounting shape would
/// otherwise render as "(\$0.00)". Zero is neither a debit nor a credit and
/// must always read "\$0.00".
bool _isZeroMoney(dynamic amount) => _moneyValue(amount).abs() < 1e-10;

/// Accounting shape for a figure whose credit-ness is decided by its row type
/// rather than carried in the value itself — a ledger Amount column, where a
/// payment entry reduces the balance and so reads as a credit even though the
/// stored amount is positive.
///
/// Always renders the magnitude, parenthesised when [isCredit].
String formatMoneyAccountingCredit(dynamic amount, {required bool isCredit}) {
  if (_isZeroMoney(amount)) return formatCurrency(0);
  final formatted = formatMoney(amount);
  final magnitude =
      formatted.startsWith('-') ? formatted.substring(1) : formatted;
  return isCredit ? '($magnitude)' : magnitude;
}

/// Whole-dollar variant of [formatMoney] — grouped thousands, no cents
/// ("\$250,000"). Use only where the design deliberately omits cents, such as a
/// purchase price, an insured value or an estimated valuation.
String formatMoneyWhole(dynamic amount) {
  final value = amount is num
      ? amount.toDouble()
      : double.tryParse(
              amount?.toString().replaceAll(RegExp(r'[^0-9.-]'), '') ?? '') ??
          0.0;
  return NumberFormat.currency(
    locale: 'en_US',
    symbol: '\$',
    decimalDigits: 0,
  ).format(value);
}
//Color grey = Color.fromRGBO(21, 43, 83, .5);
//Color grey = Color.fromRGBO(21, 43, 83, .5);

String formatPhoneNumber(String phoneNumber) {
  if (phoneNumber == null || phoneNumber.isEmpty) {
    return "N/A"; // Return "N/A" if the phone number is null or empty
  }
  // Remove any non-digit characters
  final digitsOnly = phoneNumber.replaceAll(RegExp(r'\D'), '');

  // Check if the number has the right length (10 digits for US phone numbers)
  if (digitsOnly.length == 10) {
    return '(${digitsOnly.substring(0, 3)}) ${digitsOnly.substring(3, 6)}-${digitsOnly.substring(6)}';
  } else {
    return phoneNumber; // Return original if not valid
  }
}

/// Display label for a stored vendor trade value, mirroring web's
/// `getTradeLabel` / `TRADE_OPTIONS` (`Client/src/views/source/AddVendor.jsx`).
/// Trades are stored lowercase on both platforms, so capitalising the first
/// letter rendered "hvac" as "Hvac" instead of "HVAC". Falls back to the raw
/// value, exactly like web, so an unknown trade still shows something.
const Map<String, String> kVendorTradeLabels = {
  'general': 'General',
  'drywall': 'Drywall',
  'electrical': 'Electrical',
  'hvac': 'HVAC',
  'landscaping': 'Landscaping',
  'painting': 'Painting',
  'plumbing': 'Plumbing',
  'roofing': 'Roofing',
};

String vendorTradeLabel(String? value) {
  final String raw = (value ?? '').trim();
  if (raw.isEmpty) return '';
  return kVendorTradeLabels[raw.toLowerCase()] ?? raw;
}

String formatPhoneNumberedit(String phoneNumber) {
  if (phoneNumber == null || phoneNumber.isEmpty) {
    return ""; // Return "N/A" if the phone number is null or empty
  }
  // Remove any non-digit characters
  final digitsOnly = phoneNumber.replaceAll(RegExp(r'\D'), '');

  // Check if the number has the right length (10 digits for US phone numbers)
  if (digitsOnly.length == 10) {
    return '(${digitsOnly.substring(0, 3)}) ${digitsOnly.substring(3, 6)}-${digitsOnly.substring(6)}';
  } else {
    return phoneNumber; // Return original if not valid
  }
}

/// Digits-only form of a phone number, mirroring web's `phoneNorm`
/// (`Client/src/views/source/Profile.jsx`). Use it for the value sent to the
/// API and for change-detection, so a display-formatted "(555) 123-4567" is
/// never mistaken for a different number than the stored "5551234567".
String phoneDigitsOnly(String? phoneNumber) =>
    (phoneNumber ?? '').replaceAll(RegExp(r'\D'), '');

/// True only when the API host actually resolves right now.
///
/// `connectivity_plus` answers from a cached reachability result, which can
/// still report `none` after the network is back (reliably reproducible on the
/// iOS simulator) — so a screen gated on it stays stuck on the offline view
/// even though requests succeed. Equally, trusting the opposite and assuming
/// we are online would reveal stale already-loaded data while genuinely
/// offline. A real DNS lookup settles it either way.
/// In-flight probe, shared by every caller that asks while it is running.
///
/// 122 call sites still reach this from the legacy per-screen `checkInternet()`
/// and its connectivity listener. Opening the app offline fired TWENTY-FIVE
/// separate probes — one per screen that mounted — each holding a 10-second
/// timeout, all asking the identical question and all already answered by the
/// first. The verdict is the same for every caller in that instant, so they
/// share one request instead of each making their own.
Future<bool>? _probeInFlight;

/// The last verdict, and when it was reached. Kept for one second only: long
/// enough to absorb a burst of screens mounting together, short enough that a
/// human tapping Retry always gets a fresh answer rather than a stale "still
/// offline" from a moment ago.
bool? _lastProbe;
DateTime? _lastProbeAt;

Future<bool> hasNetworkNow() async {
  if (Api_url.isEmpty) return false;
  final last = _lastProbeAt;
  if (_lastProbe != null &&
      last != null &&
      DateTime.now().difference(last) < const Duration(seconds: 1)) {
    return _lastProbe!;
  }
  final running = _probeInFlight;
  if (running != null) return running;
  final future = _probeNetwork();
  _probeInFlight = future;
  try {
    return await future;
  } finally {
    _probeInFlight = null;
  }
}

Future<bool> _probeNetwork() async {
  final result = await _probeNetworkOnce();
  _lastProbe = result;
  _lastProbeAt = DateTime.now();
  return result;
}

Future<bool> _probeNetworkOnce() async {
  if (Api_url.isEmpty) return false;
  // Probes over HTTP, deliberately — NOT InternetAddress.lookup. A raw DNS
  // lookup takes a different path from the app's own requests and is
  // unreliable inside the iOS sandbox: the app was reaching the API fine
  // (status 200) while the lookup kept failing, so the whole app was declared
  // offline on a perfectly good connection. Asking over the same transport
  // the app actually uses is the only answer that means anything.
  //
  // ANY reply counts as online — 401, 404, 500 included. We are testing
  // whether the network carries a request, not whether the endpoint is happy.
  // The path matters: probing the bare origin failed inside the app (raw
  // HttpClient, empty path) while the app's own package:http requests to
  // /api/... succeeded on the same network. Use the SAME client library and
  // the same kind of URL the app's real traffic uses, so the probe's verdict
  // and the app's actual reachability cannot disagree.
  final uri = Uri.parse('$Api_url/api/auth');
  // ONE attempt, with a timeout generous enough for a slow server. Staging has
  // been measured answering a bare request in over six seconds, so a tight
  // budget here reports "offline" on a working connection — the very failure
  // this probe exists to prevent. Tolerance for a single blip belongs in
  // CheckConnection, which already requires two consecutive failures before
  // it will block the app. ANY HTTP status counts as online — 401/404/500
  // included — because this tests whether the network carries a request, not
  // whether the endpoint is happy.
  try {
    await http.head(uri).timeout(const Duration(seconds: 10));
    return true;
  } catch (e) {
    debugPrint('NETPROBE-ERR: $e');
    return false;
  }
}

/// Web parity (`plugins/helpers.jsx: makeRentalAddress`): the lease Property
/// Details card shows the address alone unless the unit is a real, distinct
/// value. Ported verbatim so mobile stops showing "215 -  " (empty/blank
/// unit) or "1321 Creek St  -  1321 Creek St" (unit duplicates the address —
/// a data quirk on non-multi-unit properties) instead of just the address.
String formatLeasePropertyLine(String? rentalAddress, String? rentalUnit) {
  final address = rentalAddress ?? "";
  if (address.isEmpty) return "";
  final unit = rentalUnit?.trim() ?? "";
  if (unit.isEmpty || unit == "-" || unit == "null" || unit == "undefined") {
    return address;
  }
  if (unit.contains(address)) return unit;
  return "$address - $unit";
}

/// Empty-state row for a table whose visible page has no records — normally
/// because a search or filter matched nothing. The screens' own "No Data
/// Available" branch only tests the list the server returned, so it never fires
/// for a narrowed-down result; without this the table area just renders blank.
/// Mirrors that branch's presentation so both empty states look the same.
Widget kNoSearchResults(BuildContext context) {
  return Container(
    height: MediaQuery.of(context).size.height * .35,
    alignment: Alignment.center,
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Image.asset(
          "assets/images/no_data.jpg",
          height: 160,
          width: 160,
        ),
        const SizedBox(height: 10),
        Text(
          // CRM-4365: this widget is the SEARCH/FILTER empty state — the name
          // says so — but it rendered the same "No Data Available" as a
          // genuinely empty list. A user who had filtered to nothing was told
          // their records were gone. Distinct wording, plus a hint at the
          // action that clears it.
          "No Results Found",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: blueColor,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          "Try adjusting your search or filters.",
          textAlign: TextAlign.center,
          style: TextStyle(
            color: blueColor.withOpacity(0.6),
            fontSize: 13,
          ),
        ),
      ],
    ),
  );
}

/// Full state names for address dropdowns. Same 50 entries, same order, as
/// web's `US_STATES_LIST` (Client/src/utils/usStates.js) — web stores the full
/// name as the field value, so these strings are what the API receives.
const List<String> kUsStateNames = [
  'Alabama',
  'Alaska',
  'Arizona',
  'Arkansas',
  'California',
  'Colorado',
  'Connecticut',
  'Delaware',
  'Florida',
  'Georgia',
  'Hawaii',
  'Idaho',
  'Illinois',
  'Indiana',
  'Iowa',
  'Kansas',
  'Kentucky',
  'Louisiana',
  'Maine',
  'Maryland',
  'Massachusetts',
  'Michigan',
  'Minnesota',
  'Mississippi',
  'Missouri',
  'Montana',
  'Nebraska',
  'Nevada',
  'New Hampshire',
  'New Jersey',
  'New Mexico',
  'New York',
  'North Carolina',
  'North Dakota',
  'Ohio',
  'Oklahoma',
  'Oregon',
  'Pennsylvania',
  'Rhode Island',
  'South Carolina',
  'South Dakota',
  'Tennessee',
  'Texas',
  'Utah',
  'Vermont',
  'Virginia',
  'Washington',
  'West Virginia',
  'Wisconsin',
  'Wyoming',
];

/// ISO code -> full state name, matching web's `US_STATES_LIST`.
const Map<String, String> kUsStateIsoToName = {
  'AL': 'Alabama',
  'AK': 'Alaska',
  'AZ': 'Arizona',
  'AR': 'Arkansas',
  'CA': 'California',
  'CO': 'Colorado',
  'CT': 'Connecticut',
  'DE': 'Delaware',
  'FL': 'Florida',
  'GA': 'Georgia',
  'HI': 'Hawaii',
  'ID': 'Idaho',
  'IL': 'Illinois',
  'IN': 'Indiana',
  'IA': 'Iowa',
  'KS': 'Kansas',
  'KY': 'Kentucky',
  'LA': 'Louisiana',
  'ME': 'Maine',
  'MD': 'Maryland',
  'MA': 'Massachusetts',
  'MI': 'Michigan',
  'MN': 'Minnesota',
  'MS': 'Mississippi',
  'MO': 'Missouri',
  'MT': 'Montana',
  'NE': 'Nebraska',
  'NV': 'Nevada',
  'NH': 'New Hampshire',
  'NJ': 'New Jersey',
  'NM': 'New Mexico',
  'NY': 'New York',
  'NC': 'North Carolina',
  'ND': 'North Dakota',
  'OH': 'Ohio',
  'OK': 'Oklahoma',
  'OR': 'Oregon',
  'PA': 'Pennsylvania',
  'RI': 'Rhode Island',
  'SC': 'South Carolina',
  'SD': 'South Dakota',
  'TN': 'Tennessee',
  'TX': 'Texas',
  'UT': 'Utah',
  'VT': 'Vermont',
  'VA': 'Virginia',
  'WA': 'Washington',
  'WV': 'West Virginia',
  'WI': 'Wisconsin',
  'WY': 'Wyoming',
};

/// Canonical dropdown label for a stored state value, mirroring web's
/// `getStateLabelByIsoCode`: an ISO code ("CA") becomes the full name
/// ("California") so the saved value matches a dropdown option. A value that is
/// already a full name is matched case-insensitively; anything unrecognised is
/// returned unchanged (web does the same rather than discarding it).
String canonicalUsStateName(String? stored) {
  final raw = (stored ?? '').trim();
  if (raw.isEmpty) return '';
  final byIso = kUsStateIsoToName[raw.toUpperCase()];
  if (byIso != null) return byIso;
  for (final name in kUsStateNames) {
    if (name.toLowerCase() == raw.toLowerCase()) return name;
  }
  return raw;
}

// void _checkPasswordStrength(String password) {
//   final result = Zxcvbn().evaluate(password);
//   setState(() {
//     // Safely convert the score to an int, defaulting to 0 if null
//     _score = result.score?.toInt() ?? 0;
//     // Provide a default feedback message if the warning is null
//     _feedback = (result.feedback.warning!.isNotEmpty ? result.feedback.warning : 'Password is strong!')!;
//   });
// }
// bool _validatePassword(String password) {
//   if (password.length < 8 || password.length > 16) {
//     _errorMessage = 'Password must be between 8 and 16 characters.';
//     return false;
//   }
//   if (!RegExp(r'[A-Z]').hasMatch(password)) {
//     _errorMessage = 'Must contain at least one uppercase letter.';
//     return false;
//   }
//   if (!RegExp(r'[a-z]').hasMatch(password)) {
//     _errorMessage = 'Must contain at least one lowercase letter.';
//     return false;
//   }
//   if (!RegExp(r'[0-9]').hasMatch(password)) {
//     _errorMessage = 'Must contain at least one digit.';
//     return false;
//   }
//   if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) {
//     _errorMessage = 'Must contain at least one special character.';
//     return false;
//   }
//   var result = Zxcvbn().evaluate(password);
//   print(result.score);
//   if (result.score! < 3) {
//     _errorMessage = 'Password is too weak.';
//     return false;
//   }
//   if (RegExp(r'(\d)\1{2,}|\d{3,}|[A-Za-z]{3,}').hasMatch(password)) {
//     _errorMessage = 'Avoid sequential or repeating patterns.';
//     return false;
//   }
//   _errorMessage = null; // Reset error message if all checks pass
//   return true;
// }

String? ValidatePassword(String password) {
  if (password.length < 8) {
    return 'Password must be at least 8 characters.';
  }
  if (!RegExp(r'[A-Z]').hasMatch(password)) {
    return 'Must contain at least one uppercase letter.';
  }
  if (!RegExp(r'[a-z]').hasMatch(password)) {
    return 'Must contain at least one lowercase letter.';
  }
  if (!RegExp(r'[0-9]').hasMatch(password)) {
    return 'Must contain at least one digit.';
  }
  if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) {
    return 'Must contain at least one special character.';
  }

  // Avoid sequential or repeating patterns
  // if (RegExp(r'(\d)\1{2,}|[A-Za-z]{4,}|\d{4,}').hasMatch(password)) {
  //   return 'Avoid sequential or excessive repeating patterns.';
  // }

  // Simulated strength check: length-based and diversity
  if (password.length < 12) {
    return 'Password is too weak. Use a longer password.';
  }

  return null; // Indicate the password is valid
}

String generateRandomPassword() {
  const String upperCaseLetters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  const String lowerCaseLetters = 'abcdefghijklmnopqrstuvwxyz';
  const String digits = '0123456789';
  const String specialCharacters = '!@#\$%^&*(),.?":{}|<>';
  const String allCharacters =
      '$upperCaseLetters$lowerCaseLetters$digits$specialCharacters';

  // Ensure at least one of each required character type
  List<String> passwordChars = [];
  passwordChars
      .add(upperCaseLetters[Random().nextInt(upperCaseLetters.length)]);
  passwordChars
      .add(lowerCaseLetters[Random().nextInt(lowerCaseLetters.length)]);
  passwordChars.add(digits[Random().nextInt(digits.length)]);
  passwordChars
      .add(specialCharacters[Random().nextInt(specialCharacters.length)]);

  // Fill the rest of the password with random characters
  int remainingLength = Random().nextInt(5) + 8; // Ensure total length is 12-16
  for (int i = 0; i < remainingLength; i++) {
    passwordChars.add(allCharacters[Random().nextInt(allCharacters.length)]);
  }

  // Shuffle to ensure randomness
  passwordChars.shuffle();

  // Join characters into a password string
  String password = passwordChars.join('');

  // Ensure no sequential or repeating patterns
  if (RegExp(r'(\d)\1{2,}|[A-Za-z]{4,}|\d{4,}').hasMatch(password)) {
    return generateRandomPassword(); // Retry if invalid pattern is found
  }

  return password;
}

class PhoneNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    // Remove any non-digit characters
    final digitsOnly = newValue.text.replaceAll(RegExp(r'\D'), '');

    // Check if the number has the right length (10 digits for US phone numbers)
    if (digitsOnly.length > 10) {
      return oldValue; // Return old value if the new input exceeds 10 digits
    }

    String formatted = '';
    if (digitsOnly.length >= 1) {
      formatted +=
          '(${digitsOnly.substring(0, digitsOnly.length >= 3 ? 3 : digitsOnly.length)}';
    }
    if (digitsOnly.length >= 4) {
      formatted +=
          ') ${digitsOnly.substring(3, digitsOnly.length >= 6 ? 6 : digitsOnly.length)}';
    }
    if (digitsOnly.length >= 7) {
      formatted += '-${digitsOnly.substring(6)}';
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class CVVFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    // Allow only digits
    final digitsOnly = newValue.text.replaceAll(RegExp(r'\D'), '');

    // Restrict to 3 digits maximum
    if (digitsOnly.length > 3) {
      return oldValue;
    }

    return TextEditingValue(
      text: digitsOnly,
      selection: TextSelection.collapsed(offset: digitsOnly.length),
    );
  }
}

/// Restricts input to a 0–100 percentage. Web parity for the Debit Card Fee
/// Override field: mirrors the web onChange gate — accepts only an empty value,
/// or digits with a single optional decimal point whose numeric value is
/// between 0 and 100 (inclusive). Any keystroke that would fall outside that
/// range (or isn't numeric) is rejected, so out-of-range values can't be typed.
/// Digits with at most one decimal point, no upper bound.
///
/// For money amounts (e.g. the ACH flat fee) where
/// [PercentRangeFormatter]'s 0-100 cap does not apply. A raw
/// `FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))` filters per
/// character, so it lets "1..5" through and the value then fails to parse.
class DecimalAmountFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text;
    if (text.isEmpty) return newValue;
    if (!RegExp(r'^\d*\.?\d*$').hasMatch(text)) return oldValue;
    if (double.tryParse(text) == null) return oldValue;
    return newValue;
  }
}

class PercentRangeFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text;
    // Allow clearing the field.
    if (text.isEmpty) return newValue;
    // Only digits with at most one decimal point (web regex: /^\d*\.?\d*$/).
    if (!RegExp(r'^\d*\.?\d*$').hasMatch(text)) return oldValue;
    // Reject values that don't parse (e.g. a lone ".") — matches web parseFloat.
    final parsed = double.tryParse(text);
    if (parsed == null) return oldValue;
    // Range 0–100 inclusive (web: parseFloat(value) >= 0 && <= 100).
    if (parsed < 0 || parsed > 100) return oldValue;
    return newValue;
  }
}

String? ValidateExpirationDate(String expirationDate) {
  // Check if the date is in the correct MM/YYYY format
  //require formate first is 0-9 and second 0-2
  final regex = RegExp(r'^(0[1-9]|1[0-9])\/\d{4}$');
  if (!regex.hasMatch(expirationDate)) {
    return 'Expiration date must be in the format MM/YYYY.';
  }

  // Split the date into month and year
  final parts = expirationDate.split('/');
  final month = int.parse(parts[0]);
  final year = int.parse(parts[1]);

  // Validate that the month is between 01 and 12
  if (month < 1 || month > 12) {
    return 'Month must be between 01 and 12.';
  }

  // Get the current date and the expiration date
  final currentDate = DateTime.now();
  final expirationDateTime = DateTime(year, month);

  // Check if the expiration date is in the past
  if (expirationDateTime.isBefore(currentDate)) {
    return 'Expiration date cannot be in the past.';
  }

  // Check if the expiration date is too far in the future (e.g., 10 years from now)
  final maxDate = currentDate.add(Duration(days: 365 * 10)); // 10 years
  if (expirationDateTime.isAfter(maxDate)) {
    return 'Expiration date cannot be more than 10 years in the future.';
  }

  // Ensure the expiration year is not before the current year
  final minYear = currentDate.year;
  if (year < minYear) {
    return 'Expiration year must be greater than or equal to the current year.';
  }

  return null; // Indicate the expiration date is valid
}

class VideoItem extends StatefulWidget {
  String url;
  final void Function()? onTap;
  VideoItem({super.key, required this.url, this.onTap});

  @override
  State<VideoItem> createState() => _VideoItemState();
}

class _VideoItemState extends State<VideoItem> {
  VideoPlayerController? _controller;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.network("${widget.url}")
      ..initialize().then((_) {
        setState(() {}); //when your thumbnail will show.
      });
  }

  // @override
  // void dispose() {
  //   super.dispose();
  //   _controller!.dispose();
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Container(
          child: _controller!.value!.isInitialized
              ? Container(
                  width: 100.0,
                  height: 56.0,
                  child: VideoPlayer(_controller!),
                )
              : CircularProgressIndicator(),
        ),
      ),
    );
  }
}

class CustomTableView extends StatelessWidget {
  final List<String> titles;
  final List<List<String>> data;
  final bool isHeader;
  final Map<int, TableColumnWidth> columnWidths;
  final String description;
  final bool showDescription; // Boolean to control visibility

  CustomTableView({
    required this.titles,
    required this.data,
    required this.isHeader,
    required this.columnWidths,
    required this.description,
    this.showDescription = false, // Default to false
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Table(
          columnWidths: columnWidths,
          children: [
            if (isHeader)
              TableRow(
                decoration: BoxDecoration(color: Color.fromRGBO(21, 43, 83, 1)),
                children: titles
                    .map((item) => Padding(
                          padding:
                              EdgeInsets.symmetric(vertical: 9, horizontal: 1),
                          child: Text(
                            item,
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                          ),
                        ))
                    .toList(),
              ),
            ...data.asMap().entries.map(
              (entry) {
                int index = entry.key;
                List<String> row = entry.value;
                return TableRow(
                  decoration: BoxDecoration(
                    color: index.isEven
                        ? Colors.grey[300] // Light grey for even rows
                        : Colors.white, // White for odd rows
                  ),
                  children: row
                      .map(
                        (cell) => Padding(
                          padding:
                              EdgeInsets.symmetric(vertical: 7, horizontal: 6),
                          child: Text(
                            cell,
                            style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ],
        ),
        if (showDescription) // Show description only if true
          Padding(
            padding: const EdgeInsets.only(top: 8.0, left: 8, bottom: 5),
            child: Text(
              description,
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// User-facing error text (CRM-4661 and the stale-notification follow-up).
//
// Raw exceptions must never reach the screen: they leak hostnames, URIs,
// exception class names, OS errno values and whole JSON response bodies.
// ─────────────────────────────────────────────────────────────────────────────

const String kGenericErrorMessage = 'Something went wrong. Please try again.';
const String kWorkOrderNotFoundMessage =
    'This work order could not be found. It may have been deleted.';

/// Message to throw when a work-order fetch fails.
///
/// The backend answers a missing work order with `statusCode: 201` and
/// `message: "Work Order Not Found"` — 201 means "Created", so the HTTP status
/// cannot be used to detect it. The not-found case is recognised from the
/// response body instead, and the body itself is never surfaced.
String workOrderFetchErrorMessage(String responseBody) {
  final String body = responseBody.toLowerCase();
  if (body.contains('not found') || body.contains('notfound')) {
    return kWorkOrderNotFoundMessage;
  }
  return kGenericErrorMessage;
}

/// Shapes the body of `PUT /api/work-order/work-order/{id}` the way the server
/// actually reads it.
///
/// `notificationTime` has to sit at the ROOT of the body, as a sibling of
/// `workOrder`. The route pulls it from `req.body.notificationTime`
/// (Server/routes/api/superadmin/WorkOrder.js:695) and spends it on three
/// things: the work order's `updatedAt`, the pushed history entry's
/// `updatedAt`, and the notification row's `createdAt`/`updatedAt` (:938).
///
/// Nested inside `workOrder` it arrives `undefined`. The work order's
/// `updatedAt` then never advances, and because Notification's `createdAt` is
/// a plain String with no default (modals/superadmin/Notification.js:27) the
/// row is written without one — it sinks to the bottom of every bell feed,
/// which sorts `{ createdAt: -1 }`.
///
/// Mirrors the web clients, which all send it as a sibling:
/// WorkOrderDetails.js:668, VendorAddWork.js:739, Tworkorderdetail.js:224.
/// Callers may leave it in the map; it is lifted out here.
Map<String, dynamic> workOrderUpdateBody(Map<String, dynamic> workorder) {
  final Map<String, dynamic> payload = Map<String, dynamic>.from(workorder);
  final Object? supplied = payload.remove('notificationTime');
  return <String, dynamic>{
    'workOrder': payload,
    'notificationTime': (supplied is String && supplied.trim().isNotEmpty)
        ? supplied
        : DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
  };
}

/// Decodes a work-order GET response and returns its `data` object, or throws
/// an [Exception] carrying a user-safe message.
///
/// Replaces the one-liner
/// `final Map<String, dynamic> data = jsonDecode(response.body)["data"];`
/// which left two steps unguarded: `jsonDecode` on a non-JSON body (a proxy or
/// gateway page served with HTTP 200) threw a FormatException, and a 200 whose
/// body had no `data` object threw a type error. Both were uncaught and both
/// red-screened the work-order detail page. The server now returns real 4xx
/// codes for every failure it knows about, so this is hardening against
/// transport faults and shape changes rather than a live path - but it also
/// brings these methods in line with their siblings, which already trust the
/// body's own `statusCode` (see the checks around EditWorkOrder/addWorkOrder).
Map<String, dynamic> workOrderResponseData(int statusCode, String body) {
  final decoded = workOrderDecodedBody(statusCode, body);
  final dynamic data = decoded['data'];
  if (data is! Map<String, dynamic>) {
    throw Exception(kGenericErrorMessage);
  }
  return data;
}

/// Validates a work-order response and returns its decoded top-level map.
///
/// The shared prelude behind [workOrderResponseData]: HTTP status, then a
/// guarded `jsonDecode`, then the body's own `statusCode` when it carries one.
/// Callers that need to interpret `data` themselves use this directly - the
/// Tenant summary endpoint can answer with a List, with `data.result`, or with
/// a flat object, so it does its own shape handling on top of these checks.
Map<String, dynamic> workOrderDecodedBody(int statusCode, String body) {
  if (statusCode != 200) {
    throw Exception(workOrderFetchErrorMessage(body));
  }
  final dynamic decoded;
  try {
    decoded = jsonDecode(body);
  } on FormatException {
    throw Exception(kGenericErrorMessage);
  }
  if (decoded is! Map<String, dynamic>) {
    throw Exception(kGenericErrorMessage);
  }
  final dynamic bodyStatus = decoded['statusCode'];
  if (bodyStatus is int && (bodyStatus < 200 || bodyStatus >= 300)) {
    throw Exception(workOrderFetchErrorMessage(body));
  }
  return decoded;
}

/// Throws an [Exception] with a user-safe message unless [statusCode]/[body]
/// describe a successful work-order write.
///
/// For the update path, where the payload itself is never read. The old code
/// decoded and hard-cast `data` purely to discard it - taking the crash risk
/// described on [workOrderResponseData] for nothing. This checks only what
/// matters: the HTTP status and, when the body is JSON, its own `statusCode`.
/// A 200 with a non-JSON body is treated as success - the write went through
/// as far as HTTP is concerned, and failing a completed save over an
/// unparseable body would be worse than the bug being fixed.
void ensureWorkOrderSuccess(int statusCode, String body) {
  if (statusCode != 200) {
    throw Exception(workOrderFetchErrorMessage(body));
  }
  final dynamic decoded;
  try {
    decoded = jsonDecode(body);
  } on FormatException {
    return;
  }
  final dynamic bodyStatus = decoded is Map ? decoded['statusCode'] : null;
  if (bodyStatus is int && (bodyStatus < 200 || bodyStatus >= 300)) {
    throw Exception(workOrderFetchErrorMessage(body));
  }
}

/// Sanitises whatever a `FutureBuilder`/catch block hands us before it is
/// rendered. Already-friendly messages pass through; anything carrying a JSON
/// payload, URI, exception class name or errno is replaced with [fallback].
String friendlyErrorText(Object? error,
    {String fallback = kGenericErrorMessage}) {
  if (error == null) return fallback;
  String message = error.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
  message = message.trim();
  if (message.isEmpty) return fallback;
  const List<String> leaks = [
    '{',
    '}',
    'uri=',
    'http://',
    'https://',
    'SocketException',
    'ClientException',
    'HandshakeException',
    'TimeoutException',
    'FormatException',
    'errno',
    'OS Error',
    'statusCode',
  ];
  for (final String leak in leaks) {
    if (message.contains(leak)) return fallback;
  }
  return message;
}

/// Centered empty/error state for a failed fetch.
///
/// Replaces a bare left-aligned `Text(...)` floating in dead space: shows a
/// muted icon above the sanitised message, centred and padded so a
/// "record not found" reads as a designed state rather than a glitch.
Widget friendlyErrorState(
  Object? error, {
  String fallback = kGenericErrorMessage,
  IconData icon = Icons.search_off_rounded,
}) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 64,
            width: 64,
            decoration: const BoxDecoration(
              color: Color(0xFFF1F4F8),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 30, color: const Color(0xFF8A93A3)),
          ),
          const SizedBox(height: 16),
          Text(
            friendlyErrorText(error, fallback: fallback),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14.5,
              height: 1.45,
              fontWeight: FontWeight.w500,
              color: Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    ),
  );
}

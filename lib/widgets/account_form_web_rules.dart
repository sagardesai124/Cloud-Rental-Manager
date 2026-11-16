import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// Web has one Add/Edit account form (AccountDialog.jsx). It is used for
/// Settings › Accounts and for "Add account" inside Add, Edit and Renew
/// Lease, so every account form in the app takes its options and messages
/// from here.

/// Account Type, in web's order.
const List<String> kAccountTypeOptions = [
  'Income',
  'Liability Account',
  'Non Operating Income',
];

/// Fund Type, in web's order.
const List<String> kFundTypeOptions = ['Operating', 'Reserve'];

/// Shown under an empty Account Name.
const String kAccountNameRequiredMessage = 'Account name is required';

/// Shown above the buttons while a required box is red.
const String kAccountFixRedBoxesMessage = 'Please correct the red boxes above';

/// Web's messages for an empty Account Type / Fund Type.
const String kSelectAccountTypeMessage = 'Please select account type';
const String kSelectFundTypeMessage = 'Please select fund type';

/// The red web uses for an empty required box.
const Color kAccountErrorRed = Color(0xFFDC3545);

/// What web shows when the server refuses a new account: the server's own
/// message for a duplicate name (409), "Account already exists" for 400, and
/// "Failed to add account" for anything else.
String accountAddFailureMessage(http.Response response) {
  if (response.statusCode == 409) {
    return _serverMessage(response.body) ??
        'An account with this name already exists';
  }
  if (response.statusCode == 400) return 'Account already exists';
  return 'Failed to add account';
}

String? _serverMessage(String body) {
  try {
    final decoded = jsonDecode(body);
    if (decoded is Map && decoded['message'] is String) {
      final message = (decoded['message'] as String).trim();
      return message.isEmpty ? null : message;
    }
  } catch (_) {}
  return null;
}

import 'dart:convert';

import 'package:connectivity_plus_platform_interface/connectivity_plus_platform_interface.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:three_zero_two_property/model/properties.dart';
import 'package:three_zero_two_property/StaffModule/repository/properties.dart'
    as staff;
import 'package:three_zero_two_property/model/add_property.dart';
import 'package:three_zero_two_property/repository/properties.dart';

/// Add and Edit Property send the optional Subdivision as `subdivision`, like
/// web (Rentals.jsx / Functions/Rentals.js). Edit leaves it out when the form
/// didn't set it, so another caller can never wipe it by accident.

class _Online extends ConnectivityPlatform with MockPlatformInterfaceMixin {
  @override
  Future<ConnectivityResult> checkConnectivity() async =>
      ConnectivityResult.wifi;
  @override
  Stream<ConnectivityResult> get onConnectivityChanged => const Stream.empty();
}

Future<Map<String, dynamic>> _sentRental(
    Future<void> Function() save) async {
  Map<String, dynamic>? rental;
  final client = MockClient((request) async {
    if (request.method == 'PUT') {
      rental = (jsonDecode(request.body) as Map)['rental'] as Map<String, dynamic>;
    }
    return http.Response(
        jsonEncode({
          'statusCode': 200,
          'data': {'rentalOwner': {}}
        }),
        200,
        headers: {'content-type': 'application/json'});
  });
  await http.runWithClient(save, () => client);
  expect(rental, isNotNull, reason: 'the edit request was sent');
  return rental!;
}

Rentals _edit({String? subdivision}) => Rentals(
      rentalId: 'R-1',
      rentalAddress: '1 Test Street',
      rentalCity: 'Austin',
      rentalState: 'TX',
      rentalCountry: 'USA',
      rentalPostcode: '78701',
      subdivision: subdivision,
      rentalOwnerData: RentalOwnerData(rentalOwnerId: 'O-1'),
      units: const [],
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues(
        {'token': 'tkn', 'adminId': 'ADMIN-1', 'staff_id': 'STAFF-1'});
    ConnectivityPlatform.instance = _Online();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('PonnamKarthik/fluttertoast'), (_) async => true);
  });

  group('Add Property', () {
    test('sends the typed subdivision', () {
      final json = Rental(country: 'USA', subdivision: 'Oak Hills').toJson();
      expect(json['subdivision'], 'Oak Hills');
    });
    test('sends "" when left empty, like web', () {
      expect(Rental(subdivision: '').toJson()['subdivision'], '');
    });
  });

  group('Edit Property (Admin and Staff)', () {
    test('Admin sends the subdivision', () async {
      final rental = await _sentRental(
          () => PropertiesRepository().updateRental1(_edit(subdivision: 'Oak Hills')));
      expect(rental['subdivision'], 'Oak Hills');
      expect(rental['rental_country'], 'USA', reason: 'other fields unchanged');
    });
    test('Staff sends the subdivision', () async {
      final rental = await _sentRental(() =>
          staff.PropertiesRepository().updateRental1(_edit(subdivision: 'Oak Hills')));
      expect(rental['subdivision'], 'Oak Hills');
    });
    test('clearing it sends "" so it is cleared, like web', () async {
      final rental = await _sentRental(
          () => PropertiesRepository().updateRental1(_edit(subdivision: '')));
      expect(rental['subdivision'], '');
    });
    test('not set: left out, so the saved value is kept', () async {
      final rental =
          await _sentRental(() => PropertiesRepository().updateRental1(_edit()));
      expect(rental.containsKey('subdivision'), isFalse);
    });
  });
}

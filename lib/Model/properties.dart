import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:three_zero_two_property/services/api_helpers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constant/constant.dart';

// Define the Rental model with nested classes
class Rentals {
  String? id;
  String? rentalId;
  String? adminId;
  String? rentalOwnerId;
  String? propertyId;
  String? rentalAddress;
  bool? isRentOn;
  String? rentalCity;
  String? rentalState;
  String? rentalCountry;
  String? rentalPostcode;
  String? rentalImage;
  String? staffMemberId;
  String? createdAt;
  String? updatedAt;
  String? processor_id;
  bool? is_available;
  double? publishedRentAmount;
  String? parcelNumber;
  String? purchaseDate;
  double? purchasePrice;
  String? placedInService;
  String? subdivision;

  List<String>? rentalImages;
  bool? isDelete;
  RentalOwnerData? rentalOwnerData;
  PropertyTypeData? propertyTypeData;
  StaffMemberData? staffMemberData;
  List<TenantPropertiesData>? tenantsData;
  List<Map<String, dynamic>>? units;
  List<InsuredValue>? insuredValues; // Insured values list
  List<PropertyValueItem>? propertyValues;
  // Building/community amenities (Rentals.js property_amenities).
  List<String>? propertyAmenities;
  // Web's "Advertise this property on Zillow" setting (Rentals.js
  // zillow_advertise). Read-only on mobile: it only decides whether the
  // Property Amenities card is shown, exactly as web does.
  bool? zillowAdvertise;

  Rentals(
      {this.id,
      this.rentalId,
      this.adminId,
      this.rentalOwnerId,
      this.propertyId,
      this.rentalAddress,
      this.isRentOn,
      this.rentalCity,
      this.rentalState,
      this.rentalCountry,
      this.rentalPostcode,
      this.rentalImage,
      this.staffMemberId,
      this.createdAt,
      this.updatedAt,
      this.rentalImages,
      this.isDelete,
      this.rentalOwnerData,
      this.propertyTypeData,
      this.staffMemberData,
      this.processor_id,
      this.tenantsData,
      this.is_available,
      this.publishedRentAmount,
      this.parcelNumber,
      this.purchaseDate,
      this.purchasePrice,
      this.placedInService,
      this.subdivision,
      this.units,
      this.insuredValues,
      this.propertyValues,
      this.propertyAmenities,
      this.zillowAdvertise});

  // Define the fromJson method within the Rental class
  factory Rentals.fromJson(Map<String, dynamic> json) {
    return Rentals(
      id: json['_id'],
      rentalId: json['rental_id'] ?? "",
      adminId: json['admin_id'] ?? "",
      rentalOwnerId: json['rentalowner_id'] ?? "",
      propertyId: json['property_id'] ?? "",
      rentalAddress: json['rental_adress'] ?? "",
      isRentOn: json['is_rent_on'] ?? false,
      rentalCity: json['rental_city'] ?? "",
      rentalState: json['rental_state'] ?? "",
      rentalCountry: json['rental_country'] ?? "",
      rentalPostcode: json['rental_postcode'] ?? "",
      rentalImage: json['rental_image'] ?? "",
      staffMemberId: json['staffmember_id'] ?? "",
      createdAt: json['createdAt'] ?? "",
      updatedAt: json['updatedAt'] ?? "",
      processor_id: json['processor_id'] ?? "",
      rentalImages: (json['rental_images'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      isDelete: json['is_delete'] ?? false,
      is_available: json["is_available"] ?? false,
      publishedRentAmount: asDoubleN(json['published_rent_amount']),
      parcelNumber: json['parcel_number'] ?? "",
      purchaseDate: json['purchase_date'] ?? "",
      purchasePrice: asDoubleN(json['purchase_price']),
      placedInService: json['placed_in_service'] ?? "",
      subdivision: json['subdivision'] ?? "",
      rentalOwnerData:
          RentalOwnerData.fromJson(json['rental_owner_data'] ?? {}),
      propertyTypeData:
          PropertyTypeData.fromJson(json['property_type_data'] ?? {}),
      staffMemberData: StaffMemberData.fromJson(json['staffmember_data'] ?? {}),
      tenantsData: (json['tenants_data'] as List<dynamic>?)
          ?.map((e) => TenantPropertiesData.fromJson(e))
          .toList(),
      units: (json['units'] as List<dynamic>?)
          ?.map((e) => Map<String, dynamic>.from(e))
          .toList(),
      insuredValues: (json['insured_values'] as List<dynamic>?)
          ?.map((e) => InsuredValue.fromJson(e))
          .toList(),
      propertyValues: (json['propertyValues'] as List<dynamic>?)
          ?.map((e) => PropertyValueItem.fromJson(e))
          .toList(),
      zillowAdvertise: json['zillow_advertise'] == true ||
          json['zillow_advertise']?.toString() == 'true',
      propertyAmenities: (json['property_amenities'] as List<dynamic>?)
          ?.map((e) => e is String ? e : (e?['amenity_name'] ?? '').toString())
          .where((e) => e.isNotEmpty)
          .toList(),
    );
  }
}

class PropertyValueItem {
  String? id;
  num? estimatedValue;
  String? valueSource;
  String? valueAsOfDate;

  PropertyValueItem({
    this.id,
    this.estimatedValue,
    this.valueSource,
    this.valueAsOfDate,
  });

  factory PropertyValueItem.fromJson(Map<String, dynamic> json) {
    return PropertyValueItem(
      id: json['_id']?.toString(),
      estimatedValue: asDoubleN(json['estimatedValue']),
      valueSource: json['valueSource']?.toString(),
      valueAsOfDate: json['valueAsOfDate']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'estimatedValue': estimatedValue,
      'valueSource': valueSource,
      'valueAsOfDate': valueAsOfDate,
    };
  }
}

class InsuredValue {
  String? id;
  String? year;
  double? insuredValue;
  String? createdAt;

  InsuredValue({
    this.id,
    this.year,
    this.insuredValue,
    this.createdAt,
  });

  factory InsuredValue.fromJson(Map<String, dynamic> json) {
    double? parsed;
    final raw = json['insured_value'];
    if (raw is int) {
      parsed = raw.toDouble();
    } else if (raw is num) {
      parsed = raw.toDouble();
    } else if (raw != null) {
      parsed = double.tryParse(raw.toString());
    }
    return InsuredValue(
      id: json['_id'] ?? "",
      year: json['year']?.toString() ?? "",
      insuredValue: parsed,
      createdAt: json['created_at']?.toString() ?? "",
    );
  }
}

class RentalOwnerData {
  String? id;
  String? rentalOwnerId;
  String? adminId;
  String? rentalOwnerFirstName;
  String? rentalOwnerLastName;
  String? rentalOwnerCompanyName;
  String? rentalOwnerName;
  String? rentalOwnerPrimaryEmail;
  String? rentalOwnerAlternativeEmail;
  String? rentalOwnerPhoneNumber;
  String? rentalOwnerHomeNumber;
  String? rentalOwnerBuisinessNumber;
  String? city;
  String? Address;
  String? state;
  String? country;
  String? postalCode;
  String? createdAt;
  String? updatedAt;
  bool? isDelete;
  List<dynamic>? processorList;

  RentalOwnerData({
    this.id,
    this.rentalOwnerId,
    this.adminId,
    this.rentalOwnerFirstName,
    this.rentalOwnerLastName,
    this.rentalOwnerCompanyName,
    this.rentalOwnerName,
    this.rentalOwnerPrimaryEmail,
    this.rentalOwnerAlternativeEmail,
    this.rentalOwnerPhoneNumber,
    this.rentalOwnerHomeNumber,
    this.rentalOwnerBuisinessNumber,
    this.city,
    this.state,
    this.Address,
    this.country,
    this.postalCode,
    this.createdAt,
    this.updatedAt,
    this.isDelete,
    this.processorList,
  });

  factory RentalOwnerData.fromJson(Map<String, dynamic> json) {
    return RentalOwnerData(
      id: json['_id'] ?? "",
      rentalOwnerId: json['rentalowner_id'] ?? "",
      adminId: json['admin_id'] ?? "",
      rentalOwnerFirstName: json['rentalOwner_firstName'] ?? "",
      rentalOwnerLastName: json['rentalOwner_lastName'] ?? "",
      rentalOwnerCompanyName: json['rentalOwner_companyName'] ?? "",
      rentalOwnerName: json['rentalOwner_name'] ?? "",
      rentalOwnerPrimaryEmail: json['rentalOwner_primaryEmail'] ?? "",
      rentalOwnerAlternativeEmail: json['rentalOwner_alternateEmail'] ?? "",
      rentalOwnerPhoneNumber: json['rentalOwner_phoneNumber'] ?? "",
      rentalOwnerHomeNumber: json['rentalOwner_homeNumber'] ?? "",
      rentalOwnerBuisinessNumber: json['rentalOwner_businessNumber'] ?? "",
      city: json['city'] ?? "",
      state: json['state'] ?? "",
      Address: json['street_address'] ?? "",
      country: json['country'] ?? "",
      postalCode: json['postal_code'] ?? "",
      createdAt: json['createdAt'] ?? "",
      updatedAt: json['updatedAt'] ?? "",
      processorList: json['processor_list'] ?? [],
    );
  }
}

class PropertyTypeData {
  String? id;
  String? adminId;
  String? propertyId;
  String? propertyType;
  String? propertySubType;
  bool? isMultiunit;
  String? createdAt;
  String? updatedAt;

  PropertyTypeData({
    this.id,
    this.adminId,
    this.propertyId,
    this.propertyType,
    this.propertySubType,
    this.isMultiunit,
    this.createdAt,
    this.updatedAt,
  });

  factory PropertyTypeData.fromJson(Map<String, dynamic> json) {
    return PropertyTypeData(
      id: json['_id'] ?? "",
      adminId: json['admin_id'] ?? "",
      propertyId: json['property_id'] ?? "",
      propertyType: json['property_type'] ?? "",
      propertySubType: json['propertysub_type'] ?? "",
      isMultiunit: json['is_multiunit'] ?? false,
      createdAt: json['createdAt'] ?? "",
      updatedAt: json['updatedAt'] ?? "",
    );
  }
}

class StaffMemberData {
  String? id;
  String? adminId;
  String? staffmemberName;

  StaffMemberData({
    this.id,
    this.adminId,
    this.staffmemberName,
  });
  factory StaffMemberData.fromJson(Map<String, dynamic> json) {
    return StaffMemberData(
      id: json['_id'] ?? "",
      adminId: json['admin_id'] ?? "",
      staffmemberName: json['staffmember_name'] ?? "",
    );
  }
}

// Fetch rental owner data
// Future<List<Rentals>> fetchRentalOwner() async {
//   SharedPreferences prefs = await SharedPreferences.getInstance();
//   String? id = prefs.getString("adminId");
//   if (id == null) {
//     throw Exception('No adminId found in SharedPreferences');
//   }
//
//   final response = await apiGet(Uri.parse('${Api_url}/api/rentals/rental-owners/$id'));
//   if (response.statusCode == 200) {
//     List<dynamic> jsonResponse = json.decode(response.body);
//     return jsonResponse.map((data) => Rentals.fromJson(data)).toList();
//   } else {
//     throw Exception('Failed to load data');
//   }
// }
class TenantPropertiesData {
  String? id;
  String? tenantId;
  String? adminId;
  String? tenantFirstName;
  String? tenantLastName;
  String? tenantPhoneNumber;
  String? tenantAlternativeNumber;
  String? tenantEmail;
  String? tenantAlternativeEmail;
  String? tenantPassword;
  String? tenantBirthDate;
  String? taxPayerId;
  String? comments;
  bool? enableOverrideFee;
  EmergencyPropertyContact? emergencyContact;
  String? createdAt;
  String? updatedAt;
  bool? isDelete;

  TenantPropertiesData({
    this.id,
    this.tenantId,
    this.adminId,
    this.tenantFirstName,
    this.tenantLastName,
    this.tenantPhoneNumber,
    this.tenantAlternativeNumber,
    this.tenantEmail,
    this.tenantAlternativeEmail,
    this.tenantPassword,
    this.tenantBirthDate,
    this.taxPayerId,
    this.comments,
    this.enableOverrideFee,
    this.emergencyContact,
    this.createdAt,
    this.updatedAt,
    this.isDelete,
  });

  factory TenantPropertiesData.fromJson(Map<String, dynamic> json) {
    return TenantPropertiesData(
      id: json['_id'] ?? "",
      tenantId: json['tenant_id'] ?? "",
      adminId: json['admin_id'] ?? "",
      tenantFirstName: json['tenant_firstName'] ?? "",
      tenantLastName: json['tenant_lastName'] ?? "",
      tenantPhoneNumber: json['tenant_phoneNumber'] ?? "",
      tenantAlternativeNumber: json['tenant_alternativeNumber'] ?? "",
      tenantEmail: json['tenant_email'] ?? "",
      tenantAlternativeEmail: json['tenant_alternativeEmail'] ?? "",
      tenantPassword: json['tenant_password'] ?? "",
      tenantBirthDate: json['tenant_birthDate'] ?? "",
      taxPayerId: json['taxPayer_id'] ?? "",
      comments: json['comments'] ?? "",
      enableOverrideFee: json['enable_override_fee'] ?? false,
      emergencyContact:
          EmergencyPropertyContact.fromJson(json['emergency_contact'] ?? {}),
      createdAt: json['createdAt'] ?? "",
      updatedAt: json['updatedAt'] ?? "",
      isDelete: json['is_delete'] ?? false,
    );
  }
}

class EmergencyPropertyContact {
  String? name;
  String? relation;
  String? email;
  String? phoneNumber;

  EmergencyPropertyContact({
    this.name,
    this.relation,
    this.email,
    this.phoneNumber,
  });

  factory EmergencyPropertyContact.fromJson(Map<String, dynamic> json) {
    return EmergencyPropertyContact(
      name: json['name'] ?? "",
      relation: json['relation'] ?? "",
      email: json['email'] ?? "",
      phoneNumber: json['phoneNumber'] ?? "",
    );
  }
}

class LatLng {
  final double latitude;
  final double longitude;

  LatLng(this.latitude, this.longitude);
}

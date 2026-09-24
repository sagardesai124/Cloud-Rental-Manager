// lib/models.dart
class RentalOwners {
  String? adminId;
  String? rentalownersid;
  String? firstName;
  String? companyName;
  String? primaryEmail;
  String? phoneNumber;
  // Collected by the Add Rental Owner screen but previously never sent.
  // Server keys match web's submit helper (Functions/Rentals.js:108-112).
  String? alternateEmail;
  String? homeNumber;
  String? businessNumber;
  String? streetAddress;
  String? city;
  String? state;
  String? country;
  String? postalCode;
  List<ProcessorLists>? processorList;
  List<Map<String, String>>? processorid;

  RentalOwners({
    this.adminId,
    this.rentalownersid,
    this.firstName,
    this.companyName,
    this.primaryEmail,
    this.phoneNumber,
    this.alternateEmail,
    this.homeNumber,
    this.businessNumber,
    this.streetAddress,
    this.processorList,
    this.city,
    this.state,
    this.country,
    this.postalCode,
    this.processorid,
  });

  Map<String, dynamic> toJson() => {
        'admin_id': adminId,
        'rentalowner_id': rentalownersid,
        'rentalOwner_name': firstName,
        'rentalOwner_companyName': companyName,
        'rentalOwner_primaryEmail': primaryEmail,
        'rentalOwner_phoneNumber': phoneNumber,
        'rentalOwner_alternateEmail': alternateEmail ?? '',
        'rentalOwner_homeNumber': homeNumber ?? '',
        'rentalOwner_businessNumber': businessNumber ?? '',
        'street_address': streetAddress ?? '',
        'city': city,
        'state': state,
        'country': country,
        'postal_code': postalCode,
        if (processorList != null) 'processor_list': processorList,
        if (processorid != null) 'processor_list': processorid,
      };
}

class InsuredValue {
  String? year;
  String? insuredValue;

  InsuredValue({this.year, this.insuredValue});

  Map<String, dynamic> toJson() => {
        'year': year,
        'insured_value': insuredValue,
      };
}

class Rental {
  String? rentalId;
  String? adminId;
  String? propertyId;
  String? address;
  String? city;
  String? state;
  String? country;
  String? postcode;
  String? staffMemberId;
  String? processor_id;
  String? placedInService;
  List<InsuredValue>? insuredValues;
  // Building/community level amenities (Rentals.js property_amenities, plain
  // name strings). Web always sends it, [] when empty.
  List<String>? propertyAmenities;

  Rental(
      {this.adminId,
      this.rentalId,
      this.propertyId,
      this.address,
      this.city,
      this.state,
      this.country,
      this.postcode,
      this.staffMemberId,
      this.processor_id,
      this.placedInService,
      this.insuredValues,
      this.propertyAmenities});

  Map<String, dynamic> toJson() => {
        // rentalId: json['rental_id'] ?? "",
        ' rental_id': rentalId,
        'admin_id': adminId,
        'property_id': propertyId,
        'rental_adress': address,
        'rental_city': city,
        'rental_state': state,
        'rental_country': country,
        'rental_postcode': postcode,
        'staffmember_id': staffMemberId,
        if (placedInService != null && placedInService!.isNotEmpty)
          'placed_in_service': placedInService,
        if (insuredValues != null && insuredValues!.isNotEmpty)
          'insured_values': insuredValues!.map((iv) => iv.toJson()).toList(),
        if (propertyAmenities != null) 'property_amenities': propertyAmenities,
        // 'processor_id':processor_id
      };
}

class Unit {
  String? unit;
  String? address;
  String? sqft;
  String? bath;
  String? bed;
  String? Image;

  // Required on web for every residential unit (Rentals.jsx residentialSchema:
  // rental_unit_price / half_baths / availability_date). The server already
  // stores all three (Server/modals/superadmin/Unit.js), so these only needed
  // adding on the client. availabilityDate is sent as yyyy-MM-dd, like
  // placed_in_service. Commercial units leave them null and they are omitted.
  String? rentPrice;
  String? halfBaths;
  String? availabilityDate;
  // Optional on web, but all server-backed (Server/modals/superadmin/Unit.js).
  // Values are the server's enum strings, not the display labels.
  String? parkingType;
  String? leaseTerm;
  String? securityDeposit;
  String? securityDepositType;
  String? securityDepositMax;
  String? securityDepositRefundable;
  String? petPolicy;
  // Server stores these two as real Booleans (Unit.js is_furnished /
  // smoking_allowed), so send bools, not the 'true'/'false' text the
  // checkbox controllers hold.
  bool? isFurnished;
  bool? smokingAllowed;
  String? description;
  // Unit.js amenities: plain amenity names. Residential only, like web;
  // commercial units leave it null so their payload is unchanged.
  List<String>? amenities;

  Unit({
    this.unit,
    this.address,
    this.sqft,
    this.bath,
    this.bed,
    this.Image,
    this.rentPrice,
    this.halfBaths,
    this.availabilityDate,
    this.parkingType,
    this.leaseTerm,
    this.securityDeposit,
    this.securityDepositType,
    this.securityDepositMax,
    this.securityDepositRefundable,
    this.petPolicy,
    this.isFurnished,
    this.smokingAllowed,
    this.description,
    this.amenities,
  });

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{
      'rental_unit': unit,
      'rental_unit_adress': address,
      'rental_sqft': sqft,
      'rental_bath': bath,
      'rental_bed': bed,
      'rental_images': Image,
    };
    // Only send the residential-only keys when the form supplied them, so a
    // commercial unit's payload is unchanged.
    if (rentPrice != null) data['rental_unit_price'] = rentPrice;
    if (halfBaths != null) data['half_baths'] = halfBaths;
    if (availabilityDate != null) data['availability_date'] = availabilityDate;
    if (parkingType != null) data['parking_type'] = parkingType;
    if (leaseTerm != null) data['lease_term'] = leaseTerm;
    if (securityDeposit != null) data['security_deposit'] = securityDeposit;
    if (securityDepositType != null) {
      data['security_deposit_type'] = securityDepositType;
    }
    if (securityDepositMax != null) {
      data['security_deposit_max'] = securityDepositMax;
    }
    if (securityDepositRefundable != null) {
      data['security_deposit_refundable'] = securityDepositRefundable;
    }
    if (petPolicy != null) data['pet_policy'] = petPolicy;
    if (isFurnished != null) data['is_furnished'] = isFurnished;
    if (smokingAllowed != null) data['smoking_allowed'] = smokingAllowed;
    if (description != null) data['description'] = description;
    if (amenities != null) data['amenities'] = amenities;
    return data;
  }
}

class RentalRequest {
  RentalOwners? rentalOwner;
  Rental? rental;
  List<Unit>? units;
  String? notificationTime;

  RentalRequest({
    this.rentalOwner,
    this.rental,
    this.units,
    this.notificationTime,
  });

  Map<String, dynamic> toJson() => {
        'rentalOwner': rentalOwner!.toJson(),
        'rental': rental!.toJson(),
        'units': units!.map((unit) => unit.toJson()).toList(),
        'notificationTime': notificationTime,
      };
}

class ProcessorLists {
  String? processorId;
  String? sId;

  ProcessorLists({this.processorId, this.sId});

  factory ProcessorLists.fromJson(Map<String, dynamic> json) {
    return ProcessorLists(
      processorId: json['processor_id'],
      sId: json['_id'],
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['processor_id'] = this.processorId;
    data['_id'] = this.sId;
    return data;
  }
}

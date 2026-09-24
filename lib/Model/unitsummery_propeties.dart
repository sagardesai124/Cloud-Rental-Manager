class unit_properties {
  String? Id;
  String? adminId;
  String? unitId;
  String? rentalunit;
  String? rentalId;
  String? rentalunitadress;
  String? rentalsqft;
  String? rentalbath;
  String? rentalbed;
  // Residential-only, added for Add/Edit Property web parity. Server keys:
  // rental_unit_price / half_baths / availability_date (Unit.js).
  String? rentalUnitPrice;
  String? halfBaths;
  String? availabilityDate;
  String? parkingType;
  String? leaseTerm;
  String? securityDeposit;
  String? securityDepositType;
  String? securityDepositMax;
  String? securityDepositRefundable;
  String? petPolicy;
  bool? isFurnished;
  bool? smokingAllowed;
  String? description;
  List<String>? amenities;
  List<String>? rentalImages;
  int? tenantCount;
  String? createdAt;
  String? updatedAt;
  bool? isDelete;
  int? iV;

  unit_properties(
      {this.Id,
        this.adminId,
        this.unitId,
        this.rentalunit,
        this.rentalId,
        this.rentalunitadress,
        this.rentalImages,
        this.rentalsqft,
        this.tenantCount,
        this.rentalbath,
        this.rentalbed,
        this.rentalUnitPrice,
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

  unit_properties.fromJson(Map<String, dynamic> json) {
    Id = json['_id']??"";
    adminId = json['admin_id']??"";
    unitId = json['unit_id']??"";
    rentalunit = json['rental_unit']??"";
    rentalId = json['rental_id']??"";
    rentalunitadress = json['rental_unit_adress']??"";
    rentalsqft = json['rental_sqft']??"";
    tenantCount = json['tenantCount'] is int ? json['tenantCount'] as int : int.tryParse('${json['tenantCount'] ?? ''}');
    rentalbath = json['rental_bath']??"";
    rentalImages = (json['rental_images'] as List<dynamic>?)
        ?.map((e) => e as String)
        .toList();
    rentalbed = json['rental_bed']??"";
    // Server stores price as a Number; keep it as text for the form field.
    rentalUnitPrice = json['rental_unit_price']?.toString() ?? "";
    halfBaths = json['half_baths']?.toString() ?? "";
    availabilityDate = json['availability_date']?.toString() ?? "";
    parkingType = json['parking_type']?.toString() ?? "";
    leaseTerm = json['lease_term']?.toString() ?? "";
    securityDeposit = json['security_deposit']?.toString() ?? "";
    securityDepositType = json['security_deposit_type']?.toString() ?? "";
    securityDepositMax = json['security_deposit_max']?.toString() ?? "";
    securityDepositRefundable =
        json['security_deposit_refundable']?.toString() ?? "";
    petPolicy = json['pet_policy']?.toString() ?? "";
    // Tolerate bool or the string form, since older rows may hold either.
    isFurnished = json['is_furnished'] is bool
        ? json['is_furnished'] as bool
        : json['is_furnished']?.toString().toLowerCase() == 'true';
    smokingAllowed = json['smoking_allowed'] is bool
        ? json['smoking_allowed'] as bool
        : json['smoking_allowed']?.toString().toLowerCase() == 'true';
    description = json['description']?.toString() ?? "";
    // Unit.js amenities: plain names; tolerate {amenity_name} objects too.
    amenities = (json['amenities'] as List<dynamic>?)
            ?.map((e) =>
                e is String ? e : (e?['amenity_name'] ?? '').toString())
            .where((e) => e.isNotEmpty)
            .toList() ??
        <String>[];
    createdAt = json['createdAt']??"";
    updatedAt = json['updatedAt']??"";
    isDelete = json['is_delete'] is bool ? json['is_delete'] as bool : null;
    iV = json['__v'] is int ? json['__v'] as int : int.tryParse('${json['__v'] ?? ''}');
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['_id'] = this.Id;
    data['admin_id'] = this.adminId;
    data['unit_id'] = this.unitId;
    data['rental_unit'] = this.rentalunit;
    data['rental_id'] = this.rentalId;
    data['rental_unit_adress'] = this.rentalunitadress;
    data['rental_images'] = rentalImages;
    data['rental_sqft'] = this.rentalsqft;
    data['tenantCount'] = this.tenantCount;
    data['__v'] = this.iV;
    return data;
  }
}

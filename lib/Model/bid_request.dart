
import 'package:three_zero_two_property/constant/constant.dart';

class BidRequestResponse {
  int? statusCode;
  List<BidRequest>? data;
  Pagination? pagination;

  BidRequestResponse({
    this.statusCode,
    this.data,
    this.pagination,
  });

  factory BidRequestResponse.fromJson(Map<String, dynamic> json) {
    return BidRequestResponse(
      statusCode: json['statusCode'],
      data: json['data'] != null
          ? (json['data'] as List)
              .map((item) => BidRequest.fromJson(item))
              .toList()
          : null,
      pagination: json['pagination'] != null
          ? Pagination.fromJson(json['pagination'])
          : null,
    );
  }
}

class BidRequest {
  String? id;
  String? bidRequestId;

  /// Web parity: the list's "#" column renders `BR{bid_request_no}` — BR1,
  /// BR2 (BidRequests.jsx:700). The server auto-increments this per admin
  /// (BidRequest.js:39-45) and declares it as a Number, so it is parsed
  /// defensively: a whole number arrives as an int, and this must not throw
  /// if it ever arrives as a decimal or a string.
  num? bidRequestNo;
  String? adminId;
  String? rentalId;
  String? unitId;
  String? workCategory;
  String? description;
  List<String>? bidRequestImages;
  String? dueDate;
  String? status;
  String? createdByName;
  List<String>? selectedVendorIds;
  String? createdAt;
  // The real moment the bid room was created (the vendor list sends it as
  // createdAt_iso; createdAt there is the server's zone-less clock time).
  String? createdAtIso;
  String? updatedAt;
  bool? isDelete;
  int? v;
  Rental? rental;
  Unit? unit;
  int? submissionCount;
  bool? hasSubmitted;

  BidRequest({
    this.id,
    this.bidRequestId,
    this.bidRequestNo,
    this.adminId,
    this.rentalId,
    this.unitId,
    this.workCategory,
    this.description,
    this.bidRequestImages,
    this.dueDate,
    this.status,
    this.createdByName,
    this.selectedVendorIds,
    this.createdAt,
    this.createdAtIso,
    this.updatedAt,
    this.isDelete,
    this.v,
    this.rental,
    this.unit,
    this.submissionCount,
    this.hasSubmitted,
  });

  factory BidRequest.fromJson(Map<String, dynamic> json) {
    return BidRequest(
      id: json['_id'],
      bidRequestId: json['bid_request_id'],
      bidRequestNo: asNumN(json['bid_request_no']),
      adminId: json['admin_id'],
      rentalId: json['rental_id'],
      unitId: json['unit_id'],
      workCategory: json['work_category'],
      description: json['description'],
      bidRequestImages: json['bid_request_images'] != null
          ? List<String>.from(json['bid_request_images'])
          : null,
      dueDate: json['due_date'] ?? '',
      status: json['status'],
      createdByName: json['created_by_name'],
      selectedVendorIds: json['selected_vendor_ids'] != null
          ? List<String>.from(json['selected_vendor_ids'])
          : null,
      createdAt: json['createdAt'],
      createdAtIso: json['createdAt_iso']?.toString(),
      updatedAt: json['updatedAt'],
      isDelete: json['is_delete'],
      v: json['__v'],
      rental: json['rental'] != null ? Rental.fromJson(json['rental']) : null,
      unit: json['unit'] != null ? Unit.fromJson(json['unit']) : null,
      submissionCount: json['submission_count'],
      hasSubmitted: json['has_submitted'],
    );
  }
}

class Rental {
  String? id;
  String? rentalId;
  String? adminId;
  String? rentalownerId;
  String? propertyId;
  String? rentalAddress;
  bool? isRentOn;
  String? rentalCity;
  String? rentalState;
  String? rentalCountry;
  String? rentalPostcode;
  String? rentalImage;
  String? staffmemberId;
  String? createdAt;
  String? updatedAt;
  bool? isDelete;
  bool? isAvailable;
  int? v;

  Rental({
    this.id,
    this.rentalId,
    this.adminId,
    this.rentalownerId,
    this.propertyId,
    this.rentalAddress,
    this.isRentOn,
    this.rentalCity,
    this.rentalState,
    this.rentalCountry,
    this.rentalPostcode,
    this.rentalImage,
    this.staffmemberId,
    this.createdAt,
    this.updatedAt,
    this.isDelete,
    this.isAvailable,
    this.v,
  });

  factory Rental.fromJson(Map<String, dynamic> json) {
    return Rental(
      id: json['_id'],
      rentalId: json['rental_id'],
      adminId: json['admin_id'],
      rentalownerId: json['rentalowner_id'],
      propertyId: json['property_id'],
      rentalAddress: json['rental_adress'],
      isRentOn: json['is_rent_on'],
      rentalCity: json['rental_city'],
      rentalState: json['rental_state'],
      rentalCountry: json['rental_country'],
      rentalPostcode: json['rental_postcode'],
      rentalImage: json['rental_image'],
      staffmemberId: json['staffmember_id'],
      createdAt: json['createdAt'],
      updatedAt: json['updatedAt'],
      isDelete: json['is_delete'],
      isAvailable: json['is_available'],
      v: json['__v'],
    );
  }
}

class Unit {
  String? id;
  String? unitId;
  String? rentalUnit;
  String? adminId;
  String? rentalId;
  String? rentalUnitAddress;
  String? rentalSqft;
  String? rentalBath;
  String? rentalBed;
  List<String>? rentalImages;
  String? createdAt;
  String? updatedAt;
  bool? isDelete;
  int? v;

  Unit({
    this.id,
    this.unitId,
    this.rentalUnit,
    this.adminId,
    this.rentalId,
    this.rentalUnitAddress,
    this.rentalSqft,
    this.rentalBath,
    this.rentalBed,
    this.rentalImages,
    this.createdAt,
    this.updatedAt,
    this.isDelete,
    this.v,
  });

  factory Unit.fromJson(Map<String, dynamic> json) {
    return Unit(
      id: json['_id'],
      unitId: json['unit_id'],
      rentalUnit: json['rental_unit'],
      adminId: json['admin_id'],
      rentalId: json['rental_id'],
      rentalUnitAddress: json['rental_unit_adress'],
      rentalSqft: json['rental_sqft'],
      rentalBath: json['rental_bath'],
      rentalBed: json['rental_bed'],
      rentalImages: json['rental_images'] != null
          ? List<String>.from(json['rental_images'])
          : null,
      createdAt: json['createdAt'],
      updatedAt: json['updatedAt'],
      isDelete: json['is_delete'],
      v: json['__v'],
    );
  }
}

class Pagination {
  int? currentPage;
  int? totalPages;
  int? totalItems;
  int? itemsPerPage;

  Pagination({
    this.currentPage,
    this.totalPages,
    this.totalItems,
    this.itemsPerPage,
  });

  factory Pagination.fromJson(Map<String, dynamic> json) {
    return Pagination(
      currentPage: json['currentPage'],
      totalPages: json['totalPages'],
      totalItems: json['totalItems'],
      itemsPerPage: json['itemsPerPage'],
    );
  }
}

class BidRequestDetailResponse {
  int? statusCode;
  BidRequestDetail? data;

  BidRequestDetailResponse({
    this.statusCode,
    this.data,
  });

  factory BidRequestDetailResponse.fromJson(Map<String, dynamic> json) {
    return BidRequestDetailResponse(
      statusCode: json['statusCode'],
      data:
          json['data'] != null ? BidRequestDetail.fromJson(json['data']) : null,
    );
  }
}

class BidRequestDetail {
  String? id;
  String? bidRequestId;
  String? adminId;
  String? rentalId;
  String? unitId;
  String? workCategory;
  String? description;
  List<String>? bidRequestImages;
  String? dueDate;
  String? status;
  String? createdByName;
  List<String>? selectedVendorIds;
  String? createdAt;
  String? updatedAt;
  bool? isDelete;
  int? v;
  Rental? rental;
  Unit? unit;
  List<Submission>? submissions;

  BidRequestDetail({
    this.id,
    this.bidRequestId,
    this.adminId,
    this.rentalId,
    this.unitId,
    this.workCategory,
    this.description,
    this.bidRequestImages,
    this.dueDate,
    this.status,
    this.createdByName,
    this.selectedVendorIds,
    this.createdAt,
    this.updatedAt,
    this.isDelete,
    this.v,
    this.rental,
    this.unit,
    this.submissions,
  });

  factory BidRequestDetail.fromJson(Map<String, dynamic> json) {
    return BidRequestDetail(
      id: json['_id'],
      bidRequestId: json['bid_request_id'],
      adminId: json['admin_id'],
      rentalId: json['rental_id'],
      unitId: json['unit_id'],
      workCategory: json['work_category'],
      description: json['description'],
      bidRequestImages: json['bid_request_images'] != null
          ? List<String>.from(json['bid_request_images'])
          : null,
      dueDate: json['due_date'] ?? '',
      status: json['status'],
      createdByName: json['created_by_name'],
      selectedVendorIds: json['selected_vendor_ids'] != null
          ? List<String>.from(json['selected_vendor_ids'])
          : null,
      createdAt: json['createdAt'],
      updatedAt: json['updatedAt'],
      isDelete: json['is_delete'],
      v: json['__v'],
      rental: json['rental'] != null ? Rental.fromJson(json['rental']) : null,
      unit: json['unit'] != null ? Unit.fromJson(json['unit']) : null,
      submissions: json['submissions'] != null
          ? (json['submissions'] as List)
              .map((item) => Submission.fromJson(item))
              .toList()
          : null,
    );
  }
}

class Submission {
  String? id;
  String? bidSubmissionId;
  String? bidRequestId;
  String? vendorId;
  String? vendorName;
  String? adminId;
  String? submissionFile;
  String? priceBreakdown;
  double? totalPrice;
  String? status;
  String? submittedAt;
  String? createdAt;
  String? updatedAt;
  bool? isDelete;
  int? v;

  Submission({
    this.id,
    this.bidSubmissionId,
    this.bidRequestId,
    this.vendorId,
    this.vendorName,
    this.adminId,
    this.submissionFile,
    this.priceBreakdown,
    this.totalPrice,
    this.status,
    this.submittedAt,
    this.createdAt,
    this.updatedAt,
    this.isDelete,
    this.v,
  });

  factory Submission.fromJson(Map<String, dynamic> json) {
    return Submission(
      id: json['_id'],
      bidSubmissionId: json['bid_submission_id'],
      bidRequestId: json['bid_request_id'],
      vendorId: json['vendor_id'],
      vendorName: json['vendor_name'],
      adminId: json['admin_id'],
      submissionFile: json['submission_file'] ?? '',
      priceBreakdown: json['price_breakdown'] ?? '',
      totalPrice: asDoubleN(json['total_price']),
      status: json['status'],
      submittedAt: json['submitted_at'],
      createdAt: json['createdAt'],
      updatedAt: json['updatedAt'],
      isDelete: json['is_delete'],
      v: json['__v'],
    );
  }
}

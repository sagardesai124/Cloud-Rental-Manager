import 'package:three_zero_two_property/constant/constant.dart';

class Home_system_report {
  String? rentalId;
  int? totalUnits;
  int? totalAppliances;
  List<Units>? units;
  Summary? summary;

  Home_system_report(
      {this.rentalId,
        this.totalUnits,
        this.totalAppliances,
        this.units,
        this.summary});

  Home_system_report.fromJson(Map<String, dynamic> json) {
    rentalId = json['rental_id'];
    totalUnits = asIntN(json['total_units']);
    totalAppliances = asIntN(json['total_appliances']);
    if (json['units'] != null) {
      units = <Units>[];
      json['units'].forEach((v) {
        units!.add(new Units.fromJson(v));
      });
    }
    summary =
    json['summary'] != null ? new Summary.fromJson(json['summary']) : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['rental_id'] = this.rentalId;
    data['total_units'] = this.totalUnits;
    data['total_appliances'] = this.totalAppliances;
    if (this.units != null) {
      data['units'] = this.units!.map((v) => v.toJson()).toList();
    }
    if (this.summary != null) {
      data['summary'] = this.summary!.toJson();
    }
    return data;
  }
}

class Units {
  String? unitId;
  String? unitAddress;
  String? unitNumber;
  int? totalAppliances;
  List<Appliances>? appliances;

  Units(
      {this.unitId,
        this.unitAddress,
        this.unitNumber,
        this.totalAppliances,
        this.appliances});

  Units.fromJson(Map<String, dynamic> json) {
    unitId = json['unit_id'];
    unitAddress = json['unit_address'];
    unitNumber = json['unit_number'];
    totalAppliances = asIntN(json['total_appliances']);
    if (json['appliances'] != null) {
      appliances = <Appliances>[];
      json['appliances'].forEach((v) {
        appliances!.add(new Appliances.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['unit_id'] = this.unitId;
    data['unit_address'] = this.unitAddress;
    data['unit_number'] = this.unitNumber;
    data['total_appliances'] = this.totalAppliances;
    if (this.appliances != null) {
      data['appliances'] = this.appliances!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class Appliances {
  String? sId;
  String? applianceId;
  String? adminId;
  String? unitId;
  String? categoryId;
  String? applianceName;
  String? applianceDescription;
  String? type;
  String? brand;
  String? model;
  String? serialNumber;
  String? applianceImage;
  String? installedDate;
  String? warrantyExpiry;
  String? lastMaintenanceDate;
  String? maintenanceNotes;
  String? status;
  List<Filters>? filters;
  String? createdAt;
  String? updatedAt;
  List<Notes>? notes;
  List<MaintenanceHistory>? maintenanceHistory;
  int? iV;
  String? category;

  Appliances(
      {this.sId,
        this.applianceId,
        this.adminId,
        this.unitId,
        this.categoryId,
        this.applianceName,
        this.applianceDescription,
        this.type,
        this.brand,
        this.model,
        this.serialNumber,
        this.applianceImage,
        this.installedDate,
        this.warrantyExpiry,
        this.lastMaintenanceDate,
        this.maintenanceNotes,
        this.status,
        this.filters,
        this.createdAt,
        this.updatedAt,
        this.notes,
        this.maintenanceHistory,
        this.iV,
        this.category});

  Appliances.fromJson(Map<String, dynamic> json) {
    sId = json['_id'];
    applianceId = json['appliance_id'];
    adminId = json['admin_id'];
    unitId = json['unit_id'];
    categoryId = json['category_id'];
    applianceName = json['appliance_name'];
    applianceDescription = json['appliance_description'];
    type = json['type'];
    brand = json['brand'];
    model = json['model'];
    serialNumber = json['serial_number'];
    applianceImage = json['appliance_image'];
    installedDate = json['installed_date'];
    warrantyExpiry = json['warranty_expiry'];
    lastMaintenanceDate = json['last_maintenance_date'];
    maintenanceNotes = json['maintenance_notes'];
    status = json['status'];
    if (json['filters'] != null) {
      filters = <Filters>[];
      json['filters'].forEach((v) {
        filters!.add(new Filters.fromJson(v));
      });
    }
    createdAt = json['createdAt'];
    updatedAt = json['updatedAt'];
    if (json['notes'] != null) {
      notes = <Notes>[];
      json['notes'].forEach((v) {
        notes!.add(new Notes.fromJson(v));
      });
    }
    if (json['maintenance_history'] != null) {
      maintenanceHistory = <MaintenanceHistory>[];
      json['maintenance_history'].forEach((v) {
        maintenanceHistory!.add(new MaintenanceHistory.fromJson(v));
      });
    }
    iV = asIntN(json['__v']);
    category = json['category'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['_id'] = this.sId;
    data['appliance_id'] = this.applianceId;
    data['admin_id'] = this.adminId;
    data['unit_id'] = this.unitId;
    data['category_id'] = this.categoryId;
    data['appliance_name'] = this.applianceName;
    data['appliance_description'] = this.applianceDescription;
    data['type'] = this.type;
    data['brand'] = this.brand;
    data['model'] = this.model;
    data['serial_number'] = this.serialNumber;
    data['appliance_image'] = this.applianceImage;
    data['installed_date'] = this.installedDate;
    data['warranty_expiry'] = this.warrantyExpiry;
    data['last_maintenance_date'] = this.lastMaintenanceDate;
    data['maintenance_notes'] = this.maintenanceNotes;
    data['status'] = this.status;
    if (this.filters != null) {
      data['filters'] = this.filters!.map((v) => v.toJson()).toList();
    }
    data['createdAt'] = this.createdAt;
    data['updatedAt'] = this.updatedAt;
    if (this.notes != null) {
      data['notes'] = this.notes!.map((v) => v.toJson()).toList();
    }
    if (this.maintenanceHistory != null) {
      data['maintenance_history'] =
          this.maintenanceHistory!.map((v) => v.toJson()).toList();
    }
    data['__v'] = this.iV;
    data['category'] = this.category;
    return data;
  }
}

class Filters {
  String? filterId;
  String? filterName;
  String? filterSize;
  String? sId;

  Filters({this.filterId, this.filterName, this.filterSize, this.sId});

  Filters.fromJson(Map<String, dynamic> json) {
    filterId = json['filter_id'];
    filterName = json['filter_name'];
    filterSize = json['filter_size'];
    sId = json['_id'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['filter_id'] = this.filterId;
    data['filter_name'] = this.filterName;
    data['filter_size'] = this.filterSize;
    data['_id'] = this.sId;
    return data;
  }
}

class Notes {
  String? adminId;
  String? note;
  String? sId;
  String? timestamp;
  String? adminName;
  String? staffmemberName;

  Notes(
      {this.adminId,
        this.note,
        this.sId,
        this.timestamp,
        this.adminName,
        this.staffmemberName});

  Notes.fromJson(Map<String, dynamic> json) {
    adminId = json['admin_id'];
    note = json['note'];
    sId = json['_id'];
    timestamp = json['timestamp'];
    adminName = json['admin_name'];
    staffmemberName = json['staffmember_name'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['admin_id'] = this.adminId;
    data['note'] = this.note;
    data['_id'] = this.sId;
    data['timestamp'] = this.timestamp;
    data['admin_name'] = this.adminName;
    data['staffmember_name'] = this.staffmemberName;
    return data;
  }
}

class MaintenanceHistory {
  String? timestamp;
  String? adminId;
  String? staffmemberId;
  String? workorderId;
  String? vendor;
  String? event;
  List<String>? images;
  String? sId;
  String? workSubject;
  String? workStatus;
  String? adminName;
  String? staffmemberName;

  MaintenanceHistory(
      {this.timestamp,
        this.adminId,
        this.staffmemberId,
        this.workorderId,
        this.vendor,
        this.event,
        this.images,
        this.sId,
        this.workSubject,
        this.workStatus,
        this.adminName,
        this.staffmemberName});

  MaintenanceHistory.fromJson(Map<String, dynamic> json) {
    timestamp = json['timestamp'];
    adminId = json['admin_id'];
    staffmemberId = json['staffmember_id'];
    workorderId = json['workorder_id'];
    vendor = json['vendor'];
    event = json['event'];
    // Older history entries have no images list; read them as none, so the
    // whole report still loads.
    images = json['images'] is List
        ? (json['images'] as List).whereType<String>().toList()
        : <String>[];
    sId = json['_id'];
    workSubject = json['work_subject'];
    workStatus = json['work_status'];
    adminName = json['admin_name'];
    staffmemberName = json['staffmember_name'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['timestamp'] = this.timestamp;
    data['admin_id'] = this.adminId;
    data['staffmember_id'] = this.staffmemberId;
    data['workorder_id'] = this.workorderId;
    data['vendor'] = this.vendor;
    data['event'] = this.event;
    data['images'] = this.images;
    data['_id'] = this.sId;
    data['work_subject'] = this.workSubject;
    data['work_status'] = this.workStatus;
    data['admin_name'] = this.adminName;
    data['staffmember_name'] = this.staffmemberName;
    return data;
  }
}

class Summary {
  int? unitsWithAppliances;
  int? unitsWithoutAppliances;
  int? categoriesUsed;

  Summary(
      {this.unitsWithAppliances,
        this.unitsWithoutAppliances,
        this.categoriesUsed});

  Summary.fromJson(Map<String, dynamic> json) {
    unitsWithAppliances = asIntN(json['units_with_appliances']);
    unitsWithoutAppliances = asIntN(json['units_without_appliances']);
    categoriesUsed = asIntN(json['categories_used']);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['units_with_appliances'] = this.unitsWithAppliances;
    data['units_without_appliances'] = this.unitsWithoutAppliances;
    data['categories_used'] = this.categoriesUsed;
    return data;
  }
}

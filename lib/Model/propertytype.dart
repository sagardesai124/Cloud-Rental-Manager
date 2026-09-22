class propertytype {
  String? sId;
  String? adminId;
  String? propertyId;
  String? propertyType;
  String? propertysubType;
  bool? isMultiunit;
  String? propertyTypeImage;
  String? createdAt;
  String? updatedAt;
  bool? isDelete;
  int? iV;

  propertytype(
      {this.sId,
        this.adminId,
        this.propertyId,
        this.propertyType,
        this.propertysubType,
        this.isMultiunit,
        this.propertyTypeImage,
        this.createdAt,
        this.updatedAt,
        this.isDelete,
        this.iV});

  propertytype.fromJson(Map<String, dynamic> json) {
    sId = json['_id'];
    adminId = json['admin_id'];
    propertyId = json['property_id'];
    propertyType = json['property_type'];
    propertysubType = json['propertysub_type'];
    isMultiunit = json['is_multiunit'];
    propertyTypeImage = json['property_type_image'];
    createdAt = json['createdAt'];
    updatedAt = json['updatedAt'];
    isDelete = json['is_delete'];
    iV = json['__v'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['_id'] = this.sId;
    data['admin_id'] = this.adminId;
    data['property_id'] = this.propertyId;
    data['property_type'] = this.propertyType;
    data['propertysub_type'] = this.propertysubType;
    data['is_multiunit'] = this.isMultiunit;
    data['property_type_image'] = this.propertyTypeImage;
    data['createdAt'] = this.createdAt;
    data['updatedAt'] = this.updatedAt;
    data['is_delete'] = this.isDelete;
    data['__v'] = this.iV;
    return data;
  }
}

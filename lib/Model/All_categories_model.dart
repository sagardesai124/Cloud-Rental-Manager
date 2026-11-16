class allcategories_model {
  String? sId;
  String? categoryId;
  String? adminId;
  String? name;
  List<String>? brands;
  bool? isDefault;
  bool? isDelete;
  String? createdAt;
  String? updatedAt;
  int? iV;

  allcategories_model(
      {this.sId,
        this.categoryId,
        this.adminId,
        this.name,
        this.brands,
        this.isDefault,
        this.isDelete,
        this.createdAt,
        this.updatedAt,
        this.iV});

  /// Like web and the server: a category is HVAC when its name contains
  /// "hvac" in any case ("HVAC", "Hvac", "HVAC System").
  bool get isHvac => (name ?? '').toLowerCase().contains('hvac');

  allcategories_model.fromJson(Map<String, dynamic> json) {
    sId = json['_id'];
    categoryId = json['category_id'];
    adminId = json['admin_id'];
    name = json['name'];
    brands = json['brands'] != null ? List<String>.from(json['brands']) : null;
    isDefault = json['is_default'];
    isDelete = json['is_delete'];
    createdAt = json['createdAt'];
    updatedAt = json['updatedAt'];
    iV = json['__v'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['_id'] = this.sId;
    data['category_id'] = this.categoryId;
    data['admin_id'] = this.adminId;
    data['name'] = this.name;
    data['brands'] = this.brands;
    data['is_default'] = this.isDefault;
    data['is_delete'] = this.isDelete;
    data['createdAt'] = this.createdAt;
    data['updatedAt'] = this.updatedAt;
    data['__v'] = this.iV;
    return data;
  }
}

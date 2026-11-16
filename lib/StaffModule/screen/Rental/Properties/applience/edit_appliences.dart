import 'package:three_zero_two_property/services/app_log.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:three_zero_two_property/services/api_helpers.dart';
import '../../../../../Model/All_categories_model.dart';
import '../../../../../Model/unit.dart';
import '../../../../../constant/constant.dart';
import '../../../../../repository/fetch_allcategories.dart';
import '../../../../../widgets/clearable_date_picker.dart';
import '../../../../../widgets/clearable_date_suffix.dart';
import '../../../../widgets/appbar.dart';
import '../../../../widgets/custom_drawer.dart';
import '../../../../../model/properties.dart';
import '../../../../../model/unitsummery_propeties.dart';
import '../../../../repository/properties_summery.dart';
import '../../../../repository/unit_data.dart';
import 'dart:io';
import 'dart:convert';

class Edit_applience extends StatefulWidget {
  final Rentals? properties;
  final unit_properties? unit;
  final unit_appliance?
      appliance; // Make this required and non-null if possible
  Edit_applience({
    this.unit,
    this.properties,
    this.appliance,
  });

  @override
  State<Edit_applience> createState() => _Edit_applienceState();
}

class _Edit_applienceState extends State<Edit_applience> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _installedDate = TextEditingController();

  TextEditingController _type = TextEditingController();
  TextEditingController _model = TextEditingController();
  TextEditingController _serialNumber = TextEditingController();

  TextEditingController _warrantyExpiry = TextEditingController();
  TextEditingController _lastMaintenanceDate = TextEditingController();
  TextEditingController _maintenanceNotes = TextEditingController();

  final UnitData leaseRepository = UnitData();
  List<unit_appliance> leases = [];
  late Future<List<unit_appliance>> futureAppliences;
  Future<void> fetchLeases() async {
    //  try {
    final fetchedLeases =
        await leaseRepository.fetchApplianceData(widget.unit!.unitId!);
    setState(() {
      leases = fetchedLeases;
      isLoading = false;
    });
    //} catch (e) {
    setState(() {
      isLoading = false;
    });
    //print('Failed to load leases: $e');
    //}
  }

  reload_screen() {
    setState(() {
      futureAppliences =
          UnitData().fetchApplianceData(widget.unit?.unitId ?? "");
    });
  }

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {

    // Load the existing image if available
    if (widget.appliance?.applianceImage != null &&
        widget.appliance!.applianceImage!.isNotEmpty) {
      setState(() {
        _imageUrl = widget.appliance?.applianceImage;
      });
    }

    await _loadDropdownCategories();
    _loadApplianceData();
    await fetchLeases();
    futureAppliences = UnitData().fetchApplianceData(widget.unit?.unitId ?? "");
  }

  Future<void> _loadDropdownCategories() async {
    if (!mounted) return;

    setState(() {
      _isLoadingCategories = true;
    });

    try {
      final cats = await FetchAllcategories().fetchAllCategories();

      if (!mounted) return;

      setState(() {
        _dropdownCategories = cats;

        // Try to find the matching category
        if (widget.appliance?.categoryId != null) {

          // First try exact match
          try {
            var matchingCategory = cats.firstWhere(
              (cat) =>
                  (cat.categoryId ?? "").trim() ==
                  (widget.appliance?.categoryId ?? "").trim(),
            );
            _selectedDropdownCategory = matchingCategory;
          } catch (e) {
            // If no exact match, try case-insensitive match
            try {
              var matchingCategory = cats.firstWhere(
                (cat) =>
                    (cat.categoryId ?? "").trim().toLowerCase() ==
                    (widget.appliance?.categoryId ?? "").trim().toLowerCase(),
              );
              logError(
                  'Found case-insensitive matching category: ${matchingCategory.name}');
              _selectedDropdownCategory = matchingCategory;
            } catch (e) {
              // If still no match and we have category name, create temporary
              if (widget.appliance?.categoryName != null) {
                _selectedDropdownCategory = allcategories_model(
                  categoryId: widget.appliance?.categoryId ?? "",
                  name: widget.appliance?.categoryName ?? "",
                );
                logError(
                    'Created temporary category: ${_selectedDropdownCategory?.name}');
              }
            }
          }
        }

        // Web parity: derive Type (system_type) from the resolved category.
        final catName = _selectedDropdownCategory?.name ?? '';
        _selectedSystemType = _majorSystemCategories
                .any((m) => m.toLowerCase() == catName.toLowerCase())
            ? 'Major System'
            : 'Appliance';

        _isLoadingCategories = false;
      });
    } catch (e) {
      logError('Error loading categories: $e');
      if (!mounted) return;
      setState(() {
        _isLoadingCategories = false;
      });
    }
  }

  void _loadApplianceData() {
    if (!mounted || widget.appliance == null) return;

    setState(() {
      _name.text = widget.appliance?.applianceName ?? '';
      _description.text = widget.appliance?.applianceDescription ?? '';
      _installedDate.text = widget.appliance?.installedDate ?? '';
      _type.text = widget.appliance?.type ?? '';
      _model.text = widget.appliance?.model ?? '';
      _serialNumber.text = widget.appliance?.serialNumber ?? '';
      _warrantyExpiry.text = widget.appliance?.warrantyExpiry ?? '';
      _lastMaintenanceDate.text = widget.appliance?.lastMaintenanceDate ?? '';
      _maintenanceNotes.text = widget.appliance?.maintenanceNotes ?? '';

      final existingBrand = widget.appliance?.brand ?? '';
      if (existingBrand.isNotEmpty && !brandList.contains(existingBrand)) {
        _selectedBrand = 'Other';
        _customBrand.text = existingBrand;
      } else {
        _selectedBrand = existingBrand.isNotEmpty ? existingBrand : null;
      }
      _selectedStatus = widget.appliance?.status;

      if (widget.appliance?.filters != null &&
          widget.appliance!.filters!.isNotEmpty) {
        showFiltersSection = true;
        filterControllers.clear();
        for (var filter in widget.appliance!.filters!) {
          filterControllers.add({
            'name': TextEditingController(text: filter['filter_name'] ?? ''),
            'size': TextEditingController(text: filter['filter_size'] ?? ''),
          });
        }
      }
    });
  }

  bool isLoading = false;
  bool iserror = false;
  List<allcategories_model> _dropdownCategories = [];
  allcategories_model? _selectedDropdownCategory;
  bool _isLoadingCategories = false;

  List<String> brandList = [
    'Amana',
    'Badger',
    'Bosch',
    'Carrier',
    'Daikin',
    'Frigidaire',
    'GE',
    'Goodman',
    'InSinkErator',
    'KitchenAid',
    'Lennox',
    'LG',
    'Maytag',
    'Mitsubishi Electric',
    'Moen',
    'Rheem',
    'Samsung',
    'Trane',
    'Waste King',
    'Whirlpool',
    'York',
    'Other',
  ];
  List<String> statusList = ['Working', 'Needs Repair', "Out of Service"];

  String? _selectedBrand;
  String? _selectedStatus;
  String? _selectedSystemType;
  final List<String> systemTypeList = ['Major System', 'Appliance'];
  final List<String> _majorSystemCategories = [
    'Roof',
    'Electrical',
    'Plumbing',
    'Exterior',
    'Water Heater',
    'HVAC',
  ];
  final TextEditingController _customBrand = TextEditingController();

  @override
  void dispose() {
    _type.dispose();
    _model.dispose();
    _serialNumber.dispose();
    _warrantyExpiry.dispose();
    _lastMaintenanceDate.dispose();
    _maintenanceNotes.dispose();
    _customBrand.dispose();
    super.dispose();
  }

  // Web parity: Category options are filtered by the selected Type (system_type).
  List<allcategories_model> get _filteredCategories {
    if (_selectedSystemType == null || _selectedSystemType!.isEmpty) {
      return _dropdownCategories;
    }
    final isMajor = _selectedSystemType == 'Major System';
    return _dropdownCategories.where((cat) {
      final inMajor = _majorSystemCategories
          .any((m) => m.toLowerCase() == (cat.name ?? '').toLowerCase());
      return isMajor ? inMajor : !inMajor;
    }).toList();
  }

  // Add these to your state class
  List<Map<String, TextEditingController>> filterControllers = [];
  bool showFilters = false;

// Add this method to handle adding new filter
  void addNewFilter() {
    setState(() {
      filterControllers.add({
        'name': TextEditingController(),
        'size': TextEditingController(),
      });
    });
  }

// Add this method to remove filter
  void removeFilter(int index) {
    setState(() {
      filterControllers[index]['name']?.dispose();
      filterControllers[index]['size']?.dispose();
      filterControllers.removeAt(index);
    });
  }

  bool showFiltersSection = false;

  //for image add
  File? _image;
  bool isloading = false;
  String? _uploadedFileName;
  String? _imageUrl;
  bool _imageRemoved = false;

  String? _cleanBase64String(String? base64String) {
    if (base64String == null) return null;
    // Remove data URI prefix if present
    if (base64String.startsWith('data:')) {
      return base64String.split(',')[1];
    }
    return base64String;
  }

  Future<String?> uploadImage(File imageFile) async {
    final String uploadUrl = '${image_upload_url}/api/images/upload';
    var request = http.MultipartRequest(
        'POST',
        Uri.parse(
          uploadUrl,
        ));
    request.files
        .add(await http.MultipartFile.fromPath('files', imageFile.path));

    var response = await apiSend(request);
    var responseData = await http.Response.fromStream(response);

    var responseBody = json.decode(responseData.body);
    if (responseBody['status'] == 'ok') {
      List file = responseBody['files'];
      return file.first["filename"];
    } else {
      throw Exception('Failed to upload file: ${responseBody['message']}');
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker _picker = ImagePicker();
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _image = File(image.path);
        _imageRemoved = false;
      });
      _uploadImage(File(image.path));
    }
  }

  Widget _buildImage() {
    if (_image != null) {
      return Image.file(
        _image!,
        fit: BoxFit.cover,
      );
    }

    if (_imageUrl != null && _imageUrl!.isNotEmpty && _imageUrl!.contains(',')) {
      try {
        return Image.memory(
          base64Decode(_imageUrl!.split(',')[1]),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: Colors.grey[200],
              child: const Icon(Icons.error),
            );
          },
        );
      } catch (e) {
        return Container(
          color: Colors.grey[200],
          child: const Icon(Icons.error),
        );
      }
    }

    return Container(
      color: Colors.grey[200],
      child: const Icon(Icons.image_not_supported),
    );
  }

  Future<void> _uploadImage(File imageFile) async {
    try {
      List<int> imageBytes = await imageFile.readAsBytes();
      String base64Image = 'data:image/jpeg;base64,' + base64Encode(imageBytes);
      setState(() {
        _imageUrl = base64Image;
      });
    } catch (e) {
      logError('Image conversion failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget_302_Staff.App_Bar(context: context),
      backgroundColor: Colors.white,
      drawer: CustomDrawerStaff(
        currentpage: "Properties",
        dropdown: true,
      ),
      body: SingleChildScrollView(
        child: SizedBox(
          width: 800,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(
                    height: 20,
                  ),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(5.0),
                    child: Container(
                      height: 50.0,
                      padding: const EdgeInsets.only(top: 10, left: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(5.0),
                        color: blueColor,
                        boxShadow: [
                          const BoxShadow(
                            color: Colors.grey,
                            offset: Offset(0.0, 1.0),
                            blurRadius: 6.0,
                          ),
                        ],
                      ),
                      child: const Text(
                        "Edit Home Systems",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(
                    height: 20,
                  ),
                  const Padding(
                    padding: EdgeInsets.only(left: 10),
                    child: Text(
                      'Name',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  CustomTextFormField(
                    labelText: '',
                    hintText: 'Enter Name',
                    controller: _name,
                    keyboardType: TextInputType.text,
                  ),
                  const SizedBox(height: 8),
                  const Padding(
                    padding: EdgeInsets.only(left: 10),
                    child: Text(
                      'Description',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  CustomTextFormField(
                    labelText: '',
                    hintText: 'Enter description',
                    controller: _description,
                    keyboardType: TextInputType.text,
                  ),
                  const SizedBox(height: 8),
                  const Padding(
                    padding: EdgeInsets.only(left: 10),
                    child: Text(
                      'Type *',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton2<String>(
                        isExpanded: true,
                        hint: const Text('Select Type'),
                        value: _selectedSystemType,
                        items: systemTypeList.map((t) {
                          return DropdownMenuItem<String>(
                            value: t,
                            child: Text(t),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedSystemType = newValue;
                            _selectedDropdownCategory = null;
                            showFiltersSection = false;
                          });
                        },
                        buttonStyleData: _boxLikeTextField(),
                        iconStyleData: const IconStyleData(
                          icon: Icon(Icons.arrow_drop_down),
                          iconSize: 24,
                          iconEnabledColor: Color(0xFFb0b6c3),
                          iconDisabledColor: Colors.grey,
                        ),
                        dropdownStyleData: DropdownStyleData(
                          maxHeight: 250,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            color: Colors.white,
                          ),
                        ),
                        menuItemStyleData: const MenuItemStyleData(
                          height: 50,
                          padding: EdgeInsets.symmetric(horizontal: 14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Padding(
                    padding: EdgeInsets.only(left: 10),
                    child: Text(
                      'Category',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  //categories dropdwoun
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton2<allcategories_model>(
                        isExpanded: true,
                        hint: Text(_isLoadingCategories
                            ? 'Loading categories...'
                            : 'Select Category'),
                        value: _filteredCategories
                                .contains(_selectedDropdownCategory)
                            ? _selectedDropdownCategory
                            : null,
                        items: _filteredCategories.map((cat) {
                          return DropdownMenuItem<allcategories_model>(
                            value: cat,
                            child: Text(cat.name ?? ''),
                          );
                        }).toList(),
                        onChanged: _isLoadingCategories
                            ? null
                            : (allcategories_model? newValue) {
                                setState(() {
                                  _selectedDropdownCategory = newValue;

                                  // Reset filters if changing from/to HVAC
                                  if (_selectedDropdownCategory?.isHvac != true) {
                                    showFiltersSection = false;
                                    for (var controllers in filterControllers) {
                                      controllers['name']?.dispose();
                                      controllers['size']?.dispose();
                                    }
                                    filterControllers.clear();
                                  }
                                });
                              },
                        buttonStyleData: _boxLikeTextField(),
                        iconStyleData: const IconStyleData(
                          icon: Icon(Icons.arrow_drop_down),
                          iconSize: 24,
                          iconEnabledColor: Color(0xFFb0b6c3),
                          iconDisabledColor: Colors.grey,
                        ),
                        dropdownStyleData: DropdownStyleData(
                          maxHeight: 250,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            color: Colors.white,
                          ),
                          scrollbarTheme: ScrollbarThemeData(
                            radius: const Radius.circular(6),
                            thickness: MaterialStateProperty.all(6),
                            thumbVisibility: MaterialStateProperty.all(true),
                          ),
                        ),
                        menuItemStyleData: const MenuItemStyleData(
                          height: 50,
                          padding: EdgeInsets.symmetric(horizontal: 14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Padding(
                    padding: EdgeInsets.only(left: 10),
                    child: Text(
                      'Brand',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton2<String>(
                        isExpanded: true,
                        hint: const Text('Select Brand'),
                        value: brandList.contains(_selectedBrand)
                            ? _selectedBrand
                            : null,
                        items: brandList.map((brand) {
                          return DropdownMenuItem<String>(
                            value: brand,
                            child: Text(brand),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedBrand = newValue;
                            if (newValue != 'Other') _customBrand.clear();
                          });
                        },
                        buttonStyleData: _boxLikeTextField(),
                        iconStyleData: const IconStyleData(
                          icon: Icon(Icons.arrow_drop_down),
                          iconSize: 24,
                          iconEnabledColor: Color(0xFFb0b6c3),
                          iconDisabledColor: Colors.grey,
                        ),
                        dropdownStyleData: DropdownStyleData(
                          maxHeight: 250,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            color: Colors.white,
                          ),
                          scrollbarTheme: ScrollbarThemeData(
                            radius: const Radius.circular(6),
                            thickness: MaterialStateProperty.all(6),
                            thumbVisibility: MaterialStateProperty.all(true),
                          ),
                        ),
                        menuItemStyleData: const MenuItemStyleData(
                          height: 50,
                          padding: EdgeInsets.symmetric(horizontal: 14),
                        ),
                      ),
                    ),
                  ),
                  if (_selectedBrand == 'Other') ...[
                    const SizedBox(height: 8),
                    const Padding(
                      padding: EdgeInsets.only(left: 10),
                      child: Text(
                        'Custom Brand Name *',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    CustomTextFormField(
                      labelText: '',
                      hintText: 'Enter custom brand name',
                      controller: _customBrand,
                      keyboardType: TextInputType.text,
                    ),
                  ],
                  const SizedBox(height: 8),
                  const Padding(
                    padding: EdgeInsets.only(left: 10),
                    child: Text(
                      'Model',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  CustomTextFormField(
                    labelText: '',
                    hintText: 'Enter model',
                    controller: _model,
                    keyboardType: TextInputType.text,
                  ),
                  const SizedBox(height: 8),
                  const Padding(
                    padding: EdgeInsets.only(left: 10),
                    child: Text(
                      'Serial Number',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  CustomTextFormField(
                    labelText: '',
                    hintText: 'Enter serial number',
                    controller: _serialNumber,
                    keyboardType: TextInputType.text,
                  ),
                  const SizedBox(height: 8),
                  const Padding(
                    padding: EdgeInsets.only(left: 10),
                    child: Text(
                      'Installed Date',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  dateField(
                      'Installed Date', _installedDate, context, setState),
                  const SizedBox(height: 8),
                  const Padding(
                    padding: EdgeInsets.only(left: 10),
                    child: Text(
                      'Warranty Expiry',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  dateField(
                      'Warranty Expiry', _warrantyExpiry, context, setState),
                  const SizedBox(height: 8),
                  const Padding(
                    padding: EdgeInsets.only(left: 10),
                    child: Text(
                      'Last Maintenance Date',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  dateField('Last Maintenance Date', _lastMaintenanceDate,
                      context, setState),
                  const SizedBox(height: 8),
                  const Padding(
                    padding: EdgeInsets.only(left: 10),
                    child: Text(
                      'Status',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton2<String>(
                        isExpanded: true,
                        hint: const Text('Select Status'),
                        value: statusList.contains(_selectedStatus)
                            ? _selectedStatus
                            : null,
                        items: statusList.map((status) {
                          return DropdownMenuItem<String>(
                            value: status,
                            child: Text(status),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedStatus = newValue;
                          });
                        },
                        buttonStyleData: _boxLikeTextField(),
                        iconStyleData: const IconStyleData(
                          icon: Icon(Icons.arrow_drop_down),
                          iconSize: 24,
                          iconEnabledColor: Color(0xFFb0b6c3),
                          iconDisabledColor: Colors.grey,
                        ),
                        dropdownStyleData: DropdownStyleData(
                          maxHeight: 250,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            color: Colors.white,
                          ),
                          scrollbarTheme: ScrollbarThemeData(
                            radius: const Radius.circular(6),
                            thickness: MaterialStateProperty.all(6),
                            thumbVisibility: MaterialStateProperty.all(true),
                          ),
                        ),
                        menuItemStyleData: const MenuItemStyleData(
                          height: 50,
                          padding: EdgeInsets.symmetric(horizontal: 14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Padding(
                    padding: EdgeInsets.only(left: 10),
                    child: Text(
                      'Maintenance Notes',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  CustomTextFormField(
                    labelText: '',
                    hintText: 'Enter notes',
                    controller: _maintenanceNotes,
                    keyboardType: TextInputType.text,
                  ),
                  // Add this after your Status dropdown
                  if (_selectedDropdownCategory?.isHvac == true) ...[
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Padding(
                                padding: EdgeInsets.all(2.0),
                                child: Text(
                                  'Filters',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    showFiltersSection = true;
                                    // Always add a new filter when button is clicked
                                    filterControllers.add({
                                      'name': TextEditingController(),
                                      'size': TextEditingController(),
                                    });
                                  });
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: blueColor,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text('Add Filter',
                                    style: TextStyle(color: Colors.white)),
                              ),
                            ],
                          ),
                          const Padding(
                            padding: EdgeInsets.all(10.0),
                            child: Text(
                              'Optional: Add filters for HVAC systems',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (showFiltersSection) ...[
                            ...filterControllers.asMap().entries.map((entry) {
                              int index = entry.key;
                              var controllers = entry.value;
                              return Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  border:
                                      Border.all(color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('Filter ${index + 1}'),
                                        IconButton(
                                          icon: const Icon(
                                              Icons.remove_circle_outline,
                                              color: Colors.red),
                                          onPressed: () {
                                            setState(() {
                                              removeFilter(index);
                                            });
                                          },
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    CustomTextFormField(
                                      labelText: '',
                                      hintText: 'Filter Name',
                                      controller: controllers['name']!,
                                      keyboardType: TextInputType.text,
                                    ),
                                    const SizedBox(height: 8),
                                    CustomTextFormField(
                                      labelText: '',
                                      hintText: 'Filter Size (e.g., 16x20x1)',
                                      controller: controllers['size']!,
                                      keyboardType: TextInputType.text,
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ],
                        ],
                      ),
                    ),
                  ],
                  const Padding(
                    padding: EdgeInsets.only(left: 10),
                    child: Text(
                      'Image',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.only(left: 8, right: 8),
                    child: Column(
                      children: [
                        if (_imageUrl == null || _imageUrl!.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: GestureDetector(
                              onTap: () {
                                _pickImage();
                              },
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                      color: Colors.grey.shade300,
                                      style: BorderStyle.solid),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  children: [
                                    Image.asset(
                                      'assets/icons/Upload.png',
                                      height: 50,
                                      width: 50,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Upload your Photo here',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      'Maximum File Size is 20MB',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          fontSize: 12, color: Colors.grey),
                                    ),
                                    const Text(
                                      'Supported File Types are .png, .jpeg, .pdf, .csv',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          fontSize: 12, color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        if (_imageUrl != null && _imageUrl!.isNotEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              border: Border.all(
                                  color: Colors.grey.shade300,
                                  style: BorderStyle.solid),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.all(4.0),
                                      child: Container(
                                        width: 80,
                                        height: 80,
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                              color: Colors.grey.shade300),
                                        ),
                                        child: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          child: _buildImage(),
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      top: 0,
                                      right: 0,
                                      child: GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _image = null;
                                            _imageUrl = null;
                                            _imageRemoved = true;
                                          });
                                        },
                                        child: Container(
                                          width: 18,
                                          height: 18,
                                          decoration: const BoxDecoration(
                                            color: Colors.white,
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black,
                                                blurRadius: 4,
                                              ),
                                            ],
                                          ),
                                          child: const Icon(
                                            Icons.close,
                                            size: 14,
                                            color: Colors.black,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      const SizedBox(
                        width: 10,
                      ),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: blueColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () async {
                            // Like web: only Type and Category are required
                            // (editing never needs the custom brand).
                            if (_selectedSystemType == null ||
                                _selectedDropdownCategory == null) {
                              setState(() => iserror = true);
                            } else if (_selectedDropdownCategory?.isHvac == true &&
                                showFiltersSection &&
                                filterControllers.any((c) =>
                                    (c['name']?.text.trim() ?? '').isEmpty ||
                                    (c['size']?.text.trim() ?? '').isEmpty)) {
                              // Like web: every HVAC filter needs a name and a size.
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      'Filter name and size are required for all filters'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            } else {
                              setState(() {
                                isLoading = true;
                                iserror = false;
                              });

                              try {
                                SharedPreferences prefs =
                                    await SharedPreferences.getInstance();
                                String? id = prefs.getString("adminId");

                                // Generate filters list based on category
                                List<Map<String, dynamic>> finalFilters = [];
                                if (_selectedDropdownCategory?.isHvac == true &&
                                    showFiltersSection) {
                                  for (int i = 0;
                                      i < filterControllers.length;
                                      i++) {
                                    await Future.delayed(
                                        const Duration(milliseconds: 2));
                                    final uniqueId = DateTime.now()
                                        .millisecondsSinceEpoch
                                        .toString();
                                    final controller = filterControllers[i];
                                    finalFilters.add({
                                      "filter_id": uniqueId,
                                      "filter_name":
                                          controller['name']?.text ?? '',
                                      "filter_size":
                                          controller['size']?.text ?? '',
                                    });
                                  }
                                }

                                await Properies_summery_Repo().Editappliances(
                                  applianceid: widget.appliance?.applianceId,
                                  removeApplianceImages:
                                      _imageRemoved ? 'true' : 'false',
                                  adminId: id,
                                  unitId: widget.unit?.unitId,
                                  rentalId: widget.unit?.rentalId ??
                                      widget.properties?.rentalId ??
                                      "",
                                  appliancename: _name.text,
                                  appliancedescription: _description.text,
                                  installeddate: _installedDate.text,
                                  type: _type.text,
                                  systemType: _selectedSystemType ?? "",
                                  brand: _selectedBrand == 'Other'
                                      ? _customBrand.text
                                      : _selectedBrand,
                                  model: _model.text,
                                  serialNumber: _serialNumber.text,
                                  warrantyExpiry:
                                      _warrantyExpiry.text.isNotEmpty
                                          ? _warrantyExpiry.text
                                          : null,
                                  lastMaintenanceDate:
                                      _lastMaintenanceDate.text.isNotEmpty
                                          ? _lastMaintenanceDate.text
                                          : null,
                                  maintenanceNotes: _maintenanceNotes.text,
                                  status: _selectedStatus,
                                  categoryId:
                                      _selectedDropdownCategory?.categoryId ??
                                          "",
                                  filters: finalFilters,
                                  appliance_image: _imageUrl,
                                );

                                if (mounted) {
                                  setState(() {
                                    isLoading = false;
                                  });
                                  reload_screen();
                                  Navigator.pop(context, true);
                                }
                              } catch (e) {
                                if (mounted) {
                                  setState(() {
                                    isLoading = false;
                                  });
                                  final cleanMsg = e
                                      .toString()
                                      .replaceFirst('Exception: ', '');
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(cleanMsg)),
                                  );
                                }
                              }
                            }
                          },
                          child: isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Save',
                                  style: TextStyle(color: Colors.white)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cancel'),
                        ),
                      ),
                    ],
                  ),
                  if (iserror)
                    const Padding(
                      padding: EdgeInsets.only(top: 8.0),
                      child: Text(
                        "Please fill in all fields correctly.",
                        style: TextStyle(color: Colors.redAccent),
                      ),
                    )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget dateField(String label, TextEditingController controller,
      BuildContext context, StateSetter setState) {
    // Every date is optional, like web (Installed Date too), so each one
    // offers a Clear action.
    void clearDate() {
      setState(() {
        controller.clear();
      });
    }

    Future<void> openPicker() async {
      final ClearableDatePickerResult? result = await showClearableDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
        helpText: 'Select $label',
      );
      if (result == null) return; // cancelled — keep the current value
      if (result.cleared) {
        clearDate();
        return;
      }
      setState(() {
        controller.text = formatDate(result.date!.toString());
      });
    }

    return CustomTextFormField(
      labelText: label,
      hintText: 'Select $label',
      controller: controller,
      keyboardType: TextInputType.datetime,
      readOnly: true,
      onTap: openPicker,
      suffixIcon: ClearableDateSuffix(
        controller: controller,
        onPick: openPicker,
        onClear: clearDate,
        icon: Icons.calendar_today,
        iconColor: Colors.grey,
      ),
    );
  }
}

/// The dropdown boxes look like [CustomTextFormField]: white, a grey border,
/// corners 12, no shadow and the same height (52 + the 1.2 border top and
/// bottom). dropdown_button2 adds the menu item padding (14) before the text,
/// so 2 + 14 = 16, the same text start as the text boxes.
ButtonStyleData _boxLikeTextField() => ButtonStyleData(
      height: 54.4,
      padding: const EdgeInsets.only(left: 2, right: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300, width: 1.2),
      ),
    );

class CustomTextFormField extends StatefulWidget {
  final String labelText;
  final String hintText;
  final TextInputType keyboardType;
  final TextEditingController controller;
  final bool obscureText;
  final Widget? suffixIcon;
  final bool readOnly;
  final VoidCallback? onTap;

  const CustomTextFormField({
    super.key,
    required this.labelText,
    required this.hintText,
    required this.keyboardType,
    required this.controller,
    this.obscureText = false,
    this.suffixIcon,
    this.readOnly = false,
    this.onTap,
  });

  @override
  State<CustomTextFormField> createState() => _CustomTextFormFieldState();
}

class _CustomTextFormFieldState extends State<CustomTextFormField> {
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() {
        _isFocused = _focusNode.hasFocus;
      });
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: _isFocused
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ]
              : [],
          border: Border.all(
            color: Colors.grey.shade300,
            width: 1.2,
          ),
        ),
        child: TextFormField(
          focusNode: _focusNode,
          controller: widget.controller,
          keyboardType: widget.keyboardType,
          obscureText: widget.obscureText,
          readOnly: widget.readOnly,
          canRequestFocus: !widget.readOnly,
          onTap: widget.onTap,
          style: const TextStyle(fontSize: 16),
          decoration: InputDecoration(
            // labelText: widget.labelText,
            hintText: widget.hintText,
            suffixIcon: widget.suffixIcon,
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ),
    );
  }
}

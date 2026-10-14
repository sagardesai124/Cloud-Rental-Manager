import 'package:three_zero_two_property/services/app_log.dart';
import 'dart:io';

import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:three_zero_two_property/services/api_helpers.dart';
import '../../../../Model/All_categories_model.dart';
import '../../../../constant/constant.dart';
import '../../../../provider/dateProvider.dart';
import 'package:provider/provider.dart';
import '../../../../widgets/appbar.dart';
import '../../../../widgets/clearable_date_picker.dart';
import '../../../../widgets/clearable_date_suffix.dart';
import '../../../../widgets/custom_drawer.dart';
import '../../../../model/properties.dart';
import '../../../../model/unitsummery_propeties.dart';
import '../../../../repository/fetch_allcategories.dart';
import '../../../../repository/properties_summery.dart';
import '../../../../repository/unit_data.dart';
import '../../../../Model/unit.dart';

class AddApplience extends StatefulWidget {
  Rentals? properties;
  unit_properties? unit;
  unit_appliance? appliance;

  AddApplience({
    this.unit,
    this.properties,
    this.appliance,
  });

  @override
  State<AddApplience> createState() => _AddApplienceState();
}

class _AddApplienceState extends State<AddApplience> {
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

  // Error messages for date validations
  String? _warrantyExpiryError;
  String? _lastMaintenanceDateError;

  // Validate dates
  bool validateDates() {
    bool isValid = true;
    setState(() {
      _warrantyExpiryError = null;
      _lastMaintenanceDateError = null;

      if (_installedDate.text.isNotEmpty && _warrantyExpiry.text.isNotEmpty) {
        DateTime installed =
            DateTime.parse(_convertToApiFormat(_installedDate.text));
        DateTime warranty =
            DateTime.parse(_convertToApiFormat(_warrantyExpiry.text));
        if (warranty.isBefore(installed)) {
          _warrantyExpiryError =
              "Warranty Expiration Date cannot be earlier than Installed Date.";
          isValid = false;
        }
      }

      if (_installedDate.text.isNotEmpty &&
          _lastMaintenanceDate.text.isNotEmpty) {
        DateTime installed =
            DateTime.parse(_convertToApiFormat(_installedDate.text));
        DateTime maintenance =
            DateTime.parse(_convertToApiFormat(_lastMaintenanceDate.text));
        if (maintenance.isBefore(installed)) {
          _lastMaintenanceDateError =
              "Last Maintenance Date cannot be earlier than Installed Date.";
          isValid = false;
        }
      }
    });
    return isValid;
  }

  String? _imageUrl; // Add this line
  bool _imageRemoved = false;

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
    // TODO: implement initState
    super.initState();
    _loadDropdownCategories();
    fetchLeases();
    futureAppliences = UnitData().fetchApplianceData(widget.unit?.unitId ?? "");
  }

//make an funtion for load data from widget
  void loadDataFromWidget() {
    setState(() {

      _name.text = widget.appliance?.applianceName ?? '';
      _description.text = widget.appliance?.applianceDescription ?? '';

      // Convert API date format to user's preferred display format
      final dateProvider = Provider.of<DateProvider>(context, listen: false);
      _installedDate.text = widget.appliance?.installedDate != null &&
              widget.appliance!.installedDate!.isNotEmpty
          ? dateProvider.formatCurrentDate(widget.appliance!.installedDate!)
          : '';
      _warrantyExpiry.text = widget.appliance?.warrantyExpiry != null &&
              widget.appliance!.warrantyExpiry!.isNotEmpty
          ? dateProvider.formatCurrentDate(widget.appliance!.warrantyExpiry!)
          : '';
      _lastMaintenanceDate.text =
          widget.appliance?.lastMaintenanceDate != null &&
                  widget.appliance!.lastMaintenanceDate!.isNotEmpty
              ? dateProvider
                  .formatCurrentDate(widget.appliance!.lastMaintenanceDate!)
              : '';
      _maintenanceNotes.text = widget.appliance?.maintenanceNotes ?? '';
      _type.text = widget.appliance?.type ?? '';
      _model.text = widget.appliance?.model ?? '';
      _serialNumber.text = widget.appliance?.serialNumber ?? '';
      // filter out data from list of dropdown category
      // _dropdownCategories = _dropdownCategories
      //     .where(
      //         (category) => category.categoryId == widget.appliance?.categoryId)
      //     .toList();
      // _selectedDropdownCategory = _dropdownCategories.first;
      // print("Selected category: ${_selectedDropdownCategory?.name}");
      _selectedDropdownCategory = _dropdownCategories.firstWhere(
        (category) => category.categoryId == widget.appliance?.categoryId,
        orElse: () => _dropdownCategories.first,
      );

      // Web parity: derive Type (system_type) from the category.
      final catName = _selectedDropdownCategory?.name ?? '';
      _selectedSystemType = _majorSystemCategories
              .any((m) => m.toLowerCase() == catName.toLowerCase())
          ? 'Major System'
          : 'Appliance';

      brandList = _selectedDropdownCategory?.brands ?? [];
      final existingBrand = widget.appliance?.brand ?? '';
      if (existingBrand.isNotEmpty && !brandList.contains(existingBrand)) {
        _selectedBrand = 'Other';
        _customBrand.text = existingBrand;
      } else {
        _selectedBrand = existingBrand;
      }
      _selectedStatus = widget.appliance?.status ?? '';

      // Load existing image if available
      if (widget.appliance?.applianceImage != null &&
          widget.appliance!.applianceImage!.isNotEmpty) {
        _imageUrl = widget.appliance?.applianceImage;
      }

      // Load existing filters if available and category is HVAC
      if (_selectedDropdownCategory?.name == 'HVAC' &&
          widget.appliance?.filters != null &&
          widget.appliance!.filters!.isNotEmpty) {

        showFiltersSection = true;
        filterControllers.clear();
        for (var filter in widget.appliance!.filters!) {
          Map<String, dynamic> filterMap = filter as Map<String, dynamic>;
          filterControllers.add({
            'name': TextEditingController(
                text: filterMap['filter_name']?.toString() ?? ''),
            'size': TextEditingController(
                text: filterMap['filter_size']?.toString() ?? ''),
          });
        }
      } else {
      }
    });
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

  Future<void> _loadDropdownCategories() async {
    setState(() {
      _isLoadingCategories = true;
    });
    try {
      final cats = await FetchAllcategories().fetchAllCategories();
      setState(() {
        _dropdownCategories = cats;
        _isLoadingCategories = false;
      });
      if (widget.appliance != null) loadDataFromWidget();
    } catch (e) {
      logError('Error fetching categories in AddWorkOrderForMobile: ' +
          e.toString());
      setState(() {
        _isLoadingCategories = false;
      });
    }
  }

  bool isLoading = false;
  bool iserror = false;
  List<allcategories_model> _dropdownCategories = [];
  allcategories_model? _selectedDropdownCategory;
  bool _isLoadingCategories = false;

  List<String> brandList = [];
  List<String> statusList = ['Working', 'Needs Repair', "Out of Service"];

  String? _selectedBrand;
  // Web parity (PropDetails.jsx): a new appliance starts as "Working" and
  // Status is optional. Editing loads the saved status instead.
  String? _selectedStatus = 'Working';
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
  // Major System -> the fixed major-system category set; Appliance -> the rest.
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

  // Web parity: brand list always offers "Other" -> free-text custom brand.
  List<String> get _brandOptions {
    final opts = List<String>.from(brandList);
    if (!opts.contains('Other')) opts.add('Other');
    return opts;
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

  // Helper function to convert display format back to API format (yyyy-MM-dd)
  String _convertToApiFormat(String displayDate) {
    if (displayDate.isEmpty) return "";
    try {
      DateTime? parsedDate;

      // Try to parse the date using common formats
      List<String> dateFormats = [
        'yyyy-MM-dd',
        'yyyy-MMM-dd', // Added for API format like "2025-Aug-22"
        'MM/dd/yyyy',
        'MM-dd-yyyy',
        'dd/MM/yyyy',
        'dd-MM-yyyy'
      ];

      for (String format in dateFormats) {
        try {
          parsedDate = DateFormat(format).parse(displayDate);
          break;
        } catch (e) {
          continue;
        }
      }

      if (parsedDate != null) {
        return DateFormat('yyyy-MM-dd').format(parsedDate);
      }
      return displayDate;
    } catch (e) {
      return displayDate;
    }
  }

  //for image add
  File? _image;
  bool isloading = false;
  List<File> _images = [];
  String? _uploadedFileName;
  List<String> _uploadedFileNames = [];
  List<String> _imageUrls = [];
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
        _images.add(File(image.path));
        _imageRemoved = false;
      });
      _uploadImage(File(image.path));
    }
  }

  Future<void> _uploadImage(File imageFile) async {
    try {
      String? fileName = await uploadImage(imageFile);
      setState(() {
        _uploadedFileNames.add(fileName!);
        _uploadedFileName = fileName;
        _imageUrls.add(fileName!);
      });
    } catch (e) {
      logError('Image upload failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget_302.App_Bar(context: context),
      backgroundColor: Colors.white,
      drawer: CustomDrawer(
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
                      //if appliance is not null then show edit else show add
                      child: Text(
                        widget.appliance != null
                            ? "Edit Infrastructure"
                            : "Add Infrastructure",
                        style: const TextStyle(
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
                      'Infrastructure Name *',
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
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
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
                            // Web parity: changing Type resets Category + Brand.
                            _selectedDropdownCategory = null;
                            brandList = [];
                            _selectedBrand = null;
                            _customBrand.clear();
                            showFiltersSection = false;
                          });
                        },
                        buttonStyleData: ButtonStyleData(
                          height: 45,
                          padding: const EdgeInsets.only(left: 14, right: 14),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            color: Colors.white,
                          ),
                          elevation: 2,
                        ),
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
                          padding: EdgeInsets.only(left: 14, right: 14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Padding(
                    padding: EdgeInsets.only(left: 10),
                    child: Text(
                      'Category *',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 4),
                  //categories dropdwoun
                  Padding(
                    padding: const EdgeInsets.all(8.0),
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
                        // onChanged: _isLoadingCategories
                        //     ? null // disables dropdown while loading
                        //     : (allcategories_model? newValue) {
                        //   setState(() {
                        //     _selectedDropdownCategory = newValue;
                        //     // _showTextField =
                        //     //     newValue?.name == 'Other';
                        //   });
                        // },
                        onChanged: _isLoadingCategories
                            ? null // disables dropdown while loading
                            : (allcategories_model? newValue) {
                                setState(() {
                                  _selectedDropdownCategory = newValue;
                                  brandList =
                                      _selectedDropdownCategory?.brands ?? [];
                                  _selectedBrand = null;
                                  _customBrand.clear();
                                  // Don't show filters section immediately for HVAC
                                  showFiltersSection = false;
                                  // Clear any existing filters
                                  for (var controllers in filterControllers) {
                                    controllers['name']?.dispose();
                                    controllers['size']?.dispose();
                                  }
                                  filterControllers.clear();
                                });
                              },
                        buttonStyleData: ButtonStyleData(
                          height: 45,
                          padding: const EdgeInsets.only(left: 14, right: 14),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            color: Colors.white,
                          ),
                          elevation: 2,
                        ),
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
                          padding: EdgeInsets.only(left: 14, right: 14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...[
                    const Padding(
                      padding: EdgeInsets.only(left: 10),
                      child: Text(
                        'Brand',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton2<String>(
                          isExpanded: true,
                          hint: const Text('Select Brand'),
                          value: _brandOptions.contains(_selectedBrand)
                              ? _selectedBrand
                              : null,
                          items: _brandOptions.map((brand) {
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
                          buttonStyleData: ButtonStyleData(
                            height: 45,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              color: Colors.white,
                            ),
                            elevation: 2,
                          ),
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
                  ],

                  const Padding(
                    padding: EdgeInsets.only(left: 10),
                    child: Text(
                      'Installed Date *',
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
                    padding: const EdgeInsets.all(8.0),
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
                        buttonStyleData: ButtonStyleData(
                          height: 45,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            color: Colors.white,
                          ),
                          elevation: 2,
                        ),
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
                  const SizedBox(height: 5),
                  // Add this after your Status dropdown
                  if (_selectedDropdownCategory?.name == 'HVAC') ...[
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
                    padding: EdgeInsets.only(left: 13),
                    child: Text(
                      'Image',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.only(left: 8, right: 8),
                    child: Column(
                      children: [
                        if ((_imageUrl == null || _imageUrl!.isEmpty) &&
                            _images.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: GestureDetector(
                              onTap: () {
                                _pickImage().then((_) {
                                  setState(() {});
                                });
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
                        if ((_imageUrl != null && _imageUrl!.isNotEmpty) ||
                            _images.isNotEmpty)
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
                                            _images.clear();
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
                  const SizedBox(height: 16),
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
                            if (_name.text.isEmpty ||
                                _installedDate.text.isEmpty ||
                                _selectedSystemType == null ||
                                _selectedDropdownCategory == null ||
                                _selectedStatus == null ||
                                (_selectedBrand == 'Other' &&
                                    _customBrand.text.trim().isEmpty)) {
                              setState(() => iserror = true);
                            } else if (!validateDates()) {
                              // Show error if dates are invalid
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      'Please correct the date validation errors'),
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

                                // Create a single filters list
                                List<Map<String, dynamic>> filters = [];
                                if (_selectedDropdownCategory?.name == 'HVAC' &&
                                    showFiltersSection) {
                                  for (int i = 0;
                                      i < filterControllers.length;
                                      i++) {
                                    final controller = filterControllers[i];
                                    final filterName =
                                        controller['name']?.text.trim() ?? '';
                                    final filterSize =
                                        controller['size']?.text.trim() ?? '';


                                    // Only add filter if either name or size is not empty
                                    if (filterName.isNotEmpty ||
                                        filterSize.isNotEmpty) {
                                      final uniqueId = DateTime.now()
                                          .millisecondsSinceEpoch
                                          .toString();
                                      final filterData = {
                                        "filter_id":
                                            uniqueId, // Add back the filter_id
                                        "filter_name": filterName,
                                        "filter_size": filterSize,
                                      };
                                      filters.add(filterData);

                                      // Add a small delay to ensure unique timestamps for filter_ids
                                      await Future.delayed(
                                          const Duration(milliseconds: 2));
                                    }
                                  }

                                }

                                // Get the base64 image if available
                                String? base64Image;
                                if (_images.isNotEmpty) {
                                  List<int> imageBytes =
                                      await _images.first.readAsBytes();
                                  base64Image = 'data:image/jpeg;base64,' +
                                      base64Encode(imageBytes);
                                } else if (_imageUrl != null &&
                                    _imageUrl!.isNotEmpty) {
                                  base64Image = _imageUrl;
                                }

                                final response = widget.appliance == null
                                    ? await Properies_summery_Repo()
                                        .addappliances(
                                        adminId: id,
                                        unitId: widget.unit?.unitId ?? "",
                                        rentalId: widget.unit?.rentalId ??
                                            widget.properties?.rentalId ??
                                            "",
                                        appliancename: _name.text,
                                        appliancedescription: _description.text,
                                        installeddate: _convertToApiFormat(
                                            _installedDate.text),
                                        type: _type.text,
                                        systemType: _selectedSystemType ?? "",
                                        brand: _selectedBrand == 'Other'
                                            ? _customBrand.text
                                            : (_selectedBrand ?? ""),
                                        model: _model.text,
                                        serialNumber: _serialNumber.text,
                                        warrantyExpiry:
                                            _warrantyExpiry.text.isNotEmpty
                                                ? _convertToApiFormat(
                                                    _warrantyExpiry.text)
                                                : "",
                                        lastMaintenanceDate:
                                            _lastMaintenanceDate.text.isNotEmpty
                                                ? _convertToApiFormat(
                                                    _lastMaintenanceDate.text)
                                                : "",
                                        maintenanceNotes:
                                            _maintenanceNotes.text,
                                        status: _selectedStatus ?? "",
                                        categoryId: _selectedDropdownCategory
                                                ?.categoryId ??
                                            "",
                                        filters:
                                            filters.isNotEmpty ? filters : [],
                                        appliance_image: base64Image ??
                                            "", // Add the base64 image
                                      )
                                    : await Properies_summery_Repo()
                                        .Editappliances(
                                        removeApplianceImages:
                                            _imageRemoved ? 'true' : 'false',
                                        adminId: id,
                                        unitId: widget.unit?.unitId ?? "",
                                        rentalId: widget.unit?.rentalId ??
                                            widget.properties?.rentalId ??
                                            "",
                                        applianceid:
                                            widget.appliance?.applianceId ?? "",
                                        appliancename: _name.text,
                                        appliancedescription: _description.text,
                                        installeddate: _convertToApiFormat(
                                            _installedDate.text),
                                        type: _type.text,
                                        systemType: _selectedSystemType ?? "",
                                        brand: _selectedBrand == 'Other'
                                            ? _customBrand.text
                                            : (_selectedBrand ?? ""),
                                        model: _model.text,
                                        serialNumber: _serialNumber.text,
                                        warrantyExpiry:
                                            _warrantyExpiry.text.isNotEmpty
                                                ? _convertToApiFormat(
                                                    _warrantyExpiry.text)
                                                : "",
                                        lastMaintenanceDate:
                                            _lastMaintenanceDate.text.isNotEmpty
                                                ? _convertToApiFormat(
                                                    _lastMaintenanceDate.text)
                                                : "",
                                        maintenanceNotes:
                                            _maintenanceNotes.text,
                                        status: _selectedStatus ?? "",
                                        categoryId: _selectedDropdownCategory
                                                ?.categoryId ??
                                            "",
                                        filters:
                                            filters.isNotEmpty ? filters : [],
                                        appliance_image: base64Image ??
                                            "", // Add the base64 image
                                      );


                                setState(() {
                                  isLoading = false;
                                  leases.add(unit_appliance(
                                    applianceName: _name.text,
                                    applianceDescription: _description.text,
                                    installedDate: _installedDate.text,
                                    adminId: id,
                                    unitId: widget.unit?.unitId,
                                    type: _type.text,
                                    brand: _selectedBrand,
                                    model: _model.text,
                                    serialNumber: _serialNumber.text,
                                    warrantyExpiry: _warrantyExpiry.text,
                                    lastMaintenanceDate:
                                        _lastMaintenanceDate.text,
                                    maintenanceNotes: _maintenanceNotes.text,
                                    status: _selectedStatus,
                                    categoryId:
                                        _selectedDropdownCategory?.categoryId,
                                    filters: filters,
                                  ));
                                });

                                reload_screen();
                                Navigator.pop(context,
                                    true); // Return true to indicate success
                              } catch (e) {
                                logError('Error adding appliance: $e');
                                setState(() => isLoading = false);
                                final cleanMsg =
                                    friendlyErrorMessage(e);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(cleanMsg)),
                                );
                              }
                            }
                          },
                          child: const Text('Save',
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
                      padding: EdgeInsets.only(
                          top: 8.0, left: 10, right: 10, bottom: 20),
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
    String? errorText;
    if (label == 'Warranty Expiry') {
      errorText = _warrantyExpiryError;
    } else if (label == 'Last Maintenance Date') {
      errorText = _lastMaintenanceDateError;
    }

    // Installed Date is required to save; the other two are optional.
    final bool isRequired = label == 'Installed Date';

    void applyPickedDate(DateTime date) {
      setState(() {
        // Get dateProvider to format the date according to user's preference
        final dateProvider = Provider.of<DateProvider>(context, listen: false);
        // Display format: Use provider's format for user display
        String apiFormatDate = DateFormat('yyyy-MM-dd').format(date);
        controller.text = dateProvider.formatCurrentDate(apiFormatDate);
        validateDates(); // Validate dates after selection
      });
    }

    void openPicker() {
      // If installed date is empty and trying to set warranty or maintenance date
      if (_installedDate.text.isEmpty &&
          (label == 'Warranty Expiry' || label == 'Last Maintenance Date')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select Installed Date first'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      DateTime? initialDate;
      DateTime? firstDate;

      // Set minimum date based on installed date for warranty and maintenance
      if (label == 'Installed Date') {
        // For installed date, allow any date from 2000 to 2100
        firstDate = DateTime(2000);
        initialDate = DateTime.now();
      } else if (_installedDate.text.isNotEmpty &&
          (label == 'Warranty Expiry' || label == 'Last Maintenance Date')) {
        firstDate = DateTime.parse(_convertToApiFormat(_installedDate.text));
        initialDate = firstDate;
      } else {
        firstDate = DateTime(2000);
        initialDate = DateTime.now();
      }

      if (isRequired) {
        showDatePicker(
          context: context,
          initialDate: initialDate,
          firstDate: firstDate,
          lastDate: DateTime(2100),
          builder: (context, child) {
            return Theme(
              data: ThemeData.light().copyWith(
                colorScheme: ColorScheme.light(
                  primary: blueColor,
                  onSurface: Colors.black,
                ),
              ),
              child: child!,
            );
          },
        ).then((date) {
          if (date != null) applyPickedDate(date);
        });
        return;
      }

      // Optional field: the picker offers a "Clear" action (web parity).
      showClearableDatePicker(
        context: context,
        initialDate: initialDate,
        firstDate: firstDate,
        lastDate: DateTime(2100),
        helpText: 'Select $label',
      ).then((result) {
        if (result == null) return; // cancelled — keep the current value
        if (result.cleared) {
          setState(() {
            controller.clear();
            validateDates();
          });
          return;
        }
        applyPickedDate(result.date!);
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: isRequired ? openPicker : null,
          child: AbsorbPointer(
            absorbing: isRequired,
            child: CustomTextFormField(
              labelText: label,
              hintText: 'Select $label',
              controller: controller,
              keyboardType: TextInputType.datetime,
              readOnly: !isRequired,
              onTap: isRequired ? null : openPicker,
              suffixIcon: isRequired
                  ? const Icon(Icons.calendar_today, color: Colors.grey)
                  : ClearableDateSuffix(
                      controller: controller,
                      onPick: openPicker,
                      onClear: () {
                        setState(() {
                          controller.clear();
                          validateDates();
                        });
                      },
                      icon: Icons.calendar_today,
                      iconColor: Colors.grey,
                      iconSize: 20,
                    ),
            ),
          ),
        ),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(left: 12.0, top: 4.0),
            child: Text(
              errorText,
              style: const TextStyle(
                color: Colors.red,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }
}

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

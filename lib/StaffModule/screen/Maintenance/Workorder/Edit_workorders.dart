import 'package:three_zero_two_property/services/app_log.dart';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:camera/camera.dart';
import 'package:intl/intl.dart';
import '../../../../widgets/camera_capture_screen.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart' as video_thumbnail;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:three_zero_two_property/model/Edit_workorder.dart';
import '../../../../widgets/VideoPlayerWidget.dart';
import '../../../repository/workorder.dart';

import '../../../../constant/constant.dart';

import '../../../widgets/appbar.dart';
import '../../../widgets/drawer_tiles.dart';
import '../../../../widgets/titleBar.dart';
import 'package:http/http.dart' as http;
import 'package:three_zero_two_property/services/api_helpers.dart';

import '../../Rental/Tenants/add_tenants.dart';
import '../../../widgets/custom_drawer.dart';
import '../../../../Model/All_categories_model.dart';
import '../../../../repository/fetch_allcategories.dart';
import 'package:provider/provider.dart';
import '../../../../provider/dateProvider.dart';

class ResponsiveEditWorkOrder extends StatefulWidget {
  EditData? property;
  final String workorderId;
  ResponsiveEditWorkOrder(
      {super.key, required this.workorderId, this.property});
  @override
  State<ResponsiveEditWorkOrder> createState() =>
      _ResponsiveEditWorkOrderState();
}

class _ResponsiveEditWorkOrderState extends State<ResponsiveEditWorkOrder> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth > 500) {
            return EditWorkOrderForTablet(
              workorderId: widget.workorderId,
              property: widget.property,
            );
          } else {
            return EditWorkOrderForMobile(
              workorderId: widget.workorderId,
              property: widget.property,
            );
          }
        },
      ),
    );
  }
}

class EditWorkOrderForMobile extends StatefulWidget {
  EditData? property;
  final String workorderId;
  EditWorkOrderForMobile({super.key, required this.workorderId, this.property});
  @override
  State<EditWorkOrderForMobile> createState() => _EditWorkOrderForMobileState();
}

class _EditWorkOrderForMobileState extends State<EditWorkOrderForMobile> {
  final TextEditingController subject = TextEditingController();
  final TextEditingController other = TextEditingController();
  final TextEditingController perform = TextEditingController();
  final TextEditingController vendornote = TextEditingController();
  GlobalKey<FormState> _formkey = GlobalKey<FormState>();
  final TextEditingController _dateController = TextEditingController();
  bool form_valid = false;
  bool _isLoading = true;
  bool _isLoadingvendors = true;
  bool _isLoadingstaff = true;
  bool _isLoadingtenant = false;
  bool _Loading = false;
  Map<String, String> properties = {}; // Mapping of rental_id to rental_address
  Map<String, String> units = {}; // Mapping of unit_id to rental_unit
  String? _selectedPropertyId;
  String? _selectedProperty;
  String? _selectedUnitId;
  String? _selectedUnit;

  //for vendor
  Map<String, String> vendors = {};
  String? _selectedvendorsId;
  String? _selectedVendors;

  //for Staffmember
  Map<String, String> staffs = {};
  String? _selectedstaffId;
  String? _selectedStaffs;
  //for tenants
  Map<String, String> tenants = {};
  String? _selectedtenantId;
  String? _selectedTenants;

  // Dynamic categories
  List<allcategories_model> _dropdownCategories = [];
  allcategories_model? _selectedDropdownCategory;
  bool _isLoadingCategories = false;

  @override
  void initState() {
    super.initState();
    _initializeData();
    _loadProperties();
    _loadVendor();
    _loadStaff();
    partsAndLabor.clear();
    // Typing does not rebuild on its own, so the Update button would stay
    // disabled after a text-only edit without these.
    subject.addListener(_onDirtyFieldChanged);
    perform.addListener(_onDirtyFieldChanged);
    vendornote.addListener(_onDirtyFieldChanged);
    _dateController.addListener(_onDirtyFieldChanged);
  }

  Future<void> _initializeData() async {
    await _loadDropdownCategories();
    await fetchWorkordersDetails(widget.workorderId);
    _ensureCategoryInDropdown();
  }

  Future<void> _loadDropdownCategories() async {
    setState(() {
      _isLoadingCategories = true;
    });
    try {
      final cats = await FetchAllcategories().fetchAllCategories();
      // Sort categories alphabetically by name
      cats.sort((a, b) {
        final nameA = (a.name ?? '').toLowerCase();
        final nameB = (b.name ?? '').toLowerCase();
        return nameA.compareTo(nameB);
      });
      setState(() {
        _dropdownCategories = cats;
        _isLoadingCategories = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingCategories = false;
      });
    }
  }

  void _ensureCategoryInDropdown() {
    if (initialSelectedCategory != null &&
        initialSelectedCategory!.isNotEmpty) {
      final match = _dropdownCategories.firstWhere(
        (cat) => cat.name == initialSelectedCategory,
        orElse: () => allcategories_model(
          categoryId: null,
          name: initialSelectedCategory,
        ),
      );
      if (!_dropdownCategories
          .any((cat) => cat.name == initialSelectedCategory)) {
        setState(() {
          _dropdownCategories.add(match);
        });
        setState(() {
          _selectedDropdownCategory = match;
        });
      } else {
        // Use the actual object from the list to ensure reference equality
        setState(() {
          _selectedDropdownCategory = _dropdownCategories.firstWhere(
            (cat) => cat.name == initialSelectedCategory,
          );
        });
      }
    }
  }

  String? initialSubject;
  String? initialPerform;
  String? initialVendorNote;
  String? initialDate;
  String? initialSelectedPropertyId;
  String? initialSelectedUnitId;
  String? initialSelectedCategory;
  String? initialSelectedStatus;
  String? initialSelectedVendorId;
  String? initialSelectedStaffId;
  String? initialSelectedTenantId;
  String? initialSelectedpriority;
  String? initialSelectedEntry;
  bool? initialSelectedbillable;
  List<String>? initialSelectedimage;
  // Plain values only: holding TextEditingControllers here made every parts
  // comparison a fresh-object comparison (never equal) and leaked a set of
  // controllers per row.
  List<Map<String, String>>? initialSelectedparts;
  // Nothing to diff against until fetchWorkordersDetails has seeded the
  // initial* fields above.
  bool _dirtySnapshotReady = false;
  bool _lastDirty = false;

  Future<void> fetchWorkordersDetails(String workorderId) async {
    EditData fetchedDetails =
        await WorkOrderRepository().fetchWorkordersDetails(workorderId);
    String? entryAllowedString;
    if (fetchedDetails.entryAllowed != null) {
      entryAllowedString = fetchedDetails.entryAllowed! ? 'Yes' : 'No';
    }
    await Future.delayed(const Duration(seconds: 1));
    setState(() {
      if (fetchedDetails.workOrderImages != null) {
        _imageUrls = fetchedDetails.workOrderImages!.map((fileName) {
          return '$fileName';
        }).toList();
      }
      initialSubject = fetchedDetails.workSubject;
      initialPerform = fetchedDetails.workPerformed;
      initialVendorNote = fetchedDetails.vendorNotes;
      initialDate = Provider.of<DateProvider>(context, listen: false)
          .formatCurrentDate(fetchedDetails.date ?? "");
      initialSelectedPropertyId = fetchedDetails.rentalId;
      initialSelectedUnitId = fetchedDetails.unitId;
      initialSelectedCategory = fetchedDetails.workCategory;
      initialSelectedStatus = fetchedDetails.status;
      // Raw id, not .toString(): that turned a null vendor into the literal
      // string "null", which never matched the live null.
      initialSelectedVendorId = fetchedDetails.vendorId;
      initialSelectedStaffId = fetchedDetails.staffmemberId;
      initialSelectedTenantId = fetchedDetails.tenantId;
      initialSelectedpriority = fetchedDetails.priority;
      initialSelectedbillable = fetchedDetails.isBillable!;
      initialSelectedimage = fetchedDetails.workOrderImages;
      // Same encoding as the live _selectedEntry seeded below ('Yes'/'No').
      initialSelectedEntry = entryAllowedString;
      initialSelectedparts =
          fetchedDetails.partsandchargeData?.map<Map<String, String>>((data) {
                return {
                  'qty': data.partsQuantity?.toString() ?? '',
                  'account': data.account ?? '',
                  'description': data.description ?? '',
                  'price': data.partsPrice?.toString() ?? '',
                  'total': data.amount?.toString() ?? '',
                };
              }).toList() ??
              [];
      subject.text = fetchedDetails.workSubject!;
      _selectedstaffId = fetchedDetails.staffData?.staffName;
      _selectedCategory = fetchedDetails.workCategory;
      perform.text = fetchedDetails.workPerformed!;
      _selectedStatus = fetchedDetails.status! ?? "";
      vendornote.text = fetchedDetails.vendorNotes ?? "";
      _dateController.text = Provider.of<DateProvider>(context, listen: false)
          .formatCurrentDate(fetchedDetails.date ?? "");
      _selectedOption = fetchedDetails.priority ?? "";
      _selectedPropertyId = fetchedDetails.rentalId;
      renderId = fetchedDetails.rentalId!;
      _selectedUnitId = fetchedDetails.unitId;
      isChecked = fetchedDetails.isBillable!;
      _selectedvendorsId = fetchedDetails.vendorId == null
          ? null
          : fetchedDetails.vendorId ?? null;
      _selectedstaffId = fetchedDetails.staffmemberId ?? null;
      _selectedtenantId = fetchedDetails.tenantId ?? null;
      _selectedEntry = entryAllowedString;
      partsAndLabor =
          fetchedDetails.partsandchargeData?.map<Map<String, dynamic>>((data) {
                TextEditingController qtyController =
                    TextEditingController(text: data.partsQuantity!.toString());
                TextEditingController priceController =
                    TextEditingController(text: data.partsPrice!.toString());
                TextEditingController totalController =
                    TextEditingController(text: data.amount!.toString());
                TextEditingController subtotalcontroller =
                    TextEditingController();
                qtyController.addListener(() {
                  calculateTotal(qtyController, priceController,
                      totalController, subtotalcontroller);
                });
                priceController.addListener(() {
                  calculateTotal(qtyController, priceController,
                      totalController, subtotalcontroller);
                });
                return {
                  "parts_id": data.partsId,
                  "qtyController": qtyController,
                  "selectedAccount": data.account ?? '',
                  "descriptionController":
                      TextEditingController(text: data.description ?? ''),
                  "priceController": priceController,
                  "totalController": totalController,
                };
              }).toList() ??
              [];
      // Keep the Update button's dirty check in sync with the rows just built.
      for (final row in partsAndLabor) {
        (row['qtyController'] as TextEditingController?)
            ?.addListener(_onDirtyFieldChanged);
        (row['priceController'] as TextEditingController?)
            ?.addListener(_onDirtyFieldChanged);
        (row['descriptionController'] as TextEditingController?)
            ?.addListener(_onDirtyFieldChanged);
      }
      updateTotalAmount();
      _dirtySnapshotReady = true;
    });
    // First load the units for the selected property
    if (_selectedPropertyId != null) {
      await _loadUnits(_selectedPropertyId!);

      // After units are loaded, set the selected unit
      setState(() {
        if (fetchedDetails.unitId != null &&
            fetchedDetails.unitId!.isNotEmpty) {
          _selectedUnitId = fetchedDetails.unitId;
          _selectedUnit = fetchedDetails.unitId;
        }
      });

      // Load tenant data if we have a unit
      if (_selectedUnitId != null) {
        _loadTenant(_selectedPropertyId!, _selectedUnitId!);
      }
    }
  }

  Future<void> _loadProperties() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? adminid = prefs.getString("adminId");
    String? id = prefs.getString("staff_id");
    String? token = prefs.getString('token');
    setState(() {
      _isLoading = true;
    });
    try {
      final response = await http
          // `limit=0` is the server's own no-limit flag; without it the API
          // returns a page of 10 (Rentals.js) and this picker is truncated.
          .get(Uri.parse('${Api_url}/api/rentals/rentals/$adminid?limit=0'), headers: {
        "authorization": "CRM $token",
        "id": "CRM $id",
      });
      if (!mounted) return;
      if (response.statusCode == 200) {
        List jsonResponse = json.decode(response.body)['data'];
        Map<String, String> addresses = {};
        jsonResponse.forEach((data) {
          addresses[data['rental_id'].toString()] =
              data['rental_adress'].toString();
        });
        // Sort properties alphabetically by address (A-Z)
        final sortedEntries = addresses.entries.toList()
          ..sort(
              (a, b) => a.value.toLowerCase().compareTo(b.value.toLowerCase()));
        final sortedAddresses = Map<String, String>.fromEntries(sortedEntries);

        setState(() {
          properties = sortedAddresses;
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load data');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to fetch properties: ${friendlyErrorMessage(e)}')),
      );
    }
  }

  Future<void> _loadUnits(String rentalId) async {
    setState(() {
      _isLoading = true;
      // Clear units and selection when loading new units
      units = {};
      _selectedUnitId = null;
      _selectedUnit = null;
    });

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? adminid = prefs.getString("adminId");
    String? id = prefs.getString("staff_id");
    String? token = prefs.getString('token');

    try {
      final response = await http
          .get(Uri.parse('$Api_url/api/unit/rental_unit/$rentalId'), headers: {
        "authorization": "CRM $token",
        "id": "CRM $id",
      });

      if (!mounted) return;
      if (response.statusCode == 200) {
        List jsonResponse = json.decode(response.body)['data'];
        Map<String, String> unitAddresses = {};

        // Filter out any null or empty unit names
        for (var data in jsonResponse) {
          String unitId = data['unit_id']?.toString() ?? '';
          String unitName = data['rental_unit']?.toString() ?? '';

          if (unitId.isNotEmpty && unitName.trim().isNotEmpty) {
            unitAddresses[unitId] = unitName.trim();
          }
        }


        setState(() {
          units = unitAddresses;
          _isLoading = false;

          // Only keep the selected unit if it exists in the new units
          if (_selectedUnitId != null && !units.containsKey(_selectedUnitId)) {
            _selectedUnitId = null;
          }
        });

        // Load tenant data if we have a valid unit selected
        if (_selectedUnitId != null && units.containsKey(_selectedUnitId)) {
          _loadTenant(rentalId, _selectedUnitId!);
        }
      } else {
        setState(() {
          units = {};
          _selectedUnitId = null;
          _isLoading = false;
        });
      }
    } catch (e) {
      logError('Error loading units: $e');
      setState(() {
        units = {};
        _selectedUnitId = null;
        _isLoading = false;
      });
    }
  }

  //for vendor
  Future<void> _loadVendor() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? adminid = prefs.getString("adminId");
    String? id = prefs.getString("staff_id");
    String? token = prefs.getString('token');
    setState(() {
      _isLoadingvendors = true;
    });
    try {
      final response = await http
          .get(Uri.parse('${Api_url}/api/vendor/vendors/$adminid'), headers: {
        "authorization": "CRM $token",
        "id": "CRM $id",
      });

      if (!mounted) return;
      if (response.statusCode == 200) {
        List jsonResponse = json.decode(response.body)['data'];
        Map<String, String> names = {};
        jsonResponse.forEach((data) {
          names[data['vendor_id'].toString()] = data['vendor_name'].toString();
        });

        setState(() {
          vendors = names;
          _isLoadingvendors = false;
        });
      } else {
        throw Exception('Failed to load data');
      }
    } catch (e) {
      setState(() {
        _isLoadingvendors = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to fetch vendors: ${friendlyErrorMessage(e)}')),
      );
    }
  }

  Future<void> _loadStaff() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? adminid = prefs.getString("adminId");
    String? id = prefs.getString("staff_id");
    String? token = prefs.getString('token');
    setState(() {
      _isLoadingstaff = true;
    });
    try {
      final response = await apiGet(
          Uri.parse('${Api_url}/api/staffmember/staff_member/$adminid'),
          headers: {
            "authorization": "CRM $token",
            "id": "CRM $id",
          });

      if (!mounted) return;
      if (response.statusCode == 200) {
        List jsonResponse = json.decode(response.body)['data'];
        Map<String, String> staffnames = {};
        jsonResponse.forEach((data) {
          staffnames[data['staffmember_id'].toString()] =
              data['staffmember_name'].toString();
        });
        setState(() {
          staffs = staffnames;
          _isLoadingstaff = false;
        });
      } else {
        throw Exception('Failed to load data');
      }
    } catch (e) {
      setState(() {
        _isLoadingstaff = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to fetch vendors: ${friendlyErrorMessage(e)}')),
      );
    }
  }

  Future<void> _loadTenant(String rentalId, String unitId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? adminid = prefs.getString("adminId");
    String? id = prefs.getString("staff_id");
    String? token = prefs.getString('token');
    setState(() {
      _isLoadingtenant = true;
    });
    try {
      final response = await apiGet(
          Uri.parse('${Api_url}/api/leases/get_tenants/$rentalId/$unitId'),
          headers: {
            "authorization": "CRM $token",
            "id": "CRM $id",
          });
      if (!mounted) return;
      if (response.statusCode == 200) {
        List jsonResponse = json.decode(response.body)['data'];
        Map<String, String> tenantsnames = {};
        jsonResponse.forEach((data) {
          tenantsnames[data['tenant_id'].toString()] =
              data['tenant_firstName'].toString() +
                  " " +
                  data['tenant_lastName'].toString();
        });
        setState(() {
          tenants = tenantsnames;
          _isLoadingtenant = false;
        });
      } else {
        throw Exception('Failed to load data');
      }
    } catch (e) {
      setState(() {
        _isLoadingtenant = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to fetch tenants: ${friendlyErrorMessage(e)}')),
      );
    }
  }

  String? _selectedCategory;
  final List<String> _category = [
    'Complaint',
    'Contribution Request',
    'Feedback/Suggestion',
    'General Inquiry',
    'Maintenance Request',
    'Other'
  ];
  String? _selectedEntry;
  final List<String> _entry = [
    'Yes',
    'No',
  ];
  String? _selectedStatus;
  final List<String> _status = [
    'Closed',
    'Completed',
    'In Progress',
    'New',
    'On Hold',
    'Pending'
  ];
  final List<String> _account = [
    'Advertising',
    'Association Fees',
    'Bank Fees',
    'Auto and Travel',
    'Cleaning and Maintenance',
    'Commissions',
    'Depreciation Expense',
    'Insurance',
    'Legal and Professional Fees',
    'Licenses and Permits',
    'Management Fees',
    'Mortgage Interest',
    'Other Expenses',
    'Other Interest Expenses',
    'Postage and Delivery',
    'Repairs',
    'Other Expenses',
  ];

  List<Map<String, dynamic>> rows = [];
  bool _showTextField = false;
  String renderId = '';
  String unitId = '';
  String vendorId = '';
  String StaffId = '';
  String tenantId = '';
  bool isChecked = false;
  //for parts and lebours
  List<Map<String, dynamic>> partsAndLabor = [];

  void addRow() {
    setState(() {
      TextEditingController qtyController = TextEditingController();
      TextEditingController priceController = TextEditingController();
      TextEditingController totalController = TextEditingController();
      TextEditingController subtotalcontroller = TextEditingController();
      TextEditingController descriptionController = TextEditingController();

      qtyController.addListener(() {
        calculateTotal(qtyController, priceController, totalController,
            subtotalcontroller);
      });

      priceController.addListener(() {
        calculateTotal(qtyController, priceController, totalController,
            subtotalcontroller);
      });

      qtyController.addListener(_onDirtyFieldChanged);
      priceController.addListener(_onDirtyFieldChanged);
      descriptionController.addListener(_onDirtyFieldChanged);

      partsAndLabor.add({
        'qtyController': qtyController,
        'accountController': TextEditingController(),
        'descriptionController': descriptionController,
        'priceController': priceController,
        'totalController': totalController,
        'subtotalcontroller': subtotalcontroller,
        'selectedAccount': null,
      });
    });
  }

  @override
  void dispose() {
    // Controllers handed to CustomTextField are released by that widget
    // (CustomTextFieldState in screens/Maintenance/Vendor/add_vendor.dart
    // disposes whatever controller it is given), so releasing them here as
    // well threw "used after being disposed" on close. Only what this
    // screen owns outright is released below.
    subject.removeListener(_onDirtyFieldChanged);
    perform.removeListener(_onDirtyFieldChanged);
    vendornote.removeListener(_onDirtyFieldChanged);
    _dateController.removeListener(_onDirtyFieldChanged);
    other.dispose();
    _dateController.dispose();
    for (final row in partsAndLabor) {
      (row['qtyController'] as TextEditingController?)
          ?.removeListener(_onDirtyFieldChanged);
      (row['priceController'] as TextEditingController?)
          ?.removeListener(_onDirtyFieldChanged);
      (row['descriptionController'] as TextEditingController?)
          ?.removeListener(_onDirtyFieldChanged);
      (row['qtyController'] as TextEditingController?)?.dispose();
      (row['accountController'] as TextEditingController?)?.dispose();
      (row['descriptionController'] as TextEditingController?)?.dispose();
      (row['priceController'] as TextEditingController?)?.dispose();
      (row['totalController'] as TextEditingController?)?.dispose();
      (row['subtotalcontroller'] as TextEditingController?)?.dispose();
    }
    super.dispose();
  }

  void deleteRow(int index) {
    setState(() {
      final row = partsAndLabor[index];
      (row['qtyController'] as TextEditingController?)?.dispose();
      (row['accountController'] as TextEditingController?)?.dispose();
      (row['descriptionController'] as TextEditingController?)?.dispose();
      (row['priceController'] as TextEditingController?)?.dispose();
      (row['totalController'] as TextEditingController?)?.dispose();
      (row['subtotalcontroller'] as TextEditingController?)?.dispose();
      partsAndLabor.removeAt(index);
      updateTotalAmount();
    });
  }

  void calculateTotal(
      TextEditingController qtyController,
      TextEditingController priceController,
      TextEditingController totalController,
      TextEditingController subtotalcontroller) {
    double quantity = double.tryParse(qtyController.text) ?? 0;
    double price = double.tryParse(priceController.text) ?? 0;
    double total = quantity * price;
    totalController.text = total.toStringAsFixed(2);
    double subtotal = total += total;
    subtotalcontroller.text = subtotal.toStringAsFixed(2);
    updateTotalAmount();
  }

  double totalAmount = 0.0;
  void updateTotalAmount() {
    double total = 0.0;
    for (var item in partsAndLabor) {
      double itemTotal = double.tryParse(item['totalController'].text) ?? 0;
      total += itemTotal;
    }
    setState(() {
      totalAmount = total;
    });
  }

  Widget buildRow(int index) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.black),
              onPressed: () {
                deleteRow(index);
              },
            ),
          ),
          const Text(
            "Quantity",
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Color(0xFF101828)),
          ),
          const SizedBox(height: 5),
          CustomTextField(
            hintText: 'Quantity',
            controller: partsAndLabor[index]['qtyController'],
            keyboardType: TextInputType.number,
            showElevation: false,
            borderColor: const Color(0xFFCED4DA),
            borderWidth: 1.5,
          ),
          const SizedBox(height: 10),
          const Text(
            "Account",
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Color(0xFF101828)),
          ),
          const SizedBox(height: 5),
          DropdownButtonHideUnderline(
            child: DropdownButton2<String>(
              isExpanded: true,
              hint: const Text('Select'),
              value: _account.contains(partsAndLabor[index]['selectedAccount'])
                  ? partsAndLabor[index]['selectedAccount']
                  : null,
              items: _account.map((method) {
                return DropdownMenuItem<String>(
                  value: method,
                  child: Text(method),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  partsAndLabor[index]['selectedAccount'] = newValue;
                });
              },
              buttonStyleData: ButtonStyleData(
                height: 45,
                width: double.infinity,
                padding: const EdgeInsets.only(left: 14, right: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8.0),
                  color: Colors.white,
                  border: Border.all(
                    color: const Color(0xFFCED4DA),
                    width: 1.5,
                  ),
                ),
                elevation: 0,
              ),
              iconStyleData: const IconStyleData(
                icon: Icon(
                  Icons.arrow_drop_down,
                ),
                iconSize: 24,
                iconEnabledColor: Color(0xFFb0b6c3),
                iconDisabledColor: Colors.grey,
              ),
              dropdownStyleData: DropdownStyleData(
                maxHeight: 300,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  color: Colors.white,
                ),
                offset: const Offset(0, -5),
                scrollbarTheme: ScrollbarThemeData(
                  radius: const Radius.circular(6),
                  thickness: MaterialStateProperty.all(6),
                  thumbVisibility: MaterialStateProperty.all(true),
                ),
              ),
              menuItemStyleData: const MenuItemStyleData(
                height: 40,
                padding: EdgeInsets.only(left: 14, right: 14),
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            "Description",
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Color(0xFF101828)),
          ),
          const SizedBox(height: 5),
          CustomTextField(
            hintText: 'Description',
            controller: partsAndLabor[index]['descriptionController'],
            keyboardType: TextInputType.text,
            showElevation: false,
            borderColor: const Color(0xFFCED4DA),
            borderWidth: 1.5,
          ),
          const SizedBox(height: 10),
          const Text(
            "Price",
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Color(0xFF101828)),
          ),
          const SizedBox(height: 5),
          CustomTextField(
            hintText: 'Price',
            controller: partsAndLabor[index]['priceController'],
            keyboardType: TextInputType.number,
            showElevation: false,
            borderColor: const Color(0xFFCED4DA),
            borderWidth: 1.5,
          ),
          const SizedBox(height: 10),
          const Text(
            "Total",
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Color(0xFF101828)),
          ),
          const SizedBox(height: 5),
          CustomTextField(
            hintText: 'Total',
            controller: partsAndLabor[index]['totalController'],
            keyboardType: TextInputType.number,
            readOnnly: true,
            showElevation: false,
            borderColor: const Color(0xFFCED4DA),
            borderWidth: 1.5,
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  String _selectedOption = 'button 1';

  void _handleRadioValueChange(String? value) {
    setState(() {
      _selectedOption = value!;
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    DateTime? selectedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(), // Due date cannot be earlier than today
      lastDate: DateTime(2101),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: blueColor, // header background color
              onPrimary: Colors.white, // header text color
              onSurface: blueColor, // body text color
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: blueColor, // button text color
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (selectedDate != null) {
      setState(() {
        _dateController.text = DateFormat(
                Provider.of<DateProvider>(context, listen: false).dateFormat)
            .format(selectedDate);
      });
    }
  }

  //for tenants
  File? _image;
  List<File> _images = [];
  List<File> videofiles = [];
  String? _uploadedFileName;
  List<bool> isvideo = [];
  List<String> _uploadedFileNames = [];

  Future<String?> _generateVideoThumbnail(String videoPath) async {
    final String? thumbPath =
        await video_thumbnail.VideoThumbnail.thumbnailFile(
      video: videoPath,
      thumbnailPath: (await getTemporaryDirectory()).path,
      imageFormat: video_thumbnail.ImageFormat.PNG,
      maxHeight: 80,
      quality: 50,
    );
    return thumbPath;
  }

  Future<String?> uploadImage(File imageFile) async {
    final String uploadUrl = '${image_upload_url}/api/images/upload';

    var request = http.MultipartRequest(
        'POST',
        Uri.parse(
          uploadUrl,
        ));
    // The upload endpoint requires the same auth headers every other call in
    // this file sends; this request never included them, so the server
    // rejected it with a 401 and no file was ever stored.
    final prefs = await SharedPreferences.getInstance();
    final _token = prefs.getString('token');
    final _staffId = prefs.getString('staff_id');
    request.headers.addAll({
      "authorization": "CRM $_token",
      "id": "CRM $_staffId",
    });
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

  // Show image source selection dialog
  void _showImageSourceDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Title
                Text(
                  'Select Media From',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 24),

                // Options Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Gallery Option
                    _buildSourceOption(
                      icon: Icons.photo_library,
                      label: 'Gallery',
                      onTap: () {
                        Navigator.of(context).pop();
                        _pickImageFromSource(ImageSource.gallery);
                      },
                    ),

                    const SizedBox(width: 20),

                    // Camera Option
                    _buildSourceOption(
                      icon: Icons.camera_alt,
                      label: 'Camera',
                      onTap: () {
                        Navigator.of(context).pop();
                        _openCameraInterface();
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  // Build individual source option
  Widget _buildSourceOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[200]!, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: blueColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: blueColor,
                size: 28,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Pick image from specific source
  Future<void> _pickImageFromSource(ImageSource source) async {
    final ImagePicker _picker = ImagePicker();
    final XFile? image = await _picker.pickMedia();

    if (image != null) {
      final File file = File(image.path);
      // Lowercased first: the iPhone camera names videos .MOV (uppercase), which
      // failed this check and made a picked video vanish from the preview list.
      bool isVideo = image.path.toLowerCase().endsWith('.mp4') ||
          image.path.toLowerCase().endsWith('.mov');
      if (isVideo) {
        String? thumbnailPath = await _generateVideoThumbnail(image.path);
        if (thumbnailPath != null) {
          setState(() {
            _images.add(File(thumbnailPath));
            isvideo.add(true);
            videofiles.add(file);
          });
        }
      } else {
        setState(() {
          _images.add(file);
          isvideo.add(false);
          videofiles.add(file);
        });
      }
      _uploadImage(file);
    }
  }

  // Open unified camera interface for both photos and videos
  Future<void> _openCameraInterface() async {
    try {
      // Get available cameras
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        _showErrorDialog('No cameras found on this device');
        return;
      }

      // Use the first available camera (usually back camera)
      final camera = cameras.first;

      // Navigate to camera screen
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CameraCaptureScreen(
            camera: camera,
            onImageCaptured: (File imageFile) {
              // Handle captured image
              setState(() {
                _images.add(imageFile);
                isvideo.add(false);
                videofiles.add(imageFile);
              });
              _uploadImage(imageFile);
            },
            onVideoCaptured: (File videoFile) async {
              // Handle captured video
              String? thumbnailPath =
                  await _generateVideoThumbnail(videoFile.path);
              if (thumbnailPath != null) {
                setState(() {
                  _images.add(File(thumbnailPath));
                  isvideo.add(true);
                  videofiles.add(videoFile);
                });
              }
              _uploadImage(videoFile);
            },
          ),
        ),
      );
    } catch (e) {
      _showErrorDialog('Failed to open camera: $e');
    }
  }

  // Show error dialog
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage() async {
    final ImagePicker _picker = ImagePicker();
    final XFile? image = await _picker.pickMedia();

    if (image != null) {
      setState(() {
        _image = File(image.path);
        _images.add(File(image.path));
      });
      _uploadImage(File(image.path));
    }
  }

  Future<void> _uploadImage(File imageFile) async {
    try {
      String? fileName = await uploadImage(imageFile);
      if (fileName == null) {
        Fluttertoast.showToast(msg: 'Failed to upload image');
        return;
      }
      setState(() {
        _uploadedFileNames.add(fileName);
        _uploadedFileName = fileName;
        _imageUrls.add(fileName);
      });
    } catch (e) {
      // Surface the failure — this used to fail silently, leaving the upload
      // box unchanged with no indication anything went wrong.
      Fluttertoast.showToast(msg: 'Failed to upload image');
      logError('Image upload failed: $e');
    }
  }

  List<String> _imageUrls = [];

  bool isVideo(String url) {
    // .mov included: the iPhone camera records .mov by default, and the picker
    // already accepts both (`.mp4` || `.mov`). Checking only .mp4 here meant a
    // camera-recorded video was treated as a photo and failed to render.
    final lower = url.toLowerCase();
    return lower.endsWith(".mp4") || lower.endsWith(".mov");
  }

  void _showVideoDialog(String videoFile) {
    showDialog(
      context: context,
      builder: (context) {
        return Container(
          child: VideoPlayerDialog(
            videoUrl: videoFile,
          ),
        );
      },
    );
  }

  void _showImageDialog(
      dynamic imageFile, int imageIndex, File? originalFile, bool isVideo) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: Container(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with title and close button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Preview',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: blueColor,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: blueColor, width: 1),
                        ),
                        child: Icon(
                          Icons.close,
                          color: blueColor,
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20),
                // Image with rounded corners and camera icon overlay
                Stack(
                  alignment: Alignment.center,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: imageFile is String
                          ? Image.network(
                              imageFile,
                              fit: BoxFit.cover,
                              height: 300,
                              width: 300,
                            )
                          : Image.file(
                              imageFile,
                              fit: BoxFit.cover,
                              height: 300,
                              width: 300,
                            ),
                    ),
                    // Camera icon overlay for updating image
                    Positioned(
                      top: 10,
                      right: 5,
                      child: GestureDetector(
                        onTap: () async {
                          final ImagePicker _picker = ImagePicker();
                          final XFile? image = await _picker.pickMedia();

                          if (image != null) {
                            final File newFile = File(image.path);
                            // Lowercased: iPhone camera videos are .MOV.
                            bool isNewVideo =
                                image.path.toLowerCase().endsWith('.mp4') ||
                                    image.path.toLowerCase().endsWith('.mov');

                            if (isNewVideo) {
                              String? thumbnailPath =
                                  await _generateVideoThumbnail(image.path);
                              if (thumbnailPath != null) {
                                Navigator.of(context).pop();
                                _showImageDialog(File(thumbnailPath),
                                    imageIndex, newFile, true);
                              }
                            } else {
                              Navigator.of(context).pop();
                              _showImageDialog(
                                  newFile, imageIndex, newFile, false);
                            }
                          }
                        },
                        child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              //  color: Colors.white.withOpacity(0.8),
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Image.asset(
                                "assets/icons/bxs_edit.png",
                                fit: BoxFit.cover,
                                color: Colors.white,
                                height: 10,
                                width: 10,
                              ),
                            )
                            // Icon(
                            //   Icons.camera_alt,
                            //   color: Colors.white,
                            //   size: 20,
                            // ),
                            ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20),
                // Action buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: blueColor,
                        side: BorderSide(color: blueColor, width: 1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding:
                            EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: blueColor),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        Navigator.of(context).pop();

                        // The grid renders _imageUrls, so nothing changes on
                        // screen until the new file has actually landed. The
                        // old path wrote _images by an _imageUrls index (a list
                        // never seeded on Edit) and never wrote the new
                        // filename into _imageUrls, so a replacement was lost
                        // even when the upload succeeded.
                        if (imageIndex >= _imageUrls.length) return;
                        final File? newFile =
                            originalFile ?? (imageFile is File ? imageFile : null);
                        if (newFile == null) return;
                        final String oldName = _imageUrls[imageIndex];

                        // Upload the new image
                        try {
                          String? fileName = await uploadImage(newFile);
                          if (!mounted) return;
                          if (fileName == null) {
                            throw Exception('upload returned no filename');
                          }
                          // Rows may have shifted while uploading; find our own.
                          final int row = _imageUrls.indexOf(oldName);
                          if (row != -1) {
                            setState(() {
                              _imageUrls[row] = fileName;
                            });
                          }
                        } catch (e) {
                          logError('Image upload failed: $e');
                          if (!mounted) return;
                          Fluttertoast.showToast(msg: 'Failed to upload image');
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[100],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding:
                            EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                      ),
                      child: Text(
                        'Update',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.green),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    double screenHeight = MediaQuery.of(context).size.height;
    double screenWidth = MediaQuery.of(context).size.height;
    final bool canSave = _hasWorkOrderChanges();
    _lastDirty = canSave;
    return Scaffold(
      appBar: widget_302_Staff.App_Bar(context: context),
      backgroundColor: Colors.white,
      drawer: CustomDrawerStaff(
        currentpage: "Work Orders",
        dropdown: true,
      ),
      body: Form(
        key: _formkey,
        child: Container(
          color: Colors.white,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(
                  height: 25,
                ),
                titleBar(
                  width: MediaQuery.of(context).size.width * .91,
                  title: 'Edit Work Order',
                ),
                const SizedBox(
                  height: 15,
                ),
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Container(
                    width: double.infinity,
                    // height: !form_valid ? 860 : 830,
                    decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10.0),
                        border: Border.all(
                          color: Color(0xFFDBE0E5),
                        )),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Subject *',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF101828))),
                          const SizedBox(
                            height: 10,
                          ),
                          CustomTextField(
                            keyboardType: TextInputType.text,
                            hintText: 'Add subject',
                            controller: subject,
                            showElevation: false,
                            borderColor: const Color(0xFFCED4DA),
                            borderWidth: 1.5,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'please enter the subject';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(
                            height: 10,
                          ),
                          const Text('Photos (Maximum of 10) ',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF101828))),
                          const SizedBox(
                            height: 10,
                          ),
                          if (_imageUrls.isEmpty)
                            GestureDetector(
                              onTap: () {
                                _showImageSourceDialog();
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
                                    // Icon(Icons.upload,
                                    //     size: 40, color: Colors.grey[600]),
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
                          if (_imageUrls.isEmpty)
                            const SizedBox(
                              height: 10,
                            ),
                          _imageUrls.isNotEmpty
                              ? Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                        color: Colors.grey.shade300,
                                        style: BorderStyle.solid),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (_imageUrls.length < 10)
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.end,
                                          // crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            GestureDetector(
                                                onTap: () {
                                                  _showImageSourceDialog();
                                                },
                                                child: Container(
                                                    height: 20,
                                                    width: 20,
                                                    decoration: BoxDecoration(
                                                      color: blueColor,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              7),
                                                    ),
                                                    child: const Icon(
                                                      Icons.add,
                                                      color: Colors.white,
                                                      size: 15,
                                                    ))),
                                          ],
                                        ),
                                      const SizedBox(
                                        height: 15,
                                      ),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Container(
                                              //color: Colors.blue,
                                              child: Wrap(
                                                spacing:
                                                    8.0, // Horizontal spacing between items
                                                runSpacing:
                                                    8.0, // Vertical spacing between rows
                                                children: List.generate(
                                                  _imageUrls.length,
                                                  (index) {
                                                    bool isMp4 = isVideo(
                                                        _imageUrls[index]);
                                                    return Container(
                                                      // color: Colors.green,
                                                      width: 85,
                                                      child: Column(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .start,
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Row(
                                                            children: [
                                                              const SizedBox(
                                                                  width: 60),
                                                              GestureDetector(
                                                                onTap: () {
                                                                  setState(() {
                                                                    _imageUrls
                                                                        .removeAt(
                                                                            index);
                                                                  });
                                                                },
                                                                child:
                                                                    const Icon(
                                                                  Icons.close,
                                                                  color: Colors
                                                                      .grey,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                          Row(
                                                            mainAxisAlignment:
                                                                MainAxisAlignment
                                                                    .start,
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                              isMp4
                                                                  ? Container(
                                                                      height:
                                                                          80,
                                                                      width: 80,
                                                                      child:
                                                                          GestureDetector(
                                                                        onTap:
                                                                            () {
                                                                          _showVideoDialog(
                                                                              '$image_url${_imageUrls[index]}');
                                                                        },
                                                                        child:
                                                                            Stack(
                                                                          alignment:
                                                                              Alignment.center,
                                                                          children: [
                                                                            // Image.file(
                                                                            // File(snapshot.data!),
                                                                            // height:80,
                                                                            // width: 80,
                                                                            // fit: BoxFit.cover,
                                                                            // ),
                                                                            VideoItem(url: '$image_url${_imageUrls[index]}'),
                                                                            const Icon(Icons.play_circle_fill,
                                                                                color: Colors.white,
                                                                                size: 40),
                                                                          ],
                                                                        ),
                                                                      ),
                                                                    )
                                                                  : GestureDetector(
                                                                      onTap:
                                                                          () {
                                                                        _showImageDialog(
                                                                            "$image_url${_imageUrls[index]}",
                                                                            index,
                                                                            null,
                                                                            false);
                                                                      },
                                                                      child:
                                                                          Stack(
                                                                        alignment:
                                                                            Alignment.center,
                                                                        children: [
                                                                          Image
                                                                              .network(
                                                                            "$image_url${_imageUrls[index]}",
                                                                            height:
                                                                                80,
                                                                            width:
                                                                                80,
                                                                            fit:
                                                                                BoxFit.cover,
                                                                            errorBuilder: (context,
                                                                                error,
                                                                                stackTrace) {
                                                                              return const Icon(Icons.error);
                                                                            },
                                                                          ),
                                                                          Positioned(
                                                                            top:
                                                                                28,
                                                                            right:
                                                                                28,
                                                                            child:
                                                                                Container(
                                                                              padding: EdgeInsets.all(4),
                                                                              decoration: BoxDecoration(
                                                                                color: Colors.black54,
                                                                                borderRadius: BorderRadius.circular(15),
                                                                              ),
                                                                              child: Icon(
                                                                                Icons.visibility,
                                                                                color: Colors.white,
                                                                                size: 16,
                                                                              ),
                                                                            ),
                                                                          ),
                                                                        ],
                                                                      ),
                                                                    ),
                                                            ],
                                                          ),
                                                        ],
                                                      ),
                                                    );
                                                  },
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                )
                              : Container(),
                          // _imageUrls.isNotEmpty
                          //     ? Row(
                          //         children: [
                          //           Expanded(
                          //             child: Container(
                          //               child: Wrap(
                          //                 spacing:
                          //                     8.0, // Horizontal spacing between items
                          //                 runSpacing:
                          //                     8.0, // Vertical spacing between rows
                          //                 children: List.generate(
                          //                   _imageUrls.length,
                          //                   (index) {
                          //                     return Container(
                          //                       width: 85,
                          //                       child: Column(
                          //                         mainAxisAlignment:
                          //                             MainAxisAlignment.start,
                          //                         crossAxisAlignment:
                          //                             CrossAxisAlignment
                          //                                 .start,
                          //                         children: [
                          //                           Row(
                          //                             children: [
                          //                               SizedBox(width: 60),
                          //                               GestureDetector(
                          //                                 onTap: () {
                          //                                   setState(() {
                          //                                     _imageUrls
                          //                                         .removeAt(
                          //                                             index);
                          //                                   });
                          //                                 },
                          //                                 child: Icon(
                          //                                   Icons.close,
                          //                                   color:
                          //                                       Colors.grey,
                          //                                 ),
                          //                               ),
                          //                             ],
                          //                           ),
                          //                           Row(
                          //                             mainAxisAlignment:
                          //                                 MainAxisAlignment
                          //                                     .start,
                          //                             crossAxisAlignment:
                          //                                 CrossAxisAlignment
                          //                                     .start,
                          //                             children: [
                          //                               Container(
                          //                                 child:
                          //                                     Image.network(
                          //                                   "$image_url${_imageUrls[index]}",
                          //                                   height: 80,
                          //                                   width: 80,
                          //                                   fit: BoxFit.cover,
                          //                                   errorBuilder:
                          //                                       (context,
                          //                                           error,
                          //                                           stackTrace) {
                          //                                     return Icon(Icons
                          //                                         .error); // Placeholder for errors
                          //                                   },
                          //                                 ),
                          //                               ),
                          //                             ],
                          //                           ),
                          //                         ],
                          //                       ),
                          //                     );
                          //                   },
                          //                 ),
                          //               ),
                          //             ),
                          //           ),
                          //         ],
                          //       )
                          //     : Center(child: Text("No images selected.")),
                          const SizedBox(
                            height: 10,
                          ),
                          const Text('Property *',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF101828))),
                          const SizedBox(
                            height: 2,
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              FormField<String>(
                                validator: (value) {
                                  if (_selectedPropertyId == null) {
                                    return 'Please select an option';
                                  }
                                  return null;
                                },
                                builder: (FormFieldState<String> state) {
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      DropdownButtonHideUnderline(
                                        child: DropdownButtonFormField2<String>(
                                          decoration: const InputDecoration(
                                            border: InputBorder.none,
                                            contentPadding: EdgeInsets.only(top: 12),
                                          ),
                                          isExpanded: true,
                                          hint: const Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  'Select Property',
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w400,
                                                    color: Color(0xFFb0b6c3),
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                          items:
                                              properties.keys.map((rentalId) {
                                            return DropdownMenuItem<String>(
                                              value: rentalId,
                                              child: Text(
                                                properties[rentalId]!,
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w400,
                                                  color: Colors.black87,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            );
                                          }).toList(),
                                          value: properties.containsKey(
                                                  _selectedPropertyId)
                                              ? _selectedPropertyId
                                              : null,
                                          onChanged: (value) {
                                            setState(() {
                                              _selectedUnitId = null;
                                              _selectedPropertyId = value;
                                              _selectedProperty = properties[
                                                  value]; // Store selected rental address

                                              renderId = value.toString();
                                              if (value != null) {
                                                _loadUnits(value);
                                              }
                                              state.didChange(value);
                                            });
                                            state.reset();
                                          },
                                          buttonStyleData: ButtonStyleData(
                                            height: 45,
                                            width: 160,
                                            padding: const EdgeInsets.only(
                                                left: 14, right: 14),
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(8.0),
                                              color: Colors.white,
                                              border: Border.all(
                                                color: const Color(0xFFCED4DA),
                                                width: 1.5,
                                              ),
                                            ),
                                            elevation: 0,
                                          ),
                                          iconStyleData: const IconStyleData(
                                            icon: Icon(
                                              Icons.arrow_drop_down,
                                            ),
                                            iconSize: 24,
                                            iconEnabledColor: Color(0xFFb0b6c3),
                                            iconDisabledColor: Colors.grey,
                                          ),
                                          dropdownStyleData: DropdownStyleData(
                                            maxHeight: 300,
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              color: Colors.white,
                                            ),
                                            offset: const Offset(0, -5),
                                            scrollbarTheme: ScrollbarThemeData(
                                              radius: const Radius.circular(6),
                                              thickness:
                                                  MaterialStateProperty.all(6),
                                              thumbVisibility:
                                                  MaterialStateProperty.all(
                                                      true),
                                            ),
                                          ),
                                          menuItemStyleData:
                                              const MenuItemStyleData(
                                            height: 40,
                                            padding: EdgeInsets.only(
                                                left: 14, right: 14),
                                          ),
                                        ),
                                      ),
                                      if (state.hasError)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                              left: 0, top: 4),
                                          child: Text(
                                            state.errorText!,
                                            style: const TextStyle(
                                              color: Colors.red,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ),
                                    ],
                                  );
                                },
                              ),
                              const SizedBox(height: 10),
                              units.isNotEmpty &&
                                      units.values
                                          .any((unit) => unit.trim().isNotEmpty)
                                  ? const Text('Unit *',
                                      style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF101828)))
                                  : Container(),
                              const SizedBox(height: 2),
                              units.isNotEmpty &&
                                      units.values
                                          .any((unit) => unit.trim().isNotEmpty)
                                  ? FormField<String>(
                                      validator: (value) {
                                        if (_selectedUnitId == null ||
                                            _selectedUnitId!.isEmpty) {
                                          return 'Please select a unit';
                                        }
                                        return null;
                                      },
                                      builder: (FormFieldState<String> state) {
                                        return Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            DropdownButtonHideUnderline(
                                              child: DropdownButtonFormField2<
                                                  String>(
                                                decoration: const InputDecoration(
                                                  border: InputBorder.none,
                                                  contentPadding: EdgeInsets.only(top: 12),
                                                ),
                                                isExpanded: true,
                                                hint: const Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        'Select Unit',
                                                        style: TextStyle(
                                                          fontSize: 14,
                                                          fontWeight:
                                                              FontWeight.w400,
                                                          color:
                                                              Color(0xFFb0b6c3),
                                                        ),
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                items: units.keys.map((unitId) {
                                                  return DropdownMenuItem<
                                                      String>(
                                                    value: unitId,
                                                    child: Text(
                                                      units[unitId]!,
                                                      style: const TextStyle(
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.w400,
                                                        color: Colors.black87,
                                                      ),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  );
                                                }).toList(),
                                                value: _selectedUnitId
                                                        .toString()
                                                        .isNotEmpty
                                                    ? _selectedUnitId
                                                    : null,
                                                onChanged: (value) {
                                                  setState(() {
                                                    unitId = value.toString();
                                                    _selectedUnitId = value;
                                                    _selectedUnit = units[
                                                        value]; // Store selected rental_unit
                                                    _loadTenant(
                                                        _selectedPropertyId!,
                                                        unitId);
                                                    state.didChange(value);
                                                  });
                                                  state.reset();
                                                  // Notify form field of the change
                                                },
                                                buttonStyleData:
                                                    ButtonStyleData(
                                                  height: 45,
                                                  width: 160,
                                                  padding:
                                                      const EdgeInsets.only(
                                                          left: 14, right: 14),
                                                  decoration: BoxDecoration(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8.0),
                                                    color: Colors.white,
                                                    border: Border.all(
                                                      color: const Color(
                                                          0xFFCED4DA),
                                                      width: 1.5,
                                                    ),
                                                  ),
                                                  elevation: 0,
                                                ),
                                                iconStyleData:
                                                    const IconStyleData(
                                                  icon: Icon(
                                                      Icons.arrow_drop_down),
                                                  iconSize: 24,
                                                  iconEnabledColor:
                                                      Color(0xFFb0b6c3),
                                                  iconDisabledColor:
                                                      Colors.grey,
                                                ),
                                                dropdownStyleData:
                                                    DropdownStyleData(
                                                  maxHeight: 300,
                                                  decoration: BoxDecoration(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            6),
                                                    color: Colors.white,
                                                  ),
                                                  offset: const Offset(0, -5),
                                                  scrollbarTheme:
                                                      ScrollbarThemeData(
                                                    radius:
                                                        const Radius.circular(
                                                            6),
                                                    thickness:
                                                        MaterialStateProperty
                                                            .all(6),
                                                    thumbVisibility:
                                                        MaterialStateProperty
                                                            .all(true),
                                                  ),
                                                ),
                                                menuItemStyleData:
                                                    const MenuItemStyleData(
                                                  height: 40,
                                                  padding: EdgeInsets.only(
                                                      left: 14, right: 14),
                                                ),
                                              ),
                                            ),
                                            if (state.hasError)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                    left: 0, top: 4),
                                                child: Text(
                                                  state.errorText!,
                                                  style: const TextStyle(
                                                    color: Colors.red,
                                                    fontSize: 11,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        );
                                      },
                                    )
                                  : Container(),
                            ],
                          ),
                          const SizedBox(
                            height: 10,
                          ),
                          const Text('Category',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF101828))),
                          const SizedBox(
                            height: 10,
                          ),
                          SizedBox(
                            width: double.infinity,
                            child: DropdownButtonHideUnderline(
                            child: DropdownButton2<allcategories_model>(
                              isExpanded: true,
                              hint: Text(_isLoadingCategories
                                  ? 'Select here'
                                  : 'Select here',style: TextStyle(fontSize: 14, color: Color(0xFFb0b6c3),fontWeight: FontWeight.w400),),
                              value: _selectedDropdownCategory != null
                                  ? _dropdownCategories.firstWhere(
                                      (cat) =>
                                          cat.name ==
                                              _selectedDropdownCategory?.name ||
                                          (cat.categoryId != null &&
                                              cat.categoryId ==
                                                  _selectedDropdownCategory
                                                      ?.categoryId),
                                      orElse: () => _selectedDropdownCategory!,
                                    )
                                  : null,
                              items: _dropdownCategories.map((cat) {
                                return DropdownMenuItem<allcategories_model>(
                                  value: cat,
                                  child: Text(cat.name ?? ''),
                                );
                              }).toList(),
                              onChanged: _isLoadingCategories
                                  ? null // disables dropdown while loading
                                  : (allcategories_model? newValue) {
                                      setState(() {
                                        _selectedDropdownCategory = newValue;
                                        _showTextField =
                                            newValue?.name == 'Other';
                                      });
                                    },
                              buttonStyleData: ButtonStyleData(
                                height: 45,
                                padding:
                                    const EdgeInsets.only(right: 14),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8.0),
                                  color: Colors.white,
                                  border: Border.all(
                                    color: const Color(0xFFCED4DA),
                                    width: 1.5,
                                  ),
                                ),
                                elevation: 0,
                              ),
                              iconStyleData: const IconStyleData(
                                icon: Icon(Icons.arrow_drop_down),
                                iconSize: 24,
                                iconEnabledColor: Color(0xFFb0b6c3),
                                iconDisabledColor: Colors.grey,
                              ),
                              dropdownStyleData: DropdownStyleData(
                                maxHeight: 300,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(6),
                                  color: Colors.white,
                                ),
                                offset: const Offset(0, -5),
                                scrollbarTheme: ScrollbarThemeData(
                                  radius: const Radius.circular(6),
                                  thickness: MaterialStateProperty.all(6),
                                  thumbVisibility:
                                      MaterialStateProperty.all(true),
                                ),
                              ),
                              menuItemStyleData: const MenuItemStyleData(
                                height: 40,
                                padding: EdgeInsets.only(left: 14, right: 14),
                              ),
                            ),
                          ),
                          ),
                          // FormField<String>(
                          //   validator: (value) {
                          //     if (_selectedCategory == null) {
                          //       return 'Please select a category';
                          //     }
                          //     return null;
                          //   },
                          //   builder: (FormFieldState<String> state) {
                          //     return Column(
                          //       crossAxisAlignment: CrossAxisAlignment.start,
                          //       children: [
                          //         DropdownButtonHideUnderline(
                          //           child: DropdownButton2<String>(
                          //             isExpanded: true,
                          //             hint: Text('Select Category'),
                          //             value: _selectedCategory,
                          //             items: _category.map((method) {
                          //               return DropdownMenuItem<String>(
                          //                 value: method,
                          //                 child: Text(method),
                          //               );
                          //             }).toList(),
                          //             onChanged: (String? newValue) {
                          //               setState(() {
                          //                 state.didChange(
                          //                     newValue); // Notify form field of the change
                          //                 _selectedCategory = newValue;
                          //                 _showTextField =
                          //                     _selectedCategory == 'Other';
                          //               });
                          //               state.reset();
                          //               print(
                          //                   'Selected category: $_selectedCategory');
                          //             },
                          //             buttonStyleData: ButtonStyleData(
                          //               height: 45,
                          //               padding: const EdgeInsets.only(
                          //                   left: 14, right: 14),
                          //               decoration: BoxDecoration(
                          //                 borderRadius:
                          //                     BorderRadius.circular(6),
                          //                 color: Colors.white,
                          //               ),
                          //               elevation: 2,
                          //             ),
                          //             iconStyleData: const IconStyleData(
                          //               icon: Icon(
                          //                 Icons.arrow_drop_down,
                          //               ),
                          //               iconSize: 24,
                          //               iconEnabledColor: Color(0xFFb0b6c3),
                          //               iconDisabledColor: Colors.grey,
                          //             ),
                          //             dropdownStyleData: DropdownStyleData(
                          //               decoration: BoxDecoration(
                          //                 borderRadius:
                          //                     BorderRadius.circular(6),
                          //                 color: Colors.white,
                          //               ),
                          //               scrollbarTheme: ScrollbarThemeData(
                          //                 radius: const Radius.circular(6),
                          //                 thickness:
                          //                     MaterialStateProperty.all(6),
                          //                 thumbVisibility:
                          //                     MaterialStateProperty.all(true),
                          //               ),
                          //             ),
                          //             menuItemStyleData:
                          //                 const MenuItemStyleData(
                          //               height: 50,
                          //               padding: EdgeInsets.only(
                          //                   left: 14, right: 14),
                          //             ),
                          //           ),
                          //         ),
                          //         if (state.hasError)
                          //           Padding(
                          //             padding: const EdgeInsets.only(
                          //                 left: 14, top: 8),
                          //             child: Text(
                          //               state.errorText!,
                          //               style: const TextStyle(
                          //                 color: Colors.red,
                          //                 fontSize: 12,
                          //               ),
                          //             ),
                          //           ),
                          //       ],
                          //     );
                          //   },
                          // ),
                          _showTextField
                              ? Padding(
                                  padding: const EdgeInsets.only(
                                      top: 10, bottom: 10),
                                  child: buildTextField('Other Category',
                                      'Enter Other Category', other),
                                )
                              : Container(),
                          const SizedBox(
                            height: 10,
                          ),
                          const Text('Assigned To *',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF101828))),
                          const SizedBox(
                            height: 2,
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              FormField<String>(
                                validator: (value) {
                                  if (_selectedstaffId == null) {
                                    return 'Please select an option';
                                  }
                                  return null;
                                },
                                builder: (FormFieldState<String> state) {
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      DropdownButtonHideUnderline(
                                        child: DropdownButtonFormField2<String>(
                                          decoration: const InputDecoration(
                                            border: InputBorder.none,
                                            contentPadding: EdgeInsets.only(top: 12),
                                            hintText: 'Select here',
                                            hintStyle: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w400,
                                              color: Color(0xFFb0b6c3),
                                            ),
                                          ),
                                          isExpanded: true,
                                          hint: const Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  'Select here',
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w400,
                                                    color: Color(0xFFb0b6c3),
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                          items: (staffs.keys.toList()
                                                ..sort((a, b) => (staffs[a] ??
                                                        '')
                                                    .toLowerCase()
                                                    .compareTo((staffs[b] ?? '')
                                                        .toLowerCase())))
                                              .map((staffmemberId) {
                                            return DropdownMenuItem<String>(
                                              value: staffmemberId,
                                              child: Text(
                                                staffs[staffmemberId]!,
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w400,
                                                  color: Colors.black87,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            );
                                          }).toList(),
                                          value: staffs
                                                  .containsKey(_selectedstaffId)
                                              ? _selectedstaffId
                                              : null,
                                          onChanged: (value) {
                                            setState(() {
                                              // Notify form field of the change
                                              _selectedstaffId = value;
                                              _selectedStaffs = staffs[
                                                  value]; // Store selected staff
                                              StaffId = value.toString();

                                              // Units belong to the property, not the staff
                                              // member — reloading here cleared the unit.
                                              state.didChange(value);
                                            });
                                            state.reset();
                                          },
                                          buttonStyleData: ButtonStyleData(
                                            height: 45,
                                            width: 160,
                                            padding: const EdgeInsets.only(
                                                left: 14, right: 14),
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(8.0),
                                              color: Colors.white,
                                              border: Border.all(
                                                color: const Color(0xFFCED4DA),
                                                width: 1.5,
                                              ),
                                            ),
                                            elevation: 0,
                                          ),
                                          iconStyleData: const IconStyleData(
                                            icon: Icon(
                                              Icons.arrow_drop_down,
                                            ),
                                            iconSize: 24,
                                            iconEnabledColor: Color(0xFFb0b6c3),
                                            iconDisabledColor: Colors.grey,
                                          ),
                                          dropdownStyleData: DropdownStyleData(
                                            maxHeight: 300,
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              color: Colors.white,
                                            ),
                                            offset: const Offset(0, -5),
                                            scrollbarTheme: ScrollbarThemeData(
                                              radius: const Radius.circular(6),
                                              thickness:
                                                  MaterialStateProperty.all(6),
                                              thumbVisibility:
                                                  MaterialStateProperty.all(
                                                      true),
                                            ),
                                          ),
                                          menuItemStyleData:
                                              const MenuItemStyleData(
                                            height: 40,
                                            padding: EdgeInsets.only(
                                                left: 14, right: 14),
                                          ),
                                        ),
                                      ),
                                      if (state.hasError)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                              left: 0, top: 4),
                                          child: Text(
                                            state.errorText!,
                                            style: const TextStyle(
                                              color: Colors.red,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                          const SizedBox(
                            height: 10,
                          ),
                          const Text('Entry Allowed ',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF101828))),
                          const SizedBox(
                            height: 10,
                          ),
                          SizedBox(
                            width: double.infinity,
                            child: DropdownButtonHideUnderline(
                            child: DropdownButton2<String>(
                              isExpanded: true,
                              hint: const Text('Select here',style: TextStyle(fontSize: 14, color: Color(0xFFb0b6c3),fontWeight: FontWeight.w400),),
                              value: _selectedEntry,
                              items: _entry.map((method) {
                                return DropdownMenuItem<String>(
                                  value: method,
                                  child: Text(method),
                                );
                              }).toList(),
                              onChanged: (String? newValue) {
                                setState(() {
                                  _selectedEntry = newValue;
                                  //_selectedPaymentMethod = addRow();
                                  // if(_selectedCategory == 'Other')
                                  // addRow();
                                });
                              },
                              buttonStyleData: ButtonStyleData(
                                height: 45,
                                padding:
                                    const EdgeInsets.only( right: 14),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8.0),
                                  color: Colors.white,
                                  border: Border.all(
                                    color: const Color(0xFFCED4DA),
                                    width: 1.5,
                                  ),
                                ),
                                elevation: 0,
                              ),
                              iconStyleData: const IconStyleData(
                                icon: Icon(
                                  Icons.arrow_drop_down,
                                ),
                                iconSize: 24,
                                iconEnabledColor: Color(0xFFb0b6c3),
                                iconDisabledColor: Colors.grey,
                              ),
                              dropdownStyleData: DropdownStyleData(
                                maxHeight: 300,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(6),
                                  color: Colors.white,
                                ),
                                offset: const Offset(0, -5),
                                scrollbarTheme: ScrollbarThemeData(
                                  radius: const Radius.circular(6),
                                  thickness: MaterialStateProperty.all(6),
                                  thumbVisibility:
                                      MaterialStateProperty.all(true),
                                ),
                              ),
                              menuItemStyleData: const MenuItemStyleData(
                                height: 40,
                                padding: EdgeInsets.only(left: 14, right: 14),
                              ),
                            ),
                          ),
                          ),
                          const SizedBox(
                            height: 10,
                          ),
                          const Text('Vendor ',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF101828))),
                          const SizedBox(
                            height: 2,
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              FormField<String>(
                                validator: (value) {
                                  if (_selectedvendorsId == null) {
                                    return 'Please select an option';
                                  }
                                  return null;
                                },
                                builder: (FormFieldState<String> state) {
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      DropdownButtonHideUnderline(
                                        child: DropdownButtonFormField2<String>(
                                          decoration: const InputDecoration(
                                            border: InputBorder.none,
                                            contentPadding: EdgeInsets.only(top: 12),
                                            hintText: 'Select here',
                                            hintStyle: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w400,
                                              color: Color(0xFFb0b6c3),
                                            ),
                                          ),
                                          isExpanded: true,
                                          hint: const Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  'Select here',
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w400,
                                                    color: Color(0xFFb0b6c3),
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                          items: vendors.keys.map((vendorId) {
                                            return DropdownMenuItem<String>(
                                              value: vendorId,
                                              child: Text(
                                                vendors[vendorId]!,
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w400,
                                                  color: Colors.black87,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            );
                                          }).toList(),
                                          value: vendors.containsKey(
                                                  _selectedvendorsId)
                                              ? _selectedvendorsId
                                              : null,
                                          onChanged: (value) {
                                            setState(() {
                                              // Notify form field of the change
                                              _selectedvendorsId = value;
                                              _selectedVendors = vendors[
                                                  value]; // Store selected vendor

                                              vendorId = value.toString();
                                              // Units belong to the property, not the vendor —
                                              // reloading here cleared the selected unit.
                                              state.didChange(value);
                                            });
                                            state.reset();
                                          },
                                          buttonStyleData: ButtonStyleData(
                                            height: 45,
                                            width: 160,
                                            padding: const EdgeInsets.only(
                                                left: 14, right: 14),
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(8.0),
                                              color: Colors.white,
                                              border: Border.all(
                                                color: const Color(0xFFCED4DA),
                                                width: 1.5,
                                              ),
                                            ),
                                            elevation: 0,
                                          ),
                                          iconStyleData: const IconStyleData(
                                            icon: Icon(
                                              Icons.arrow_drop_down,
                                            ),
                                            iconSize: 24,
                                            iconEnabledColor: Color(0xFFb0b6c3),
                                            iconDisabledColor: Colors.grey,
                                          ),
                                          dropdownStyleData: DropdownStyleData(
                                            maxHeight: 300,
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              color: Colors.white,
                                            ),
                                            offset: const Offset(0, -5),
                                            scrollbarTheme: ScrollbarThemeData(
                                              radius: const Radius.circular(6),
                                              thickness:
                                                  MaterialStateProperty.all(6),
                                              thumbVisibility:
                                                  MaterialStateProperty.all(
                                                      true),
                                            ),
                                          ),
                                          menuItemStyleData:
                                              const MenuItemStyleData(
                                            height: 40,
                                            padding: EdgeInsets.only(
                                                left: 14, right: 14),
                                          ),
                                        ),
                                      ),
                                      if (state.hasError)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                              left: 0, top: 4),
                                          child: Text(
                                            state.errorText!,
                                            style: const TextStyle(
                                              color: Colors.red,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                          const SizedBox(
                            height: 10,
                          ),

                          const Text('Work To Be Performed',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF101828))),
                          const SizedBox(
                            height: 10,
                          ),
                          CustomTextField(
                            keyboardType: TextInputType.text,
                            hintText: 'Enter here',
                            controller: perform,
                            optional: true,
                            showElevation: false,
                            borderColor: const Color(0xFFCED4DA),
                            borderWidth: 1.5,
                          ),
                          const SizedBox(
                            height: 10,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Container(
                    width: double.infinity,
                    // height: !form_valid ? 860 : 830,
                    decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10.0),
                        border: Border.all(
                          color: const Color(0xFFCED4DA),
                        )),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Text('Parts And Labour :',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16)),
                            ],
                          ),
                          ...partsAndLabor.asMap().entries.map((entry) {
                            int index = entry.key;
                            return buildRow(index);
                          }).toList(),
                          const SizedBox(
                            height: 10,
                          ),
                          // Row(
                          //   children: [
                          //     // SizedBox(width: 10),
                          //     const Text('Total :',
                          //         style: TextStyle(
                          //           fontWeight: FontWeight.bold,
                          //         )),
                          //     Padding(
                          //       padding: const EdgeInsets.all(8.0),
                          //       child:
                          //           Text('\$${totalAmount.toStringAsFixed(2)}'),
                          //     ),
                          //   ],
                          // ),
                          Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                    onTap: () {
                                      addRow();
                                    },
                                    child: Text(
                                      ' +   Add Row',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: blueColor),
                                    )),
                              ),
                              Expanded(
                                child: Container(
                                  child: Row(
                                    children: [
                                      // SizedBox(width: 10),
                                      const Text('Total :',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                          )),
                                      Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Text(
                                            formatMoney(totalAmount)),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(
                            height: 10,
                          ),
                          // ElevatedButton(
                          //   onPressed: addRow,
                          //   child: const Text('Add Row'),
                          // ),
                          // const SizedBox(
                          //   height: 10,
                          // ),
                          const Text('Vendors Note ',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF101828))),
                          const SizedBox(
                            height: 10,
                          ),
                          CustomTextField(
                            controller: vendornote,
                            keyboardType: TextInputType.text,
                            hintText: 'Enter here',
                            optional: true,
                            showElevation: false,
                            borderColor: const Color(0xFFCED4DA),
                            borderWidth: 1.5,
                          ),
                          const SizedBox(
                            height: 20,
                          ),
                          Row(
                            children: [
                              SizedBox(
                                width: 24.0, // Standard width for checkbox
                                height: 24.0,
                                child: Checkbox(
                                  value: isChecked,
                                  onChanged: (value) {
                                    setState(() {
                                      isChecked = value ?? false;
                                    });
                                  },
                                  activeColor:
                                      isChecked ? blueColor : Colors.black,
                                ),
                              ),
                              const SizedBox(
                                width: 10,
                              ),
                              const Text(
                                "Billable To Tenant",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF101828)),
                              ),
                            ],
                          ),
                          const SizedBox(
                            height: 10,
                          ),
                          if (isChecked)
                            Column(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                _isLoadingtenant
                                    ? const Center(
                                        child: SpinKitFadingCircle(
                                          color: Colors.black,
                                          size: 50.0,
                                        ),
                                      )
                                    : tenants.isNotEmpty
                                        ? Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Text('Tenant',
                                                  style: TextStyle(
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color:
                                                          Color(0xFF101828))),
                                              const SizedBox(height: 2),
                                              DropdownButtonHideUnderline(
                                                child: DropdownButtonFormField2<
                                                    String>(
                                                  decoration:
                                                      const InputDecoration(
                                                          border:
                                                              InputBorder.none),
                                                  isExpanded: true,
                                                  hint: const Row(
                                                    children: [
                                                      Expanded(
                                                        child: Text(
                                                          'Select Tenant',
                                                          style: TextStyle(
                                                            fontSize: 14,
                                                            fontWeight:
                                                                FontWeight.w400,
                                                            color: Color(
                                                                0xFFb0b6c3),
                                                          ),
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  items: tenants.keys
                                                      .map((tenantId) {
                                                    return DropdownMenuItem<
                                                        String>(
                                                      value: tenantId,
                                                      child: Text(
                                                        tenants[tenantId]!,
                                                        style: const TextStyle(
                                                          fontSize: 14,
                                                          fontWeight:
                                                              FontWeight.w400,
                                                          color: Colors.black87,
                                                        ),
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    );
                                                  }).toList(),
                                                  value: tenants.containsKey(
                                                          _selectedtenantId)
                                                      ? _selectedtenantId
                                                      : null,
                                                  onChanged: (value) {
                                                    setState(() {
                                                      tenantId =
                                                          value.toString();
                                                      _selectedtenantId = value;
                                                      _selectedTenants = tenants[
                                                          value]; // Store selected tenant name
                                                    });
                                                  },
                                                  buttonStyleData:
                                                      ButtonStyleData(
                                                    height: 45,
                                                    width: 160,
                                                    padding:
                                                        const EdgeInsets.only(
                                                            left: 14,
                                                            right: 14),
                                                    decoration: BoxDecoration(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8.0),
                                                      color: Colors.white,
                                                      border: Border.all(
                                                        color: const Color(
                                                            0xFFCED4DA),
                                                        width: 1.5,
                                                      ),
                                                    ),
                                                    elevation: 0,
                                                  ),
                                                  iconStyleData:
                                                      const IconStyleData(
                                                    icon: Icon(
                                                        Icons.arrow_drop_down),
                                                    iconSize: 24,
                                                    iconEnabledColor:
                                                        Color(0xFFb0b6c3),
                                                    iconDisabledColor:
                                                        Colors.grey,
                                                  ),
                                                  dropdownStyleData:
                                                      DropdownStyleData(
                                                    maxHeight: 300,
                                                    decoration: BoxDecoration(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              6),
                                                      color: Colors.white,
                                                    ),
                                                    offset: const Offset(0, -5),
                                                    scrollbarTheme:
                                                        ScrollbarThemeData(
                                                      radius:
                                                          const Radius.circular(
                                                              6),
                                                      thickness:
                                                          MaterialStateProperty
                                                              .all(6),
                                                      thumbVisibility:
                                                          MaterialStateProperty
                                                              .all(true),
                                                    ),
                                                  ),
                                                  menuItemStyleData:
                                                      const MenuItemStyleData(
                                                    height: 40,
                                                    padding: EdgeInsets.only(
                                                        left: 14, right: 14),
                                                  ),
                                                  validator: (value) {
                                                    if (value == null ||
                                                        value.isEmpty) {
                                                      return 'Please select an option';
                                                    }
                                                    return null;
                                                  },
                                                ),
                                              ),
                                            ],
                                          )
                                        : Container(),
                              ],
                            ),
                          const SizedBox(
                            height: 15,
                          ),
                          const Row(
                            children: [
                              Text(
                                "Priority",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF101828)),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              /*  Expanded(
                                    child: ListTile(
                                        contentPadding: EdgeInsets.zero,
                                      title: const Text(' High'),
                                      leading: Radio<String>(
                                        value: 'High',
                                        groupValue: _selectedOption,
                                        onChanged: _handleRadioValueChange,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      title: const Text(' Normal'),
                                      leading: Radio<String>(
                                        value: 'Normal',
                                        groupValue: _selectedOption,
                                        onChanged: _handleRadioValueChange,
                                      ),
                                    ),
                                  ),*/
                              Row(
                                children: [
                                  Container(
                                    width: 25,
                                    child: Radio<String>(
                                      value: 'High',
                                      groupValue: _selectedOption,
                                      onChanged: _handleRadioValueChange,
                                    ),
                                  ),
                                  const SizedBox(
                                    width: 5,
                                  ),
                                  const Text(' High')
                                ],
                              ),
                              const SizedBox(
                                width: 20,
                              ),
                              Row(
                                children: [
                                  Container(
                                    width: 25,
                                    child: Radio<String>(
                                      value: 'Normal',
                                      groupValue: _selectedOption,
                                      onChanged: _handleRadioValueChange,
                                    ),
                                  ),
                                  const SizedBox(
                                    width: 5,
                                  ),
                                  const Text(' Normal')
                                ],
                              ),
                              const SizedBox(
                                width: 20,
                              ),
                              Row(
                                children: [
                                  Container(
                                    width: 25,
                                    child: Radio<String>(
                                      value: 'Low',
                                      groupValue: _selectedOption,
                                      onChanged: _handleRadioValueChange,
                                    ),
                                  ),
                                  const SizedBox(
                                    width: 5,
                                  ),
                                  const Text(' Low')
                                ],
                              )
                              /* ListTile(

                                    tileColor: Colors.amber,
                                    contentPadding: EdgeInsets.only(left:5),
                                    title: Container(
                                    color: Colors.cyan,
                                      child: const Text(' Low')),
                                    leading: Container(
                                      color: Colors.grey,
                                      width: 25,
                                      child: Radio<String>(
                                        value: 'Low',
                                        groupValue: _selectedOption,
                                        onChanged: _handleRadioValueChange,
                                      ),
                                    ),
                                  ),*/
                            ],
                          ),
                          const SizedBox(
                            height: 10,
                          ),
                          const Text('Status *',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF101828))),
                          const SizedBox(
                            height: 10,
                          ),
                          SizedBox(
                            width: double.infinity,
                            child: DropdownButtonHideUnderline(
                            child: DropdownButton2<String>(
                              isExpanded: true,
                              hint: const Text('New',style: TextStyle(fontSize: 14, color: Color(0xFFb0b6c3),fontWeight: FontWeight.w400),),
                              value: _selectedStatus,
                              items: _status.map((method) {
                                return DropdownMenuItem<String>(
                                  value: method,
                                  child: Text(method),
                                );
                              }).toList(),
                              onChanged: (String? newValue) {
                                setState(() {
                                  _selectedStatus = newValue;
                                });
                              },
                              buttonStyleData: ButtonStyleData(
                                height: 45,
                                padding:
                                    const EdgeInsets.only(right: 14),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8.0),
                                  color: Colors.white,
                                  border: Border.all(
                                    color: const Color(0xFFCED4DA),
                                    width: 1.5,
                                  ),
                                ),
                                elevation: 0,
                              ),
                              iconStyleData: const IconStyleData(
                                icon: Icon(
                                  Icons.arrow_drop_down,
                                ),
                                iconSize: 24,
                                iconEnabledColor: Color(0xFFb0b6c3),
                                iconDisabledColor: Colors.grey,
                              ),
                              dropdownStyleData: DropdownStyleData(
                                maxHeight: 300,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(6),
                                  color: Colors.white,
                                ),
                                offset: const Offset(0, -5),
                                scrollbarTheme: ScrollbarThemeData(
                                  radius: const Radius.circular(6),
                                  thickness: MaterialStateProperty.all(6),
                                  thumbVisibility:
                                      MaterialStateProperty.all(true),
                                ),
                              ),
                              menuItemStyleData: const MenuItemStyleData(
                                height: 40,
                                padding: EdgeInsets.only(left: 14, right: 14),
                              ),
                            ),
                          ),
                          ),
                          const SizedBox(
                            height: 15,
                          ),
                          const Text('Due Date *',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF101828))),
                          const SizedBox(
                            height: 10,
                          ),
                          FormField<String>(
                            // Web parity (AddWorkorder.js): due date is required. The error
                            // renders below the box so the field keeps its 50px height.
                            validator: (value) =>
                                _dateController.text.trim().isEmpty
                                    ? 'Please select due date'
                                    : null,
                            builder: (FormFieldState<String> state) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                Container(
                                  // Match the "Enter here" fields (CustomTextField in
                                  // add_tenants.dart): 50 high, 16 horizontal inset.
                                  height: 50,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16.0, vertical: 0),
                                  decoration: BoxDecoration(
                                      color: Colors.white,
                                      // boxShadow: [
                                      //   const BoxShadow(
                                      //     color: Colors.black26,
                                      //     offset: Offset(1.0,
                                      //         1.0), // Shadow offset to the bottom right
                                      //     blurRadius:
                                      //     8.0, // How much to blur the shadow
                                      //     spreadRadius:
                                      //     0.0, // How much the shadow should spread
                                      //   ),
                                      // ],
                                      // Match the other fields on this form: 1.5px
                                      // #CED4DA outline, 8px radius. width: 0 drew a
                                      // hairline that read as no border at all.
                                      border: Border.all(
                                        width: 1.5,
                                        color: const Color(0xFFCED4DA),
                                      ),
                                      borderRadius: BorderRadius.circular(8.0)),
                                  child: TextFormField(
                                    style: const TextStyle(
                                      // A selected date is a VALUE, not a hint: #8898aa is the
                                      // placeholder grey, which made a chosen date read as
                                      // unfilled next to Status and the "Enter here" fields.
                                      color: Colors.black87,
                                      fontSize: 16.0, // Text size
                                      fontWeight: FontWeight.w400, // Text weight
                                    ),
                                    controller: _dateController,
                                    decoration: InputDecoration(
                                      // Same hint styling as the "Enter here" fields,
                                      // and no contentPadding/isDense override — the
                                      // Material default is what centres the text in
                                      // those fields, so overriding it is what made
                                      // this one sit differently.
                                      hintStyle: const TextStyle(
                                          fontSize: 13, color: Color(0xFFb0b6c3)),
                                      border: InputBorder.none,
                                      // labelText: 'Select Date',
                                      hintText: Provider.of<DateProvider>(context)
                                          .dateFormat,
                                      suffixIcon: IconButton(
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(
                                            minWidth: 36, minHeight: 36),
                                        visualDensity: VisualDensity.compact,
                                        icon: const Icon(Icons.calendar_today, size: 18),
                                        onPressed: () => _selectDate(context),
                                      ),
                                    ),
                                    readOnly: true,
                                    onTap: () {
                                      _selectDate(context);
                                    },
                                  ),
                                ),
                                  if (state.hasError)
                                    Padding(
                                      padding: const EdgeInsets.only(left: 0, top: 4),
                                      child: Text(
                                        state.errorText!,
                                        style: const TextStyle(
                                          color: Colors.red,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(
                            height: 10,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0,),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                            height: 50,
                            width: 120,
                            decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8.0),
                                border: Border.all(
                                  color: const Color(0xFFCED4DA),
                                )),
                            child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFffffff),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(8.0))),
                                onPressed: () {
                                  Navigator.pop(context);
                                },
                                child: Text(
                                  'Cancel',
                                  style: TextStyle(
                                      color: blueColor,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold),
                                ))),
                      ),
                      const SizedBox(
                        width: 20,
                      ),
                      Expanded(
                        child: Container(
                          height: 50,
                          width: 180,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  canSave ? blueColor : const Color(0xFFE5E8ED),
                              disabledBackgroundColor: const Color(0xFFE5E8ED),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                            ),
                            // Web parity: disabled until something changed.
                            onPressed:
                                (isloading || !canSave) ? null : _submitForm,
                            child: isloading
                                ? const Center(
                                    child: SpinKitFadingCircle(
                                      color: Colors.white,
                                      size: 55.0,
                                    ),
                                  )
                                : Text(
                                    'Update Work Order',
                                    style: TextStyle(
                                        color: canSave
                                            ? Colors.white
                                            : Colors.grey,
                                        fontWeight: FontWeight.bold),
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget buildTextField(
      String label, String hintText, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label,
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 8.0),
        Material(
          elevation: 3,
          borderRadius: BorderRadius.circular(5),
          child: Container(
            padding: const EdgeInsets.only(left: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(5),
            ),
            child: TextFormField(
              controller: controller,
              focusNode: FocusNode(),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: hintText,
              ),
            ),
          ),
        ),
      ],
    );
  }

  bool isLoading = false;
  bool isloading = false;
  bool formValid = true;

  // Web parity (AddWorkorder.jsx normalizeValue / checkForChanges): a no-op
  // save must never reach the server, which mails everyone on every PUT.
  String _normDirty(dynamic v) => v == null ? '' : v.toString().trim();

  bool _imagesDiffer() {
    final cur = _imageUrls;
    final was = initialSelectedimage ?? const <String>[];
    if (cur.length != was.length) return true;
    for (var i = 0; i < cur.length; i++) {
      if (_normDirty(cur[i]) != _normDirty(was[i])) return true;
    }
    return false;
  }

  bool _partsDiffer() {
    final was = initialSelectedparts ?? const <Map<String, String>>[];
    if (partsAndLabor.length != was.length) return true;
    for (var i = 0; i < partsAndLabor.length; i++) {
      final c = partsAndLabor[i];
      final w = was[i];
      if (_normDirty(c['qtyController']?.text) != _normDirty(w['qty'])) {
        return true;
      }
      if (_normDirty(c['selectedAccount']) != _normDirty(w['account'])) {
        return true;
      }
      if (_normDirty(c['descriptionController']?.text) !=
          _normDirty(w['description'])) {
        return true;
      }
      if (_normDirty(c['priceController']?.text) != _normDirty(w['price'])) {
        return true;
      }
      if (_normDirty(c['totalController']?.text) != _normDirty(w['total'])) {
        return true;
      }
    }
    return false;
  }

  bool _hasWorkOrderChanges() {
    if (!_dirtySnapshotReady) return false;
    return _normDirty(subject.text) != _normDirty(initialSubject) ||
        _normDirty(perform.text) != _normDirty(initialPerform) ||
        _normDirty(vendornote.text) != _normDirty(initialVendorNote) ||
        _normDirty(_dateController.text) != _normDirty(initialDate) ||
        _normDirty(_selectedPropertyId) !=
            _normDirty(initialSelectedPropertyId) ||
        _normDirty(_selectedUnitId) != _normDirty(initialSelectedUnitId) ||
        // The category dropdown only writes _selectedDropdownCategory, so the
        // live dropdown value is what has to be compared here.
        _normDirty(_selectedDropdownCategory?.name ?? _selectedCategory) !=
            _normDirty(initialSelectedCategory) ||
        _normDirty(_selectedStatus) != _normDirty(initialSelectedStatus) ||
        _normDirty(_selectedvendorsId) != _normDirty(initialSelectedVendorId) ||
        _normDirty(_selectedstaffId) != _normDirty(initialSelectedStaffId) ||
        _normDirty(_selectedtenantId) != _normDirty(initialSelectedTenantId) ||
        _normDirty(_selectedOption) != _normDirty(initialSelectedpriority) ||
        _normDirty(_selectedEntry) != _normDirty(initialSelectedEntry) ||
        isChecked != (initialSelectedbillable ?? false) ||
        _imagesDiffer() ||
        _partsDiffer();
  }

  void _onDirtyFieldChanged() {
    final v = _hasWorkOrderChanges();
    if (v != _lastDirty) {
      _lastDirty = v;
      if (mounted) setState(() {});
    }
  }

  void _submitForm() async {
    if (_formkey.currentState!.validate()) {
      setState(() {
        isloading = true;
      });

      // Submit-time backstop for the same check the button is gated on.
      if (!_hasWorkOrderChanges()) {
        setState(() {
          isloading = false;
        });
        Fluttertoast.showToast(
          msg: "Please change at least one field to update the Work Order",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          timeInSecForIosWeb: 1,
          backgroundColor: Colors.orange,
          textColor: Colors.white,
          fontSize: 16.0,
        );
        return;
      }

      // Proceed with API call
      String? finalVendorId = _selectedvendorsId ?? vendorId;
      // Fall back to the tenant loaded with the work order when the dropdown
      // was never re-picked, so saving does not clear the existing tenant.
      String? finalTenantId = _selectedtenantId ?? tenantId;
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? id = prefs.getString("adminId");
      String? token = prefs.getString('token');
      String? rentalId = _selectedPropertyId;
      String? unitId = _selectedUnitId;

      // Use dynamic category dropdown value for categoryId
      String? categoryName =
          _selectedDropdownCategory?.name ?? _selectedCategory;
      String? categoryId = _selectedDropdownCategory?.categoryId;
      if (categoryId == null || categoryId.isEmpty) categoryId = null;

      List<Map<String, dynamic>> parts = partsAndLabor.map((part) {
        return {
          'parts_id': part['parts_id'],
          "parts_quantity":
              int.tryParse(part['qtyController'].text.trim()) ?? 0,
          "account": part['selectedAccount'],
          "description": part['descriptionController'].text.trim(),
          "charge_type": "Workorder Charge",
          "parts_price":
              double.tryParse(part['priceController'].text.trim()) ?? 0.0,
          "amount": double.tryParse(part['totalController'].text.trim()) ?? 0.0,
        };
      }).toList();

      try {
        await WorkOrderRepository().EditWorkOrder(
          adminId: id,
          workOrderid: widget.workorderId,
          workSubject: subject.text.trim(),
          staffMemberName: _selectedstaffId,
          workCategory: categoryName,
          categoryId: categoryId,
          workPerformed: perform.text.trim(),
          status: _selectedStatus,
          rentalAddress: properties[_selectedPropertyId],
          rentalUnit: units[_selectedUnitId],
          tenant: finalTenantId,
          rentalid: rentalId,
          unitid: unitId,
          workOrderImages: _imageUrls,
          vendorId: finalVendorId,
          vendorNotes: vendornote.text.trim(),
          priority: _selectedOption,
          isBillable: isChecked,
          // Web parity (AddWorkorder.jsx): the string "Tenant" when billable,
          // otherwise "". This compared a bool to a String, which is always
          // false, so work_charge_to was stored as false every time.
          workChargeTo: isChecked ? 'Tenant' : '',
          date: reverseFormatDate(_dateController.text.trim()),
          entry: _selectedEntry == 'Yes',
          parts: parts,
          notificationTime:
              DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
        );

        // Success
        Fluttertoast.showToast(
          msg: "Work order updated successfully",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          timeInSecForIosWeb: 1,
          backgroundColor: Colors.green,
          textColor: Colors.white,
          fontSize: 16.0,
        );

        if (mounted) Navigator.pop(context, true);
      } catch (e) {
        // Error
        Fluttertoast.showToast(
          msg: "Failed to edit work order: ${friendlyErrorMessage(e)}",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          timeInSecForIosWeb: 1,
          backgroundColor: Colors.red,
          textColor: Colors.white,
          fontSize: 16.0,
        );
        logError(e);
      } finally {
        // Final cleanup
        if (mounted) {
          setState(() {
            isloading = false;
          });
        }
      }
    } else {
      setState(() {
        formValid = false;
      });
    }
  }
}

class EditWorkOrderForTablet extends StatefulWidget {
  EditData? property;
  final String workorderId;
  EditWorkOrderForTablet({super.key, required this.workorderId, this.property});
  @override
  State<EditWorkOrderForTablet> createState() => _EditWorkOrderForTabletState();
}

class _EditWorkOrderForTabletState extends State<EditWorkOrderForTablet> {
  final TextEditingController subject = TextEditingController();

  final TextEditingController other = TextEditingController();

  final TextEditingController perform = TextEditingController();
  final TextEditingController vendornote = TextEditingController();

  GlobalKey<FormState> _formkey = GlobalKey<FormState>();
  final TextEditingController _dateController = TextEditingController();
  bool form_valid = false;
  bool _isLoading = true;
  bool _isLoadingvendors = true;
  bool _isLoadingstaff = true;
  bool _isLoadingtenant = false;
  bool _Loading = false;
  Map<String, String> properties = {}; // Mapping of rental_id to rental_address
  Map<String, String> units = {}; // Mapping of unit_id to rental_unit
  String? _selectedPropertyId;
  String? _selectedProperty;
  String? _selectedUnitId;
  String? _selectedUnit;

  //for vendor
  Map<String, String> vendors = {};
  String? _selectedvendorsId;
  String? _selectedVendors;

  //for Staffmember
  Map<String, String> staffs = {};
  String? _selectedstaffId;
  String? _selectedStaffs;
  //for tenants
  Map<String, String> tenants = {};
  String? _selectedtenantId;
  String? _selectedTenants;
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _loadProperties();
    _loadVendor();
    _loadStaff();
    if (_selectedPropertyId != null && _selectedUnitId != null) {
      _loadTenant(_selectedPropertyId!, _selectedUnitId!);
    }
    // _loadTenant();
    fetchWorkordersDetails(widget.workorderId);
    partsAndLabor.clear();
    // Typing does not rebuild on its own, so the Update button would stay
    // disabled after a text-only edit without these.
    subject.addListener(_onDirtyFieldChanged);
    perform.addListener(_onDirtyFieldChanged);
    vendornote.addListener(_onDirtyFieldChanged);
    _dateController.addListener(_onDirtyFieldChanged);
  }

  String? initialSubject;
  String? initialPerform;
  String? initialVendorNote;
  String? initialDate;
  String? initialSelectedPropertyId;
  String? initialSelectedUnitId;
  String? initialSelectedCategory;
  String? initialSelectedStatus;
  String? initialSelectedVendorId;
  String? initialSelectedStaffId;
  String? initialSelectedTenantId;
  String? initialSelectedpriority;
  String? initialSelectedEntry;
  bool? initialSelectedbillable;
  List<String>? initialSelectedimage;
  List<Map<String, String>>? initialSelectedparts;
  // Nothing to diff against until fetchWorkordersDetails has seeded the
  // initial* fields above.
  bool _dirtySnapshotReady = false;
  bool _lastDirty = false;

  Future<void> fetchWorkordersDetails(String workorderId) async {
    //try {
    // await _loadProperties();
    EditData fetchedDetails =
        await WorkOrderRepository().fetchWorkordersDetails(workorderId);

    // print('Fetched parts and charge data: ${fetchedDetails.partsandchargeData?.first.account}');
    String? entryAllowedString;
    if (fetchedDetails.entryAllowed != null) {
      entryAllowedString = fetchedDetails.entryAllowed! ? 'true' : 'false';
    }
    await Future.delayed(const Duration(seconds: 1));
    setState(() {
      // print(fetchedDetails.rental.rentalAddress);
      if (fetchedDetails.workOrderImages != null) {
        _imageUrls = fetchedDetails.workOrderImages!.map((fileName) {
          return '$fileName'; // Adjust the path as needed
        }).toList();
      }
      subject.text = fetchedDetails.workSubject!;
      _selectedstaffId = fetchedDetails.staffData?.staffName;
      _selectedCategory = fetchedDetails.workCategory;
      perform.text = fetchedDetails.workPerformed!;
      _selectedStatus = fetchedDetails.status!;
      vendornote.text = fetchedDetails.vendorNotes ?? "";
      _dateController.text = Provider.of<DateProvider>(context, listen: false)
          .formatCurrentDate(fetchedDetails.date!);
      _selectedOption = fetchedDetails.priority ?? "";
      _selectedPropertyId = fetchedDetails.rentalId?.isEmpty ?? true
          ? null
          : fetchedDetails.rentalId;
      renderId = fetchedDetails.rentalId!;
      _selectedUnitId = fetchedDetails.unitId;
      isChecked = fetchedDetails.isBillable!;
      _selectedvendorsId = fetchedDetails.vendorId!.isEmpty
          ? null
          : fetchedDetails.vendorId ?? null;
      //_selectedstaffId = fetchedDetails.staffmemberId ?? null;
      _selectedstaffId = fetchedDetails.staffmemberId?.isEmpty ?? true
          ? null
          : fetchedDetails.staffmemberId;
      _selectedtenantId = fetchedDetails.tenantId ?? null;
      _selectedEntry = entryAllowedString;
      partsAndLabor =
          fetchedDetails.partsandchargeData?.map<Map<String, dynamic>>((data) {
                TextEditingController qtyController =
                    TextEditingController(text: data.partsQuantity!.toString());
                TextEditingController priceController =
                    TextEditingController(text: data.partsPrice!.toString());
                TextEditingController totalController =
                    TextEditingController(text: data.amount!.toString());
                TextEditingController subtotalcontroller =
                    TextEditingController();
                qtyController.addListener(() {
                  calculateTotal(qtyController, priceController,
                      totalController, subtotalcontroller);
                });
                priceController.addListener(() {
                  calculateTotal(qtyController, priceController,
                      totalController, subtotalcontroller);
                });
                return {
                  "parts_id": data.partsId,
                  "qtyController": qtyController,
                  "selectedAccount": data.account ?? '',
                  "descriptionController":
                      TextEditingController(text: data.description ?? ''),
                  "priceController": priceController,
                  "totalController": totalController,
                };
              }).toList() ??
              [];

      // Keep the Update button's dirty check in sync with the rows just built.
      for (final row in partsAndLabor) {
        (row['qtyController'] as TextEditingController?)
            ?.addListener(_onDirtyFieldChanged);
        (row['priceController'] as TextEditingController?)
            ?.addListener(_onDirtyFieldChanged);
        (row['descriptionController'] as TextEditingController?)
            ?.addListener(_onDirtyFieldChanged);
      }

      // Snapshot of the record as loaded, for the no-op-save guard. Read off
      // the live fields seeded just above so the two cannot drift apart.
      initialSubject = subject.text;
      initialPerform = perform.text;
      initialVendorNote = vendornote.text;
      initialDate = _dateController.text;
      initialSelectedPropertyId = _selectedPropertyId;
      initialSelectedUnitId = _selectedUnitId;
      initialSelectedCategory = _selectedCategory;
      initialSelectedStatus = _selectedStatus;
      initialSelectedVendorId = _selectedvendorsId;
      initialSelectedStaffId = _selectedstaffId;
      initialSelectedTenantId = _selectedtenantId;
      initialSelectedpriority = _selectedOption;
      // This class encodes entry allowed as 'true'/'false'.
      initialSelectedEntry = _selectedEntry;
      initialSelectedbillable = isChecked;
      initialSelectedimage = List<String>.from(_imageUrls);
      initialSelectedparts =
          fetchedDetails.partsandchargeData?.map<Map<String, String>>((data) {
                return {
                  'qty': data.partsQuantity?.toString() ?? '',
                  'account': data.account ?? '',
                  'description': data.description ?? '',
                  'price': data.partsPrice?.toString() ?? '',
                  'total': data.amount?.toString() ?? '',
                };
              }).toList() ??
              [];

      updateTotalAmount();
      _dirtySnapshotReady = true;

      // totalAmount = calculateTotalAmount(partsAndLabor);
    });

    _loadUnits(_selectedPropertyId!);
    if (_selectedUnitId != null) {
      _loadTenant(_selectedPropertyId!, _selectedUnitId!);
    }
    // _loadUnits(renderId)
    if (_selectedProperty != null) {
      await _loadUnits(_selectedProperty!);
    }
    setState(() {
      _selectedUnit = fetchedDetails.unitId;
    });
    //} catch (e) {
    //print('Failed to fetch lease details: ${friendlyErrorMessage(e)}');
    //}
  }

  Future<void> _loadProperties() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString("adminId");
    String? token = prefs.getString('token');
    setState(() {
      _isLoading = true;
    });
    try {
      final response = await http
          // `limit=0` is the server's own no-limit flag; without it the API
          // returns a page of 10 (Rentals.js) and this picker is truncated.
          .get(Uri.parse('${Api_url}/api/rentals/rentals/$id?limit=0'), headers: {
        "authorization": "CRM $token",
        "id": "CRM ${prefs.getString('staff_id') ?? id}",
      });
      if (!mounted) return;
      if (response.statusCode == 200) {
        List jsonResponse = json.decode(response.body)['data'];
        Map<String, String> addresses = {};
        jsonResponse.forEach((data) {
          addresses[data['rental_id'].toString()] =
              data['rental_adress'].toString();
        });
        // Sort properties alphabetically by address (A-Z)
        final sortedEntries = addresses.entries.toList()
          ..sort(
              (a, b) => a.value.toLowerCase().compareTo(b.value.toLowerCase()));
        final sortedAddresses = Map<String, String>.fromEntries(sortedEntries);

        setState(() {
          properties = sortedAddresses;
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load data');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to fetch properties: ${friendlyErrorMessage(e)}')),
      );
    }
  }

  Future<void> _loadUnits(String rentalId) async {
    setState(() {
      _isLoading = true;
    });
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString("adminId");
    String? token = prefs.getString('token');
    try {
      final response = await http
          .get(Uri.parse('$Api_url/api/unit/rental_unit/$rentalId'), headers: {
        "authorization": "CRM $token",
        "id": "CRM ${prefs.getString('staff_id') ?? id}",
      });

      if (!mounted) return;
      if (response.statusCode == 200) {
        List jsonResponse = json.decode(response.body)['data'];
        Map<String, String> unitAddresses = {};
        jsonResponse.forEach((data) {
          unitAddresses[data['unit_id'].toString()] =
              data['rental_unit'].toString();
        });
        //  200 no hoy tyare _loadtennant
        setState(() {
          units = unitAddresses;
          _isLoading = false;
        });
      } else {
        _loadTenant(rentalId, unitId);
        throw Exception('Failed to load units');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  //for vendor
  Future<void> _loadVendor() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString("adminId");
    String? token = prefs.getString('token');
    setState(() {
      _isLoadingvendors = true;
    });
    try {
      final response = await http
          .get(Uri.parse('${Api_url}/api/vendor/vendors/$id'), headers: {
        "authorization": "CRM $token",
        "id": "CRM ${prefs.getString('staff_id') ?? id}",
      });

      if (!mounted) return;
      if (response.statusCode == 200) {
        List jsonResponse = json.decode(response.body)['data'];
        Map<String, String> names = {};
        jsonResponse.forEach((data) {
          names[data['vendor_id'].toString()] = data['vendor_name'].toString();
        });

        setState(() {
          vendors = names;
          _isLoadingvendors = false;
        });
      } else {
        throw Exception('Failed to load data');
      }
    } catch (e) {
      setState(() {
        _isLoadingvendors = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to fetch vendors: ${friendlyErrorMessage(e)}')),
      );
    }
  }

  Future<void> _loadStaff() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString("adminId");
    String? token = prefs.getString('token');
    setState(() {
      _isLoadingstaff = true;
    });
    try {
      final response = await apiGet(
          Uri.parse('${Api_url}/api/staffmember/staff_member/$id'),
          headers: {
            "authorization": "CRM $token",
            "id": "CRM ${prefs.getString('staff_id') ?? id}",
          });

      if (!mounted) return;
      if (response.statusCode == 200) {
        List jsonResponse = json.decode(response.body)['data'];
        Map<String, String> staffnames = {};
        jsonResponse.forEach((data) {
          staffnames[data['staffmember_id'].toString()] =
              data['staffmember_name'].toString();
        });

        setState(() {
          staffs = staffnames;
          _isLoadingstaff = false;
        });
      } else {
        throw Exception('Failed to load data');
      }
    } catch (e) {
      setState(() {
        _isLoadingstaff = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to fetch vendors: ${friendlyErrorMessage(e)}')),
      );
    }
  }

  Future<void> _loadTenant(String rentalId, String unitId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString("adminId");
    String? token = prefs.getString('token');
    setState(() {
      _isLoadingtenant = true;
    });
    try {
      final response = await apiGet(
          Uri.parse('${Api_url}/api/leases/get_tenants/$rentalId/$unitId'),
          headers: {
            "authorization": "CRM $token",
            "id": "CRM ${prefs.getString('staff_id') ?? id}",
          });
      if (!mounted) return;
      if (response.statusCode == 200) {
        List jsonResponse = json.decode(response.body)['data'];
        Map<String, String> tenantsnames = {};
        jsonResponse.forEach((data) {
          tenantsnames[data['tenant_id'].toString()] =
              data['tenant_firstName'].toString() +
                  " " +
                  data['tenant_lastName'].toString();
        });
        setState(() {
          tenants = tenantsnames;
          _isLoadingtenant = false;
        });
      } else {
        throw Exception('Failed to load data');
      }
    } catch (e) {
      setState(() {
        _isLoadingtenant = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to fetch tenants: ${friendlyErrorMessage(e)}')),
      );
    }
  }

  String? _selectedCategory;
  final List<String> _category = [
    'Complaint',
    'Contribution Request',
    'Feedback/Suggestion',
    'General Inquiry',
    'Maintenance Request',
    'Other'
  ];
  String? _selectedEntry;
  final List<String> _entry = [
    'true',
    'false',
  ];
  String? _selectedStatus;
  final List<String> _status = [
    'Closed',
    'Completed',
    'In Progress',
    'New',
    'On Hold'
  ];
  final List<String> _account = [
    'Advertising',
    'Association Fees',
    'Bank Fees',
    'Auto and Travel',
    'Cleaning and Maintenance',
    'Commissions',
    'Depreciation Expense',
    'Insurance',
    'Legal and Professional Fees',
    'Licenses and Permits',
    'Management Fees',
    'Mortgage Interest',
    'Other Expenses',
    'Other Interest Expenses',
    'Postage and Delivery',
    'Repairs',
    'Other Expenses',
  ];

  List<Map<String, dynamic>> rows = [];
  bool _showTextField = false;
  String renderId = '';
  String unitId = '';
  String vendorId = '';
  String StaffId = '';
  String tenantId = '';
  bool isChecked = false;
  //for parts and lebours
  List<Map<String, dynamic>> partsAndLabor = [];

  void addRow() {
    setState(() {
      TextEditingController qtyController = TextEditingController();
      TextEditingController priceController = TextEditingController();
      TextEditingController totalController = TextEditingController();
      TextEditingController subtotalcontroller = TextEditingController();
      TextEditingController descriptionController = TextEditingController();

      qtyController.addListener(() {
        calculateTotal(qtyController, priceController, totalController,
            subtotalcontroller);
      });
      priceController.addListener(() {
        calculateTotal(qtyController, priceController, totalController,
            subtotalcontroller);
      });

      qtyController.addListener(_onDirtyFieldChanged);
      priceController.addListener(_onDirtyFieldChanged);
      descriptionController.addListener(_onDirtyFieldChanged);

      partsAndLabor.add({
        'qtyController': qtyController,
        'accountController': TextEditingController(),
        'descriptionController': descriptionController,
        'priceController': priceController,
        'totalController': totalController,
        'subtotalcontroller': subtotalcontroller,
        'selectedAccount': null,
      });
    });
  }

  @override
  void dispose() {
    // Controllers handed to CustomTextField are released by that widget
    // (CustomTextFieldState in screens/Maintenance/Vendor/add_vendor.dart
    // disposes whatever controller it is given), so releasing them here as
    // well threw "used after being disposed" on close. Only what this
    // screen owns outright is released below.
    subject.removeListener(_onDirtyFieldChanged);
    perform.removeListener(_onDirtyFieldChanged);
    vendornote.removeListener(_onDirtyFieldChanged);
    _dateController.removeListener(_onDirtyFieldChanged);
    other.dispose();
    _dateController.dispose();
    for (final row in partsAndLabor) {
      (row['qtyController'] as TextEditingController?)
          ?.removeListener(_onDirtyFieldChanged);
      (row['priceController'] as TextEditingController?)
          ?.removeListener(_onDirtyFieldChanged);
      (row['descriptionController'] as TextEditingController?)
          ?.removeListener(_onDirtyFieldChanged);
      (row['qtyController'] as TextEditingController?)?.dispose();
      (row['accountController'] as TextEditingController?)?.dispose();
      (row['descriptionController'] as TextEditingController?)?.dispose();
      (row['priceController'] as TextEditingController?)?.dispose();
      (row['totalController'] as TextEditingController?)?.dispose();
      (row['subtotalcontroller'] as TextEditingController?)?.dispose();
    }
    super.dispose();
  }

  void deleteRow(int index) {
    setState(() {
      final row = partsAndLabor[index];
      (row['qtyController'] as TextEditingController?)?.dispose();
      (row['accountController'] as TextEditingController?)?.dispose();
      (row['descriptionController'] as TextEditingController?)?.dispose();
      (row['priceController'] as TextEditingController?)?.dispose();
      (row['totalController'] as TextEditingController?)?.dispose();
      (row['subtotalcontroller'] as TextEditingController?)?.dispose();
      partsAndLabor.removeAt(index);
      updateTotalAmount();
    });
  }

  void calculateTotal(
      TextEditingController qtyController,
      TextEditingController priceController,
      TextEditingController totalController,
      TextEditingController subtotalcontroller) {
    double quantity = double.tryParse(qtyController.text) ?? 0;
    double price = double.tryParse(priceController.text) ?? 0;
    double total = quantity * price;
    totalController.text = total.toStringAsFixed(2);
    double subtotal = total += total;
    subtotalcontroller.text = subtotal.toStringAsFixed(2);
    updateTotalAmount();
  }

  double totalAmount = 0.0;
  void updateTotalAmount() {
    double total = 0.0;
    for (var item in partsAndLabor) {
      double itemTotal = double.tryParse(item['totalController'].text) ?? 0;
      total += itemTotal;
    }
    setState(() {
      totalAmount = total;
    });
  }

  Widget buildRow(int index) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.black),
              onPressed: () {
                deleteRow(index);
              },
            ),
          ),
          const Text(
            "Quantity",
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Color(0xFF101828)),
          ),
          const SizedBox(height: 5),
          CustomTextField(
            hintText: 'Quantity',
            controller: partsAndLabor[index]['qtyController'],
            keyboardType: TextInputType.number,
            showElevation: false,
            borderColor: const Color(0xFFCED4DA),
            borderWidth: 1.5,
          ),
          const SizedBox(height: 10),
          const Text(
            "Account",
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Color(0xFF101828)),
          ),
          const SizedBox(height: 5),
          DropdownButtonHideUnderline(
            child: DropdownButton2<String>(
              isExpanded: true,
              hint: const Text('Select'),
              value: _account.contains(partsAndLabor[index]['selectedAccount'])
                  ? partsAndLabor[index]['selectedAccount']
                  : null,
              items: _account.map((method) {
                return DropdownMenuItem<String>(
                  value: method,
                  child: Text(method),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  partsAndLabor[index]['selectedAccount'] = newValue;
                });
              },
              buttonStyleData: ButtonStyleData(
                height: 50,
                width: 250,
                padding: const EdgeInsets.only(left: 14, right: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8.0),
                  color: Colors.white,
                  border: Border.all(
                    color: const Color(0xFFCED4DA),
                    width: 1.5,
                  ),
                ),
                elevation: 0,
              ),
              iconStyleData: const IconStyleData(
                icon: Icon(
                  Icons.arrow_drop_down,
                ),
                iconSize: 24,
                iconEnabledColor: Color(0xFFb0b6c3),
                iconDisabledColor: Colors.grey,
              ),
              dropdownStyleData: DropdownStyleData(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8.0),
                  color: Colors.white,
                ),
                scrollbarTheme: ScrollbarThemeData(
                  radius: const Radius.circular(6),
                  thickness: MaterialStateProperty.all(6),
                  thumbVisibility: MaterialStateProperty.all(true),
                ),
              ),
              menuItemStyleData: const MenuItemStyleData(
                height: 40,
                padding: EdgeInsets.only(left: 14, right: 14),
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            "Description",
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Color(0xFF101828)),
          ),
          const SizedBox(height: 5),
          CustomTextField(
            hintText: 'Description',
            controller: partsAndLabor[index]['descriptionController'],
            keyboardType: TextInputType.text,
            showElevation: false,
            borderColor: const Color(0xFFCED4DA),
            borderWidth: 1.5,
          ),
          const SizedBox(height: 10),
          const Text(
            "Price",
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Color(0xFF101828)),
          ),
          const SizedBox(height: 5),
          CustomTextField(
            hintText: 'Price',
            controller: partsAndLabor[index]['priceController'],
            keyboardType: TextInputType.number,
            showElevation: false,
            borderColor: const Color(0xFFCED4DA),
            borderWidth: 1.5,
          ),
          const SizedBox(height: 10),
          const Text(
            "Total",
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Color(0xFF101828)),
          ),
          const SizedBox(height: 5),
          CustomTextField(
            hintText: 'Total',
            controller: partsAndLabor[index]['totalController'],
            keyboardType: TextInputType.number,
            readOnnly: true,
            showElevation: false,
            borderColor: const Color(0xFFCED4DA),
            borderWidth: 1.5,
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  String _selectedOption = 'button 1';

  void _handleRadioValueChange(String? value) {
    setState(() {
      _selectedOption = value!;
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    DateTime? selectedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(), // Due date cannot be earlier than today
      lastDate: DateTime(2101),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: blueColor, // header background color
              onPrimary: Colors.white, // header text color
              onSurface: blueColor, // body text color
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: blueColor, // button text color
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (selectedDate != null) {
      setState(() {
        _dateController.text = DateFormat(
                Provider.of<DateProvider>(context, listen: false).dateFormat)
            .format(selectedDate);
      });
    }
  }

  //for tenants
  File? _image;
  List<File> _images = [];
  List<File> videofiles = [];
  String? _uploadedFileName;
  List<bool> isvideo = [];
  List<String> _uploadedFileNames = [];

  Future<String?> _generateVideoThumbnail(String videoPath) async {
    final String? thumbPath =
        await video_thumbnail.VideoThumbnail.thumbnailFile(
      video: videoPath,
      thumbnailPath: (await getTemporaryDirectory()).path,
      imageFormat: video_thumbnail.ImageFormat.PNG,
      maxHeight: 80,
      quality: 50,
    );
    return thumbPath;
  }

  Future<String?> uploadImage(File imageFile) async {
    final String uploadUrl = '${image_upload_url}/api/images/upload';

    var request = http.MultipartRequest(
        'POST',
        Uri.parse(
          uploadUrl,
        ));
    // The upload endpoint requires the same auth headers every other call in
    // this file sends; this request never included them, so the server
    // rejected it with a 401 and no file was ever stored.
    final prefs = await SharedPreferences.getInstance();
    final _token = prefs.getString('token');
    final _staffId = prefs.getString('staff_id');
    request.headers.addAll({
      "authorization": "CRM $_token",
      "id": "CRM $_staffId",
    });
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

  // Show image source selection dialog
  void _showImageSourceDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Title
                Text(
                  'Select Media From',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 24),

                // Options Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Gallery Option
                    _buildSourceOption(
                      icon: Icons.photo_library,
                      label: 'Gallery',
                      onTap: () {
                        Navigator.of(context).pop();
                        _pickImageFromSource(ImageSource.gallery);
                      },
                    ),

                    const SizedBox(width: 20),

                    // Camera Option
                    _buildSourceOption(
                      icon: Icons.camera_alt,
                      label: 'Camera',
                      onTap: () {
                        Navigator.of(context).pop();
                        _openCameraInterface();
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  // Build individual source option
  Widget _buildSourceOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[200]!, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: blueColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: blueColor,
                size: 28,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Pick image from specific source
  Future<void> _pickImageFromSource(ImageSource source) async {
    final ImagePicker _picker = ImagePicker();
    final XFile? image = await _picker.pickMedia();

    if (image != null) {
      final File file = File(image.path);
      // Lowercased first: the iPhone camera names videos .MOV (uppercase), which
      // failed this check and made a picked video vanish from the preview list.
      bool isVideo = image.path.toLowerCase().endsWith('.mp4') ||
          image.path.toLowerCase().endsWith('.mov');
      if (isVideo) {
        String? thumbnailPath = await _generateVideoThumbnail(image.path);
        if (thumbnailPath != null) {
          setState(() {
            _image = File(thumbnailPath);
            _images.add(File(thumbnailPath));
            isvideo.add(true);
            videofiles.add(file);
          });
        }
      } else {
        setState(() {
          _image = file;
          _images.add(file);
          isvideo.add(false);
          videofiles.add(file);
        });
      }
      _uploadImage(file);
    }
  }

  // Open unified camera interface for both photos and videos
  Future<void> _openCameraInterface() async {
    try {
      // Get available cameras
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        _showErrorDialog('No cameras found on this device');
        return;
      }

      // Use the first available camera (usually back camera)
      final camera = cameras.first;

      // Navigate to camera screen
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CameraCaptureScreen(
            camera: camera,
            onImageCaptured: (File imageFile) {
              // Handle captured image
              setState(() {
                _image = imageFile;
                _images.add(imageFile);
              });
              _uploadImage(imageFile);
            },
            onVideoCaptured: (File videoFile) async {
              // Handle captured video
              setState(() {
                _image = videoFile;
                _images.add(videoFile);
              });
              _uploadImage(videoFile);
            },
          ),
        ),
      );
    } catch (e) {
      _showErrorDialog('Failed to open camera: $e');
    }
  }

  // Show error dialog
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage() async {
    final ImagePicker _picker = ImagePicker();
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() {
        _image = File(image.path);
        _images.add(File(image.path));
      });
      _uploadImage(File(image.path));
    }
  }

  Future<void> _uploadImage(File imageFile) async {
    try {
      String? fileName = await uploadImage(imageFile);
      if (fileName == null) {
        Fluttertoast.showToast(msg: 'Failed to upload image');
        return;
      }
      setState(() {
        _uploadedFileNames.add(fileName);
        _uploadedFileName = fileName;
        _imageUrls.add(fileName);
      });
    } catch (e) {
      // Surface the failure — this used to fail silently, leaving the upload
      // box unchanged with no indication anything went wrong.
      Fluttertoast.showToast(msg: 'Failed to upload image');
      logError('Image upload failed: $e');
    }
  }

  List<String> _imageUrls = [];

  @override
  Widget build(BuildContext context) {
    double screenHeight = MediaQuery.of(context).size.height;
    double screenWidth = MediaQuery.of(context).size.height;
    final bool canSave = _hasWorkOrderChanges();
    _lastDirty = canSave;
    return Scaffold(
        appBar: widget_302_Staff.App_Bar(context: context),
        backgroundColor: Colors.white,
        drawer: CustomDrawerStaff(
          currentpage: "Work Orders",
          dropdown: false,
        ),
        body: Form(
          key: _formkey,
          child: Container(
            color: Colors.white,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(
                    height: 25,
                  ),
                  titleBar(
                    width: MediaQuery.of(context).size.width * .91,
                    title: 'Edit Work Order',
                  ),
                  const SizedBox(
                    height: 15,
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: MediaQuery.of(context).size.width * .04),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Container(
                            width: double.infinity,
                            // height: !form_valid ? 860 : 830,
                            decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10.0),
                                border: Border.all(
                                  color: const Color(0xFFCED4DA),
                                )),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Subject *',
                                      style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF101828))),
                                  const SizedBox(
                                    height: 10,
                                  ),
                                  CustomTextField(
                                    keyboardType: TextInputType.text,
                                    hintText: 'Add subject',
                                    controller: subject,
                                    showElevation: false,
                                    borderColor: const Color(0xFFCED4DA),
                                    borderWidth: 1.5,
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'please enter the subject';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(
                                    height: 10,
                                  ),
                                  const Text('Photo ',
                                      style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF101828))),
                                  const SizedBox(
                                    height: 10,
                                  ),
                                  Container(
                                    height: 50,
                                    width: 150,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8.0),
                                    ),
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: blueColor,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8.0),
                                        ),
                                      ),
                                      onPressed: () async {
                                        _showImageSourceDialog();
                                      },
                                      child: isLoading
                                          ? const Center(
                                              child: SpinKitFadingCircle(
                                                color: Colors.white,
                                                size: 55.0,
                                              ),
                                            )
                                          : const Text(
                                              'Upload here',
                                              style: TextStyle(
                                                  color: Color(0xFFf7f8f9)),
                                            ),
                                    ),
                                  ),
                                  const SizedBox(
                                    height: 10,
                                  ),
                                  // _images.isNotEmpty
                                  //     ? Row(
                                  //   children: [
                                  //     Expanded(
                                  //       child: Container(
                                  //         //color: Colors.blue,
                                  //         child: Wrap(
                                  //
                                  //
                                  //           spacing: 8.0, // Horizontal spacing between items
                                  //           runSpacing: 8.0, // Vertical spacing between rows
                                  //           children: List.generate(
                                  //             _images.length,
                                  //                 (index) {
                                  //               return Container(
                                  //                 // color: Colors.green,
                                  //                 width: 85,
                                  //                 child: Column(
                                  //                   mainAxisAlignment: MainAxisAlignment.start,
                                  //                   crossAxisAlignment: CrossAxisAlignment.start,
                                  //                   children: [
                                  //                     Row(
                                  //                       children: [
                                  //                         SizedBox(
                                  //                           width: 60,
                                  //                         ),
                                  //                         GestureDetector(
                                  //                           onTap: () {
                                  //                             setState(() {
                                  //                               _images.removeAt(index);
                                  //                             });
                                  //                           },
                                  //                           child: Icon(
                                  //                             Icons.close,
                                  //                             color: Colors.grey,
                                  //                           ),
                                  //                         ),
                                  //                       ],
                                  //                     ),
                                  //                     Row(
                                  //                       mainAxisAlignment: MainAxisAlignment.start,
                                  //                       crossAxisAlignment: CrossAxisAlignment.start,
                                  //                       children: [
                                  //                         Container(
                                  //                           // color:Colors.blue,
                                  //                           child: Image.file(
                                  //                             _images[index],
                                  //                             height: 80,
                                  //                             width: 80,
                                  //                             fit: BoxFit.cover,
                                  //                           ),
                                  //                         ),
                                  //
                                  //                       ],
                                  //                     ),
                                  //                   ],
                                  //                 ),
                                  //               );
                                  //             },
                                  //           ),
                                  //         ),
                                  //       ),
                                  //     ),
                                  //   ],
                                  // )
                                  //     : Center(
                                  //   child: Text("No images selected."),
                                  // ),
                                  _imageUrls.isNotEmpty
                                      ? Row(
                                          children: [
                                            Expanded(
                                              child: Container(
                                                child: Wrap(
                                                  spacing:
                                                      8.0, // Horizontal spacing between items
                                                  runSpacing:
                                                      8.0, // Vertical spacing between rows
                                                  children: List.generate(
                                                    _imageUrls.length,
                                                    (index) {
                                                      return Container(
                                                        width: 85,
                                                        child: Column(
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .start,
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            Row(
                                                              children: [
                                                                const SizedBox(
                                                                    width: 60),
                                                                GestureDetector(
                                                                  onTap: () {
                                                                    setState(
                                                                        () {
                                                                      _imageUrls
                                                                          .removeAt(
                                                                              index);
                                                                    });
                                                                  },
                                                                  child:
                                                                      const Icon(
                                                                    Icons.close,
                                                                    color: Colors
                                                                        .grey,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                            Row(
                                                              mainAxisAlignment:
                                                                  MainAxisAlignment
                                                                      .start,
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .start,
                                                              children: [
                                                                GestureDetector(
                                                                  onTap: () {
                                                                    _showImageDialog(
                                                                        "$image_url${_imageUrls[index]}",
                                                                        index,
                                                                        null,
                                                                        false);
                                                                  },
                                                                  child: Stack(
                                                                    alignment:
                                                                        Alignment
                                                                            .center,
                                                                    children: [
                                                                      Image
                                                                          .network(
                                                                        "$image_url${_imageUrls[index]}",
                                                                        height:
                                                                            80,
                                                                        width:
                                                                            80,
                                                                        fit: BoxFit
                                                                            .cover,
                                                                        errorBuilder: (context,
                                                                            error,
                                                                            stackTrace) {
                                                                          return const Icon(
                                                                              Icons.error);
                                                                        },
                                                                      ),
                                                                      Positioned(
                                                                        top: 20,
                                                                        right:
                                                                            25,
                                                                        child:
                                                                            Container(
                                                                          padding:
                                                                              EdgeInsets.all(4),
                                                                          decoration:
                                                                              BoxDecoration(
                                                                            color:
                                                                                Colors.black54,
                                                                            borderRadius:
                                                                                BorderRadius.circular(15),
                                                                          ),
                                                                          child:
                                                                              Icon(
                                                                            Icons.visibility,
                                                                            color:
                                                                                Colors.white,
                                                                            size:
                                                                                16,
                                                                          ),
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ],
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        )
                                      : const Center(
                                          child: Text("No images selected.")),
                                  const SizedBox(
                                    height: 10,
                                  ),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.start,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text('Property *',
                                                style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(0xFF101828))),
                                            DropdownButtonHideUnderline(
                                              child: DropdownButtonFormField2<
                                                  String>(
                                                decoration:
                                                    const InputDecoration(
                                                        border:
                                                            InputBorder.none),
                                                isExpanded: true,
                                                hint: const Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        'Select Property',
                                                        style: TextStyle(
                                                          fontSize: 14,
                                                          fontWeight:
                                                              FontWeight.w400,
                                                          color:
                                                              Color(0xFFb0b6c3),
                                                        ),
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                items: properties.keys
                                                    .map((rentalId) {
                                                  return DropdownMenuItem<
                                                      String>(
                                                    value: rentalId,
                                                    child: Text(
                                                      properties[rentalId]!,
                                                      style: const TextStyle(
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.w400,
                                                        color: Colors.black87,
                                                      ),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  );
                                                }).toList(),
                                                value: properties.containsKey(
                                                        _selectedPropertyId)
                                                    ? _selectedPropertyId
                                                    : null,
                                                onChanged: (value) {
                                                  setState(() {
                                                    _selectedUnitId = null;
                                                    _selectedPropertyId = value;
                                                    _selectedProperty = properties[
                                                        value]; // Store selected rental_adress

                                                    renderId = value.toString();

                                                    // _loadUnits(
                                                    //     value!);
                                                    if (value != null) {
                                                      _loadUnits(value);
                                                    }
                                                  });
                                                },
                                                buttonStyleData:
                                                    ButtonStyleData(
                                                  height: 45,
                                                  width: 160,
                                                  padding:
                                                      const EdgeInsets.only(
                                                          left: 14, right: 14),
                                                  decoration: BoxDecoration(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8.0),
                                                    color: Colors.white,
                                                    border: Border.all(
                                                      color: const Color(
                                                          0xFFCED4DA),
                                                      width: 1.5,
                                                    ),
                                                  ),
                                                  elevation: 0,
                                                ),
                                                iconStyleData:
                                                    const IconStyleData(
                                                  icon: Icon(
                                                    Icons.arrow_drop_down,
                                                  ),
                                                  iconSize: 24,
                                                  iconEnabledColor:
                                                      Color(0xFFb0b6c3),
                                                  iconDisabledColor:
                                                      Colors.grey,
                                                ),
                                                dropdownStyleData:
                                                    DropdownStyleData(
                                                  decoration: BoxDecoration(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            6),
                                                    color: Colors.white,
                                                  ),
                                                  scrollbarTheme:
                                                      ScrollbarThemeData(
                                                    radius:
                                                        const Radius.circular(
                                                            6),
                                                    thickness:
                                                        MaterialStateProperty
                                                            .all(6),
                                                    thumbVisibility:
                                                        MaterialStateProperty
                                                            .all(true),
                                                  ),
                                                ),
                                                menuItemStyleData:
                                                    const MenuItemStyleData(
                                                  height: 40,
                                                  padding: EdgeInsets.only(
                                                      left: 14, right: 14),
                                                ),
                                                validator: (value) {
                                                  if (value == null ||
                                                      value.isEmpty) {
                                                    return 'Please select an option';
                                                  }
                                                  return null;
                                                },
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(
                                        width: 20,
                                      ),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            units.isNotEmpty
                                                ? const Text('Unit',
                                                    style: TextStyle(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: Colors.grey))
                                                : Container(),
                                            const SizedBox(height: 2),
                                            units.isNotEmpty
                                                ? DropdownButtonHideUnderline(
                                                    child:
                                                        DropdownButtonFormField2<
                                                            String>(
                                                      decoration:
                                                          const InputDecoration(
                                                              border:
                                                                  InputBorder
                                                                      .none),
                                                      isExpanded: true,
                                                      hint: const Row(
                                                        children: [
                                                          Expanded(
                                                            child: Text(
                                                              'Select Unit',
                                                              style: TextStyle(
                                                                fontSize: 14,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w400,
                                                                color: Color(
                                                                    0xFFb0b6c3),
                                                              ),
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      items: units.keys
                                                          .map((unitId) {
                                                        return DropdownMenuItem<
                                                            String>(
                                                          value: unitId,
                                                          child: Text(
                                                            units[unitId]!,
                                                            style:
                                                                const TextStyle(
                                                              fontSize: 14,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w400,
                                                              color: Colors
                                                                  .black87,
                                                            ),
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                          ),
                                                        );
                                                      }).toList(),
                                                      value: _selectedUnitId
                                                              .toString()
                                                              .isNotEmpty
                                                          ? _selectedUnitId
                                                          : null,
                                                      onChanged: (value) {
                                                        setState(() {
                                                          unitId =
                                                              value.toString();
                                                          _selectedUnitId =
                                                              value;
                                                          _selectedUnit = units[
                                                              value]; // Store selected rental_unit
                                                          _loadTenant(
                                                              _selectedPropertyId!,
                                                              unitId);
                                                        });
                                                      },
                                                      buttonStyleData:
                                                          ButtonStyleData(
                                                        height: 45,
                                                        width: 160,
                                                        padding:
                                                            const EdgeInsets
                                                                .only(
                                                                left: 14,
                                                                right: 14),
                                                        decoration:
                                                            BoxDecoration(
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(
                                                                      8.0),
                                                          color: Colors.white,
                                                          border: Border.all(
                                                            color: const Color(
                                                                0xFFCED4DA),
                                                            width: 1.5,
                                                          ),
                                                        ),
                                                        elevation: 0,
                                                      ),
                                                      iconStyleData:
                                                          const IconStyleData(
                                                        icon: Icon(Icons
                                                            .arrow_drop_down),
                                                        iconSize: 24,
                                                        iconEnabledColor:
                                                            Color(0xFFb0b6c3),
                                                        iconDisabledColor:
                                                            Colors.grey,
                                                      ),
                                                      dropdownStyleData:
                                                          DropdownStyleData(
                                                        decoration:
                                                            BoxDecoration(
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(6),
                                                          color: Colors.white,
                                                        ),
                                                        scrollbarTheme:
                                                            ScrollbarThemeData(
                                                          radius: const Radius
                                                              .circular(6),
                                                          thickness:
                                                              MaterialStateProperty
                                                                  .all(6),
                                                          thumbVisibility:
                                                              MaterialStateProperty
                                                                  .all(true),
                                                        ),
                                                      ),
                                                      menuItemStyleData:
                                                          const MenuItemStyleData(
                                                        height: 40,
                                                        padding:
                                                            EdgeInsets.only(
                                                                left: 14,
                                                                right: 14),
                                                      ),
                                                      validator: (value) {
                                                        if (value == null ||
                                                            value.isEmpty) {
                                                          return 'Please select an option';
                                                        }
                                                        return null;
                                                      },
                                                    ),
                                                  )
                                                : Container(),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(
                                    height: 2,
                                  ),
                                  const SizedBox(
                                    height: 10,
                                  ),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.start,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text('Category',
                                                style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(0xFF101828))),
                                            const SizedBox(
                                              height: 10,
                                            ),
                                            DropdownButtonHideUnderline(
                                              child: DropdownButton2<String>(
                                                isExpanded: true,
                                                hint: const Text(
                                                    'Select Category'),
                                                value: _selectedCategory,
                                                items: _category.map((method) {
                                                  return DropdownMenuItem<
                                                      String>(
                                                    value: method,
                                                    child: Text(method),
                                                  );
                                                }).toList(),
                                                onChanged: (String? newValue) {
                                                  setState(() {
                                                    _selectedCategory =
                                                        newValue;
                                                    _showTextField =
                                                        _selectedCategory ==
                                                            'Other';
                                                  });
                                                },
                                                buttonStyleData:
                                                    ButtonStyleData(
                                                  height: 45,
                                                  width: 250,
                                                  padding:
                                                      const EdgeInsets.only(
                                                          left: 14, right: 14),
                                                  decoration: BoxDecoration(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8.0),
                                                    color: Colors.white,
                                                    border: Border.all(
                                                      color: const Color(
                                                          0xFFCED4DA),
                                                      width: 1.5,
                                                    ),
                                                  ),
                                                  elevation: 0,
                                                ),
                                                iconStyleData:
                                                    const IconStyleData(
                                                  icon: Icon(
                                                    Icons.arrow_drop_down,
                                                  ),
                                                  iconSize: 24,
                                                ),
                                                dropdownStyleData:
                                                    DropdownStyleData(
                                                  decoration: BoxDecoration(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            6),
                                                    color: Colors.white,
                                                  ),
                                                  scrollbarTheme:
                                                      ScrollbarThemeData(
                                                    radius:
                                                        const Radius.circular(
                                                            6),
                                                    thickness:
                                                        MaterialStateProperty
                                                            .all(6),
                                                    thumbVisibility:
                                                        MaterialStateProperty
                                                            .all(true),
                                                  ),
                                                ),
                                                menuItemStyleData:
                                                    const MenuItemStyleData(
                                                  height: 50,
                                                  padding: EdgeInsets.only(
                                                      left: 14, right: 14),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(
                                        width: 20,
                                      ),
                                      Expanded(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.start,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text('Entry Allowed ',
                                                style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(0xFF101828))),
                                            const SizedBox(
                                              height: 10,
                                            ),
                                            DropdownButtonHideUnderline(
                                              child: DropdownButton2<String>(
                                                isExpanded: true,
                                                hint: const Text('Select'),
                                                value: _selectedEntry,
                                                items: _entry.map((method) {
                                                  return DropdownMenuItem<
                                                      String>(
                                                    value: method,
                                                    child: Text(method),
                                                  );
                                                }).toList(),
                                                onChanged: (String? newValue) {
                                                  setState(() {
                                                    _selectedEntry = newValue;
                                                    // _selectedPaymentMethod = addRow();
                                                    // if(_selectedCategory == 'Other')
                                                    // addRow();
                                                  });
                                                },
                                                buttonStyleData:
                                                    ButtonStyleData(
                                                  height: 45,
                                                  width: 200,
                                                  padding:
                                                      const EdgeInsets.only(
                                                          left: 14, right: 14),
                                                  decoration: BoxDecoration(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8.0),
                                                    color: Colors.white,
                                                    border: Border.all(
                                                      color: const Color(
                                                          0xFFCED4DA),
                                                      width: 1.5,
                                                    ),
                                                  ),
                                                  elevation: 0,
                                                ),
                                                iconStyleData:
                                                    const IconStyleData(
                                                  icon: Icon(
                                                    Icons.arrow_drop_down,
                                                  ),
                                                  iconSize: 24,
                                                  iconEnabledColor:
                                                      Color(0xFFb0b6c3),
                                                  iconDisabledColor:
                                                      Colors.grey,
                                                ),
                                                dropdownStyleData:
                                                    DropdownStyleData(
                                                  decoration: BoxDecoration(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            6),
                                                    color: Colors.white,
                                                  ),
                                                  scrollbarTheme:
                                                      ScrollbarThemeData(
                                                    radius:
                                                        const Radius.circular(
                                                            6),
                                                    thickness:
                                                        MaterialStateProperty
                                                            .all(6),
                                                    thumbVisibility:
                                                        MaterialStateProperty
                                                            .all(true),
                                                  ),
                                                ),
                                                menuItemStyleData:
                                                    const MenuItemStyleData(
                                                  height: 40,
                                                  padding: EdgeInsets.only(
                                                      left: 14, right: 14),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.start,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text('Assigned To *',
                                                style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(0xFF101828))),
                                            const SizedBox(
                                              height: 2,
                                            ),
                                            _isLoadingstaff
                                                ? const Center(
                                                    child: SpinKitFadingCircle(
                                                      color: Colors.black,
                                                      size: 50.0,
                                                    ),
                                                  )
                                                : Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      DropdownButtonHideUnderline(
                                                        child:
                                                            DropdownButtonFormField2<
                                                                String>(
                                                          decoration:
                                                              const InputDecoration(
                                                                  border:
                                                                      InputBorder
                                                                          .none),
                                                          isExpanded: true,
                                                          hint: const Row(
                                                            children: [
                                                              Expanded(
                                                                child: Text(
                                                                  'Select here',
                                                                  style:
                                                                      TextStyle(
                                                                    fontSize:
                                                                        14,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w400,
                                                                    color: Color(
                                                                        0xFFb0b6c3),
                                                                  ),
                                                                  overflow:
                                                                      TextOverflow
                                                                          .ellipsis,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                          items: (staffs.keys
                                                                  .toList()
                                                                ..sort((a, b) => (staffs[
                                                                            a] ??
                                                                        '')
                                                                    .toLowerCase()
                                                                    .compareTo((staffs[b] ??
                                                                            '')
                                                                        .toLowerCase())))
                                                              .map(
                                                                  (staffmember_id) {
                                                            return DropdownMenuItem<
                                                                String>(
                                                              value:
                                                                  staffmember_id,
                                                              child: Text(
                                                                staffs[
                                                                    staffmember_id]!,
                                                                style:
                                                                    const TextStyle(
                                                                  fontSize: 14,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w400,
                                                                  color: Colors
                                                                      .black87,
                                                                ),
                                                                overflow:
                                                                    TextOverflow
                                                                        .ellipsis,
                                                              ),
                                                            );
                                                          }).toList(),
                                                          value:
                                                              _selectedstaffId,
                                                          onChanged: (value) {
                                                            setState(() {
                                                              // _selectedUnitId = null;
                                                              _selectedstaffId =
                                                                  value;
                                                              _selectedStaffs =
                                                                  staffs[
                                                                      value]; // Store selected rental_adress

                                                              StaffId = value
                                                                  .toString();
                                                              // Units belong to the property,
                                                              // not the staff member.
                                                            });
                                                          },
                                                          buttonStyleData:
                                                              ButtonStyleData(
                                                            height: 45,
                                                            padding:
                                                                const EdgeInsets
                                                                    .only(
                                                                    left: 14,
                                                                    right: 14),
                                                            decoration:
                                                                BoxDecoration(
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          8.0),
                                                              color:
                                                                  Colors.white,
                                                              border:
                                                                  Border.all(
                                                                color: const Color(
                                                                    0xFFCED4DA),
                                                                width: 1.5,
                                                              ),
                                                            ),
                                                            elevation: 0,
                                                          ),
                                                          iconStyleData:
                                                              const IconStyleData(
                                                            icon: Icon(
                                                              Icons
                                                                  .arrow_drop_down,
                                                            ),
                                                            iconSize: 24,
                                                            iconEnabledColor:
                                                                Color(
                                                                    0xFFb0b6c3),
                                                            iconDisabledColor:
                                                                Colors.grey,
                                                          ),
                                                          dropdownStyleData:
                                                              DropdownStyleData(
                                                            maxHeight: 250,
                                                            decoration:
                                                                BoxDecoration(
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          6),
                                                              color:
                                                                  Colors.white,
                                                            ),
                                                            scrollbarTheme:
                                                                ScrollbarThemeData(
                                                              radius:
                                                                  const Radius
                                                                      .circular(
                                                                      6),
                                                              thickness:
                                                                  MaterialStateProperty
                                                                      .all(6),
                                                              thumbVisibility:
                                                                  MaterialStateProperty
                                                                      .all(
                                                                          true),
                                                            ),
                                                          ),
                                                          menuItemStyleData:
                                                              const MenuItemStyleData(
                                                            height: 40,
                                                            padding:
                                                                EdgeInsets.only(
                                                                    left: 14,
                                                                    right: 14),
                                                          ),
                                                          validator: (value) {
                                                            if (value == null ||
                                                                value.isEmpty) {
                                                              return 'Please select an option';
                                                            }
                                                            return null;
                                                          },
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Container(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const SizedBox(height: 18),
                                              const Text('Vendor ',
                                                  style: TextStyle(
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color:
                                                          Color(0xFF101828))),
                                              _isLoadingvendors
                                                  ? const Center(
                                                      child:
                                                          SpinKitFadingCircle(
                                                        color: Colors.black,
                                                        size: 50.0,
                                                      ),
                                                    )
                                                  : Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        DropdownButtonHideUnderline(
                                                          child:
                                                              DropdownButtonFormField2<
                                                                  String>(
                                                            decoration:
                                                                const InputDecoration(
                                                                    border:
                                                                        InputBorder
                                                                            .none),
                                                            isExpanded: true,
                                                            hint: const Row(
                                                              children: [
                                                                Expanded(
                                                                  child: Text(
                                                                    'Select here',
                                                                    style:
                                                                        TextStyle(
                                                                      fontSize:
                                                                          14,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w400,
                                                                      color: Color(
                                                                          0xFFb0b6c3),
                                                                    ),
                                                                    overflow:
                                                                        TextOverflow
                                                                            .ellipsis,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                            items: vendors.keys
                                                                .map(
                                                                    (vender_id) {
                                                              return DropdownMenuItem<
                                                                  String>(
                                                                value:
                                                                    vender_id,
                                                                child: Text(
                                                                  vendors[
                                                                      vender_id]!,
                                                                  style:
                                                                      const TextStyle(
                                                                    fontSize:
                                                                        14,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w400,
                                                                    color: Colors
                                                                        .black87,
                                                                  ),
                                                                  overflow:
                                                                      TextOverflow
                                                                          .ellipsis,
                                                                ),
                                                              );
                                                            }).toList(),
                                                            value:
                                                                _selectedvendorsId,
                                                            onChanged: (value) {
                                                              setState(() {
                                                                // _selectedUnitId = null;
                                                                _selectedvendorsId =
                                                                    value;
                                                                _selectedVendors =
                                                                    vendors[
                                                                        value]; // Store selected rental_adress

                                                                vendorId = value
                                                                    .toString();
                                                                // Units belong to the property,
                                                                // not the vendor.
                                                              });
                                                            },
                                                            buttonStyleData:
                                                                ButtonStyleData(
                                                              height: 45,
                                                              width: 160,
                                                              padding:
                                                                  const EdgeInsets
                                                                      .only(
                                                                      left: 14,
                                                                      right:
                                                                          14),
                                                              decoration:
                                                                  BoxDecoration(
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            8.0),
                                                                color: Colors
                                                                    .white,
                                                                border:
                                                                    Border.all(
                                                                  color: const Color(
                                                                      0xFFCED4DA),
                                                                  width: 1.5,
                                                                ),
                                                              ),
                                                              elevation: 0,
                                                            ),
                                                            iconStyleData:
                                                                const IconStyleData(
                                                              icon: Icon(
                                                                Icons
                                                                    .arrow_drop_down,
                                                              ),
                                                              iconSize: 24,
                                                              iconEnabledColor:
                                                                  Color(
                                                                      0xFFb0b6c3),
                                                              iconDisabledColor:
                                                                  Colors.grey,
                                                            ),
                                                            dropdownStyleData:
                                                                DropdownStyleData(
                                                              decoration:
                                                                  BoxDecoration(
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            6),
                                                                color: Colors
                                                                    .white,
                                                              ),
                                                              scrollbarTheme:
                                                                  ScrollbarThemeData(
                                                                radius:
                                                                    const Radius
                                                                        .circular(
                                                                        6),
                                                                thickness:
                                                                    MaterialStateProperty
                                                                        .all(6),
                                                                thumbVisibility:
                                                                    MaterialStateProperty
                                                                        .all(
                                                                            true),
                                                              ),
                                                            ),
                                                            menuItemStyleData:
                                                                const MenuItemStyleData(
                                                              height: 40,
                                                              padding: EdgeInsets
                                                                  .only(
                                                                      left: 14,
                                                                      right:
                                                                          14),
                                                            ),
                                                            validator: (value) {
                                                              if (value ==
                                                                      null ||
                                                                  value
                                                                      .isEmpty) {
                                                                return 'Please select an option';
                                                              }
                                                              return null;
                                                            },
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Container(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Text('Work To Be Performed',
                                                  style: TextStyle(
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color:
                                                          Color(0xFF101828))),
                                              const SizedBox(
                                                height: 10,
                                              ),
                                              CustomTextField(
                                                keyboardType:
                                                    TextInputType.text,
                                                hintText: 'Enter here',
                                                controller: perform,
                                                optional: true,
                                                showElevation: false,
                                                borderColor:
                                                    const Color(0xFFCED4DA),
                                                borderWidth: 1.5,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(
                                    height: 10,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Container(
                            width: double.infinity,
                            // height: !form_valid ? 860 : 830,
                            decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10.0),
                                border: Border.all(
                                  color: const Color(0xFFCED4DA),
                                )),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    children: [
                                      Text('Parts And Labour ',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                  /*   ...partsAndLabor.asMap().entries.map((entry) {
                                    int index = entry.key;
                                    return buildRow(index);
                                  }).toList(),
                                  SizedBox(
                                    height: 10,
                                  ),
                                  Row(
                                    children: [
                                      // SizedBox(width: 10),
                                      Text('Total :',
                                          style:
                                          TextStyle(fontWeight: FontWeight.bold,)),
                                      Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child:
                                        Text(formatMoney(totalAmount)),
                                      ),
                                    ],
                                  ),*/
                                  const SizedBox(
                                    height: 10,
                                  ),
                                  Table(
                                    border: TableBorder.all(width: 1),
                                    columnWidths: const {
                                      0: FlexColumnWidth(2),
                                      1: FlexColumnWidth(3),
                                      2: FlexColumnWidth(3),
                                      3: FlexColumnWidth(2),
                                      4: FlexColumnWidth(2),
                                    },
                                    children: [
                                      TableRow(children: [
                                        Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Text('QTY',
                                              style: TextStyle(
                                                  color: blueColor,
                                                  fontWeight: FontWeight.bold)),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Text('Account',
                                              style: TextStyle(
                                                  color: blueColor,
                                                  fontWeight: FontWeight.bold)),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Text('Description',
                                              style: TextStyle(
                                                  color: blueColor,
                                                  fontWeight: FontWeight.bold)),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Text('Price',
                                              style: TextStyle(
                                                  color: blueColor,
                                                  fontWeight: FontWeight.bold)),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Text('Amount',
                                              style: TextStyle(
                                                  color: blueColor,
                                                  fontWeight: FontWeight.bold)),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Text('',
                                              style: TextStyle(
                                                  color: blueColor,
                                                  fontWeight: FontWeight.bold)),
                                        ),
                                      ]),
                                      /* ...summery.partsandchargeData!.asMap().entries.map((entry) {
                                      int index = entry.key;
                                      PartsandchargeData row = entry.value;
                                      grandTotal += (row.partsQuantity! * row.partsPrice!);
                                      return TableRow(children: [
                                        Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child:Text("${row.partsQuantity}"),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child:Text("${row.account}"),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child:Text("${row.description}"),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child:Text(formatMoney(row.partsPrice ?? 0)),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child:Text(formatMoney(row.partsPrice! * row.partsQuantity!)),
                                        ),
                                      ]);
                                    }).toList(),*/
                                      ...partsAndLabor
                                          .asMap()
                                          .entries
                                          .map((entry) {
                                        int index = entry.key;
                                        return TableRow(children: [
                                          Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: CustomTextField(
                                              hintText: 'Quantity',
                                              controller: partsAndLabor[index]
                                                  ['qtyController'],
                                              keyboardType:
                                                  TextInputType.number,
                                              showElevation: false,
                                              borderColor:
                                                  const Color(0xFFCED4DA),
                                              borderWidth: 1.5,
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: DropdownButtonHideUnderline(
                                              child: DropdownButton2<String>(
                                                isExpanded: true,
                                                hint: const Text('Select'),
                                                value: _account.contains(
                                                        partsAndLabor[index]
                                                            ['selectedAccount'])
                                                    ? partsAndLabor[index]
                                                        ['selectedAccount']
                                                    : null,
                                                items: _account.map((method) {
                                                  return DropdownMenuItem<
                                                      String>(
                                                    value: method,
                                                    child: Text(method),
                                                  );
                                                }).toList(),
                                                onChanged: (String? newValue) {
                                                  setState(() {
                                                    partsAndLabor[index][
                                                            'selectedAccount'] =
                                                        newValue;
                                                  });
                                                },
                                                buttonStyleData:
                                                    ButtonStyleData(
                                                  height: 45,
                                                  // width: 300,
                                                  //  padding: const EdgeInsets.only(left: 14, right: 14),
                                                  decoration: BoxDecoration(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8.0),
                                                    color: Colors.white,
                                                    border: Border.all(
                                                      color: const Color(
                                                          0xFFCED4DA),
                                                      width: 1.5,
                                                    ),
                                                  ),
                                                  elevation: 0,
                                                ),
                                                iconStyleData:
                                                    const IconStyleData(
                                                  icon: Icon(
                                                    Icons.arrow_drop_down,
                                                  ),
                                                  iconSize: 24,
                                                  iconEnabledColor:
                                                      Color(0xFFb0b6c3),
                                                  iconDisabledColor:
                                                      Colors.grey,
                                                ),
                                                dropdownStyleData:
                                                    DropdownStyleData(
                                                  decoration: BoxDecoration(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            6),
                                                    color: Colors.white,
                                                  ),
                                                  scrollbarTheme:
                                                      ScrollbarThemeData(
                                                    radius:
                                                        const Radius.circular(
                                                            6),
                                                    thickness:
                                                        MaterialStateProperty
                                                            .all(6),
                                                    thumbVisibility:
                                                        MaterialStateProperty
                                                            .all(true),
                                                  ),
                                                ),
                                                menuItemStyleData:
                                                    const MenuItemStyleData(
                                                  height: 50,
                                                  padding: EdgeInsets.only(
                                                      left: 14, right: 14),
                                                ),
                                              ),
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: CustomTextField(
                                              hintText: 'Description',
                                              controller: partsAndLabor[index]
                                                  ['descriptionController'],
                                              keyboardType: TextInputType.text,
                                              showElevation: false,
                                              borderColor:
                                                  const Color(0xFFCED4DA),
                                              borderWidth: 1.5,
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: CustomTextField(
                                              hintText: 'Price',
                                              controller: partsAndLabor[index]
                                                  ['priceController'],
                                              keyboardType:
                                                  TextInputType.number,
                                              showElevation: false,
                                              borderColor:
                                                  const Color(0xFFCED4DA),
                                              borderWidth: 1.5,
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: CustomTextField(
                                              hintText: 'Total',
                                              controller: partsAndLabor[index]
                                                  ['totalController'],
                                              keyboardType:
                                                  TextInputType.number,
                                              readOnnly: true,
                                              showElevation: false,
                                              borderColor:
                                                  const Color(0xFFCED4DA),
                                              borderWidth: 1.5,
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: IconButton(
                                              icon: const Icon(Icons.close,
                                                  color: Colors.black),
                                              onPressed: () {
                                                deleteRow(index);
                                              },
                                            ),
                                          ),
                                          /* Padding(
                                        padding: EdgeInsets.all(8.0),
                                        child: Text(formatMoney(grandTotal),style: TextStyle(
                                            fontWeight: FontWeight.bold)),
                                      ),*/

                                          /* Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                              formatMoney(totalAmount)),
                        ),*/
                                        ]);
                                      }).toList(),
                                      TableRow(children: [
                                        const Padding(
                                          padding: EdgeInsets.all(8.0),
                                          child: Text('Total',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.bold)),
                                        ),
                                        const Padding(
                                          padding: EdgeInsets.all(8.0),
                                          child: Text('',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.bold)),
                                        ),
                                        const Padding(
                                          padding: EdgeInsets.all(8.0),
                                          child: Text('',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.bold)),
                                        ),
                                        const Padding(
                                          padding: EdgeInsets.all(8.0),
                                          child: Text('',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.bold)),
                                        ),
                                        /* const Padding(
                                        padding: EdgeInsets.all(8.0),
                                        child: Text('',
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold)),
                                      ),*/
                                        Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Text(
                                              formatMoney(totalAmount)),
                                        ),
                                        const Padding(
                                          padding: EdgeInsets.all(8.0),
                                          child: Text(''),
                                        ),

                                        /* Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                              formatMoney(totalAmount)),
                        ),*/
                                      ]),
                                      /*TableRow(children: [
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Container(
                            height: 34,
                            decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border.all(width: 1),
                                borderRadius:
                                BorderRadius.circular(10.0)),
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                      BorderRadius.circular(
                                          10.0)),
                                  elevation: 0,
                                  backgroundColor: Colors.white),
                              onPressed: addRow,
                              child: const Text(
                                'Add Row',
                                style: TextStyle(
                                  color:
                                  blueColor,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox.shrink(),
                        const SizedBox.shrink(),
                      ]),*/
                                    ],
                                  ),
                                  ElevatedButton(
                                    onPressed: addRow,
                                    child: const Text('Add Row'),
                                  ),
                                  const SizedBox(
                                    height: 10,
                                  ),
                                  const SizedBox(
                                    height: 20,
                                  ),
                                  Row(
                                    children: [
                                      const Text(
                                        "Billable To Tenants",
                                        style: TextStyle(color: Colors.grey),
                                      ),
                                      const SizedBox(
                                        width: 10,
                                      ),
                                      SizedBox(
                                        width:
                                            24.0, // Standard width for checkbox
                                        height: 24.0,
                                        child: Checkbox(
                                          value: isChecked,
                                          onChanged: (value) {
                                            setState(() {
                                              isChecked = value ?? false;
                                            });
                                          },
                                          activeColor: isChecked
                                              ? blueColor
                                              : Colors.black,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(
                                    height: 10,
                                  ),
                                  Row(
                                    children: [
                                      if (isChecked)
                                        Expanded(
                                          child: Container(
                                            child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.start,
                                              children: [
                                                _isLoadingtenant
                                                    ? const Center(
                                                        child:
                                                            SpinKitFadingCircle(
                                                          color: Colors.black,
                                                          size: 50.0,
                                                        ),
                                                      )
                                                    : tenants.isNotEmpty
                                                        ? Column(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                              const SizedBox(
                                                                height: 3,
                                                              ),
                                                              const Text(
                                                                  'Tenant',
                                                                  style: TextStyle(
                                                                      fontSize:
                                                                          13,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .bold,
                                                                      color: Colors
                                                                          .grey)),
                                                              const SizedBox(
                                                                height: 5,
                                                              ),
                                                              DropdownButtonHideUnderline(
                                                                child:
                                                                    DropdownButtonFormField2<
                                                                        String>(
                                                                  decoration:
                                                                      const InputDecoration(
                                                                          border:
                                                                              InputBorder.none),
                                                                  isExpanded:
                                                                      true,
                                                                  hint:
                                                                      const Row(
                                                                    children: [
                                                                      Expanded(
                                                                        child:
                                                                            Text(
                                                                          'Select Tenant',
                                                                          style:
                                                                              TextStyle(
                                                                            fontSize:
                                                                                14,
                                                                            fontWeight:
                                                                                FontWeight.w400,
                                                                            color:
                                                                                Color(0xFFb0b6c3),
                                                                          ),
                                                                          overflow:
                                                                              TextOverflow.ellipsis,
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                  items: tenants
                                                                      .keys
                                                                      .map(
                                                                          (tenantId) {
                                                                    return DropdownMenuItem<
                                                                        String>(
                                                                      value:
                                                                          tenantId,
                                                                      child:
                                                                          Text(
                                                                        tenants[
                                                                            tenantId]!,
                                                                        style:
                                                                            const TextStyle(
                                                                          fontSize:
                                                                              14,
                                                                          fontWeight:
                                                                              FontWeight.w400,
                                                                          color:
                                                                              Colors.black87,
                                                                        ),
                                                                        overflow:
                                                                            TextOverflow.ellipsis,
                                                                      ),
                                                                    );
                                                                  }).toList(),
                                                                  value: tenants
                                                                          .containsKey(
                                                                              _selectedtenantId)
                                                                      ? _selectedtenantId
                                                                      : null,
                                                                  onChanged:
                                                                      (value) {
                                                                    setState(
                                                                        () {
                                                                      tenantId =
                                                                          value
                                                                              .toString();
                                                                      _selectedtenantId =
                                                                          value;
                                                                      _selectedTenants =
                                                                          tenants[
                                                                              value]; // Store selected tenant name
                                                                    });
                                                                  },
                                                                  buttonStyleData:
                                                                      ButtonStyleData(
                                                                    height: 45,
                                                                    width: 160,
                                                                    padding: const EdgeInsets
                                                                        .only(
                                                                        left:
                                                                            14,
                                                                        right:
                                                                            14),
                                                                    decoration:
                                                                        BoxDecoration(
                                                                      borderRadius:
                                                                          BorderRadius.circular(
                                                                              6),
                                                                      color: Colors
                                                                          .white,
                                                                    ),
                                                                    elevation:
                                                                        2,
                                                                  ),
                                                                  iconStyleData:
                                                                      const IconStyleData(
                                                                    icon: Icon(Icons
                                                                        .arrow_drop_down),
                                                                    iconSize:
                                                                        24,
                                                                    iconEnabledColor:
                                                                        Color(
                                                                            0xFFb0b6c3),
                                                                    iconDisabledColor:
                                                                        Colors
                                                                            .grey,
                                                                  ),
                                                                  dropdownStyleData:
                                                                      DropdownStyleData(
                                                                    decoration:
                                                                        BoxDecoration(
                                                                      borderRadius:
                                                                          BorderRadius.circular(
                                                                              6),
                                                                      color: Colors
                                                                          .white,
                                                                    ),
                                                                    scrollbarTheme:
                                                                        ScrollbarThemeData(
                                                                      radius: const Radius
                                                                          .circular(
                                                                          6),
                                                                      thickness:
                                                                          MaterialStateProperty.all(
                                                                              6),
                                                                      thumbVisibility:
                                                                          MaterialStateProperty.all(
                                                                              true),
                                                                    ),
                                                                  ),
                                                                  menuItemStyleData:
                                                                      const MenuItemStyleData(
                                                                    height: 40,
                                                                    padding: EdgeInsets.only(
                                                                        left:
                                                                            14,
                                                                        right:
                                                                            14),
                                                                  ),
                                                                  validator:
                                                                      (value) {
                                                                    if (value ==
                                                                            null ||
                                                                        value
                                                                            .isEmpty) {
                                                                      return 'Please select an option';
                                                                    }
                                                                    return null;
                                                                  },
                                                                ),
                                                              ),
                                                            ],
                                                          )
                                                        : Container(),
                                              ],
                                            ),
                                          ),
                                        ),
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Container(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                const Text('Vendors Note *',
                                                    style: TextStyle(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color:
                                                            Color(0xFF101828))),
                                                const SizedBox(
                                                  height: 10,
                                                ),
                                                CustomTextField(
                                                  keyboardType:
                                                      TextInputType.text,
                                                  hintText: 'Enter here',
                                                  controller: vendornote,
                                                  optional: true,
                                                  showElevation: false,
                                                  borderColor:
                                                      const Color(0xFFCED4DA),
                                                  borderWidth: 1.5,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(
                                    height: 20,
                                  ),
                                  /* Row(
                                children: [
                                  Text("Billable To Tenants",style: TextStyle(
                                      color: Colors.grey
                                  ),),
                                  SizedBox(width: 10,),
                                  SizedBox(
                                    width: 24.0, // Standard width for checkbox
                                    height: 24.0,
                                    child: Checkbox(
                                      value: isChecked,
                                      onChanged: (value) {
                                        setState(() {
                                          isChecked = value ?? false;
                                        });
                                      },
                                      activeColor: isChecked
                                          ? blueColor
                                          : Colors.black,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(
                                height: 10,
                              ),
                              if(isChecked)
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    _isLoadingtenant
                                        ? const Center(
                                      child: SpinKitFadingCircle(
                                        color: Colors.black,
                                        size: 50.0,
                                      ),
                                    )
                                        : tenants.isNotEmpty
                                        ? Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Tenant',
                                            style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF101828))),
                                        SizedBox(height: 2),
                                        DropdownButtonHideUnderline(
                                          child: DropdownButtonFormField2<String>(
                                            decoration: InputDecoration(border: InputBorder.none),
                                            isExpanded: true,
                                            hint: const Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    'Select Tenant',
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.w400,
                                                      color: Color(0xFFb0b6c3),
                                                    ),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            items: tenants.keys.map((tenantId) {
                                              return DropdownMenuItem<String>(
                                                value: tenantId,
                                                child: Text(
                                                  tenants[tenantId]!,
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w400,
                                                    color: Colors.black87,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              );
                                            }).toList(),
                                            value: _selectedtenantId,
                                            onChanged: (value) {
                                              setState(() {
                                                tenantId = value.toString();
                                                _selectedtenantId = value;
                                                _selectedTenants = tenants[value]; // Store selected tenant name
                                              });
                                            },
                                            buttonStyleData: ButtonStyleData(
                                              height: 45,
                                              width: 160,
                                              padding: const EdgeInsets.only(left: 14, right: 14),
                                              decoration: BoxDecoration(
                                                borderRadius: BorderRadius.circular(8.0),
                                                color: Colors.white,
                                                border: Border.all(
                                                  color: const Color(0xFFCED4DA),
                                                  width: 1.5,
                                                ),
                                              ),
                                              elevation: 0,
                                            ),
                                            iconStyleData: const IconStyleData(
                                              icon: Icon(Icons.arrow_drop_down),
                                              iconSize: 24,
                                              iconEnabledColor: Color(0xFFb0b6c3),
                                              iconDisabledColor: Colors.grey,
                                            ),
                                            dropdownStyleData: DropdownStyleData(
                                              decoration: BoxDecoration(
                                                borderRadius: BorderRadius.circular(8.0),
                                                color: Colors.white,
                                              ),
                                              scrollbarTheme: ScrollbarThemeData(
                                                radius: const Radius.circular(6),
                                                thickness: MaterialStateProperty.all(6),
                                                thumbVisibility: MaterialStateProperty.all(true),
                                              ),
                                            ),
                                            menuItemStyleData: const MenuItemStyleData(
                                              height: 40,
                                              padding: EdgeInsets.only(left: 14, right: 14),
                                            ),
                                            validator: (value) {
                                              if (value == null || value.isEmpty) {
                                                return 'Please select an option';
                                              }
                                              return null;
                                            },
                                          ),
                                        ),
                                      ],
                                    )
                                        : Container(),
                                  ],
                                ),
                              SizedBox(
                                height: 15,
                              ),*/
                                  const Row(
                                    children: [
                                      Text(
                                        "Priority",
                                        style: TextStyle(color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Expanded(
                                        flex: 1,
                                        child: ListTile(
                                          title: const Text('High'),
                                          leading: Radio<String>(
                                            value: 'High',
                                            groupValue: _selectedOption,
                                            onChanged: _handleRadioValueChange,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 1,
                                        child: ListTile(
                                          title: const Text('Normal'),
                                          leading: Radio<String>(
                                            value: 'Normal',
                                            groupValue: _selectedOption,
                                            onChanged: _handleRadioValueChange,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 1,
                                        child: ListTile(
                                          title: const Text('Low'),
                                          leading: Radio<String>(
                                            value: 'Low',
                                            groupValue: _selectedOption,
                                            onChanged: _handleRadioValueChange,
                                          ),
                                        ),
                                      ),
                                      const Expanded(
                                        flex: 1,
                                        child: ListTile(
                                          title: Text(''),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(
                                    height: 10,
                                  ),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.start,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text('Status *',
                                                style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(0xFF101828))),
                                            const SizedBox(
                                              height: 10,
                                            ),
                                            DropdownButtonHideUnderline(
                                              child: DropdownButton2<String>(
                                                isExpanded: true,
                                                hint: const Text('New'),
                                                value: _selectedStatus,
                                                items: _status.map((method) {
                                                  return DropdownMenuItem<
                                                      String>(
                                                    value: method,
                                                    child: Text(method),
                                                  );
                                                }).toList(),
                                                onChanged: (String? newValue) {
                                                  setState(() {
                                                    _selectedStatus = newValue;
                                                  });
                                                },
                                                buttonStyleData:
                                                    ButtonStyleData(
                                                  height: 45,
                                                  width: 200,
                                                  padding:
                                                      const EdgeInsets.only(
                                                          left: 14, right: 14),
                                                  decoration: BoxDecoration(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8.0),
                                                    color: Colors.white,
                                                    border: Border.all(
                                                      color: const Color(
                                                          0xFFCED4DA),
                                                      width: 1.5,
                                                    ),
                                                  ),
                                                  elevation: 0,
                                                ),
                                                iconStyleData:
                                                    const IconStyleData(
                                                  icon: Icon(
                                                    Icons.arrow_drop_down,
                                                  ),
                                                  iconSize: 24,
                                                  iconEnabledColor:
                                                      Color(0xFFb0b6c3),
                                                  iconDisabledColor:
                                                      Colors.grey,
                                                ),
                                                dropdownStyleData:
                                                    DropdownStyleData(
                                                  decoration: BoxDecoration(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            6),
                                                    color: Colors.white,
                                                  ),
                                                  scrollbarTheme:
                                                      ScrollbarThemeData(
                                                    radius:
                                                        const Radius.circular(
                                                            6),
                                                    thickness:
                                                        MaterialStateProperty
                                                            .all(6),
                                                    thumbVisibility:
                                                        MaterialStateProperty
                                                            .all(true),
                                                  ),
                                                ),
                                                menuItemStyleData:
                                                    const MenuItemStyleData(
                                                  height: 40,
                                                  padding: EdgeInsets.only(
                                                      left: 14, right: 14),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(
                                        width: 15,
                                      ),
                                      Expanded(
                                        flex: 1,
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.start,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text('Due Date *',
                                                style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(0xFF101828))),
                                            const SizedBox(
                                              height: 10,
                                            ),
                                            FormField<String>(
                                              // Web parity (AddWorkorder.js): due date is required. The error
                                              // renders below the box so the field keeps its 50px height.
                                              validator: (value) =>
                                                  _dateController.text.trim().isEmpty
                                                      ? 'Please select due date'
                                                      : null,
                                              builder: (FormFieldState<String> state) {
                                                return Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                  Container(
                                                    height: 50,
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                            horizontal: 16.0,
                                                            vertical: 0),
                                                    decoration: BoxDecoration(
                                                        color: Colors.white,
                                                        border: Border.all(
                                                          color:
                                                              const Color(0xFFCED4DA),
                                                          width: 1.5,
                                                        ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                                8.0)),
                                                    child: TextFormField(
                                                      style: const TextStyle(
                                                        // A selected date is a VALUE, not a hint: #8898aa is the
                                                        // placeholder grey, which made a chosen date read as
                                                        // unfilled next to Status and the "Enter here" fields.
                                                        color: Colors.black87,
                                                        fontSize: 16.0, // Text size
                                                        fontWeight: FontWeight
                                                            .w400, // Text weight
                                                      ),
                                                      controller: _dateController,
                                                      decoration: InputDecoration(
                                                        hintStyle: const TextStyle(
                                                            fontWeight:
                                                                FontWeight.w500,
                                                            fontSize: 13,
                                                            color: Color(0xFFb0b6c3)),
                                                        border: InputBorder.none,
                                                        // labelText: 'Select Date',
                                                        hintText:
                                                            Provider.of<DateProvider>(
                                                                    context)
                                                                .dateFormat,
                                                        suffixIcon: IconButton(
                                                          padding: EdgeInsets.zero,
                                                          constraints: const BoxConstraints(
                                                              minWidth: 36, minHeight: 36),
                                                          visualDensity: VisualDensity.compact,
                                                          icon: const Icon(Icons.calendar_today, size: 18),
                                                          onPressed: () => _selectDate(context),
                                                        ),
                                                      ),
                                                      readOnly: true,
                                                      onTap: () {
                                                        _selectDate(context);
                                                      },
                                                    ),
                                                  ),
                                                    if (state.hasError)
                                                      Padding(
                                                        padding: const EdgeInsets.only(left: 0, top: 4),
                                                        child: Text(
                                                          state.errorText!,
                                                          style: const TextStyle(
                                                            color: Colors.red,
                                                            fontSize: 11,
                                                          ),
                                                        ),
                                                      ),
                                                  ],
                                                );
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Expanded(
                                        flex: 2,
                                        child: ListTile(
                                          title: Text(''),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(
                                    height: 10,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              Container(
                                height: 50,
                                width: 150,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: canSave
                                        ? blueColor
                                        : const Color(0xFFE5E8ED),
                                    disabledBackgroundColor:
                                        const Color(0xFFE5E8ED),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8.0),
                                    ),
                                  ),
                                  // Web parity: disabled until something changed.
                                  onPressed: (isLoading || !canSave)
                                      ? null
                                      : _submitForm,
                                  child: isLoading
                                      ? const Center(
                                          child: SpinKitFadingCircle(
                                            color: Colors.white,
                                            size: 55.0,
                                          ),
                                        )
                                      : Text(
                                          'Edit Work Order',
                                          style: TextStyle(
                                              color: canSave
                                                  ? const Color(0xFFf7f8f9)
                                                  : Colors.grey),
                                        ),
                                ),
                              ),
                              const SizedBox(
                                width: 8,
                              ),
                              Container(
                                  height: 50,
                                  width: 120,
                                  decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8.0)),
                                  child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              const Color(0xFFffffff),
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8.0))),
                                      onPressed: () {
                                        Navigator.pop(context);
                                      },
                                      child: const Text(
                                        'Cancel',
                                        style:
                                            TextStyle(color: Color(0xFF748097)),
                                      )))
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ));
  }

  Widget buildTextField(
      String label, String hintText, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label,
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 8.0),
        Material(
          elevation: 3,
          borderRadius: BorderRadius.circular(5),
          child: Container(
            padding: const EdgeInsets.only(left: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(5),
            ),
            child: TextFormField(
              controller: controller,
              focusNode: FocusNode(),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: hintText,
              ),
            ),
          ),
        ),
      ],
    );
  }

  bool isLoading = false;
  bool formValid = true;

  // Web parity (AddWorkorder.jsx normalizeValue / checkForChanges): a no-op
  // save must never reach the server, which mails everyone on every PUT.
  String _normDirty(dynamic v) => v == null ? '' : v.toString().trim();

  bool _imagesDiffer() {
    final cur = _imageUrls;
    final was = initialSelectedimage ?? const <String>[];
    if (cur.length != was.length) return true;
    for (var i = 0; i < cur.length; i++) {
      if (_normDirty(cur[i]) != _normDirty(was[i])) return true;
    }
    return false;
  }

  bool _partsDiffer() {
    final was = initialSelectedparts ?? const <Map<String, String>>[];
    if (partsAndLabor.length != was.length) return true;
    for (var i = 0; i < partsAndLabor.length; i++) {
      final c = partsAndLabor[i];
      final w = was[i];
      if (_normDirty(c['qtyController']?.text) != _normDirty(w['qty'])) {
        return true;
      }
      if (_normDirty(c['selectedAccount']) != _normDirty(w['account'])) {
        return true;
      }
      if (_normDirty(c['descriptionController']?.text) !=
          _normDirty(w['description'])) {
        return true;
      }
      if (_normDirty(c['priceController']?.text) != _normDirty(w['price'])) {
        return true;
      }
      if (_normDirty(c['totalController']?.text) != _normDirty(w['total'])) {
        return true;
      }
    }
    return false;
  }

  bool _hasWorkOrderChanges() {
    if (!_dirtySnapshotReady) return false;
    return _normDirty(subject.text) != _normDirty(initialSubject) ||
        _normDirty(perform.text) != _normDirty(initialPerform) ||
        _normDirty(vendornote.text) != _normDirty(initialVendorNote) ||
        _normDirty(_dateController.text) != _normDirty(initialDate) ||
        _normDirty(_selectedPropertyId) !=
            _normDirty(initialSelectedPropertyId) ||
        _normDirty(_selectedUnitId) != _normDirty(initialSelectedUnitId) ||
        _normDirty(_selectedCategory) != _normDirty(initialSelectedCategory) ||
        _normDirty(_selectedStatus) != _normDirty(initialSelectedStatus) ||
        _normDirty(_selectedvendorsId) != _normDirty(initialSelectedVendorId) ||
        _normDirty(_selectedstaffId) != _normDirty(initialSelectedStaffId) ||
        _normDirty(_selectedtenantId) != _normDirty(initialSelectedTenantId) ||
        _normDirty(_selectedOption) != _normDirty(initialSelectedpriority) ||
        _normDirty(_selectedEntry) != _normDirty(initialSelectedEntry) ||
        isChecked != (initialSelectedbillable ?? false) ||
        _imagesDiffer() ||
        _partsDiffer();
  }

  void _onDirtyFieldChanged() {
    final v = _hasWorkOrderChanges();
    if (v != _lastDirty) {
      _lastDirty = v;
      if (mounted) setState(() {});
    }
  }

  void _submitForm() async {
    if (_formkey.currentState!.validate()) {
      setState(() {
        isLoading = true;
      });

      // Submit-time backstop for the same check the button is gated on.
      if (!_hasWorkOrderChanges()) {
        setState(() {
          isLoading = false;
        });
        Fluttertoast.showToast(
          msg: "Please change at least one field to update the Work Order",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          timeInSecForIosWeb: 1,
          backgroundColor: Colors.orange,
          textColor: Colors.white,
          fontSize: 16.0,
        );
        return;
      }

      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? id = prefs.getString("adminId");
      String? token = prefs.getString('token');
      String? rentalId = _selectedPropertyId;
      String? unitId = _selectedUnitId;
      String? finalVendorId = _selectedvendorsId ?? vendorId;
      // Fall back to the tenant loaded with the work order when the dropdown
      // was never re-picked, so saving does not clear the existing tenant.
      String? finalTenantId = _selectedtenantId ?? tenantId;
      List<Map<String, dynamic>> parts = partsAndLabor.map((part) {
        return {
          'parts_id': part['parts_id'],
          "parts_quantity":
              int.tryParse(part['qtyController'].text.trim()) ?? 0,
          "account": part['selectedAccount'],
          "description": part['descriptionController'].text.trim(),
          "charge_type": "Workorder Charge",
          "parts_price":
              double.tryParse(part['priceController'].text.trim()) ?? 0.0,
          "amount": double.tryParse(part['totalController'].text.trim()) ?? 0.0,
        };
      }).toList();
      log(parts.toString());
      WorkOrderRepository()
          .EditWorkOrder(
        adminId: id,
        workOrderid: widget.workorderId,
        workSubject: subject.text.trim(),
        staffMemberName: _selectedstaffId,
        workCategory: _selectedCategory,
        workPerformed: perform.text.trim(),
        status: _selectedStatus,
        rentalAddress: properties[_selectedPropertyId],
        rentalUnit: units[_selectedUnitId],
        tenant: finalTenantId,
        rentalid: rentalId,
        unitid: unitId,
        workOrderImages: _imageUrls,
        vendorId: finalVendorId,
        vendorNotes: vendornote.text.trim(),
        priority: _selectedOption,
        isBillable: isChecked,
        // Web parity (AddWorkorder.jsx): the string "Tenant" when billable,
        // otherwise "". This compared a bool to a String, which is always
        // false, so work_charge_to was stored as false every time.
        workChargeTo: isChecked ? 'Tenant' : '',
        date: reverseFormatDate(_dateController.text.trim()),
        entry: _selectedEntry == 'true',
        parts: parts,
        notificationTime:
            DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
      )
          .then((value) {
        if (!mounted) return;
        setState(() {
          widget.property?.workSubject = subject.text;
        });
        // Success
        Fluttertoast.showToast(
          msg: "Work order updated successfully",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          timeInSecForIosWeb: 1,
          backgroundColor: Colors.green,
          textColor: Colors.white,
          fontSize: 16.0,
        );
        Navigator.pop(context, true);
      }).catchError((e) {
        // Error
        Fluttertoast.showToast(
          msg: "Failed to edit work order: ${friendlyErrorMessage(e)}",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          timeInSecForIosWeb: 1,
          backgroundColor: Colors.red,
          textColor: Colors.white,
          fontSize: 16.0,
        );
      }).whenComplete(() {
        // Final cleanup
        if (mounted) {
          setState(() {
            isLoading = false;
          });
        }
      });
    } else {
      setState(() {
        formValid = false;
      });
    }
  }

  void _showImageDialog(
      dynamic imageFile, int imageIndex, File? originalFile, bool isVideo) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: Container(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Preview',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: blueColor,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: blueColor, width: 1),
                        ),
                        child: Icon(
                          Icons.close,
                          color: blueColor,
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20),
                Stack(
                  alignment: Alignment.center,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: imageFile is String
                          ? Image.network(
                              imageFile,
                              fit: BoxFit.cover,
                              height: 300,
                              width: 300,
                            )
                          : Image.file(
                              imageFile,
                              fit: BoxFit.cover,
                              height: 300,
                              width: 300,
                            ),
                    ),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: GestureDetector(
                        onTap: () async {
                          final ImagePicker _picker = ImagePicker();
                          final XFile? image = await _picker.pickMedia();

                          if (image != null) {
                            final File newFile = File(image.path);
                            // Lowercased: iPhone camera videos are .MOV.
                            bool isNewVideo =
                                image.path.toLowerCase().endsWith('.mp4') ||
                                    image.path.toLowerCase().endsWith('.mov');

                            if (isNewVideo) {
                              String? thumbnailPath =
                                  await _generateVideoThumbnail(image.path);
                              if (thumbnailPath != null) {
                                Navigator.of(context).pop();
                                _showImageDialog(File(thumbnailPath),
                                    imageIndex, newFile, true);
                              }
                            } else {
                              Navigator.of(context).pop();
                              _showImageDialog(
                                  newFile, imageIndex, newFile, false);
                            }
                          }
                        },
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: blueColor,
                        side: BorderSide(color: blueColor, width: 1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding:
                            EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: blueColor),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        Navigator.of(context).pop();

                        // The grid renders _imageUrls, so nothing changes on
                        // screen until the new file has actually landed. The
                        // old path wrote _images by an _imageUrls index (a list
                        // never seeded on Edit) and never wrote the new
                        // filename into _imageUrls, so a replacement was lost
                        // even when the upload succeeded.
                        if (imageIndex >= _imageUrls.length) return;
                        final File? newFile =
                            originalFile ?? (imageFile is File ? imageFile : null);
                        if (newFile == null) return;
                        final String oldName = _imageUrls[imageIndex];

                        try {
                          String? fileName = await uploadImage(newFile);
                          if (!mounted) return;
                          if (fileName == null) {
                            throw Exception('upload returned no filename');
                          }
                          // Rows may have shifted while uploading; find our own.
                          final int row = _imageUrls.indexOf(oldName);
                          if (row != -1) {
                            setState(() {
                              _imageUrls[row] = fileName;
                            });
                          }
                        } catch (e) {
                          logError('Image upload failed: $e');
                          if (!mounted) return;
                          Fluttertoast.showToast(msg: 'Failed to upload image');
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[100],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding:
                            EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                      ),
                      child: Text(
                        'Update',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.green),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

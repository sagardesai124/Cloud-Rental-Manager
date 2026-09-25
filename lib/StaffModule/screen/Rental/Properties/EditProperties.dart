import 'package:three_zero_two_property/services/app_log.dart';
import 'dart:convert';
import 'dart:io';

import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:email_validator/email_validator.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:keyboard_actions/keyboard_actions.dart';
import 'package:keyboard_actions/keyboard_actions_item.dart';
import 'package:provider/provider.dart';
import 'package:rflutter_alert/rflutter_alert.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:three_zero_two_property/StaffModule/repository/Staffmember.dart';
import 'package:three_zero_two_property/StaffModule/screen/Rental/Properties/Edit_Rentalowners.dart';
import 'package:three_zero_two_property/StaffModule/screen/Rental/Properties/add_rentalowners.dart';
import 'package:three_zero_two_property/model/staffmember.dart';
import 'package:three_zero_two_property/provider/dateProvider.dart';

import 'package:three_zero_two_property/repository/rental_properties.dart';

import '../../../../Model/propertytype.dart';
import '../../../../constant/constant.dart';
import '../../../../model/add_property.dart' hide InsuredValue;
import '../../../../model/properties.dart';
import '../../../../model/rental_properties.dart';
import '../../../../provider/add_property.dart';
import '../../../repository/Property_type.dart';
import '../../../repository/properties.dart';
import '../../../repository/properties_summery.dart';
import '../../../widgets/drawer_tiles.dart';
import '../../../../widgets/rental_widget.dart';
import 'package:http/http.dart' as http;
import 'package:three_zero_two_property/services/api_helpers.dart';
import 'package:three_zero_two_property/widgets/amenities_picker.dart';
import '../../../../model/unitsummery_propeties.dart';
import '../../../widgets/custom_drawer.dart';
import '../../../widgets/appbar.dart';

class Edit_properties extends StatefulWidget {
  propertytype? property;
  Staffmembers? staff;
  Rentals properties;
  RentalRequest? propties;
  final String rentalId;

  Edit_properties({
    super.key,
    this.property,
    this.staff,
    required this.properties,
    required this.rentalId,
  });

  @override
  State<Edit_properties> createState() => _Edit_propertiesState();
}

class _Edit_propertiesState extends State<Edit_properties> {
  List<String> months = ['Residential', "Commercial"];
  List<Widget> fields = [];
  int? selectedIndex;
  List<ProcessorGroup> _processorGroups = [];

  final List<String> items = [
    'Residential',
    "Commercial",
  ];
  String? selectedStaff;

  bool isLoading = false;
  String? selectedValue;
  bool isChecked = false;
  bool isChecked2 = false;
  bool showproperty = false;
  String selectedMonth = 'Residential';

  TextEditingController city = TextEditingController();
  TextEditingController state = TextEditingController();
  TextEditingController country = TextEditingController();
  TextEditingController postalcode = TextEditingController();
  TextEditingController address = TextEditingController();
  TextEditingController subtype = TextEditingController();

  bool addresserror = false;
  bool cityerror = false;
  bool stateerror = false;
  bool countryerror = false;
  bool postalcodeerror = false;
  bool subtypeerror = false;
  bool propertyTypeError = false;

  String addressmessage = "";
  String citymessage = "";
  String statemessage = "";
  String countrymessage = "";
  String postalcodemessage = "";
  String subtypemessage = "";
  String propertyTypeErrorMessage = "";
  //add rental owner

  TextEditingController firstname = TextEditingController();

  TextEditingController comname = TextEditingController();
  TextEditingController primaryemail = TextEditingController();
  TextEditingController alternativeemail = TextEditingController();
  TextEditingController phonenum = TextEditingController();
  TextEditingController homenum = TextEditingController();
  TextEditingController businessnum = TextEditingController();
  TextEditingController street2 = TextEditingController();
  TextEditingController city2 = TextEditingController();
  TextEditingController state2 = TextEditingController();
  TextEditingController county2 = TextEditingController();
  TextEditingController code2 = TextEditingController();
  TextEditingController proid = TextEditingController();

  bool firstnameerror = false;

  bool comnameerror = false;
  bool primaryemailerror = false;
  bool alternativeerror = false;
  bool phonenumerror = false;
  bool homenumerror = false;
  bool businessnumerror = false;
  bool street2error = false;
  bool city2error = false;
  bool state2error = false;
  bool county2error = false;
  bool code2error = false;
  bool proiderror = false;

  String firstnamemessage = "";

  String comnamemessage = "";
  String primaryemailmessage = "";
  String alternativemessage = "";
  String phonenummessage = "";
  String homenummessage = "";
  String businessnummessage = "";
  String street2message = "";
  String city2message = "";
  String state2message = "";
  String county2message = "";
  String code2message = "";
  String proidmessage = "";

  // Insured Value Information
  TextEditingController datePlacedInService = TextEditingController();
  List<HistoricalInsuredValue> historicalInsuredValues = [];
  bool datePlacedInServiceError = false;
  String datePlacedInServiceMessage = "";

  TextEditingController searchController = TextEditingController();

  late Future<List<Staffmembers>> futureStaffMembers;
  String? selectedStaffmember;
  bool showError = false;
  Future<List<propertytype>>? futureProperties;
  String? selectedProperty;
  Future<List<RentalOwners>>? futureRentalOwner;

  Map<String, List<propertytype>> groupPropertiesByType(
      List<propertytype> properties) {
    Map<String, List<propertytype>> groupedProperties = {};
    for (var property in properties) {
      if (!groupedProperties.containsKey(property.propertyType)) {
        groupedProperties[property.propertyType!] = [];
      }
      groupedProperties[property.propertyType!]!.add(property);
    }

    // Sort the values (property lists) for each property type and subtype
    groupedProperties.forEach((key, value) {
      value.sort((a, b) => (a.propertysubType ?? '')
          .toLowerCase()
          .compareTo((b.propertysubType ?? '').toLowerCase()));
    });

    // Sort property types alphabetically (A-Z)
    var sortedKeys = groupedProperties.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    Map<String, List<propertytype>> sortedGroupedProperties = {};
    for (var key in sortedKeys) {
      sortedGroupedProperties[key] = groupedProperties[key]!;
    }

    return sortedGroupedProperties;
  }

  List<Owner> owners = [];
  List<Owner> filteredOwners = [];
  List<bool> selected = [];

  Future<void> fetchOwners() async {
    setState(() {
      isLoading = true;
    });
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString("adminId");
    String? token = prefs.getString('token');
    String? staffid = prefs.getString("staff_id");
    final response = await http
        .get(Uri.parse('${Api_url}/api/rentals/rental-owners/$id'), headers: {
      "id": "CRM $staffid",
      "authorization": "CRM $token",
    });

    if (response.statusCode == 200) {
      List<dynamic> data = json.decode(response.body);
      owners = data.map((item) => Owner.fromJson(item)).toList();
      filteredOwners = List.from(owners);
      selected = List<bool>.filled(owners.length, false);
    } else {
      // Handle error
    }
    setState(() {
      isLoading = false;
    });
  }

  void filterOwners(String query) {
    setState(() {
      filteredOwners = owners.where((owner) {
        final fullName = '${owner.rentalOwnername} '.toLowerCase();
        return fullName.contains(query.toLowerCase());
      }).toList();
    });
  }

  String? initialAddress;
  String? initialCity;
  String? initialState;
  String? initialCountry;
  String? initialPostalCode;
  // Snapshot of the loaded service date, so supplying a missing one counts
  // as a change and is not swallowed by the "No changes detected" guard.
  String? initialPlacedInService;
  String? initialFirstName;
  String? initialCompanyName;
  String? initialPrimaryEmail;
  String? initialAlternativeEmail;
  String? initialPhoneNumber;
  String? initialHomeNumber;
  String? initialBuisinessNumber;
  String? initialRentalOwnerId;
  String? initialrentalOwnercity;
  String? initialrentalOwnerstate;
  String? initialrentalOwnerAddress;
  String? initialrentalOwnerpostalCode;
  String? initialrentalOwnercountry;
  String? initialselectedpropertytype;
  String? initialselectedselectedStaff;

  @override
  void initState() {
    super.initState();
    filteredOwners = owners;
    selected = List<bool>.generate(owners.length, (index) => false);
    // searchController.addListener(() { });
    // futureMember = StaffMemberRepository().fetchStaffmembers();
    futureProperties = PropertyTypeRepository().fetchPropertyTypes();
    futureStaffMembers = StaffMemberRepository().fetchStaffmembers();
    propertyGroups = [];
    // Add property group based on selected subproperty type
    addPropertyGroup();
    fetchOwners();
    Ownersdetails = RentalOwner(
        rentalOwnerId: widget.properties.rentalOwnerId,
        rentalOwnerName: widget.properties.rentalOwnerData?.rentalOwnerName,
        rentalOwnerPhoneNumber:
            widget.properties.rentalOwnerData?.rentalOwnerPhoneNumber,
        rentalOwnerHomeNumber:
            widget.properties.rentalOwnerData?.rentalOwnerHomeNumber,
        rentalOwnerBusinessNumber:
            widget.properties.rentalOwnerData?.rentalOwnerBuisinessNumber,
        rentalOwnerAlternateEmail:
            widget.properties.rentalOwnerData?.rentalOwnerAlternativeEmail,
        rentalOwnerPrimaryEmail:
            widget.properties.rentalOwnerData?.rentalOwnerPrimaryEmail,
        rentalOwnerCompanyName:
            widget.properties.rentalOwnerData?.rentalOwnerCompanyName,
        city: widget.properties.rentalOwnerData?.city,
        state: widget.properties.rentalOwnerData?.state,
        streetAddress: widget.properties.rentalOwnerData?.Address,
        postalCode: widget.properties.rentalOwnerData?.postalCode,
        country: widget.properties.rentalOwnerData?.country,
        processorList:
            widget.properties.rentalOwnerData?.processorList?.map((item) {
          return ProcessorList.fromJson(item as Map<String, dynamic>);
        }).toList());
    processor_id = widget.properties.processor_id;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider =
          Provider.of<OwnerDetailsProvider>(context, listen: false);
      if (Ownersdetails != null) {
        provider.setOwnerDetails(Ownersdetails!);
      }
    });
    isEditable = false;
    // Show insured values from list immediately so they appear before fetch completes
    if (widget.properties.insuredValues != null &&
        widget.properties.insuredValues!.isNotEmpty) {
      for (var iv in widget.properties.insuredValues!) {
        historicalInsuredValues.add(HistoricalInsuredValue(
          year: iv.year,
          yearController: TextEditingController(text: iv.year ?? ''),
          valueController: TextEditingController(
            text: iv.insuredValue != null
                ? NumberFormat('#,##0').format(iv.insuredValue!)
                : '',
          ),
        ));
      }
    }
    fetchDetails1(widget.rentalId).then((_) {
      // Load unit data after property details are set
      fetchunits1();
    });
  }

  List<unit_properties> data = [];
  // True only once fetchunits1 has rebuilt every unit's full field list.
  // Until then the unit fields are partial or empty, and saving would blank
  // or drop units, so Update waits for it (web waits for the load too).
  bool _unitsLoaded = false;
  // Unit slots whose card was removed with its delete icon. Removing drops only
  // the card; the slot's fields stay in place, so the save skips a removed
  // never-saved unit instead of creating it.
  final Set<int> _removedUnitSlots = <int>{};

  // A unit added with Add Another Unit that has not been removed again.
  bool _isLiveNewUnit(int i) =>
      i >= data.length && !_removedUnitSlots.contains(i);

  // The first unit missing a field web requires, as a toast message, or null
  // when every unit is complete. As web's unit schemas: SQFT on every unit, the
  // unit name on multi-unit properties, and the full residential set on a newly
  // added residential unit. Saved units are held only to SQFT and the unit
  // name, so a property saved before the newer fields existed stays editable.
  String? _missingUnitFields() {
    final bool residential =
        getActualPropertyType(selectedpropertytype) == 'Residential';
    int number = 0;
    for (int i = 0; i < propertyGroupControllers.length; i++) {
      if (_removedUnitSlots.contains(i)) continue;
      number++;
      final List<TextEditingController> c = propertyGroupControllers[i];
      final List<String> missing = <String>[];
      if (selectedIsMultiUnit) {
        if (_at(c, 0).isEmpty) missing.add(residential ? 'Unit' : 'Unit Number');
        if (_at(c, 2).isEmpty) missing.add('SQFT');
        if (residential && i >= data.length) {
          if (_at(c, 4).isEmpty) missing.add('Bed');
          if (_at(c, 5).isEmpty) missing.add('Rent Price');
          if (_at(c, 3).isEmpty) missing.add('Baths');
          if (_at(c, 6).isEmpty) missing.add('Half Baths');
          if (_at(c, 7).isEmpty) missing.add('Availability Date');
        }
      } else if (_at(c, 0).isEmpty) {
        missing.add('SQFT');
      }
      if (missing.isNotEmpty) {
        return 'Please enter ${missing.join(', ')} for Unit $number.';
      }
    }
    return null;
  }

  /// Photos to save for unit [i]. This form shows one photo per unit, but a
  /// unit can hold up to 10 (added on web). Send every stored photo back
  /// exactly as stored, and only change the first one when the user replaced
  /// or removed it here, so a save on mobile never drops photos 2-10.
  List<String> _unitImagesForSave(int i) {
    final List<String> stored = i < data.length
        ? List<String>.from(data[i].rentalImages ?? const <String>[])
        : <String>[];
    final String? shown =
        i < propertyGroupImagenames.length ? propertyGroupImagenames[i] : null;
    final bool hasShown = shown != null && shown.isNotEmpty;
    if (stored.isEmpty) return hasShown ? <String>[shown] : <String>[];
    // First photo removed here: keep the rest.
    if (!hasShown) return stored.sublist(1);
    String name(String s) => s.split('/').last;
    // Untouched: the form only prefixed the stored name for display.
    if (name(shown) == name(stored.first)) return stored;
    // First photo replaced here: keep the rest after it.
    return <String>[shown, ...stored.sublist(1)];
  }
  final Properies_summery_Repo unit1Repository = Properies_summery_Repo();
  Future<void> fetchunits1() async {
    try {
      final fetchedunit1 =
          await unit1Repository.fetchunit(widget.properties.rentalId ?? "");

      setState(() {
        data = fetchedunit1;
        isLoading = false;

        // Clear existing property groups
        propertyGroups.clear();
        propertyGroupControllers.clear();
        propertyGroupImages.clear();
        propertyGroupImagenames.clear();
        for (final notifier in propertyGroupAmenities) {
          notifier.dispose();
        }
        propertyGroupAmenities.clear();
        originalValues.clear();


        // Create property groups for each unit
        for (var unit in data) {
          // Created before the fields so the pre-built Unit Amenities field can
          // bind to it; added to propertyGroupAmenities next to the image entry.
          final unitAmenities = ValueNotifier<List<String>>(
              List<String>.from(unit.amenities ?? const <String>[]));

          List<TextEditingController> controllers = [];
          List<Widget> fields = [];

          if (selectedpropertytypedata?.propertyType == 'Commercial') {
            if (selectedpropertytypedata?.isMultiunit == true) {
              // Commercial multi-unit
              controllers = [
                TextEditingController(text: unit.rentalunit ?? ''),
                TextEditingController(text: unit.rentalunitadress ?? ''),
                TextEditingController(text: unit.rentalsqft ?? ''),
                // Appended, never inserted: existing indices 0-2 must not move.
                TextEditingController(text: unit.description ?? ''),
              ];
              fields = [
                customTextField('Unit Number', controllers[0],
                    placeholder: 'Enter unit number'),
                customTextField('Unit Address', controllers[1],
                    placeholder: 'Enter unit address'),
                customTextField('SQFT', controllers[2],
                    placeholder: 'Enter Sqft'),
                customOptionalField(
                    'Unit Description', controllers[3],
                    maxLines: 3,
                    placeholder: _pfUnitDescHint,
                    helperText: _pfUnitDescHelp),
                photo(propertyGroups.length),
              ];
            } else {
              // Commercial single unit

              // For Commercial single unit, if sqft is empty but unit has a value, use that
              String sqftValue = unit.rentalsqft?.isNotEmpty == true
                  ? unit.rentalsqft!
                  : unit.rentalunit ?? '';


              controllers = [
                TextEditingController(
                    text: sqftValue), // sqft in first position
                // Unit Description takes the unused slot 1 so it sits at the
                // same index as a Commercial unit built by addPropertyGroup().
                TextEditingController(text: unit.description ?? ''),
                TextEditingController(), // dummy controller for consistency
              ];

              for (int j = 0; j < controllers.length; j++) {
              }

              fields = [
                customTextField('SQFT', controllers[0],
                    placeholder: 'Enter Sqft'),
                customOptionalField(
                    'Unit Description', controllers[1],
                    maxLines: 3,
                    placeholder: _pfUnitDescHint,
                    helperText: _pfUnitDescHelp),
                photo(propertyGroups.length),
              ];
            }
          } else {
            // Residential properties
            if (selectedpropertytypedata?.isMultiunit == true) {
              // Use original values directly for display
              controllers = [
                TextEditingController(text: unit.rentalunit ?? ''),
                TextEditingController(text: unit.rentalunitadress ?? ''),
                TextEditingController(text: unit.rentalsqft ?? ''),
                TextEditingController(text: unit.rentalbath ?? ''),
                TextEditingController(text: unit.rentalbed ?? ''),
                // Appended, never inserted: existing indices 0-4 must not move.
                TextEditingController(text: unit.rentalUnitPrice ?? ''),
                TextEditingController(text: unit.halfBaths ?? ''),
                TextEditingController(
                    text: _displayDate(unit.availabilityDate)),
                TextEditingController(text: unit.parkingType ?? ''),
                TextEditingController(
                    text: (unit.leaseTerm ?? '').isEmpty
                        ? 'ContactForDetails'
                        : unit.leaseTerm!),
                TextEditingController(text: unit.securityDeposit ?? ''),
                TextEditingController(
                    text: (unit.securityDepositType ?? '').isEmpty
                        ? 'flatFee'
                        : unit.securityDepositType!),
                TextEditingController(text: unit.securityDepositMax ?? ''),
                TextEditingController(
                    text: (unit.securityDepositRefundable ?? '').isEmpty
                        ? 'refundable'
                        : unit.securityDepositRefundable!),
                TextEditingController(text: unit.petPolicy ?? ''),
                TextEditingController(
                    text: (unit.isFurnished ?? false).toString()),
                TextEditingController(
                    text: (unit.smokingAllowed ?? false).toString()),
                TextEditingController(text: unit.description ?? ''),
              ];
              // Store original values for API
              originalValues.add({
                'bath': unit.rentalbath ?? '',
                'bed': unit.rentalbed ?? '',
              });
              fields = [
                customTextField('Unit', controllers[0],
                    placeholder: 'Enter unit'),
                customTextField('Unit Address', controllers[1],
                    placeholder: 'Enter unit address'),
                _pfTwoCol(
                  customTextField('SQFT', controllers[2],
                      placeholder: 'Enter Sqft'),
                  customTextField('Rent Price (\$)', controllers[5],
                      money: true, placeholder: 'Enter rent price'),
                ),
                _pfTwoCol(
                  customDropdownField('Bed', roomsArray, controllers[4],
                      placeholder: 'Select'),
                  customDropdownField('Baths', bathArray, controllers[3],
                      placeholder: 'Select'),
                ),
                _pfTwoCol(
                  customDropdownField(
                      'Half Baths', halfBathArray, controllers[6],
                      placeholder: 'Select'),
                  customValueDropdown(
                      'Parking Type', parkingTypeOptions, controllers[8]),
                ),
                customUnitDateField('Availability Date', controllers[7]),
                customValueDropdown(
                    'Lease Term', leaseTermOptions, controllers[9],
                    showRequired: true),
                _pfTwoCol(
                  customOptionalField(
                      'Security Deposit (\$)', controllers[10],
                      money: true, placeholder: '0'),
                  customValueDropdown(
                      'Deposit Type', depositTypeOptions, controllers[11]),
                ),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: controllers[11],
                  builder: (_, v, __) => v.text == 'range'
                      ? customOptionalField(
                          'Deposit Max (\$)', controllers[12], money: true)
                      : const SizedBox.shrink(),
                ),
                customValueDropdown('Deposit Refundable?',
                    depositRefundableOptions, controllers[13]),
                customOptionalField('Pet Policy', controllers[14],
                    maxLines: 3, placeholder: _pfPetHint),
                ValueListenableBuilder<List<String>>(
                  valueListenable: unitAmenities,
                  builder: (_, value, __) => AmenitiesField(
                      label: 'Unit Amenities',
                      value: value,
                      isStaff: true,
                      onChanged: (v) => unitAmenities.value = v),
                ),
                const SizedBox(height: 16),
                _pfTileRow(
                  customCheckboxField('Furnished', controllers[15]),
                  customCheckboxField(
                      'Smoking Allowed', controllers[16]),
                ),
                customOptionalField(
                    'Unit Description', controllers[17],
                    maxLines: 3,
                    placeholder: _pfUnitDescHint,
                    helperText: _pfUnitDescHelp),
                photo(propertyGroups.length),
              ];
            } else {
              // Extract correct values from potentially corrupted data
              Map<String, String> correctValues = extractCorrectValues(unit);


              controllers = [
                TextEditingController(text: correctValues['sqft'] ?? ''),
                TextEditingController(text: correctValues['bath'] ?? ''),
                TextEditingController(text: correctValues['bed'] ?? ''),
                // Appended, never inserted: existing indices 0-2 must not move.
                TextEditingController(text: unit.rentalUnitPrice ?? ''),
                TextEditingController(text: unit.halfBaths ?? ''),
                TextEditingController(
                    text: _displayDate(unit.availabilityDate)),
                TextEditingController(text: unit.parkingType ?? ''),
                TextEditingController(
                    text: (unit.leaseTerm ?? '').isEmpty
                        ? 'ContactForDetails'
                        : unit.leaseTerm!),
                TextEditingController(text: unit.securityDeposit ?? ''),
                TextEditingController(
                    text: (unit.securityDepositType ?? '').isEmpty
                        ? 'flatFee'
                        : unit.securityDepositType!),
                TextEditingController(text: unit.securityDepositMax ?? ''),
                TextEditingController(
                    text: (unit.securityDepositRefundable ?? '').isEmpty
                        ? 'refundable'
                        : unit.securityDepositRefundable!),
                TextEditingController(text: unit.petPolicy ?? ''),
                TextEditingController(
                    text: (unit.isFurnished ?? false).toString()),
                TextEditingController(
                    text: (unit.smokingAllowed ?? false).toString()),
                TextEditingController(text: unit.description ?? ''),
              ];
              // Store original values for API
              originalValues.add({
                'bath': correctValues['bath'] ?? '',
                'bed': correctValues['bed'] ?? '',
              });
              fields = [
                _pfTwoCol(
                  customTextField('SQFT', controllers[0],
                      placeholder: 'Enter Sqft'),
                  customTextField('Rent Price (\$)', controllers[3],
                      money: true, placeholder: 'Enter rent price'),
                ),
                _pfTwoCol(
                  customDropdownField('Bed', roomsArray, controllers[2],
                      placeholder: 'Select'),
                  customDropdownField('Baths', bathArray, controllers[1],
                      placeholder: 'Select'),
                ),
                _pfTwoCol(
                  customDropdownField(
                      'Half Baths', halfBathArray, controllers[4],
                      placeholder: 'Select'),
                  customValueDropdown(
                      'Parking Type', parkingTypeOptions, controllers[6]),
                ),
                customUnitDateField('Availability Date', controllers[5]),
                customValueDropdown(
                    'Lease Term', leaseTermOptions, controllers[7],
                    showRequired: true),
                _pfTwoCol(
                  customOptionalField(
                      'Security Deposit (\$)', controllers[8],
                      money: true, placeholder: '0'),
                  customValueDropdown(
                      'Deposit Type', depositTypeOptions, controllers[9]),
                ),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: controllers[9],
                  builder: (_, v, __) => v.text == 'range'
                      ? customOptionalField(
                          'Deposit Max (\$)', controllers[10], money: true)
                      : const SizedBox.shrink(),
                ),
                customValueDropdown('Deposit Refundable?',
                    depositRefundableOptions, controllers[11]),
                customOptionalField('Pet Policy', controllers[12],
                    maxLines: 3, placeholder: _pfPetHint),
                ValueListenableBuilder<List<String>>(
                  valueListenable: unitAmenities,
                  builder: (_, value, __) => AmenitiesField(
                      label: 'Unit Amenities',
                      value: value,
                      isStaff: true,
                      onChanged: (v) => unitAmenities.value = v),
                ),
                const SizedBox(height: 16),
                _pfTileRow(
                  customCheckboxField('Furnished', controllers[13]),
                  customCheckboxField(
                      'Smoking Allowed', controllers[14]),
                ),
                customOptionalField(
                    'Unit Description', controllers[15],
                    maxLines: 3,
                    placeholder: _pfUnitDescHint,
                    helperText: _pfUnitDescHelp),
                photo(propertyGroups.length),
              ];
            }
          }

          for (int i = 0; i < controllers.length; i++) {
          }

          propertyGroups.add(fields);
          propertyGroupControllers.add(controllers);

          // Handle images - construct full URL for display
          if (unit.rentalImages != null && unit.rentalImages!.isNotEmpty) {
            String imageFilename = unit.rentalImages![0];

            // Check if it's already a full URL
            if (imageFilename.startsWith('http')) {
              propertyGroupImagenames.add(imageFilename);
            } else {
              // Construct full URL using the image_url constant
              String fullUrl = '$image_url$imageFilename';
              propertyGroupImagenames.add(fullUrl);
            }
            propertyGroupImages.add(null);
          } else {
            propertyGroupImagenames.add(null);
            propertyGroupImages.add(null);
          }
          propertyGroupAmenities.add(unitAmenities);
        }

        // Multi-unit means the property TYPE is multi-unit — the same flag the unit
        // fields were laid out from — not "has more than one unit". A multi-unit
        // building with a single unit used to read as single-unit here, so the
        // change check and save read its fields by the wrong positions.
        selectedIsMultiUnit = selectedpropertytypedata?.isMultiunit == true;
        _removedUnitSlots.clear();
        _unitsLoaded = true;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      logError('Failed to load units: $e');
    }
  }

  Future<void> fetchDetails1(String rentalId) async {
    final dateProvider =
                  Provider.of<DateProvider>(context, listen: false);
    try {
      Rentals fetchedDetails =
          await Properies_summery_Repo().fetchrentalDetails(rentalId);

      await Future.delayed(const Duration(seconds: 1));
      setState(() {
        originalValues.clear();
        // print(fetchedDetails.rentalAddress);
        // selectedpropertytype = fetchedDetails.propertyTypeData?.propertyType;
        selectedpropertytypedata = propertytype(
            propertyType: fetchedDetails.propertyTypeData?.propertyType ?? "",
            propertysubType:
                fetchedDetails.propertyTypeData?.propertySubType ?? "",
            isMultiunit: fetchedDetails.propertyTypeData?.isMultiunit ?? false,
            propertyId: fetchedDetails.propertyTypeData?.propertyId ?? "");
        selectedpropertytype = fetchedDetails.propertyTypeData?.propertyType;
        selectedProperty = fetchedDetails.propertyTypeData?.propertySubType;
        address.text = fetchedDetails.rentalAddress!;
        city.text = fetchedDetails.rentalCity!;
        state.text = fetchedDetails.rentalState!;
        postalcode.text = fetchedDetails.rentalPostcode!;
        datePlacedInService.text = dateProvider.formatCurrentDate(fetchedDetails.placedInService!);
        // country.text = fetchedDetails.rentalCountry!;
        country.text = fetchedDetails.rentalCountry ?? 'N/A';
        selectedProperty = fetchedDetails.propertyTypeData!.propertySubType;
        Ownersdetails = RentalOwner(
            rentalOwnerId: fetchedDetails.rentalOwnerId,
            rentalOwnerPhoneNumber:
                fetchedDetails.rentalOwnerData?.rentalOwnerPhoneNumber,
            rentalOwnerName: fetchedDetails.rentalOwnerData?.rentalOwnerName,
            rentalOwnerHomeNumber:
                fetchedDetails.rentalOwnerData?.rentalOwnerHomeNumber,
            rentalOwnerBusinessNumber:
                fetchedDetails.rentalOwnerData?.rentalOwnerBuisinessNumber,
            rentalOwnerAlternateEmail:
                fetchedDetails.rentalOwnerData?.rentalOwnerAlternativeEmail,
            rentalOwnerPrimaryEmail:
                fetchedDetails.rentalOwnerData?.rentalOwnerPrimaryEmail,
            rentalOwnerCompanyName:
                fetchedDetails.rentalOwnerData?.rentalOwnerCompanyName,
            city: fetchedDetails.rentalOwnerData?.city,
            state: fetchedDetails.rentalOwnerData?.state,
            streetAddress: fetchedDetails.rentalOwnerData?.Address,
            postalCode: fetchedDetails.rentalOwnerData?.postalCode,
            country: fetchedDetails.rentalOwnerData?.country,
            processorList:
                fetchedDetails.rentalOwnerData?.processorList?.map((item) {
              return ProcessorList.fromJson(item as Map<String, dynamic>);
            }).toList());
        firstname.text = (fetchedDetails.rentalOwnerData?.rentalOwnerName ?? '');
        comname.text = (fetchedDetails.rentalOwnerData?.rentalOwnerCompanyName ?? '');
        primaryemail.text =
            (fetchedDetails.rentalOwnerData?.rentalOwnerPrimaryEmail ?? '');
        alternativeemail.text =
            (fetchedDetails.rentalOwnerData?.rentalOwnerAlternativeEmail ?? '');
        // print(alternativeemail);
        phonenum.text = (fetchedDetails.rentalOwnerData?.rentalOwnerPhoneNumber ?? '');
        // print(phonenum);
        homenum.text = (fetchedDetails.rentalOwnerData?.rentalOwnerHomeNumber ?? '');
        // print(homenum);
        businessnum.text =
            (fetchedDetails.rentalOwnerData?.rentalOwnerBuisinessNumber ?? '');
        // print(widget.properties.rentalOwnerData!.rentalOwnerBuisinessNumber);
        street2.text = (fetchedDetails.rentalOwnerData?.Address ?? '');
        city2.text = (fetchedDetails.rentalOwnerData?.city ?? '');
        state2.text = (fetchedDetails.rentalOwnerData?.state ?? '');
        county2.text = (fetchedDetails.rentalOwnerData?.country ?? '');
        code2.text = (fetchedDetails.rentalOwnerData?.postalCode ?? '');
        selectedStaff = (fetchedDetails.staffMemberId?.isEmpty ?? true)
            ? null
            : fetchedDetails.staffMemberId ?? null;
        // print(selectedStaffmember);
        Provider.of<OwnerDetailsProvider>(context, listen: false)
            .setOwnerDetails(Ownersdetails!);

        initialAddress = fetchedDetails.rentalAddress!;
        // initialPlacedInService is NOT captured here: the block further down
        // rewrites datePlacedInService.text, so a baseline taken now would hold
        // a different string than the field the user sees and every save would
        // read as changed. It is captured right after that block instead.
        // No trailing `!`: with no manager this was `null!`, which threw and
        // skipped every line below — the remaining change-check baselines and
        // the Historical Insured Values load — so an untouched form always
        // read as changed. The field is nullable; null means "no manager".
        initialselectedselectedStaff =
            (fetchedDetails.staffMemberId?.isEmpty ?? true)
                ? null
                : fetchedDetails.staffMemberId;
        initialCity = fetchedDetails.rentalCity!;
        initialState = fetchedDetails.rentalState!;
        initialPostalCode = fetchedDetails.rentalPostcode!;
        initialCountry = fetchedDetails.rentalCountry ?? 'N/A';
        initialFirstName = (fetchedDetails.rentalOwnerData?.rentalOwnerName ?? '');
        initialCompanyName =
            (fetchedDetails.rentalOwnerData?.rentalOwnerCompanyName ?? '');
        initialPrimaryEmail =
            (fetchedDetails.rentalOwnerData?.rentalOwnerPrimaryEmail ?? '');
        initialAlternativeEmail =
            (fetchedDetails.rentalOwnerData?.rentalOwnerAlternativeEmail ?? '');
        initialHomeNumber =
            (fetchedDetails.rentalOwnerData?.rentalOwnerHomeNumber ?? '');
        initialBuisinessNumber =
            (fetchedDetails.rentalOwnerData?.rentalOwnerBuisinessNumber ?? '');
        initialrentalOwnerAddress = (fetchedDetails.rentalOwnerData?.Address ?? '');
        initialrentalOwnercity = (fetchedDetails.rentalOwnerData?.city ?? '');
        initialrentalOwnerstate = (fetchedDetails.rentalOwnerData?.state ?? '');
        initialrentalOwnercountry = (fetchedDetails.rentalOwnerData?.country ?? '');
        initialrentalOwnerpostalCode =
            (fetchedDetails.rentalOwnerData?.postalCode ?? '');
        initialPhoneNumber =
            (fetchedDetails.rentalOwnerData?.rentalOwnerPhoneNumber ?? '');
        propertyAmenities.value = List<String>.from(
            fetchedDetails.propertyAmenities ?? const <String>[]);
        initialPropertyAmenities = List<String>.from(propertyAmenities.value);
        _zillowAdvertise = fetchedDetails.zillowAdvertise == true;

        // Load placed_in_service date
        try {
          final placedInServiceValue =
              (fetchedDetails as dynamic).placedInService;
          if (placedInServiceValue != null &&
              placedInServiceValue.toString().isNotEmpty) {
            try {
              // Format through DateProvider, the same way every other date on
              // this form does, instead of a hardcoded MM/dd/yyyy. The hardcode
              // ignored the account's configured date format and disagreed with
              // the unit dates shown a few fields below.
              datePlacedInService.text = dateProvider
                  .formatCurrentDate(placedInServiceValue.toString());
            } catch (e) {
              logError('Error loading placed_in_service date: $e');
            }
          }
        } catch (e) {
          logError('Error accessing placedInService: $e');
        }

        // Capture the change-check baseline only now, once the field holds the
        // value the user will actually see.
        initialPlacedInService = datePlacedInService.text;

        // Load insured values from fetch response, or fallback to initial properties
        final insuredValuesToLoad = fetchedDetails.insuredValues != null &&
                fetchedDetails.insuredValues!.isNotEmpty
            ? fetchedDetails.insuredValues!
            : (widget.properties.insuredValues != null &&
                    widget.properties.insuredValues!.isNotEmpty
                ? widget.properties.insuredValues!
                : null);
        if (insuredValuesToLoad != null) {
          historicalInsuredValues.clear();
          for (var insuredValue in insuredValuesToLoad) {
            historicalInsuredValues.add(HistoricalInsuredValue(
              year: insuredValue.year,
              yearController:
                  TextEditingController(text: insuredValue.year ?? ''),
              valueController: TextEditingController(
                text: insuredValue.insuredValue != null
                    ? NumberFormat('#,##0').format(insuredValue.insuredValue!)
                    : '',
              ),
            ));
          }
        }

        // _selectedProperty = fetchedDetails.rentalId; // Uncomment and update based on your use case
      });
    } catch (e) {
      // print('Failed to fetch property details: $e');
    }
  }

  @override
  void dispose() {
    searchController.dispose();
    datePlacedInService.dispose();
    for (var item in historicalInsuredValues) {
      item.yearController.dispose();
      item.valueController.dispose();
    }
    for (final notifier in propertyGroupAmenities) {
      notifier.dispose();
    }
    propertyAmenities.dispose();
    super.dispose();
  }

  void addHistoricalInsuredValue() {
    setState(() {
      historicalInsuredValues.add(HistoricalInsuredValue(
        yearController: TextEditingController(),
        valueController: TextEditingController(),
      ));
    });
  }

  void removeHistoricalInsuredValue(int index) {
    setState(() {
      historicalInsuredValues[index].yearController.dispose();
      historicalInsuredValues[index].valueController.dispose();
      historicalInsuredValues.removeAt(index);
    });
  }

  Future<void> _selectDatePlacedInService() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
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
    );
    if (picked != null) {
      setState(() {
        final dateProvider = Provider.of<DateProvider>(context, listen: false);
        String apiFormatDate = DateFormat('yyyy-MM-dd').format(picked);
        datePlacedInService.text =
            dateProvider.formatCurrentDate(apiFormatDate);
        datePlacedInServiceError = false;
      });
    }
  }

  List<String> _generateYearList() {
    int currentYear = DateTime.now().year;
    List<String> years = [];
    for (int i = currentYear; i >= 1900; i--) {
      years.add(i.toString());
    }
    return years;
  }

  Owner? selectedOwner;
  Owner? rentalOwnerId;
  Owner? getSelectedOwner() {
    for (int i = 0; i < selected.length; i++) {
      if (selected[i]) {
        return filteredOwners[i];
      }
    }
    return null;
  }

  void onAddButtonTapped() {
    for (int i = 0; i < selected.length; i++) {
      if (selected[i]) {
        setState(() {
          selectedOwner = filteredOwners[i];
        });
        return;
      }
    }
    // Show a message to select an owner
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Please select an owner.'),
    ));
  }

  List<List<TextEditingController>> propertyGroupControllers = [];
  // Track original values for API (separate from display values)
  List<Map<String, String>> originalValues = [];

  bool iserror = false;
  bool iserror2 = false;
  GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  TextEditingController name = TextEditingController();
  TextEditingController designation = TextEditingController();
  TextEditingController phonenumber = TextEditingController();
  TextEditingController email = TextEditingController();
  TextEditingController password = TextEditingController();
  bool nameerror = false;
  bool designationerror = false;
  bool phonenumbererror = false;
  bool emailerror = false;
  bool passworderror = false;
  propertytype? selectedpropertytypedata = propertytype();
  propertytype? id = propertytype();
  String? sid = "";
  String? showdata;

//  propertytype? selectedpropertytype = propertytype();
  String? selectedpropertytype;
  //propertytype? selectedIsMultiUnit;
  bool selectedIsMultiUnit = false;
  String namemessage = "";
  String designationmessage = "";
  String phonenumbermessage = "";
  String emailmessage = "";
  String passwordmessage = "";

  bool loading = false;
  List<Widget> units = [];

  void removePropertyGroup(int index) {
    setState(() {
      // Cards and unit slots share one order and cards are only ever removed,
      // so the index-th card belongs to the index-th slot not yet removed.
      int seen = -1;
      for (int slot = 0; slot < propertyGroupControllers.length; slot++) {
        if (_removedUnitSlots.contains(slot)) continue;
        if (++seen == index) {
          _removedUnitSlots.add(slot);
          break;
        }
      }
      propertyGroups.removeAt(index);
    });
  }

  Future<void> getImage(int index) async {
    final pickedFile =
        await ImagePicker().pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      try {
        String? filename = await uploadImage(File(pickedFile.path));
        setState(() {
          // Store the full URL for the uploaded image
          if (filename != null && filename.isNotEmpty) {
            propertyGroupImagenames[index] = '$image_url$filename';
          }
          // Store the local file for immediate display
          propertyGroupImages[index] = File(pickedFile.path);
        });
      } catch (e) {
        logError('Error uploading image: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload image: ${friendlyErrorMessage(e)}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<List<Widget>> propertyGroups = [];
  //  List<List<TextEditingController>> propertyGroupControllers = [];
  List<File?> propertyGroupImages = [];
  List<String?> propertyGroupImagenames = [];
  // Unit Amenities, one notifier per unit, index-aligned with
  // propertyGroupImagenames. Notifiers because each unit's widgets are
  // pre-built into propertyGroups, so a plain setState would not redraw them.
  List<ValueNotifier<List<String>>> propertyGroupAmenities = [];
  // Property Amenities (building/community level), Residential only.
  final ValueNotifier<List<String>> propertyAmenities =
      ValueNotifier(<String>[]);
  List<String> initialPropertyAmenities = [];
  // Web shows Property Amenities only inside its Zillow card, i.e. when the
  // property's "Advertise on Zillow" setting is on. Mobile has no Zillow
  // switch, so it just follows the saved setting (read-only).
  bool _zillowAdvertise = false;

  // Order-insensitive comparison key, so re-picking the same amenities in a
  // different order never reads as a change.
  String _amenitiesKey(List<String> l) =>
      (List<String>.from(l)..sort()).join('\u0001');
  File? _image;
  Future<String?> uploadImage(File imageFile) async {
    // API URL
    //   final String uploadUrl = 'http://192.168.1.17:4000/api/images/upload';
    final String uploadUrl = '${image_upload_url}/api/images/upload';

    var request = http.MultipartRequest('POST', Uri.parse(uploadUrl));
    if (imageFile != null) {
      request.files
          .add(await http.MultipartFile.fromPath('files', imageFile!.path));
    }
    // Create a multipart request
//    var request = http.MultipartRequest('POST', Uri.parse(uploadUrl));

    // Attach the file in the 'image' field
    // var multipartFile = await http.MultipartFile.fromPath(
    //   'files',
    //   imageFile.path,
    // //  contentType: MediaType('image', 'jpeg'), // Adjust based on your file type
    // );
    //
    // // Add the file to the request
    // request.files.add(multipartFile);

    // Send the request
    var response = await apiSend(request);
    // Parse the response
    var responseData = await http.Response.fromStream(response);
    var responseBody = json.decode(responseData.body);

    // Extract the filename from the response
    if (responseBody['status'] == 'ok') {
      List file = responseBody['files'];
      return file.first["filename"];
    } else {
      throw Exception('Failed to upload file: ${responseBody['message']}');
    }
  }

  Widget customTextField(String label, TextEditingController Controller,
      {bool money = false, String? placeholder, bool showRequired = true}) {
    return FormField<String>(
      validator: (value) {
        if (Controller.text.isEmpty) {
          return 'required';
        }
        return null;
      },
      builder: (FormFieldState<String> state) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _pfFieldLabel(label, required: showRequired),
              TextFormField(
                controller: Controller,
                // Rent/deposit are Numbers on the server; web strips everything but
                // digits and '.', so '1,850' or '$1850' must not be typeable.
                keyboardType: money
                    ? const TextInputType.numberWithOptions(decimal: true)
                    : null,
                inputFormatters: money
                    ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))]
                    : null,
                cursorColor: Colors.black,
                style: const TextStyle(fontSize: 14, color: navyClr),
                decoration: _pfInputDecoration(
                  hint: placeholder ?? label,
                  error: state.hasError,
                ),
                  // labelText: label,
                  // labelStyle: TextStyle(color: Colors.grey[700]),
              ),
            if (state.hasError)
              Padding(
                padding: const EdgeInsets.only(left: 5, top: 4),
                child: Text(
                  state.errorText!,
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 14,
                  ),
                ),
              ),
          ],
          ),
        );
      },
    );
  }

  // Exactly web's Half Baths options (Rentals.jsx: ["0","0.5",..,"4"]).
  static const List<String> halfBathArray = [
    "0",
    "0.5",
    "1",
    "1.5",
    "2",
    "2.5",
    "3",
    "3.5",
    "4",
  ];

  /// Stored availability_date (yyyy-MM-dd) -> the user's display format, so the
  /// field reads like every other date on the form. Falls back to the raw value
  /// rather than blanking the field if it cannot be parsed.
  String _displayDate(String? apiDate) {
    final raw = (apiDate ?? '').trim();
    if (raw.isEmpty) return '';
    try {
      final dateProvider = Provider.of<DateProvider>(context, listen: false);
      return dateProvider.formatCurrentDate(raw);
    } catch (_) {
      return raw;
    }
  }

  /// True when any unit field AFTER Bed differs from what was loaded.
  /// [base] is the index of Rent Price for this unit's layout (single 3,
  /// multi 5); everything after Bed sits in the same order in both layouts.
  /// Without this, editing only one of these reads as "no changes" and the
  /// save is skipped, silently throwing the edit away.
  bool _unitExtrasChanged(
      unit_properties oldUnit, List<TextEditingController> c, int base) {
    String at(int i) => i < c.length ? c[i].text.trim() : '';
    // Dropdowns are seeded with a default when the stored value is blank, so
    // compare against that same default or every save looks like a change.
    String def(String? v, String d) =>
        (v ?? '').trim().isEmpty ? d : v!.trim();
    return (oldUnit.rentalUnitPrice?.trim() ?? '') != at(base) ||
        (oldUnit.halfBaths?.trim() ?? '') != at(base + 1) ||
        (oldUnit.availabilityDate?.trim() ?? '') !=
            (_toApiDate(at(base + 2)) ?? '') ||
        (oldUnit.parkingType?.trim() ?? '') != at(base + 3) ||
        def(oldUnit.leaseTerm, 'ContactForDetails') != at(base + 4) ||
        (oldUnit.securityDeposit?.trim() ?? '') != at(base + 5) ||
        def(oldUnit.securityDepositType, 'flatFee') != at(base + 6) ||
        (oldUnit.securityDepositMax?.trim() ?? '') != at(base + 7) ||
        def(oldUnit.securityDepositRefundable, 'refundable') != at(base + 8) ||
        (oldUnit.petPolicy?.trim() ?? '') != at(base + 9) ||
        (oldUnit.isFurnished ?? false) != (at(base + 10) == 'true') ||
        (oldUnit.smokingAllowed ?? false) != (at(base + 11) == 'true') ||
        (oldUnit.description?.trim() ?? '') != at(base + 12);
  }

  /// Controller text by index, or '' when the list is shorter than
  /// expected. A stale unit fetch can leave a shorter list behind and
  /// indexing it directly would throw mid-save.
  String _at(List<TextEditingController> c, int i) =>
      i < c.length ? c[i].text.trim() : '';

  /// Displayed date -> yyyy-MM-dd for the payload. Same order-sensitive parse
  /// list the form already uses for placed_in_service; returns null when
  /// nothing parses so a blank field is omitted rather than sent as garbage.
  String? _toApiDate(String text) {
    if (text.trim().isEmpty) return null;
    for (final format in const [
      'yyyy-MM-dd',
      'yyyy-M-d',
      'yyyy-MMM-dd',
      'dd-MM-yyyy',
      'd-M-yyyy',
      'M/d/yyyy',
      'MM/dd/yyyy',
    ]) {
      try {
        return DateFormat('yyyy-MM-dd').format(DateFormat(format).parse(text));
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  /// Per-unit Availability Date picker. Read-only like Date Placed in Service.
  Widget customUnitDateField(String label, TextEditingController controller,
      {String? placeholder, bool showRequired = true}) {
    return FormField<String>(
      validator: (_) => controller.text.trim().isEmpty ? 'required' : null,
      builder: (FormFieldState<String> state) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _pfFieldLabel(label, required: showRequired),
              TextFormField(
                controller: controller,
                readOnly: true,
                cursorColor: Colors.black,
                onTap: () async {
                  final DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(DateTime.now().year + 10),
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
                  );
                  if (picked != null) {
                    final dateProvider =
                        Provider.of<DateProvider>(context, listen: false);
                    setState(() {
                      controller.text = dateProvider.formatCurrentDate(
                          DateFormat('yyyy-MM-dd').format(picked));
                    });
                    state.didChange(controller.text);
                  }
                },
                style: const TextStyle(fontSize: 14, color: navyClr),
                decoration: _pfInputDecoration(
                  hint: placeholder ?? label,
                  error: state.hasError,
                  suffixIcon: const Icon(Icons.calendar_today_outlined,
                      size: 18, color: navyClr),
                ),
              ),
            if (state.hasError)
              Padding(
                padding: const EdgeInsets.only(left: 5, top: 4),
                child: Text(
                  state.errorText!,
                  style: const TextStyle(color: Colors.red, fontSize: 14),
                ),
              ),
          ],
          ),
        );
      },
    );
  }

  // Web's exact option VALUES and labels (Rentals.jsx getOptionLabel blocks).
  // The value is what the server stores; the label is only what we display.
  static const Map<String, String> parkingTypeOptions = {
    '': 'Select type',
    'surfaceLot': 'Surface Lot',
    'garageLot': 'Garage Lot',
    'coveredLot': 'Covered Lot',
    'street': 'Street',
    'other': 'Other',
    'none': 'None',
  };
  static const Map<String, String> leaseTermOptions = {
    'ContactForDetails': 'Contact for Details',
    'Monthly': 'Monthly',
    'SixMonths': '6 Months',
    'OneYear': '1 Year',
  };
  static const Map<String, String> depositTypeOptions = {
    'flatFee': 'Flat Fee',
    'range': 'Range',
    'percentage': '% of Rent',
    'multiplier': 'Multiplier of Rent',
  };
  static const Map<String, String> depositRefundableOptions = {
    'refundable': 'Refundable',
    'nonRefundable': 'Non-Refundable',
    'partiallyRefundable': 'Partially Refundable',
  };

  /// Dropdown over a value->label map: the controller always holds the server
  /// VALUE while the user sees the label, so nothing has to be translated at
  /// save time. Optional, so unlike customDropdownField it does not validate.
  /// Checkbox backed by a TextEditingController holding 'true'/'false', so it
  /// slots into the same positional controller list as every other unit field.
  Widget customCheckboxField(String label, TextEditingController controller) {
    // Unit widgets are pre-built into a stored list, so setState never repaints
    // this box. Listen to the controller itself so the tick follows the value
    // and a second tap can untick it.
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, current, _) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: outlineClr),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: Checkbox(
              value: current.text == 'true',
              activeColor: navyClr,
              checkColor: Colors.white,
              side: const BorderSide(color: checkOffClr, width: 1.5),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6)),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
              onChanged: (checked) =>
                  controller.text = (checked ?? false).toString(),
            ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(label,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: navyClr)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget customValueDropdown(
    String hint,
    Map<String, String> options,
    TextEditingController controller, {
    bool showRequired = false,
  }) {
    final current = options.containsKey(controller.text) ? controller.text : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _pfFieldLabel(hint, required: showRequired),
          DropdownButtonFormField<String>(
        value: current,
        isExpanded: true,
        decoration: _pfInputDecoration(),
        icon: const Icon(Icons.keyboard_arrow_down, color: navyClr),
        hint: Text(hint,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, color: _pfHintClr)),
        items: options.entries
            .map((e) => DropdownMenuItem<String>(
                  value: e.key,
                  child: Text(e.value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14, color: navyClr)),
                ))
            .toList(),
        onChanged: (v) => setState(() => controller.text = v ?? ''),
          ),
        ],
      ),
    );
  }

  /// Free-text unit field that is optional (customTextField always requires).
  Widget customOptionalField(String label, TextEditingController controller,
      {int maxLines = 1,
      bool money = false,
      String? placeholder,
      String? helperText}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _pfFieldLabel(label),
          TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: money
            ? const TextInputType.numberWithOptions(decimal: true)
            : null,
        inputFormatters: money
            ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))]
            : null,
        cursorColor: Colors.black,
        style: const TextStyle(fontSize: 14, color: navyClr),
        decoration: _pfInputDecoration(hint: placeholder ?? label),
          ),
          if (helperText != null) ...[
            const SizedBox(height: 6),
            Text(helperText,
                style: const TextStyle(fontSize: 13, color: mutedClr)),
          ],
        ],
      ),
    );
  }

  Widget customDropdownField(
    String hint,
    List<String> items,
    TextEditingController controller, {
    String? placeholder,
    bool showRequired = true,
  }) {
    // Check if the current value exists in the items list
    String? currentValue = controller.text.isNotEmpty ? controller.text : null;
    bool valueExists = currentValue != null && items.contains(currentValue);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _pfFieldLabel(hint, required: showRequired),
          DropdownButtonFormField<String>(
        value: valueExists ? currentValue : null,
        isExpanded: true,
        decoration: _pfInputDecoration(),
        icon: const Icon(Icons.keyboard_arrow_down, color: navyClr),
        hint: Text(
            valueExists
                ? (placeholder ?? hint)
                : (currentValue ?? placeholder ?? hint),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, color: _pfHintClr)),
        items: items.map((String value) {
          return DropdownMenuItem<String>(
            value: value,
            child: Text(value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14, color: navyClr)),
          );
        }).toList(),
        onChanged: (String? newValue) {
          controller.text = newValue ?? '';
        },
        validator: (value) =>
            value == null || value.isEmpty ? 'Required' : null,
          ),
        ],
      ),
    );
  }

  static const List<String> roomsArray = [
    "1 Bed",
    "2 Bed",
    "3 Bed",
    "4 Bed",
    "5 Bed",
    "6 Bed",
    "7 Bed",
    "8 Bed",
    "9 Bed",
    "9+ Bed",
  ];

  static const List<String> bathArray = [
    "1 Bath",
    "1.5 Bath",
    "2 Bath",
    "2.5 Bath",
    "3 Bath",
    "3.5 Bath",
    "4 Bath",
    "4.5 Bath",
    "5 Bath",
    "5+ Bath",
  ];

  // Helper method to get actual property type
  String getActualPropertyType(String? propertyType) {
    if (propertyType == null) return '';
    if (propertyType == 'Single-Family') return 'Commercial';
    return propertyType;
  }

  // Helper method to find best matching dropdown option for display
  String findBestDropdownMatch(String? dbValue, List<String> options) {
    if (dbValue == null || dbValue.isEmpty) {
      return '';
    }

    // Check if the value exists in the dropdown options (exact match)
    if (options.contains(dbValue)) {
      return dbValue;
    }

    // Try to find an exact match (case insensitive)
    String searchValue = dbValue.toLowerCase();
    for (String option in options) {
      if (option.toLowerCase() == searchValue) {
        return option;
      }
    }

    // For numeric values like "2", "4", etc., return empty string to show as hint
    // This way the dropdown will show the original value as hint instead of converting it
    return '';
  }

  // Helper method to check if value exists in dropdown options
  bool isValueInDropdown(String? dbValue, List<String> options) {
    if (dbValue == null || dbValue.isEmpty) {
      return false;
    }

    // Check if the value exists in the dropdown options (exact match)
    if (options.contains(dbValue)) {
      return true;
    }

    // Try to find an exact match (case insensitive)
    String searchValue = dbValue.toLowerCase();
    for (String option in options) {
      if (option.toLowerCase() == searchValue) {
        return true;
      }
    }

    // Only return true if the value is already in dropdown format (contains "Bath" or "Bed")
    if (searchValue.contains('bath') || searchValue.contains('bed')) {
      return true;
    }

    // For numeric values like "2", "3", etc., return false to use text field
    return false;
  }

  // Helper method to safely set dropdown value - only set if it exists in options
  String safeDropdownValue(String? dbValue, List<String> options) {
    if (dbValue == null || dbValue.isEmpty) {
      return '';
    }

    // Check if the value exists in the dropdown options (exact match)
    if (options.contains(dbValue)) {
      return dbValue; // Use as is if it exists in dropdown
    }

    // Try to find an exact match (case insensitive)
    String searchValue = dbValue.toLowerCase();
    for (String option in options) {
      if (option.toLowerCase() == searchValue) {
        return option;
      }
    }

    // Only try to match if the value is already in dropdown format (contains "Bath" or "Bed")
    if (searchValue.contains('bath') || searchValue.contains('bed')) {
      for (String option in options) {
        if (option.toLowerCase().contains(searchValue)) {
          return option;
        }
      }
    }

    // If no match found, return empty string to avoid dropdown error
    return '';
  }

  // Helper method to extract correct values from corrupted data
  Map<String, String> extractCorrectValues(unit_properties unit) {
    Map<String, String> result = {
      'sqft': '',
      'bath': '',
      'bed': '',
    };

    // Try to find numeric sqft value
    if (unit.rentalsqft != null &&
        RegExp(r'^\d+$').hasMatch(unit.rentalsqft!)) {
      result['sqft'] = unit.rentalsqft!;
    } else if (unit.rentalunit != null &&
        RegExp(r'^\d+$').hasMatch(unit.rentalunit!)) {
      result['sqft'] = unit.rentalunit!;
    } else if (unit.rentalunitadress != null &&
        RegExp(r'^\d+$').hasMatch(unit.rentalunitadress!)) {
      result['sqft'] = unit.rentalunitadress!;
    }

    // Try to find bath value
    if (unit.rentalbath != null &&
        (unit.rentalbath ?? '').toLowerCase().contains('bath')) {
      result['bath'] = unit.rentalbath!;
    } else if (unit.rentalunit != null &&
        (unit.rentalunit ?? '').toLowerCase().contains('bath')) {
      result['bath'] = unit.rentalunit!;
    } else if (unit.rentalunitadress != null &&
        (unit.rentalunitadress ?? '').toLowerCase().contains('bath')) {
      result['bath'] = unit.rentalunitadress!;
    } else if (unit.rentalsqft != null &&
        (unit.rentalsqft ?? '').toLowerCase().contains('bath')) {
      result['bath'] = unit.rentalsqft!;
    }

    // Try to find bed value
    if (unit.rentalbed != null &&
        (unit.rentalbed ?? '').toLowerCase().contains('bed')) {
      result['bed'] = unit.rentalbed!;
    } else if (unit.rentalunit != null &&
        (unit.rentalunit ?? '').toLowerCase().contains('bed')) {
      result['bed'] = unit.rentalunit!;
    } else if (unit.rentalunitadress != null &&
        (unit.rentalunitadress ?? '').toLowerCase().contains('bed')) {
      result['bed'] = unit.rentalunitadress!;
    } else if (unit.rentalsqft != null &&
        (unit.rentalsqft ?? '').toLowerCase().contains('bed')) {
      result['bed'] = unit.rentalsqft!;
    }

    return result;
  }

  Widget photo(int index) {
    return StatefulBuilder(
      builder: (BuildContext context, StateSetter setState) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _pfFieldLabel('Photo'),

            // Show image - prioritize local image over network image
            if (propertyGroupImages[index] != null)
              // Show local image if selected (new image from gallery)
              _pfPhotoThumb(
                image: Image.file(
                          propertyGroupImages[index]!,
                  height: 72,
                  width: 72,
                  fit: BoxFit.cover,
                ),
                onRemove: () {
                          setState(() {
                            propertyGroupImages[index] =
                                null; // Clear the local image
                            propertyGroupImagenames[index] =
                                null; // Also clear the network image
                          });
                },
              )
            else if (propertyGroupImagenames[index] != null &&
                propertyGroupImagenames[index]!.isNotEmpty)
              // Show network image if no local image (existing image from API)
              _pfPhotoThumb(
                image: Image.network(
                          propertyGroupImagenames[index]!,
                  height: 72,
                  width: 72,
                  fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 72,
                      width: 72,
                      color: Colors.grey[300],
                      child: const Icon(Icons.error, color: Colors.grey),
                    );
                  },
                ),
                onRemove: () {
                          setState(() {
                            propertyGroupImagenames[index] =
                                null; // Clear the existing image
                          });
                },
              ),

            // Show add image button if no image is displayed
            if (propertyGroupImages[index] == null &&
                (propertyGroupImagenames[index] == null ||
                    propertyGroupImagenames[index]!.isEmpty))
              GestureDetector(
                    onTap: () {
                      getImage(index).then((_) {
                        setState(
                            () {}); // Rebuild the widget after selecting the image
                      });
                    },
                child: CustomPaint(
                  painter: const _PfDashedRRectPainter(
                    color: Color(0xFFCED4DA),
                  ),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.file_upload_outlined,
                            color: navyClr, size: 26),
                        SizedBox(height: 6),
                        Text(
                          'Add Unit Photo',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: navyClr),
                        ),
                        SizedBox(height: 2),
                        Text(
                          '.png, .jpg, .jpeg',
                          style: TextStyle(fontSize: 12, color: mutedClr),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  void addPropertyGroup() {
    // The unit slot this card's fields take. After a card is removed the card
    // count is smaller than the slot count, so the photo and amenities bind to
    // the slot, not to propertyGroups.length.
    final int slot = propertyGroupControllers.length;
    // print("hello");
    List<Widget> fields = [];
    List<TextEditingController> controllers = [];
    // Created before the fields so the pre-built Unit Amenities field can bind
    // to it; added to propertyGroupAmenities next to the image entry below.
    final unitAmenities = ValueNotifier<List<String>>(<String>[]);

    // print(selectedpropertytype);

    if (selectedpropertytype == 'Commercial' && selectedIsMultiUnit == true) {
      var unitController = TextEditingController();
      var unitAddressController = TextEditingController();
      var sqftController = TextEditingController();
      var unitDescriptionController = TextEditingController();

      fields = [
        customTextField('Unit Number', unitController,
            placeholder: 'Enter unit number'),
        customTextField('Unit Address', unitAddressController,
            placeholder: 'Enter unit address'),
        customTextField('SQFT', sqftController, placeholder: 'Enter Sqft'),
        customOptionalField('Unit Description', unitDescriptionController,
            maxLines: 3,
            placeholder: _pfUnitDescHint,
            helperText: _pfUnitDescHelp),
        photo(slot), // Pass the index
      ];

      // Appended, never inserted: existing indices 0-2 must not move.
      controllers = [
        unitController,
        unitAddressController,
        sqftController,
        unitDescriptionController,
      ];
    } else if (selectedpropertytype == 'Residential' &&
        selectedIsMultiUnit == true) {
      var unitController = TextEditingController();
      var unitAddressController = TextEditingController();
      var sqftController = TextEditingController();
      var bathController = TextEditingController();
      var bedController = TextEditingController();
      var rentPriceController = TextEditingController();
      var halfBathsController = TextEditingController();
      var availabilityDateController = TextEditingController();
      var parkingTypeController = TextEditingController();
      var leaseTermController = TextEditingController(text: 'ContactForDetails');
      var securityDepositController = TextEditingController();
      var depositTypeController = TextEditingController(text: 'flatFee');
      var depositMaxController = TextEditingController();
      var depositRefundableController =
          TextEditingController(text: 'refundable');
      var petPolicyController = TextEditingController();
      var furnishedController = TextEditingController(text: 'false');
      var smokingController = TextEditingController(text: 'false');
      var unitDescriptionController = TextEditingController();

      fields = [
        customTextField('Unit', unitController, placeholder: 'Enter unit'),
        customTextField('Unit Address', unitAddressController,
            placeholder: 'Enter unit address'),
        _pfTwoCol(
          customTextField('SQFT', sqftController, placeholder: 'Enter Sqft'),
          customTextField('Rent Price (\$)', rentPriceController,
              money: true, placeholder: 'Enter rent price'),
        ),
        _pfTwoCol(
          customDropdownField('Bed', roomsArray, bedController,
              placeholder: 'Select'),
          customDropdownField('Baths', bathArray, bathController,
              placeholder: 'Select'),
        ),
        _pfTwoCol(
          customDropdownField('Half Baths', halfBathArray, halfBathsController,
              placeholder: 'Select'),
          customValueDropdown(
              'Parking Type', parkingTypeOptions, parkingTypeController),
        ),
        customUnitDateField('Availability Date', availabilityDateController),
        customValueDropdown(
            'Lease Term', leaseTermOptions, leaseTermController,
            showRequired: true),
        _pfTwoCol(
          customOptionalField('Security Deposit (\$)', securityDepositController,
              money: true, placeholder: '0'),
          customValueDropdown(
              'Deposit Type', depositTypeOptions, depositTypeController),
        ),
        // The unit's widgets are built once and stored, so a plain `if` here
        // would be frozen at build time. Listen to the type controller so the
        // field appears/disappears live, like web.
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: depositTypeController,
          builder: (_, v, __) => v.text == 'range'
              ? customOptionalField('Deposit Max (\$)', depositMaxController, money: true)
              : const SizedBox.shrink(),
        ),
        customValueDropdown('Deposit Refundable?', depositRefundableOptions,
            depositRefundableController),
        customOptionalField('Pet Policy', petPolicyController,
            maxLines: 3, placeholder: _pfPetHint),
        ValueListenableBuilder<List<String>>(
          valueListenable: unitAmenities,
          builder: (_, value, __) => AmenitiesField(
              label: 'Unit Amenities',
              value: value,
              isStaff: true,
              onChanged: (v) => unitAmenities.value = v),
        ),
        const SizedBox(height: 16),
        _pfTileRow(
          customCheckboxField('Furnished', furnishedController),
          customCheckboxField('Smoking Allowed', smokingController),
        ),
        customOptionalField('Unit Description', unitDescriptionController,
            maxLines: 3,
            placeholder: _pfUnitDescHint,
            helperText: _pfUnitDescHelp),
        photo(slot), // Pass the index
      ];

      controllers = [
        unitController,
        unitAddressController,
        sqftController,
        bathController,
        bedController,
        rentPriceController,
        halfBathsController,
        availabilityDateController,
        parkingTypeController,
        leaseTermController,
        securityDepositController,
        depositTypeController,
        depositMaxController,
        depositRefundableController,
        petPolicyController,
        furnishedController,
        smokingController,
        unitDescriptionController,
      ];
    } else if (selectedpropertytype == 'Residential') {
      var sqftController = TextEditingController();
      var bathController = TextEditingController();
      var bedController = TextEditingController();
      var rentPriceController = TextEditingController();
      var halfBathsController = TextEditingController();
      var availabilityDateController = TextEditingController();
      var parkingTypeController = TextEditingController();
      var leaseTermController = TextEditingController(text: 'ContactForDetails');
      var securityDepositController = TextEditingController();
      var depositTypeController = TextEditingController(text: 'flatFee');
      var depositMaxController = TextEditingController();
      var depositRefundableController =
          TextEditingController(text: 'refundable');
      var petPolicyController = TextEditingController();
      var furnishedController = TextEditingController(text: 'false');
      var smokingController = TextEditingController(text: 'false');
      var unitDescriptionController = TextEditingController();

      fields = [
        _pfTwoCol(
          customTextField('SQFT', sqftController, placeholder: 'Enter Sqft'),
          customTextField('Rent Price (\$)', rentPriceController,
              money: true, placeholder: 'Enter rent price'),
        ),
        _pfTwoCol(
          customDropdownField('Bed', roomsArray, bedController,
              placeholder: 'Select'),
          customDropdownField('Baths', bathArray, bathController,
              placeholder: 'Select'),
        ),
        _pfTwoCol(
          customDropdownField('Half Baths', halfBathArray, halfBathsController,
              placeholder: 'Select'),
          customValueDropdown(
              'Parking Type', parkingTypeOptions, parkingTypeController),
        ),
        customUnitDateField('Availability Date', availabilityDateController),
        customValueDropdown(
            'Lease Term', leaseTermOptions, leaseTermController,
            showRequired: true),
        _pfTwoCol(
          customOptionalField('Security Deposit (\$)', securityDepositController,
              money: true, placeholder: '0'),
          customValueDropdown(
              'Deposit Type', depositTypeOptions, depositTypeController),
        ),
        // The unit's widgets are built once and stored, so a plain `if` here
        // would be frozen at build time. Listen to the type controller so the
        // field appears/disappears live, like web.
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: depositTypeController,
          builder: (_, v, __) => v.text == 'range'
              ? customOptionalField('Deposit Max (\$)', depositMaxController, money: true)
              : const SizedBox.shrink(),
        ),
        customValueDropdown('Deposit Refundable?', depositRefundableOptions,
            depositRefundableController),
        customOptionalField('Pet Policy', petPolicyController,
            maxLines: 3, placeholder: _pfPetHint),
        ValueListenableBuilder<List<String>>(
          valueListenable: unitAmenities,
          builder: (_, value, __) => AmenitiesField(
              label: 'Unit Amenities',
              value: value,
              isStaff: true,
              onChanged: (v) => unitAmenities.value = v),
        ),
        const SizedBox(height: 16),
        _pfTileRow(
          customCheckboxField('Furnished', furnishedController),
          customCheckboxField('Smoking Allowed', smokingController),
        ),
        customOptionalField('Unit Description', unitDescriptionController,
            maxLines: 3,
            placeholder: _pfUnitDescHint,
            helperText: _pfUnitDescHelp),
        photo(slot), // Pass the index
      ];

      controllers = [
        sqftController,
        bathController,
        bedController,
        rentPriceController,
        halfBathsController,
        availabilityDateController,
        parkingTypeController,
        leaseTermController,
        securityDepositController,
        depositTypeController,
        depositMaxController,
        depositRefundableController,
        petPolicyController,
        furnishedController,
        smokingController,
        unitDescriptionController,
      ];
    } else if (selectedpropertytype == 'Commercial') {
      var sqftController = TextEditingController();
      var unitDescriptionController = TextEditingController();

      fields = [
        customTextField('SQFT', sqftController, placeholder: 'Enter Sqft'),
        customOptionalField('Unit Description', unitDescriptionController,
            maxLines: 3,
            placeholder: _pfUnitDescHint,
            helperText: _pfUnitDescHelp),
        photo(slot), // Pass the index
      ];

      // Appended, never inserted: sqft stays at index 0.
      controllers = [sqftController, unitDescriptionController];
    }

    setState(() {
      propertyGroups.add(fields);
      propertyGroupControllers.add(controllers);
      propertyGroupImages.add(null);
      propertyGroupImagenames.add(null);
      propertyGroupAmenities.add(unitAmenities);
      // Initialize with null for the new group
    });
  }

  void displayPropertyData() {
    // Check if the first element is blank and remove it if it is
    if (propertyGroupControllers.isNotEmpty) {
      List<TextEditingController> firstControllers =
          propertyGroupControllers[0];
      bool isFirstBlank =
          firstControllers.every((controller) => controller.text.isEmpty);

      if (isFirstBlank) {
        propertyGroupControllers.removeAt(0);
      }
    }

    // print(propertyGroupControllers.length);

    for (int i = 0; i < propertyGroupControllers.length; i++) {
      List<TextEditingController> controllers = propertyGroupControllers[i];
      for (int j = 0; j < controllers.length; j++) {
        // print(controllers[j].text);
      }
    }
  }

  void handleEdit(RentalOwner rental) async {
    // Handle edit action
    // print('Edit ${rental.sId}');
    // // final result = await Navigator.push(
    // //     context,
    // //     MaterialPageRoute(
    // //         builder: (context) => Edit_staff_member(
    // //           staff: rental,
    // //         )));
    // if (result == true) {
    //   setState(() {
    //     futureStaffMembers = StaffMemberRepository().fetchStaffmembers();
    //   });
    // }
  }
  RentalOwner? Ownersdetails;
  String? processor_id;
  List<OwnersDetails> OwnersdetailsGroups = [];
  bool hasError = false;

  final FocusNode _nodeText1 = FocusNode();
  KeyboardActionsConfig _buildConfig(BuildContext context) {
    return KeyboardActionsConfig(
      keyboardActionsPlatform: KeyboardActionsPlatform.ALL,
      keyboardBarColor: Colors.grey[200],
      nextFocus: true,
      actions: [
        KeyboardActionsItem(
          focusNode: _nodeText1,
        ),
      ],
    );
  }

  bool isEditable = false;

  // ---- Redesign helpers (web-aligned property form; visual only) ---------

  static const Color _pfHintClr = Color(0xFF94A1B4);
  static const TextStyle _pfTableHeadStyle =
      TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: navyClr);
  static const String _pfUnitDescHint = 'Enter unit-level description...';
  static const String _pfUnitDescHelp =
      'Describe unit features, layout, appliances, and unique qualities';
  static const String _pfPetHint =
      'Additional pet policy notes (e.g., Max 2 pets, \$500 deposit)';

  Widget _pfSectionCard({
    String? title,
    String? subtitle,
    Widget? trailing,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderClr),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: navyClr,
                    ),
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 8),
                  trailing,
                ],
              ],
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: navyClr,
                ),
              ),
            ],
            const SizedBox(height: 16),
          ],
          ...children,
        ],
      ),
    );
  }

  // Text.rich (not RichText) so the label inherits the app font.
  Widget _pfFieldLabel(String text, {bool required = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      // Keep long labels (e.g. "Security Deposit ($)") on one line in a
      // half-width column so both boxes in the row stay level.
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text.rich(
        TextSpan(
          text: text,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: navyClr,
          ),
          children: required
              ? const [
                  TextSpan(
                    text: ' *',
                    style: TextStyle(
                      color: redClr,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ]
              : const [],
        ),
      ),
      ),
    );
  }

  InputDecoration _pfInputDecoration({
    String? hint,
    bool error = false,
    Widget? suffixIcon,
  }) {
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color, width: width),
        );
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: _pfHintClr, fontSize: 14),
      filled: true,
      fillColor: Colors.white,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      suffixIcon: suffixIcon,
      border: border(outlineClr),
      enabledBorder: border(error ? redClr : outlineClr),
      focusedBorder: border(error ? redClr : navyClr, 1.5),
      errorBorder: border(redClr),
      focusedErrorBorder: border(redClr, 1.5),
    );
  }

  Widget _pfTwoCol(Widget a, Widget b) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: a),
        const SizedBox(width: 12),
        Expanded(child: b),
      ],
    );
  }

  // Two equal-height tiles (Furnished | Smoking Allowed).
  Widget _pfTileRow(Widget a, Widget b) {
    // Side by side only when each tile has room for "Furnished" on one line
    // (row >= 300); on narrower phones stack them so no word breaks mid-way.
    return LayoutBuilder(
      builder: (context, box) => box.maxWidth >= 300
          ? IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: a),
                  const SizedBox(width: 12),
                  Expanded(child: b),
                ],
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [a, const SizedBox(height: 12), b],
            ),
    );
  }

  Widget _pfAddLinkButton({
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: navyClr,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 10),
            // No Flexible here: as a card-title trailing widget this Row gets
            // unbounded width, where a flex child would throw.
            Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: navyClr,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pfIconButton({
    required IconData icon,
    required Color color,
    required Color bg,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }

  Widget _pfUnitSubCard({required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderClr),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _pfPhotoThumb({
    required Widget image,
    required VoidCallback onRemove,
  }) {
    return SizedBox(
      width: 80,
      height: 80,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            bottom: 0,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: image,
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: borderClr),
                ),
                child: const Icon(Icons.close, size: 14, color: mutedClr),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // print(selectedIsMultiUnit);
    // print(selectedProperty);
    final ownerDetails =
        Provider.of<OwnerDetailsProvider>(context).OwnerDetails;

    final firstnameController =
        TextEditingController(text: ownerDetails?.rentalOwnerName);
    final comnameController =
        TextEditingController(text: ownerDetails?.rentalOwnerCompanyName);
    final primaryemailController =
        TextEditingController(text: ownerDetails?.rentalOwnerPrimaryEmail);
    final phonenumController =
        TextEditingController(text: ownerDetails?.rentalOwnerPhoneNumber);
    final cityController = TextEditingController(text: ownerDetails?.city);
    final stateController = TextEditingController(text: ownerDetails?.state);
    final countyController = TextEditingController(text: ownerDetails?.country);
    final codeController =
        TextEditingController(text: ownerDetails?.postalCode);
    return Scaffold(
      appBar: widget_302_Staff.App_Bar(context: context),
      backgroundColor: pageBg,
      drawer: CustomDrawerStaff(
        currentpage: "Properties",
        dropdown: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14.0),
                  child: Container(
                    height: 50.0,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    alignment: Alignment.centerLeft,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14.0),
                      color: navyClr,
                    ),
                    child: const Text(
                      "Edit Property",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                //dropdown
                _pfSectionCard(
                  title: "Property Information",
                  children: [
                          // Row(
                          //   children: [
                          //     SizedBox(
                          //       width: 15,
                          //     ),
                          //     Text(
                          //       "New Property ",
                          //       style: TextStyle(
                          //           fontWeight: FontWeight.bold,
                          //           color: blueColor,
                          //           fontSize:
                          //               MediaQuery.of(context).size.width < 500
                          //                   ? 17
                          //                   : 18),
                          //     ),
                          //   ],
                          // ),
                          // SizedBox(
                          //   height: 10,
                          // ),
                          _pfFieldLabel("Property Type", required: true),
                              FutureBuilder<List<propertytype>>(
                                future: futureProperties,
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return const Center(
                                        child: SpinKitFadingCircle(
                                      color: Colors.black,
                                      size: 40.0,
                                    ));
                                  } else if (snapshot.hasError) {
                                    return Text(friendlyErrorMessage(snapshot.error), textAlign: TextAlign.center);
                                  } else if (!snapshot.hasData ||
                                      snapshot.data!.isEmpty) {
                                    return const Text('No properties found');
                                  } else {
                                    Map<String, List<propertytype>>
                                        groupedProperties =
                                        groupPropertiesByType(snapshot.data!);

                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                          Container(
                                            // height: MediaQuery.of(context)
                                            //         .size
                                            //         .height *
                                            //     .05,
                                            height: 50,
                                            width: double.infinity,
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              border: Border.all(
                                                color: outlineClr,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: DropdownButtonHideUnderline(
                                              child: DropdownButton2<String>(
                                                value: groupedProperties
                                                        .isNotEmpty
                                                    ? (groupedProperties.entries
                                                            .expand((entry) =>
                                                                entry.value.map(
                                                                    (item) => item
                                                                        .propertysubType))
                                                            .contains(
                                                                selectedProperty)
                                                        ? selectedProperty
                                                        : null)
                                                    : null,
                                                hint: const Text(
                                                  'Add Property Type',
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    color: _pfHintClr,
                                                  ),
                                                ),
                                                onChanged: isEditable
                                                    ? (String? newValue) {
                                                        if (newValue ==
                                                            'Edit_properties') {
                                                          // Prevent the dropdown from changing the selected item
                                                          setState(() {
                                                            selectedProperty =
                                                                null;
                                                          });
                                                          // Show the dialog
                                                          showDialog(
                                                            context: context,
                                                            builder:
                                                                (BuildContext
                                                                    context) {
                                                              bool isChecked =
                                                                  false; // Moved isChecked inside the StatefulBuilder
                                                              return StatefulBuilder(
                                                                builder: (BuildContext
                                                                        context,
                                                                    StateSetter
                                                                        setState) {
                                                                  return Dialog(
                                                                    // Inline "add a property type" from the property form. Restyled to the
                                                                    // house card system used by the Property Type screens; fields and the
                                                                    // save call are exactly as before. No image field on purpose: web's
                                                                    // inline AddpropertyModal has none either (only Settings' dialog does),
                                                                    // so the type falls back to the default image, matching web.
                                                                    backgroundColor: Colors.transparent,
                                                                    insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                                                    child: ConstrainedBox(
                                                                      constraints: const BoxConstraints(maxWidth: 480),
                                                                      child: Container(
                                                                        decoration: BoxDecoration(
                                                                          color: Colors.white,
                                                                          borderRadius: BorderRadius.circular(16),
                                                                          border: Border.all(color: borderClr),
                                                                          boxShadow: [
                                                                            BoxShadow(
                                                                              color: Colors.black.withOpacity(0.06),
                                                                              blurRadius: 16,
                                                                              offset: const Offset(0, 6),
                                                                            ),
                                                                          ],
                                                                        ),
                                                                        padding: const EdgeInsets.all(20),
                                                                        child: SingleChildScrollView(
                                                                          child: Column(
                                                                            mainAxisSize: MainAxisSize.min,
                                                                            crossAxisAlignment: CrossAxisAlignment.start,
                                                                            children: [
                                                                              // Header: title leads, close control trails.
                                                                              Row(
                                                                                children: [
                                                                                  Expanded(
                                                                                    child: Text(
                                                                                      'New Property Type',
                                                                                      style: TextStyle(
                                                                                        fontSize: 18,
                                                                                        fontWeight: FontWeight.bold,
                                                                                        color: navyClr,
                                                                                      ),
                                                                                    ),
                                                                                  ),
                                                                                  Material(
                                                                                    color: Colors.transparent,
                                                                                    child: InkWell(
                                                                                      borderRadius: BorderRadius.circular(18),
                                                                                      onTap: () => Navigator.pop(context),
                                                                                      child: Container(
                                                                                        width: 36,
                                                                                        height: 36,
                                                                                        decoration: const BoxDecoration(
                                                                                          color: Color(0xFFF2F4F7),
                                                                                          shape: BoxShape.circle,
                                                                                        ),
                                                                                        child: const Icon(Icons.close,
                                                                                            size: 20, color: Colors.black54),
                                                                                      ),
                                                                                    ),
                                                                                  ),
                                                                                ],
                                                                              ),
                                                                              const SizedBox(height: 18),

                                                                              // Property Type *
                                                                              Padding(
                                                                                padding: const EdgeInsets.only(bottom: 8),
                                                                                child: RichText(
                                                                                  text: TextSpan(
                                                                                    text: 'Property Type',
                                                                                    style: TextStyle(
                                                                                        fontSize: 14, fontWeight: FontWeight.bold, color: navyClr),
                                                                                    children: [
                                                                                      TextSpan(
                                                                                          text: ' *',
                                                                                          style: TextStyle(
                                                                                              color: redClr, fontWeight: FontWeight.bold)),
                                                                                    ],
                                                                                  ),
                                                                                ),
                                                                              ),
                                                                              DropdownButtonHideUnderline(
                                                                                child: DropdownButton2<String>(
                                                                                  isExpanded: true,
                                                                                  hint: Text(
                                                                                    'Select type',
                                                                                    style: TextStyle(
                                                                                        fontSize: 15,
                                                                                        fontWeight: FontWeight.w600,
                                                                                        color: mutedClr),
                                                                                    overflow: TextOverflow.ellipsis,
                                                                                  ),
                                                                                  items: items
                                                                                      .map((String item) => DropdownMenuItem<String>(
                                                                                            value: item,
                                                                                            // Item padding lives here, not on menuItemStyleData: the package
                                                                                            // derives the closed button's inner inset from half that value.
                                                                                            child: Padding(
                                                                                              padding: const EdgeInsets.symmetric(horizontal: 14),
                                                                                              child: Text(
                                                                                                item,
                                                                                                style: TextStyle(
                                                                                                    fontSize: 15,
                                                                                                    fontWeight: FontWeight.w600,
                                                                                                    color: navyClr),
                                                                                                overflow: TextOverflow.ellipsis,
                                                                                              ),
                                                                                            ),
                                                                                          ))
                                                                                      .toList(),
                                                                                  // The closed button renders the item with menuItemStyleData's own
                                                                                  // padding on top of the button's, so the selected value sat further
                                                                                  // in than the text field below it. This draws the closed state
                                                                                  // itself, with no padding, leaving only the button's 14.
                                                                                  selectedItemBuilder: (context) => items
                                                                                      .map((String item) => Align(
                                                                                            alignment: Alignment.centerLeft,
                                                                                            child: Text(
                                                                                              item,
                                                                                              style: TextStyle(
                                                                                                fontSize: 15,
                                                                                                fontWeight: FontWeight.w600,
                                                                                                color: navyClr,
                                                                                              ),
                                                                                              overflow: TextOverflow.ellipsis,
                                                                                            ),
                                                                                          ))
                                                                                      .toList(),
                                                                                  value: selectedValue,
                                                                                  onChanged: (value) {
                                                                                    setState(() {
                                                                                      selectedValue = value;
                                                                                    });
                                                                                  },
                                                                                  buttonStyleData: ButtonStyleData(
                                                                                    height: 52,
                                                                                    padding: const EdgeInsets.only(left: 14, right: 12),
                                                                                    decoration: BoxDecoration(
                                                                                      color: Colors.white,
                                                                                      borderRadius: BorderRadius.circular(10),
                                                                                      border: Border.all(color: outlineClr),
                                                                                    ),
                                                                                  ),
                                                                                  iconStyleData: IconStyleData(
                                                                                    icon: Icon(Icons.keyboard_arrow_down_rounded, color: mutedClr),
                                                                                    iconSize: 24,
                                                                                  ),
                                                                                  dropdownStyleData: DropdownStyleData(
                                                                                    maxHeight: 220,
                                                                                    decoration: BoxDecoration(
                                                                                      color: Colors.white,
                                                                                      borderRadius: BorderRadius.circular(12),
                                                                                    ),
                                                                                  ),
                                                                                  // Zero here on purpose: the package derives the CLOSED button's
                                                                                  // inner padding from half of this value, which pushed the selected
                                                                                  // value further in than the text field below it. Each item carries
                                                                                  // its own padding instead, so the open menu is unchanged.
                                                                                  menuItemStyleData: const MenuItemStyleData(
                                                                                    height: 44,
                                                                                    padding: EdgeInsets.zero,
                                                                                  ),
                                                                                ),
                                                                              ),
                                                                              const SizedBox(height: 18),

                                                                              // Property Sub Type *
                                                                              Padding(
                                                                                padding: const EdgeInsets.only(bottom: 8),
                                                                                child: RichText(
                                                                                  text: TextSpan(
                                                                                    text: 'Property Sub Type',
                                                                                    style: TextStyle(
                                                                                        fontSize: 14, fontWeight: FontWeight.bold, color: navyClr),
                                                                                    children: [
                                                                                      TextSpan(
                                                                                          text: ' *',
                                                                                          style: TextStyle(
                                                                                              color: redClr, fontWeight: FontWeight.bold)),
                                                                                    ],
                                                                                  ),
                                                                                ),
                                                                              ),
                                                                              Container(
                                                                                decoration: BoxDecoration(
                                                                                  color: Colors.white,
                                                                                  borderRadius: BorderRadius.circular(10),
                                                                                  border: Border.all(color: outlineClr),
                                                                                ),
                                                                                padding: const EdgeInsets.symmetric(horizontal: 14),
                                                                                child: TextFormField(
                                                                                  controller: subtype,
                                                                                  style: TextStyle(
                                                                                      fontSize: 15, fontWeight: FontWeight.w600, color: navyClr),
                                                                                  decoration: InputDecoration(
                                                                                    border: InputBorder.none,
                                                                                    isDense: true,
                                                                                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                                                                                    hintText: 'e.g. Townhome',
                                                                                    hintStyle: TextStyle(
                                                                                        color: mutedClr,
                                                                                        fontWeight: FontWeight.w500,
                                                                                        fontSize: 15),
                                                                                  ),
                                                                                ),
                                                                              ),
                                                                              const SizedBox(height: 18),

                                                                              // Multi Unit
                                                                              Row(
                                                                                children: [
                                                                                  SizedBox(
                                                                                    width: 24,
                                                                                    height: 24,
                                                                                    child: Checkbox(
                                                                                      value: isChecked,
                                                                                      onChanged: (value) {
                                                                                        setState(() {
                                                                                          isChecked = value ?? false;
                                                                                        });
                                                                                      },
                                                                                      activeColor: navyClr,
                                                                                      checkColor: Colors.white,
                                                                                      side: BorderSide(color: checkOffClr, width: 1.5),
                                                                                      shape: RoundedRectangleBorder(
                                                                                          borderRadius: BorderRadius.circular(6)),
                                                                                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                                                      visualDensity: VisualDensity.compact,
                                                                                    ),
                                                                                  ),
                                                                                  const SizedBox(width: 12),
                                                                                  Expanded(
                                                                                    child: Text(
                                                                                      'Multi Unit',
                                                                                      style: TextStyle(
                                                                                          fontSize: 15,
                                                                                          fontWeight: FontWeight.w600,
                                                                                          color: navyClr),
                                                                                    ),
                                                                                  ),
                                                                                ],
                                                                              ),

                                                                              if (iserror) ...[
                                                                                const SizedBox(height: 14),
                                                                                Text(
                                                                                  'Please fill in all fields correctly.',
                                                                                  style: TextStyle(
                                                                                      color: redClr, fontWeight: FontWeight.w600, fontSize: 13),
                                                                                ),
                                                                              ],
                                                                              const SizedBox(height: 22),

                                                                              // Actions
                                                                              Row(
                                                                                children: [
                                                                                  Expanded(
                                                                                    child: OutlinedButton(
                                                                                      onPressed: isLoading ? null : () => Navigator.pop(context),
                                                                                      style: OutlinedButton.styleFrom(
                                                                                        backgroundColor: Colors.white,
                                                                                        side: BorderSide(color: outlineClr),
                                                                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                                                                        shape: RoundedRectangleBorder(
                                                                                            borderRadius: BorderRadius.circular(10)),
                                                                                      ),
                                                                                      child: Text(
                                                                                        'Cancel',
                                                                                        style: TextStyle(
                                                                                            color: mutedClr,
                                                                                            fontWeight: FontWeight.bold,
                                                                                            fontSize: 15),
                                                                                      ),
                                                                                    ),
                                                                                  ),
                                                                                  const SizedBox(width: 12),
                                                                                  Expanded(
                                                                                    child: ElevatedButton(
                                                                                      // Save logic unchanged from the previous dialog, including
                                                                                      // the un-trimmed subtype check it always had.
                                                                                      onPressed: isLoading
                                                                                          ? null
                                                                                          : () async {
                                                                                              if (selectedValue == null ||
                                                                                                  subtype.text.isEmpty) {
                                                                                                setState(() {
                                                                                                  iserror = true;
                                                                                                });
                                                                                              } else {
                                                                                                setState(() {
                                                                                                  isLoading = true;
                                                                                                  iserror = false;
                                                                                                });
                                                                                                SharedPreferences prefs =
                                                                                                    await SharedPreferences.getInstance();
                                                                                                String? id = prefs.getString("adminId");
                                                                                                PropertyTypeRepository()
                                                                                                    .addPropertyType(
                                                                                                  adminId: id!,
                                                                                                  propertyType: selectedValue,
                                                                                                  propertySubType: subtype.text,
                                                                                                  isMultiUnit: isChecked,
                                                                                                )
                                                                                                    .then((value) {
                                                                                                  setState(() {
                                                                                                    isLoading = false;
                                                                                                  });
                                                                                                  Navigator.pop(context, true);
                                                                                                }).catchError((e) {
                                                                                                  setState(() {
                                                                                                    isLoading = false;
                                                                                                  });
                                                                                                });
                                                                                              }
                                                                                            },
                                                                                      style: ElevatedButton.styleFrom(
                                                                                        backgroundColor: navyClr,
                                                                                        disabledBackgroundColor: navyClr.withOpacity(0.6),
                                                                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                                                                        elevation: 0,
                                                                                        shape: RoundedRectangleBorder(
                                                                                            borderRadius: BorderRadius.circular(10)),
                                                                                      ),
                                                                                      child: isLoading
                                                                                          ? const SpinKitFadingCircle(
                                                                                              color: Colors.white, size: 22.0)
                                                                                          : const Text(
                                                                                              'Add',
                                                                                              style: TextStyle(
                                                                                                  color: Colors.white,
                                                                                                  fontWeight: FontWeight.bold,
                                                                                                  fontSize: 15),
                                                                                            ),
                                                                                    ),
                                                                                  ),
                                                                                ],
                                                                              ),
                                                                            ],
                                                                          ),
                                                                        ),
                                                                      ),
                                                                    ),
                                                                  );
                                                                },
                                                              );
                                                            },
                                                          );
                                                        } else {
                                                          setState(() {
                                                            // selectedIsMultiUnit = snapshot.data!.where((element) => element.isMultiunit == newValue ).first;
                                                            selectedpropertytypedata = snapshot
                                                                .data!
                                                                .where((element) =>
                                                                    element
                                                                        .propertysubType ==
                                                                    newValue)
                                                                .first;
                                                            // print(selectedProperty);
                                                            selectedProperty =
                                                                newValue;
                                                            propertyGroups = [];
                                                            // Call the method here
                                                            selectedpropertytype =
                                                                selectedpropertytypedata!
                                                                    .propertyType;
                                                            selectedIsMultiUnit =
                                                                selectedpropertytypedata!
                                                                    .isMultiunit!;
                                                          });
                                                          showError =
                                                              selectedProperty ==
                                                                  null;
                                                          propertyGroups
                                                              .clear();
                                                          addPropertyGroup();
                                                          propertyTypeError =
                                                              false;
                                                        }
                                                      }
                                                    : null,
                                                items: [
                                                  ...groupedProperties.entries
                                                      .expand((entry) {
                                                    return [
                                                      DropdownMenuItem<String>(
                                                        enabled: false,
                                                        child: Text(
                                                          entry.key,
                                                          style:
                                                              const TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  color: Color
                                                                      .fromRGBO(
                                                                          21,
                                                                          43,
                                                                          81,
                                                                          1)),
                                                        ),
                                                      ),
                                                      ...entry.value
                                                          .map((item) {
                                                        return DropdownMenuItem<
                                                            String>(
                                                          value: item
                                                              .propertysubType,
                                                          child: Padding(
                                                            padding:
                                                                const EdgeInsets
                                                                    .only(
                                                                    left: 16.0),
                                                            child: Text(
                                                              item.propertysubType ??
                                                                  '',
                                                              style:
                                                                  const TextStyle(
                                                                color: Colors
                                                                    .black,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w400,
                                                              ),
                                                            ),
                                                          ),
                                                        );
                                                      }).toList(),
                                                    ];
                                                  }).toList(),
                                                  const DropdownMenuItem<
                                                      String>(
                                                    value: 'Edit_properties',
                                                    child: Row(
                                                      children: [
                                                        Icon(Icons.add,
                                                            size:
                                                                15), // Adjusted icon size
                                                        SizedBox(width: 6),
                                                        Text(
                                                            'Add New properties',
                                                            style: TextStyle(
                                                                fontSize:
                                                                    16 //MediaQuery.of(context).size.width * .03
                                                                )), // Adjusted text size
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                                // Closed-button text only, one entry per item above (group header,
                                                // sub types, then the add row), so the chosen sub type sits flush
                                                // left like the other fields instead of carrying the menu indent.
                                                selectedItemBuilder: (context) => [
                                                  ...groupedProperties.entries.expand((entry) => [
                                                        const SizedBox.shrink(),
                                                        ...entry.value.map(
                                                          (item) => Align(
                                                            alignment: Alignment.centerLeft,
                                                            child: Text(
                                                              item.propertysubType ?? '',
                                                              style: const TextStyle(fontSize: 14, color: navyClr),
                                                              overflow: TextOverflow.ellipsis,
                                                            ),
                                                          ),
                                                        ),
                                                      ]),
                                                  const SizedBox.shrink(),
                                                ],
                                                isExpanded: true,
                                                buttonStyleData:
                                                    ButtonStyleData(
                                                  height: 48,
                                                  // No extra left inset: the item padding already
                                                  // lines the text up with the fields below.
                                                  padding: const EdgeInsets
                                                      .only(
                                                      left: 0,
                                                      right: 12),
                                                  decoration: BoxDecoration(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12),
                                                    color: Colors.transparent,
                                                  ),
                                                ),
                                                iconStyleData:
                                                    const IconStyleData(
                                                  icon: Icon(
                                                      Icons.keyboard_arrow_down,
                                                      color: navyClr),
                                                  iconSize: 22,
                                                ),
                                                dropdownStyleData:
                                                    DropdownStyleData(
                                                  maxHeight: 300,
                                                  decoration: BoxDecoration(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            10),
                                                    color: Colors.white,
                                                  ),
                                                  scrollbarTheme:
                                                      ScrollbarThemeData(
                                                    radius:
                                                        const Radius.circular(
                                                            40),
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
                                                  padding: EdgeInsets.symmetric(
                                                      horizontal: 16,
                                                      vertical: 8),
                                                ),
                                              ),
                                            ),
                                          ),
                                        const SizedBox(
                                          height: 8,
                                        ),
                                        if (showError)
                                          const Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.start,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Please select a property type.',
                                                style: TextStyle(
                                                    color: Colors.red),
                                              ),
                                            ],
                                          ),
                                      ],
                                    );
                                  }
                                },
                              ),
                          propertyTypeError
                              ? Row(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Text(
                                      propertyTypeErrorMessage,
                                        style: const TextStyle(
                                            color: Colors.red, fontSize: 13),
                                      ),
                                    ),
                                  ],
                                )
                              : Container(),
                          const SizedBox(
                            height: 8,
                          ),
                          _pfFieldLabel("Address", required: true),
                              // Expanded(
                              //   child: Container(
                              //     height: 40,
                              //     decoration: BoxDecoration(
                              //       color: Colors.white,
                              //       borderRadius: BorderRadius.circular(5),
                              //       border:
                              //       Border.all(color: Color(0xFF8A95A8)),
                              //     ),
                              //     child: Stack(
                              //       children: [
                              //         Positioned.fill(
                              //           child: TextField(
                              //             style: TextStyle(
                              //               color: Colors.black,
                              //               fontSize:
                              //               MediaQuery.of(context).size.width < 500 ? 13 : 15,
                              //             ),
                              //             onChanged: (value) {
                              //               setState(() {
                              //                 addresserror = false;
                              //               });
                              //             },
                              //             controller: address,
                              //             cursorColor:
                              //             blueColor,
                              //             decoration: InputDecoration(
                              //               enabledBorder: addresserror
                              //                   ? OutlineInputBorder(
                              //                 borderRadius:
                              //                 BorderRadius.circular(
                              //                     5),
                              //                 borderSide: BorderSide(
                              //                     color: Colors
                              //                         .red), // Set border color here
                              //               )
                              //                   : InputBorder.none,
                              //               border: InputBorder.none,
                              //               contentPadding: EdgeInsets.all(14),
                              //               // prefixIcon: Container(
                              //               //   height: 20,
                              //               //   width: 20,
                              //               //   padding: EdgeInsets.all(13),
                              //               //   child: FaIcon(
                              //               //     FontAwesomeIcons.envelope,
                              //               //     size: 20,
                              //               //     color: Colors.grey[600],
                              //               //   ),
                              //               // ),
                              //               hintText: "Enter address",
                              //               hintStyle: TextStyle(
                              //                   color: Color(0xFF8A95A8),
                              //                   fontSize:  MediaQuery.of(context).size.width < 500 ? 14 : 18),
                              //             ),
                              //           ),
                              //         ),
                              //       ],
                              //     ),
                              //   ),
                              // ),
                                        TextField(
                                          style: const TextStyle(
                                            color: navyClr,
                                            fontSize: 14,
                                          ),
                                          keyboardType: TextInputType
                                              .text, // Adjust as needed
                                          onChanged: (value) {
                                            setState(() {
                                              addresserror = false;
                                            });
                                          },
                                          controller: address,
                                          cursorColor: blueColor,
                                          decoration: _pfInputDecoration(
                                            hint: "Enter street address",
                                            error: addresserror,
                                          ),
                                      // color: Color.fromRGBO(196, 196, 196, .3),
                                            // prefixIcon: Container(
                                            //   height: 20,
                                            //   width: 20,
                                            //   padding: EdgeInsets.all(13),
                                            //   child: FaIcon(
                                            //     FontAwesomeIcons.locationArrow, // Replace with your icon
                                            //     size: 20,
                                            //     color: Colors.grey[600],
                                            //   ),
                                            // ),
                                        ),
                          addresserror
                              ? Row(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    Text(
                                      addressmessage,
                                      style: const TextStyle(color: Colors.red),
                                    ),
                                  ],
                                )
                              : Container(),
                          const SizedBox(
                            height: 16,
                          ),
                          Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // First Column
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _pfFieldLabel("City", required: true),
                                      TextField(
                                                keyboardType:
                                                    TextInputType.text,
                                                controller: city,
                                                style: const TextStyle(
                                                  color: navyClr,
                                                  fontSize: 14,
                                                ),
                                                onChanged: (value) {
                                                  setState(() {
                                                    cityerror = false;
                                                  });
                                                },
                                                cursorColor: blueColor,
                                                decoration: _pfInputDecoration(
                                                  hint: "Enter city",
                                                  error: cityerror,
                                                ),
                                              ),
                                      cityerror
                                          ? Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.start,
                                              children: [
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                          left: 5),
                                                  child: Text(
                                                    citymessage,
                                                    style: const TextStyle(color: Colors.red),
                                                  ),
                                                ),
                                              ],
                                            )
                                          : Container(),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Second Column
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _pfFieldLabel("State", required: true),
                                      TextField(
                                                keyboardType:
                                                    TextInputType.text,
                                                controller: state,
                                                style: const TextStyle(
                                                  color: navyClr,
                                                  fontSize: 14,
                                                ),
                                                onChanged: (value) {
                                                  setState(() {
                                                    stateerror = false;
                                                  });
                                                },
                                                cursorColor: blueColor,
                                                decoration: _pfInputDecoration(
                                                  hint: "Enter state",
                                                  error: stateerror,
                                                ),
                                              ),
                                      stateerror
                                          ? Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.start,
                                              children: [
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                          left: 5),
                                                  child: Text(
                                                    statemessage,
                                                    style: const TextStyle(color: Colors.red),
                                                  ),
                                                ),
                                              ],
                                            )
                                          : Container(),
                                    ],
                                  ),
                                ),
                              ],
                          ),
                          const SizedBox(
                            height: 16,
                          ),
                          Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // First Column
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _pfFieldLabel("Zip Code", required: true),
                                      TextField(
                                                focusNode: _nodeText1,
                                                controller: postalcode,
                                                style: const TextStyle(
                                                  color: navyClr,
                                                  fontSize: 14,
                                                ),
                                                onChanged: (value) {
                                                  setState(() {
                                                    postalcodeerror = false;
                                                  });
                                                },
                                                keyboardType:
                                                    TextInputType.number,
                                                inputFormatters: [
                                                  FilteringTextInputFormatter
                                                      .digitsOnly,
                                                ],
                                                // keyboardType: TextInputType.numberWithOptions(signed: true,decimal: true),
                                                cursorColor: blueColor,
                                                decoration: _pfInputDecoration(
                                                  hint: "Enter zip code",
                                                  error: postalcodeerror,
                                                ),
                                              ),
                                      postalcodeerror
                                          ? Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.start,
                                              children: [
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                          left: 5),
                                                  child: Text(
                                                    postalcodemessage,
                                                    style: const TextStyle(color: Colors.red),
                                                  ),
                                                ),
                                              ],
                                            )
                                          : Container(),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Second Column
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _pfFieldLabel("Country", required: true),
                                      TextField(
                                                keyboardType:
                                                    TextInputType.text,
                                                controller: country,
                                                style: const TextStyle(
                                                  color: navyClr,
                                                  fontSize: 14,
                                                ),
                                                onChanged: (value) {
                                                  setState(() {
                                                    countryerror = false;
                                                  });
                                                },
                                                cursorColor: blueColor,
                                                decoration: _pfInputDecoration(
                                                  hint: "Enter country",
                                                  error: countryerror,
                                                ),
                                              ),
                                      countryerror
                                          ? Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.start,
                                              children: [
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                          left: 5),
                                                  child: Text(
                                                    countrymessage,
                                                    style: const TextStyle(color: Colors.red),
                                                  ),
                                                ),
                                              ],
                                            )
                                          : Container(),
                                    ],
                                  ),
                                ),
                              ],
                          ),
                  ],
                ),
                const SizedBox(height: 16),
                // Property Amenities (building/community level) — Residential
                // only, like web. One list for the whole property.
                if (selectedpropertytypedata != null &&
                    selectedpropertytypedata!.propertyType == "Residential" &&
                    _zillowAdvertise)
                  ...[
                    _pfSectionCard(
                      children: [
                        ValueListenableBuilder<List<String>>(
                            valueListenable: propertyAmenities,
                            builder: (_, value, __) => AmenitiesField(
                              label:
                                  'Property Amenities (Building/Community Level)',
                              value: value,
                              isStaff: true,
                              emptyText:
                                  'No property amenities — click "Add Amenities" to select from the catalog or add custom.',
                              onChanged: (v) => propertyAmenities.value = v,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(
                      height: 16,
                    ),
                  ],
                //rental
                _pfSectionCard(
                  title: "Owner Information",
                  children: [
                    const Text.rich(
                      TextSpan(
                        text: "Who is the property owner?",
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: navyClr),
                        children: [
                          TextSpan(
                            text: " (Required)",
                            style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: mutedClr),
                          ),
                        ],
                      ),
                    ),
                                        //  fontWeight: FontWeight.bold,
                    const SizedBox(height: 6),
                    const Text(
                      "This information will be used to help prepare owner draws and 1099s.",
                      style: TextStyle(fontSize: 14, color: mutedClr),
                    ),
                                        //  fontWeight: FontWeight.bold,
                    const SizedBox(height: 14),
                    _pfAddLinkButton(
                      label: "Add Rental Owner",
                              onTap: () {
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) => AddRentalowners(
                                              OwnersDetails: Ownersdetails,
                                              isEdit: true,
                                            )));
                              },
                    ),
                            if (hasError &&
                                Provider.of<OwnerDetailsProvider>(context)
                                        .OwnerDetails ==
                                    null)
                              const Padding(
                                padding: EdgeInsets.only(top: 8.0, bottom: 3),
                                child: Text(
                                  'required',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            Consumer<OwnerDetailsProvider>(
                              builder: (context, provider, child) {
                                Ownersdetails = provider.OwnerDetails;
                                return Ownersdetails != null
                                    ? Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const SizedBox(height: 18),
                                          const Text(
                                            "Rental Owner Information",
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: navyClr,
                                            ),
                                          ),
                                          const SizedBox(height: 10),
                                          Container(
                                            width: double.infinity,
                                            clipBehavior: Clip.antiAlias,
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border:
                                                  Border.all(color: borderClr),
                                            ),
                                            child: Column(
                                              children: [
                                                Container(
                                                  color: tintBg,
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 14,
                                                      vertical: 12),
                                                  child: const Row(
                                                    children: [
                                                      Expanded(
                                                        child: Text('Name',
                                                            style:
                                                                _pfTableHeadStyle),
                                                      ),
                                                      SizedBox(width: 8),
                                                      Expanded(
                                                        child: Text(
                                                            'Phone Number',
                                                            style:
                                                                _pfTableHeadStyle),
                                                      ),
                                                      SizedBox(width: 8),
                                                      SizedBox(
                                                        width: 80,
                                                        child: Text('Action',
                                                            style:
                                                                _pfTableHeadStyle),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                Padding(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 14,
                                                      vertical: 10),
                                                  child: Row(
                                                    children: [
                                                      Expanded(
                                                        child: Text(
                                                              Ownersdetails!
                                                                      .rentalOwnerName ??
                                                                  'N/A',
                                                          style:
                                                              const TextStyle(
                                                                  fontSize: 14,
                                                                  color:
                                                                      navyClr),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Expanded(
                                                        child: Text(
                                                              Ownersdetails!
                                                                      .rentalOwnerPhoneNumber ??
                                                                  'N/A',
                                                          style:
                                                              const TextStyle(
                                                                  fontSize: 14,
                                                                  color:
                                                                      navyClr),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      SizedBox(
                                                        width: 80,
                                                        child: Row(
                                                          children: [
                                                            _pfIconButton(
                                                              icon: Icons
                                                                  .edit_outlined,
                                                              color: const Color(
                                                                  0xFF2C72E0),
                                                              bg: const Color(
                                                                  0xFFE8F0FC),
                                                                  onTap: () {
                                                                    //  final ownerDetails = Provider.of<OwnerDetailsProvider>(context).OwnerDetails;
                                                                    //for edit pur
                                                                    Navigator.push(
                                                                        context,
                                                                        MaterialPageRoute(
                                                                            builder: (context) => EditRentalowners(
                                                                                  rentalId: widget.rentalId,
                                                                                  pro_id: processor_id!,
                                                                                )));
                                                                    // Navigator.push(context, MaterialPageRoute(builder: (context)=>AddRentalowners(OwnersDetails: Ownersdetails,isEdit: true,)));
                                                                    //   }
                                                                  },
                                                            ),
                                                            const SizedBox(
                                                                width: 8),
                                                            _pfIconButton(
                                                              icon: Icons
                                                                  .delete_outline,
                                                              color: redClr,
                                                              bg: const Color(
                                                                  0xFFFBE9E7),
                                                                  onTap: () {
                                                                    provider
                                                                        .clearOwners();

                                                                    setState(
                                                                        () {
                                                                      RentalOwner?
                                                                          owner;
                                                                      Ownersdetails =
                                                                          owner;
                                                                    });
                                                                  },
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      )
                                    : const Text('');
                              },
                            ),
                    const SizedBox(height: 20),
                    Container(
                      height: 1,
                      color: const Color(0xFFEAEEF4),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      "Who will be the primary manager of this property?",
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: navyClr),
                    ),
                                        //  fontWeight: FontWeight.bold,
                    const SizedBox(height: 6),
                    const Text(
                                    "If staff member has not yet been added as user in your account ,they can be added to the account"
                                    ",than as the manager later through the property's summary details.",
                      style: TextStyle(fontSize: 14, color: mutedClr),
                    ),
                                        //  fontWeight: FontWeight.bold,
                    const SizedBox(height: 16),
                    _pfFieldLabel("Manager (Optional)"),
                                FutureBuilder<List<Staffmembers>>(
                                  future: futureStaffMembers,
                                  builder: (context, snapshot) {
                                    if (snapshot.connectionState ==
                                        ConnectionState.waiting) {
                                      return const Center(
                                          child: SpinKitFadingCircle(
                                        color: Colors.black,
                                        size: 40.0,
                                      ));
                                    } else if (snapshot.hasError) {
                                      return Text(friendlyErrorMessage(snapshot.error), textAlign: TextAlign.center);
                                    } else if (!snapshot.hasData ||
                                        snapshot.data!.isEmpty) {
                                      return const Text(
                                          'No staff members found');
                                    } else {
                                      List<Staffmembers> staffMembers =
                                          snapshot.data!;

                                      // Sort staff members alphabetically by name (A-Z)
                                      staffMembers.sort((a, b) =>
                                          (a.staffmemberName ?? '')
                                              .toLowerCase()
                                              .compareTo(
                                                  (b.staffmemberName ?? '')
                                                      .toLowerCase()));

                                      List<DropdownMenuItem<String>>
                                          dropdownItems = staffMembers
                                              .map<DropdownMenuItem<String>>(
                                                  (Staffmembers staffMember) {
                                        return DropdownMenuItem<String>(
                                          value: staffMember.staffmemberId,
                                          onTap: () {
                                            setState(() {
                                              sid = staffMember.staffmemberId;
                                            });
                                          },
                                          child: Text(
                                            staffMember.staffmemberName ?? '',
                                            style:
                                                const TextStyle(fontSize: 14),
                                          ),
                                        );
                                      }).toList();
                                      // Add the special "Add new property" item
                                      dropdownItems.add(
                                        DropdownMenuItem<String>(
                                          value: 'Edit_properties',
                                          child: GestureDetector(
                                            onTap: () {
                                              name.clear();
                                              designation.clear();
                                              phonenumber.clear();
                                              email.clear();
                                              password.clear();
                                              nameerror = false;
                                              designationerror = false;
                                              phonenumbererror = false;
                                              emailerror = false;
                                              passworderror = false;
                                              Navigator.of(context).pop();
                                              showDialog(
                                                context: context,
                                                builder:
                                                    (BuildContext context) {
                                                  bool isChecked =
                                                      false; // Moved isChecked inside the StatefulBuilder
                                                  return StatefulBuilder(
                                                    builder: (BuildContext
                                                            context,
                                                        StateSetter setState) {
                                                      return Dialog(
                                                        backgroundColor:
                                                            Colors.white,
                                                        surfaceTintColor:
                                                            Colors.white,
                                                        child: Padding(
                                                          padding:
                                                              const EdgeInsets
                                                                  .only(
                                                                  left: 10,
                                                                  right: 5,
                                                                  bottom: 20,
                                                                  top: 10),
                                                          child:
                                                              SingleChildScrollView(
                                                            child: Column(
                                                              children: [
                                                                Row(
                                                                  children: [
                                                                    const Spacer(),
                                                                    InkWell(
                                                                      onTap:
                                                                          () {
                                                                        Navigator.pop(
                                                                            context);
                                                                      },
                                                                      child:
                                                                          Container(
                                                                        //    color: Colors.redAccent,
                                                                        padding:
                                                                            EdgeInsets.zero,
                                                                        child:
                                                                            const FaIcon(
                                                                          FontAwesomeIcons
                                                                              .xmark,
                                                                          size:
                                                                              20,
                                                                          color:
                                                                              Color(0xFF8A95A8),
                                                                        ),
                                                                      ),
                                                                    ),
                                                                    const SizedBox(
                                                                      width: 5,
                                                                    ),
                                                                  ],
                                                                ),
                                                                Row(
                                                                  children: [
                                                                    const SizedBox(
                                                                      width: 15,
                                                                    ),
                                                                    Text(
                                                                      "New Staff Member",
                                                                      style: TextStyle(
                                                                          color:
                                                                              blueColor,
                                                                          fontWeight: FontWeight
                                                                              .bold,
                                                                          fontSize:
                                                                              18),
                                                                    ),
                                                                  ],
                                                                ),
                                                                const SizedBox(
                                                                  height: 10,
                                                                ),
                                                                const Row(
                                                                  children: [
                                                                    SizedBox(
                                                                      width: 15,
                                                                    ),
                                                                    Text(
                                                                      "Staff member name..*",
                                                                      style: TextStyle(
                                                                          color: Color(
                                                                              0xFF8A95A8),
                                                                          fontWeight: FontWeight
                                                                              .bold,
                                                                          fontSize:
                                                                              13),
                                                                    ),
                                                                  ],
                                                                ),
                                                                const SizedBox(
                                                                  height: 5,
                                                                ),
                                                                Row(
                                                                  children: [
                                                                    const SizedBox(
                                                                        width:
                                                                            15),
                                                                    Material(
                                                                      elevation:
                                                                          4,
                                                                      child:
                                                                          Container(
                                                                        height:
                                                                            50,
                                                                        width: MediaQuery.of(context).size.width *
                                                                            .63,
                                                                        decoration:
                                                                            BoxDecoration(
                                                                          borderRadius:
                                                                              BorderRadius.circular(2),
                                                                          border:
                                                                              Border.all(
                                                                            color:
                                                                                const Color(0xFF8A95A8),
                                                                          ),
                                                                        ),
                                                                        child:
                                                                            Stack(
                                                                          children: [
                                                                            Positioned.fill(
                                                                              child: TextField(
                                                                                onChanged: (value) {
                                                                                  setState(() {
                                                                                    nameerror = false;
                                                                                  });
                                                                                },
                                                                                controller: name,
                                                                                cursorColor: blueColor,
                                                                                decoration: InputDecoration(
                                                                                  hintText: "Enter a staff member name here..*",
                                                                                  hintStyle: const TextStyle(
                                                                                    fontSize: 13,
                                                                                    color: Color(0xFF8A95A8),
                                                                                  ),
                                                                                  enabledBorder: nameerror
                                                                                      ? OutlineInputBorder(
                                                                                          borderRadius: BorderRadius.circular(2),
                                                                                          borderSide: const BorderSide(
                                                                                            color: Colors.red,
                                                                                          ),
                                                                                        )
                                                                                      : InputBorder.none,
                                                                                  border: InputBorder.none,
                                                                                  contentPadding: const EdgeInsets.all(12),
                                                                                ),
                                                                              ),
                                                                            ),
                                                                          ],
                                                                        ),
                                                                      ),
                                                                    ),
                                                                    const SizedBox(
                                                                        width:
                                                                            20),
                                                                  ],
                                                                ),
                                                                nameerror
                                                                    ? Row(
                                                                        children: [
                                                                          const SizedBox(
                                                                            width:
                                                                                12,
                                                                          ),
                                                                          Expanded(
                                                                            child:
                                                                                Text(
                                                                              namemessage,
                                                                              style: const TextStyle(color: Colors.red, fontSize: 14),
                                                                            ),
                                                                          ),
                                                                          const SizedBox(
                                                                            width:
                                                                                20,
                                                                          ),
                                                                        ],
                                                                      )
                                                                    : Container(),
                                                                const SizedBox(
                                                                  height: 10,
                                                                ),
                                                                const Row(
                                                                  children: [
                                                                    SizedBox(
                                                                      width: 15,
                                                                    ),
                                                                    Text(
                                                                      "Designation...*",
                                                                      style: TextStyle(
                                                                          // color: Colors.grey,
                                                                          color: Color(0xFF8A95A8),
                                                                          fontWeight: FontWeight.bold,
                                                                          fontSize: 13),
                                                                    ),
                                                                  ],
                                                                ),
                                                                const SizedBox(
                                                                  height: 5,
                                                                ),
                                                                Row(
                                                                  children: [
                                                                    const SizedBox(
                                                                        width:
                                                                            15),
                                                                    Material(
                                                                      elevation:
                                                                          4,
                                                                      child:
                                                                          Container(
                                                                        height:
                                                                            50,
                                                                        width: MediaQuery.of(context).size.width *
                                                                            .63,
                                                                        decoration:
                                                                            BoxDecoration(
                                                                          borderRadius:
                                                                              BorderRadius.circular(2),
                                                                          border:
                                                                              Border.all(
                                                                            color:
                                                                                const Color(0xFF8A95A8),
                                                                          ),
                                                                        ),
                                                                        child:
                                                                            Stack(
                                                                          children: [
                                                                            Positioned.fill(
                                                                              child: TextField(
                                                                                onChanged: (value) {
                                                                                  setState(() {
                                                                                    designationerror = false;
                                                                                  });
                                                                                },
                                                                                controller: designation,
                                                                                cursorColor: blueColor,
                                                                                decoration: InputDecoration(
                                                                                  hintText: "Enter Designation here..*",
                                                                                  hintStyle: const TextStyle(
                                                                                    fontSize: 13,
                                                                                    color: Color(0xFF8A95A8),
                                                                                  ),
                                                                                  enabledBorder: designationerror
                                                                                      ? OutlineInputBorder(
                                                                                          borderRadius: BorderRadius.circular(2),
                                                                                          borderSide: const BorderSide(
                                                                                            color: Colors.red,
                                                                                          ),
                                                                                        )
                                                                                      : InputBorder.none,
                                                                                  border: InputBorder.none,
                                                                                  contentPadding: const EdgeInsets.all(12),
                                                                                ),
                                                                              ),
                                                                            ),
                                                                          ],
                                                                        ),
                                                                      ),
                                                                    ),
                                                                    const SizedBox(
                                                                        width:
                                                                            20),
                                                                  ],
                                                                ),
                                                                designationerror
                                                                    ? Row(
                                                                        children: [
                                                                          const SizedBox(
                                                                            width:
                                                                                12,
                                                                          ),
                                                                          Expanded(
                                                                            child:
                                                                                Text(
                                                                              designationmessage,
                                                                              style: const TextStyle(color: Colors.red, fontSize: 14),
                                                                            ),
                                                                          ),
                                                                          const SizedBox(
                                                                            width:
                                                                                20,
                                                                          ),
                                                                        ],
                                                                      )
                                                                    : Container(),
                                                                const SizedBox(
                                                                  height: 10,
                                                                ),
                                                                const Row(
                                                                  children: [
                                                                    SizedBox(
                                                                      width: 15,
                                                                    ),
                                                                    Text(
                                                                      "Phone Number...",
                                                                      style: TextStyle(
                                                                          // color: Colors.grey,
                                                                          color: Color(0xFF8A95A8),
                                                                          fontWeight: FontWeight.bold,
                                                                          fontSize: 13),
                                                                    ),
                                                                  ],
                                                                ),
                                                                const SizedBox(
                                                                  height: 5,
                                                                ),
                                                                Row(
                                                                  children: [
                                                                    const SizedBox(
                                                                        width:
                                                                            15),
                                                                    Material(
                                                                      elevation:
                                                                          4,
                                                                      child:
                                                                          Container(
                                                                        height:
                                                                            50,
                                                                        width: MediaQuery.of(context).size.width *
                                                                            .63,
                                                                        decoration:
                                                                            BoxDecoration(
                                                                          borderRadius:
                                                                              BorderRadius.circular(2),
                                                                          border:
                                                                              Border.all(
                                                                            color:
                                                                                const Color(0xFF8A95A8),
                                                                          ),
                                                                        ),
                                                                        child:
                                                                            Stack(
                                                                          children: [
                                                                            Positioned.fill(
                                                                              child: TextField(
                                                                                onChanged: (value) {
                                                                                  setState(() {
                                                                                    phonenumbererror = false;
                                                                                  });
                                                                                },
                                                                                controller: phonenumber,
                                                                                inputFormatters: [
                                                                                  FilteringTextInputFormatter.digitsOnly,
                                                                                  LengthLimitingTextInputFormatter(10),
                                                                                  PhoneNumberFormatter(),
                                                                                ],
                                                                                keyboardType: TextInputType.number,
                                                                                cursorColor: blueColor,
                                                                                decoration: InputDecoration(
                                                                                  hintText: "Enter Phone Number here..*",
                                                                                  hintStyle: const TextStyle(
                                                                                    fontSize: 13,
                                                                                    color: Color(0xFF8A95A8),
                                                                                  ),
                                                                                  enabledBorder: phonenumbererror
                                                                                      ? OutlineInputBorder(
                                                                                          borderRadius: BorderRadius.circular(2),
                                                                                          borderSide: const BorderSide(
                                                                                            color: Colors.red,
                                                                                          ),
                                                                                        )
                                                                                      : InputBorder.none,
                                                                                  border: InputBorder.none,
                                                                                  contentPadding: const EdgeInsets.all(12),
                                                                                ),
                                                                              ),
                                                                            ),
                                                                          ],
                                                                        ),
                                                                      ),
                                                                    ),
                                                                    const SizedBox(
                                                                        width:
                                                                            20),
                                                                  ],
                                                                ),
                                                                phonenumbererror
                                                                    ? Row(
                                                                        children: [
                                                                          const SizedBox(
                                                                            width:
                                                                                12,
                                                                          ),
                                                                          Expanded(
                                                                            child:
                                                                                Text(
                                                                              phonenumbermessage,
                                                                              style: const TextStyle(color: Colors.red, fontSize: 14),
                                                                            ),
                                                                          ),
                                                                          const SizedBox(
                                                                            width:
                                                                                20,
                                                                          ),
                                                                        ],
                                                                      )
                                                                    : Container(),
                                                                const SizedBox(
                                                                  height: 10,
                                                                ),
                                                                const Row(
                                                                  children: [
                                                                    SizedBox(
                                                                      width: 15,
                                                                    ),
                                                                    Text(
                                                                      "Email...*",
                                                                      style: TextStyle(
                                                                          // color: Colors.grey,
                                                                          color: Color(0xFF8A95A8),
                                                                          fontWeight: FontWeight.bold,
                                                                          fontSize: 13),
                                                                    ),
                                                                  ],
                                                                ),
                                                                const SizedBox(
                                                                  height: 5,
                                                                ),
                                                                Row(
                                                                  children: [
                                                                    const SizedBox(
                                                                        width:
                                                                            15),
                                                                    Material(
                                                                      elevation:
                                                                          4,
                                                                      child:
                                                                          Container(
                                                                        height:
                                                                            50,
                                                                        width: MediaQuery.of(context).size.width *
                                                                            .63,
                                                                        decoration:
                                                                            BoxDecoration(
                                                                          borderRadius:
                                                                              BorderRadius.circular(2),
                                                                          border:
                                                                              Border.all(
                                                                            color:
                                                                                const Color(0xFF8A95A8),
                                                                          ),
                                                                        ),
                                                                        child:
                                                                            Stack(
                                                                          children: [
                                                                            Positioned.fill(
                                                                              child: TextField(
                                                                                onChanged: (value) {
                                                                                  setState(() {
                                                                                    emailerror = false;
                                                                                  });
                                                                                },
                                                                                controller: email,
                                                                                cursorColor: blueColor,
                                                                                decoration: InputDecoration(
                                                                                  hintText: "Enter Email here..*",
                                                                                  hintStyle: const TextStyle(
                                                                                    fontSize: 13,
                                                                                    color: Color(0xFF8A95A8),
                                                                                  ),
                                                                                  enabledBorder: emailerror
                                                                                      ? OutlineInputBorder(
                                                                                          borderRadius: BorderRadius.circular(2),
                                                                                          borderSide: const BorderSide(
                                                                                            color: Colors.red,
                                                                                          ),
                                                                                        )
                                                                                      : InputBorder.none,
                                                                                  border: InputBorder.none,
                                                                                  contentPadding: const EdgeInsets.all(12),
                                                                                ),
                                                                              ),
                                                                            ),
                                                                          ],
                                                                        ),
                                                                      ),
                                                                    ),
                                                                    const SizedBox(
                                                                        width:
                                                                            20),
                                                                  ],
                                                                ),
                                                                emailerror
                                                                    ? Row(
                                                                        children: [
                                                                          const SizedBox(
                                                                            width:
                                                                                12,
                                                                          ),
                                                                          Expanded(
                                                                            child:
                                                                                Text(
                                                                              emailmessage,
                                                                              style: const TextStyle(color: Colors.red, fontSize: 14),
                                                                            ),
                                                                          ),
                                                                          const SizedBox(
                                                                            width:
                                                                                20,
                                                                          ),
                                                                        ],
                                                                      )
                                                                    : Container(),
                                                                const SizedBox(
                                                                  height: 10,
                                                                ),
                                                                const Row(
                                                                  children: [
                                                                    SizedBox(
                                                                      width: 15,
                                                                    ),
                                                                    Text(
                                                                      "Password...*",
                                                                      style: TextStyle(
                                                                          // color: Colors.grey,
                                                                          color: Color(0xFF8A95A8),
                                                                          fontWeight: FontWeight.bold,
                                                                          fontSize: 13),
                                                                    ),
                                                                  ],
                                                                ),
                                                                const SizedBox(
                                                                  height: 5,
                                                                ),
                                                                Row(
                                                                  children: [
                                                                    const SizedBox(
                                                                        width:
                                                                            15),
                                                                    Material(
                                                                      elevation:
                                                                          4,
                                                                      child:
                                                                          Container(
                                                                        height:
                                                                            50,
                                                                        width: MediaQuery.of(context).size.width *
                                                                            .63,
                                                                        decoration:
                                                                            BoxDecoration(
                                                                          borderRadius:
                                                                              BorderRadius.circular(2),
                                                                          border:
                                                                              Border.all(
                                                                            color:
                                                                                const Color(0xFF8A95A8),
                                                                          ),
                                                                        ),
                                                                        child:
                                                                            Stack(
                                                                          children: [
                                                                            Positioned.fill(
                                                                              child: TextField(
                                                                                onChanged: (value) {
                                                                                  setState(() {
                                                                                    passworderror = false;
                                                                                  });
                                                                                },
                                                                                controller: password,
                                                                                cursorColor: blueColor,
                                                                                decoration: InputDecoration(
                                                                                  hintText: "Enter Password here..*",
                                                                                  hintStyle: const TextStyle(
                                                                                    fontSize: 13,
                                                                                    color: Color(0xFF8A95A8),
                                                                                  ),
                                                                                  enabledBorder: passworderror
                                                                                      ? OutlineInputBorder(
                                                                                          borderRadius: BorderRadius.circular(2),
                                                                                          borderSide: const BorderSide(
                                                                                            color: Colors.red,
                                                                                          ),
                                                                                        )
                                                                                      : InputBorder.none,
                                                                                  border: InputBorder.none,
                                                                                  contentPadding: const EdgeInsets.all(12),
                                                                                ),
                                                                              ),
                                                                            ),
                                                                          ],
                                                                        ),
                                                                      ),
                                                                    ),
                                                                    const SizedBox(
                                                                        width:
                                                                            20),
                                                                  ],
                                                                ),
                                                                passworderror
                                                                    ? Row(
                                                                        children: [
                                                                          const SizedBox(
                                                                            width:
                                                                                12,
                                                                          ),
                                                                          Expanded(
                                                                            child:
                                                                                Text(
                                                                              passwordmessage,
                                                                              style: const TextStyle(color: Colors.red, fontSize: 14),
                                                                            ),
                                                                          ),
                                                                          const SizedBox(
                                                                            width:
                                                                                20,
                                                                          ),
                                                                        ],
                                                                      )
                                                                    : Container(),
                                                                const SizedBox(
                                                                  height: 20,
                                                                ),
                                                                Row(
                                                                  children: [
                                                                    if (MediaQuery.of(context)
                                                                            .size
                                                                            .width >
                                                                        500)
                                                                      SizedBox(
                                                                        width: MediaQuery.of(context).size.width *
                                                                            0.013,
                                                                      ),
                                                                    if (MediaQuery.of(context)
                                                                            .size
                                                                            .width <
                                                                        500)
                                                                      SizedBox(
                                                                        width: MediaQuery.of(context).size.width *
                                                                            0.035,
                                                                      ),
                                                                    //                                                                   GestureDetector(
                                                                    //                                                                     onTap:
                                                                    //                                                                         () async {
                                                                    //                                                                       if (name
                                                                    //                                                                           .text
                                                                    //                                                                           .isEmpty) {
                                                                    //                                                                         setState(
                                                                    //                                                                             () {
                                                                    //                                                                           nameerror =
                                                                    //                                                                               true;
                                                                    //                                                                           namemessage =
                                                                    //                                                                               "required";
                                                                    //                                                                         });
                                                                    //                                                                       } else {
                                                                    //                                                                         setState(
                                                                    //                                                                             () {
                                                                    //                                                                           nameerror =
                                                                    //                                                                               false;
                                                                    //                                                                         });
                                                                    //                                                                       }
                                                                    //                                                                       if (designation
                                                                    //                                                                           .text
                                                                    //                                                                           .isEmpty) {
                                                                    //                                                                         setState(
                                                                    //                                                                             () {
                                                                    //                                                                           designationerror =
                                                                    //                                                                               true;
                                                                    //                                                                           designationmessage =
                                                                    //                                                                               "required";
                                                                    //                                                                         });
                                                                    //                                                                       } else {
                                                                    //                                                                         setState(
                                                                    //                                                                             () {
                                                                    //                                                                           designationerror =
                                                                    //                                                                               false;
                                                                    //                                                                         });
                                                                    //                                                                       }
                                                                    //                                                                       if (phonenumber
                                                                    //                                                                           .text
                                                                    //                                                                           .isEmpty) {
                                                                    //                                                                         setState(
                                                                    //                                                                             () {
                                                                    //                                                                           phonenumbererror =
                                                                    //                                                                               true;
                                                                    //                                                                           phonenumbermessage =
                                                                    //                                                                               "required";
                                                                    //                                                                         });
                                                                    //                                                                       } else {
                                                                    //                                                                         setState(
                                                                    //                                                                             () {
                                                                    //                                                                           phonenumbererror =
                                                                    //                                                                               false;
                                                                    //                                                                         });
                                                                    //                                                                       }
                                                                    //                                                                       if (email
                                                                    //                                                                           .text
                                                                    //                                                                           .isEmpty) {
                                                                    //                                                                         setState(
                                                                    //                                                                             () {
                                                                    //                                                                           emailerror =
                                                                    //                                                                               true;
                                                                    //                                                                           emailmessage =
                                                                    //                                                                               "required";
                                                                    //                                                                         });
                                                                    //                                                                       } else {
                                                                    //                                                                         setState(
                                                                    //                                                                             () {
                                                                    //                                                                           emailerror =
                                                                    //                                                                               false;
                                                                    //                                                                         });
                                                                    //                                                                       }
                                                                    //                                                                       if (password
                                                                    //                                                                           .text
                                                                    //                                                                           .isEmpty) {
                                                                    //                                                                         setState(
                                                                    //                                                                             () {
                                                                    //                                                                           passworderror =
                                                                    //                                                                               true;
                                                                    //                                                                           passwordmessage =
                                                                    //                                                                               "required";
                                                                    //                                                                         });
                                                                    //                                                                       } else {
                                                                    //                                                                         setState(
                                                                    //                                                                             () {
                                                                    //                                                                           passworderror =
                                                                    //                                                                               false;
                                                                    //                                                                         });
                                                                    //                                                                       }
                                                                    //                                                                       if (!nameerror &&
                                                                    //                                                                           !designationerror &&
                                                                    //                                                                           !phonenumbererror &&
                                                                    //                                                                           !emailerror &&
                                                                    //                                                                           !phonenumbererror) {
                                                                    //                                                                         setState(
                                                                    //                                                                             () {
                                                                    //                                                                           loading =
                                                                    //                                                                               true;
                                                                    //                                                                         });
                                                                    //                                                                       }
                                                                    //                                                                       SharedPreferences
                                                                    //                                                                           prefs =
                                                                    //                                                                           await SharedPreferences
                                                                    //                                                                               .getInstance();
                                                                    //                                                                       String?
                                                                    //                                                                           adminId =
                                                                    //                                                                           prefs.getString(
                                                                    //                                                                               "adminId");
                                                                    //                                                                       if (adminId !=
                                                                    //                                                                           null) {
                                                                    //                                                                         try {
                                                                    //                                                                           await StaffMemberRepository()
                                                                    //                                                                               .addStaffMember(
                                                                    //                                                                             adminId:
                                                                    //                                                                                 adminId,
                                                                    //                                                                             staffmemberName:
                                                                    //                                                                                 name.text,
                                                                    //                                                                             staffmemberDesignation:
                                                                    //                                                                                 designation.text,
                                                                    //                                                                             staffmemberPhoneNumber:
                                                                    //                                                                                 phonenumber.text,
                                                                    //                                                                             staffmemberEmail:
                                                                    //                                                                                 email.text,
                                                                    //                                                                             staffmemberPassword:
                                                                    //                                                                                 password.text,
                                                                    //                                                                           );
                                                                    //                                                                           setState(
                                                                    //                                                                               () {
                                                                    //                                                                             loading =
                                                                    //                                                                                 false;
                                                                    //                                                                           });
                                                                    //                                                                           Navigator.of(context)
                                                                    //                                                                               .pop(true);
                                                                    //                                                                         } catch (e) {
                                                                    //                                                                           setState(
                                                                    //                                                                               () {
                                                                    //                                                                             loading =
                                                                    //                                                                                 false;
                                                                    //                                                                           });
                                                                    //                                                                           // Handle error
                                                                    //                                                                         }
                                                                    //                                                                       }
                                                                    //                                                                     },
                                                                    //                                                                     child:
                                                                    //                                                                         ClipRRect(
                                                                    //                                                                       borderRadius:
                                                                    //                                                                           BorderRadius.circular(
                                                                    //                                                                               5.0),
                                                                    //                                                                       child:
                                                                    //                                                                           Container(
                                                                    //                                                                         height:
                                                                    //                                                                             30.0,
                                                                    //                                                                         width: MediaQuery.of(context).size.width *
                                                                    //                                                                             .36,
                                                                    //                                                                         decoration:
                                                                    //                                                                             BoxDecoration(
                                                                    //                                                                           borderRadius:
                                                                    //                                                                               BorderRadius.circular(5.0),
                                                                    //                                                                           color: blueColor
                                                                    //
                                                                    //
                                                                    // ,
                                                                    //                                                                           boxShadow: [
                                                                    //                                                                             BoxShadow(
                                                                    //                                                                               color: Colors.grey,
                                                                    //                                                                               offset: Offset(0.0, 1.0), //(x,y)
                                                                    //                                                                               blurRadius: 6.0,
                                                                    //                                                                             ),
                                                                    //                                                                           ],
                                                                    //                                                                         ),
                                                                    //                                                                         child:
                                                                    //                                                                             Center(
                                                                    //                                                                           child:
                                                                    //                                                                               Text(
                                                                    //                                                                             "Add staff Member",
                                                                    //                                                                             style: TextStyle(
                                                                    //                                                                                 color: Colors.white,
                                                                    //                                                                                 fontWeight: FontWeight.bold,
                                                                    //                                                                                 fontSize: MediaQuery.of(context).size.width < 500 ? 15 : 18),
                                                                    //                                                                           ),
                                                                    //                                                                         ),
                                                                    //                                                                       ),
                                                                    //                                                                     ),
                                                                    //                                                                   ),
                                                                    GestureDetector(
                                                                      onTap:
                                                                          () async {
                                                                        // Reset error states
                                                                        setState(
                                                                            () {
                                                                          nameerror =
                                                                              false;
                                                                          designationerror =
                                                                              false;
                                                                          phonenumbererror =
                                                                              false;
                                                                          emailerror =
                                                                              false;
                                                                          passworderror =
                                                                              false;
                                                                        });

                                                                        // Validate fields
                                                                        bool
                                                                            isValid =
                                                                            true;

                                                                        if (name
                                                                            .text
                                                                            .isEmpty) {
                                                                          setState(
                                                                              () {
                                                                            nameerror =
                                                                                true;
                                                                            namemessage =
                                                                                "required";
                                                                          });
                                                                          isValid =
                                                                              false;
                                                                        }

                                                                        if (designation
                                                                            .text
                                                                            .isEmpty) {
                                                                          setState(
                                                                              () {
                                                                            designationerror =
                                                                                true;
                                                                            designationmessage =
                                                                                "required";
                                                                          });
                                                                          isValid =
                                                                              false;
                                                                        }

                                                                        // Validate phone number
                                                                        String formattedPhoneNumber = phonenumber.text.replaceAll(
                                                                            RegExp(r'\D'),
                                                                            '');
                                                                        if (formattedPhoneNumber
                                                                            .isEmpty) {
                                                                          setState(
                                                                              () {
                                                                            phonenumbererror =
                                                                                true;
                                                                            phonenumbermessage =
                                                                                "required";
                                                                          });
                                                                          isValid =
                                                                              false;
                                                                        } else if (formattedPhoneNumber.length !=
                                                                            10) {
                                                                          setState(
                                                                              () {
                                                                            phonenumbererror =
                                                                                true;
                                                                            phonenumbermessage =
                                                                                "must be 10 digits";
                                                                          });
                                                                          isValid =
                                                                              false;
                                                                        } else {
                                                                          setState(
                                                                              () {
                                                                            phonenumbererror =
                                                                                false;
                                                                          });
                                                                        }

                                                                        // Validate email
                                                                        if (email
                                                                            .text
                                                                            .isEmpty) {
                                                                          setState(
                                                                              () {
                                                                            emailerror =
                                                                                true;
                                                                            emailmessage =
                                                                                "required";
                                                                          });
                                                                          isValid =
                                                                              false;
                                                                        } else if (!EmailValidator.validate(
                                                                            email.text)) {
                                                                          setState(
                                                                              () {
                                                                            emailerror =
                                                                                true;
                                                                            emailmessage =
                                                                                "Email is not valid";
                                                                          });
                                                                          isValid =
                                                                              false;
                                                                        } else {
                                                                          setState(
                                                                              () {
                                                                            emailerror =
                                                                                false;
                                                                          });
                                                                        }

                                                                        // Validate password
                                                                        if (password
                                                                            .text
                                                                            .isEmpty) {
                                                                          setState(
                                                                              () {
                                                                            passworderror =
                                                                                true;
                                                                            passwordmessage =
                                                                                "required";
                                                                          });
                                                                          isValid =
                                                                              false;
                                                                        } else if (password.text.length <
                                                                            8) {
                                                                          setState(
                                                                              () {
                                                                            passworderror =
                                                                                true;
                                                                            passwordmessage =
                                                                                "at least 8 characters";
                                                                          });
                                                                          isValid =
                                                                              false;
                                                                        } else {
                                                                          String?
                                                                              validationMessage =
                                                                              ValidatePassword(password.text);
                                                                          if (validationMessage !=
                                                                              null) {
                                                                            setState(() {
                                                                              passworderror = true;
                                                                              passwordmessage = validationMessage; // Use the dynamic message
                                                                            });
                                                                            isValid =
                                                                                false;
                                                                          } else {
                                                                            setState(() {
                                                                              passworderror = false; // No error
                                                                            });
                                                                          }
                                                                        }

                                                                        // If all fields are valid, proceed to add the staff member
                                                                        if (isValid) {
                                                                          setState(
                                                                              () {
                                                                            loading =
                                                                                true;
                                                                          });

                                                                          SharedPreferences
                                                                              prefs =
                                                                              await SharedPreferences.getInstance();
                                                                          String?
                                                                              adminId =
                                                                              prefs.getString("adminId");

                                                                          if (adminId !=
                                                                              null) {
                                                                            try {
                                                                              await StaffMemberRepository().addStaffMember(
                                                                                adminId: adminId,
                                                                                staffmemberName: name.text,
                                                                                staffmemberDesignation: designation.text,
                                                                                staffmemberPhoneNumber: phonenumber.text,
                                                                                staffmemberEmail: email.text,
                                                                                staffmemberPassword: password.text,
                                                                              );
                                                                              setState(() {
                                                                                loading = false;
                                                                              });
                                                                              Navigator.of(context).pop(true);
                                                                            } catch (e) {
                                                                              setState(() {
                                                                                loading = false;
                                                                              });
                                                                              // Handle error
                                                                            }
                                                                          }
                                                                        }
                                                                      },
                                                                      child:
                                                                          ClipRRect(
                                                                        borderRadius:
                                                                            BorderRadius.circular(5.0),
                                                                        child:
                                                                            Container(
                                                                          height:
                                                                              37.0,
                                                                          width:
                                                                              MediaQuery.of(context).size.width * .36,
                                                                          decoration:
                                                                              BoxDecoration(
                                                                            borderRadius:
                                                                                BorderRadius.circular(5.0),
                                                                            color:
                                                                                blueColor,
                                                                            boxShadow: [
                                                                              const BoxShadow(
                                                                                color: Colors.grey,
                                                                                offset: Offset(0.0, 1.0), //(x,y)
                                                                                blurRadius: 6.0,
                                                                              ),
                                                                            ],
                                                                          ),
                                                                          child:
                                                                              Center(
                                                                            child: loading
                                                                                ? const SpinKitFadingCircle(
                                                                                    color: Colors.white,
                                                                                    size: 25.0,
                                                                                  )
                                                                                : Text(
                                                                                    "Add Staff Member",
                                                                                    style: TextStyle(
                                                                                      color: Colors.white,
                                                                                      fontWeight: FontWeight.bold,
                                                                                      fontSize: MediaQuery.of(context).size.width < 500 ? 14 : 18,
                                                                                    ),
                                                                                  ),
                                                                          ),
                                                                        ),
                                                                      ),
                                                                    ),
                                                                    const SizedBox(
                                                                      width: 15,
                                                                    ),
                                                                    InkWell(
                                                                      onTap:
                                                                          () {
                                                                        Navigator.pop(
                                                                            context);
                                                                      },
                                                                      child: const Text(
                                                                          "Cancel"),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                      );
                                                    },
                                                  );
                                                },
                                              );
                                            },
                                            child: Row(
                                              children: [
                                                const Icon(
                                                  Icons.add,
                                                  size: 16,
                                                ),
                                                const SizedBox(width: 3),
                                                Text(
                                                  'Add New Staffmember',
                                                  style: TextStyle(
                                                      fontSize:
                                                          MediaQuery.of(context)
                                                                      .size
                                                                      .width <
                                                                  500
                                                              ? 12
                                                              : 14),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                      return Container(
                                          // height: MediaQuery.of(context)
                                          //     .size
                                          //     .height *
                                          //     .05,
                                          height: 50,
                                          width: double.infinity,
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            border: Border.all(
                                              color: outlineClr,
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: DropdownButtonHideUnderline(
                                            child: DropdownButton2<String>(
                                              value: selectedStaff,
                                              hint: const Text(
                                                'Select',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: _pfHintClr,
                                                ),
                                              ),
                                              onChanged: (String? newValue) {
                                                if (newValue ==
                                                    'Edit_properties') {
                                                  // Prevent the dropdown from changing the selected item
                                                  setState(() {
                                                    selectedStaff = null;
                                                  });
                                                  // Show the dialog
                                                  // showDialog(
                                                  //   context: context,
                                                  //   builder:
                                                  //       (BuildContext context) {
                                                  //     //  bool isChecked = false; // Moved isChecked inside the StatefulBuilder
                                                  //     return StatefulBuilder(
                                                  //       builder: (BuildContext
                                                  //       context,
                                                  //           StateSetter
                                                  //           setState) {
                                                  //         return AlertDialog(
                                                  //           backgroundColor:
                                                  //           Colors.white,
                                                  //           surfaceTintColor:
                                                  //           Colors.white,
                                                  //           title: Text(
                                                  //             "Add Rental Owner",
                                                  //             style: TextStyle(
                                                  //                 fontWeight:
                                                  //                 FontWeight
                                                  //                     .bold,
                                                  //                 color: Color
                                                  //                     .fromRGBO(
                                                  //                     21,
                                                  //                     43,
                                                  //                     81,
                                                  //                     1),
                                                  //                 fontSize: 15),
                                                  //           ),
                                                  //           content:
                                                  //           SingleChildScrollView(
                                                  //               child:
                                                  //               Column(
                                                  //                 children: [],
                                                  //               )),
                                                  //         );
                                                  //       },
                                                  //     );
                                                  //   },
                                                  // );
                                                } else {
                                                  setState(() {
                                                    selectedStaff = newValue;
                                                  });
                                                }
                                              },
                                              items: dropdownItems,
                                              isExpanded: true,
                                              buttonStyleData: ButtonStyleData(
                                                height: 48,
                                                padding:
                                                    const EdgeInsets.only(
                                                        left: 8,
                                                        right: 12),
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  color: Colors.transparent,
                                                ),
                                              ),
                                              iconStyleData:
                                                  const IconStyleData(
                                                icon: Icon(
                                                    Icons.keyboard_arrow_down,
                                                    color: navyClr),
                                                iconSize: 22,
                                              ),
                                              dropdownStyleData:
                                                  DropdownStyleData(
                                                maxHeight: 300,
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                  color: Colors.white,
                                                ),
                                                offset: const Offset(0, -5),
                                                scrollbarTheme:
                                                    ScrollbarThemeData(
                                                  radius:
                                                      const Radius.circular(40),
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
                                                padding: EdgeInsets.symmetric(
                                                    horizontal: 16,
                                                    vertical: 8),
                                              ),
                                            ),
                                          ),
                                      );
                                    }
                                  },
                                ),
                  ],
                ),
                const SizedBox(height: 16),
                // Insured Value Information
                _pfSectionCard(
                  title: "Insured Value Information",
                  children: [
                          _pfFieldLabel("Date Placed in Service",
                              required: true),
                                    TextField(
                                      controller: datePlacedInService,
                                      readOnly: true,
                                      style: const TextStyle(
                                        color: navyClr,
                                        fontSize: 14,
                                      ),
                                      cursorColor: blueColor,
                                      decoration: _pfInputDecoration(
                                        hint: "MM/DD/YYYY",
                                        error: datePlacedInServiceError,
                                        suffixIcon: GestureDetector(
                                        onTap: _selectDatePlacedInService,
                                          child: const Icon(
                                            Icons.calendar_today_outlined,
                                            color: navyClr,
                                            size: 18,
                                          ),
                                        ),
                                      ),
                                    ),
                          if (datePlacedInServiceError)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                datePlacedInServiceMessage,
                                style: const TextStyle(color: Colors.red),
                              ),
                            ),
                          const SizedBox(height: 20),
                          const Text(
                            "Historical Insured Values",
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: navyClr,
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (historicalInsuredValues.isNotEmpty)
                            ...historicalInsuredValues
                                .asMap()
                                .entries
                                .map((entry) {
                              int index = entry.key;
                              HistoricalInsuredValue item = entry.value;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                        children: [
                                          _pfFieldLabel("Year",
                                              required: true),
                                          Container(
                                            height: 50,
                                            decoration: BoxDecoration(
                                              borderRadius:
                                              BorderRadius.circular(12),
                                              color: Colors.white,
                                              border: Border.all(
                                                color: item.yearError
                                                    ? Colors.red
                                                    : outlineClr,
                                              ),
                                            ),
                                            child: DropdownButtonHideUnderline(
                                              child: DropdownButton2<String>(
                                                value: item.year,
                                                hint: const Text(
                                                  'Select Year',
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    color: _pfHintClr,
                                                  ),
                                                ),
                                                onChanged: (String? newValue) {
                                                  setState(() {
                                                    item.year = newValue;
                                                    item.yearError = false;
                                                  });
                                                },
                                                items: _generateYearList()
                                                    .map((String year) {
                                                  return DropdownMenuItem<
                                                      String>(
                                                    value: year,
                                                    child: Text(
                                                      year,
                                                      style: const TextStyle(
                                                        fontSize: 14,
                                                        color: navyClr,
                                                      ),
                                                    ),
                                                  );
                                                }).toList(),
                                                isExpanded: true,
                                                buttonStyleData:
                                                ButtonStyleData(
                                                  height: 48,
                                                  padding: const EdgeInsets
                                                      .only(
                                                      left: 8,
                                                      right: 8),
                                                  decoration: BoxDecoration(
                                                    borderRadius:
                                                    BorderRadius.circular(
                                                        12),
                                                    color: Colors.transparent,
                                                  ),
                                                ),
                                                iconStyleData:
                                                    const IconStyleData(
                                                  icon: Icon(
                                                      Icons.keyboard_arrow_down,
                                                      color: navyClr),
                                                  iconSize: 22,
                                                ),
                                                dropdownStyleData:
                                                DropdownStyleData(
                                                  maxHeight: 300,
                                                  decoration: BoxDecoration(
                                                    borderRadius:
                                                    BorderRadius.circular(
                                                        10),
                                                    color: Colors.white,
                                                  ),
                                                ),
                                                menuItemStyleData:
                                                const MenuItemStyleData(
                                                  height: 40,
                                                  padding: EdgeInsets.symmetric(
                                                      horizontal: 16,
                                                      vertical: 8),
                                                ),
                                              ),
                                            ),
                                          ),
                                          if (item.yearError)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                  top: 5, left: 2),
                                              child: Text(
                                                "Required",
                                                style: TextStyle(
                                                  color: Colors.red,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                        children: [
                                          _pfFieldLabel("Insured Value (\$)",
                                              required: true),
                                              TextField(
                                                key: ValueKey('value_$index'),
                                                controller:
                                                item.valueController,
                                                keyboardType: TextInputType
                                                    .numberWithOptions(
                                                    decimal: true),
                                                style: const TextStyle(
                                                  color: navyClr,
                                                  fontSize: 14,
                                                ),
                                                onChanged: (value) {
                                                  setState(() {
                                                    item.valueError = false;
                                                  });
                                                },
                                                cursorColor: blueColor,
                                                decoration: _pfInputDecoration(
                                                  hint: "Enter value..",
                                                  error: item.valueError,
                                                ),
                                              ),
                                          if (item.valueError)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                  top: 5, left: 2),
                                              child: Text(
                                                "Required",
                                                style: TextStyle(
                                                  color: Colors.red,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Padding(
                                      padding: const EdgeInsets.only(top: 36),
                                      child: _pfIconButton(
                                        icon: Icons.delete_outline,
                                        color: redClr,
                                        bg: const Color(0xFFFBE9E7),
                                        onTap: () =>
                                            removeHistoricalInsuredValue(index),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          const SizedBox(height: 4),
                          _pfAddLinkButton(
                            label: "Add Historical Insured Value",
                              onTap: addHistoricalInsuredValue,
                          ),
                  ],
                ),
                const SizedBox(
                  height: 16,
                ),
                if (selectedpropertytypedata != null &&
                    selectedpropertytypedata!.propertyType == "Residential")
                  _pfSectionCard(
                    title: 'Residential Unit',
                    subtitle: 'Enter Residential Units',
                    trailing: selectedpropertytypedata?.isMultiunit == true
                        ? _pfAddLinkButton(
                            label: "Add Another Unit",
                                        // borderRadius: BorderRadius.circular(3),
                                        // boxShadow: [
                                        //   BoxShadow(
                                        //     color: Colors.grey,
                                        //     offset: Offset(0.0, 1.0), //(x,y)
                                        //     blurRadius: 6.0,
                                        //   ),
                                        // ],
                                              // fontWeight: FontWeight.bold,
                                onTap: () {
                                  // if (selectedProperty != null) {
                                  //   addPropertyGroup();
                                  // }
                                  addPropertyGroup();
                                },
                          )
                        : null,
                    children: [
                            if (propertyGroups.isNotEmpty)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SingleChildScrollView(
                                    child: Column(
                                      children: propertyGroups.map((group) {
                                        int index =
                                            propertyGroups.indexOf(group);
                                        return Padding(
                                          padding: const EdgeInsets.only(
                                              bottom: 12),
                                          child: _pfUnitSubCard(
                                            children: [
                                              // Align(
                                              //   alignment:
                                              //       Alignment.centerRight,
                                              //   child: InkWell(
                                              //     onTap: () =>
                                              //         removePropertyGroup(
                                              //             index),
                                              //     child: Icon(Icons.close,
                                              //         color: Colors.black),
                                              //   ),
                                              // ),
                                              Row(
                                                children: [
                                                  if (selectedpropertytypedata
                                                          ?.isMultiunit ==
                                                      true)
                                                    Expanded(
                                                      child: Text(
                                                        'Residential ${index + 1}',
                                                        style: const TextStyle(
                                                          fontSize: 16,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: navyClr,
                                                        ),
                                                      ),
                                                    )
                                                  else
                                                    const Spacer(),
                                                  Visibility(
                                                  visible:
                                                      !(selectedpropertytype ==
                                                              'Residential' &&
                                                          data.length == 1 &&
                                                          index == 0),
                                                    child: _pfIconButton(
                                                      icon:
                                                          Icons.delete_outline,
                                                      color: redClr,
                                                      bg: const Color(
                                                          0xFFFBE9E7),
                                                    onTap: () =>
                                                        removePropertyGroup(
                                                            index),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              if (selectedpropertytypedata
                                                      ?.isMultiunit ==
                                                  true)
                                                const SizedBox(height: 12),
                                              ...group,
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ],
                              ),
                    ],
                  ),
                if (selectedpropertytypedata != null &&
                    selectedpropertytypedata!.propertyType == "Commercial")
                  _pfSectionCard(
                    title: 'Commercial Unit',
                    subtitle: 'Enter Commercial Units',
                    trailing: selectedpropertytypedata?.isMultiunit == true
                        ? _pfAddLinkButton(
                            label: "Add Another Unit",
                                          // borderRadius: BorderRadius.circular(3),
                                          // boxShadow: [
                                          //   BoxShadow(
                                          //     color: Colors.grey,
                                          //     offset: Offset(0.0, 1.0), //(x,y)
                                          //     blurRadius: 6.0,
                                          //   ),
                                          // ],
                                  onTap: () {
                                    addPropertyGroup();
                                  },
                          )
                        : null,
                    children: [
                              if (propertyGroups.isNotEmpty)
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SingleChildScrollView(
                                      child: Column(
                                        children: propertyGroups.map((group) {
                                          int index =
                                              propertyGroups.indexOf(group);
                                          return Padding(
                                            padding: const EdgeInsets.only(
                                                bottom: 12),
                                            child: _pfUnitSubCard(
                                              children: [
                                                // Align(
                                                //   alignment:
                                                //       Alignment.centerRight,
                                                //   child: InkWell(
                                                //     onTap: () =>
                                                //         removePropertyGroup(
                                                //             index),
                                                //     child: Icon(Icons.close,
                                                //         color: Colors.black),
                                                //   ),
                                                // ),
                                                Row(
                                                  children: [
                                                    if (selectedpropertytypedata
                                                            ?.isMultiunit ==
                                                        true)
                                                      Expanded(
                                                        child: Text(
                                                          'Commercial ${index + 1}',
                                                          style:
                                                              const TextStyle(
                                                            fontSize: 16,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color: navyClr,
                                                          ),
                                                        ),
                                                      )
                                                    else
                                                      const Spacer(),
                                                    Visibility(
                                                    visible:
                                                        !(selectedpropertytype ==
                                                                'Commercial' &&
                                                            data.length == 1 &&
                                                            index == 0),
                                                      child: _pfIconButton(
                                                        icon: Icons
                                                            .delete_outline,
                                                        color: redClr,
                                                        bg: const Color(
                                                            0xFFFBE9E7),
                                                      onTap: () =>
                                                          removePropertyGroup(
                                                              index),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                if (selectedpropertytypedata
                                                        ?.isMultiunit ==
                                                    true)
                                                  const SizedBox(height: 12),
                                                ...group,
                                              ],
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                  ],
                                ),
                    ],
                  ),
                if (iserror2)
                  const Text(
                    "required",
                    style: TextStyle(color: Colors.redAccent),
                  ),
                const SizedBox(height: 15),
                Row(
                  children: [
                    //SizedBox(width: MediaQuery.of(context).size.width * 0.01),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          // displayPropertyData();
                          Navigator.pop(context);
                        },
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white,
                          side: const BorderSide(color: outlineClr),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          "Cancel",
                          style: TextStyle(
                            color: mutedClr,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
//                       onTap: () async {
//                         if (address.text.isEmpty) {
//                           setState(() {
//                             addresserror = true;
//                             addressmessage = "required";
//                           });
//                         } else {
//                           setState(() {
//                             addresserror = false;
//                           });
//                         }
//                         if (city.text.isEmpty) {
//                           setState(() {
//                             cityerror = true;
//                             citymessage = "required";
//                           });
//                         } else {
//                           setState(() {
//                             cityerror = false;
//                           });
//                         }
//                         if (state.text.isEmpty) {
//                           setState(() {
//                             stateerror = true;
//                             statemessage = "required";
//                           });
//                         } else {
//                           setState(() {
//                             stateerror = false;
//                           });
//                         }
//                         if (country.text.isEmpty) {
//                           setState(() {
//                             countryerror = true;
//                             countrymessage = "required";
//                           });
//                         } else {
//                           setState(() {
//                             countryerror = false;
//                           });
//                         }
//                         if (postalcode.text.isEmpty) {
//                           setState(() {
//                             postalcodeerror = true;
//                             postalcodemessage = "required";
//                           });
//                         } else {
//                           setState(() {
//                             postalcodeerror = false;
//                           });
//                         }
//                         if (Ownersdetails == null) {
//                           setState(() {
//                             hasError = true;
//                             postalcodemessage = "required";
//                           });
//                         } else {
//                           setState(() {
//                             hasError = false;
//                           });
//                           // print(selectedpropertytypedata!.propertyId);
//                           print('hiii${widget.properties.propertyId}');
//                           print('staff${widget.properties.staffMemberId}');
//                           SharedPreferences prefs =
//                           await SharedPreferences.getInstance();
//                           String? id = prefs.getString("adminId");
//                           Rental rentals = Rental(
//                             rentalId: widget.rentalId,
//                             adminId: id,
//                             propertyId: widget.properties.propertyId,
//                             // propertyId: selectedpropertytypedata!.propertyId,
//                             address: address.text,
//                             city: city.text,
//                             state: state.text,
//                             country: country.text,
//                             postcode: postalcode.text,
//                             // staffMemberId: sid,
//                             staffMemberId: widget.properties.staffMemberId,
//                           );
//                           List<Unit> units = [];
//                           if (propertyGroupControllers.isNotEmpty) {
//                             List<TextEditingController> firstControllers =
//                             propertyGroupControllers[0];
//                             bool isFirstBlank = firstControllers
//                                 .every((controller) => controller.text.isEmpty);
//                             //1714547540497
//                             //1709188861753
//                             if (isFirstBlank) {
//                               propertyGroupControllers.removeAt(0);
//                             }
//                           }
//                           if (selectedpropertytype == 'Commercial' &&
//                               selectedIsMultiUnit == true) {
//                             for (int i = 0;
//                             i < propertyGroupControllers.length;
//                             i++) {
//                               if (units.length <= i) {
//                                 units.add(Unit());
//                               }
//                               List<TextEditingController> controllers =
//                               propertyGroupControllers[i];
//                               units[i].unit = controllers[0].text;
//                               units[i].address = controllers[1].text;
//                               units[i].sqft = controllers[2].text;
//                               units[i].Image = propertyGroupImagenames[i];
//                               //      units[i].bath = controllers[3].text;
//                               //     units[i].bed = controllers[4].text;
//
// //                                  units[i].unit = controllers[0].text;
//                             }
//                           } else if (selectedpropertytype == 'Residential' &&
//                               selectedIsMultiUnit == true) {
//                             for (int i = 0;
//                             i < propertyGroupControllers.length;
//                             i++) {
//                               if (units.length <= i) {
//                                 units.add(Unit());
//                               }
//                               List<TextEditingController> controllers =
//                               propertyGroupControllers[i];
//                               units[i].unit = controllers[0].text;
//                               units[i].address = controllers[1].text;
//                               units[i].sqft = controllers[2].text;
//                               units[i].bath = controllers[3].text;
//                               units[i].bed = controllers[4].text;
//                               units[i].Image = propertyGroupImagenames[i];
// //                                  units[i].unit = controllers[0].text;
//                             }
//                           } else if (selectedpropertytype == 'Residential') {
//                             for (int i = 0;
//                             i < propertyGroupControllers.length;
//                             i++) {
//                               if (units.length <= i) {
//                                 units.add(Unit());
//                               }
//                               List<TextEditingController> controllers =
//                               propertyGroupControllers[i];
//                               print(controllers.length);
//                               units[i].sqft = controllers[0].text;
//                               units[i].bath = controllers[1].text;
//                               units[i].bed = controllers[2].text;
//                               units[i].Image = propertyGroupImagenames[i];
// //                                  units[i].unit = controllers[0].text;
//                             }
//                           } else if (selectedpropertytype == 'Commercial') {
//                             for (int i = 0;
//                             i < propertyGroupControllers.length;
//                             i++) {
//                               if (units.length <= i) {
//                                 units.add(Unit());
//                               }
//                               List<TextEditingController> controllers =
//                               propertyGroupControllers[i];
//                               units[i].sqft = controllers[0].text;
//                               units[i].Image = propertyGroupImagenames[i];
//                               //units[i].address = controllers[1].text;
//                               //units[i].sqft = controllers[2].text;
// //                                  units[i].unit = controllers[0].text;
//                             }
//                           }
//                           RentalOwners owners = RentalOwners(
//                             adminId: id,
//                             firstName: firstname.text,
//                             companyName: comname.text,
//                             primaryEmail: primaryemail.text,
//                             phoneNumber: phonenum.text,
//                             city: city2.text,
//                             state: state2.text,
//                             country: county2.text,
//                             postalCode: code2.text,
//                           );
//                           RentalRequest rentalrequest = RentalRequest(
//                               rentalOwner: owners,
//                               rental: rentals,
//                               units: units);
//                           final updatedOwner = RentalOwner(
//                             rentalOwnerName: firstnameController.text,
//                             rentalOwnerCompanyName: comnameController.text,
//                             rentalOwnerPrimaryEmail: primaryemailController.text,
//                             rentalOwnerPhoneNumber: phonenumController.text,
//                             city: cityController.text,
//                             state: stateController.text,
//                             country: countyController.text,
//                             postalCode: codeController.text,
//                           );
//                           RentalOwner? ownerDetails = context.read<OwnerDetailsProvider>().ownerDetails;
//
//                           String processorId = context.read<OwnerDetailsProvider>().selectedprocessorlist ?? "";
//
//                           List<Map<String, String>> processorIds = ownerDetails!.processorList!.map((processor) {
//                             return {
//                               'processor_id': processor.processorId ?? "",
//                             };
//                           }).toList();
//
//                           //Provider.of<OwnerDetailsProvider>(context, listen: false).setOwnerDetails(updatedOwner);
//
//                           Rentals properties = Rentals(
//                               adminId: id,
//                               rentalOwnerData: RentalOwnerData(
//                                   adminId: widget.properties.adminId,
//                                   rentalOwnerId: widget.properties.rentalOwnerId,
//                                   rentalOwnerName: updatedOwner.rentalOwnerName,
//                                   rentalOwnerCompanyName: updatedOwner.rentalOwnerCompanyName,
//                                   rentalOwnerPrimaryEmail: updatedOwner.rentalOwnerPrimaryEmail,
//                                   rentalOwnerPhoneNumber: updatedOwner.rentalOwnerPhoneNumber,
//                                   city: updatedOwner.city,
//                                   state: updatedOwner.state,
//                                   country: updatedOwner.country,
//                                   postalCode: updatedOwner.postalCode,
//                                   processorList: processorIds
//                               ),
//                               rentalId: widget.rentalId,
//                               propertyId: widget.properties.propertyId,
//                               rentalAddress: address.text,
//                               rentalCity: city.text,
//                               rentalState: state.text,
//                               rentalCountry: country.text,
//                               rentalPostcode: postalcode.text,
//                               staffMemberId: sid,
//                               processor_id:processorId
//                           );
//                           PropertiesRepository()
//                               .updateRental1(properties)
//                               .then((value) {
//                             setState(() {
//                               widget.properties.rentalOwnerData = RentalOwnerData(
//                                 adminId: widget.properties.adminId,
//                                 rentalOwnerId: widget.properties.rentalOwnerId,
//                                 rentalOwnerName: updatedOwner.rentalOwnerName,
//                                 rentalOwnerCompanyName: updatedOwner.rentalOwnerCompanyName,
//                                 rentalOwnerPrimaryEmail: updatedOwner.rentalOwnerPrimaryEmail,
//                                 rentalOwnerPhoneNumber: updatedOwner.rentalOwnerPhoneNumber,
//                                 rentalOwnerAlternativeEmail: updatedOwner.rentalOwnerAlternateEmail,
//                                 rentalOwnerBuisinessNumber: updatedOwner.rentalOwnerBusinessNumber,
//                                 rentalOwnerHomeNumber: updatedOwner.rentalOwnerHomeNumber,
//                                 city: updatedOwner.city,
//                                 state: updatedOwner.state,
//                                 country: updatedOwner.country,
//                                 postalCode: updatedOwner.postalCode,
//                               );
//                               widget.properties.rentalAddress = address.text;
//                               widget.properties.propertyTypeData?.propertyType =
//                                   selectedpropertytype;
//                               widget.properties.propertyTypeData
//                                   ?.propertySubType = selectedpropertytype;
//                               isLoading = false;
//                             });
//                             Navigator.of(context).pop(true);
//                           }).catchError((e) {
//                             setState(() {
//                               isLoading = false;
//                             });
//                           });
//                         }
//                         print(selectedValue);
//                       },
                      onPressed: () async {
                        // A second tap while a save is running does nothing.
                        if (loading) return;
                        if (!_unitsLoaded) {
                          Fluttertoast.showToast(
                              msg:
                                  "Unit details haven't loaded yet. Please wait, or go back and reopen this property.");
                          return;
                        }

                        // Validate selected property
                        if (selectedProperty == null) {
                          setState(() {
                            showError = true;
                          });
                          return; // Exit if no property is selected
                        } else {
                          setState(() {
                            showError = false;
                          });
                        }

                        // Validate form fields
                        if (address.text.trim().isEmpty) {
                          setState(() {
                            addresserror = true;
                            addressmessage = "required";
                          });
                          return; // Exit if address is empty
                        } else {
                          setState(() {
                            addresserror = false;
                          });
                        }

                        if (city.text.trim().isEmpty) {
                          setState(() {
                            cityerror = true;
                            citymessage = "required";
                          });
                          return; // Exit if city is empty
                        } else {
                          setState(() {
                            cityerror = false;
                          });
                        }

                        if (state.text.trim().isEmpty) {
                          setState(() {
                            stateerror = true;
                            statemessage = "required";
                          });
                          return; // Exit if state is empty
                        } else {
                          setState(() {
                            stateerror = false;
                          });
                        }

                        if (country.text.trim().isEmpty) {
                          setState(() {
                            countryerror = true;
                            countrymessage = "required";
                          });
                          return; // Exit if country is empty
                        } else {
                          setState(() {
                            countryerror = false;
                          });
                        }

                        if (postalcode.text.trim().isEmpty) {
                          setState(() {
                            postalcodeerror = true;
                            postalcodemessage = "required";
                          });
                          return; // Exit if postal code is empty
                        } else {
                          setState(() {
                            postalcodeerror = false;
                          });
                        }

                        if (Ownersdetails == null) {
                          setState(() {
                            hasError = true;
                            postalcodemessage = "required";
                          });
                          return; // Exit if owner details are not provided
                        } else {
                          setState(() {
                            hasError = false;
                          });
                        }

                        // Web marks this required (Rentals.jsx placed_in_service),
                        // and the asterisk on the label already promises it.
                        if (datePlacedInService.text.trim().isEmpty) {
                          setState(() {
                            datePlacedInServiceError = true;
                            datePlacedInServiceMessage =
                                "Please enter date placed in service";
                          });
                          return; // Exit if date placed in service is empty
                        } else {
                          setState(() {
                            datePlacedInServiceError = false;
                          });
                        }

                        // Check for unit changes

                        // A unit added with Add Another Unit (and not removed
                        // again) is a change.
                        bool hasUnitChanges = Iterable<int>.generate(
                                propertyGroupControllers.length)
                            .any(_isLiveNewUnit);

                        // Debug: Print controller structure
                        for (int i = 0;
                            i < propertyGroupControllers.length;
                            i++) {
                          for (int j = 0;
                              j < propertyGroupControllers[i].length;
                              j++) {
                          }
                        }

                        // Loaded units are compared even when a unit was added.
                        if (propertyGroupControllers.length >= data.length) {
                          for (int i = 0; i < data.length; i++) {
                            var oldUnit = data[i];
                            var controllers = propertyGroupControllers[i];

                            // Add detailed debug prints

                            // Compare values based on property type
                            bool sqftChanged = false;
                            bool unitChanged = false;
                            bool addressChanged = false;
                            bool bathChanged = false;
                            bool bedChanged = false;
                            bool imageChanged = false;
                            // Rent Price / Half Baths / Availability Date
                            bool unitExtraChanged = false;
                            // Unit Amenities — Residential only; stays false
                            // for Commercial.
                            bool amenitiesChanged = false;
                            // Unit Description — Commercial only (Residential
                            // compares it inside _unitExtrasChanged).
                            bool descriptionChanged = false;


                            // Fix property type detection - Single-Family should be Commercial
                            String actualPropertyType =
                                getActualPropertyType(selectedpropertytype);

                            if (actualPropertyType == 'Commercial') {
                              if (selectedIsMultiUnit == true) {
                                // Commercial multi-unit
                                String oldSqft =
                                    oldUnit.rentalsqft?.trim() ?? '';
                                String newSqft = controllers[2].text.trim();
                                String oldUnitName =
                                    oldUnit.rentalunit?.trim() ?? '';
                                String newUnitName = controllers[0].text.trim();
                                String oldAddress =
                                    oldUnit.rentalunitadress?.trim() ?? '';
                                String newAddress = controllers[1].text.trim();

                                sqftChanged = oldSqft != newSqft;
                                unitChanged = oldUnitName != newUnitName;
                                addressChanged = oldAddress != newAddress;
                                descriptionChanged =
                                    (oldUnit.description ?? '').trim() !=
                                        _at(controllers, 3);

                              } else {
                                // Commercial single unit
                                String oldSqft =
                                    oldUnit.rentalsqft?.trim() ?? '';
                                String newSqft = controllers[0].text.trim();

                                sqftChanged = oldSqft != newSqft;
                                descriptionChanged =
                                    (oldUnit.description ?? '').trim() !=
                                        _at(controllers, 1);

                              }
                            } else if (actualPropertyType == 'Residential') {
                              if (selectedIsMultiUnit == true) {
                                // Residential multi-unit
                                for (int c = 0; c < controllers.length; c++) {
                                }

                                String oldSqft =
                                    oldUnit.rentalsqft?.trim() ?? '';
                                String newSqft = controllers[2].text.trim();
                                String oldUnitName =
                                    oldUnit.rentalunit?.trim() ?? '';
                                String newUnitName = controllers[0].text.trim();
                                String oldAddress =
                                    oldUnit.rentalunitadress?.trim() ?? '';
                                String newAddress = controllers[1].text.trim();
                                String oldBath =
                                    oldUnit.rentalbath?.trim() ?? '';
                                String newBath = controllers[3].text.trim();
                                String oldBed = oldUnit.rentalbed?.trim() ?? '';
                                String newBed = controllers[4].text.trim();

                                sqftChanged = oldSqft != newSqft;
                                unitChanged = oldUnitName != newUnitName;
                                addressChanged = oldAddress != newAddress;
                                bathChanged = oldBath != newBath;
                                bedChanged = oldBed != newBed;
                                // Compare the dates in API form so a display
                                // format change alone never reads as an edit.
                                unitExtraChanged =
                                    _unitExtrasChanged(oldUnit, controllers, 5);

                              } else {
                                // Residential single unit
                                // Extract correct values from potentially corrupted data for comparison
                                Map<String, String> correctValues =
                                    extractCorrectValues(oldUnit);

                                String oldSqft = correctValues['sqft'] ?? '';
                                String newSqft = controllers[0].text.trim();
                                String oldBath = correctValues['bath'] ?? '';
                                String newBath = controllers[1].text.trim();
                                String oldBed = correctValues['bed'] ?? '';
                                String newBed = controllers[2].text.trim();
                                // Compare the dates in API form so a display
                                // format change alone never reads as an edit.
                                unitExtraChanged =
                                    _unitExtrasChanged(oldUnit, controllers, 3);

                                // Check if the data is corrupted (sqft contains "Bed" or "Bath")
                                bool isDataCorrupted = oldUnit.rentalsqft
                                            ?.toLowerCase()
                                            .contains('bed') ==
                                        true ||
                                    oldUnit.rentalsqft
                                            ?.toLowerCase()
                                            .contains('bath') ==
                                        true;

                                if (isDataCorrupted) {
                                }

                                // Compare using extracted correct values
                                sqftChanged = oldSqft != newSqft;
                                bathChanged = oldBath != newBath;
                                bedChanged = oldBed != newBed;

                              }
                              amenitiesChanged = _amenitiesKey(
                                      propertyGroupAmenities[i].value) !=
                                  _amenitiesKey(
                                      oldUnit.amenities ?? const <String>[]);
                            }

                            // Check for image changes

                            // Check if there's a new local image (user added a new image)
                            if (propertyGroupImages[i] != null) {
                              imageChanged = true;
                            }
                            // Check if network image was removed (user removed existing image)
                            else if (oldUnit.rentalImages != null &&
                                oldUnit.rentalImages!.isNotEmpty &&
                                (propertyGroupImagenames[i] == null ||
                                    propertyGroupImagenames[i]!.isEmpty)) {
                              imageChanged = true;
                            }
                            // Check if network image changed (different from original)
                            else if (oldUnit.rentalImages != null &&
                                oldUnit.rentalImages!.isNotEmpty &&
                                propertyGroupImagenames[i] != null &&
                                propertyGroupImagenames[i]!.isNotEmpty) {
                              String oldImage = oldUnit.rentalImages![0];
                              String newImage = propertyGroupImagenames[i]!;
                              // Extract filename from URL if it's a full URL
                              if (newImage.startsWith('http')) {
                                newImage = newImage.split('/').last;
                              }
                              if (oldImage != newImage) {
                                imageChanged = true;
                              }
                            }

                            // Check if any changes were detected
                            if (sqftChanged ||
                                unitChanged ||
                                addressChanged ||
                                bathChanged ||
                                bedChanged ||
                                unitExtraChanged ||
                                amenitiesChanged ||
                                descriptionChanged ||
                                imageChanged) {
                              hasUnitChanges = true;
                              break; // Exit the loop once we find a change
                            } else {
                            }
                          }
                        }

                        // Check for changes

                        bool hasChanges = hasUnitChanges ||
                            address.text != initialAddress ||
                            datePlacedInService.text !=
                                initialPlacedInService ||
                            city.text != initialCity ||
                            state.text != initialState ||
                            country.text != initialCountry ||
                            postalcode.text != initialPostalCode ||
                            // Owner fields: the controllers above are filled
                            // with `?? ''`, while Ownersdetails keeps whatever
                            // the server sent, including null. Comparing them
                            // raw made `'' != null` true for every owner with a
                            // blank field, so no save could ever read as
                            // unchanged. Normalise both sides, the same way the
                            // manager comparison below already does.
                            firstname.text !=
                                (Ownersdetails?.rentalOwnerName ?? '') ||
                            comname.text !=
                                (Ownersdetails?.rentalOwnerCompanyName ?? '') ||
                            primaryemail.text !=
                                (Ownersdetails?.rentalOwnerPrimaryEmail ?? '') ||
                            alternativeemail.text !=
                                (Ownersdetails?.rentalOwnerAlternateEmail ??
                                    '') ||
                            phonenum.text !=
                                (Ownersdetails?.rentalOwnerPhoneNumber ?? '') ||
                            homenum.text !=
                                (Ownersdetails?.rentalOwnerHomeNumber ?? '') ||
                            businessnum.text !=
                                (Ownersdetails?.rentalOwnerBusinessNumber ??
                                    '') ||
                            street2.text !=
                                (Ownersdetails?.streetAddress ?? '') ||
                            city2.text != (Ownersdetails?.city ?? '') ||
                            state2.text != (Ownersdetails?.state ?? '') ||
                            county2.text != (Ownersdetails?.country ?? '') ||
                            code2.text != (Ownersdetails?.postalCode ?? '') ||
                            // No manager is null on the form but "" on the property;
                            // compare them as equal so an untouched form reads unchanged.
                            (selectedStaff ?? '') !=
                                (widget.properties.staffMemberId ?? '') ||
                            _amenitiesKey(propertyAmenities.value) !=
                                _amenitiesKey(initialPropertyAmenities);



















                        if (!hasChanges) {
                          // A toast, not a SnackBar, so this matches the save
                          // confirmation on this same screen and the Admin form.
                          Fluttertoast.showToast(msg: "No changes detected");
                          Navigator.pop(context, false);
                          return; // Exit if no changes
                        }


                        // Required unit fields, as web requires them.
                        final String? missingUnitField = _missingUnitFields();
                        if (missingUnitField != null) {
                          Fluttertoast.showToast(msg: missingUnitField);
                          return;
                        }

                        // Lock the button before the first await so a double tap cannot
                        // send a second save; the finally releases it whatever happens.
                        setState(() => loading = true);
                        try {
                          // Proceed with form submission
                          SharedPreferences prefs =
                              await SharedPreferences.getInstance();
                          String? id = prefs.getString("adminId");

                          Rental rentals = Rental(
                            rentalId: widget.rentalId,
                            adminId: id,
                            propertyId: widget.properties.propertyId,
                            address: address.text.trim(),
                            city: city.text.trim(),
                            state: state.text.trim(),
                            country: country.text.trim(),
                            postcode: postalcode.text.trim(),
                            staffMemberId: widget.properties.staffMemberId,
                          );

                          List<Map<String, dynamic>> convertedUnits = [];

                          // Every loaded unit is sent (Update waits for the unit load), so none is
                          // dropped here; a blank SQFT or unit name is caught above, as on web.

                          // Prepare units based on property type
                          for (int i = 0;
                              i < propertyGroupControllers.length;
                              i++) {
                            List<TextEditingController> controllers =
                                propertyGroupControllers[i];
                            Map<String, dynamic> unitData = {
                              "admin_id": id,
                              "unit_id": DateTime.now()
                                      .millisecondsSinceEpoch
                                      .toString() +
                                  "_$i",
                              "rental_images": []
                            };

                            // Handle images - prioritize new images over existing ones

                            if (propertyGroupImages[i] != null) {
                              // If new image is selected, use the uploaded filename
                              if (propertyGroupImagenames[i] != null &&
                                  propertyGroupImagenames[i]!.isNotEmpty) {
                                // Extract filename from URL if it's a full URL
                                String imageValue = propertyGroupImagenames[i]!;
                                if (imageValue.startsWith('http')) {
                                  // Extract filename from URL
                                  imageValue = imageValue.split('/').last;
                                }
                                unitData["rental_images"] = [imageValue];
                              } else {
                                // If no filename yet, use the file path temporarily
                                unitData["rental_images"] = [
                                  propertyGroupImages[i]!.path
                                ];
                              }
                            } else if (propertyGroupImagenames[i] != null &&
                                propertyGroupImagenames[i]!.isNotEmpty) {
                              // If no new image but existing image exists, keep the existing one
                              // Extract filename from URL if it's a full URL
                              String imageValue = propertyGroupImagenames[i]!;
                              if (imageValue.startsWith('http')) {
                                // Extract filename from URL
                                imageValue = imageValue.split('/').last;
                              }
                              unitData["rental_images"] = [imageValue];
                            } else {
                            }

                            String actualPropertyType =
                                getActualPropertyType(selectedpropertytype);

                            if (actualPropertyType == 'Commercial' &&
                                selectedIsMultiUnit == true) {
                              if (controllers[0].text.trim().isNotEmpty &&
                                  controllers[1].text.trim().isNotEmpty &&
                                  controllers[2].text.trim().isNotEmpty) {
                                unitData.addAll({
                                  "rental_unit": controllers[0].text.trim(),
                                  "rental_unit_adress":
                                      controllers[1].text.trim(),
                                  "rental_sqft": controllers[2].text.trim(),
                                });
                                convertedUnits.add(unitData);
                              }
                            } else if (actualPropertyType == 'Residential' &&
                                selectedIsMultiUnit == true) {

                              if (controllers[0].text.trim().isNotEmpty &&
                                  controllers[1].text.trim().isNotEmpty &&
                                  controllers[2].text.trim().isNotEmpty &&
                                  controllers[3].text.trim().isNotEmpty &&
                                  controllers[4].text.trim().isNotEmpty) {
                                unitData.addAll({
                                  "rental_unit": controllers[0].text.trim(),
                                  "rental_unit_adress":
                                      controllers[1].text.trim(),
                                  "rental_sqft": controllers[2].text.trim(),
                                  "rental_bath": i < originalValues.length
                                      ? originalValues[i]['bath'] ??
                                          controllers[3].text.trim()
                                      : controllers[3].text.trim(),
                                  "rental_bed": i < originalValues.length
                                      ? originalValues[i]['bed'] ??
                                          controllers[4].text.trim()
                                      : controllers[4].text.trim(),
                                });
                                convertedUnits.add(unitData);
                              } else {
                              }
                            } else if (actualPropertyType == 'Residential') {
                              if (controllers[0].text.trim().isNotEmpty &&
                                  controllers[1].text.trim().isNotEmpty &&
                                  controllers[2].text.trim().isNotEmpty) {
                                unitData.addAll({
                                  "rental_sqft": controllers[0].text.trim(),
                                  "rental_bath": i < originalValues.length
                                      ? originalValues[i]['bath'] ??
                                          controllers[1].text.trim()
                                      : controllers[1].text.trim(),
                                  "rental_bed": i < originalValues.length
                                      ? originalValues[i]['bed'] ??
                                          controllers[2].text.trim()
                                      : controllers[2].text.trim(),
                                });
                                convertedUnits.add(unitData);
                              }
                            } else if (actualPropertyType == 'Commercial') {
                              // For Commercial single unit, we only need sqft
                              unitData.addAll({
                                "rental_sqft": controllers[0].text,
                                "rental_unit": "Unit 1", // Default unit name
                                "rental_unit_adress":
                                    address.text, // Use main property address
                              });
                              convertedUnits.add(unitData);
                            }
                          }


                          RentalOwners owners = RentalOwners(
                            adminId: id,
                            firstName: firstname.text.trim(),
                            companyName: comname.text.trim(),
                            primaryEmail: primaryemail.text.trim(),
                            phoneNumber: phonenum.text.trim(),
                            city: city2.text.trim(),
                            state: state2.text.trim(),
                            country: county2.text.trim(),
                            postalCode: code2.text.trim(),
                          );

                          // RentalRequest rentalrequest = RentalRequest(
                          //   rentalOwner: owners,
                          //   rental: rentals,
                          //   units: units,
                          // );

                          final updatedOwner = RentalOwner(
                            rentalOwnerName: firstnameController.text.trim(),
                            rentalOwnerCompanyName: comnameController.text.trim(),
                            rentalOwnerPrimaryEmail:
                                primaryemailController.text.trim(),
                            rentalOwnerPhoneNumber:
                                phonenumController.text.trim(),
                            city: cityController.text.trim(),
                            state: stateController.text.trim(),
                            country: countyController.text.trim(),
                            postalCode: codeController.text.trim(),
                          );

                          RentalOwner? ownerDetails =
                              context.read<OwnerDetailsProvider>().ownerDetails;

                          String processorId = context
                                  .read<OwnerDetailsProvider>()
                                  .selectedprocessorlist ??
                              "";

                          List<Map<String, String>> processorIds =
                              ownerDetails!.processorList!.map((processor) {
                            return {
                              'processor_id': processor.processorId ?? "",
                            };
                          }).toList();

                          // Convert List<Unit> to List<Map<String, dynamic>>
                          // convertedUnits is already prepared above


                          // Prepare units data
                          List<Map<String, dynamic>> unitData = [];
                          for (var controllers in propertyGroupControllers) {
                            for (int i = 0; i < controllers.length; i++) {
                            }
                          }
                          for (var unit in data) {
                          }
                          for (int i = 0;
                              i < propertyGroupControllers.length;
                              i++) {
                            var controllers = propertyGroupControllers[i];
                            // A never-saved unit whose card was removed.
                            if (i >= data.length &&
                                _removedUnitSlots.contains(i)) {
                              continue;
                            }
                            // New units (Add Another Unit) have no entry in data.
                            final unit_properties? oldUnit =
                                i < data.length ? data[i] : null;
                            for (int j = 0; j < controllers.length; j++) {
                            }

                            // For Commercial single unit, ensure sqft goes to rental_sqft
                            Map<String, dynamic> unit;
                            String actualPropertyType =
                                getActualPropertyType(selectedpropertytype);

                            if (actualPropertyType == 'Commercial' &&
                                !selectedIsMultiUnit) {
                              unit = {
                                'admin_id': id,
                                // New units go without an id so the server creates
                                // them, like web; loaded units keep theirs.
                                if (oldUnit != null) 'unit_id': oldUnit.unitId,
                                // Send the stored unit name/address back unchanged,
                                // like web (it used to overwrite them with "Unit 1"
                                // and the property address).
                                'rental_unit': oldUnit?.rentalunit ?? '',
                                'rental_unit_adress': oldUnit?.rentalunitadress ?? '',
                                'rental_sqft': controllers[0]
                                    .text, // sqft from first controller
                                'rental_images':
                                    _unitImagesForSave(i),
                                'rental_bath':
                                    "", // Add empty bath for consistency
                                'rental_bed': "", // Add empty bed for consistency
                                'description': _at(controllers, 1),
                              };
                            } else if (actualPropertyType == 'Residential' &&
                                !selectedIsMultiUnit) {
                              // Single-unit Residential shows only SQFT / Bath / Bed —
                              // its controllers are [sqft, bath, bed], not the multi-unit
                              // [unit, address, sqft, bath, bed]. Reading them by the
                              // multi-unit positions wrote Bed into SQFT on every save.
                              // Uses the SAME flag the unit fields were built from
                              // (selectedpropertytypedata.isMultiunit), so it cannot
                              // drift. It used to count controllers, which silently
                              // broke every time a field was added — that is what put
                              // Bed into SQFT. Unit name and address aren't on this
                              // form, so keep what the unit already has.
                              unit = {
                                'admin_id': id,
                                // New units go without an id so the server creates
                                // them, like web; loaded units keep theirs.
                                if (oldUnit != null) 'unit_id': oldUnit.unitId,
                                'rental_unit': oldUnit?.rentalunit ?? '',
                                'rental_unit_adress': oldUnit?.rentalunitadress ?? '',
                                'rental_sqft': controllers[0].text.trim(),
                                'rental_images':
                                    _unitImagesForSave(i),
                                'rental_bath': controllers[1].text.trim(),
                                'rental_bed': controllers[2].text.trim(),
                                'rental_unit_price': _at(controllers, 3),
                                'half_baths': _at(controllers, 4),
                                'availability_date': _toApiDate(_at(controllers, 5)) ?? '',
                                'parking_type': _at(controllers, 6),
                                'lease_term': _at(controllers, 7),
                                'security_deposit': _at(controllers, 8),
                                'security_deposit_type': _at(controllers, 9),
                                'security_deposit_max': _at(controllers, 10),
                                'security_deposit_refundable': _at(controllers, 11),
                                'pet_policy': _at(controllers, 12),
                                'is_furnished': _at(controllers, 13) == 'true',
                                'smoking_allowed': _at(controllers, 14) == 'true',
                                'description': _at(controllers, 15),
                                'amenities': List<String>.from(
                                    propertyGroupAmenities[i].value),
                              };
                            } else {
                              unit = {
                                'admin_id': id,
                                // New units go without an id so the server creates
                                // them, like web; loaded units keep theirs.
                                if (oldUnit != null) 'unit_id': oldUnit.unitId,
                                'rental_unit': controllers[0].text,
                                'rental_unit_adress': controllers[1].text,
                                'rental_sqft': controllers[2].text,
                                'rental_images':
                                    _unitImagesForSave(i),
                                'rental_bath': "",
                                'rental_bed': "",
                              };
                              // Multi-unit Residential: Bath / Bed come from what is
                              // selected now. They used to come from a snapshot taken on
                              // load, so every Bath / Bed change was silently dropped.
                              if (actualPropertyType == 'Residential') {
                                unit['rental_bath'] = controllers[3].text.trim();
                                unit['rental_bed'] = controllers[4].text.trim();
                                unit['rental_unit_price'] = _at(controllers, 5);
                                unit['half_baths'] = _at(controllers, 6);
                                unit['availability_date'] =
                                    _toApiDate(_at(controllers, 7)) ?? '';
                                unit['parking_type'] = _at(controllers, 8);
                                unit['lease_term'] = _at(controllers, 9);
                                unit['security_deposit'] = _at(controllers, 10);
                                unit['security_deposit_type'] = _at(controllers, 11);
                                unit['security_deposit_max'] = _at(controllers, 12);
                                unit['security_deposit_refundable'] = _at(controllers, 13);
                                unit['pet_policy'] = _at(controllers, 14);
                                unit['is_furnished'] = _at(controllers, 15) == 'true';
                                unit['smoking_allowed'] = _at(controllers, 16) == 'true';
                                unit['description'] = _at(controllers, 17);
                                unit['amenities'] = List<String>.from(
                                    propertyGroupAmenities[i].value);
                              } else if (actualPropertyType == 'Commercial') {
                                // Multi-unit Commercial: [unit, address, sqft,
                                // description].
                                unit['description'] = _at(controllers, 3);
                              }
                            }
                            unitData.add(unit);
                          }


                          // Format placed_in_service date to yyyy-MM-dd
                          String? formattedPlacedInService;
                          if (datePlacedInService.text.isNotEmpty) {
                            try {
                              DateTime? parsedDate;
                              List<String> dateFormats = [
                                'yyyy-MM-dd', 'yyyy-M-d', 'yyyy-MMM-dd', 'dd-MM-yyyy',
                                'd-M-yyyy', 'M/d/yyyy', 'MM/dd/yyyy',
                              ];
                              for (String format in dateFormats) {
                                try {
                                  parsedDate =
                                      DateFormat(format).parse(datePlacedInService.text);
                                  break;
                                } catch (e) {
                                  continue;
                                }
                              }
                              if (parsedDate != null) {
                                formattedPlacedInService =
                                    DateFormat('yyyy-MM-dd').format(parsedDate);
                              }
                            } catch (e) {
                              logError(
                                  'Error formatting placed_in_service date: $e');
                            }
                          }
                          // Create InsuredValue list (from model/properties.dart) for Rentals
                          List<InsuredValue> insuredValuesList = [];
                          for (var item in historicalInsuredValues) {
                            if (item.year != null &&
                                item.year!.isNotEmpty &&
                                item.valueController.text.isNotEmpty) {
                              String cleanValue =
                                  item.valueController.text.replaceAll(',', '');
                              final numValue = double.tryParse(cleanValue);
                              insuredValuesList.add(InsuredValue(
                                year: item.year,
                                insuredValue: numValue,
                              ));
                            }
                          }
                          Rentals properties = Rentals(
                            units: unitData,
                            adminId: id,
                            rentalOwnerData: RentalOwnerData(
                              adminId: widget.properties.adminId,
                              rentalOwnerId: ownerDetails.rentalOwnerId,
                              rentalOwnerName: updatedOwner.rentalOwnerName,
                              rentalOwnerCompanyName:
                                  updatedOwner.rentalOwnerCompanyName,
                              rentalOwnerPrimaryEmail:
                                  updatedOwner.rentalOwnerPrimaryEmail,
                              rentalOwnerPhoneNumber:
                                  updatedOwner.rentalOwnerPhoneNumber,
                              // All four come from the owner currently selected on
                              // the form (the provider, which the owner dialogs
                              // update). updatedOwner never carried home/business,
                              // so they went out blank and the server wiped them,
                              // and the screen controllers only ever held the
                              // owner that was loaded first.
                              rentalOwnerHomeNumber:
                                  ownerDetails.rentalOwnerHomeNumber ?? '',
                              rentalOwnerBuisinessNumber:
                                  ownerDetails.rentalOwnerBusinessNumber ?? '',
                              rentalOwnerAlternativeEmail:
                                  ownerDetails.rentalOwnerAlternateEmail ?? '',
                              Address: ownerDetails.streetAddress ?? '',
                              city: updatedOwner.city,
                              state: updatedOwner.state,
                              country: updatedOwner.country,
                              postalCode: updatedOwner.postalCode,
                              processorList: processorIds,
                            ),
                            rentalId: widget.rentalId,
                            propertyId: widget.properties.propertyId,
                            rentalAddress: address.text.trim(),
                            rentalOwnerId: ownerDetails.rentalOwnerId,
                            rentalCity: city.text.trim(),
                            rentalState: state.text.trim(),
                            rentalCountry: country.text.trim(),
                            rentalPostcode: postalcode.text.trim(),
                            staffMemberId: selectedStaff,
                            processor_id: processorId,
                            placedInService: formattedPlacedInService,
                            insuredValues: insuredValuesList.isNotEmpty
                                ? insuredValuesList
                                : null,
                            propertyAmenities:
                                List<String>.from(propertyAmenities.value),
                          );


                          try {
                            await PropertiesRepository()
                                .updateRental1(properties);

                            // ScaffoldMessenger.of(context).showSnackBar(
                            //   const SnackBar(
                            //     content: Text('Property updated successfully'),
                            //     backgroundColor: Colors.green,
                            //   ),
                            // );

                            Navigator.of(context).pop(true);
                          } catch (e) {
                            logError('Error updating property: $e');
                            setState(() {
                              isLoading = false;
                            });

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    'Failed to update property: ${friendlyErrorMessage(e)}'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        } finally {
                          if (mounted) setState(() => loading = false);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: navyClr,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: loading
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: SpinKitFadingCircle(
                                color: Colors.white,
                                size: 22.0,
                              ),
                            )
                          : const Text(
                              "Update Property",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                      ),
                    ),
                  ],
                ),
                const Column(
                  children: [
                    //SetshowRentalOwnerTable(),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProcessorGroup(int index) {
    ProcessorGroup group = _processorGroups[index];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          SizedBox(
            width: 20.0,
            height: 20.0,
            child: Checkbox(
              value: group.isChecked,
              onChanged: (value) {
                setState(() {
                  group.isChecked = value ?? false;
                });
              },
              activeColor: blueColor,
            ),
          ),
          SizedBox(width: MediaQuery.of(context).size.width * .02),
          Expanded(
            child: Material(
              elevation: 3,
              borderRadius: BorderRadius.circular(5),
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(5),
                  color: Colors.white,
                  border: Border.all(color: const Color(0xFF8A95A8)),
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: TextField(
                        controller: group.controller,
                        cursorColor: blueColor,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.only(
                              top: 12.5, bottom: 12.5, left: 15),
                          hintText: "Enter processor",
                          hintStyle: TextStyle(
                            color: Color(0xFF8A95A8),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(width: MediaQuery.of(context).size.width * .02),
          InkWell(
            onTap: () {
              _removeGroup(index);
            },
            child: Container(
              padding: EdgeInsets.zero,
              child: FaIcon(
                FontAwesomeIcons.trashCan,
                size: 20,
                color: blueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  SetshowRentalOwnerTable() {
    const Row(
      children: [
        Text("Hello"),
      ],
    );
  }

  void _addNewGroup() {
    setState(() {
      _processorGroups.add(ProcessorGroup(
          isChecked: false, controller: TextEditingController()));
    });
  }

  void _removeGroup(int index) {
    setState(() {
      _processorGroups.removeAt(index);
    });
  }

  List<Widget> generateOwnerWidgets(
      List<Owner> filteredOwners, BuildContext context) {
    return List<Widget>.generate(filteredOwners.length, (index) {
      Owner owner = filteredOwners[index];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (owner.processorList.isNotEmpty) ...[
            const Row(
              children: [
                Text(
                  "Merchant Id",
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF8A95A8),
                      fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Column(
              children: [
                Container(
                  height: 150,
                  child: ListView.builder(
                    itemCount: _processorGroups.length,
                    itemBuilder: (context, index) {
                      ProcessorGroup group = _processorGroups[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 20.0,
                              height: 20.0,
                              child: Checkbox(
                                value: group.isChecked,
                                onChanged: (value) {
                                  setState(() {
                                    group.isChecked = value ?? false;
                                  });
                                },
                                activeColor: blueColor,
                              ),
                            ),
                            SizedBox(
                                width: MediaQuery.of(context).size.width * .02),
                            Expanded(
                              child: Material(
                                elevation: 3,
                                borderRadius: BorderRadius.circular(5),
                                child: Container(
                                  height: 50,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(5),
                                    color: Colors.white,
                                    border: Border.all(
                                        color: const Color(0xFF8A95A8)),
                                  ),
                                  child: Stack(
                                    children: [
                                      Positioned.fill(
                                        child: TextField(
                                          controller: group.controller,
                                          cursorColor: blueColor,
                                          decoration: const InputDecoration(
                                            border: InputBorder.none,
                                            contentPadding: EdgeInsets.only(
                                                top: 12.5,
                                                bottom: 12.5,
                                                left: 15),
                                            hintText: "Enter processor",
                                            hintStyle: TextStyle(
                                              color: Color(0xFF8A95A8),
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(
                                width: MediaQuery.of(context).size.width * .02),
                            InkWell(
                              onTap: () {
                                _removeGroup(index);
                              },
                              child: Container(
                                padding: EdgeInsets.zero,
                                child: FaIcon(
                                  FontAwesomeIcons.trashCan,
                                  size: 20,
                                  color: blueColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: _addNewGroup,
                  child: const Text("Add Processor Group"),
                ),
              ],
            ),
            SizedBox(height: MediaQuery.of(context).size.height * 0.01),
            const Row(
              children: [
                // Handle error display here if needed
              ],
            ),
          ],
        ],
      );
    });
  }
}

class Owner {
  final String id;
  final String rentalOwnerId;
  final String adminId;
  final String rentalOwnername;
  final String companyName;
  final String primaryEmail;
  final String alternateEmail;
  final String phoneNumber;
  final String? homeNumber;
  final String? businessNumber;
  final String birthDate;
  final String startDate;
  final String endDate;
  final String taxpayerId;
  final String identityType;
  final String streetAddress;
  final String city;
  final String state;
  final String country;
  final String postalCode;
  final String createdAt;
  final String updatedAt;
  final bool isDelete;
  final List<Processor> processorList;

  Owner({
    required this.id,
    required this.rentalOwnerId,
    required this.adminId,
    required this.rentalOwnername,
    required this.companyName,
    required this.primaryEmail,
    required this.alternateEmail,
    required this.phoneNumber,
    required this.homeNumber,
    required this.businessNumber,
    required this.birthDate,
    required this.startDate,
    required this.endDate,
    required this.taxpayerId,
    required this.identityType,
    required this.streetAddress,
    required this.city,
    required this.state,
    required this.country,
    required this.postalCode,
    required this.createdAt,
    required this.updatedAt,
    required this.isDelete,
    required this.processorList,
  });

  factory Owner.fromJson(Map<String, dynamic> json) {
    var list = json['processor_list'] as List;
    List<Processor> processorList =
        list.map((i) => Processor.fromJson(i)).toList();

    return Owner(
      id: json['_id'],
      rentalOwnerId: json['rentalowner_id'] ?? "",
      adminId: json['admin_id'] ?? "",
      rentalOwnername: json['rentalOwner_name'] ?? "",
      companyName: json['rentalOwner_companyName'] ?? "",
      primaryEmail: json['rentalOwner_primaryEmail'] ?? "",
      alternateEmail: json['rentalOwner_alternateEmail'] ?? "",
      phoneNumber: json['rentalOwner_phoneNumber'] ?? "",
      homeNumber: json['rentalOwner_homeNumber'] ?? "", // Nullable field
      businessNumber:
          json['rentalOwner_businessNumber'] ?? "", // Nullable field
      birthDate: json['birth_date'] ?? "",
      startDate: json['start_date'] ?? "",
      endDate: json['end_date'] ?? "",
      taxpayerId: json['texpayer_id'] ?? "",
      identityType: json['text_identityType'] ?? "",
      streetAddress: json['street_address'] ?? "",
      city: json['city'] ?? "",
      state: json['state'] ?? "",
      country: json['country'] ?? "",
      postalCode: json['postal_code'] ?? "",
      createdAt: json['createdAt'] ?? "",
      updatedAt: json['updatedAt'] ?? "",
      isDelete: json['is_delete'],
      processorList: processorList,
    );
  }
}

// class Processor {
//   final String processorId;
//   final String id;
//
//   Processor({required this.processorId, required this.id});
//
//   factory Processor.fromJson(Map<String, dynamic> json) {
//     return Processor(
//       processorId: json['processor_id'],
//       id: json['_id'],
//     );
//   }
// }
class Processor {
  final String processorId;
  final String id;

  Processor({required this.processorId, required this.id});

  factory Processor.fromJson(Map<String, dynamic> json) {
    return Processor(
      processorId: json['processor_id'],
      id: json['_id'],
    );
  }
}

class ProcessorGroup {
  bool isChecked;
  TextEditingController controller;

  ProcessorGroup({required this.isChecked, required this.controller});
}

class OwnersDetails {
  RentalOwner? Ownersdetails;
  OwnersDetails({
    required this.Ownersdetails,
  });
}

class RentalOwnerSource extends DataTableSource {
  final List<RentalOwner> rentalowner;
  final Function(RentalOwner) onEdit;
  final Function(RentalOwner) onDelete;

  RentalOwnerSource(this.rentalowner,
      {required this.onEdit, required this.onDelete});

  @override
  DataRow getRow(int index) {
    final rental = rentalowner[index];
    return DataRow(cells: [
      DataCell(Text(rental.rentalOwnerName!)),
      DataCell(Text(rental.rentalOwnerPhoneNumber!)),
      DataCell(Row(
        children: [
          InkWell(
            onTap: () {
              onEdit(rental);
            },
            child: Container(
              //  color: Colors.redAccent,
              padding: EdgeInsets.zero,
              child: const FaIcon(
                FontAwesomeIcons.edit,
                size: 20,
              ),
            ),
          ),
          const SizedBox(
            width: 4,
          ),
          InkWell(
            onTap: () {
              onDelete(rental);
            },
            child: Container(
              //    color: Colors.redAccent,
              padding: EdgeInsets.zero,
              child: const FaIcon(
                FontAwesomeIcons.trashCan,
                size: 20,
              ),
            ),
          ),
        ],
      )),
    ]);
  }

  @override
  bool get isRowCountApproximate => false;

  @override
  int get rowCount => rentalowner.length;

  @override
  int get selectedRowCount => 0;
}

class HistoricalInsuredValue {
  String? year;
  String? insuredValue;
  TextEditingController yearController;
  TextEditingController valueController;
  bool yearError;
  bool valueError;

  HistoricalInsuredValue({
    this.year,
    this.insuredValue,
    required this.yearController,
    required this.valueController,
    this.yearError = false,
    this.valueError = false,
  });
}

/// Dashed rounded-rect outline for the unit photo upload box. Visual only;
/// drawn here so no extra package is needed.
class _PfDashedRRectPainter extends CustomPainter {
  final Color color;
  static const double strokeWidth = 1.2;
  static const double radius = 12;

  const _PfDashedRRectPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;
    const half = strokeWidth / 2;
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(
            half, half, size.width - strokeWidth, size.height - strokeWidth),
        Radius.circular(radius),
      ));
    const dash = 6.0;
    const gap = 4.0;
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final end = (distance + dash).clamp(0.0, metric.length).toDouble();
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance = end + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PfDashedRRectPainter oldDelegate) =>
      oldDelegate.color != color;
}

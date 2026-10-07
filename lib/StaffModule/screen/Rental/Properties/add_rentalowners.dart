import 'dart:convert';

import 'package:email_validator/email_validator.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:keyboard_actions/keyboard_actions.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../widgets/appbar.dart';
import 'package:three_zero_two_property/widgets/us_state_dropdown.dart';

import '../../../../constant/constant.dart';
import '../../../../model/rental_properties.dart';
import '../../../../provider/add_property.dart';
import '../../../repository/rental_properties.dart';
import 'package:three_zero_two_property/services/api_helpers.dart';
import '../../../widgets/custom_drawer.dart';

class AddRentalowners extends StatefulWidget {
  RentalOwner? OwnersDetails;
  bool? isEdit;
  AddRentalowners({super.key, this.OwnersDetails, this.isEdit});

  @override
  State<AddRentalowners> createState() => _AddRentalownersState();
}

class _AddRentalownersState extends State<AddRentalowners> {
  // ---- Redesign visual constants (one place for the whole screen).
  // Values = app palette in lib/constant/constant.dart.
  static const Color _ownerNavy = Color(0xFF152B51); // text/labels (blueColor)
  static const Color _ownerNavy2 = navyClr; // title bar + primary button
  static const Color _ownerPageBg = pageBg; // page background
  static const Color _ownerBorder = borderClr; // card + Cancel border
  static const Color _ownerInputBorder = outlineClr; // input border
  static const Color _ownerTint = Color(0xFFEEF3FA); // list header strip
  static const Color _ownerMuted = mutedClr; // owner phone line
  static const Color _ownerFaint = Color(0xFF94A1B4); // placeholders, icon
  static const Color _ownerCheckOff = checkOffClr; // unchecked checkbox
  static const TextStyle _ownerHintStyle =
      TextStyle(color: _ownerFaint, fontSize: 14);
  Owner? selectedOwner;
  Owner? rentalOwnerId;

  bool isEdit = false;

  /// Web parity (Rentals.jsx isEditingExistingOwner): opened on an existing
  /// owner = "Edit Rental Owner" / "Update"; picking a different owner from the
  /// list reads as Add again, as on web.
  bool get _isEditingOwner =>
      widget.isEdit == true &&
      (widget.OwnersDetails?.rentalOwnerName ?? '').trim().isNotEmpty &&
      !isChecked2;
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

  GlobalKey<FormState> _formKey = GlobalKey<FormState>();

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
  TextEditingController searchController = TextEditingController();

  @override
  void dispose() {
    firstname.dispose();
    comname.dispose();
    primaryemail.dispose();
    alternativeemail.dispose();
    phonenum.dispose();
    homenum.dispose();
    businessnum.dispose();
    street2.dispose();
    city2.dispose();
    state2.dispose();
    county2.dispose();
    code2.dispose();
    proid.dispose();
    searchController.dispose();
    super.dispose();
  }

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
  bool isChecked = false;
  bool isChecked2 = false;
  bool isFetchingOwners = false;
  bool isSubmitting = false;
  String? processor_id;

  List<Owner> owners = [];
  List<Owner> filteredOwners = [];
  List<bool> selected = [];
  int? selectedIndex;

  List<ProcessorGroup> _processorGroups = [];

  RentalOwner? Ownersdetails;
  //List<OwnersDetails> OwnersdetailsGroups = [];
  bool hasError = false;
  Future<void> fetchOwners() async {
    if (!mounted) return;
    setState(() {
      isFetchingOwners = true;
    });
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? id = prefs.getString("adminId");
      String? token = prefs.getString('token');
      String? staffid = prefs.getString("staff_id");
      final response = await apiGet(
        Uri.parse('${Api_url}/api/rentals/rental-owners/$id'),
        headers: {
          "id": "CRM $staffid",
          "authorization": "CRM $token",
        },
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        owners = data.map((item) => Owner.fromJson(item)).toList();
        filteredOwners = List.from(owners);
        selected = List<bool>.filled(owners.length, false);
      }
    } catch (_) {
      // Keep the form usable even if the existing-owner list fails to load.
    } finally {
      if (mounted) {
        setState(() {
          isFetchingOwners = false;
        });
      }
    }
  }

  void filterOwners(String query) {
    setState(() {
      filteredOwners = owners.where((owner) {
        final fullName = '${owner.rentalOwnername} '.toLowerCase();
        return fullName.contains(query.toLowerCase());
      }).toList();
    });
  }

  @override
  void initState() {
    super.initState();
    filteredOwners = owners;
    selected = List<bool>.generate(owners.length, (index) => false);
    // searchController.addListener(() { });
    // futureMember = StaffMemberRepository().fetchStaffmembers();
    //futureProperties = PropertyTypeRepository().fetchPropertyTypes();
    //futureStaffMembers = StaffMemberRepository().fetchStaffmembers();
    //propertyGroups = [];
    // Add property group based on selected subproperty type
    //addPropertyGroup();
    fetchOwners();
    firstname.text = widget.OwnersDetails?.rentalOwnerName ?? "";
    phonenum.text = widget.OwnersDetails?.rentalOwnerPhoneNumber ?? "";
    comname.text = widget.OwnersDetails?.rentalOwnerCompanyName ?? "";
    primaryemail.text = widget.OwnersDetails?.rentalOwnerPrimaryEmail ?? "";
    alternativeemail.text =
        widget.OwnersDetails?.rentalOwnerAlternateEmail ?? "";
    phonenum.text = formatPhoneNumberedit(
        widget.OwnersDetails?.rentalOwnerPhoneNumber ?? "");
    homenum.text = formatPhoneNumberedit(
        widget.OwnersDetails?.rentalOwnerHomeNumber ?? "");
    businessnum.text = formatPhoneNumberedit(
        widget.OwnersDetails?.rentalOwnerBusinessNumber ?? "");
    street2.text = widget.OwnersDetails?.streetAddress ?? "";
    city2.text = widget.OwnersDetails?.city ?? "";
    state2.text = widget.OwnersDetails?.state ?? "";
    county2.text = widget.OwnersDetails?.country ?? "";
    code2.text = widget.OwnersDetails?.postalCode ?? "";
    proid.text = widget.OwnersDetails?.postalCode ?? "";

    if (widget.isEdit != null &&
        widget.OwnersDetails?.processorList != null &&
        widget.OwnersDetails!.processorList!.length > 0) {
      for (var i = 0; i < widget.OwnersDetails!.processorList!.length; i++) {
        _processorGroups.add(ProcessorGroup(
          isChecked: false,
          controller: TextEditingController(
              text: widget.OwnersDetails!.processorList![i].processorId),
        ));
      }
    } else {
      if (_processorGroups.isEmpty) {
        _processorGroups.add(ProcessorGroup(
          isChecked: false,
          controller: TextEditingController(),
        ));
      }
    }
  }

  final FocusNode _nodeText1 = FocusNode();
  final FocusNode _nodeText2 = FocusNode();
  final FocusNode _nodeText3 = FocusNode();
  final FocusNode _nodeText4 = FocusNode();

  KeyboardActionsConfig _buildConfig(BuildContext context) {
    return KeyboardActionsConfig(
      keyboardActionsPlatform: KeyboardActionsPlatform.ALL,
      keyboardBarColor: Colors.grey[200],
      nextFocus: true,
      actions: [
        KeyboardActionsItem(
          focusNode: _nodeText1,
        ),
        KeyboardActionsItem(
          focusNode: _nodeText2,
          //  displayCloseWidget: false,
        ),
        KeyboardActionsItem(
          focusNode: _nodeText3,
        ),
        KeyboardActionsItem(
          focusNode: _nodeText4,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget_302_Staff.App_Bar(context: context),
      backgroundColor: _ownerPageBg,
      drawer: CustomDrawerStaff(
        currentpage: "Properties",
        dropdown: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ownerTitleBar(
                _isEditingOwner ? "Edit Rental Owner" : "Add Rental Owner",
              ),
              const SizedBox(height: 16),
              _ownerCheckCard(
                value: isChecked,
                label: "Choose an existing rental owner",
                onChanged: (value) {
                  setState(() {
                    isChecked = value ?? false;
                  });
                },
              ),
              const SizedBox(height: 16),
              isChecked
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _ownerSearchBox(
                          child: TextField(
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 14,
                            ),
                            controller: searchController,
                            //keyboardType: TextInputType.emailAddress,
                            onChanged: (value) {
                              setState(() {
                                if (value != "")
                                  filteredOwners = owners
                                      .where((element) => element
                                          .rentalOwnername
                                          .toLowerCase()
                                          .contains(value
                                              .toLowerCase()))
                                      .toList();
                                if (value == "") {
                                  filteredOwners = owners;
                                }
                              });
                            },
                            cursorColor: blueColor,
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding:
                                  EdgeInsets.symmetric(vertical: 14),
                              hintText: "Search by first and last name",
                              hintStyle: _ownerHintStyle,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _ownerListHeader(
                          left: "Rental Owner Name",
                          right: "Select",
                        ),
                        ...List<Widget>.generate(
                          filteredOwners.length,
                          (index) => Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: _ownerListRow(
                              name: filteredOwners[index].rentalOwnername,
                              phone: filteredOwners[index].phoneNumber,
                              selected: selectedIndex == index,
                              onChanged: (bool? value) {
                                setState(() {
                                  if (value != null &&
                                      value) {
                                    selectedIndex = index;
                                    selectedOwner =
                                        filteredOwners[index];
                                    firstname.text =
                                        selectedOwner!
                                            .rentalOwnername;
                                    comname.text =
                                        selectedOwner!
                                            .companyName;
                                    primaryemail.text =
                                        selectedOwner!
                                            .primaryEmail;
                                    alternativeemail.text =
                                        selectedOwner!
                                            .alternateEmail;
                                    homenum.text =
                                        selectedOwner!
                                                .homeNumber ??
                                            '';
                                    phonenum.text =
                                        selectedOwner!
                                            .phoneNumber;
                                    businessnum
                                        .text = selectedOwner!
                                            .businessNumber ??
                                        '';
                                    street2.text =
                                        selectedOwner!
                                            .streetAddress;
                                    city2.text =
                                        selectedOwner!.city;
                                    state2.text =
                                        selectedOwner!.state;
                                    county2.text =
                                        selectedOwner!
                                            .country;
                                    code2.text =
                                        selectedOwner!
                                            .postalCode;
                                    proid.text = selectedOwner!
                                        .processorList
                                        .map((processor) =>
                                            processor
                                                .processorId)
                                        .join(', ');
                                  } else {
                                    selectedIndex = null;
                                  }
                                  isChecked2 = true;
                                  isChecked = false;
                                  _processorGroups.clear();
                                  for (Processor processor
                                      in selectedOwner!
                                          .processorList) {
                                    _processorGroups.add(ProcessorGroup(
                                        isChecked: false,
                                        controller:
                                            TextEditingController(
                                                text: processor
                                                    .processorId)));
                                  }
                                });
                              },
                            ),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _ownerSectionCard(
                          title: "Owner Details",
                          children: [
                            _ownerFieldLabel("Contact Name", required: true),
                            _ownerInput(
                              child: TextField(
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize:
                                      MediaQuery.of(context)
                                                  .size
                                                  .width <
                                              500
                                          ? 14
                                          : 15,
                                ),
                                keyboardType: TextInputType
                                    .text, // Adjust as needed
                                onChanged: (value) {
                                  setState(() {
                                    firstnameerror = false;
                                  });
                                },
                                controller: firstname,
                                cursorColor: blueColor,
                                decoration: const InputDecoration(
                                  // enabledBorder: firstnameerror
                                  //     ? OutlineInputBorder(
                                  //         borderRadius:
                                  //             BorderRadius
                                  //                 .circular(
                                  //                     10),
                                  //         borderSide: BorderSide(
                                  //             color: Colors
                                  //                 .red), // Set border color here
                                  //       )
                                  //     : InputBorder.none,
                                  border: InputBorder.none,
                                  contentPadding:
                                      EdgeInsets.all(14),
                                  hintText: "Enter name",
                                  hintStyle: _ownerHintStyle,
                                ),
                              ),
                            ),
                            if (firstnameerror)
                              _ownerErrorText(firstnamemessage),
                            const SizedBox(height: 16),
                            _ownerFieldLabel("Company Name", required: true),
                            _ownerInput(
                              child: TextField(
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize:
                                      MediaQuery.of(context)
                                                  .size
                                                  .width <
                                              500
                                          ? 14
                                          : 15,
                                ),
                                keyboardType: TextInputType
                                    .text, // Adjust as needed
                                onChanged: (value) {
                                  setState(() {
                                    comnameerror = false;
                                  });
                                },
                                controller: comname,
                                cursorColor: blueColor,
                                decoration: const InputDecoration(
                                  // enabledBorder: comnameerror
                                  //     ? OutlineInputBorder(
                                  //         borderRadius:
                                  //             BorderRadius
                                  //                 .circular(
                                  //                     10),
                                  //         borderSide: BorderSide(
                                  //             color: Colors
                                  //                 .red), // Set border color here
                                  //       )
                                  //     : InputBorder.none,
                                  border: InputBorder.none,
                                  contentPadding:
                                      EdgeInsets.all(14),
                                  hintText:
                                      "Enter company name",
                                  hintStyle: _ownerHintStyle,
                                ),
                              ),
                            ),
                            if (comnameerror) _ownerErrorText(comnamemessage),
                            const SizedBox(height: 16),
                            _ownerFieldLabel("Primary Email", required: true),
                            _ownerInput(
                              child: TextField(
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize:
                                      MediaQuery.of(context)
                                                  .size
                                                  .width <
                                              500
                                          ? 14
                                          : 15,
                                ),
                                keyboardType: TextInputType
                                    .emailAddress, // Adjust as needed
                                onChanged: (value) {
                                  setState(() {
                                    primaryemailerror = false;
                                  });
                                },

                                controller: primaryemail,
                                cursorColor: blueColor,
                                decoration: const InputDecoration(
                                  // enabledBorder:
                                  //     primaryemailerror
                                  //         ? OutlineInputBorder(
                                  //             borderRadius:
                                  //                 BorderRadius
                                  //                     .circular(
                                  //                         10),
                                  //             borderSide: BorderSide(
                                  //                 color: Colors
                                  //                     .red), // Set border color here
                                  //           )
                                  //         : InputBorder.none,
                                  border: InputBorder.none,
                                  contentPadding:
                                      EdgeInsets.all(14),
                                  hintText:
                                      "Enter primary email",
                                  hintStyle: _ownerHintStyle,
                                ),
                              ),
                            ),
                            if (primaryemailerror)
                              _ownerErrorText(primaryemailmessage),
                            const SizedBox(height: 16),
                            _ownerFieldLabel("Alternative Email"),
                            _ownerInput(
                              child: TextField(
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize:
                                      MediaQuery.of(context)
                                                  .size
                                                  .width <
                                              500
                                          ? 14
                                          : 15,
                                ),
                                keyboardType: TextInputType
                                    .emailAddress, // Adjust as needed
                                onChanged: (value) {
                                  setState(() {
                                    alternativeerror = false;
                                  });
                                },
                                controller: alternativeemail,
                                cursorColor: blueColor,
                                decoration: const InputDecoration(
                                  // enabledBorder:
                                  //     alternativeerror
                                  //         ? OutlineInputBorder(
                                  //             borderRadius:
                                  //                 BorderRadius
                                  //                     .circular(
                                  //                         10),
                                  //             borderSide: BorderSide(
                                  //                 color: Colors
                                  //                     .red), // Set border color here
                                  //           )
                                  //         : InputBorder.none,
                                  border: InputBorder.none,
                                  contentPadding:
                                      EdgeInsets.all(14),
                                  hintText:
                                      "Enter alternative email",
                                  hintStyle: _ownerHintStyle,
                                ),
                              ),
                            ),
                            if (alternativeerror)
                              _ownerErrorText(alternativemessage),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _ownerSectionCard(
                          title: "Phone Numbers",
                          required: true,
                          children: [
                            _ownerFieldLabel("Mobile"),
                            _ownerInput(
                              child: TextField(
                                inputFormatters: [
                                  FilteringTextInputFormatter
                                      .digitsOnly,
                                  LengthLimitingTextInputFormatter(
                                      10),
                                  PhoneNumberFormatter(),
                                ],
                                focusNode: _nodeText1,
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize:
                                      MediaQuery.of(context)
                                                  .size
                                                  .width <
                                              500
                                          ? 14
                                          : 15,
                                ),
                                keyboardType:
                                    TextInputType.number,
                                // keyboardType: TextInputType
                                //     .numberWithOptions(
                                //         signed: true,
                                //         decimal:
                                //             true), // Adjust as needed
                                onChanged: (value) {
                                  setState(() {
                                    phonenumerror = false;
                                  });
                                },
                                controller: phonenum,
                                cursorColor: blueColor,
                                decoration: const InputDecoration(
                                  // enabledBorder: phonenumerror
                                  //     ? OutlineInputBorder(
                                  //         borderRadius:
                                  //             BorderRadius
                                  //                 .circular(
                                  //                     10),
                                  //         borderSide: BorderSide(
                                  //             color: Colors
                                  //                 .red), // Set border color here
                                  //       )
                                  //     : InputBorder.none,
                                  border: InputBorder.none,
                                  contentPadding:
                                      EdgeInsets.all(14),
                                  hintText:
                                      "Enter phone number",
                                  hintStyle: _ownerHintStyle,
                                ),
                              ),
                            ),
                            if (phonenumerror)
                              _ownerErrorText(phonenummessage),
                            const SizedBox(height: 16),
                            _ownerFieldLabel("Home"),
                            _ownerInput(
                              child: TextField(
                                inputFormatters: [
                                  FilteringTextInputFormatter
                                      .digitsOnly,
                                  LengthLimitingTextInputFormatter(
                                      10),
                                  PhoneNumberFormatter(),
                                ],
                                focusNode: _nodeText2,
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize:
                                      MediaQuery.of(context)
                                                  .size
                                                  .width <
                                              500
                                          ? 14
                                          : 15,
                                ),
                                keyboardType:
                                    TextInputType.number,
                                // keyboardType: TextInputType
                                //     .numberWithOptions(
                                //         signed: true,
                                //         decimal:
                                //             true), // Adjust as needed
                                onChanged: (value) {
                                  setState(() {
                                    homenumerror = false;
                                  });
                                },
                                controller: homenum,
                                cursorColor: blueColor,
                                decoration: const InputDecoration(
                                  // enabledBorder: homenumerror
                                  //     ? OutlineInputBorder(
                                  //         borderRadius:
                                  //             BorderRadius
                                  //                 .circular(
                                  //                     10),
                                  //         borderSide: BorderSide(
                                  //             color: Colors
                                  //                 .red), // Set border color here
                                  //       )
                                  //     : InputBorder.none,
                                  border: InputBorder.none,
                                  contentPadding:
                                      EdgeInsets.all(14),
                                  hintText:
                                      "Enter home number",
                                  hintStyle: _ownerHintStyle,
                                ),
                              ),
                            ),
                            if (homenumerror) _ownerErrorText(homenummessage),
                            const SizedBox(height: 16),
                            _ownerFieldLabel("Business"),
                            _ownerInput(
                              child: TextField(
                                inputFormatters: [
                                  FilteringTextInputFormatter
                                      .digitsOnly,
                                  LengthLimitingTextInputFormatter(
                                      10),
                                  PhoneNumberFormatter(),
                                ],
                                focusNode: _nodeText3,
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize:
                                      MediaQuery.of(context)
                                                  .size
                                                  .width <
                                              500
                                          ? 14
                                          : 15,
                                ),
                                keyboardType:
                                    TextInputType.number,
                                // keyboardType: TextInputType
                                //     .numberWithOptions(
                                //         signed: true,
                                //         decimal:
                                //             true), // Adjust as needed
                                onChanged: (value) {
                                  setState(() {
                                    businessnumerror = false;
                                  });
                                },
                                controller: businessnum,
                                cursorColor: blueColor,
                                decoration: const InputDecoration(
                                  // enabledBorder:
                                  //     businessnumerror
                                  //         ? OutlineInputBorder(
                                  //             borderRadius:
                                  //                 BorderRadius
                                  //                     .circular(
                                  //                         10),
                                  //             borderSide: BorderSide(
                                  //                 color: Colors
                                  //                     .red), // Set border color here
                                  //           )
                                  //         : InputBorder.none,
                                  border: InputBorder.none,
                                  contentPadding:
                                      EdgeInsets.all(14),
                                  hintText:
                                      "Enter business number",
                                  hintStyle: _ownerHintStyle,
                                ),
                              ),
                            ),
                            if (businessnumerror)
                              _ownerErrorText(businessnummessage),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _ownerSectionCard(
                          title: "Address Information",
                          children: [
                            _ownerFieldLabel("Street Address"),
                            _ownerInput(
                              child: TextField(
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize:
                                      MediaQuery.of(context)
                                                  .size
                                                  .width <
                                              500
                                          ? 14
                                          : 15,
                                ),
                                keyboardType: TextInputType
                                    .text, // Adjust as needed
                                onChanged: (value) {
                                  setState(() {
                                    street2error = false;
                                  });
                                },
                                controller: street2,
                                cursorColor: blueColor,
                                decoration: const InputDecoration(
                                  // enabledBorder: street2error
                                  //     ? OutlineInputBorder(
                                  //         borderRadius:
                                  //             BorderRadius
                                  //                 .circular(
                                  //                     10),
                                  //         borderSide: BorderSide(
                                  //             color: Colors
                                  //                 .red), // Set border color here
                                  //       )
                                  //     : InputBorder.none,
                                  border: InputBorder.none,
                                  contentPadding:
                                      EdgeInsets.all(14),
                                  hintText:
                                      "Enter street address",
                                  hintStyle: _ownerHintStyle,
                                ),
                              ),
                            ),
                            if (street2error) _ownerErrorText(street2message),
                            const SizedBox(height: 16),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _ownerFieldLabel("City"),
                                      _ownerInput(
                                        child: TextField(
                                          keyboardType:
                                              TextInputType.text,
                                          controller: city2,
                                          style: TextStyle(
                                            color: Colors.black,
                                            fontSize: MediaQuery.of(
                                                            context)
                                                        .size
                                                        .width <
                                                    500
                                                ? 14
                                                : 15,
                                          ),
                                          onChanged: (value) {
                                            setState(() {
                                              city2error = false;
                                            });
                                          },
                                          cursorColor:
                                              const Color.fromRGBO(
                                                  21, 43, 81, 1),
                                          decoration:
                                              const InputDecoration(
                                            // enabledBorder:
                                            //     city2error
                                            //         ? OutlineInputBorder(
                                            //             borderRadius:
                                            //                 BorderRadius.circular(
                                            //                     10),
                                            //             borderSide:
                                            //                 BorderSide(
                                            //                     color: Colors.red), // Error border color
                                            //           )
                                            //         : InputBorder
                                            //             .none,
                                            border:
                                                InputBorder.none,
                                            contentPadding:
                                                EdgeInsets.all(
                                                    14),
                                            hintText:
                                                "Enter city",
                                            hintStyle: _ownerHintStyle,
                                          ),
                                        ),
                                      ),
                                      if (city2error)
                                        _ownerErrorText(city2message),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _ownerFieldLabel("State"),
                                      UsStateDropdown(
                                        controller: state2,
                                        hintText: 'Select',
                                        borderColor:
                                            state2error ? redClr : null,
                                        onChanged: (value) {
                                          setState(() {
                                            state2error = false;
                                          });
                                        },
                                      ),
                                      if (state2error)
                                        _ownerErrorText(state2message),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _ownerFieldLabel("Country"),
                                      _ownerInput(
                                        child: TextField(
                                          keyboardType:
                                              TextInputType.text,
                                          controller: county2,
                                          style: TextStyle(
                                            color: Colors.black,
                                            fontSize: MediaQuery.of(
                                                            context)
                                                        .size
                                                        .width <
                                                    500
                                                ? 14
                                                : 15,
                                          ),
                                          onChanged: (value) {
                                            setState(() {
                                              county2error =
                                                  false;
                                            });
                                          },
                                          cursorColor:
                                              const Color.fromRGBO(
                                                  21, 43, 81, 1),
                                          decoration:
                                              const InputDecoration(
                                            // enabledBorder:
                                            //     county2error
                                            //         ? OutlineInputBorder(
                                            //             borderRadius:
                                            //                 BorderRadius.circular(
                                            //                     10),
                                            //             borderSide:
                                            //                 BorderSide(
                                            //                     color: Colors.red), // Error border color
                                            //           )
                                            //         : InputBorder
                                            //             .none,
                                            border:
                                                InputBorder.none,
                                            contentPadding:
                                                EdgeInsets.all(
                                                    14),
                                            hintText:
                                                "Enter country",
                                            hintStyle: _ownerHintStyle,
                                          ),
                                        ),
                                      ),
                                      if (county2error)
                                        _ownerErrorText(county2message),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _ownerFieldLabel("Zip Code"),
                                      _ownerInput(
                                        child: TextField(
                                          focusNode: _nodeText4,
                                          controller: code2,
                                          keyboardType:
                                              TextInputType.number,
                                          inputFormatters: [
                                            FilteringTextInputFormatter.digitsOnly,
                                          ],
                                          style: TextStyle(
                                            color: Colors.black,
                                            fontSize: MediaQuery.of(
                                                            context)
                                                        .size
                                                        .width <
                                                    500
                                                ? 14
                                                : 15,
                                          ),
                                          onChanged: (value) {
                                            setState(() {
                                              code2error = false;
                                            });
                                          },
                                          cursorColor:
                                              const Color.fromRGBO(
                                                  21, 43, 81, 1),
                                          decoration:
                                              const InputDecoration(
                                            // enabledBorder:
                                            //     code2error
                                            //         ? OutlineInputBorder(
                                            //             borderRadius:
                                            //                 BorderRadius.circular(
                                            //                     10),
                                            //             borderSide:
                                            //                 BorderSide(
                                            //                     color: Colors.red), // Error border color
                                            //           )
                                            //         : InputBorder
                                            //             .none,
                                            border:
                                                InputBorder.none,
                                            contentPadding:
                                                EdgeInsets.all(
                                                    14),
                                            hintText:
                                                "Enter zip",
                                            hintStyle: _ownerHintStyle,
                                          ),
                                        ),
                                      ),
                                      if (code2error)
                                        _ownerErrorText(code2message),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                                  // SizedBox(
                                  //     height: MediaQuery.of(
                                  //         context)
                                  //         .size
                                  //         .height *
                                  //         0.01),
                                  //
                                  // if (selectedOwner !=
                                  //     null)
                                  //   Padding(
                                  //     padding: const EdgeInsets.only(left: 13),
                                  //     child: Column(
                                  //       crossAxisAlignment:
                                  //       CrossAxisAlignment
                                  //           .start,
                                  //       children: [
                                  //         if (selectedOwner!
                                  //             .processorList
                                  //             .isNotEmpty) ...[
                                  //           Row(
                                  //             children: [
                                  //               Text(
                                  //                 "Merchant Id",
                                  //                 style: TextStyle(
                                  //                     fontWeight:
                                  //                     FontWeight.bold,
                                  //                     color: Color(0xFF8A95A8),
                                  //                     fontSize: 14),
                                  //               ),
                                  //             ],
                                  //           ),
                                  //           SizedBox(
                                  //               height:
                                  //               5),
                                  //           Column(
                                  //             children: [
                                  //               Column(
                                  //                   children:
                                  //                   _processorGroups.map((group) {
                                  //                     return Padding(
                                  //                       padding: const EdgeInsets
                                  //                           .symmetric(
                                  //                           vertical: 8.0),
                                  //                       child:
                                  //                       Row(
                                  //                         children: [
                                  //                           SizedBox(
                                  //                             width: 20.0,
                                  //                             height: 20.0,
                                  //                             child: Checkbox(
                                  //                               value: group?.isChecked,
                                  //                               onChanged: (value) {
                                  //                                 setState(() {
                                  //                                   group?.isChecked = value ?? false;
                                  //                                   processor_id = group.controller.text;
                                  //                                 });
                                  //                               },
                                  //                               activeColor: blueColor,
                                  //                             ),
                                  //                           ),
                                  //                           SizedBox(width: MediaQuery.of(context).size.width * .02),
                                  //                           Expanded(
                                  //                             child: Material(
                                  //                               elevation: 3,
                                  //                               borderRadius: BorderRadius.circular(5),
                                  //                               child: Container(
                                  //                                 height: 50,
                                  //                                 decoration: BoxDecoration(
                                  //                                   borderRadius: BorderRadius.circular(5),
                                  //                                   color: Colors.white,
                                  //                                   border: Border.all(color: Color(0xFF8A95A8)),
                                  //                                 ),
                                  //                                 child: Stack(
                                  //                                   children: [
                                  //                                     Positioned.fill(
                                  //                                       child: TextField(
                                  //                                         controller: group.controller,
                                  //                                         cursorColor: blueColor,
                                  //                                         decoration: InputDecoration(
                                  //                                           border: InputBorder.none,
                                  //                                           contentPadding: EdgeInsets.only(top: 12.5, bottom: 12.5, left: 15),
                                  //                                           hintText: "Enter processor",
                                  //                                           hintStyle: TextStyle(
                                  //                                             color: Color(0xFF8A95A8),
                                  //                                             fontSize: 13,
                                  //                                           ),
                                  //                                         ),
                                  //                                       ),
                                  //                                     ),
                                  //                                   ],
                                  //                                 ),
                                  //                               ),
                                  //                             ),
                                  //                           ),
                                  //                           SizedBox(width: MediaQuery.of(context).size.width * .02),
                                  //                           InkWell(
                                  //                             onTap: () {
                                  //                               setState(() {
                                  //                                 _processorGroups.remove(group);
                                  //                               });
                                  //                             },
                                  //                             child: Container(
                                  //                               padding: EdgeInsets.zero,
                                  //                               child: FaIcon(
                                  //                                 FontAwesomeIcons.trashCan,
                                  //                                 size: 20,
                                  //                                 color: blueColor,
                                  //                               ),
                                  //                             ),
                                  //                           ),
                                  //                         ],
                                  //                       ),
                                  //                     );
                                  //                   }).toList())
                                  //             ],
                                  //           ),
                                  //           SizedBox(
                                  //               height: MediaQuery.of(context)
                                  //                   .size
                                  //                   .height *
                                  //                   0.01),
                                  //           Row(
                                  //             children: [
                                  //               // Handle error display here if needed
                                  //             ],
                                  //           ),
                                  //         ],
                                  //       ],
                                  //     ),
                                  //   ),
                                  // /*  Padding(
                                  //     padding: const EdgeInsets.only(left: 13),
                                  //     child: Column(
                                  //       crossAxisAlignment:
                                  //       CrossAxisAlignment
                                  //           .start,
                                  //       children: [
                                  //         if (selectedOwner == null || selectedOwner!.processorList.isEmpty)...[
                                  //           Row(
                                  //             children: [
                                  //               Text(
                                  //                 "Merchant Id",
                                  //                 style: TextStyle(
                                  //                     fontWeight:
                                  //                     FontWeight.bold,
                                  //                     color: Color(0xFF8A95A8),
                                  //                     fontSize: 14),
                                  //               ),
                                  //             ],
                                  //           ),
                                  //           SizedBox(
                                  //               height:
                                  //               5),
                                  //           Column(
                                  //             children: [
                                  //               Column(
                                  //                   children:
                                  //                   _processorGroups.map((group) {
                                  //                     return Padding(
                                  //                       padding: const EdgeInsets
                                  //                           .symmetric(
                                  //                           vertical: 8.0),
                                  //                       child:
                                  //                       Row(
                                  //                         children: [
                                  //                           SizedBox(
                                  //                             width: 20.0,
                                  //                             height: 20.0,
                                  //                             child: Checkbox(
                                  //                               value: group?.isChecked,
                                  //                               onChanged: (value) {
                                  //                                 setState(() {
                                  //                                   group?.isChecked = value ?? false;
                                  //                                   processor_id = group.controller.text;
                                  //                                 });
                                  //                               },
                                  //                               activeColor: blueColor,
                                  //                             ),
                                  //                           ),
                                  //                           SizedBox(width: MediaQuery.of(context).size.width * .02),
                                  //                           Expanded(
                                  //                             child: Material(
                                  //                               elevation: 3,
                                  //                               borderRadius: BorderRadius.circular(5),
                                  //                               child: Container(
                                  //                                 height: 50,
                                  //                                 decoration: BoxDecoration(
                                  //                                   borderRadius: BorderRadius.circular(5),
                                  //                                   color: Colors.white,
                                  //                                   border: Border.all(color: Color(0xFF8A95A8)),
                                  //                                 ),
                                  //                                 child: Stack(
                                  //                                   children: [
                                  //                                     Positioned.fill(
                                  //                                       child: TextField(
                                  //                                         controller: group.controller,
                                  //                                         cursorColor: blueColor,
                                  //                                         decoration: InputDecoration(
                                  //                                           border: InputBorder.none,
                                  //                                           contentPadding: EdgeInsets.only(top: 12.5, bottom: 12.5, left: 15),
                                  //                                           hintText: "Enter processor",
                                  //                                           hintStyle: TextStyle(
                                  //                                             color: Color(0xFF8A95A8),
                                  //                                             fontSize: 13,
                                  //                                           ),
                                  //                                         ),
                                  //                                       ),
                                  //                                     ),
                                  //                                   ],
                                  //                                 ),
                                  //                               ),
                                  //                             ),
                                  //                           ),
                                  //                           SizedBox(width: MediaQuery.of(context).size.width * .02),
                                  //                           InkWell(
                                  //                             onTap: () {
                                  //                               setState(() {
                                  //                                 _processorGroups.remove(group);
                                  //                               });
                                  //                             },
                                  //                             child: Container(
                                  //                               padding: EdgeInsets.zero,
                                  //                               child: FaIcon(
                                  //                                 FontAwesomeIcons.trashCan,
                                  //                                 size: 20,
                                  //                                 color: blueColor,
                                  //                               ),
                                  //                             ),
                                  //                           ),
                                  //                         ],
                                  //                       ),
                                  //                     );
                                  //                   }).toList())
                                  //             ],
                                  //           ),
                                  //           SizedBox(
                                  //               height: MediaQuery.of(context)
                                  //                   .size
                                  //                   .height *
                                  //                   0.01),
                                  //           Row(
                                  //             children: [
                                  //               // Handle error display here if needed
                                  //             ],
                                  //           ),
                                  //         ],
                                  //       ],
                                  //     ),
                                  //   ),
                                  // SizedBox(
                                  //     height: MediaQuery.of(
                                  //         context)
                                  //         .size
                                  //         .height *
                                  //         0.01),
                                  // Row(
                                  //   mainAxisAlignment:
                                  //   MainAxisAlignment
                                  //       .start,
                                  //   children: [
                                  //     SizedBox(width: 13,),
                                  //     GestureDetector(
                                  //       onTap: () {
                                  //         setState(() {
                                  //           _processorGroups.add(ProcessorGroup(
                                  //               isChecked:
                                  //               false,
                                  //               controller:
                                  //               TextEditingController()));
                                  //
                                  //         });
                                  //       },
                                  //       child:
                                  //       ClipRRect(
                                  //         borderRadius:
                                  //         BorderRadius
                                  //             .circular(
                                  //             5.0),
                                  //         child:
                                  //         Container(
                                  //           height:
                                  //           40.0,
                                  //           width: MediaQuery.of(context)
                                  //               .size
                                  //               .width *
                                  //               .3,
                                  //           decoration:
                                  //           BoxDecoration(
                                  //             borderRadius:
                                  //             BorderRadius.circular(
                                  //                 5.0),
                                  //             color: Color
                                  //                 .fromRGBO(
                                  //                 21,
                                  //                 43,
                                  //                 81,
                                  //                 1),
                                  //             boxShadow: [
                                  //               BoxShadow(
                                  //                 color:
                                  //                 Colors.grey,
                                  //                 offset: Offset(
                                  //                     0.0,
                                  //                     1.0), //(x,y)
                                  //                 blurRadius:
                                  //                 6.0,
                                  //               ),
                                  //             ],
                                  //           ),
                                  //           child:
                                  //           Center(
                                  //             child: isLoading
                                  //                 ? SpinKitFadingCircle(
                                  //               color: Colors.white,
                                  //               size: 25.0,
                                  //             )
                                  //                 : Text(
                                  //               "Add another",
                                  //               style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
                                  //             ),
                                  //           ),
                                  //         ),
                                  //       ),
                                  //     ),
                                  //   ],
                                  // ),*/
                          ],
                        ),
                      ],
                    ),
              const SizedBox(height: 16),
              _ownerActionBar(
                onCancel: () {
                  Navigator.pop(context);
                },
                onSubmit: isSubmitting
                          ? null
                          : () async {
                        if (firstname.text.trim().isEmpty) {
                          setState(() {
                            firstnameerror = true;
                            firstnamemessage = "Please enter name";
                          });
                        } else {
                          setState(() {
                            firstnameerror = false;
                          });
                        }
                        if (comname.text.trim().isEmpty) {
                          setState(() {
                            comnameerror = true;
                            comnamemessage = "Please enter company name";
                          });
                        } else {
                          setState(() {
                            comnameerror = false;
                          });
                        }
                        if (primaryemail.text.trim().isEmpty) {
                          setState(() {
                            primaryemailerror = true;
                            primaryemailmessage = "Email is required";
                          });
                        } else if (!EmailValidator.validate(
                            primaryemail.text)) {
                          setState(() {
                            primaryemailerror = true;
                            primaryemailmessage = "Email is not valid";
                          });
                        } else {
                          setState(() {
                            primaryemailerror = false;
                          });
                        }
                        if (alternativeemail.text.trim().isNotEmpty &&
                            !EmailValidator.validate(alternativeemail.text)) {
                          setState(() {
                            alternativeerror = true;
                            alternativemessage = "Email is not valid";
                          });
                        } else if (alternativeemail.text == primaryemail.text) {
                          setState(() {
                            alternativeerror = true;
                            alternativemessage = " email cannot be the same";
                          });
                        } else {
                          setState(() {
                            alternativeerror = false;
                            alternativemessage = "";
                          });
                        }

                        String formattedPhoneNumber =
                            phonenum.text.replaceAll(RegExp(r'\D'), '');
                        if (formattedPhoneNumber.isEmpty) {
                          setState(() {
                            phonenumerror = true;
                            phonenummessage = "Please enter phone number";
                          });
                        } else if (formattedPhoneNumber.length != 10) {
                          setState(() {
                            phonenumerror = true;
                            phonenummessage = "Phone number must be 10 digits";
                          });
                        } else {
                          setState(() {
                            phonenumerror = false;
                          });
                        }
                        String formattedhomeNumber =
                            homenum.text.replaceAll(RegExp(r'\D'), '');
                        if (formattedhomeNumber.isEmpty) {
                          setState(() {
                            homenumerror = false;
                          });
                        } else if (formattedhomeNumber.length != 10) {
                          setState(() {
                            homenumerror = true;
                            homenummessage = "Phone number must be 10 digits";
                          });
                        } else if (formattedhomeNumber ==
                            formattedPhoneNumber) {
                          setState(() {
                            homenumerror = true;
                            homenummessage = " number cannot be the same";
                          });
                        } else {
                          setState(() {
                            homenumerror = false;
                          });
                        }
                        String formattedofficeNumber =
                            businessnum.text.replaceAll(RegExp(r'\D'), '');
                        if (formattedofficeNumber.isEmpty) {
                          setState(() {
                            businessnumerror = false;
                          });
                        } else if (formattedofficeNumber.length != 10) {
                          setState(() {
                            businessnumerror = true;
                            businessnummessage =
                                "Phone number must be 10 digits";
                          });
                        } else if (formattedofficeNumber ==
                            formattedhomeNumber) {
                          setState(() {
                            businessnumerror = true;
                            businessnummessage = " number cannot be the same";
                          });
                        } else {
                          setState(() {
                            businessnumerror = false;
                          });
                        }
                        if (!firstnameerror &&
                            !comnameerror &&
                            !primaryemailerror &&
                            !phonenumerror &&
                            !primaryemailerror &&
                            !homenumerror &&
                            !businessnumerror &&
                            !alternativeerror) {
                          setState(() {
                            isSubmitting = true;
                          });
                          try {
                          var ownerSaved = false;
                          if (widget.isEdit == true || isChecked2) {
                            /* Fluttertoast.showToast(
                            msg:
                            "Rental Owner added Successfully!",
                            toastLength:
                            Toast
                                .LENGTH_SHORT,
                            gravity:
                            ToastGravity
                                .TOP,
                            timeInSecForIosWeb:
                            1,
                            backgroundColor:
                            Colors
                                .green,
                            textColor:
                            Colors
                                .white,
                            fontSize:
                            16.0,
                          );*/
                            List<ProcessorList> selectedProcessors =
                                _processorGroups
                                    .map((group) => ProcessorList(
                                        processorId: group.controller.text
                                            .trim())) // Create ProcessorList objects
                                    .where((processor) => processor.processorId!
                                        .isNotEmpty) // Filter out empty IDs
                                    .toList();
                            SharedPreferences prefs =
                                await SharedPreferences.getInstance();
                            var adminId = prefs.getString("adminId");
                            Ownersdetails = RentalOwner(
                              rentalOwnerId: selectedOwner?.rentalOwnerId,
                              rentalOwnerPhoneNumber: phonenum.text.trim(),
                              rentalOwnerName: firstname.text.trim(),
                              rentalOwnerCompanyName: comname.text.trim(),
                              rentalOwnerPrimaryEmail: primaryemail.text.trim(),
                              rentalOwnerAlternateEmail:
                                  alternativeemail.text.trim(),
                              rentalOwnerHomeNumber: homenum.text.trim(),
                              rentalOwnerBusinessNumber:
                                  businessnum.text.trim(),
                              streetAddress: street2.text.trim(),
                              city: city2.text.trim(),
                              country: county2.text.trim(),
                              state: state2.text.trim(),
                              postalCode: code2.text.trim(),
                              processorList: selectedProcessors,
                            );
                            if (!mounted) return;
                            context
                                .read<OwnerDetailsProvider>()
                                .setOwnerDetails(Ownersdetails!);
                            ownerSaved = true;
                            // context
                            //     .read<
                            //     OwnerDetailsProvider>()
                            //     .selectedprocessid(
                            //     processor_id!);
                            /* context
                              .read<
                              OwnerDetailsProvider>()
                              .selectedprocessid(
                              processor_id!);*/
                            // Navigator.pop(
                            //     context);
                          } else {
                            var response = await Rental_PropertiesRepository()
                                .checkIfRentalOwnerExists(
                              rentalOwner_name: firstname.text,
                              rentalOwner_companyName: comname.text,
                              rentalOwner_primaryEmail: primaryemail.text,
                              rentalOwner_alternativeEmail:
                                  alternativeemail.text,
                              rentalOwner_phoneNumber: phonenum.text,
                              rentalOwner_homeNumber: homenum.text,
                              rentalOwner_businessNumber: businessnum.text,
                            );
                            if (response == true) {
                              List<ProcessorList> selectedProcessors =
                                  _processorGroups
                                      //  .where((group) => group.isChecked)
                                      .map((group) => ProcessorList(
                                          processorId: group.controller.text
                                              .trim())) // Create ProcessorList objects
                                      .where((processor) => processor
                                          .processorId!
                                          .isNotEmpty) // Filter out empty IDs
                                      .toList();
                              SharedPreferences prefs =
                                  await SharedPreferences.getInstance();
                              var adminId = prefs.getString("adminId");
                              Ownersdetails = RentalOwner(
                                adminId: adminId,
                                //  rentalOwnerId: selectedOwner!.rentalOwnerId,
                                rentalOwnerPhoneNumber: phonenum.text,
                                rentalOwnerName: firstname.text,
                                rentalOwnerCompanyName: comname.text,
                                rentalOwnerPrimaryEmail: primaryemail.text,
                                rentalOwnerAlternateEmail:
                                    alternativeemail.text,
                                rentalOwnerHomeNumber: homenum.text,
                                rentalOwnerBusinessNumber: businessnum.text,
                                streetAddress: street2.text,
                                city: city2.text,
                                country: county2.text,
                                state: state2.text,
                                postalCode: code2.text,
                                processorList: selectedProcessors,
                              );
                              if (!mounted) return;
                              context
                                  .read<OwnerDetailsProvider>()
                                  .setOwnerDetails(Ownersdetails!);
                              ownerSaved = true;
                              Fluttertoast.showToast(
                                msg: _isEditingOwner
                                    ? "Rental Owner Updated Successfully!"
                                    : "Rental Owner Added Successfully!",
                                toastLength: Toast.LENGTH_SHORT,
                                gravity: ToastGravity.TOP,
                                timeInSecForIosWeb: 1,
                                backgroundColor: Colors.green,
                                textColor: Colors.white,
                                fontSize: 16.0,
                              );
                            } else {
                              Fluttertoast.showToast(
                                msg: "Rental Owner Already Exists!",
                                toastLength: Toast.LENGTH_SHORT,
                                gravity: ToastGravity.TOP,
                                timeInSecForIosWeb: 1,
                                backgroundColor: Colors.red,
                                textColor: Colors.white,
                                fontSize: 16.0,
                              );
                            }
                          }
                          if (ownerSaved) {
                            setState(() {
                              hasError = false;
                            });
                            if (mounted) {
                              Navigator.pop(context);
                            }
                          }
                          } catch (_) {
                            Fluttertoast.showToast(
                              msg: "Failed to add rental owner",
                              toastLength: Toast.LENGTH_SHORT,
                              gravity: ToastGravity.TOP,
                              timeInSecForIosWeb: 1,
                              backgroundColor: Colors.red,
                              textColor: Colors.white,
                              fontSize: 16.0,
                            );
                          } finally {
                            if (mounted) {
                              setState(() {
                                isSubmitting = false;
                              });
                            }
                          }
                        }
                      },
                submitChild: isSubmitting
                    ? const SpinKitFadingCircle(
                        color: Colors.white,
                        size: 25.0,
                      )
                    : Text(
                        _isEditingOwner ? "Update" : "Add",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---- Redesign helpers (house card system; copied by the sibling
  // Add/Edit Rental Owner screens). Inputs stay the screen's own TextFields;
  // these only draw the shell around them.

  BoxDecoration _ownerCardDecoration({
    required double radius,
    Color borderColor = _ownerBorder,
    double borderWidth = 1,
  }) {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: borderColor, width: borderWidth),
      boxShadow: const [
        BoxShadow(
          color: Color(0x08000000),
          blurRadius: 8,
          offset: Offset(0, 2),
        ),
      ],
    );
  }

  Widget _ownerTitleBar(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: _ownerNavy2,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
      ),
    );
  }

  Widget _ownerCheckbox({
    required bool value,
    required ValueChanged<bool?> onChanged,
  }) {
    return SizedBox(
      width: 24,
      height: 24,
      child: Checkbox(
        value: value,
        onChanged: onChanged,
        activeColor: _ownerNavy,
        checkColor: Colors.white,
        side: const BorderSide(color: _ownerCheckOff, width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
        ),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Widget _ownerCheckCard({
    required bool value,
    required String label,
    required ValueChanged<bool?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _ownerCardDecoration(radius: 16),
      child: Row(
        children: [
          _ownerCheckbox(value: value, onChanged: onChanged),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: _ownerNavy,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _ownerSectionCard({
    required String title,
    bool required = false,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: _ownerCardDecoration(radius: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            required ? '$title *' : title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: _ownerNavy,
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _ownerFieldLabel(String text, {bool required = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        required ? '$text *' : text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: _ownerNavy,
        ),
      ),
    );
  }

  /// Shell for the screen's existing TextField: white, 1px input outline,
  /// radius 10, height 50 — the same box UsStateDropdown draws.
  Widget _ownerInput({required Widget child}) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _ownerInputBorder, width: 1),
      ),
      child: Stack(
        children: [
          Positioned.fill(child: child),
        ],
      ),
    );
  }

  Widget _ownerErrorText(String message) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        message,
        style: const TextStyle(color: Colors.red),
      ),
    );
  }

  Widget _ownerSearchBox({required Widget child}) {
    return Container(
      height: 50,
      padding: const EdgeInsets.only(left: 14, right: 8),
      decoration: _ownerCardDecoration(radius: 14),
      child: Row(
        children: [
          const Icon(Icons.search, color: _ownerFaint, size: 22),
          const SizedBox(width: 8),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _ownerListHeader({required String left, required String right}) {
    const style = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.bold,
      color: _ownerNavy,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _ownerTint,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(child: Text(left, style: style)),
          const SizedBox(width: 12),
          // Same 56px column as the row checkbox, so it sits under "Select".
          SizedBox(width: 56, child: Center(child: Text(right, style: style))),
        ],
      ),
    );
  }

  Widget _ownerListRow({
    required String name,
    required String phone,
    required bool selected,
    required ValueChanged<bool?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _ownerCardDecoration(
        radius: 14,
        borderColor: selected ? _ownerNavy : _ownerBorder,
        borderWidth: selected ? 1.5 : 1,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _ownerNavy,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  phone,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _ownerMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 56,
            child: Center(
                child: _ownerCheckbox(value: selected, onChanged: onChanged)),
          ),
        ],
      ),
    );
  }

  Widget _ownerActionBar({
    required VoidCallback onCancel,
    required VoidCallback? onSubmit,
    required Widget submitChild,
  }) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: onCancel,
            child: Container(
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _ownerBorder),
              ),
              child: const Text(
                "Cancel",
                style: TextStyle(
                  color: _ownerNavy,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: onSubmit,
            child: Container(
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _ownerNavy2,
                borderRadius: BorderRadius.circular(12),
              ),
              child: submitChild,
            ),
          ),
        ),
      ],
    );
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
    final list = json['processor_list'];
    List<Processor> processorList = [];
    if (list is List) {
      processorList = list.map((i) => Processor.fromJson(i)).toList();
    }

    return Owner(
      id: json['_id'] ?? "",
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
      isDelete: json['is_delete'] ?? false,
      processorList: processorList,
    );
  }
}

class Processor {
  final String processorId;
  final String id;

  Processor({required this.processorId, required this.id});

  factory Processor.fromJson(Map<String, dynamic> json) {
    return Processor(
      processorId: json['processor_id'] ?? "",
      id: json['_id'] ?? "",
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

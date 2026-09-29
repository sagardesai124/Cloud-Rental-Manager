import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:three_zero_two_property/services/api_helpers.dart';
import 'package:three_zero_two_property/widgets/clearable_date_picker.dart';
import 'package:three_zero_two_property/widgets/clearable_date_suffix.dart';
import 'package:email_validator/email_validator.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:keyboard_actions/keyboard_actions.dart';
import 'package:keyboard_actions/keyboard_actions_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../constant/constant.dart';
import '../../../widgets/appbar.dart';
import 'package:three_zero_two_property/widgets/us_state_dropdown.dart';

import '../../../../Model/RentalOwnersData.dart';
import '../../../repository/Rental_ownersData.dart';
import '../../../repository/Staffmember.dart';
import '../../../widgets/drawer_tiles.dart';
import '../../../widgets/custom_drawer.dart';
import '../../../../provider/dateProvider.dart';
import 'package:provider/provider.dart';

class Add_rentalowners extends StatefulWidget {
  const Add_rentalowners({super.key});

  @override
  State<Add_rentalowners> createState() => _Add_rentalownersState();
}

class _Add_rentalownersState extends State<Add_rentalowners> {
  TextEditingController name = TextEditingController();
  TextEditingController lastname = TextEditingController();
  TextEditingController comname = TextEditingController();
  TextEditingController primaryemail = TextEditingController();
  TextEditingController alternativeemail = TextEditingController();
  TextEditingController phonenum = TextEditingController();
  TextEditingController homenum = TextEditingController();
  TextEditingController businessnum = TextEditingController();
  TextEditingController officenum = TextEditingController();
  TextEditingController street2 = TextEditingController();
  TextEditingController city2 = TextEditingController();
  TextEditingController state2 = TextEditingController();
  TextEditingController county2 = TextEditingController();
  TextEditingController code2 = TextEditingController();
  TextEditingController proid = TextEditingController();
  TextEditingController taxtype = TextEditingController();
  TextEditingController taxid = TextEditingController();
  TextEditingController achProcessorId = TextEditingController();

  bool nameerror = false;
  bool lastnameerror = false;
  bool comnameerror = false;
  bool primaryemailerror = false;
  bool alternativeerror = false;
  bool phonenumerror = false;
  bool homenumerror = false;
  bool businessnumerror = false;
  bool officenumerror = false;
  bool street2error = false;
  bool city2error = false;
  bool state2error = false;
  bool county2error = false;
  bool code2error = false;
  bool proiderror = false;
  bool taxtypeerror = false;
  bool taxiderror = false;

  String namemessage = "";
  String lastnamemessage = "";
  String comnamemessage = "";
  String primaryemailmessage = "";
  String alternativemessage = "";
  String phonenummessage = "";
  String homenummessage = "";
  String businessnummessage = "";
  String officenummessage = "";
  String street2message = "";
  String city2message = "";
  String state2message = "";
  String county2message = "";
  String code2message = "";
  String proidmessage = "";
  String taxtypemessage = "";
  String taxidmessage = "";

  bool loading = false;
  Map<int, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    // Initialize with one text field
    _controllers[0] = TextEditingController();
  }

  @override
  void dispose() {
    // Every controller created by this State is released here. These
    // screens use plain TextField, which never disposes a controller it
    // is given, so the State owns them outright — nothing else can free
    // them and nothing else can double-free them.
    name.dispose();
    lastname.dispose();
    comname.dispose();
    primaryemail.dispose();
    alternativeemail.dispose();
    phonenum.dispose();
    homenum.dispose();
    businessnum.dispose();
    officenum.dispose();
    street2.dispose();
    city2.dispose();
    state2.dispose();
    county2.dispose();
    code2.dispose();
    proid.dispose();
    taxtype.dispose();
    taxid.dispose();
    achProcessorId.dispose();
    birthdateController.dispose();
    startdateController.dispose();
    enddateController.dispose();
    // The dynamically added rows keep their controllers in this map.
    for (final c in _controllers.values) {
      c.dispose();
    }
    _controllers.clear();
    super.dispose();
  }


  // Add a text field
  void _addTextField() {
    // Next unused key, not the row count. `.length` collided after any
    // middle removal: keys {0,1,2,3} minus 1 leaves {0,2,3}, whose length is
    // 3, so the new row reused key 3 and overwrote the live controller for
    // that row — silently wiping an email the user had typed, both on screen
    // and in the saved payload, and leaking the replaced controller.
    int nextIndex = _controllers.isEmpty
        ? 0
        : (_controllers.keys.reduce((a, b) => a > b ? a : b) + 1);
    setState(() {
      _controllers[nextIndex] = TextEditingController();
    });
  }

  // Remove a text field
  void _removeTextField(int index) {
    setState(() {
      // Free it before dropping the reference, otherwise the
      // controller for a removed row leaks for the screen's lifetime.
      _controllers[index]?.dispose();
      _controllers.remove(index);
    });
  }

  TextEditingController birthdateController = TextEditingController();
  TextEditingController startdateController = TextEditingController();
  TextEditingController enddateController = TextEditingController();

  bool birthdateerror = false;
  bool startdatederror = false;
  bool enddatederror = false;

  String birthdatemessage = "";
  String startdatemessage = "";
  String enddatemessage = "";

  DateTime? birthdate;
  DateTime? startdate;
  DateTime? enddate;

  Future<void> _birthDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: birthdate ?? DateTime.now(),
      firstDate: DateTime(1900, 1),
      lastDate: DateTime.now(),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: blueColor, // Header background color
            // accentColor: Colors.white, // Button text color
            colorScheme: ColorScheme.light(
              primary: blueColor, // Selection color
              onPrimary: Colors.white, // Text color
              surface: Colors.white, // Calendar background color
              onSurface: Colors.black, // Calendar text color
            ),
            dialogBackgroundColor: Colors.white, // Background color
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != birthdate) {
      setState(() {
        birthdate = picked;
        // Get dateProvider to format the date according to user's preference
        final dateProvider = Provider.of<DateProvider>(context, listen: false);
        // Display format: Use provider's format for user display
        birthdateController.text =
            DateFormat(dateProvider.dateFormat).format(picked);
      });
    }
  }

  void _clearStartDate() {
    setState(() {
      startdate = null;
      startdateController.clear();
      startdatederror = false;
    });
  }

  void _clearEndDate() {
    setState(() {
      enddate = null;
      enddateController.clear();
      enddatederror = false;
    });
  }

  Future<void> _startDate(BuildContext context) async {
    final ClearableDatePickerResult? result = await showClearableDatePicker(
      context: context,
      initialDate: startdate ?? DateTime.now(),
      firstDate: DateTime(2015, 8),
      lastDate: DateTime(2101),
      helpText: 'Select start date',
    );
    if (result == null) return; // cancelled — keep the current value
    if (result.cleared) {
      _clearStartDate();
      return;
    }
    final DateTime picked = result.date!;
    if (picked != startdate) {
      setState(() {
        startdate = picked;
        // Get dateProvider to format the date according to user's preference
        final dateProvider = Provider.of<DateProvider>(context, listen: false);
        // Display format: Use provider's format for user display
        startdateController.text =
            DateFormat(dateProvider.dateFormat).format(picked);
      });
    }
  }

  Future<void> _endDate(BuildContext context) async {
    final ClearableDatePickerResult? result = await showClearableDatePicker(
      context: context,
      initialDate: enddate ?? DateTime.now(),
      firstDate: startdate ?? DateTime.now(),
      // firstDate: DateTime(2015, 8),
      lastDate: DateTime(2101),
      helpText: 'Select end date',
    );
    if (result == null) return; // cancelled — keep the current value
    if (result.cleared) {
      _clearEndDate();
      return;
    }
    final DateTime picked = result.date!;
    if (picked != enddate) {
      setState(() {
        enddate = picked;
        // Get dateProvider to format the date according to user's preference
        final dateProvider = Provider.of<DateProvider>(context, listen: false);
        // Display format: Use provider's format for user display
        enddateController.text =
            DateFormat(dateProvider.dateFormat).format(picked);
      });
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

  bool creditcard = true;
  bool achaccepted = false;
  bool debitcard = true;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBar: widget302.,
      appBar: widget_302_Staff.App_Bar(context: context),
      backgroundColor: Colors.white,
      drawer: CustomDrawerStaff(
        currentpage: "Rental Owner",
        dropdown: true,
      ),
      body: ListView(
        scrollDirection: Axis.vertical,
        children: [
          Padding(
            padding: const EdgeInsets.all(15.0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(5.0),
              child: Container(
                height: 50.0,
                padding: const EdgeInsets.only(top: 9, left: 10),
                width: MediaQuery.of(context).size.width * .99,
                margin: const EdgeInsets.only(bottom: 6.0),
                //Same as `blurRadius` i guess
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(5.0),
                  color: blueColor,
                  boxShadow: [
                    const BoxShadow(
                      color: Colors.grey,
                      offset: Offset(0.0, 1.0), //(x,y)
                      blurRadius: 6.0,
                    ),
                  ],
                ),
                child: const Text(
                  "Add Rental Owners ",
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18),
                ),
              ),
            ),
          ),
          //Personal information
          Padding(
            padding: const EdgeInsets.only(left: 15, right: 15),
            child: Material(
              //  elevation: 6,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFCED4DA)),
                ),
                child: Padding(
                  padding: const EdgeInsets.only(
                      left: 10, right: 10, top: 10, bottom: 20),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const SizedBox(
                            width: 2,
                          ),
                          Text(
                            "Personal Information",
                            style: TextStyle(
                                color: const Color(0xFF152B51),
                                fontWeight: FontWeight.bold,
                                // fontSize: 18
                                fontSize:
                                    MediaQuery.of(context).size.width < 500
                                        ? 20
                                        : 25),
                          ),
                        ],
                      ),
                      const SizedBox(
                        height: 10,
                      ),
                      //first name
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const SizedBox(width: 2),
                              Expanded(
                                child: Container(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Name *",
                                        style: TextStyle(
                                            color: const Color(0xFF101828),
                                            fontWeight: FontWeight.bold,
                                            fontSize: MediaQuery.of(context)
                                                        .size
                                                        .width <
                                                    500
                                                ? 15
                                                : 20),
                                      ),
                                      Material(
                                        // elevation: 4,
                                        child: Container(
                                          height: 50,
                                          // width: MediaQuery.of(context)
                                          //         .size
                                          //         .width *
                                          //     .6,
                                          decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            border: Border.all(
                                              color: const Color(0xFFCED4DA),
                                            ),
                                          ),
                                          child: Stack(
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
                                                    hintText: "Enter name",
                                                    hintStyle: TextStyle(
                                                      fontSize:
                                                          MediaQuery.of(context)
                                                                      .size
                                                                      .width <
                                                                  500
                                                              ? 15
                                                              : 19,
                                                      color: const Color(
                                                          0xFFA1A8B0),
                                                    ),
                                                    enabledBorder: nameerror
                                                        ? OutlineInputBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        10),
                                                            borderSide:
                                                                const BorderSide(
                                                              color: Colors.red,
                                                            ),
                                                          )
                                                        : InputBorder.none,
                                                    border: InputBorder.none,
                                                    contentPadding: EdgeInsets
                                                        .all(MediaQuery.of(
                                                                        context)
                                                                    .size
                                                                    .width <
                                                                500
                                                            ? 14
                                                            : 11),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Container(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Company Name *",
                                        style: TextStyle(
                                            // color: Colors.grey,
                                            color: const Color(0xFF101828),
                                            fontWeight: FontWeight.bold,
                                            fontSize: MediaQuery.of(context)
                                                        .size
                                                        .width <
                                                    500
                                                ? 15
                                                : 20),
                                      ),
                                      Material(
                                        // elevation: 4,
                                        child: Container(
                                          height: 50,
                                          // width: MediaQuery.of(context)
                                          //         .size
                                          //         .width *
                                          //     .6,
                                          decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            border: Border.all(
                                              color: const Color(0xFFCED4DA),
                                            ),
                                          ),
                                          child: Stack(
                                            children: [
                                              Positioned.fill(
                                                child: TextField(
                                                  onChanged: (value) {
                                                    setState(() {
                                                      comnameerror = false;
                                                    });
                                                  },
                                                  controller: comname,
                                                  cursorColor: blueColor,
                                                  decoration: InputDecoration(
                                                    hintText:
                                                        "Enter company name",
                                                    hintStyle: TextStyle(
                                                      fontSize:
                                                          MediaQuery.of(context)
                                                                      .size
                                                                      .width <
                                                                  500
                                                              ? 15
                                                              : 19,
                                                      color: const Color(
                                                          0xFFA1A8B0),
                                                    ),
                                                    enabledBorder: comnameerror
                                                        ? OutlineInputBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        10),
                                                            borderSide:
                                                                const BorderSide(
                                                              color: Colors.red,
                                                            ),
                                                          )
                                                        : InputBorder.none,
                                                    border: InputBorder.none,
                                                    contentPadding: EdgeInsets
                                                        .all(MediaQuery.of(
                                                                        context)
                                                                    .size
                                                                    .width <
                                                                500
                                                            ? 14
                                                            : 11),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: nameerror
                                    ? Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Container(
                                          alignment: Alignment
                                              .centerLeft, // Ensure left alignment
                                          child: Text(
                                            namemessage,
                                            style: TextStyle(
                                              color: Colors.red,
                                              fontSize: MediaQuery.of(context)
                                                      .size
                                                      .width *
                                                  0.035,
                                            ),
                                          ),
                                        ),
                                      )
                                    : const SizedBox.shrink(),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: comnameerror
                                    ? Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Container(
                                          alignment: Alignment
                                              .centerLeft, // Ensure left alignment
                                          child: Text(
                                            comnamemessage,
                                            style: TextStyle(
                                              color: Colors.red,
                                              fontSize: MediaQuery.of(context)
                                                      .size
                                                      .width *
                                                  0.035,
                                            ),
                                          ),
                                        ),
                                      )
                                    : const SizedBox.shrink(),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(
            height: 15,
          ),
          //merchent id
          Padding(
            padding: const EdgeInsets.only(left: 15, right: 15),
            child: Material(
              // elevation: 6,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFCED4DA)),
                ),
                child: Padding(
                  padding: const EdgeInsets.only(
                      left: 10, right: 10, top: 10, bottom: 10),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const SizedBox(
                            width: 2,
                          ),
                          Text(
                            "Merchant ID",
                            style: TextStyle(
                                color: const Color(0xFF152B51),
                                fontWeight: FontWeight.bold,
                                // fontSize: 18
                                fontSize:
                                    MediaQuery.of(context).size.width < 500
                                        ? 20
                                        : 25),
                          ),
                        ],
                      ),
                      const SizedBox(
                        height: 10,
                      ),
                      Row(
                        children: [
                          const SizedBox(
                            width: 2,
                          ),
                          Text(
                            "Processor Id",
                            style: TextStyle(
                                color: const Color(0xFF101828),
                                fontWeight: FontWeight.bold,
                                fontSize:
                                    MediaQuery.of(context).size.width < 500
                                        ? 15
                                        : 20),
                          ),
                        ],
                      ),
                      const SizedBox(
                        height: 5,
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 1, right: 1),
                        child: Column(
                          children: [
                            Column(
                              children: _controllers.entries.map((entry) {
                                return Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 8.0),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Material(
                                          // elevation: 3,
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          child: Container(
                                            height: 50,
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              color: Colors.white,
                                              border: Border.all(
                                                  color:
                                                      const Color(0xFFCED4DA)),
                                            ),
                                            child: Stack(
                                              children: [
                                                Positioned.fill(
                                                  child: TextField(
                                                    controller: entry.value,
                                                    cursorColor: blueColor,
                                                    decoration: InputDecoration(
                                                      border: InputBorder.none,
                                                      contentPadding:
                                                          const EdgeInsets.only(
                                                              top: 12.5,
                                                              bottom: 12.5,
                                                              left: 15),
                                                      hintText:
                                                          "Enter processor",
                                                      hintStyle: TextStyle(
                                                        color: const Color(
                                                            0xFFA1A8B0),
                                                        fontSize: MediaQuery.of(
                                                                        context)
                                                                    .size
                                                                    .width <
                                                                500
                                                            ? 15
                                                            : 19,
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
                                          width: MediaQuery.of(context)
                                                  .size
                                                  .width *
                                              .02),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),

                            /*  Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    _addTextField();
                                  },
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(5.0),
                                    child: Container(
                                      height:
                                          MediaQuery.of(context).size.width <
                                                  500
                                              ? 35
                                              : 40,
                                      width: MediaQuery.of(context).size.width <
                                              500
                                          ? 120
                                          : 180,
                                      decoration: BoxDecoration(
                                        borderRadius:
                                            BorderRadius.circular(5.0),
                                        color: blueColor,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.grey,
                                            offset: Offset(0.0, 1.0), //(x,y)
                                            blurRadius: 6.0,
                                          ),
                                        ],
                                      ),
                                      child: Center(
                                        child: Text(
                                          "Add another",
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: MediaQuery.of(context)
                                                          .size
                                                          .width <
                                                      500
                                                  ? 13
                                                  : 20),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),*/
                            const SizedBox(
                              height: 15,
                            ),
                            Row(
                              children: [
                                const SizedBox(
                                  width: 2,
                                ),
                                Text(
                                  "ACH Processor ID",
                                  style: TextStyle(
                                      color: const Color(0xFF101828),
                                      fontWeight: FontWeight.bold,
                                      fontSize:
                                          MediaQuery.of(context).size.width <
                                                  500
                                              ? 15
                                              : 20),
                                ),
                              ],
                            ),
                            const SizedBox(
                              height: 5,
                            ),
                            Material(
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                height: 50,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  color: Colors.white,
                                  border: Border.all(
                                      color: const Color(0xFFCED4DA)),
                                ),
                                child: Stack(
                                  children: [
                                    Positioned.fill(
                                      child: TextField(
                                        controller: achProcessorId,
                                        cursorColor: blueColor,
                                        decoration: InputDecoration(
                                          border: InputBorder.none,
                                          contentPadding: const EdgeInsets.only(
                                              top: 12.5,
                                              bottom: 12.5,
                                              left: 15),
                                          hintText: "Enter ACH Processor ID",
                                          hintStyle: TextStyle(
                                            color: const Color(0xFFA1A8B0),
                                            fontSize: MediaQuery.of(context)
                                                        .size
                                                        .width <
                                                    500
                                                ? 15
                                                : 19,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
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
          ),

          const SizedBox(
            height: 15,
          ),
          //management agreement
          Padding(
            padding: const EdgeInsets.only(left: 15, right: 15),
            child: Material(
              // elevation: 6,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFCED4DA)),
                ),
                child: Padding(
                  padding: const EdgeInsets.only(
                      left: 10, right: 10, top: 10, bottom: 20),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const SizedBox(
                            width: 2,
                          ),
                          Text(
                            "Management Agreement ",
                            style: TextStyle(
                                color: const Color(0xFF152B51),
                                fontWeight: FontWeight.bold,
                                // fontSize: 18
                                fontSize:
                                    MediaQuery.of(context).size.width < 500
                                        ? 20
                                        : 25),
                          ),
                        ],
                      ),
                      const SizedBox(
                        height: 10,
                      ),
                      if (MediaQuery.of(context).size.width < 500)
                        Column(
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(width: 2),
                                Expanded(
                                  child: Container(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "Start Date ",
                                          style: TextStyle(
                                              color: const Color(0xFF101828),
                                              fontWeight: FontWeight.bold,
                                              fontSize: MediaQuery.of(context)
                                                          .size
                                                          .width <
                                                      500
                                                  ? 15
                                                  : 20),
                                        ),
                                        Material(
                                          //  elevation: 4,
                                          child: Container(
                                            height: 50,
                                            //  width: MediaQuery.of(context).size.width * .6,
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              border: Border.all(
                                                color: const Color(0xFFCED4DA),
                                              ),
                                            ),
                                            child: Stack(
                                              children: [
                                                Positioned.fill(
                                                  child: TextField(
                                                    onChanged: (value) {
                                                      setState(() {
                                                        startdatederror = false;
                                                        // _selectDate(context);
                                                      });
                                                    },
                                                    controller:
                                                        startdateController,
                                                    cursorColor: blueColor,
                                                    decoration: InputDecoration(
                                                      hintText: Provider.of<
                                                                  DateProvider>(
                                                              context,
                                                              listen: false)
                                                          .dateFormat
                                                          .toUpperCase(),
                                                      hintStyle: TextStyle(
                                                        fontSize: MediaQuery.of(
                                                                        context)
                                                                    .size
                                                                    .width <
                                                                500
                                                            ? 15
                                                            : 18,
                                                        color: const Color(
                                                            0xFFA1A8B0),
                                                      ),
                                                      enabledBorder:
                                                          startdatederror
                                                              ? OutlineInputBorder(
                                                                  borderRadius:
                                                                      BorderRadius
                                                                          .circular(
                                                                              10),
                                                                  borderSide:
                                                                      const BorderSide(
                                                                    color: Colors
                                                                        .red,
                                                                  ),
                                                                )
                                                              : InputBorder
                                                                  .none,
                                                      border: InputBorder.none,
                                                      contentPadding:
                                                          const EdgeInsets.all(
                                                              12),
                                                      suffixIcon:
                                                          ClearableDateSuffix(
                                                        controller:
                                                            startdateController,
                                                        onPick: () {
                                                          _startDate(context);
                                                          setState(() {
                                                            startdatederror =
                                                                false;
                                                          });
                                                        },
                                                        onClear:
                                                            _clearStartDate,
                                                        iconSize: 20,
                                                      ),
                                                    ),
                                                    readOnly: true,
                                                    onTap: () {
                                                      _startDate(context);
                                                      setState(() {
                                                        startdatederror = false;
                                                      });
                                                    },
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Container(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "End Date",
                                          style: TextStyle(
                                              // color: Colors.grey,
                                              color: const Color(0xFF101828),
                                              fontWeight: FontWeight.bold,
                                              fontSize: MediaQuery.of(context)
                                                          .size
                                                          .width <
                                                      500
                                                  ? 15
                                                  : 20),
                                        ),
                                        Material(
                                          //elevation: 4,
                                          child: Container(
                                            height: 50,
                                            // width: MediaQuery.of(context).size.width * .6,
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              border: Border.all(
                                                color: const Color(0xFFCED4DA),
                                              ),
                                            ),
                                            child: Stack(
                                              children: [
                                                Positioned.fill(
                                                  child: TextField(
                                                    onChanged: (value) {
                                                      setState(() {
                                                        enddatederror = false;
                                                        // _selectDate(context);
                                                      });
                                                    },
                                                    controller:
                                                        enddateController,
                                                    cursorColor: blueColor,
                                                    decoration: InputDecoration(
                                                      hintText: Provider.of<
                                                                  DateProvider>(
                                                              context,
                                                              listen: false)
                                                          .dateFormat
                                                          .toUpperCase(),
                                                      hintStyle: TextStyle(
                                                        fontSize: MediaQuery.of(
                                                                        context)
                                                                    .size
                                                                    .width <
                                                                500
                                                            ? 15
                                                            : 18,
                                                        color: const Color(
                                                            0xFFA1A8B0),
                                                      ),
                                                      enabledBorder: enddatederror
                                                          ? OutlineInputBorder(
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          10),
                                                              borderSide:
                                                                  const BorderSide(
                                                                color:
                                                                    Colors.red,
                                                              ),
                                                            )
                                                          : InputBorder.none,
                                                      border: InputBorder.none,
                                                      contentPadding:
                                                          const EdgeInsets.all(
                                                              12),
                                                      suffixIcon:
                                                          ClearableDateSuffix(
                                                        controller:
                                                            enddateController,
                                                        onPick: () =>
                                                            _endDate(context),
                                                        onClear: _clearEndDate,
                                                        iconSize: 20,
                                                      ),
                                                    ),
                                                    readOnly: true,
                                                    onTap: () {
                                                      _endDate(context);
                                                      setState(() {
                                                        enddatederror = false;
                                                      });
                                                    },
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: startdatederror
                                      ? Padding(
                                          padding:
                                              const EdgeInsets.only(top: 4),
                                          child: Container(
                                            alignment: Alignment
                                                .centerLeft, // Ensure left alignment
                                            child: Text(
                                              startdatemessage,
                                              style: TextStyle(
                                                color: Colors.red,
                                                fontSize: MediaQuery.of(context)
                                                        .size
                                                        .width *
                                                    0.035,
                                              ),
                                            ),
                                          ),
                                        )
                                      : const SizedBox.shrink(),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: enddatederror
                                      ? Padding(
                                          padding:
                                              const EdgeInsets.only(top: 4),
                                          child: Container(
                                            alignment: Alignment
                                                .centerLeft, // Ensure left alignment
                                            child: Text(
                                              enddatemessage,
                                              style: TextStyle(
                                                color: Colors.red,
                                                fontSize: MediaQuery.of(context)
                                                        .size
                                                        .width *
                                                    0.035,
                                              ),
                                            ),
                                          ),
                                        )
                                      : const SizedBox.shrink(),
                                ),
                              ],
                            ),
                          ],
                        ),
                      if (MediaQuery.of(context).size.width > 500)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 5.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // First Column
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Start Date",
                                      style: TextStyle(
                                          color: const Color(0xFF8A95A8),
                                          fontWeight: FontWeight.bold,
                                          fontSize: MediaQuery.of(context)
                                                      .size
                                                      .width <
                                                  500
                                              ? 15
                                              : 20),
                                    ),
                                    const SizedBox(height: 5),
                                    Material(
                                      elevation: 4,
                                      child: Container(
                                        height: 50,
                                        width:
                                            MediaQuery.of(context).size.width *
                                                .6,
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(2),
                                          border: Border.all(
                                            color: const Color(0xFF8A95A8),
                                          ),
                                        ),
                                        child: Stack(
                                          children: [
                                            Positioned.fill(
                                              child: TextField(
                                                onChanged: (value) {
                                                  setState(() {
                                                    startdatederror = false;
                                                    // _selectDate(context);
                                                  });
                                                },
                                                controller: startdateController,
                                                cursorColor: blueColor,
                                                decoration: InputDecoration(
                                                  hintText:
                                                      Provider.of<DateProvider>(
                                                              context,
                                                              listen: false)
                                                          .dateFormat
                                                          .toUpperCase(),
                                                  hintStyle: TextStyle(
                                                    fontSize:
                                                        MediaQuery.of(context)
                                                                    .size
                                                                    .width <
                                                                500
                                                            ? 15
                                                            : 18,
                                                    color:
                                                        const Color(0xFF8A95A8),
                                                  ),
                                                  enabledBorder: startdatederror
                                                      ? OutlineInputBorder(
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(3),
                                                          borderSide:
                                                              const BorderSide(
                                                            color: Colors.red,
                                                          ),
                                                        )
                                                      : InputBorder.none,
                                                  border: InputBorder.none,
                                                  contentPadding:
                                                      const EdgeInsets.all(12),
                                                  suffixIcon:
                                                      ClearableDateSuffix(
                                                    controller:
                                                        startdateController,
                                                    onPick: () {
                                                      _startDate(context);
                                                      setState(() {
                                                        startdatederror = false;
                                                      });
                                                    },
                                                    onClear: _clearStartDate,
                                                    iconSize: 20,
                                                  ),
                                                ),
                                                readOnly: true,
                                                onTap: () {
                                                  _startDate(context);
                                                  setState(() {
                                                    startdatederror = false;
                                                  });
                                                },
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    startdatederror
                                        ? Row(
                                            children: [
                                              const Spacer(),
                                              Text(
                                                startdatemessage,
                                                style: TextStyle(
                                                    color: Colors.red,
                                                    fontSize:
                                                        MediaQuery.of(context)
                                                                    .size
                                                                    .width <
                                                                500
                                                            ? 15
                                                            : 19),
                                              ),
                                              const SizedBox(
                                                width: 2,
                                              ),
                                            ],
                                          )
                                        : Container(),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              // Second Column
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "End Date",
                                      style: TextStyle(
                                          // color: Colors.grey,
                                          color: const Color(0xFF8A95A8),
                                          fontWeight: FontWeight.bold,
                                          fontSize: MediaQuery.of(context)
                                                      .size
                                                      .width <
                                                  500
                                              ? 15
                                              : 20),
                                    ),
                                    const SizedBox(height: 5),
                                    Material(
                                      elevation: 4,
                                      child: Container(
                                        height: 50,
                                        width:
                                            MediaQuery.of(context).size.width *
                                                .6,
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(2),
                                          border: Border.all(
                                            color: const Color(0xFF8A95A8),
                                          ),
                                        ),
                                        child: Stack(
                                          children: [
                                            Positioned.fill(
                                              child: TextField(
                                                onChanged: (value) {
                                                  setState(() {
                                                    enddatederror = false;
                                                    // _selectDate(context);
                                                  });
                                                },
                                                controller: enddateController,
                                                cursorColor: blueColor,
                                                decoration: InputDecoration(
                                                  hintText:
                                                      Provider.of<DateProvider>(
                                                              context,
                                                              listen: false)
                                                          .dateFormat
                                                          .toUpperCase(),
                                                  hintStyle: TextStyle(
                                                    fontSize:
                                                        MediaQuery.of(context)
                                                                    .size
                                                                    .width <
                                                                500
                                                            ? 15
                                                            : 18,
                                                    color:
                                                        const Color(0xFF8A95A8),
                                                  ),
                                                  enabledBorder: enddatederror
                                                      ? OutlineInputBorder(
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(3),
                                                          borderSide:
                                                              const BorderSide(
                                                            color: Colors.red,
                                                          ),
                                                        )
                                                      : InputBorder.none,
                                                  border: InputBorder.none,
                                                  contentPadding:
                                                      const EdgeInsets.all(12),
                                                  suffixIcon:
                                                      ClearableDateSuffix(
                                                    controller:
                                                        enddateController,
                                                    onPick: () =>
                                                        _endDate(context),
                                                    onClear: _clearEndDate,
                                                    iconSize: 20,
                                                  ),
                                                ),
                                                readOnly: true,
                                                onTap: () {
                                                  _endDate(context);
                                                  setState(() {
                                                    enddatederror = false;
                                                  });
                                                },
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    enddatederror
                                        ? Row(
                                            children: [
                                              const Spacer(),
                                              Text(
                                                enddatemessage,
                                                style: TextStyle(
                                                    color: Colors.red,
                                                    fontSize:
                                                        MediaQuery.of(context)
                                                                    .size
                                                                    .width <
                                                                500
                                                            ? 15
                                                            : 19),
                                              ),
                                              const SizedBox(
                                                width: 2,
                                              ),
                                            ],
                                          )
                                        : Container(),
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
            ),
          ),
          const SizedBox(
            height: 15,
          ),
          //contact information
          Padding(
            padding: const EdgeInsets.only(left: 15, right: 15),
            child: Material(
              //elevation: 6,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFCED4DA)),
                ),
                child: Padding(
                  padding: const EdgeInsets.only(
                      left: 10, right: 10, top: 10, bottom: 20),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const SizedBox(
                            width: 2,
                          ),
                          Text(
                            "Contact Information",
                            style: TextStyle(
                                color: const Color(0xFF152B51),
                                fontWeight: FontWeight.bold,
                                // fontSize: 18
                                fontSize:
                                    MediaQuery.of(context).size.width < 500
                                        ? 20
                                        : 25),
                          ),
                        ],
                      ),
                      const SizedBox(
                        height: 10,
                      ),
                      Column(
                        children: [
                          Row(
                            children: [
                              const SizedBox(width: 2),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Primary E-mail *",
                                      style: TextStyle(
                                          color: const Color(0xFF101828),
                                          fontWeight: FontWeight.bold,
                                          fontSize: MediaQuery.of(context)
                                                      .size
                                                      .width <
                                                  500
                                              ? 15
                                              : 20),
                                    ),
                                    Material(
                                      // elevation: 4,
                                      child: Container(
                                        height: 50,
                                        width:
                                            MediaQuery.of(context).size.width *
                                                .6,
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          border: Border.all(
                                            color: const Color(0xFFCED4DA),
                                          ),
                                        ),
                                        child: Stack(
                                          children: [
                                            Positioned.fill(
                                              child: TextField(
                                                onChanged: (value) {
                                                  setState(() {
                                                    primaryemailerror = false;
                                                  });
                                                },
                                                keyboardType:
                                                    TextInputType.emailAddress,
                                                controller: primaryemail,
                                                cursorColor: blueColor,
                                                decoration: InputDecoration(
                                                  hintText:
                                                      "Enter primary e-mail",
                                                  hintStyle: TextStyle(
                                                    fontSize:
                                                        MediaQuery.of(context)
                                                                    .size
                                                                    .width <
                                                                500
                                                            ? 15
                                                            : 18,
                                                    color:
                                                        const Color(0xFFA1A8B0),
                                                  ),
                                                  enabledBorder:
                                                      primaryemailerror
                                                          ? OutlineInputBorder(
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          10),
                                                              borderSide:
                                                                  const BorderSide(
                                                                color:
                                                                    Colors.red,
                                                              ),
                                                            )
                                                          : InputBorder.none,
                                                  border: InputBorder.none,
                                                  contentPadding:
                                                      const EdgeInsets.all(12),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Container(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Alternative E-mail",
                                        style: TextStyle(
                                            // color: Colors.grey,
                                            color: const Color(0xFF101828),
                                            fontWeight: FontWeight.bold,
                                            fontSize: MediaQuery.of(context)
                                                        .size
                                                        .width <
                                                    500
                                                ? 15
                                                : 20),
                                      ),
                                      Material(
                                        // elevation: 4,
                                        child: Container(
                                          height: 50,
                                          width: MediaQuery.of(context)
                                                  .size
                                                  .width *
                                              .6,
                                          decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            border: Border.all(
                                              color: const Color(0xFFCED4DA),
                                            ),
                                          ),
                                          child: Stack(
                                            children: [
                                              Positioned.fill(
                                                child: TextField(
                                                  onChanged: (value) {
                                                    setState(() {
                                                      alternativeerror = false;
                                                    });
                                                  },
                                                  controller: alternativeemail,
                                                  keyboardType: TextInputType
                                                      .emailAddress,
                                                  cursorColor: blueColor,
                                                  decoration: InputDecoration(
                                                    hintText:
                                                        "Enter alternative e-mail ",
                                                    hintStyle: TextStyle(
                                                      fontSize:
                                                          MediaQuery.of(context)
                                                                      .size
                                                                      .width <
                                                                  500
                                                              ? 15
                                                              : 18,
                                                      color: const Color(
                                                          0xFFA1A8B0),
                                                    ),
                                                    enabledBorder:
                                                        alternativeerror
                                                            ? OutlineInputBorder(
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            10),
                                                                borderSide:
                                                                    const BorderSide(
                                                                  color: Colors
                                                                      .red,
                                                                ),
                                                              )
                                                            : InputBorder.none,
                                                    border: InputBorder.none,
                                                    contentPadding:
                                                        const EdgeInsets.all(
                                                            12),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: primaryemailerror
                                    ? Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Container(
                                          alignment: Alignment
                                              .centerLeft, // Ensure left alignment
                                          child: Text(
                                            primaryemailmessage,
                                            style: TextStyle(
                                              color: Colors.red,
                                              fontSize: MediaQuery.of(context)
                                                      .size
                                                      .width *
                                                  0.035,
                                            ),
                                          ),
                                        ),
                                      )
                                    : const SizedBox.shrink(),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: alternativeerror
                                    ? Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Container(
                                          alignment: Alignment
                                              .centerLeft, // Ensure left alignment
                                          child: Text(
                                            alternativemessage,
                                            style: TextStyle(
                                              color: Colors.red,
                                              fontSize: MediaQuery.of(context)
                                                      .size
                                                      .width *
                                                  0.035,
                                            ),
                                          ),
                                        ),
                                      )
                                    : const SizedBox.shrink(),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(
                        height: 10,
                      ),
                      //phonenumber and homenumber
                      Column(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(width: 2),
                              Expanded(
                                child: Container(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Phone Number *",
                                        style: TextStyle(
                                            // color: Colors.grey,
                                            color: const Color(0xFF101828),
                                            fontWeight: FontWeight.bold,
                                            fontSize: MediaQuery.of(context)
                                                        .size
                                                        .width <
                                                    500
                                                ? 15
                                                : 20),
                                      ),
                                      Material(
                                        // elevation: 4,
                                        child: Container(
                                          height: 50,
                                          width: MediaQuery.of(context)
                                                  .size
                                                  .width *
                                              .6,
                                          decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            border: Border.all(
                                              color: const Color(0xFFCED4DA),
                                            ),
                                          ),
                                          child: Stack(
                                            children: [
                                              Positioned.fill(
                                                child: TextField(
                                                  inputFormatters: [
                                                    FilteringTextInputFormatter
                                                        .digitsOnly,
                                                    LengthLimitingTextInputFormatter(
                                                        10),
                                                    PhoneNumberFormatter(),
                                                  ],
                                                  focusNode: _nodeText1,
                                                  onChanged: (value) {
                                                    setState(() {
                                                      phonenumerror = false;
                                                    });
                                                  },
                                                  controller: phonenum,
                                                  keyboardType:
                                                      TextInputType.number,
                                                  // keyboardType:
                                                  //     TextInputType.numberWithOptions(
                                                  //         signed: true, decimal: true),
                                                  cursorColor: blueColor,
                                                  decoration: InputDecoration(
                                                    hintText:
                                                        "Enter phone number",
                                                    hintStyle: TextStyle(
                                                      fontSize:
                                                          MediaQuery.of(context)
                                                                      .size
                                                                      .width <
                                                                  500
                                                              ? 15
                                                              : 18,
                                                      color: const Color(
                                                          0xFFA1A8B0),
                                                    ),
                                                    enabledBorder: phonenumerror
                                                        ? OutlineInputBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        10),
                                                            borderSide:
                                                                const BorderSide(
                                                              color: Colors.red,
                                                            ),
                                                          )
                                                        : InputBorder.none,
                                                    border: InputBorder.none,
                                                    contentPadding:
                                                        const EdgeInsets.all(
                                                            12),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Container(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Home Number",
                                        style: TextStyle(
                                            // color: Colors.grey,
                                            color: const Color(0xFF101828),
                                            fontWeight: FontWeight.bold,
                                            fontSize: MediaQuery.of(context)
                                                        .size
                                                        .width <
                                                    500
                                                ? 15
                                                : 20),
                                      ),
                                      Material(
                                        // elevation: 4,
                                        child: Container(
                                          height: 50,
                                          width: MediaQuery.of(context)
                                                  .size
                                                  .width *
                                              .6,
                                          decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            border: Border.all(
                                              color: const Color(0xFFCED4DA),
                                            ),
                                          ),
                                          child: Stack(
                                            children: [
                                              Positioned.fill(
                                                child: TextField(
                                                  inputFormatters: [
                                                    FilteringTextInputFormatter
                                                        .digitsOnly,
                                                    LengthLimitingTextInputFormatter(
                                                        10),
                                                    PhoneNumberFormatter(),
                                                  ],
                                                  focusNode: _nodeText2,
                                                  onChanged: (value) {
                                                    setState(() {
                                                      homenumerror = false;
                                                    });
                                                  },
                                                  controller: homenum,
                                                  keyboardType:
                                                      TextInputType.number,
                                                  // keyboardType:
                                                  //     TextInputType.numberWithOptions(
                                                  //         signed: true, decimal: true),
                                                  cursorColor: blueColor,
                                                  decoration: InputDecoration(
                                                    hintText:
                                                        "Enter home number",
                                                    hintStyle: TextStyle(
                                                      fontSize:
                                                          MediaQuery.of(context)
                                                                      .size
                                                                      .width <
                                                                  500
                                                              ? 15
                                                              : 18,
                                                      color: const Color(
                                                          0xFFA1A8B0),
                                                    ),
                                                    enabledBorder: homenumerror
                                                        ? OutlineInputBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        10),
                                                            borderSide:
                                                                const BorderSide(
                                                              color: Colors.red,
                                                            ),
                                                          )
                                                        : InputBorder.none,
                                                    border: InputBorder.none,
                                                    contentPadding:
                                                        const EdgeInsets.all(
                                                            12),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 2),
                            ],
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: phonenumerror
                                    ? Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Container(
                                          alignment: Alignment
                                              .centerLeft, // Ensure left alignment
                                          child: Text(
                                            phonenummessage,
                                            style: TextStyle(
                                              color: Colors.red,
                                              fontSize: MediaQuery.of(context)
                                                      .size
                                                      .width *
                                                  0.035,
                                            ),
                                          ),
                                        ),
                                      )
                                    : const SizedBox.shrink(),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: homenumerror
                                    ? Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Container(
                                          alignment: Alignment
                                              .centerLeft, // Ensure left alignment
                                          child: Text(
                                            homenummessage,
                                            style: TextStyle(
                                              color: Colors.red,
                                              fontSize: MediaQuery.of(context)
                                                      .size
                                                      .width *
                                                  0.035,
                                            ),
                                          ),
                                        ),
                                      )
                                    : const SizedBox.shrink(),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(
                        height: 10,
                      ),
                      //office number and city
                      Column(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(width: 2),
                              Expanded(
                                child: Container(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Office Number",
                                        style: TextStyle(
                                            // color: Colors.grey,
                                            color: const Color(0xFF101828),
                                            fontWeight: FontWeight.bold,
                                            fontSize: MediaQuery.of(context)
                                                        .size
                                                        .width <
                                                    500
                                                ? 15
                                                : 20),
                                      ),
                                      Material(
                                        // elevation: 4,
                                        child: Container(
                                          height: 50,
                                          // width: MediaQuery.of(context).size.width * .6,
                                          decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            border: Border.all(
                                              color: const Color(0xFFCED4DA),
                                            ),
                                          ),
                                          child: Stack(
                                            children: [
                                              Positioned.fill(
                                                child: TextField(
                                                  inputFormatters: [
                                                    FilteringTextInputFormatter
                                                        .digitsOnly,
                                                    LengthLimitingTextInputFormatter(
                                                        10),
                                                    PhoneNumberFormatter(),
                                                  ],
                                                  onChanged: (value) {
                                                    setState(() {
                                                      officenumerror = false;
                                                    });
                                                  },
                                                  controller: officenum,
                                                  keyboardType:
                                                      TextInputType.number,
                                                  // keyboardType:
                                                  //     TextInputType.numberWithOptions(
                                                  //         signed: true, decimal: true),
                                                  cursorColor: blueColor,
                                                  decoration: InputDecoration(
                                                    hintText:
                                                        "Enter office number",
                                                    hintStyle: TextStyle(
                                                      fontSize:
                                                          MediaQuery.of(context)
                                                                      .size
                                                                      .width <
                                                                  500
                                                              ? 15
                                                              : 18,
                                                      color: const Color(
                                                          0xFFA1A8B0),
                                                    ),
                                                    enabledBorder: officenumerror
                                                        ? OutlineInputBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        10),
                                                            borderSide:
                                                                const BorderSide(
                                                              color: Colors.red,
                                                            ),
                                                          )
                                                        : InputBorder.none,
                                                    border: InputBorder.none,
                                                    contentPadding:
                                                        const EdgeInsets.all(
                                                            12),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Container(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "City",
                                        style: TextStyle(
                                            // color: Colors.grey,
                                            color: const Color(0xFF101828),
                                            fontWeight: FontWeight.bold,
                                            fontSize: MediaQuery.of(context)
                                                        .size
                                                        .width <
                                                    500
                                                ? 15
                                                : 20),
                                      ),
                                      Material(
                                        // elevation: 4,
                                        child: Container(
                                          height: 50,
                                          // width: MediaQuery.of(context).size.width * .6,
                                          decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            border: Border.all(
                                              color: const Color(0xFFCED4DA),
                                            ),
                                          ),
                                          child: Stack(
                                            children: [
                                              Positioned.fill(
                                                child: TextField(
                                                  keyboardType:
                                                      TextInputType.text,
                                                  onChanged: (value) {
                                                    setState(() {
                                                      city2error = false;
                                                    });
                                                  },
                                                  controller: city2,
                                                  cursorColor: blueColor,
                                                  decoration: InputDecoration(
                                                    hintText: "Enter city",
                                                    hintStyle: TextStyle(
                                                      fontSize:
                                                          MediaQuery.of(context)
                                                                      .size
                                                                      .width <
                                                                  500
                                                              ? 15
                                                              : 18,
                                                      color: const Color(
                                                          0xFFA1A8B0),
                                                    ),
                                                    enabledBorder: city2error
                                                        ? OutlineInputBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        10),
                                                            borderSide:
                                                                const BorderSide(
                                                              color: Colors.red,
                                                            ),
                                                          )
                                                        : InputBorder.none,
                                                    border: InputBorder.none,
                                                    contentPadding:
                                                        const EdgeInsets.all(
                                                            12),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 2),
                            ],
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: officenumerror
                                    ? Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Container(
                                          alignment: Alignment
                                              .centerLeft, // Ensure left alignment
                                          child: Text(
                                            officenummessage,
                                            style: TextStyle(
                                              color: Colors.red,
                                              fontSize: MediaQuery.of(context)
                                                      .size
                                                      .width *
                                                  0.035,
                                            ),
                                          ),
                                        ),
                                      )
                                    : const SizedBox.shrink(),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: city2error
                                    ? Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Container(
                                          alignment: Alignment
                                              .centerLeft, // Ensure left alignment
                                          child: Text(
                                            city2message,
                                            style: TextStyle(
                                              color: Colors.red,
                                              fontSize: MediaQuery.of(context)
                                                      .size
                                                      .width *
                                                  0.035,
                                            ),
                                          ),
                                        ),
                                      )
                                    : const SizedBox.shrink(),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(
                        height: 10,
                      ),
                      //state and country
                      Column(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(width: 2),
                              Expanded(
                                child: Container(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "State",
                                        style: TextStyle(
                                            // color: Colors.grey,
                                            color: const Color(0xFF101828),
                                            fontWeight: FontWeight.bold,
                                            fontSize: MediaQuery.of(context)
                                                        .size
                                                        .width <
                                                    500
                                                ? 15
                                                : 20),
                                      ),
                                      SizedBox(
                                        width: MediaQuery.of(context)
                                                .size
                                                .width *
                                            .6,
                                        child: UsStateDropdown(
                                          controller: state2,
                                          hintText: 'Select state',
                                          borderColor:
                                              state2error ? redClr : null,
                                          onChanged: (value) {
                                            setState(() {
                                              state2error = false;
                                            });
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Container(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Country",
                                        style: TextStyle(
                                            // color: Colors.grey,
                                            color: const Color(0xFF101828),
                                            fontWeight: FontWeight.bold,
                                            fontSize: MediaQuery.of(context)
                                                        .size
                                                        .width <
                                                    500
                                                ? 15
                                                : 20),
                                      ),
                                      Material(
                                        // elevation: 4,
                                        child: Container(
                                          height: 50,
                                          width: MediaQuery.of(context)
                                                  .size
                                                  .width *
                                              .6,
                                          decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            border: Border.all(
                                              color: const Color(0xFFCED4DA),
                                            ),
                                          ),
                                          child: Stack(
                                            children: [
                                              Positioned.fill(
                                                child: TextField(
                                                  keyboardType:
                                                      TextInputType.text,
                                                  onChanged: (value) {
                                                    setState(() {
                                                      county2error = false;
                                                    });
                                                  },
                                                  controller: county2,
                                                  cursorColor: blueColor,
                                                  decoration: InputDecoration(
                                                    hintText: "Enter country",
                                                    hintStyle: TextStyle(
                                                      fontSize:
                                                          MediaQuery.of(context)
                                                                      .size
                                                                      .width <
                                                                  500
                                                              ? 15
                                                              : 18,
                                                      color: const Color(
                                                          0xFFA1A8B0),
                                                    ),
                                                    enabledBorder: county2error
                                                        ? OutlineInputBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        10),
                                                            borderSide:
                                                                const BorderSide(
                                                              color: Colors.red,
                                                            ),
                                                          )
                                                        : InputBorder.none,
                                                    border: InputBorder.none,
                                                    contentPadding:
                                                        const EdgeInsets.all(
                                                            12),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: street2error
                                    ? Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Container(
                                          alignment: Alignment
                                              .centerLeft, // Ensure left alignment
                                          child: Text(
                                            state2message,
                                            style: TextStyle(
                                              color: Colors.red,
                                              fontSize: MediaQuery.of(context)
                                                      .size
                                                      .width *
                                                  0.035,
                                            ),
                                          ),
                                        ),
                                      )
                                    : const SizedBox.shrink(),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: county2error
                                    ? Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Container(
                                          alignment: Alignment
                                              .centerLeft, // Ensure left alignment
                                          child: Text(
                                            county2message,
                                            style: TextStyle(
                                              color: Colors.red,
                                              fontSize: MediaQuery.of(context)
                                                      .size
                                                      .width *
                                                  0.035,
                                            ),
                                          ),
                                        ),
                                      )
                                    : const SizedBox.shrink(),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(
                        height: 10,
                      ),
                      //postal code and street
                      Column(
                        children: [
                          Row(
                            children: [
                              const SizedBox(width: 2),
                              Expanded(
                                child: Container(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Zip Code",
                                        style: TextStyle(
                                            // color: Colors.grey,
                                            color: const Color(0xFF101828),
                                            fontWeight: FontWeight.bold,
                                            fontSize: MediaQuery.of(context)
                                                        .size
                                                        .width <
                                                    500
                                                ? 15
                                                : 20),
                                      ),
                                      Material(
                                        // elevation: 4,
                                        child: Container(
                                          height: 50,
                                          width: MediaQuery.of(context)
                                                  .size
                                                  .width *
                                              .6,
                                          decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            border: Border.all(
                                              color: const Color(0xFFCED4DA),
                                            ),
                                          ),
                                          child: Stack(
                                            children: [
                                              Positioned.fill(
                                                child: TextField(
                                                  focusNode: _nodeText4,
                                                  onChanged: (value) {
                                                    setState(() {
                                                      code2error = false;
                                                    });
                                                  },
                                                  controller: code2,
                                                  keyboardType:
                                                      TextInputType.number,
                                                  inputFormatters: [
                                                    FilteringTextInputFormatter
                                                        .digitsOnly,
                                                  ],
                                                  cursorColor: blueColor,
                                                  decoration: InputDecoration(
                                                    hintText: "Enter zip code",
                                                    hintStyle: TextStyle(
                                                      fontSize:
                                                          MediaQuery.of(context)
                                                                      .size
                                                                      .width <
                                                                  500
                                                              ? 15
                                                              : 18,
                                                      color: const Color(
                                                          0xFFA1A8B0),
                                                    ),
                                                    enabledBorder: code2error
                                                        ? OutlineInputBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        10),
                                                            borderSide:
                                                                const BorderSide(
                                                              color: Colors.red,
                                                            ),
                                                          )
                                                        : InputBorder.none,
                                                    border: InputBorder.none,
                                                    contentPadding:
                                                        const EdgeInsets.all(
                                                            12),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Container(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Street Address",
                                        style: TextStyle(
                                            // color: Colors.grey,
                                            color: const Color(0xFF101828),
                                            fontWeight: FontWeight.bold,
                                            fontSize: MediaQuery.of(context)
                                                        .size
                                                        .width <
                                                    500
                                                ? 15
                                                : 20),
                                      ),
                                      Material(
                                        // elevation: 4,
                                        child: Container(
                                          height: 50,
                                          width: MediaQuery.of(context)
                                                  .size
                                                  .width *
                                              .6,
                                          decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            border: Border.all(
                                              color: const Color(0xFFCED4DA),
                                            ),
                                          ),
                                          child: Stack(
                                            children: [
                                              Positioned.fill(
                                                child: TextField(
                                                  onChanged: (value) {
                                                    setState(() {
                                                      street2error = false;
                                                    });
                                                  },
                                                  controller: street2,
                                                  cursorColor: blueColor,
                                                  decoration: InputDecoration(
                                                    hintText:
                                                        "Enter street address",
                                                    hintStyle: TextStyle(
                                                      fontSize:
                                                          MediaQuery.of(context)
                                                                      .size
                                                                      .width <
                                                                  500
                                                              ? 15
                                                              : 18,
                                                      color: const Color(
                                                          0xFFA1A8B0),
                                                    ),
                                                    enabledBorder: street2error
                                                        ? OutlineInputBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        10),
                                                            borderSide:
                                                                const BorderSide(
                                                              color: Colors.red,
                                                            ),
                                                          )
                                                        : InputBorder.none,
                                                    border: InputBorder.none,
                                                    contentPadding:
                                                        const EdgeInsets.all(
                                                            12),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: code2error
                                    ? Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Container(
                                          alignment: Alignment
                                              .centerLeft, // Ensure left alignment
                                          child: Text(
                                            code2message,
                                            style: TextStyle(
                                              color: Colors.red,
                                              fontSize: MediaQuery.of(context)
                                                      .size
                                                      .width *
                                                  0.035,
                                            ),
                                          ),
                                        ),
                                      )
                                    : const SizedBox.shrink(),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: street2error
                                    ? Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Container(
                                          alignment: Alignment
                                              .centerLeft, // Ensure left alignment
                                          child: Text(
                                            street2message,
                                            style: TextStyle(
                                              color: Colors.red,
                                              fontSize: MediaQuery.of(context)
                                                      .size
                                                      .width *
                                                  0.035,
                                            ),
                                          ),
                                        ),
                                      )
                                    : const SizedBox.shrink(),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(
            height: 15,
          ),
          //tax payer information
          Padding(
            padding: const EdgeInsets.only(left: 15, right: 15),
            child: Material(
              // elevation: 6,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFCED4DA)),
                ),
                child: Padding(
                  padding: const EdgeInsets.only(
                      left: 10, right: 10, top: 10, bottom: 20),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const SizedBox(
                            width: 2,
                          ),
                          Text(
                            "Taxpayer Information ",
                            style: TextStyle(
                                color: const Color(0xFF152B51),
                                fontWeight: FontWeight.bold,
                                // fontSize: 18
                                fontSize:
                                    MediaQuery.of(context).size.width < 500
                                        ? 20
                                        : 25),
                          ),
                        ],
                      ),
                      const SizedBox(
                        height: 10,
                      ),
                      Column(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(width: 2),
                              Expanded(
                                child: Container(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Tax ID Type",
                                        style: TextStyle(
                                            color: const Color(0xFF101828),
                                            fontWeight: FontWeight.bold,
                                            fontSize: MediaQuery.of(context)
                                                        .size
                                                        .width <
                                                    500
                                                ? 15
                                                : 20),
                                      ),
                                      Material(
                                        // elevation: 4,
                                        child: Container(
                                          height: 50,
                                          width: MediaQuery.of(context)
                                                  .size
                                                  .width *
                                              .6,
                                          decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            border: Border.all(
                                              color: const Color(0xFFCED4DA),
                                            ),
                                          ),
                                          child: Stack(
                                            children: [
                                              Positioned.fill(
                                                child: TextField(
                                                  onChanged: (value) {
                                                    setState(() {
                                                      taxtypeerror = false;
                                                    });
                                                  },
                                                  controller: taxtype,
                                                  cursorColor: blueColor,
                                                  decoration: InputDecoration(
                                                    hintText:
                                                        "Enter tax id type",
                                                    hintStyle: TextStyle(
                                                      fontSize:
                                                          MediaQuery.of(context)
                                                                      .size
                                                                      .width <
                                                                  500
                                                              ? 15
                                                              : 18,
                                                      color: const Color(
                                                          0xFFA1A8B0),
                                                    ),
                                                    enabledBorder: taxtypeerror
                                                        ? OutlineInputBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        10),
                                                            borderSide:
                                                                const BorderSide(
                                                              color: Colors.red,
                                                            ),
                                                          )
                                                        : InputBorder.none,
                                                    border: InputBorder.none,
                                                    contentPadding:
                                                        const EdgeInsets.all(
                                                            12),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Container(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Taxpayer ID",
                                        style: TextStyle(
                                            // color: Colors.grey,
                                            color: const Color(0xFF101828),
                                            fontWeight: FontWeight.bold,
                                            fontSize: MediaQuery.of(context)
                                                        .size
                                                        .width <
                                                    500
                                                ? 15
                                                : 20),
                                      ),
                                      Material(
                                        // elevation: 4,
                                        child: Container(
                                          height: 50,
                                          width: MediaQuery.of(context)
                                                  .size
                                                  .width *
                                              .6,
                                          decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            border: Border.all(
                                              color: const Color(0xFFCED4DA),
                                            ),
                                          ),
                                          child: Stack(
                                            children: [
                                              Positioned.fill(
                                                child: TextField(
                                                  onChanged: (value) {
                                                    setState(() {
                                                      taxiderror = false;
                                                    });
                                                  },
                                                  controller: taxid,
                                                  cursorColor: blueColor,
                                                  decoration: InputDecoration(
                                                    hintText:
                                                        "Enter SSN or EIN",
                                                    hintStyle: TextStyle(
                                                      fontSize:
                                                          MediaQuery.of(context)
                                                                      .size
                                                                      .width <
                                                                  500
                                                              ? 15
                                                              : 18,
                                                      color: const Color(
                                                          0xFFA1A8B0),
                                                    ),
                                                    enabledBorder: taxiderror
                                                        ? OutlineInputBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        10),
                                                            borderSide:
                                                                const BorderSide(
                                                              color: Colors.red,
                                                            ),
                                                          )
                                                        : InputBorder.none,
                                                    border: InputBorder.none,
                                                    contentPadding:
                                                        const EdgeInsets.all(
                                                            12),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 2),
                            ],
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: taxtypeerror
                                    ? Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Container(
                                          alignment: Alignment
                                              .centerLeft, // Ensure left alignment
                                          child: Text(
                                            taxtypemessage,
                                            style: TextStyle(
                                              color: Colors.red,
                                              fontSize: MediaQuery.of(context)
                                                      .size
                                                      .width *
                                                  0.035,
                                            ),
                                          ),
                                        ),
                                      )
                                    : const SizedBox.shrink(),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: enddatederror
                                    ? Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Container(
                                          alignment: Alignment
                                              .centerLeft, // Ensure left alignment
                                          child: Text(
                                            enddatemessage,
                                            style: TextStyle(
                                              color: Colors.red,
                                              fontSize: MediaQuery.of(context)
                                                      .size
                                                      .width *
                                                  0.035,
                                            ),
                                          ),
                                        ),
                                      )
                                    : const SizedBox.shrink(),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(
            height: 15,
          ),
          Padding(
            padding: const EdgeInsets.only(left: 15, right: 15),
            child: Material(
              // elevation: 6,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFCED4DA)),
                ),
                child: Padding(
                  padding: const EdgeInsets.only(
                      left: 10, right: 10, top: 10, bottom: 10),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const SizedBox(
                            width: 2,
                          ),
                          Text(
                            "Card Transaction Type \nManagement ",
                            style: TextStyle(
                                color: const Color(0xFF152B51),
                                fontWeight: FontWeight.bold,
                                // fontSize: 18
                                fontSize:
                                    MediaQuery.of(context).size.width < 500
                                        ? 20
                                        : 25),
                          ),
                        ],
                      ),
                      const SizedBox(
                        height: 10,
                      ),
                      Row(
                        children: [
                          const SizedBox(
                            width: 2,
                          ),
                          Text(
                            "Select the type of card you wish to \naccept",
                            style: TextStyle(
                                color: const Color(0xFF636363),
                                fontWeight: FontWeight.bold,
                                fontSize:
                                    MediaQuery.of(context).size.width < 500
                                        ? 15
                                        : 20),
                          ),
                        ],
                      ),
                      const SizedBox(
                        height: 5,
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Container(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  Transform.scale(
                                    scale: 1.2,
                                    child: Checkbox(
                                      value: creditcard,
                                      onChanged: (value) {
                                        setState(() {
                                          creditcard = value!;
                                        });
                                      },
                                      activeColor: blueColor,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  const Text(
                                    "Credit Card",
                                    style: TextStyle(
                                        fontSize: 16, color: Color(0xFF101828)),
                                  )
                                ],
                              ),
                            ),
                          ),
                          Expanded(
                            child: Container(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  Transform.scale(
                                    scale: 1.2,
                                    child: Checkbox(
                                        value: debitcard,
                                        onChanged: (value) {
                                          setState(() {
                                            debitcard = value!;
                                          });
                                        },
                                        activeColor: blueColor),
                                  ),
                                  const SizedBox(width: 10),
                                  const Text(
                                    "Debit Card",
                                    style: TextStyle(
                                        fontSize: 16, color: Color(0xFF101828)),
                                  )
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(
                        height: 5,
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Container(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  Transform.scale(
                                    scale: 1.2,
                                    child: Checkbox(
                                        value: achaccepted,
                                        onChanged: (value) {
                                          setState(() {
                                            achaccepted = value!;
                                          });
                                        },
                                        activeColor: blueColor),
                                  ),
                                  const SizedBox(width: 10),
                                  const Text(
                                    "ACH",
                                    style: TextStyle(
                                        fontSize: 16, color: Color(0xFF101828)),
                                  )
                                ],
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
          ),
          const SizedBox(
            height: 20,
          ),
          // Padding(
          //   padding: const EdgeInsets.only(left: 25, right: 25),
          //   child: Material(
          //     elevation: 6,
          //     borderRadius: BorderRadius.circular(10),
          //     child: Container(
          //       decoration: BoxDecoration(
          //         color: Colors.white,
          //         borderRadius: BorderRadius.circular(10),
          //         border: Border.all(color: blueColor),
          //       ),
          //       child: Padding(
          //         padding: const EdgeInsets.only(
          //             left: 25, right: 25, top: 20, bottom: 30),
          //         child: Column(
          //           children: [
          //             Row(
          //               children: [
          //                 SizedBox(
          //                   width: 2,
          //                 ),
          //                 Expanded(
          //                   child: Text(
          //                     "Card Transaction  Type Management ",
          //                     style: TextStyle(
          //                         color: blueColor,
          //                         fontWeight: FontWeight.bold,
          //                         // fontSize: 18
          //                         fontSize:
          //                         MediaQuery.of(context).size.width < 500
          //                             ? 20
          //                             : 25),
          //                   ),
          //                 ),
          //               ],
          //             ),
          //             SizedBox(
          //               height: 10,
          //             ),
          //             Row(
          //               children: [
          //                 // Checkbox(
          //                 //     activeColor: b,
          //                 //     value: enableOverrideFee,
          //                 //     onChanged: (value) {
          //                 //       setState(() {
          //                 //         enableOverrideFee = value!;
          //                 //         if (!enableOverrideFee) {
          //                 //           overrideFee.clear();
          //                 //           overRideFeeError = '';
          //                 //         }
          //                 //       });
          //                 //     }),
          //                 Text('Enable Debit Card Fee',
          //                     style: TextStyle(
          //                         fontSize: 13,
          //                         fontWeight: FontWeight.bold,
          //                         color: Colors.grey)),
          //               ],
          //             ),
          //             SizedBox(
          //               height: 10,
          //             ),
          //             Row(
          //               children: [
          //                 SizedBox(
          //                   width: 2,
          //                 ),
          //                 Text(
          //                   "Tax Identify Type",
          //                   style: TextStyle(
          //                       color: Color(0xFF8A95A8),
          //                       fontWeight: FontWeight.bold,
          //                       fontSize:
          //                       MediaQuery.of(context).size.width < 500
          //                           ? 15
          //                           : 20),
          //                 ),
          //               ],
          //             ),
          //             SizedBox(
          //               height: 5,
          //             ),
          //             Row(
          //               children: [
          //                 SizedBox(width: 2),
          //                 Expanded(
          //                   child: Material(
          //                     elevation: 4,
          //                     child: Container(
          //                       height: 50,
          //                       width: MediaQuery.of(context).size.width * .6,
          //                       decoration: BoxDecoration(
          //                         borderRadius: BorderRadius.circular(2),
          //                         border: Border.all(
          //                           color: Color(0xFF8A95A8),
          //                         ),
          //                       ),
          //                       child: Stack(
          //                         children: [
          //                           Positioned.fill(
          //                             child: TextField(
          //                               onChanged: (value) {
          //                                 setState(() {
          //                                   taxtypeerror = false;
          //                                 });
          //                               },
          //                               controller: taxtype,
          //                               cursorColor:
          //                               blueColor,
          //                               decoration: InputDecoration(
          //                                 hintText: "Enter tax identify type",
          //                                 hintStyle: TextStyle(
          //                                   fontSize: MediaQuery.of(context)
          //                                       .size
          //                                       .width <
          //                                       500
          //                                       ? 15
          //                                       : 18,
          //                                   color: Color(0xFF8A95A8),
          //                                 ),
          //                                 enabledBorder: taxtypeerror
          //                                     ? OutlineInputBorder(
          //                                   borderRadius:
          //                                   BorderRadius.circular(2),
          //                                   borderSide: BorderSide(
          //                                     color: Colors.red,
          //                                   ),
          //                                 )
          //                                     : InputBorder.none,
          //                                 border: InputBorder.none,
          //                                 contentPadding: EdgeInsets.all(12),
          //                               ),
          //                             ),
          //                           ),
          //                         ],
          //                       ),
          //                     ),
          //                   ),
          //                 ),
          //                 SizedBox(width: 2),
          //               ],
          //             ),
          //             taxtypeerror
          //                 ? Row(
          //               children: [
          //                 Spacer(),
          //                 Text(
          //                   taxtypemessage,
          //                   style: TextStyle(
          //                       color: Colors.red,
          //                       fontSize:
          //                       MediaQuery.of(context).size.width <
          //                           500
          //                           ? 15
          //                           : 19),
          //                 ),
          //                 SizedBox(
          //                   width: 2,
          //                 ),
          //               ],
          //             )
          //                 : Container(),
          //             SizedBox(
          //               height: 10,
          //             ),
          //             Row(
          //               children: [
          //                 SizedBox(
          //                   width: 3,
          //                 ),
          //                 Text(
          //                   "Tax PayerId",
          //                   style: TextStyle(
          //                     // color: Colors.grey,
          //                       color: Color(0xFF8A95A8),
          //                       fontWeight: FontWeight.bold,
          //                       fontSize:
          //                       MediaQuery.of(context).size.width < 500
          //                           ? 15
          //                           : 20),
          //                 ),
          //               ],
          //             ),
          //             SizedBox(
          //               height: 5,
          //             ),
          //             Row(
          //               children: [
          //                 SizedBox(width: 2),
          //                 Expanded(
          //                   child: Material(
          //                     elevation: 4,
          //                     child: Container(
          //                       height: 50,
          //                       width: MediaQuery.of(context).size.width * .6,
          //                       decoration: BoxDecoration(
          //                         borderRadius: BorderRadius.circular(2),
          //                         border: Border.all(
          //                           color: Color(0xFF8A95A8),
          //                         ),
          //                       ),
          //                       child: Stack(
          //                         children: [
          //                           Positioned.fill(
          //                             child: TextField(
          //                               onChanged: (value) {
          //                                 setState(() {
          //                                   taxiderror = false;
          //                                 });
          //                               },
          //                               controller: taxid,
          //                               cursorColor:
          //                               blueColor,
          //                               decoration: InputDecoration(
          //                                 hintText: "Enter SSN or EIN",
          //                                 hintStyle: TextStyle(
          //                                   fontSize: MediaQuery.of(context)
          //                                       .size
          //                                       .width <
          //                                       500
          //                                       ? 15
          //                                       : 18,
          //                                   color: Color(0xFF8A95A8),
          //                                 ),
          //                                 enabledBorder: taxiderror
          //                                     ? OutlineInputBorder(
          //                                   borderRadius:
          //                                   BorderRadius.circular(2),
          //                                   borderSide: BorderSide(
          //                                     color: Colors.red,
          //                                   ),
          //                                 )
          //                                     : InputBorder.none,
          //                                 border: InputBorder.none,
          //                                 contentPadding: EdgeInsets.all(12),
          //                               ),
          //                             ),
          //                           ),
          //                         ],
          //                       ),
          //                     ),
          //                   ),
          //                 ),
          //                 SizedBox(width: 2),
          //               ],
          //             ),
          //             taxiderror
          //                 ? Row(
          //               children: [
          //                 Spacer(),
          //                 Text(
          //                   taxidmessage,
          //                   style: TextStyle(
          //                       color: Colors.red,
          //                       fontSize:
          //                       MediaQuery.of(context).size.width <
          //                           500
          //                           ? 15
          //                           : 19),
          //                 ),
          //                 SizedBox(
          //                   width: 2,
          //                 ),
          //               ],
          //             )
          //                 : Container(),
          //           ],
          //         ),
          //       ),
          //     ),
          //   ),
          // ),
          // SizedBox(
          //   height: 20,
          // ),
          Row(
            children: [
              if (MediaQuery.of(context).size.width < 500)
                SizedBox(width: MediaQuery.of(context).size.width * 0.04),
              if (MediaQuery.of(context).size.width > 500)
                const SizedBox(
                  width: 25,
                ),
              Expanded(
                child: GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                    },
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.white,
                          border: Border.all(color: const Color(0x80152B51))
                          // boxShadow: [
                          //   BoxShadow(
                          //     color: Colors.grey,
                          //     offset: Offset(0.0, 1.0), //(x,y)
                          //     blurRadius: 6.0,
                          //   ),
                          // ],
                          ),
                      child: Center(
                        child: Text(
                          "Cancel",
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: MediaQuery.of(context).size.width < 500
                                  ? 15
                                  : 18),
                        ),
                      ),
                    )),
              ),
              const SizedBox(
                width: 15,
              ),
              Expanded(
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(5),
                      color: const Color(0xFF101828)),
                  child: GestureDetector(
                    onTap: () async {
                      if (name.text.trim().isEmpty) {
                        setState(() {
                          nameerror = true;
                          namemessage = "required";
                        });
                      } else {
                        setState(() {
                          nameerror = false;
                        });
                      }
                      if (comname.text.trim().isEmpty) {
                        setState(() {
                          comnameerror = true;
                          comnamemessage = "required";
                        });
                      } else {
                        setState(() {
                          comnameerror = false;
                        });
                      }
                      // if (birthdateController.text.isEmpty) {
                      //   setState(() {
                      //     birthdateerror = true;
                      //     birthdatemessage = "required";
                      //   });
                      // } else {
                      //   setState(() {
                      //     birthdateerror = false;
                      //   });
                      // }
                      /* if (startdateController.text.isEmpty) {
                    setState(() {
                      startdatederror = true;
                      startdatemessage = "required";
                    });
                  } else {
                    setState(() {
                      startdatederror = false;
                    });
                  }
                  if (enddateController.text.isEmpty) {
                    setState(() {
                      enddatederror = true;
                      enddatemessage = "required";
                    });
                  } else {
                    setState(() {
                      enddatederror = false;
                    });
                  }*/
                      if (primaryemail.text.trim().isEmpty) {
                        setState(() {
                          primaryemailerror = true;
                          primaryemailmessage = "required";
                        });
                      } else if (!EmailValidator.validate(
                          primaryemail.text.trim())) {
                        setState(() {
                          primaryemailerror = true;
                          primaryemailmessage = "Email is not valid";
                        });
                      } else {
                        setState(() {
                          primaryemailerror = false;
                        });
                      }
                      /* if (alternativeemail.text.isEmpty) {
                    setState(() {
                      alternativeerror = true;
                      alternativemessage = "required";
                    });
                  } else {
                    setState(() {
                      alternativeerror = false;
                    });
                  }*/
                      if (alternativeemail.text.trim().isEmpty) {
                        setState(() {
                          alternativeerror = false;
                        });
                      } else if (!EmailValidator.validate(
                          alternativeemail.text)) {
                        setState(() {
                          alternativeerror = true;
                          alternativemessage = "Email is not valid";
                        });
                      } else if (alternativeemail.text.trim() ==
                          primaryemail.text.trim()) {
                        setState(() {
                          alternativeerror = true;
                          alternativemessage =
                              "Email cannot be the same as primary";
                        });
                      } else {
                        setState(() {
                          alternativeerror = false;
                        });
                      }
                      // if (alternativeemail.text.trim().isEmpty) {
                      //   setState(() {
                      //     alternativeerror = false;
                      //
                      //   });
                      // }else if(alternativeemail.text == primaryemail.text){
                      //   setState(() {
                      //     alternativeerror = true;
                      //     alternativemessage = " email cannot be the same";
                      //   });
                      // } else {
                      //   setState(() {
                      //     alternativeerror = false;
                      //   });
                      // }

                      String formattedPhoneNumber =
                          phonenum.text.replaceAll(RegExp(r'\D'), '');
                      if (formattedPhoneNumber.isEmpty) {
                        setState(() {
                          phonenumerror = true;
                          phonenummessage = "required";
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
                      } else if (formattedhomeNumber == formattedPhoneNumber) {
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
                          officenum.text.replaceAll(RegExp(r'\D'), '');
                      if (formattedofficeNumber.isEmpty) {
                        setState(() {
                          officenumerror = false;
                        });
                      } else if (formattedofficeNumber.length != 10) {
                        setState(() {
                          officenumerror = true;
                          officenummessage = "Phone number must be 10 digits";
                        });
                      } else if (formattedofficeNumber == formattedhomeNumber) {
                        setState(() {
                          officenumerror = true;
                          officenummessage = " number cannot be the same";
                        });
                      } else {
                        setState(() {
                          officenumerror = false;
                        });
                      }
                      /*  if (homenum.text.isEmpty) {
                    setState(() {
                      homenumerror = true;
                      homenummessage = "required";
                    });
                  } else {
                    setState(() {
                      homenumerror = false;
                    });
                  }
                  if (officenum.text.isEmpty) {
                    setState(() {
                      officenumerror = true;
                      officenummessage = "required";
                    });
                  } else {
                    setState(() {
                      officenumerror = false;
                    });
                  }
                  if (street2.text.isEmpty) {
                    setState(() {
                      street2error = true;
                      street2message = "required";
                    });
                  } else {
                    setState(() {
                      street2error = false;
                    });
                  }
                  if (city2.text.isEmpty) {
                    setState(() {
                      city2error = true;
                      city2message = "required";
                    });
                  } else {
                    setState(() {
                      city2error = false;
                    });
                  }
                  if (state2.text.isEmpty) {
                    setState(() {
                      state2error = true;
                      state2message = "required";
                    });
                  } else {
                    setState(() {
                      state2error = false;
                    });
                  }
                  if (city2.text.isEmpty) {
                    setState(() {
                      city2error = true;
                      city2message = "required";
                    });
                  } else {
                    setState(() {
                      city2error = false;
                    });
                  }
                  if (county2.text.isEmpty) {
                    setState(() {
                      county2error = true;
                      county2message = "required";
                    });
                  } else {
                    setState(() {
                      county2error = false;
                    });
                  }
                  if (code2.text.isEmpty) {
                    setState(() {
                      code2error = true;
                      code2message = "required";
                    });
                  } else {
                    setState(() {
                      code2error = false;
                    });
                  }
                  if (taxtype.text.isEmpty) {
                    setState(() {
                      taxtypeerror = true;
                      taxtypemessage = "required";
                    });
                  } else {
                    setState(() {
                      taxtypeerror = false;
                    });
                  }
                  if (taxid.text.isEmpty) {
                    setState(() {
                      taxiderror = true;
                      taxidmessage = "required";
                    });
                  } else {
                    setState(() {
                      taxiderror = false;
                    });
                  }*/
                      if (!nameerror &&
                              !comnameerror &&
                              !primaryemailerror &&
                              !alternativeerror &&
                              !phonenumerror &&
                              !homenumerror &&
                              !officenumerror
                          // !street2error &&
                          // !city2error &&
                          //  !state2error &&
                          // !county2error &&
                          //    !code2error &&
                          //  !taxtypeerror &&
                          //     !taxiderror &&
                          // !birthdateerror &&
                          //     !startdatederror &&
                          //    !enddatederror
                          ) {
                        setState(() {
                          loading = true;
                        });

                        // List<ProcessorList> processor = [];
                        // for (var i = 0; i < _controllers.length; i++) {
                        //   if (_controllers.isNotEmpty)
                        //     processor.add(
                        //         ProcessorList(processorId: _controllers[i]!.text));
                        // }

                        List<ProcessorList> processorList = [];
                        _controllers.forEach((key, controller) {
                          if (controller.text.trim().isNotEmpty) {
                            processorList.add(
                                ProcessorList(processorId: controller.text));
                          }
                        });
                        // Convert display format to API format (yyyy-MM-dd)
                        String convertToApiFormat(String displayDate) {
                          if (displayDate.isEmpty) return "";
                          return reverseFormatDate(displayDate);
                        }

                        SharedPreferences prefs =
                            await SharedPreferences.getInstance();
                        var adminId = prefs.getString("adminId");
                        final RentalOwnerData rentalOwner = RentalOwnerData(
                          adminId: adminId,
                          rentalOwnername: name.text.trim(),
                          rentalOwnerLastName: lastname.text.trim(),
                          rentalOwnerCompanyName: comname.text.trim(),
                          // startDate: reverseFormatDate(
                          //     startdateController.text.trim()),
                          startDate: convertToApiFormat(
                              startdateController.text.trim()),
                          endDate:
                              convertToApiFormat(enddateController.text.trim()),
                          rentalOwnerPrimaryEmail: primaryemail.text.trim(),
                          rentalOwnerAlternateEmail: alternativeemail.text,
                          rentalOwnerPhoneNumber: phonenum.text.trim(),
                          rentalOwnerHomeNumber: homenum.text.trim(),
                          rentalOwnerBusinessNumber: officenum.text.trim(),
                          streetAddress: street2.text.trim(),
                          city: city2.text.trim(),
                          state: state2.text.trim(),
                          postalCode: code2.text.trim(),
                          country: county2.text.trim(),
                          textIdentityType: taxtype.text.trim(),
                          texpayerId: taxid.text.trim(),
                          // processorLists:processorIds,
                          processorList: processorList,
                          achProcessorId: achProcessorId.text.trim(),
                        );
                        // print(processorIds);
                        // var result =
                        //     await RentalOwnerService().addRentalOwner(rentalOwner);
                        // if (result) {
                        //   Navigator.of(context).pop(result);
                        // }else{
                        //   print("faild");
                        // }
                        RentalOwnerService()
                            .addRentalOwner(rentalOwner)
                            .then((result) async {
                          setState(() {
                            loading = false;
                          });
                          if (result != "") {
                            await updatePaymentSettings(result);
                            Navigator.of(context).pop(result);
                          } else {
                          }
                        }).catchError((e) {
                          setState(() {
                            loading = false;
                          });
                        });
                      }
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(5.0),
                      child: Container(
                        height: 40,
                        // width: MediaQuery.of(context).size.width < 500 ? 160 : 190,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(5.0),
                          color: blueColor,
                          boxShadow: [
                            const BoxShadow(
                              color: Colors.grey,
                              offset: Offset(0.0, 1.0), //(x,y)
                              blurRadius: 6.0,
                            ),
                          ],
                        ),
                        child: Center(
                          child: loading
                              ? const SpinKitFadingCircle(
                                  color: Colors.white,
                                  size: 20.0,
                                )
                              : Text(
                                  "Add Rental Owner",
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize:
                                          MediaQuery.of(context).size.width <
                                                  500
                                              ? 15
                                              : 20),
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(
                width: 15,
              ),
            ],
          ),
          const SizedBox(
            height: 20,
          ),
        ],
      ),
    );
  }

  bool isloading = false;
  Future<void> updatePaymentSettings(String? rentalownerId) async {
    if (!mounted) return; // Prevents calling setState if widget is disposed

    setState(() {
      isloading = true;
    });

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');
      String? id = prefs.getString('adminId');

      final url = '${Api_url}/api/payment/rental_owner/setting';
      final headers = {
        "authorization": "CRM $token",
        "id": "CRM ${prefs.getString('staff_id') ?? id}",
        'Content-Type': 'application/json; charset=UTF-8',
      };

      final body = json.encode({
        "creditCardAccepted": creditcard,
        "achAccepted": achaccepted,
        "debitCardAccepted": debitcard,
        "rentalOwnerId": rentalownerId ?? "",
      });

      final response =
          await apiPost(Uri.parse(url), headers: headers, body: body);

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        //Fluttertoast.showToast(msg: responseData["message"]);
      } else {
        final responseData = json.decode(response.body);
        throw Exception(
            responseData["message"] ?? 'Failed to update card type');
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('An error occurred: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isloading = false;
        });
      }
    }
  }
}

import 'package:three_zero_two_property/services/app_log.dart';
import 'dart:convert';

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
import 'package:three_zero_two_property/constant/constant.dart';
import 'package:three_zero_two_property/widgets/clearable_date_picker.dart';
import 'package:three_zero_two_property/widgets/clearable_date_suffix.dart';
import '../../../widgets/appbar.dart';
import 'package:three_zero_two_property/widgets/us_state_dropdown.dart';
import 'package:http/http.dart' as http;
import 'package:three_zero_two_property/services/api_helpers.dart';
import '../../../../Model/RentalOwnersData.dart';
import '../../../model/rentalOwner.dart';
import '../../../model/rentalowners_summery.dart';
import '../../../repository/Rental_ownersData.dart';
import '../../../repository/Staffmember.dart';
import '../../../widgets/drawer_tiles.dart';
import '../../../widgets/custom_drawer.dart';
import '../../../../provider/dateProvider.dart';
import 'package:provider/provider.dart';

class Edit_rentalowners extends StatefulWidget {
  RentalOwnerData rentalOwner;
  Edit_rentalowners({super.key, required this.rentalOwner});

  @override
  State<Edit_rentalowners> createState() => _Edit_rentalownersState();
}

class _Edit_rentalownersState extends State<Edit_rentalowners> {
  TextEditingController name = TextEditingController();
  TextEditingController lastname = TextEditingController();
  TextEditingController comname = TextEditingController();
  TextEditingController primaryemail = TextEditingController();
  TextEditingController alternativeemail = TextEditingController();
  TextEditingController phonenum = TextEditingController();
  TextEditingController homenum = TextEditingController();
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
  String officenummessage = "";
  String street2message = "";
  String city2message = "";
  String state2message = "";
  String county2message = "";
  String code2message = "";
  String proidmessage = "";
  String taxtypemessage = "";
  String taxidmessage = "";

  bool isLoading = false;
  Map<int, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    // Initialize with one text field
    _controllers[0] = TextEditingController();
    name.text = widget.rentalOwner.rentalOwnername!;
    comname.text = widget.rentalOwner.rentalOwnerCompanyName!;
    // comname.text = widget.rentalOwner.rentalOwnerCompanyName!;
    primaryemail.text = widget.rentalOwner.rentalOwnerPrimaryEmail!;
    alternativeemail.text = widget.rentalOwner.rentalOwnerAlternateEmail!;
    phonenum.text =
        formatPhoneNumberedit(widget.rentalOwner.rentalOwnerPhoneNumber!);
    homenum.text =
        formatPhoneNumberedit(widget.rentalOwner.rentalOwnerHomeNumber!);
    officenum.text =
        formatPhoneNumberedit(widget.rentalOwner.rentalOwnerBusinessNumber!);
    street2.text = widget.rentalOwner.streetAddress!;
    city2.text = widget.rentalOwner.city!;
    state2.text = widget.rentalOwner.state!;
    county2.text = widget.rentalOwner.country!;
    code2.text = widget.rentalOwner.postalCode!;
    //proid.text = widget.rentalOwner.processorLists.toString();
    taxtype.text = widget.rentalOwner.textIdentityType!;
    taxid.text = widget.rentalOwner.texpayerId!;
    achProcessorId.text = widget.rentalOwner.achProcessorId ?? "";
    //birthdateController.text = widget.rentalOwner.b;
    // Convert API format (yyyy-MM-dd) to display format using DateProvider
    String convertToDisplayFormat(String apiDate) {
      if (apiDate.isEmpty) return "";
      try {
        // Get dateProvider to format the date according to user's preference
        final dateProvider = Provider.of<DateProvider>(context, listen: false);
        return dateProvider.formatCurrentDate(apiDate);
      } catch (e) {
        return apiDate; // Return as is if parsing fails
      }
    }

    startdateController.text =
        convertToDisplayFormat(widget.rentalOwner.startDate!);
    enddateController.text =
        convertToDisplayFormat(widget.rentalOwner.endDate!);

    if (widget.rentalOwner.processorList != null) {
      for (int i = 0; i < widget.rentalOwner.processorList!.length; i++) {
        _controllers[i] = TextEditingController(
          text: widget.rentalOwner.processorList![i].processorId,
        );
      }
    } else {
      _controllers[0] = TextEditingController();
    }

    initialName = widget.rentalOwner.rentalOwnername;
    initialCompanyName = widget.rentalOwner.rentalOwnerCompanyName;
    initialPrimaryEmail = widget.rentalOwner.rentalOwnerPrimaryEmail;
    initialAlternativeEmail = widget.rentalOwner.rentalOwnerAlternateEmail;
    initialPhoneNumber = widget.rentalOwner.rentalOwnerPhoneNumber;
    initialHomeNumber = widget.rentalOwner.rentalOwnerHomeNumber;
    initialOfficeNumber = widget.rentalOwner.rentalOwnerBusinessNumber;
    initialStreetAddress = widget.rentalOwner.streetAddress;
    initialCity = widget.rentalOwner.city;
    initialState = widget.rentalOwner.state;
    initialCountry = widget.rentalOwner.country;
    initialPostalCode = widget.rentalOwner.postalCode;
    initialTaxId = widget.rentalOwner.texpayerId;
    initialTaxType = widget.rentalOwner.textIdentityType;
    initialStartDate = convertToDisplayFormat(widget.rentalOwner.startDate!);
    initialEndDate = convertToDisplayFormat(widget.rentalOwner.endDate!);
    fetchPaymentSettings();
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
    startdateController.dispose();
    enddateController.dispose();
    // The dynamically added rows keep their controllers in this map.
    for (final c in _controllers.values) {
      c.dispose();
    }
    _controllers.clear();
    super.dispose();
  }


  String? initialName;
  String? initialCompanyName;
  String? initialPrimaryEmail;
  String? initialAlternativeEmail;
  String? initialPhoneNumber;
  String? initialHomeNumber;
  String? initialOfficeNumber;
  String? initialStreetAddress;
  String? initialCity;
  String? initialState;
  String? initialCountry;
  String? initialPostalCode;
  String? initialTaxId;
  String? initialTaxType;
  String? initialStartDate;
  String? initialEndDate;
  bool? initialcreditcard;
  bool? initialdebitcard;
  bool? initialachaccepted;
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

  //TextEditingController birthdateController = TextEditingController();
  TextEditingController startdateController = TextEditingController();
  TextEditingController enddateController = TextEditingController();

  // bool birthdateerror = false;
  bool startdatederror = false;
  bool enddatederror = false;

  //String birthdatemessage = "";
  String startdatemessage = "";
  String enddatemessage = "";

  //DateTime? birthdate;
  DateTime? startdate;
  DateTime? enddate;

  // Future<void> _startDate(BuildContext context) async {
  //   final DateTime? picked = await showDatePicker(
  //     context: context,
  //     initialDate: startdate ?? DateTime.now(),
  //     firstDate: DateTime(2015, 8),
  //     lastDate: DateTime(2101),
  //     builder: (BuildContext context, Widget? child) {
  //       return Theme(
  //         data: ThemeData.light().copyWith(
  //           primaryColor:
  //               blueColor, // Header background color
  //           // accentColor: Colors.white, // Button text color
  //           colorScheme:  ColorScheme.light(
  //             primary: blueColor, // Selection color
  //             onPrimary: Colors.white, // Text color
  //             surface: Colors.white, // Calendar background color
  //             onSurface: Colors.black, // Calendar text color
  //           ),
  //           dialogBackgroundColor: Colors.white, // Background color
  //         ),
  //         child: child!,
  //       );
  //     },
  //   );
  //   if (picked != null && picked != startdate) {
  //     setState(() {
  //       startdate = picked;
  //       // startdateController.text = DateFormat('yyyy-MM-dd').format(picked);
  //       startdateController.text = DateFormat('dd-MM-yyyy').format(picked);
  //       // Use this format (yyyy-MM-dd) when passing it to your API or saving it
  //       String dateForApi = DateFormat('yyyy-MM-dd').format(picked);
  //       print(dateForApi);
  //     });
  //   }
  // }
  //
  // Future<void> _endDate(BuildContext context) async {
  //   final DateTime? picked = await showDatePicker(
  //     context: context,
  //     initialDate: enddate ?? DateTime.now(),
  //     // firstDate: DateTime(2015, 8),
  //     firstDate: startdate!,
  //     lastDate: DateTime(2101),
  //     builder: (BuildContext context, Widget? child) {
  //       return Theme(
  //         data: ThemeData.light().copyWith(
  //           primaryColor:
  //               blueColor, // Header background color
  //           // accentColor: Colors.white, // Button text color
  //           colorScheme:  ColorScheme.light(
  //             primary: blueColor, // Selection color
  //             onPrimary: Colors.white, // Text color
  //             surface: Colors.white, // Calendar background color
  //             onSurface: Colors.black, // Calendar text color
  //           ),
  //           dialogBackgroundColor: Colors.white, // Background color
  //         ),
  //         child: child!,
  //       );
  //     },
  //   );
  //   if (picked != null && picked != enddate) {
  //     setState(() {
  //       enddate = picked;
  //       //birthdateController.text = DateFormat('yyyy-MM-dd').format(picked);
  //       //startdateController.text = DateFormat('yyyy-MM-dd').format(picked);
  //       enddateController.text = DateFormat('dd-MM-yyyy').format(picked);
  //     });
  //   }
  // }
  // Future<void> _startDate(BuildContext context) async {
  //   DateTime initialDate = startdateController.text.isNotEmpty
  //       ? DateFormat('dd-MM-yyyy').parse(startdateController.text)
  //       : DateTime.now();
  //   final DateTime? picked = await showDatePicker(
  //     context: context,
  //     initialDate: initialDate,
  //     //  initialDate: startdate ?? DateTime.now(),
  //     firstDate: DateTime(2015, 8),
  //     lastDate: DateTime(2101),
  //     builder: (BuildContext context, Widget? child) {
  //       return Theme(
  //         data: ThemeData.light().copyWith(
  //           primaryColor: blueColor, // Header background color
  //           // accentColor: Colors.white, // Button text color
  //           colorScheme: ColorScheme.light(
  //             primary: blueColor, // Selection color
  //             onPrimary: Colors.white, // Text color
  //             surface: Colors.white, // Calendar background color
  //             onSurface: Colors.black, // Calendar text color
  //           ),
  //           dialogBackgroundColor: Colors.white, // Background color
  //         ),
  //         child: child!,
  //       );
  //     },
  //   );
  //   if (picked != null && picked != startdate) {
  //     setState(() {
  //       startdate = picked;
  //       // startdateController.text = DateFormat('yyyy-MM-dd').format(picked);
  //       startdateController.text = DateFormat('dd-MM-yyyy').format(picked);
  //       // Use this format (yyyy-MM-dd) when passing it to your API or saving it
  //       String dateForApi = DateFormat('yyyy-MM-dd').format(picked);
  //       print(dateForApi);
  //     });
  //   }
  // }
  //
  // Future<void> _endDate(BuildContext context) async {
  //   DateTime initialDate = startdateController.text.isNotEmpty
  //       ? DateFormat('dd-MM-yyyy').parse(startdateController.text)
  //       : DateTime.now();
  //
  //   final DateTime? picked = await showDatePicker(
  //     context: context,
  //     initialDate: initialDate,
  //     firstDate: initialDate, // Dynamically set based on startdate
  //     //firstDate: DateTime(2015, 8), // Dynamically set based on startdate
  //     lastDate: DateTime(2101), // Far future date as upper limit
  //     builder: (BuildContext context, Widget? child) {
  //       return Theme(
  //         data: ThemeData.light().copyWith(
  //           primaryColor: blueColor, // Header background color
  //           colorScheme: ColorScheme.light(
  //             primary: blueColor, // Selection color
  //             onPrimary: Colors.white, // Text color
  //             surface: Colors.white, // Calendar background color
  //             onSurface: Colors.black, // Calendar text color
  //           ),
  //           dialogBackgroundColor: Colors.white, // Background color
  //         ),
  //         child: child!,
  //       );
  //     },
  //   );
  //
  //   if (picked != null && picked != enddate) {
  //     setState(() {
  //       enddate = picked;
  //       enddateController.text = DateFormat('dd-MM-yyyy').format(picked);
  //       String dateForApi = DateFormat('yyyy-MM-dd').format(picked);
  //       print(dateForApi); // For API usage
  //     });
  //   }
  // }
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
    final ClearableDatePickerResult? startResult =
        await showClearableDatePicker(
      context: context,
      initialDate: startdate ?? DateTime.now(),
      firstDate: DateTime(2015, 8),
      lastDate: DateTime(2101),
      helpText: 'Select start date',
    );
    if (startResult == null) return; // cancelled — keep the current value
    if (startResult.cleared) {
      _clearStartDate();
      return;
    }
    final DateTime? picked = startResult.date;
    if (picked != null && picked != startdate) {
      setState(() {
        startdate = picked;
        // Get dateProvider to format the date according to user's preference
        final dateProvider = Provider.of<DateProvider>(context, listen: false);
        // Display format: Use provider's format for user display
        startdateController.text =
            DateFormat(dateProvider.dateFormat).format(picked);

        // Check if the new start date is later than the current end date
        if (enddateController.text.isNotEmpty) {
          try {
            // The field text is written using the provider's format (see
            // above), not a fixed 'MM-dd-yyyy' — parsing with a hardcoded
            // format silently failed (caught below) whenever the account uses
            // a different one, which skipped this validation entirely.
            DateTime currentEndDate =
                DateFormat(dateProvider.dateFormat).parse(enddateController.text);
            if (picked.isAfter(currentEndDate)) {
              // Clear the end date if start date is after end date
              enddateController.clear();
              enddate = null;
            }
            // If start date is before or equal to end date, keep the end date
            // This allows valid date ranges like start: 22, end: 23
          } catch (e) {
            // If parsing fails, just continue
            logError('Error parsing end date: $e');
          }
        }
      });
    }
  }

  Future<void> _endDate(BuildContext context) async {
    // Parse the start date from the controller to get the current start date
    DateTime? currentStartDate;
    try {
      if (startdateController.text.isNotEmpty) {
        // Get dateProvider to parse the date from display format
        final dateProvider = Provider.of<DateProvider>(context, listen: false);
        // Convert display format back to yyyy-MM-dd for parsing
        String apiFormatDate =
            dateProvider.formatCurrentDate(startdateController.text);
        currentStartDate = DateFormat('yyyy-MM-dd').parse(apiFormatDate);
      }
    } catch (e) {
      currentStartDate = DateTime.now();
    }

    // Set initial date for end date picker
    DateTime initialEndDate;
    if (enddateController.text.isNotEmpty) {
      try {
        // Get dateProvider to parse the date from display format
        final dateProvider = Provider.of<DateProvider>(context, listen: false);
        // Convert display format back to yyyy-MM-dd for parsing
        String apiFormatDate =
            dateProvider.formatCurrentDate(enddateController.text);
        DateTime parsedEndDate = DateFormat('yyyy-MM-dd').parse(apiFormatDate);
        // Only use the current end date if it's after the start date
        if (parsedEndDate.isAfter(currentStartDate ?? DateTime.now())) {
          initialEndDate = parsedEndDate;
        } else {
          // If current end date is before or equal to start date, use start date + 1 day
          initialEndDate =
              (currentStartDate ?? DateTime.now()).add(const Duration(days: 1));
        }
      } catch (e) {
        // If parsing fails, use start date + 1 day
        initialEndDate =
            (currentStartDate ?? DateTime.now()).add(const Duration(days: 1));
      }
    } else {
      // If no end date is set, use start date + 1 day
      initialEndDate =
          (currentStartDate ?? DateTime.now()).add(const Duration(days: 1));
    }


    final ClearableDatePickerResult? endResult = await showClearableDatePicker(
      context: context,
      initialDate: initialEndDate,
      firstDate: currentStartDate ?? DateTime.now(),
      // firstDate: DateTime(2015, 8),
      lastDate: DateTime(2101),
      helpText: 'Select end date',
    );
    if (endResult == null) {
      return; // cancelled — keep the current value
    }
    if (endResult.cleared) {
      _clearEndDate();
      return;
    }
    final DateTime? picked = endResult.date;
    if (picked != null && picked != enddate) {
      setState(() {
        enddate = picked;
        // Get dateProvider to format the date according to user's preference
        final dateProvider = Provider.of<DateProvider>(context, listen: false);
        // Display format: Use provider's format for user display
        enddateController.text =
            DateFormat(dateProvider.dateFormat).format(picked);
      });
    } else if (picked == null) {
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

  //for card payment

  bool creditcard = true;
  bool achaccepted = false;
  bool debitcard = true;
  bool isloading = false;

  Future<void> fetchPaymentSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString("adminId");
    String? token = prefs.getString('token');
    String? staffid = prefs.getString("staff_id");
    final response = await apiGet(
      Uri.parse(
          '${Api_url}/api/payment/rental_owner/setting/${widget.rentalOwner.rentalownerId}'),
      headers: {
        "authorization": "CRM $token",
        "id": "CRM $staffid",
      },
    );
    final jsonData = json.decode(response.body);
    if (jsonData["statusCode"] == 200 || jsonData["statusCode"] == 201) {
      setState(() {
        creditcard = jsonData['data']['creditCardAccepted'] ?? true;
        achaccepted = jsonData['data']['achAccepted'] ?? false;
        debitcard = jsonData['data']['debitCardAccepted'] ?? true;
        initialdebitcard = debitcard;
        initialcreditcard = creditcard;
        initialachaccepted = achaccepted;
      });
    } else {
      throw Exception('Failed to load data');
    }
  }

  //for update payment

  Future<void> updatePaymentSettings() async {
    setState(() {
      isloading = true; // Show loading indicator
    });
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');
    String? id = prefs.getString('adminId');
    String? staffid = prefs.getString("staff_id");
    final url = '${Api_url}/api/payment/rental_owner/setting';
    final headers = {
      "authorization": "CRM $token",
      "id": "CRM $staffid",
      'Content-Type': 'application/json; charset=UTF-8',
    };
    final body = json.encode({
      "creditCardAccepted": creditcard,
      "achAccepted": achaccepted,
      "debitCardAccepted": debitcard,
      "rentalOwnerId": widget.rentalOwner.rentalownerId,
    });

    try {
      final response =
          await apiPost(Uri.parse(url), headers: headers, body: body);

      var responseData = json.decode(response.body);
      if (responseData["statusCode"] == 200) {
        // Fluttertoast.showToast(msg: responseData["message"]);
        return json.decode(response.body);
      } else {
        Fluttertoast.showToast(msg: responseData["message"]);
        throw Exception('Failed to update card type');
      }
    } catch (error) {
      // Handle network error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred: $error')),
      );
    } finally {
      setState(() {
        isloading = false; // Hide loading indicator
      });
    }
  }

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
                  "Edit Rental Owner ",
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
                child: GestureDetector(
                  onTap: () async {
                    bool isFormValid = true;

                    // Validate each field and update the state accordingly
                    if (name.text.trim().isEmpty) {
                      setState(() {
                        nameerror = true;
                        namemessage = "required";
                        isFormValid = false;
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
                        isFormValid = false;
                      });
                    } else {
                      setState(() {
                        comnameerror = false;
                      });
                    }

                    if (primaryemail.text.trim().isEmpty) {
                      setState(() {
                        primaryemailerror = true;
                        primaryemailmessage = "required";
                        isFormValid = false;
                      });
                    } else if (!EmailValidator.validate(primaryemail.text)) {
                      setState(() {
                        primaryemailerror = true;
                        primaryemailmessage = "Email is not valid";
                        isFormValid = false;
                      });
                    } else {
                      setState(() {
                        primaryemailerror = false;
                      });
                    }
                    if (alternativeemail.text.trim().isNotEmpty) {
                      if (alternativeemail.text.trim() ==
                          primaryemail.text.trim()) {
                        isFormValid = false;
                        setState(() {
                          alternativeerror = true;
                          alternativemessage = "Email cannot be the same";
                        });
                      } else if (!EmailValidator.validate(
                          alternativeemail.text.trim())) {
                        isFormValid = false;
                        setState(() {
                          alternativeerror = true;
                          alternativemessage = "Email is not valid";
                        });
                      } else {
                        setState(() {
                          alternativeerror = false;
                        });
                      }
                    }

                    // if (alternativeemail.text.trim().isNotEmpty) {
                    //   if (alternativeemail.text == primaryemail.text) {
                    //     setState(() {
                    //       alternativeerror = true;
                    //       alternativemessage = "Email cannot be the same";
                    //       isFormValid = false;
                    //     });
                    //   } else if (!EmailValidator.validate(
                    //       alternativeemail.text)) {
                    //     setState(() {
                    //       alternativeerror = true;
                    //       alternativemessage = "Email is not valid";
                    //       isFormValid = false;
                    //     });
                    //   } else {
                    //     setState(() {
                    //       alternativeerror = false;
                    //     });
                    //   }
                    // }
                    String formattedPhoneNumber =
                        phonenum.text.replaceAll(RegExp(r'\D'), '');
                    if (formattedPhoneNumber.isEmpty) {
                      setState(() {
                        phonenumerror = true;
                        phonenummessage = "required";
                        isFormValid = false;
                      });
                    } else if (formattedPhoneNumber.length != 10) {
                      setState(() {
                        phonenumerror = true;
                        phonenummessage = "Phone number must be 10 digits";
                        isFormValid = false;
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
                        isFormValid = false;
                      });
                    } else if (formattedhomeNumber == formattedPhoneNumber) {
                      setState(() {
                        homenumerror = true;
                        homenummessage = " number cannot be the same";
                        isFormValid = false;
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
                        isFormValid = false;
                      });
                    } else if (formattedofficeNumber == formattedhomeNumber) {
                      setState(() {
                        officenumerror = true;
                        officenummessage = " number cannot be the same";
                        isFormValid = false;
                      });
                    } else {
                      setState(() {
                        officenumerror = false;
                      });
                    }
                    // Validate other fields similarly...
                    String? isProcessorListChanged =
                        widget.rentalOwner.processorList != null &&
                                widget.rentalOwner.processorList!.isNotEmpty
                            ? widget
                                .rentalOwner.processorList!.first.processorId
                            : "";

                    // Check for changes
                    bool hasChanges = name.text != initialName ||
                        comname.text != initialCompanyName ||
                        primaryemail.text != initialPrimaryEmail ||
                        alternativeemail.text != initialAlternativeEmail ||
                        phonenum.text != initialPhoneNumber ||
                        homenum.text != initialHomeNumber ||
                        officenum.text != initialOfficeNumber ||
                        street2.text != initialStreetAddress ||
                        city2.text != initialCity ||
                        state2.text != initialState ||
                        county2.text != initialCountry ||
                        code2.text != initialPostalCode ||
                        taxid.text != initialTaxId ||
                        taxtype.text != initialTaxType ||
                        creditcard != initialcreditcard ||
                        debitcard != initialdebitcard ||
                        achaccepted != initialachaccepted ||
                        startdateController.text != initialStartDate ||
                        enddateController.text != initialEndDate ||
                        _controllers[0]!.text != isProcessorListChanged;

                    if (!hasChanges) {
                      Navigator.of(context)
                          .pop(false); // Optionally navigate back
                      return;
                    }

                    if (!isFormValid) {
                      return; // Exit early if the form is not valid
                    }

                    SharedPreferences prefs =
                        await SharedPreferences.getInstance();
                    String? adminId = prefs.getString("adminId");

                    // Prepare the processor list
                    List<ProcessorList> processorList = [];
                    _controllers.forEach((key, controller) {
                      if (controller.text.trim().isNotEmpty) {
                        processorList
                            .add(ProcessorList(processorId: controller.text));
                      }
                    });

                    // Convert display format to API format (yyyy-MM-dd)
                    String convertToApiFormat(String displayDate) {
                      if (displayDate.isEmpty) return "";
                      return reverseFormatDate(displayDate);
                    }

                    try {
                      setState(() {
                        isLoading = true;
                      });
                      await RentalOwnerService().Edit_Rentalowners(
                        adminId: adminId,
                        rentalownerId: widget.rentalOwner.rentalownerId,
                        rentalOwnerName: name.text.trim(),
                        rentalOwnerCompanyName: comname.text.trim(),
                        rentalOwnerPrimaryEmail: primaryemail.text.trim(),
                        rentalOwnerAlternateEmail: alternativeemail.text.trim(),
                        rentalOwnerPhoneNumber: phonenum.text.trim(),
                        rentalOwnerHomeNumber: homenum.text.trim(),
                        rentalOwnerBusinessNumber: officenum.text.trim(),
                        startDate:
                            convertToApiFormat(startdateController.text.trim()),
                        endDate:
                            convertToApiFormat(enddateController.text.trim()),
                        texpayerId: taxid.text.trim(),
                        textIdentityType: taxtype.text.trim(),
                        city: city2.text.trim(),
                        state: state2.text.trim(),
                        streetAddress: street2.text.trim(),
                        country: county2.text.trim(),
                        postalCode: code2.text.trim(),
                        processorList: processorList,
                        achProcessorId: achProcessorId.text.trim(),
                      );

                      setState(() {
                        widget.rentalOwner.rentalOwnername = name.text;
                        widget.rentalOwner.rentalOwnerCompanyName =
                            comname.text;
                        widget.rentalOwner.rentalOwnerPrimaryEmail =
                            primaryemail.text;
                        widget.rentalOwner.rentalOwnerAlternateEmail =
                            alternativeemail.text;
                        widget.rentalOwner.rentalOwnerPhoneNumber =
                            phonenum.text;
                        widget.rentalOwner.rentalOwnerHomeNumber = homenum.text;
                        widget.rentalOwner.rentalOwnerBusinessNumber =
                            officenum.text;
                        widget.rentalOwner.startDate =
                            convertToApiFormat(startdateController.text.trim());
                        widget.rentalOwner.endDate =
                            convertToApiFormat(enddateController.text.trim());
                        widget.rentalOwner.texpayerId = taxid.text;
                        widget.rentalOwner.textIdentityType = taxtype.text;
                        widget.rentalOwner.city = city2.text;
                        widget.rentalOwner.state = state2.text;
                        widget.rentalOwner.streetAddress = street2.text;
                        widget.rentalOwner.country = county2.text;
                        widget.rentalOwner.postalCode = code2.text;
                        widget.rentalOwner.processorList = processorList;
                        widget.rentalOwner.achProcessorId =
                            achProcessorId.text.trim();
                        isLoading = false;
                      });
                      Navigator.pop(context, true);
                      await updatePaymentSettings();
                    } catch (e) {
                      setState(() {
                        isLoading = false;
                      });
                      // Handle error
                    }
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(5.0),
                    child: Container(
                      height: MediaQuery.of(context).size.height * .045,
                      width:
                          MediaQuery.of(context).size.width < 500 ? 160 : 190,
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
                        child: isLoading
                            ? const SpinKitFadingCircle(
                                color: Colors.white,
                                size: 20.0,
                              )
                            : Text(
                                "Edit  Rental Owner",
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize:
                                        MediaQuery.of(context).size.width < 500
                                            ? 15
                                            : 20),
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

  reload_Screen() {
    setState(() {});
  }
}

import 'dart:convert';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:html_editor_enhanced/html_editor.dart';
import 'package:http/http.dart' as http;
import 'package:three_zero_two_property/services/api_helpers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:super_tooltip/super_tooltip.dart';
import 'package:three_zero_two_property/widgets/template_name_date_helper.dart';

import 'package:three_zero_two_property/constant/constant.dart';
import 'package:three_zero_two_property/screens/Rental/Tenants/add_tenants.dart';

import '../../../repository/Communication/Templet_Repo.dart';
import '../../../widgets/appbar.dart';
import '../../../widgets/custom_drawer.dart';

class Add_Email_templet extends StatefulWidget {
  String? templetid;
  Add_Email_templet({super.key, this.templetid});

  @override
  _Add_Email_templetState createState() => _Add_Email_templetState();
}

class _Add_Email_templetState extends State<Add_Email_templet> {
  String? selectedTemplateId;
  GlobalKey<TooltipState> _tooltipKey = GlobalKey<TooltipState>();
  final HtmlEditorController _htmlEditorController = HtmlEditorController();
  final TextEditingController name = TextEditingController();
  final TextEditingController subject = TextEditingController();
  GlobalKey<FormState> _formkey = GlobalKey<FormState>();
  final _controller = SuperTooltipController();
  FocusNode? _subjectFocusNode;
  FocusNode? _bodyFocusNode;
  FocusNode? _nameFocusNode;
  List<Map<String, dynamic>> templates = [];
  bool nameError = false;
  bool subjectError = false;
  bool bodyError = false;
  bool eventError = false;
  String htmlName = ""; // Store HTML content
  String htmlBody = ""; // Store HTML content
  String htmlsubject = ""; // Store HTML content
  String namemessage = "";
  String submessage = "";
  String bodymessage = "";
  String eventmessage = "";

  bool isLoading = false;
  String? _selectedEvent;
  String _selectedType = "E-mail";
  List<String> events = [
    'Reset password',
    'Invitation',
    'Property assign',
    'Lease creation',
    'Work Orders',
    'Payment receipt',
    'LateFee reminder',
    'Lease end Reminder',
    'Express Payment',
    'Payment refund',
    'Applicant application',
    'Applicant status',
    'Payment failure',
    'Manual Tenant',
  ];
  @override
  void initState() {
    super.initState();
    _subjectFocusNode = FocusNode();
    _nameFocusNode = FocusNode();
    if (widget.templetid != null) fetchTemplates();
  }

  String replaceSpanTags(String html) {
    // Mapping class names to corresponding font sizes
    final Map<String, String> classToFontSizeMap = {
      'text-tiny': '1',
      'text-small': '2',
      'text-default': '3',
      'text-big': '5',
      'text-huge': '7',
    };

    // Regex to match <span> with class and/or style attributes
    return html.replaceAllMapped(
      RegExp(r'<span([^>]*)>(.*?)<\/span>', caseSensitive: false),
      (match) {
        String attributes =
            match.group(1) ?? ''; // Extract attributes inside <span>
        String text = match.group(2) ?? ''; // Extract inner text

        // Extract class names
        RegExpMatch? classMatch =
            RegExp(r'class="([^"]+)"').firstMatch(attributes);
        String classNames = classMatch?.group(1) ?? '';

        // Extract styles
        RegExpMatch? styleMatch =
            RegExp(r'style="([^"]+)"').firstMatch(attributes);
        String style = styleMatch?.group(1) ?? '';

        // Extract color from style
        RegExpMatch? colorMatch = RegExp(r'color:\s*([^;]+)').firstMatch(style);
        String? color = colorMatch?.group(1);

        // Extract the first matching class from the known map
        String? fontSize = classNames
            .split(' ')
            .map((cls) => classToFontSizeMap[cls])
            .firstWhere((size) => size != null, orElse: () => null);
        // print(hslToHex(color!));
        // Build the <font> tag
        if (fontSize != null) {
          String fontTag = '<font size="$fontSize"';
          if (color != null) fontTag += ' color="${hslToHex(color!)}"';
          fontTag += '>$text</font>';
          return fontTag;
        }

        return match.group(0)!; // Return original <span> if no match
      },
    );
  }

  String hslToHex(String hsl) {
    // Remove spaces and extract numbers
    RegExp regExp = RegExp(r'hsl\(\s*(\d+)\s*,\s*(\d+)%\s*,\s*(\d+)%\s*\)');
    Match? match = regExp.firstMatch(hsl);

    if (match == null) {
      return hsl;
    }

    int h = int.parse(match.group(1)!);
    double s = int.parse(match.group(2)!) / 100;
    double l = int.parse(match.group(3)!) / 100;

    double c = (1 - (2 * l - 1).abs()) * s;
    double x = c * (1 - ((h / 60) % 2 - 1).abs());
    double m = l - c / 2;

    double r = 0, g = 0, b = 0;

    if (h < 60) {
      r = c;
      g = x;
    } else if (h < 120) {
      r = x;
      g = c;
    } else if (h < 180) {
      g = c;
      b = x;
    } else if (h < 240) {
      g = x;
      b = c;
    } else if (h < 300) {
      r = x;
      b = c;
    } else {
      r = c;
      b = x;
    }

    int red = ((r + m) * 255).round();
    int green = ((g + m) * 255).round();
    int blue = ((b + m) * 255).round();

    return "#${red.toRadixString(16).padLeft(2, '0')}"
        "${green.toRadixString(16).padLeft(2, '0')}"
        "${blue.toRadixString(16).padLeft(2, '0')}";
  }

  Future<void> fetchTemplates() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? adminId = prefs.getString("adminId");
    String? token = prefs.getString("token");

    final response = await apiGet(
      Uri.parse("${Api_url}/api/templates/get/${widget.templetid}"),
      headers: {
        "authorization": "CRM $token",
        "id": "CRM ${prefs.getString('staff_id') ?? adminId}",
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data["statusCode"] == 200 && data.containsKey("template")) {
        setState(() {
          templates = [data["template"]]; // Store in list
          //events = [data["template"]["name"] as String]; // Extract name
          final loadedEvent = data["template"]["mail_type"]; // Select default
          _selectedEvent = events.contains(loadedEvent) ? loadedEvent : null;
          _selectedType = data["template"]["type"] == "Print"
              ? "Print"
              : "E-mail"; // Template type (E-mail/Print)
          name.text = data["template"]["name"] ?? ""; // Get HTML content

          htmlBody = data["template"]["body"] ?? ""; // Get HTML content
          subject.text = data["template"]["subject"] ?? ""; // Get HTML content
          // _htmlEditorController
          //     .setText(replaceDollarWithAt(replaceSpanTags(htmlBody))); // Set editor content

          //_htmlEditorController.setText(htmlBody);
        });

        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            _htmlEditorController.setFocus();
            _htmlEditorController
                .setText(replaceDollarWithAt(replaceSpanTags(htmlBody)));
          }
        });
      }
    } else {
    }
  }
  // void saveTemplate() async {
  //   setState(() {
  //     isLoading = true;
  //     nameError = null;
  //     subjectError = null;
  //     bodyError = null; // Start loading
  //   });
  //   SharedPreferences prefs = await SharedPreferences.getInstance();
  //   String? adminId = prefs.getString("adminId");
  //   String? token = prefs.getString("token");
  //
  //   String updatedHtmlBody =
  //       await _htmlEditorController.getText(); // Get updated HTML content
  //
  //   print("body of ${updatedHtmlBody}");
  //
  //   if (name.text.trim().isEmpty ||
  //       subject.text.trim().isEmpty ||
  //       updatedHtmlBody.trim().isEmpty) {
  //     setState(() {
  //       isLoading = false;
  //       nameError = name.text.trim().isEmpty ? "required" : null;
  //       subjectError = subject.text.trim().isEmpty ? "required" : null;
  //       bodyError = "required"; // Set the error message
  //     });
  //     return; // Stop execution
  //   }
  //   Map<String, dynamic> updatedTemplate = {
  //     "admin_id": adminId,
  //     "name": name.text,
  //     "subject": subject.text,
  //     "body": updatedHtmlBody,
  //     "type": "E-mail",
  //     "mail_type": _selectedEvent,
  //   };
  //
  //   final response = await apiPost(
  //     Uri.parse("${Api_url}/api/templates"),
  //     headers: {
  //       "Content-Type": "application/json",
  //       "authorization": "CRM $token",
  //       "id": "CRM ${prefs.getString('staff_id') ?? adminId}",
  //     },
  //     body: json.encode(updatedTemplate),
  //   );
  //   print(" templet post ${response.body}");
  //   setState(() {
  //     isLoading = false; // Stop loading
  //   });
  //   if (response.statusCode == 200) {
  //     Fluttertoast.showToast(
  //       msg: "Template posted successfully!",
  //     );
  //     Navigator.pop(context, true);
  //   } else {
  //     print("Failed to add template");
  //     Fluttertoast.showToast(msg: "Failed to post template");
  //   }
  // }

  Map<String, List<Map<String, String>>> tipsObject = {
    "Reset password": [
      {"Name": "Receiver Name"},
      {"Url": "Reset password link"},
      {"EmailAddress": "E-mail Address"},
      {"CompanyName": "Company Name"},
    ],
    "Invitation": [
      {"Name": "Receiver Name"},
      {"EmailAddress": "Email Address"},
      {"Password": "Password"},
      {"Url": "Login Link"},
      {"CompanyName": "Company Name"},
    ],
    "Property assign": [
      {"Name": "Receiver Name"},
      {"RentalOwner": "Rental Owner Name"},
      {"RentalAddress": "Rental Address"},
      {"Unit": "Unit Address"},
      {"EmailAddress": "E-mail Address"},
      {"CompanyName": "Company Name"},
    ],
    "Lease creation": [
      {"Name": "Receiver Name"},
      {"RentalOwner": "Rental Owner Name"},
      {"RentalAddress": "Rental Address"},
      {"Unit": "Unit Address"},
      {"StartDate": "Start Date"},
      {"EndDate": "End Date"},
      {"Rent": "Rent Amount"},
      {"EmailAddress": "E-mail Address"},
      {"CompanyName": "Company Name"},
    ],
    "Work Orders": [
      {"Name": "Receiver Name"},
      {"RentalOwner": "Rental Owner Name"},
      {"RentalAddress": "Rental Address"},
      {"Unit": "Unit Address"},
      {"Title": "Title"},
      {"Category": "Category"},
      {"Priority": "Priority"},
      {"Work_Perform": "Work to be performed"},
      {"Status": "Status"},
      {"DueDate": "Due Date"},
      {"Entry_Allowed": "Entry allowed"},
      {"EmailAddress": "E-mail Address"},
      {"CompanyName": "Company Name"},
    ],
    "Payment receipt": [
      {"Name": "Receiver Name"},
      {"RentalOwner": "Rental Owner Name"},
      {"RentalAddress": "Rental Address"},
      {"PaymentDate": "Payment Date"},
      {"CurrentDate": "Current Date"},
      {"AmountPaid": "Amount Paid"},
      {"AmountDue": "Due Amount"},
      {"TransactionId": "Transaction Id"},
      {"PaymentMethod": "Payment Method"},
      {"EmailAddress": "E-mail Address"},
      {"CompanyName": "Company Name"},
    ],
    "LateFee reminder": [
      {"Name": "Receiver Name"},
      {"Amount": "Rent amount"},
      {"LateFee": "Late Fee percentage"},
      {"Duration": "Late fee duration"},
      {"RentalAddress": "Rental Address"},
      {"DueDate": "Due date to pay Rent"},
      {"EmailAddress": "E-mail Address"},
      {"CompanyName": "Company Name"},
    ],
    "Lease end Reminder": [
      {"Name": "Receivers Name"},
      {"EndDate": "Lease End Date"},
      {"RentalAddress": "Rental Address"},
      {"EmailAddress": "E-mail Address"},
      {"CompanyName": "Company Name"},
    ],
    "Express Payment": [
      {"Name": "Receivers Name"},
      {"RentalOwner": "Rental Owner Name"},
      {"RentalAddress": "Rental Address"},
      {"Url": "Express Payment URL"},
      {"EmailAddress": "E-mail Address"},
      {"CompanyName": "Company Name"},
      {"Duration": "Link valid until days"},
    ],
    "Payment refund": [
      {"Name": "Receiver Name"},
      {"Amount": "Refund Amount"},
      {"TransactionId": "Transaction Id"},
      {"Date": "Refund Date"},
      {"EmailAddress": "E-mail Address"},
      {"CompanyName": "Company Name"},
    ],
    "Applicant application": [
      {"Name": "Receiver Name"},
      {"RentalAddress": "Rental Address"},
      {"Url": "Application link"},
      {"EmailAddress": "E-mail Address"},
      {"CompanyName": "Company Name"},
    ],
    "Applicant status": [
      {"Name": "Receiver Name"},
      {"RentalAddress": "Rental Address"},
      {"Status": "Applicant Status"},
      {"EmailAddress": "E-mail Address"},
      {"CompanyName": "Company Name"},
    ],
    "Payment failure": [
      {"Name": "Receiver Name"},
      {"RentalAddress": "Rental Address"},
      {"PaymentDate": "Payment Date"},
      {"AmountPaid": "Amount Paid"},
      {"PaymentFailureReason": "Payment Failure Reason"},
      {"PaymentMethod": "Payment Method"},
      {"EmailAddress": "E-mail Address"},
      {"CompanyName": "Company Name"},
    ],
    "Manual Tenant": [
      {"Name": "Receiver Name"},
      {"EmailAddress": "E-mail Address"},
      {"CompanyName": "Company Name"},
    ],
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      drawer: CustomDrawerStaff(
        currentpage: "Templates",
        dropdown: true,
      ),
      appBar: widget_302_Staff.App_Bar(context: context),
      body: Padding(
        padding: const EdgeInsets.only(left: 16, right: 16, top: 16),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(2.0),
            child: Form(
              key: _formkey,
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          // height: 50.0,
                          height: (MediaQuery.of(context).size.width < 500)
                              ? 50
                              : 60,
                          padding: EdgeInsets.only(
                              top: MediaQuery.of(context).size.width < 500
                                  ? 9
                                  : 5,
                              left: 10),
                          margin: const EdgeInsets.only(bottom: 6.0),
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
                          child: Text(
                            widget.templetid != null
                                ? "Edit Template"
                                : 'Add Template',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: Text('Template Type *',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: blueColor)),
                      ),
                    ],
                  ),
                  DropdownButtonHideUnderline(
                    child: DropdownButton2<String>(
                      style: const TextStyle(fontSize: 15, color: Colors.black),
                      isExpanded: true,
                      hint: const Text('Select Template Type'),
                      value: _selectedType,
                      items: ["E-mail", "Print"].map((method) {
                        return DropdownMenuItem<String>(
                          value: method,
                          child: Text(method),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedType = newValue ?? "E-mail";
                          if (_selectedType == "Print") {
                            eventError = false;
                            subjectError = false;
                          }
                        });
                      },
                      buttonStyleData: ButtonStyleData(
                        height: 46,
                        padding: const EdgeInsets.symmetric(horizontal: 3),
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
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Container(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(4.0),
                                child: Row(
                                  children: [
                                    Text('Name *',
                                        style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: blueColor)),
                                    const Spacer(),
                                    // Same as web: tip about ${date} in the name.
                                    TemplateNameDateTip(
                                        color: blueColor, size: 16),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(3.0),
                                child: Material(
                                  elevation: 2,
                                  borderRadius: BorderRadius.circular(8.0),
                                  child: Container(
                                    height: 47,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16.0, vertical: 0),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8.0),
                                      //border: Border.all(color: blueColor),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.2),
                                          offset: const Offset(4, 4),
                                          blurRadius: 3,
                                        ),
                                      ],
                                    ),
                                    child: Stack(
                                      children: [
                                        Positioned.fill(
                                          // Same as web: typing `$` in the name suggests
                                          // ${date} (Current Date).
                                          child: TemplateDateTypeAhead(
                                            controller: name,
                                            focusNode: _nameFocusNode!,
                                            child: TextField(
                                              focusNode: _nameFocusNode,
                                              onChanged: (value) {
                                                setState(() {
                                                  nameError = false;
                                                });
                                              },
                                              controller: name,
                                              cursorColor: blueColor,
                                              onTapOutside: (_) {
                                                _nameFocusNode?.unfocus();
                                                FocusScope.of(context)
                                                    .requestFocus(_bodyFocusNode);
                                                _htmlEditorController.setFocus();
                                              },
                                              decoration: const InputDecoration(
                                                hintStyle: TextStyle(
                                                    fontSize: 13,
                                                    color: Color(0xFFb0b6c3)),
                                                border: InputBorder.none,
                                                hintText: "Enter name",
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 3),
                              nameError
                                  ? Row(
                                      children: [
                                        const SizedBox(
                                          width: 2,
                                        ),
                                        Text(
                                          namemessage,
                                          style: TextStyle(
                                              color: Colors.red,
                                              fontSize: MediaQuery.of(context)
                                                      .size
                                                      .width *
                                                  .035),
                                        ),
                                        const SizedBox(
                                          width: 2,
                                        ),
                                      ],
                                    )
                                  : eventError
                                      ? Row(
                                          children: [
                                            const SizedBox(
                                              width: 3,
                                            ),
                                            Text(
                                              eventmessage,
                                              style: TextStyle(
                                                  color: Colors.transparent,
                                                  fontSize:
                                                      MediaQuery.of(context)
                                                              .size
                                                              .width *
                                                          .035),
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
                      ),
                      if (_selectedType == "E-mail")
                        const SizedBox(
                          width: 1,
                        ),
                      if (_selectedType == "E-mail")
                        Expanded(
                          flex: 3,
                          child: Container(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(4.0),
                                  child: Text(
                                    "Event Type *",
                                  style: TextStyle(
                                      color: blueColor,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                              DropdownButtonHideUnderline(
                                child: DropdownButton2<String>(
                                  style: const TextStyle(
                                      fontSize: 15, color: Colors.black),
                                  isExpanded: true,
                                  hint: const Text(
                                    'Select Event',
                                  ),
                                  value: _selectedEvent,
                                  items: events.map((method) {
                                    return DropdownMenuItem<String>(
                                      value: method,
                                      child: Text(method),
                                    );
                                  }).toList(),
                                  onChanged: (String? newValue) {
                                    setState(() {
                                      _selectedEvent = newValue;
                                      eventError = false;
                                      //  fetchTemplates();
                                    });

                                    // Notify FormField of value change
                                  },
                                  buttonStyleData: ButtonStyleData(
                                    height: 46,
                                    padding:
                                        const EdgeInsets.symmetric(horizontal: 3),
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
                                  // iconStyleData: const IconStyleData(
                                  //   icon: SizedBox.shrink(), // Hides the dropdown icon
                                  // ),
                                  dropdownStyleData: DropdownStyleData(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(6),
                                      color: Colors.white,
                                    ),
                                    scrollbarTheme: ScrollbarThemeData(
                                      radius: const Radius.circular(6),
                                      thickness: MaterialStateProperty.all(6),
                                      thumbVisibility:
                                          MaterialStateProperty.all(true),
                                    ),
                                  ),
                                  menuItemStyleData: const MenuItemStyleData(
                                    height: 50,
                                    padding:
                                        EdgeInsets.only(left: 14, right: 14),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 3),
                              eventError
                                  ? Row(
                                      children: [
                                        const SizedBox(
                                          width: 3,
                                        ),
                                        Text(
                                          eventmessage,
                                          style: TextStyle(
                                              color: Colors.red,
                                              fontSize: MediaQuery.of(context)
                                                      .size
                                                      .width *
                                                  .035),
                                        ),
                                        const SizedBox(
                                          width: 2,
                                        ),
                                      ],
                                    )
                                  : nameError
                                      ? Row(
                                          children: [
                                            const SizedBox(
                                              width: 3,
                                            ),
                                            Text(
                                              eventmessage,
                                              style: TextStyle(
                                                  color: Colors.transparent,
                                                  fontSize:
                                                      MediaQuery.of(context)
                                                              .size
                                                              .width *
                                                          .035),
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
                      ),
                    ],
                  ),
                  if (_selectedType == "E-mail") ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const SizedBox(
                        width: 2,
                      ),
                      Text('Subject *',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: blueColor)),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      const SizedBox(width: 2),
                      Expanded(
                        child: Material(
                          elevation: 2,
                          borderRadius: BorderRadius.circular(8.0),
                          child: Container(
                            height: 47,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16.0, vertical: 0),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8.0),
                              //border: Border.all(color: blueColor),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  offset: const Offset(4, 4),
                                  blurRadius: 3,
                                ),
                              ],
                            ),
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: TextField(
                                    focusNode: _subjectFocusNode,
                                    onChanged: (value) {
                                      setState(() {
                                        subjectError = false;
                                      });
                                    },
                                    controller: subject,
                                    cursorColor: blueColor,
                                    onTapOutside: (_) {
                                      _subjectFocusNode?.unfocus();
                                      FocusScope.of(context)
                                          .requestFocus(_bodyFocusNode);
                                      _htmlEditorController
                                          .setFocus(); // Move focus to the editor
                                    },
                                    decoration: const InputDecoration(
                                      hintStyle: TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFFb0b6c3)),
                                      border: InputBorder.none,
                                      hintText: "Enter subject",
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 2),
                    ],
                  ),
                  const SizedBox(height: 5),
                  subjectError
                      ? Row(
                          children: [
                            const SizedBox(
                              width: 2,
                            ),
                            Text(
                              submessage,
                              style: TextStyle(
                                  color: Colors.red,
                                  fontSize:
                                      MediaQuery.of(context).size.width * .035),
                            ),
                            const SizedBox(
                              width: 2,
                            ),
                          ],
                        )
                      : Container(),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const SizedBox(
                        width: 2,
                      ),
                      Text(
                        "Body",
                        style: TextStyle(
                            color: blueColor, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      SuperTooltip(
                        controller: _controller,
                        popupDirection: TooltipDirection.down,
                        backgroundColor: const Color(0xff2f2d2f),
                        arrowTipDistance: 20.0,
                        touchThroughAreaShape: ClipAreaShape.rectangle,
                        touchThroughAreaCornerRadius: 30,
                        barrierColor: const Color.fromARGB(26, 47, 45, 47),
                        content: Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: Text(
                            tipsObject[_selectedEvent] != null &&
                                    tipsObject[_selectedEvent]!.isNotEmpty
                                ? 'You can personalize transaction templates using the following dynamic variables :\n' +
                                    tipsObject[_selectedEvent]!
                                        .map((e) => e.entries.first)
                                        .map((entry) =>
                                            "@${entry.key}: ${entry.value}")
                                        .join("\n")
                                : 'You can personalize transaction templates using the following dynamic variables :',
                            softWrap: true,
                            style: const TextStyle(color: Colors.white, fontSize: 15),
                          ),
                        ),
                        child: Icon(
                          Icons.error,
                          color: blueColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(
                    height: 4,
                  ),
                  SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(2.0),
                      child: Column(
                        children: [
                          Focus(
                            focusNode: _bodyFocusNode,
                            child: HtmlEditor(
                              controller: _htmlEditorController,
                              htmlEditorOptions: const HtmlEditorOptions(
                                adjustHeightForKeyboard: false,

                                //  shouldEnsureVisible: true,
                              ),
                              otherOptions: OtherOptions(
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.black),
                                  borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(4),
                                      topRight: Radius.circular(4)),
                                ),
                              ),
                              htmlToolbarOptions: HtmlToolbarOptions(
                                // toolbarType: ToolbarType.nativeExpandable,
                                customToolbarButtons: [
                                  Row(
                                    children: [
                                      PopupMenuButton<String>(
                                        padding: const EdgeInsets.all(0),
                                        icon: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.format_list_bulleted,
                                                color: Colors.black),
                                            // SizedBox(width: 4),
                                            Icon(Icons.arrow_drop_down,
                                                color: Colors
                                                    .black), // Dropdown Arrow
                                          ],
                                        ),
                                        tooltip: "Unordered List",
                                        offset: const Offset(
                                            0, 40), // Adjusts dropdown position
                                        shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                                10)), // Rounded corners
                                        onSelected: (String style) {
                                          _htmlEditorController.execCommand(
                                              "insertHTML",
                                              argument:
                                                  '<ul style="list-style-type: $style;"><li>List Item</li></ul>');
                                        },
                                        itemBuilder: (context) => [
                                          const PopupMenuItem(
                                            value: "disc",
                                            child: Row(
                                              children: [
                                                Icon(Icons.circle,
                                                    size: 16,
                                                    color: Colors.black),
                                                SizedBox(width: 10),
                                                Text("Disc"),
                                              ],
                                            ),
                                          ),
                                          const PopupMenuItem(
                                            value: "circle",
                                            child: Row(
                                              children: [
                                                Icon(Icons.circle_outlined,
                                                    size: 16,
                                                    color: Colors.black),
                                                SizedBox(width: 10),
                                                Text("Circle"),
                                              ],
                                            ),
                                          ),
                                          const PopupMenuItem(
                                            value: "square",
                                            child: Row(
                                              children: [
                                                Icon(Icons.square,
                                                    size: 16,
                                                    color: Colors.black),
                                                SizedBox(width: 10),
                                                Text("Square"),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(
                                        width: 5,
                                      ),
                                      PopupMenuButton<String>(
                                        constraints: const BoxConstraints(
                                          minWidth:
                                              100, // Minimum width of the popup
                                          maxWidth: 200, // Maximum width
                                        ),
                                        padding: const EdgeInsets.all(0),
                                        icon: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.format_list_numbered,
                                                color: Colors.black),
                                            // SizedBox(width: 4),
                                            Icon(Icons.arrow_drop_down,
                                                color: Colors
                                                    .black), // Dropdown Arrow
                                          ],
                                        ), // Ordered List Button
                                        tooltip: "Ordered List",
                                        offset: const Offset(0, 40),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10)),
                                        onSelected: (String style) {
                                          _htmlEditorController.execCommand(
                                              "insertHTML",
                                              argument:
                                                  '<ol style="list-style-type: $style;"><li>List Item</li></ol>');
                                        },
                                        itemBuilder: (context) => [
                                          PopupMenuItem(
                                            enabled:
                                                false, // Disable selection on this item
                                            child: Container(
                                              width:
                                                  200, // Adjust width as needed
                                              child: GridView.count(
                                                shrinkWrap: true,
                                                crossAxisCount:
                                                    3, // 3 items in a row
                                                mainAxisSpacing: 5,
                                                crossAxisSpacing: 5,
                                                //childAspectRatio: .3,
                                                // Adjust for better layout
                                                children: [
                                                  _buildListItem(
                                                      "decimal", "1"),
                                                  _buildListItem(
                                                      "decimal-leading-zero",
                                                      "01"),
                                                  _buildListItem(
                                                      "lower-roman", "i"),
                                                  _buildListItem(
                                                      "upper-roman", "I"),
                                                  _buildListItem(
                                                      "lower-alpha", "a"),
                                                  _buildListItem(
                                                      "upper-alpha", "A"),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),

                                  // OL (Ordered List) Style Dropdown

                                  PopupMenuButton<String>(
                                    child: const Padding(
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text("Paragraph",
                                              style: TextStyle(
                                                fontSize: 16,
                                              )),
                                          Icon(Icons
                                              .arrow_drop_down), // Dropdown indicator
                                        ],
                                      ),
                                    ),
                                    tooltip: "Paragraph",
                                    onSelected: (String format) {
                                      _htmlEditorController.execCommand(
                                          "formatBlock",
                                          argument: format);
                                    },
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(
                                        value: "h1",
                                        child: Text("Heading 1",
                                            style: TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.bold)),
                                      ),
                                      const PopupMenuItem(
                                        value: "h2",
                                        child: Text("Heading 2",
                                            style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold)),
                                      ),
                                      const PopupMenuItem(
                                        value: "h3",
                                        child: Text("Heading 3",
                                            style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold)),
                                      ),
                                      const PopupMenuItem(
                                        value: "p",
                                        child: Text("Paragraph",
                                            style: TextStyle(fontSize: 14)),
                                      ),
                                    ],
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.format_quote),
                                    tooltip: "Insert Quote",
                                    onPressed: () {
                                      _htmlEditorController.execCommand(
                                          "formatBlock",
                                          argument: "blockquote");
                                    },
                                  ),
                                  PopupMenuButton<String>(
                                    icon: const Icon(Icons.text_fields),
                                    tooltip: "Font Size",
                                    onSelected: (String text) {
                                      _htmlEditorController.execCommand(
                                          "fontSize",
                                          argument: text);
                                    },
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(
                                          value: "1", child: Text("tiny")),
                                      const PopupMenuItem(
                                          value: "2", child: Text("small")),
                                      const PopupMenuItem(
                                          value: "3", child: Text("default")),
                                      const PopupMenuItem(
                                          value: "5", child: Text("big")),
                                      const PopupMenuItem(
                                          value: "7", child: Text("huge")),
                                    ],
                                  ),
                                ],
                                defaultToolbarButtons: [
                                  const OtherButtons(
                                      fullscreen: false,
                                      help: false,
                                      codeview: false,
                                      undo: true,
                                      redo: true,
                                      copy: false,
                                      paste: false),
                                  const FontButtons(
                                    bold: true,
                                    italic: true,
                                    underline: false,
                                    strikethrough: false,
                                    subscript: false,
                                    superscript: false,
                                    clearAll: false,
                                  ),
                                  const InsertButtons(
                                    picture: false,
                                    video: false,
                                    audio: false,
                                    table: true,
                                    hr: false,
                                  ),
                                  const ListButtons(
                                    ul: false,
                                    ol: false,
                                    listStyles: false,
                                  ),
                                  const ParagraphButtons(
                                    textDirection: false,
                                    lineHeight: false,
                                    caseConverter: false,
                                    decreaseIndent: false,
                                    increaseIndent: false,
                                  ),
                                  const ColorButtons(),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  bodyError
                      ? Row(
                          children: [
                            const SizedBox(
                              width: 2,
                            ),
                            Text(
                              bodymessage,
                              style: TextStyle(
                                  color: Colors.red,
                                  fontSize:
                                      MediaQuery.of(context).size.width * .035),
                            ),
                            const SizedBox(
                              width: 2,
                            ),
                          ],
                        )
                      : Container(),
                  const SizedBox(
                    height: 8,
                  ),
                  Row(
                    children: [
                      ElevatedButton(
                        onPressed: () async {
                          // Validate name
                          if (name.text.trim().isEmpty) {
                            setState(() {
                              nameError = true;
                              namemessage = "required";
                            });
                          } else {
                            setState(() {
                              nameError = false;
                            });
                          }

                          // Validate designation
                          if (_selectedType == "E-mail") {
                            if (subject.text.trim().isEmpty) {
                              setState(() {
                                subjectError = true;
                                submessage = "required";
                              });
                            } else {
                              setState(() {
                                subjectError = false;
                              });
                            }
                            if (_selectedEvent == null) {
                              setState(() {
                                eventError = true;
                                eventmessage = "required";
                              });
                            } else {
                              setState(() {
                                eventError = false;
                              });
                            }
                          } else {
                            setState(() {
                              subjectError = false;
                              eventError = false;
                            });
                          }
                          String updatedHtmlBody =
                              await _htmlEditorController.getText();

                          if (updatedHtmlBody.trim().isEmpty) {
                            setState(() {
                              bodyError = true;
                              bodymessage = "required";
                            });
                          } else {
                            setState(() {
                              bodyError = false;
                            });
                          }

                          // Now, only proceed if all fields are filled and valid
                          if (!nameError &&
                              !subjectError &&
                              !eventError &&
                              !bodyError) {
                            // Fixed the extra check
                            setState(() {
                              isLoading = true;
                            });

                            SharedPreferences prefs =
                                await SharedPreferences.getInstance();
                            String? adminId = prefs.getString("adminId");

                            if (adminId != null) {
                              try {
                                if (widget.templetid != null) {
                                  // Editing existing template
                                  await TempletRepository().Edit_Templet(
                                    template_id: widget.templetid,
                                    adminId: adminId,
                                    name: name.text.trim(),
                                    subject: subject.text.trim(),
                                    body: replaceFontTags(updatedHtmlBody),
                                    type: _selectedType,
                                    mail_type:
                                        _selectedType == "E-mail" ? _selectedEvent : "",
                                  );
                                } else {
                                  // Adding new template
                                  await TempletRepository().addTemplet(
                                    adminId: adminId,
                                    name: name.text.trim(),
                                    subject: subject.text.trim(),
                                    body: replaceFontTags(updatedHtmlBody),
                                    type: _selectedType,
                                    mail_type:
                                        _selectedType == "E-mail" ? _selectedEvent : "",
                                  );
                                }
                                setState(() {
                                  isLoading = false;
                                });
                                Navigator.of(context).pop(true);
                              } catch (e) {
                                setState(() {
                                  isLoading = false;
                                });
                                // Handle error here
                              }
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 32, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          backgroundColor: blueColor,
                        ),
                        child: isLoading
                            ? const SpinKitFadingCircle(
                                color: Colors.white,
                                size: 25.0,
                              )
                            : const Text(
                                "Save",
                                style: TextStyle(
                                    fontSize: 16, color: Colors.white),
                              ),
                      ),
                      const SizedBox(
                        width: 10,
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 32, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          backgroundColor: Colors.white,
                        ),
                        child: Text(
                          "Cancel",
                          style: TextStyle(fontSize: 16, color: blueColor),
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
    );
  }

  String replaceDollarWithAt(String input) {
    return input.replaceAllMapped(
      RegExp(r'\$\{(\w+)\}'), // Match ${VariableName}
      (match) => '@${match.group(1)}', // Replace with @VariableName
    );
  }

  String replaceAtWithDollar(String input) {
    return input.replaceAllMapped(
      RegExp(r'@(\w+)'), // Match @ followed by a word
      (match) => '\${${match.group(1)}}', // Replace with ${Variable}
    );
  }

  String replaceFontTags(String html) {
    final Map<String, String> fontSizeMap = {
      '1': 'text-tiny',
      '2': 'text-small',
      '3': 'text-default',
      '4': 'text-medium', // Added missing size 4
      '5': 'text-big',
      '6': 'text-larger', // Added missing size 6
      '7': 'text-huge',
    };

    return replaceAtWithDollar(html.replaceAllMapped(
      RegExp(
        r'<font\s+([^>]*)>(.*?)<\/font>',
        caseSensitive: false,
      ),
      (match) {
        String attributes =
            match.group(1) ?? ''; // Get all attributes inside <font>
        String text = match.group(2) ?? ''; // Get the inner text

        // Extract size attribute
        RegExpMatch? sizeMatch = RegExp(r'size="(\d+)"').firstMatch(attributes);
        String? size = sizeMatch?.group(1);

        // Extract color attribute
        RegExpMatch? colorMatch =
            RegExp(r'color="([^"]+)"').firstMatch(attributes);
        String? color = colorMatch?.group(1);

        // Get the corresponding class name for size
        String? className = fontSizeMap[size];

        // Build the <span> tag
        String spanClass = className != null ? 'class="$className"' : '';
        String spanStyle = color != null ? 'style="color: $color;"' : '';

        return '<span $spanClass $spanStyle>$text</span>';
      },
    ));
  }

  Widget _buildListItem(String value, String text) {
    return GestureDetector(
      onTap: () {
        // Execute the command when an item is clicked
        _htmlEditorController.execCommand("insertHTML",
            argument:
                '<ol style="list-style-type: $value;"><li>List Item</li></ol>');
      },
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black),
          borderRadius: BorderRadius.circular(5),
        ),
        child: SvgPicture.asset(
          "assets/images/${text == "1" ? "1" : text == "01" ? "01" : text == "i" ? "OL-i" : text == "I" ? "OL-II" : text == "a" ? "OL-aa" : "OL-AAA"}.svg",
          height: 80,
          width: 80,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}

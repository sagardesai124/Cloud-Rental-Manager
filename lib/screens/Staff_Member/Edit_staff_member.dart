import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:keyboard_actions/keyboard_actions.dart';
import 'package:keyboard_actions/keyboard_actions_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:three_zero_two_property/widgets/appbar.dart';
import '../../constant/constant.dart';
import '../../model/staffmember.dart';
import '../../repository/Staffmember.dart';
import '../../widgets/drawer_tiles.dart';
import '../../widgets/custom_drawer.dart';
import 'package:http/http.dart' as http;
import 'package:three_zero_two_property/services/api_helpers.dart';

class Edit_staff_member extends StatefulWidget {
  Staffmembers? staff;
  Edit_staff_member({super.key, this.staff});

  @override
  State<Edit_staff_member> createState() => _Edit_staff_memberState();
}

class _Edit_staff_memberState extends State<Edit_staff_member> {
  TextEditingController name = TextEditingController();
  TextEditingController designation = TextEditingController();
  TextEditingController phonenumber = TextEditingController();
  TextEditingController email = TextEditingController();
  TextEditingController password = TextEditingController();
  TextEditingController conpassword = TextEditingController();

  bool nameerror = false;
  bool designationerror = false;
  bool phonenumbererror = false;
  bool emailerror = false;
  bool passworderror = false;
  bool conpassworderror = false;

  String namemessage = "";
  String designationmessage = "";
  String phonenumbermessage = "";
  String emailmessage = "";
  String passwordmessage = "";
  String conpasswordmessage = "";

  String? initialname;
  String? initialdesignation;
  String? initialphonenumber;
  String? initialemail;
  String? initialpass;
  String? initialconpass;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    name.text = widget.staff!.staffmemberName!;
    designation.text = widget.staff!.staffmemberDesignation!;
    phonenumber.text = formatPhoneNumberedit(widget.staff!.staffmemberPhoneNumber!.toString());
    email.text = widget.staff!.staffmemberEmail.toString();
   // password.text = widget.staff!.staffmemberPassword.toString();
  //  conpassword.text = widget.staff!.staffmemberPassword.toString();

    initialname = widget.staff!.staffmemberName!;
    initialdesignation = widget.staff!.staffmemberDesignation!;
    initialphonenumber = widget.staff!.staffmemberPhoneNumber!.toString();
    initialemail = widget.staff!.staffmemberEmail.toString();


    fetchStaff();
  }

  bool isLoading = false;
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

  Future<void> fetchStaff() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString("adminId");
    String? token = prefs.getString('token');
    final response = await apiGet(Uri.parse('$Api_url/api/staffmember/staff/member/${widget.staff?.staffmemberId}'),
      headers: {"authorization" : "CRM $token","id":"CRM ${prefs.getString('staff_id') ?? id}",},
    );
    if (response.statusCode == 200) {
      // Parse the response body
      final Map<String, dynamic> data = jsonDecode(response.body);

     setState(() {
       // Extract the password
       password.text = data['data']['staffmember_password'] ?? "";
       conpassword.text = data['data']['staffmember_password'] ?? "";

       initialpass =  data['data']['staffmember_password'] ?? "";
       initialconpass =  data['data']['staffmember_password'] ?? "";
     });


    } else {
      throw Exception('Failed to load tenant override fee data');
    }
  }
  bool obsecure = true;
  bool conobsecure = true;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget_302.App_Bar(context: context),
      backgroundColor: Colors.white,
      drawer: CustomDrawer(
        currentpage: "Staff",
        dropdown: false,
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
                padding: EdgeInsets.only(top: 9, left: 10),
                width: MediaQuery.of(context).size.width * .99,
                margin: EdgeInsets.only(bottom: 6.0),
                //Same as `blurRadius` i guess
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8.0),
                  color: blueColor,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey,
                      offset: Offset(0.0, 1.0), //(x,y)
                      blurRadius: 6.0,
                    ),
                  ],
                ),
                child: Text(
                  " Edit Staff Member",
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize:
                          MediaQuery.of(context).size.width < 500 ? 18 : 20),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 15, right: 15),
            child: Material(
              // elevation: 6,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Color(0xFFDBE0E5),
                  ),
                ),
                child: Padding(
                  padding:
                  EdgeInsets.only(left: 10, right: 10, top: 20, bottom: 30),
                  child: Column(
                    children: [
                      //staff name and designation
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Staff Member Name *",
                                style: TextStyle(
                                  color: Color(0xFF101828),
                                  fontWeight: FontWeight.bold,
                                  fontSize:
                                  MediaQuery.of(context).size.width < 500
                                      ? 14
                                      : 20,
                                ),
                              ),
                              SizedBox(height: 2),
                              Material(
                                //elevation: 4,
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  height: 50,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: Color(0xFFCED4DA),
                                    ),
                                  ),
                                  child: TextField(
                                    onChanged: (value) {
                                      setState(() => nameerror = false);
                                    },
                                    controller: name,
                                    cursorColor: blueColor,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.allow(RegExp(
                                          r"[a-zA-Z\s]")), // only letters + spaces
                                    ],
                                    decoration: InputDecoration(
                                      hintText: "Enter staff member name",
                                      hintStyle: TextStyle(
                                        fontSize:
                                        MediaQuery.of(context).size.width <
                                            500
                                            ? 13
                                            : 18,
                                        color: Color(0xFFA1A8B0),
                                      ),
                                      border: InputBorder.none,
                                      contentPadding: EdgeInsets.all(12),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 2),
                          Row(
                            children: [
                              nameerror
                                  ? Padding(
                                padding: const EdgeInsets.only(top: 4,left: 3),
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
                                  : SizedBox.shrink(),

                            ],
                          ),
                          SizedBox(height: 8),

                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(left: 4),
                                      child: Text(
                                        "Title *",
                                        style: TextStyle(
                                          color: Color(0xFF101828),
                                          fontWeight: FontWeight.bold,
                                          fontSize: MediaQuery.of(context)
                                              .size
                                              .width <
                                              500
                                              ? 14
                                              : 18,
                                        ),
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Material(
                                      // elevation: 4,
                                      borderRadius: BorderRadius.circular(10),
                                      child: Container(
                                        height: 50,
                                        decoration: BoxDecoration(
                                          borderRadius:
                                          BorderRadius.circular(10),
                                          border: Border.all(
                                            color: Color(0xFFCED4DA),
                                          ),
                                        ),
                                        child: TextField(
                                          onChanged: (value) {
                                            setState(
                                                    () => designationerror = false);
                                          },
                                          controller: designation,
                                          cursorColor: blueColor,
                                          decoration: InputDecoration(
                                            hintText: "Enter title",
                                            hintStyle: TextStyle(
                                              fontSize: MediaQuery.of(context)
                                                  .size
                                                  .width <
                                                  500
                                                  ? 13
                                                  : 18,
                                              color: Color(0xFFA1A8B0),
                                            ),
                                            border: InputBorder.none,
                                            contentPadding: EdgeInsets.all(12),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          // SizedBox(height: 6),
                          Row(
                            children: [
                              designationerror
                                  ? Padding(
                                padding: const EdgeInsets.only(top: 4,left: 3),
                                child: Container(
                                  alignment: Alignment
                                      .centerLeft, // Ensure left alignment
                                  child: Text(
                                    designationmessage,
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
                                  : SizedBox.shrink(),
                            ],
                          ),
                        ],
                      ),
                      SizedBox(
                        height: 12,
                      ),
                      //phone and email
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Phone Number *",
                            style: TextStyle(
                              color: Color(0xFF101828),
                              fontWeight: FontWeight.bold,
                              fontSize: MediaQuery.of(context).size.width < 500
                                  ? 13
                                  : 20,
                            ),
                          ),
                          Material(
                            //elevation: 4,
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              height: 50,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: Color(0xFFCED4DA),
                                ),
                              ),
                              child: TextField(
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(10),
                                  PhoneNumberFormatter(),
                                ],
                                focusNode: _nodeText1,
                                onChanged: (value) {
                                  setState(() => phonenumbererror = false);
                                },
                                controller: phonenumber,
                                keyboardType: TextInputType.number,
                                cursorColor: blueColor,
                                decoration: InputDecoration(
                                  hintText: "Enter phone number",
                                  hintStyle: TextStyle(
                                    fontSize:
                                    MediaQuery.of(context).size.width < 500
                                        ? 13
                                        : 18,
                                    color: Color(0xFFA1A8B0),
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.all(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 2),
                      Row(
                        children: [
                          phonenumbererror
                              ? Padding(
                            padding: const EdgeInsets.only(top: 4,left: 3),
                            child: Container(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                phonenumbermessage,
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
                              : SizedBox
                              .shrink(),

                        ],
                      ),
                      SizedBox(height: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Email *",
                                      style: TextStyle(
                                        color: Color(0xFF101828),
                                        fontWeight: FontWeight.bold,
                                        fontSize:
                                        MediaQuery.of(context).size.width <
                                            500
                                            ? 13
                                            : 20,
                                      ),
                                    ),
                                    Material(
                                      //  elevation: 4,
                                      borderRadius: BorderRadius.circular(10),
                                      child: Container(
                                        height: 50,
                                        decoration: BoxDecoration(
                                          borderRadius:
                                          BorderRadius.circular(10),
                                          border: Border.all(
                                            color: Color(0xFFCED4DA),
                                          ),
                                        ),
                                        child: TextField(
                                          onChanged: (value) {
                                            setState(() => emailerror = false);
                                          },
                                          controller: email,
                                          keyboardType:
                                          TextInputType.emailAddress,
                                          cursorColor: blueColor,
                                          decoration: InputDecoration(
                                            hintText: "Enter email",
                                            hintStyle: TextStyle(
                                              fontSize: MediaQuery.of(context)
                                                  .size
                                                  .width <
                                                  500
                                                  ? 13
                                                  : 18,
                                              color: Color(0xFFA1A8B0),
                                            ),
                                            border: InputBorder.none,
                                            contentPadding: EdgeInsets.all(12),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              emailerror
                                  ? Padding(
                                padding: const EdgeInsets.only(top: 4,left: 3),
                                child: Container(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    emailmessage,
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
                                  : SizedBox
                                  .shrink(),
                            ],
                          ),
                        ],
                      ),
                      SizedBox(
                        height: 8,
                      ),
                      //password and confirm pass
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Password *",
                            style: TextStyle(
                              color: Color(0xFF101828),
                              fontWeight: FontWeight.bold,
                              fontSize: MediaQuery.of(context).size.width < 500
                                  ? 13
                                  : 18,
                            ),
                          ),
                          SizedBox(height: 2),
                          Material(
                            //  elevation: 4,
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              height: 50,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Color(0xFFCED4DA)),
                              ),
                              child: TextField(
                                onChanged: (value) {
                                  setState(() => passworderror = false);
                                },
                                controller: password,
                                cursorColor: blueColor,
                                obscureText: obsecure,
                                decoration: InputDecoration(
                                  hintText: "Enter password",
                                  hintStyle: TextStyle(
                                    fontSize:
                                    MediaQuery.of(context).size.width < 500
                                        ? 13
                                        : 18,
                                    color: Color(0xFFA1A8B0),
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.all(12),
                                  suffixIcon: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        obsecure = !obsecure;
                                      });
                                    },
                                    child: Icon(
                                      obsecure
                                          ? Icons.visibility
                                          : Icons.visibility_off,
                                      color: Color(0xFF444444),
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 2),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          passworderror
                              ? Padding(
                            padding: const EdgeInsets.only(top: 4,left: 3),
                            child: Container(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                passwordmessage,
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
                              : SizedBox
                              .shrink(),
                        ],
                      ),
                      SizedBox(height: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Confirm Password *",
                                      style: TextStyle(
                                        color: Color(0xFF101828),
                                        fontWeight: FontWeight.bold,
                                        fontSize:
                                        MediaQuery.of(context).size.width <
                                            500
                                            ? 13
                                            : 18,
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Material(
                                      // elevation: 4,
                                      borderRadius: BorderRadius.circular(10),
                                      child: Container(
                                        height: 50,
                                        decoration: BoxDecoration(
                                          borderRadius:
                                          BorderRadius.circular(10),
                                          border: Border.all(
                                            color: Color(0xFFCED4DA),
                                          ),
                                        ),
                                        child: TextField(
                                          onChanged: (value) {
                                            setState(
                                                    () => conpassworderror = false);
                                          },
                                          controller: conpassword,
                                          obscureText: conobsecure,
                                          cursorColor: blueColor,
                                          decoration: InputDecoration(
                                            hintText: "Enter password",
                                            hintStyle: TextStyle(
                                              fontSize: MediaQuery.of(context)
                                                  .size
                                                  .width <
                                                  500
                                                  ? 13
                                                  : 18,
                                              color: Color(0xFFA1A8B0),
                                            ),
                                            border: InputBorder.none,
                                            contentPadding: EdgeInsets.all(12),
                                            suffixIcon: GestureDetector(
                                              onTap: () {
                                                setState(() {
                                                  conobsecure = !conobsecure;
                                                });
                                              },
                                              child: Icon(
                                                conobsecure
                                                    ? Icons.visibility
                                                    : Icons.visibility_off,
                                                color: Color(0xFF444444),
                                                size: 20,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              conpassworderror
                                  ? Padding(
                                padding: const EdgeInsets.only(top: 4,left: 3),
                                child: Container(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    conpasswordmessage,
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
                                  : SizedBox
                                  .shrink(),
                            ],
                          ),
                        ],
                      ),
                      SizedBox(
                        height: 60,
                      ),
                      Row(
                        children: [
                          if (MediaQuery.of(context).size.width < 500)
                            SizedBox(
                                width:
                                MediaQuery.of(context).size.width * 0.01),
                          if (MediaQuery.of(context).size.width > 500)
                            SizedBox(
                                width:
                                MediaQuery.of(context).size.width * 0.004),
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
                                      border: Border.all(color: Color(0x80152B51))
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
                                          fontSize:
                                          MediaQuery.of(context).size.width < 500
                                              ? 15
                                              : 18),
                                    ),
                                  ),
                                )),
                          ),
                          SizedBox(
                            width: 15,
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () async {
                                // Check if the user has made any changes
                                bool hasChanges = name.text != initialname ||
                                    designation.text != initialdesignation ||
                                    // The field shows the phone formatted but the saved value may be
                                    // plain digits, so compare digits only.
                                    phonenumber.text.replaceAll(RegExp(r'\D'), '') !=
                                        (initialphonenumber ?? '').replaceAll(RegExp(r'\D'), '') ||
                                    email.text != initialemail ||
                                    password.text != initialpass ||
                                    conpassword.text != initialconpass;

                                // Validate Name Field
                                if (name.text.trim().isEmpty) {
                                  setState(() {
                                    nameerror = true;
                                    namemessage = "Please enter Staff Member Name";
                                  });
                                } else {
                                  setState(() {
                                    nameerror = false;
                                  });
                                }

                                // Validate Designation Field
                                if (designation.text.trim().isEmpty) {
                                  setState(() {
                                    designationerror = true;
                                    designationmessage =
                                    "Please enter Title";
                                  });
                                } else {
                                  setState(() {
                                    designationerror = false;
                                  });
                                }
                                String formattedPhoneNumber = phonenumber.text.replaceAll(RegExp(r'\D'), '');
                                // Validate Phone Number Field
                                if (formattedPhoneNumber.isEmpty) {
                                  setState(() {
                                    phonenumbererror = true;
                                    phonenumbermessage =
                                    "Please enter Phone Number";
                                  });
                                }else if (formattedPhoneNumber.length != 10) {
                                  setState(() {
                                    phonenumbererror = true;
                                    phonenumbermessage = "Phone number must be 10 digits";
                                  });
                                } else {
                                  setState(() {
                                    phonenumbererror = false;
                                  });
                                }

                                // Validate Email Field
                                if (email.text.trim().isEmpty) {
                                  setState(() {
                                    emailerror = true;
                                    emailmessage = "Please enter Email Address";
                                  });
                                } else {
                                  setState(() {
                                    emailerror = false;
                                  });
                                }

                                if (password.text.trim().isEmpty) {
                                  setState(() {
                                    passworderror = true;
                                    passwordmessage = "Please enter Password";
                                  });
                                } else if (password.text.length < 8) {
                                  setState(() {
                                    passworderror = true;
                                    passwordmessage =
                                    "Password must have 8 Characters";
                                  });
                                }

                                else {
                                  String? validationMessage =
                                  ValidatePassword(password.text);

                                  if (validationMessage != null) {
                                    setState(() {
                                      passworderror = true;
                                      passwordmessage =
                                          validationMessage; // Use the dynamic message
                                    });
                                  } else {
                                    setState(() {
                                      passworderror = false; // No error
                                    });
                                  }
                                }

                                if (conpassword.text.trim().isEmpty) {
                                  setState(() {
                                    conpassworderror = true;
                                    conpasswordmessage = "Must be same as password";
                                  });
                                } else if (conpassword.text != password.text) {
                                  setState(() {
                                    conpassworderror = true;
                                    conpasswordmessage = "Passwords do not match";
                                  });
                                } else {
                                  setState(() {
                                    conpassworderror = false;
                                  });
                                }
                                // If any validation fails, return early and do not proceed with API call or navigation
                                if (nameerror ||
                                    designationerror ||
                                    phonenumbererror ||
                                    emailerror ||
                                    passworderror ||
                                    conpassworderror

                                ) {
                                  return; // This prevents the navigation and edit if any field is invalid
                                }

                                // If no changes were made, you can choose to navigate back without making an API call
                                if (!hasChanges) {

                                  Navigator.of(context)
                                      .pop(false); // Optionally navigate back
                                  return;
                                }


                                setState(() {
                                  isLoading = true;
                                });


                                SharedPreferences prefs =
                                await SharedPreferences.getInstance();
                                String? adminId = prefs.getString("adminId");

                                if (adminId != null) {
                                  try {
                                    // API call to edit staff member
                                    await StaffMemberRepository()
                                        .Edit_staff_member(
                                      adminId: adminId,
                                      staffmemberName: name.text.trim(),
                                      staffmemberDesignation: designation.text.trim(),
                                      staffmemberPhoneNumber: phonenumber.text.trim(),
                                      staffmemberEmail: email.text.trim(),
                                      Sid: widget.staff!.staffmemberId,
                                      staffmemberPassword: password.text.trim(),
                                    );

                                    // Update the staff details after successful edit
                                    setState(() {
                                      widget.staff?.staffmemberName = name.text;
                                      widget.staff?.staffmemberDesignation =
                                          designation.text;
                                      widget.staff?.staffmemberPhoneNumber =
                                          phonenumber.text;
                                      widget.staff?.staffmemberEmail = email.text;
                                      widget.staff?.staffmemberId =
                                          widget.staff!.staffmemberId;
                                      widget.staff?.adminId = adminId;
                                      widget.staff?.staffmemberPassword = password.text;
                                      isLoading = false;
                                    });

                                    // Navigate back with success response
                                    Navigator.of(context).pop(true);
                                  } catch (e) {
                                    // Handle error and stop the loading spinner
                                    setState(() {
                                      isLoading = false;
                                    });
                                    // You can add further error handling here

                                  }
                                }
                              },
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(5.0),
                                child: Container(
                                  height:40,
                                  // width: MediaQuery.of(context).size.width < 500
                                  //     ? 160
                                  //     : 180,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(5.0),
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
                                    child: isLoading
                                        ? SpinKitFadingCircle(
                                      color: Colors.white,
                                      size: 25.0,
                                    )
                                        : Text(
                                      "Edit Staff Member",
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: MediaQuery.of(context)
                                              .size
                                              .width <
                                              500
                                              ? 15
                                              : 18),
                                    ),
                                  ),
                                ),
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
          SizedBox(
            height: 10,
          ),
        ],
      ),
    );
  }
}

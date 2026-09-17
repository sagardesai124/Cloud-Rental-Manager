import 'package:three_zero_two_property/services/app_log.dart';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:flutter_svg/svg.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:three_zero_two_property/services/api_helpers.dart';
import 'package:three_zero_two_property/StaffModule/widgets/appbar.dart';
import 'package:three_zero_two_property/StaffModule/widgets/custom_drawer.dart';
import 'package:three_zero_two_property/constant/constant.dart';
import 'package:three_zero_two_property/widgets/titleBar.dart';

class Change_password extends StatefulWidget {
  const Change_password({super.key});

  @override
  State<Change_password> createState() => _Change_passwordState();
}

class _Change_passwordState extends State<Change_password> {
  TextEditingController provider = TextEditingController();
  TextEditingController policy = TextEditingController();
  TextEditingController effective = TextEditingController();
  TextEditingController expiration = TextEditingController();
  TextEditingController liablity = TextEditingController();
  GlobalKey<ScaffoldState> key = GlobalKey<ScaffoldState>();
  bool isLoading = false;
  bool ispassword1 = true;
  bool ispassword2 = true;
  List<File> _pdfFiles = [];

  List<String> _uploadedFileNames = [];

  Future<void> _pickPdfFiles() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: true,
    );

    if (result != null) {
      List<File> files = result.paths
          .where((path) => path != null)
          .map((path) => File(path!))
          .toList();

      if (files.length > 10) {
        Fluttertoast.showToast(msg: 'You can only select up to 10 files.');
        return; // Exit the method if more than 10 files are selected
      }

      setState(() {
        _pdfFiles = files;
      });

      for (var file in _pdfFiles) {
        await _uploadPdf(file);
      }
    }
  }

  Future<void> _uploadPdf(File pdfFile) async {
    try {
      String? fileName = await uploadPdf(pdfFile);
      setState(() {
        if (fileName != null) {
          if (_uploadedFileNames.isNotEmpty) {
            _uploadedFileNames.clear();
          }
          _uploadedFileNames.add(fileName);
        }
      });
    } catch (e) {
      logError('PDF upload failed: $e');
    }
  }

  Future<String?> uploadPdf(File pdfFile) async {
    final String uploadUrl = '${image_upload_url}/api/images/upload';

    var request = http.MultipartRequest('POST', Uri.parse(uploadUrl));
    request.files.add(await http.MultipartFile.fromPath('files', pdfFile.path));

    var response = await apiSend(request);
    var responseData = await http.Response.fromStream(response);

    var responseBody = json.decode(responseData.body);
    if (responseBody['status'] == 'ok') {
      Fluttertoast.showToast(msg: 'PDF added successfully');
      List file = responseBody['files'];
      return file.first["filename"];
    } else {
      throw Exception('Failed to upload file: ${responseBody['message']}');
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    DateTime? selectedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime(2101),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: blueColor, // header background color
              onPrimary: Colors.white, // header text color
              // onSurface: Colors.blue, // body text color
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
        effective.text = DateFormat('dd-MM-yyyy').format(selectedDate);
      });
    }
  }

  Future<void> _selectDateexpiration(BuildContext context) async {
    DateTime? selectedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime(2101),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: blueColor, // header background color
              onPrimary: Colors.white, // header text color
              // onSurface: Colors.blue, // body text color
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
        expiration.text = DateFormat('dd-MM-yyyy').format(selectedDate);
      });
    }
  }

  GlobalKey<FormState> _formkey = GlobalKey<FormState>();

  //for change password

  @override
  void initState() {
    super.initState();
    _loadOldPassword();
  }

  TextEditingController currentpassword = TextEditingController();
  TextEditingController password = TextEditingController();
  TextEditingController confirmpassword = TextEditingController();
  bool currentpassworderror = false;
  bool passworderror = false;
  bool confirmpassworderror = false;
  bool loading = false;
  String currentpasswordmessage = "";
  String passwordmessage = "";
  String confirmpasswordmessage = "";
  bool visiable_password = true;
  bool visiable_password_confirm = true;
  bool visiable_passwordcurrent = true;
  final formKey = GlobalKey<FormState>();

  //for save

  Future<void> _savePassword(String password) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        "staffmember_password", password); // Store the new password
  }

  String oldPassword = "";
  Future<void> _loadOldPassword() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    String? pass = prefs.getString("staffmember_password");
    setState(() {
      // Same nullable as the validation below — `pass!` threw on a
      // session with no stored copy. Empty string instead; the check
      // itself now treats absence as a failure.
      oldPassword = pass ?? '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: widget_302_Staff.App_Bar(context: context),
        backgroundColor: Colors.white,
        drawer: CustomDrawerStaff(
          currentpage: "Dashboard",
          dropdown: false,
        ),
        body: Form(
          key: _formkey,
          child: Container(
            color: Colors.white,
            child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
              if (constraints.maxWidth > 600) {
                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        height: 25,
                      ),
                      titleBar(
                        width: MediaQuery.of(context).size.width * .91,
                        title: 'Change Password',
                        //  size: 18,
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal:
                                MediaQuery.of(context).size.width * 0.04,
                            vertical: 20),
                        child: Container(
                          width: double.infinity,
                          // height: !form_valid ? 860 : 830,
                          decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10.0),
                              border: Border.all(
                                color: Color.fromRGBO(21, 43, 103, 1),
                              )),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16.0, vertical: 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Enter your new password *',
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey)),
                                SizedBox(
                                  height: 10,
                                ),
                                Row(
                                  children: [
                                    Expanded(
                                      child: CustomTextField(
                                        keyboardType: TextInputType.text,
                                        hintText: 'New Password',
                                        obscureText: ispassword1,
                                        controller: provider,
                                        //   label: "",
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return 'please enter the subject';
                                          }
                                          return null;
                                        },
                                        suffixIcon: ispassword1
                                            ? Icon(
                                                Icons.visibility,
                                                color: Colors.grey,
                                              )
                                            : Icon(Icons.visibility_off,
                                                color: Colors.grey),
                                        onSuffixIconPressed: () {
                                          setState(() {
                                            ispassword1 = !ispassword1;
                                          });
                                        },
                                      ),
                                    ),
                                    Expanded(
                                      child: Visibility(
                                        visible: false,
                                        child: CustomTextField(
                                          keyboardType: TextInputType.text,
                                          hintText: 'New Password',
                                          obscureText: ispassword1,
                                          controller: provider,
                                          //   label: "",
                                          validator: (value) {
                                            if (value == null ||
                                                value.isEmpty) {
                                              return 'please enter the subject';
                                            }
                                            return null;
                                          },
                                          suffixIcon: ispassword1
                                              ? Icon(
                                                  Icons.visibility,
                                                  color: Colors.grey,
                                                )
                                              : Icon(Icons.visibility_off,
                                                  color: Colors.grey),
                                          onSuffixIconPressed: () {
                                            setState(() {
                                              ispassword1 = !ispassword1;
                                            });
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(
                                  height: 10,
                                ),
                                Text('Confirm new password *',
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey)),
                                SizedBox(
                                  height: 10,
                                ),
                                Row(
                                  children: [
                                    Expanded(
                                      child: CustomTextField(
                                        keyboardType: TextInputType.text,
                                        hintText: 'Confirm Password',
                                        obscureText: ispassword2,
                                        controller: policy,
                                        //   label: "",
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return 'please enter the subject';
                                          }
                                          return null;
                                        },
                                        suffixIcon: ispassword2
                                            ? Icon(
                                                Icons.visibility,
                                                color: Colors.grey,
                                              )
                                            : Icon(Icons.visibility_off,
                                                color: Colors.grey),
                                        onSuffixIconPressed: () {
                                          setState(() {
                                            ispassword2 = !ispassword2;
                                          });
                                        },
                                        matchingPasswordController: provider,
                                      ),
                                    ),
                                    Expanded(
                                      child: Visibility(
                                        visible: false,
                                        child: CustomTextField(
                                          keyboardType: TextInputType.text,
                                          hintText: 'Confirm Password',
                                          obscureText: ispassword2,
                                          controller: policy,
                                          //   label: "",
                                          validator: (value) {
                                            if (value == null ||
                                                value.isEmpty) {
                                              return 'please enter the subject';
                                            }
                                            return null;
                                          },
                                          suffixIcon: ispassword2
                                              ? Icon(
                                                  Icons.visibility,
                                                  color: Colors.grey,
                                                )
                                              : Icon(Icons.visibility_off,
                                                  color: Colors.grey),
                                          onSuffixIconPressed: () {
                                            setState(() {
                                              ispassword2 = !ispassword2;
                                            });
                                          },
                                          matchingPasswordController: provider,
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
                      Padding(
                        padding: const EdgeInsets.only(left: 35.0),
                        child: Row(
                          children: [
                            Container(
                              height: 50,
                              width: 180,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: blueColor,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8.0),
                                  ),
                                ),
                                onPressed: () {
                                  // A second tap while the first request is in
                                  // flight submits again: `loading` only drives
                                  // the spinner, it never disables the button.
                                  // Matches the Tenant/Vendor screens.
                                  if (loading) return;
                                  //print("calling 111");
                                  if (_formkey.currentState!.validate()) {
                                    //  print("calling 22");
                                    addinsurance();
                                  }
                                },
                                child: isLoading
                                    ? Center(
                                        child: SpinKitFadingCircle(
                                          color: Colors.white,
                                          size: 55.0,
                                        ),
                                      )
                                    : Text(
                                        'Change Password',
                                        style:
                                            TextStyle(color: Color(0xFFf7f8f9)),
                                      ),
                              ),
                            ),
                            SizedBox(
                              width: 8,
                            ),
                            Container(
                                height: 50,
                                width: 120,
                                decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8.0)),
                                child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: Color(0xFFffffff),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(8.0))),
                                    onPressed: () {
                                      Navigator.pop(context);
                                    },
                                    child: Text(
                                      'Cancel',
                                      style:
                                          TextStyle(color: Color(0xFF748097)),
                                    )))
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              } else {
                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        height: 25,
                      ),
                      titleBar(
                        width: MediaQuery.of(context).size.width * .91,
                        title: 'Change Password',
                        //  size: 18,
                      ),

                      // Padding(
                      //   padding: const EdgeInsets.all(12.0),
                      //   child: Container(
                      //     width: double.infinity,
                      //     // height: !form_valid ? 860 : 830,
                      //     decoration: BoxDecoration(
                      //         borderRadius: BorderRadius.circular(10.0),
                      //         border: Border.all(
                      //           color: Color.fromRGBO(21, 43, 103, 1),
                      //         )),
                      //     child: Padding(
                      //       padding: const EdgeInsets.symmetric(horizontal: 16.0,vertical: 10),
                      //       child: Column(
                      //         crossAxisAlignment: CrossAxisAlignment.start,
                      //         children: [
                      //           Text('Enter your new password *',
                      //               style: TextStyle(
                      //                   fontSize: 13,
                      //                   fontWeight: FontWeight.bold,
                      //                   color: Colors.grey)),
                      //           SizedBox(
                      //             height: 10,
                      //           ),
                      //           CustomTextField(
                      //             keyboardType: TextInputType.text,
                      //             hintText: 'New Password',
                      //             obscureText: ispassword1,
                      //             controller: provider,
                      //             //   label: "",
                      //             validator: (value) {
                      //               if (value == null || value.isEmpty) {
                      //                 return 'please enter the subject';
                      //               }
                      //               return null;
                      //             },
                      //             suffixIcon: ispassword1 ? Icon(Icons.visibility,color: Colors.grey,) :  Icon(Icons.visibility_off,color: Colors.grey),
                      //             onSuffixIconPressed: (){
                      //               setState(() {
                      //                 print("111");
                      //                 ispassword1 = !ispassword1;
                      //               });
                      //             },
                      //           ),
                      //           SizedBox(
                      //             height: 10,
                      //           ),
                      //           Text('Confirm new password *',
                      //               style: TextStyle(
                      //                   fontSize: 13,
                      //                   fontWeight: FontWeight.bold,
                      //                   color: Colors.grey)),
                      //           SizedBox(
                      //             height: 10,
                      //           ),
                      //           CustomTextField(
                      //             keyboardType: TextInputType.text,
                      //             hintText: 'Confirm Password',
                      //             obscureText: ispassword2,
                      //             controller: policy,
                      //             //   label: "",
                      //             validator: (value) {
                      //               if (value == null || value.isEmpty) {
                      //                 return 'please enter the subject';
                      //               }
                      //               return null;
                      //             },
                      //             suffixIcon: ispassword2 ? Icon(Icons.visibility,color: Colors.grey,) :  Icon(Icons.visibility_off,color: Colors.grey),
                      //             onSuffixIconPressed: (){
                      //               setState(() {
                      //                 print("111");
                      //                 ispassword2 = !ispassword2;
                      //               });
                      //             },
                      //             matchingPasswordController: provider,
                      //           ),
                      //
                      //         ],
                      //       ),
                      //     ),
                      //   ),
                      // ),
                      Padding(
                        // Breathing room on the sides, and the card carries the
                        // same soft hairline shell as the Admin profile cards
                        // instead of a hard black outline.
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20.0, vertical: 15.0),
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            border:
                                Border.all(color: const Color(0xFFE5E9F0)),
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Form(
                            key: formKey,
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                children: [
                                  // const SizedBox(height: 20),
                                  // Login text
                                  Row(
                                    children: [
                                      Text(
                                        "Change Password ",
                                        style: TextStyle(
                                            color: blueColor,
                                            fontWeight: FontWeight.bold,
                                            fontSize: MediaQuery.of(context)
                                                    .size
                                                    .width *
                                                0.045),
                                      ),
                                    ],
                                  ),
                                  SizedBox(
                                    height: MediaQuery.of(context).size.height *
                                        0.03,
                                  ),
                                  Row(
                                    children: [
                                      Text(
                                        'Current Password',
                                        style: TextStyle(
                                            color: Color(0xFF8A95A8),
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(
                                    height: 10,
                                  ),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Material(
                                          // Flat field, matching the house form
                                          // style: soft tinted fill with a
                                          // hairline outline, no drop shadow.
                                          elevation: 0,
                                          color: Colors.transparent,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          child: Container(
                                            height: 54,
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                  color: outlineClr),
                                              color: const Color(0xFFF7F9FC),
                                            ),
                                            child: Stack(
                                              children: [
                                                Positioned.fill(
                                                  child: Padding(
                                                    padding: EdgeInsets.symmetric(
                                                        horizontal:
                                                            MediaQuery.of(
                                                                        context)
                                                                    .size
                                                                    .width *
                                                                0.00),
                                                    child: Center(
                                                      child: TextField(
                                                        onChanged: (value) {
                                                          setState(() {
                                                            currentpassworderror =
                                                                false;
                                                          });
                                                        },
                                                        obscureText:
                                                            visiable_passwordcurrent,
                                                        controller:
                                                            currentpassword,
                                                        cursorColor: blueColor,
                                                        decoration:
                                                            InputDecoration(
                                                          border:
                                                              InputBorder.none,
                                                          contentPadding:
                                                              EdgeInsets.all(
                                                                  14),
                                                          enabledBorder:
                                                              currentpassworderror
                                                                  ? OutlineInputBorder(
                                                                      borderRadius: BorderRadius.circular(MediaQuery.of(context)
                                                                              .size
                                                                              .width *
                                                                          0.013),
                                                                      borderSide:
                                                                          BorderSide(
                                                                              color: Colors.red), // Set border color here
                                                                    )
                                                                  : InputBorder
                                                                      .none,
                                                          prefixIcon: Padding(
                                                            padding:
                                                                const EdgeInsets
                                                                    .all(15.0),
                                                            child: Image.asset(
                                                                'assets/icons/pasword.png'),
                                                          ),
                                                          hintText:
                                                              "Current Password",
                                                          suffixIcon: InkWell(
                                                            onTap: () {
                                                              setState(() {
                                                                visiable_passwordcurrent =
                                                                    !visiable_passwordcurrent;
                                                              });
                                                            },
                                                            child: Icon(
                                                              visiable_passwordcurrent
                                                                  ? Icons
                                                                      .remove_red_eye_outlined
                                                                  : Icons
                                                                      .visibility_off_outlined,
                                                              color:
                                                                  Colors.grey,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  currentpassworderror
                                      ? Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                currentpasswordmessage,
                                                style: TextStyle(
                                                    color: Colors.red),
                                              ),
                                            ),
                                          ],
                                        )
                                      : Container(),
                                  SizedBox(
                                    height: MediaQuery.of(context).size.height *
                                        0.02,
                                  ),
                                  Row(
                                    children: [
                                      Text(
                                        // This field is bound to `password` —
                                        // the NEW password. The label said
                                        // "current password", contradicting the
                                        // field's own "New Password" hint and
                                        // asking for the current one twice.
                                        'New Password',
                                        style: TextStyle(
                                            color: Color(0xFF8A95A8),
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(
                                    height: 10,
                                  ),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Material(
                                          // Flat field, matching the house form
                                          // style: soft tinted fill with a
                                          // hairline outline, no drop shadow.
                                          elevation: 0,
                                          color: Colors.transparent,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          child: Container(
                                            height: 54,
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                  color: outlineClr),
                                              color: const Color(0xFFF7F9FC),
                                            ),
                                            child: Stack(
                                              children: [
                                                Positioned.fill(
                                                  child: Padding(
                                                    padding: EdgeInsets.symmetric(
                                                        horizontal:
                                                            MediaQuery.of(
                                                                        context)
                                                                    .size
                                                                    .width *
                                                                0.00),
                                                    child: Center(
                                                      child: TextField(
                                                        onChanged: (value) {
                                                          setState(() {
                                                            passworderror =
                                                                false;
                                                          });
                                                        },
                                                        obscureText:
                                                            visiable_password,
                                                        controller: password,
                                                        cursorColor: blueColor,
                                                        decoration:
                                                            InputDecoration(
                                                          border:
                                                              InputBorder.none,
                                                          contentPadding:
                                                              EdgeInsets.all(
                                                                  14),
                                                          enabledBorder:
                                                              passworderror
                                                                  ? OutlineInputBorder(
                                                                      borderRadius: BorderRadius.circular(MediaQuery.of(context)
                                                                              .size
                                                                              .width *
                                                                          0.013),
                                                                      borderSide:
                                                                          BorderSide(
                                                                              color: Colors.red), // Set border color here
                                                                    )
                                                                  : InputBorder
                                                                      .none,
                                                          prefixIcon: Padding(
                                                            padding:
                                                                const EdgeInsets
                                                                    .all(15.0),
                                                            child: Image.asset(
                                                                'assets/icons/pasword.png'),
                                                          ),
                                                          hintText:
                                                              "New Password",
                                                          suffixIcon: InkWell(
                                                            onTap: () {
                                                              setState(() {
                                                                visiable_password =
                                                                    !visiable_password;
                                                              });
                                                            },
                                                            child: Icon(
                                                              visiable_password
                                                                  ? Icons
                                                                      .remove_red_eye_outlined
                                                                  : Icons
                                                                      .visibility_off_outlined,
                                                              color:
                                                                  Colors.grey,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  passworderror
                                      ? Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                passwordmessage,
                                                style: TextStyle(
                                                    color: Colors.red),
                                              ),
                                            ),
                                          ],
                                        )
                                      : Container(),
                                  SizedBox(
                                    height: MediaQuery.of(context).size.height *
                                        0.02,
                                  ),
                                  Row(
                                    children: [
                                      Text(
                                        'Confirm Password',
                                        style: TextStyle(
                                            color: Color(0xFF8A95A8),
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(
                                    height: 10,
                                  ),
                                  Row(
                                    children: [
                                      // SizedBox(
                                      //   width: MediaQuery.of(context).size.width * 0.099,
                                      // ),
                                      Expanded(
                                        child: Material(
                                          // Flat field, matching the house form
                                          // style: soft tinted fill with a
                                          // hairline outline, no drop shadow.
                                          elevation: 0,
                                          color: Colors.transparent,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          child: Container(
                                            height: 54,
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                  color: outlineClr),
                                              color: const Color(0xFFF7F9FC),
                                            ),
                                            child: Stack(
                                              children: [
                                                Positioned.fill(
                                                  child: Padding(
                                                    padding: EdgeInsets.symmetric(
                                                        horizontal:
                                                            MediaQuery.of(
                                                                        context)
                                                                    .size
                                                                    .width *
                                                                0.00),
                                                    child: Center(
                                                      child: TextField(
                                                        onChanged: (value) {
                                                          setState(() {
                                                            confirmpassworderror =
                                                                false;
                                                          });
                                                        },
                                                        obscureText:
                                                            visiable_password_confirm,
                                                        controller:
                                                            confirmpassword,
                                                        cursorColor: blueColor,
                                                        decoration:
                                                            InputDecoration(
                                                          border:
                                                              InputBorder.none,
                                                          contentPadding:
                                                              EdgeInsets.all(
                                                                  14),
                                                          enabledBorder:
                                                              confirmpassworderror
                                                                  ? OutlineInputBorder(
                                                                      borderRadius: BorderRadius.circular(MediaQuery.of(context)
                                                                              .size
                                                                              .width *
                                                                          0.013),
                                                                      borderSide:
                                                                          BorderSide(
                                                                              color: Colors.red), // Set border color here
                                                                    )
                                                                  : InputBorder
                                                                      .none,
                                                          prefixIcon: Padding(
                                                            padding:
                                                                const EdgeInsets
                                                                    .all(15.0),
                                                            child: Image.asset(
                                                                'assets/icons/pasword.png'),
                                                          ),
                                                          hintText:
                                                              "Confirm password",
                                                          suffixIcon: InkWell(
                                                            onTap: () {
                                                              setState(() {
                                                                visiable_password_confirm =
                                                                    !visiable_password_confirm;
                                                              });
                                                            },
                                                            child: Icon(
                                                              visiable_password_confirm
                                                                  ? Icons
                                                                      .remove_red_eye_outlined
                                                                  : Icons
                                                                      .visibility_off_outlined,
                                                              color:
                                                                  Colors.grey,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      // SizedBox(
                                      //   width: MediaQuery.of(context).size.width * 0.099,
                                      // ),
                                    ],
                                  ),
                                  confirmpassworderror
                                      ? Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                confirmpasswordmessage,
                                                style: TextStyle(
                                                    color: Colors.red),
                                              ),
                                            ),
                                          ],
                                        )
                                      : Container(),

                                  // Spacer(),
                                  // Login button
                                  SizedBox(
                                    height: MediaQuery.of(context).size.height *
                                        0.04,
                                  ),
                                  GestureDetector(
                                    onTap: () async {
                                      // Same in-flight guard as the other
                                      // submit paths on this screen.
                                      if (loading) return;
                                      SharedPreferences prefs =
                                          await SharedPreferences.getInstance();
                                      String? pass = prefs
                                          .getString("staffmember_password");
                                      // Validate Current Password
                                      if (currentpassword.text.isEmpty) {
                                        setState(() {
                                          currentpassworderror = true;
                                          currentpasswordmessage =
                                              "Current password is required";
                                        });
                                      // A missing stored copy must FAIL this check, not skip it. With
                                      // `pass != null &&` a null fell through to the
                                      // else below and marked the field valid, so a
                                      // session restored without the password re-stored
                                      // let the password be changed without knowing the
                                      // old one. Any non-empty box passed.
                                      } else if (pass == null ||
                                          currentpassword.text != pass) {
                                        setState(() {
                                          currentpassworderror = true;
                                          currentpasswordmessage =
                                              "Current password is incorrect";
                                        });
                                      } else {
                                        setState(() {
                                          currentpassworderror = false;
                                        });
                                      }

                                      // Validate the new password
                                      if (password.text.isEmpty) {
                                        setState(() {
                                          passworderror = true;
                                          passwordmessage =
                                              "Password is required";
                                        });
                                      } else if (password.text.length < 8) {
                                        setState(() {
                                          passworderror = true;
                                          passwordmessage =
                                              "Password must have at least 8 characters";
                                        });
                                      } else if (!RegExp(
                                              r'^(?=.*?[a-z])(?=.*?[A-Z])(?=.*?[0-9])(?=.*?[!@#\$&*~]).{8,}$')
                                          .hasMatch(password.text)) {
                                        setState(() {
                                          passworderror = true;
                                          passwordmessage =
                                              'Password must contain at least one uppercase letter, one lowercase letter, one number, and one special character';
                                        });
                                      } else if (password.text == pass) {
                                        setState(() {
                                          passworderror = true;
                                          passwordmessage =
                                              'New password cannot be the same as the old password';
                                        });
                                        // Fluttertoast.showToast(msg: "New password cannot be the same as the old password");
                                        //  return;
                                      } else {
                                        setState(() {
                                          passworderror =
                                              false; // Clear the password error
                                        });
                                      }

                                      // Validate the confirmation password
                                      if (confirmpassword.text.isEmpty) {
                                        setState(() {
                                          confirmpassworderror = true;
                                          confirmpasswordmessage =
                                              "Confirm password is required";
                                        });
                                      } else if (confirmpassword.text !=
                                          password.text) {
                                        setState(() {
                                          confirmpassworderror = true;
                                          confirmpasswordmessage =
                                              "Both passwords do not match";
                                        });
                                      } else {
                                        setState(() {
                                          confirmpassworderror =
                                              false; // Clear the confirmation password error
                                        });
                                      }

                                      // If there are no errors, proceed to change the password
                                      if (!passworderror &&
                                          !confirmpassworderror &&
                                          !currentpassworderror) {
                                        //await _savePassword(password.text);
                                        addinsurance(); // Call the function to change the password
                                      }
                                    },
                                    child: Row(
                                      children: [
                                        // Full-width primary action, matching
                                        // the house button style.
                                        Expanded(
                                            child: Container(
                                          height: 54,
                                          decoration: BoxDecoration(
                                            color: navyClr,
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Center(
                                            child: loading
                                                ? SpinKitFadingCircle(
                                                    color: Colors.white,
                                                    size: 40.0,
                                                  )
                                                : Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    children: [
                                                      Text(
                                                        "Change Password",
                                                        style: TextStyle(
                                                          color: Colors.white,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: MediaQuery.of(
                                                                          context)
                                                                      .size
                                                                      .width <
                                                                  500
                                                              ? 15
                                                              : 20,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                          ),
                                        )),
                                      ],
                                    ),
                                  ),
                                  SizedBox(
                                    height: MediaQuery.of(context).size.height *
                                        0.02,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Padding(
                      //   padding: const EdgeInsets.all(16.0),
                      //   child: Row(
                      //     children: [
                      //       Container(
                      //         height: 50,
                      //         width: 180,
                      //         decoration: BoxDecoration(
                      //           borderRadius: BorderRadius.circular(8.0),
                      //         ),
                      //         child: ElevatedButton(
                      //           style: ElevatedButton.styleFrom(
                      //             backgroundColor: blueColor,
                      //             shape: RoundedRectangleBorder(
                      //               borderRadius: BorderRadius.circular(8.0),
                      //             ),
                      //           ),
                      //           onPressed: (){
                      //             //print("calling 111");
                      //             if(_formkey.currentState!.validate()){
                      //                 print("calling 22");
                      //               addinsurance();
                      //             }
                      //           },
                      //           child: isLoading
                      //               ? Center(
                      //             child: SpinKitFadingCircle(
                      //               color: Colors.white,
                      //               size: 55.0,
                      //             ),
                      //           )
                      //               : Text(
                      //             'Change Password',
                      //             style: TextStyle(color: Color(0xFFf7f8f9)),
                      //           ),
                      //         ),
                      //       ),
                      //       SizedBox(
                      //         width: 8,
                      //       ),
                      //       Container(
                      //           height: 50,
                      //           width: 120,
                      //           decoration: BoxDecoration(
                      //               borderRadius: BorderRadius.circular(8.0)),
                      //           child: ElevatedButton(
                      //               style: ElevatedButton.styleFrom(
                      //                   backgroundColor: Color(0xFFffffff),
                      //                   shape: RoundedRectangleBorder(
                      //                       borderRadius:
                      //                       BorderRadius.circular(8.0))),
                      //               onPressed: () {
                      //                 Navigator.pop(context);
                      //               },
                      //               child: Text(
                      //                 'Cancel',
                      //                 style: TextStyle(color: Color(0xFF748097)),
                      //               )))
                      //     ],
                      //   ),
                      // ),
                    ],
                  ),
                );
              }
              /*return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        height: 25,
                      ),
                      titleBar(
                        width: MediaQuery.of(context).size.width * .91,
                        title: 'Change Password',
                       // size: 18,
                      ),

                      Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Container(
                          width: double.infinity,
                          // height: !form_valid ? 860 : 830,
                          decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10.0),
                              border: Border.all(
                                color: Color.fromRGBO(21, 43, 103, 1),
                              )),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0,vertical: 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Enter your new password *',
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey)),
                                SizedBox(
                                  height: 10,
                                ),
                                CustomTextField(
                                  keyboardType: TextInputType.text,
                                  hintText: 'New Password',
                                  obscureText: ispassword1,
                                  controller: provider,
                                  //   label: "",
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'please enter the subject';
                                    }
                                    return null;
                                  },
                                  suffixIcon: ispassword1 ? Icon(Icons.visibility,color: Colors.grey,) :  Icon(Icons.visibility_off,color: Colors.grey),
                                  onSuffixIconPressed: (){
                                    setState(() {
                                      print("111");
                                      ispassword1 = !ispassword1;
                                    });
                                  },
                                ),
                                SizedBox(
                                  height: 10,
                                ),
                                Text('Confirm new password *',
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey)),
                                SizedBox(
                                  height: 10,
                                ),
                                CustomTextField(
                                  keyboardType: TextInputType.text,
                                  hintText: 'Confirm Password',
                                  obscureText: ispassword2,
                                  controller: policy,
                                  //   label: "",
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'please enter the subject';
                                    }
                                    return null;
                                  },
                                  suffixIcon: ispassword2 ? Icon(Icons.visibility,color: Colors.grey,) :  Icon(Icons.visibility_off,color: Colors.grey),
                                  onSuffixIconPressed: (){
                                    setState(() {
                                      print("111");
                                      ispassword2 = !ispassword2;
                                    });
                                  },
                                  matchingPasswordController: provider,
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
                              width: 180,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: blueColor,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8.0),
                                  ),
                                ),
                                onPressed: (){
                                  // Same in-flight guard as the primary
                                  // submit button above.
                                  if (loading) return;
                                  //print("calling 111");
                                  if(_formkey.currentState!.validate()){
                                    //  print("calling 22");
                                    addinsurance();
                                  }
                                },
                                child: isLoading
                                    ? Center(
                                  child: SpinKitFadingCircle(
                                    color: Colors.white,
                                    size: 55.0,
                                  ),
                                )
                                    : Text(
                                  'Change Password',
                                  style: TextStyle(color: Color(0xFFf7f8f9)),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 8,
                            ),
                            Container(
                                height: 50,
                                width: 120,
                                decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8.0)),
                                child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: Color(0xFFffffff),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                            BorderRadius.circular(8.0))),
                                    onPressed: () {
                                      Navigator.pop(context);
                                    },
                                    child: Text(
                                      'Cancel',
                                      style: TextStyle(color: Color(0xFF748097)),
                                    )))
                          ],
                        ),
                      ),
                    ],
                  ),
                );*/
            }),
          ),
        ));
  }

  addinsurance() async {
    try {
      setState(() {
        loading = true;
        isLoading = true;
      });
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');
      String? email = prefs.getString('staffemail');
      String? staffid = prefs.getString("staff_id");
      Map<String, dynamic> values = {
        'password': password.text.trim(),
        "currentPassword": currentpassword.text.trim()
      };
      // v2 identifies the staff member from the JWT instead of an email in the
      // URL. The legacy `/reset_password/$email` route resolves the account BY
      // EMAIL and picks the wrong record when two accounts share one, and it
      // runs with no auth check at all. Web moved to v2 for both reasons
      // (StaffPassChange.jsx); the server keeps v1 alive only for older
      // clients.
      final http.Response response = await apiPut(
        Uri.parse('$Api_url/api/staffmember/reset_password_v2'),
        headers: <String, String>{
          "authorization": "CRM $token",
          "id": "CRM $staffid",
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: json.encode(values),
      );
      log(response.body);
      var responseData = json.decode(response.body);

      // Check HTTP status code and response message
      if (response.statusCode == 200 &&
          (responseData["message"] != null &&
              responseData["message"]
                  .toString()
                  .toLowerCase()
                  .contains("success"))) {
        await _savePassword(password.text.trim());

        // Save new token if provided
        if (responseData["newToken"] != null) {
          await prefs.setString('token', responseData["newToken"]);
        }

        setState(() {
          loading = false;
          isLoading = false;
        });

        Fluttertoast.showToast(
            msg: responseData["message"] ?? "Password updated successfully");

        // Clear form and navigate back after a short delay
        Future.delayed(Duration(milliseconds: 500), () {
          if (mounted) {
            Navigator.pop(context);
          }
        });

        return responseData;
      } else {
        setState(() {
          loading = false;
          isLoading = false;
        });

        String errorMessage =
            responseData["message"] ?? "Failed to change password";
        Fluttertoast.showToast(msg: errorMessage);
        throw Exception(errorMessage);
      }
    } catch (e) {
      setState(() {
        loading = false;
        isLoading = false;
      });

      String errorMsg = 'An error occurred: $e';
      // Remove the exception prefix if it's already in the message
      if (e.toString().contains('Exception:')) {
        errorMsg = friendlyErrorMessage(e);
      }
      Fluttertoast.showToast(msg: errorMsg);
      logError('Error: $e');
    }
  }
}

class CustomTextField extends StatefulWidget {
  final String hintText;
  final TextEditingController? controller;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final bool obscureText;
  final Function(String)? onChanged;
  final Function(String)? onChanged2;
  final Widget? suffixIcon;
  final IconData? prefixIcon;
  final void Function()? onSuffixIconPressed;
  final void Function()? onTap;
  final String? label;
  final bool readOnnly;
  final bool? amount_check;
  final String? max_amount;
  final String? error_mess;
  final TextEditingController? matchingPasswordController;

  CustomTextField({
    Key? key,
    this.onChanged,
    this.controller,
    required this.hintText,
    this.obscureText = false,
    this.keyboardType = TextInputType.emailAddress,
    this.readOnnly = false,
    this.prefixIcon,
    this.suffixIcon,
    this.validator,
    this.onSuffixIconPressed,
    this.label,
    this.onTap,
    this.onChanged2,
    this.amount_check,
    this.max_amount,
    this.error_mess,
    this.matchingPasswordController,

    // Initialize onTap
  }) : super(key: key);

  @override
  CustomTextFieldState createState() => CustomTextFieldState();
}

class CustomTextFieldState extends State<CustomTextField> {
  String? _errorMessage;
  TextEditingController _textController =
      TextEditingController(); // Add this line

  @override
  void dispose() {
    _textController.dispose(); // Dispose the controller when not needed anymore
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        FormField<String>(
          validator: (value) {
            if (widget.controller!.text.trim().isEmpty) {
              setState(() {
                if (widget.label == null)
                  _errorMessage = 'Please ${widget.hintText}';
                else
                  _errorMessage = 'Please ${widget.label}';
              });
              return '';
            } else if (widget.matchingPasswordController != null &&
                widget.controller!.text.trim() !=
                    widget.matchingPasswordController!.text.trim()) {
              setState(() {
                _errorMessage = 'Password does not match';
              });
              return '';
            }
            return null;
          },
          builder: (FormFieldState<String> state) {
            return Column(
              children: <Widget>[
                Material(
                  elevation: 2,
                  borderRadius: BorderRadius.circular(8.0),
                  child: Container(
                    height: 50,
                    padding:
                        EdgeInsets.symmetric(horizontal: 16.0, vertical: 0),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8.0),
                      //border: Border.all(color: blueColor),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          offset: Offset(4, 4),
                          blurRadius: 3,
                        ),
                      ],
                    ),
                    child: TextFormField(
                      /*    onFieldSubmitted: (value){
                        if(value.isNotEmpty){

                          if(widget.amount_check != null){
                            if(int.parse(value) > int.parse(widget.max_amount!)){
                              setState(() {
                                _errorMessage = '${widget.error_mess}';
                              });
                            }
                          }
                          else{
                            setState(() {
                              _errorMessage = null;
                            });
                          }

                        }
                        print(value);
                        widget.onChanged2;
                      },*/
                      onFieldSubmitted: widget.onChanged2,
                      onChanged: (value) {
                        if (value.isNotEmpty) {
                          setState(() {
                            _errorMessage = null;
                          });
                        }
                        widget.onChanged;
                      },
                      onTap: widget.onTap,
                      obscureText: widget.obscureText,
                      readOnly: widget.readOnnly,
                      keyboardType: widget.keyboardType,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          state.validate();
                        }
                        return null;
                      },
                      controller: widget.controller,
                      decoration: InputDecoration(
                        suffixIcon: InkWell(
                            onTap: widget.onSuffixIconPressed,
                            child: widget.suffixIcon),
                        hintStyle:
                            TextStyle(fontSize: 13, color: Color(0xFFb0b6c3)),
                        border: InputBorder.none,
                        hintText: widget.hintText,
                      ),
                    ),
                  ),
                ),
                if (state.hasError || widget.amount_check != null)
                  SizedBox(height: 24),
                // Reserve space for error message
              ],
            );
          },
        ),
        if (_errorMessage != null)
          Positioned(
            top: 60,
            left: 8,
            child: Text(
              _errorMessage!,
              style: TextStyle(
                color: Colors.red,
                fontSize: 12.0,
              ),
            ),
          ),
      ],
    );
  }
}

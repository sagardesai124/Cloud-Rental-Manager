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

import '../../../constant/constant.dart';

import '../../../widgets/titleBar.dart';
import '../widgets/appbar.dart';
import '../widgets/custom_drawer.dart';
import '../../widgets/drawer_tiles.dart';
import 'package:http/http.dart' as http;
import 'package:three_zero_two_property/services/api_helpers.dart';

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
  bool ispassword3 = true;
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
    // Every other authenticated call in this file sends these headers; this
    // upload never did. The server has since started requiring them here
    // (confirmed via a live 401 "session expired" — the token/id were never
    // actually being sent, not actually expired).
    final prefs = await SharedPreferences.getInstance();
    final _token = prefs.getString('token');
    final _tenantId = prefs.getString('tenant_id');
    request.headers.addAll({
      "authorization": "CRM $_token",
      "id": "CRM $_tenantId",
    });
    request.files.add(await http.MultipartFile.fromPath('files', pdfFile.path));

    var response = await apiSend(request);
    var responseData = await http.Response.fromStream(response);

    var responseBody = json.decode(responseData.body);
    if (responseBody['status'] == 'ok') {
      // A success status with no file entries would otherwise crash on
      // .first (or on the null list itself) after the toast already fired.
      final List files = responseBody['files'] ?? [];
      if (files.isEmpty) {
        throw Exception('Upload succeeded but no file was returned');
      }
      Fluttertoast.showToast(msg: 'PDF added successfully');
      return files.first["filename"];
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

  //for change password

  @override
  void initState() {
    super.initState();
  }

  TextEditingController currentpassword = TextEditingController();
  TextEditingController password = TextEditingController();
  TextEditingController confirmpassword = TextEditingController();
  bool currentpassworderror = false;
  bool passworderror = false;
  // bool passwordsameerror = false;
  bool confirmpassworderror = false;
  bool loading = false;

  String currentpasswordmessage = "";
  String passwordmessage = "";
  // String passwordsamemessage = "";
  String confirmpasswordmessage = "";
  bool visiable_passwordcurrent = true;
  bool visiable_password = true;
  bool visiable_password_confirm = true;

  final formKey = GlobalKey<FormState>();
  GlobalKey<FormState> _formkey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        key: key,
        appBar: widget_302.App_Bar(
          context: context,
          onDrawerIconPressed: () {
            key.currentState!.openDrawer();
          },
        ),
        backgroundColor: Colors.white,
        drawer: CustomDrawer(
          currentpage: 'Dashboard',
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
                      const SizedBox(
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
                                color: const Color.fromRGBO(21, 43, 103, 1),
                              )),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16.0, vertical: 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Enter your new password *',
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey)),
                                const SizedBox(
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
                                            ? const Icon(
                                                Icons.visibility,
                                                color: Colors.grey,
                                              )
                                            : const Icon(Icons.visibility_off,
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
                                              ? const Icon(
                                                  Icons.visibility,
                                                  color: Colors.grey,
                                                )
                                              : const Icon(Icons.visibility_off,
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
                                const SizedBox(
                                  height: 10,
                                ),
                                const Text('Confirm new password *',
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey)),
                                const SizedBox(
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
                                            ? const Icon(
                                                Icons.visibility,
                                                color: Colors.grey,
                                              )
                                            : const Icon(Icons.visibility_off,
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
                                              ? const Icon(
                                                  Icons.visibility,
                                                  color: Colors.grey,
                                                )
                                              : const Icon(Icons.visibility_off,
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
                                onPressed: isLoading
                                    ? null
                                    : () {
                                        if (_formkey.currentState!
                                            .validate()) {
                                          addinsurance();
                                        }
                                      },
                                child: isLoading
                                    ? const Center(
                                        child: SpinKitFadingCircle(
                                          color: Colors.white,
                                          size: 55.0,
                                        ),
                                      )
                                    : const Text(
                                        'Change Password',
                                        style:
                                            TextStyle(color: Color(0xFFf7f8f9)),
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
                );
              } else {
                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(
                        height: 25,
                      ),
                      titleBar(
                        width: MediaQuery.of(context).size.width * .91,
                        title: 'Change Password',
                        //  size: 18,
                      ),
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
                                  const Row(
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
                                                              const EdgeInsets
                                                                  .all(14),
                                                          enabledBorder:
                                                              currentpassworderror
                                                                  ? OutlineInputBorder(
                                                                      borderRadius: BorderRadius.circular(MediaQuery.of(context)
                                                                              .size
                                                                              .width *
                                                                          0.013),
                                                                      borderSide:
                                                                          const BorderSide(
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
                                                style: const TextStyle(
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
                                  const Row(
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
                                                              const EdgeInsets
                                                                  .all(14),
                                                          enabledBorder:
                                                              passworderror
                                                                  ? OutlineInputBorder(
                                                                      borderRadius: BorderRadius.circular(MediaQuery.of(context)
                                                                              .size
                                                                              .width *
                                                                          0.013),
                                                                      borderSide:
                                                                          const BorderSide(
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
                                                style: const TextStyle(
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
                                  const Row(
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
                                                              const EdgeInsets
                                                                  .all(14),
                                                          enabledBorder:
                                                              confirmpassworderror
                                                                  ? OutlineInputBorder(
                                                                      borderRadius: BorderRadius.circular(MediaQuery.of(context)
                                                                              .size
                                                                              .width *
                                                                          0.013),
                                                                      borderSide:
                                                                          const BorderSide(
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
                                                style: const TextStyle(
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
                                    onTap: loading
                                        ? null
                                        : () async {
                                      // Validate Current Password
                                      if (currentpassword.text.isEmpty) {
                                        setState(() {
                                          currentpassworderror = true;
                                          currentpasswordmessage =
                                              "Current password is required";
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
                                      } else if (password.text.trim() ==
                                          currentpassword.text.trim()) {
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
                                                ? const SpinKitFadingCircle(
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
                      //               //  print("calling 22");
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
    // The tablet layout's button reads isLoading, the phone layout's reads
    // loading — both are driven from here so either button shows the
    // spinner, disables itself, and can't fire a second overlapping
    // reset_password request (each success rotates the auth token, so an
    // overlapping request can leave the client holding a token the server
    // has already superseded).
    if (isLoading || loading) return;
    setState(() {
      isLoading = true;
      loading = true;
    });
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? id = prefs.getString("tenant_id");
      String? admin_id = prefs.getString("adminId");
      String? token = prefs.getString('token');
      String? email = prefs.getString('email');
      Map<String, dynamic> values = {
        'password': password.text.trim(),
        "currentPassword": currentpassword.text.trim()
      };

      // v2 identifies the tenant from the JWT instead of an email in the URL.
      // The legacy `/reset_password/$email` route resolves the account BY EMAIL
      // and picks the wrong record when two tenants share one — which rejected a
      // correct current password — and it runs with no auth check at all. Web
      // moved to v2 for both reasons (TenantPassChange.jsx); the server keeps v1
      // alive only for older clients.
      final http.Response response = await apiPut(
        Uri.parse('$Api_url/api/tenant/reset_password_v2'),
        headers: <String, String>{
          "authorization": "CRM $token",
          "id": "CRM $id",
          //'Content-Type': 'application/json; charset=UTF-8',
        },
        body: values,
      );

      log(response.body);
      var responseData = json.decode(response.body);

      // The server reports success in the HTTP status; its body carries only
      // `message` and `newToken`. Reading a `statusCode` field out of the body
      // never matched, so every response — including a successful one — fell to
      // the else branch and printed its message, leaving the form untouched.
      // StaffModule's copy already checks the HTTP status.
      if (response.statusCode == 200) {
        // The server issues a fresh token with the password change and the old
        // one stops working. Web stores it the same way (TenantPassChange.jsx),
        // and StaffModule's copy of this screen already does. Without it every
        // later request keeps using the stale token until the user logs out and
        // back in. Guarded, so a response without the field changes nothing.
        if (responseData["newToken"] != null) {
          await prefs.setString('token', responseData["newToken"]);
        }

        Fluttertoast.showToast(msg: responseData["message"]);
        // Both fields are emptied so the new password is not left sitting on
        // screen in plaintext once it has been saved. StaffModule's copy of this
        // screen reaches the same end state by popping straight after the toast;
        // this one stays put, so it has to clear itself. Validation state is
        // reset too, or a stale message would sit under a now-empty field.
        if (mounted) {
          setState(() {
            // All THREE fields, not just the two new-password ones — this screen
            // also asks for the current password, and leaving that populated
            // keeps a live credential on screen just the same.
            currentpassword.clear();
            password.clear();
            confirmpassword.clear();
            passworderror = false;
            confirmpassworderror = false;
            passwordmessage = "";
            confirmpasswordmessage = "";
          });
        }
        // Leave the screen once the change is saved, as web does
        // (TenantPassChange.jsx routes to the dashboard on success) and as
        // StaffModule's copy of this screen already does. The clear above still
        // runs first, so nothing is on screen during the short delay.
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) Navigator.pop(context);
        });
        return responseData;
      } else {
        // The server checks the current password (no copy is kept on the
        // device); show its answer under the field, as before.
        if ('${responseData["message"]}'
            .toLowerCase()
            .contains('current password is incorrect')) {
          setState(() {
            currentpassworderror = true;
            currentpasswordmessage = "Current password is incorrect";
          });
        }
        Fluttertoast.showToast(msg: responseData["message"]);
        return;
      }
    } catch (e) {
      Fluttertoast.showToast(msg: 'An error occurred. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
          loading = false;
        });
      }
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
                        hintStyle: const TextStyle(
                            fontSize: 13, color: Color(0xFFb0b6c3)),
                        border: InputBorder.none,
                        hintText: widget.hintText,
                      ),
                    ),
                  ),
                ),
                if (state.hasError || widget.amount_check != null)
                  const SizedBox(height: 24),
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
              style: const TextStyle(
                color: Colors.red,
                fontSize: 12.0,
              ),
            ),
          ),
      ],
    );
  }
}

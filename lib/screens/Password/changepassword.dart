import 'dart:convert';

import 'package:email_validator/email_validator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
import 'package:three_zero_two_property/services/api_helpers.dart';
import 'package:three_zero_two_property/screens/Login/login_screen.dart';

import '../../constant/constant.dart';

class Changepassword extends StatefulWidget {
  final String email;
  final String admin_id;
  final String role;
  String user_id;
  Changepassword(
      {super.key,
      required this.email,
      required this.admin_id,
      required this.role,
      required this.user_id});

  @override
  State<Changepassword> createState() => _ChangepasswordState();
}

class _ChangepasswordState extends State<Changepassword> {
  TextEditingController password = TextEditingController();
  TextEditingController confirmpassword = TextEditingController();

  @override
  void dispose() {
    password.dispose();
    confirmpassword.dispose();
    super.dispose();
  }
  bool passworderror = false;
  bool confirmpassworderror = false;
  bool loading = false;

  String passwordmessage = "";
  String confirmpasswordmessage = "";
  bool visiable_password = true;
  bool visiable_password_confirm = true;

  final formKey = GlobalKey<FormState>();
  void changePassword() async {
    setState(() {
      loading = true; // Set loading to true while changing password
    });

    final response = await apiPut(
      Uri.parse('${Api_url}/api/admin/app/reset_password'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode(<String, dynamic>{
        'email': widget.email,
        // Trim to match how login submits the password
        // (login_screen.dart: `password.text.trim()`). The server hashes
        // whatever string it receives, so saving an untrimmed value here would
        // store a password that the trimmed login value can never match.
        'password': password.text.trim(),
        'admin_id': widget.admin_id,
        'role': widget.role,
        'user_id': widget.user_id
      }),
    );
    setState(() {
      loading = false; // Set loading to false after receiving response
    });
    if (response.statusCode == 200) {
      final jsonData = json.decode(response.body);
      if (jsonData["message"] == "Password Updated Successfully") {
        Navigator.push(
            context, MaterialPageRoute(builder: (context) => Login_Screen()));
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(content: Text("Password updated successfully")),
        // );
        Fluttertoast.showToast(msg: 'Password updated successfully');
      } else {
        // Handle other successful responses or display an error message
      }
    } else {
      // Handle HTTP error responses
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text("Failed to update password")),
      // );
      Fluttertoast.showToast(msg: 'Failed to update password');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Form(
          key: formKey,
          child: ListView(
            children: [
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.1,
              ),
              Image(
                image: AssetImage('assets/images/logo.png'),
                height: MediaQuery.of(context).size.height * 0.05,
                width: MediaQuery.of(context).size.width * 0.9,
              ),
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.02,
              ),
              // Welcome
              // Center(
              //   child: Text(
              //     "Welcome to 302 Rentals",
              //     style: TextStyle(
              //       color: Colors.black,
              //       fontWeight: FontWeight.bold,
              //       fontSize: MediaQuery.of(context).size.width * 0.05,
              //     ),
              //   ),
              // ),
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.01,
              ),
              // Login text
              Center(
                child: Text(
                  "Change Password ?",
                  style: TextStyle(
                      color: Colors.black,
                      fontSize: MediaQuery.of(context).size.width * 0.045),
                ),
              ),
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.06,
              ),
              Row(
                children: [
                  SizedBox(
                    width: MediaQuery.of(context).size.width * 0.099,
                  ),
                  Text(
                    'Password',
                    style: TextStyle(
                        fontSize: 14,
                        color: blueColor,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.01,
              ),
              Row(
                children: [
                  SizedBox(
                    width: MediaQuery.of(context).size.width * 0.099,
                  ),
                  Expanded(
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(
                            MediaQuery.of(context).size.width * 0.02),
                        color: Color.fromRGBO(196, 196, 196, 0.3),
                      ),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                  horizontal:
                                      MediaQuery.of(context).size.width * 0.00),
                              child: Center(
                                child: TextField(
                                  onChanged: (value) {
                                    setState(() {
                                      passworderror = false;
                                    });
                                  },
                                  obscureText: visiable_password,
                                  controller: password,
                                  cursorColor: blueColor,
                                  decoration: InputDecoration(
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.all(14),
                                    enabledBorder: passworderror
                                        ? OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            borderSide: BorderSide(
                                                color: Colors
                                                    .red), // Set border color here
                                          )
                                        : InputBorder.none,
                                    prefixIcon: Padding(
                                      padding: const EdgeInsets.all(15.0),
                                      child: Image.asset(
                                          'assets/icons/pasword.png'),
                                    ),
                                    hintText: "Password",
                                    suffixIcon: InkWell(
                                      onTap: () {
                                        setState(() {
                                          visiable_password =
                                              !visiable_password;
                                        });
                                      },
                                      child: Icon(
                                        visiable_password
                                            ? Icons.remove_red_eye_outlined
                                            : Icons.visibility_off_outlined,
                                        color: Colors.grey,
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
                  SizedBox(
                    width: MediaQuery.of(context).size.width * 0.099,
                  ),
                ],
              ),
              passworderror
                  ? Row(
                      children: [
                        SizedBox(
                          width: MediaQuery.of(context).size.width * 0.099,
                        ),
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                              top: MediaQuery.of(context).size.height * 0.005,
                            ),
                            child: Text(
                              passwordmessage,
                              style: TextStyle(color: Colors.red, fontSize: 12),
                              textAlign: TextAlign.left,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: MediaQuery.of(context).size.width * 0.099,
                        ),
                      ],
                    )
                  : Container(),
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.03,
              ),
              Row(
                children: [
                  SizedBox(
                    width: MediaQuery.of(context).size.width * 0.099,
                  ),
                  Text(
                    'Confirm Password',
                    style: TextStyle(
                        fontSize: 14,
                        color: blueColor,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.01,
              ),
              Row(
                children: [
                  SizedBox(
                    width: MediaQuery.of(context).size.width * 0.099,
                  ),
                  Expanded(
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(
                            MediaQuery.of(context).size.width * 0.02),
                        color: Color.fromRGBO(196, 196, 196, 0.3),
                      ),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                  horizontal:
                                      MediaQuery.of(context).size.width * 0.00),
                              child: Center(
                                child: TextField(
                                  onChanged: (value) {
                                    setState(() {
                                      confirmpassworderror = false;
                                    });
                                  },
                                  obscureText: visiable_password_confirm,
                                  controller: confirmpassword,
                                  cursorColor: blueColor,
                                  decoration: InputDecoration(
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.all(14),
                                    enabledBorder: confirmpassworderror
                                        ? OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            borderSide: BorderSide(
                                                color: Colors
                                                    .red), // Set border color here
                                          )
                                        : InputBorder.none,
                                    prefixIcon: Padding(
                                      padding: const EdgeInsets.all(15.0),
                                      child: Image.asset(
                                          'assets/icons/pasword.png'),
                                    ),
                                    hintText: "Confirm Password",
                                    suffixIcon: InkWell(
                                      onTap: () {
                                        setState(() {
                                          visiable_password_confirm =
                                              !visiable_password_confirm;
                                        });
                                      },
                                      child: Icon(
                                        visiable_password_confirm
                                            ? Icons.remove_red_eye_outlined
                                            : Icons.visibility_off_outlined,
                                        color: Colors.grey,
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
                  SizedBox(
                    width: MediaQuery.of(context).size.width * 0.099,
                  ),
                ],
              ),
              confirmpassworderror
                  ? Padding(
                      padding: EdgeInsets.only(
                        left: MediaQuery.of(context).size.width * 0.099,
                        top: MediaQuery.of(context).size.height * 0.005,
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          confirmpasswordmessage,
                          style: TextStyle(color: Colors.red, fontSize: 12),
                          textAlign: TextAlign.left,
                        ),
                      ),
                    )
                  : Container(),

              // Spacer(),
              // Login button
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.08,
              ),
              GestureDetector(
                onTap: () {
                  // A second tap while the first request is in flight
                  // submits again: `loading` only swaps the button's child to
                  // a spinner, it never disables the tap. The duplicate reset
                  // pushed a second Login_Screen onto the stack and raised a
                  // second toast. Matches the guard already used on the OTP
                  // screen (otp_vrify.dart).
                  if (loading) return;
                  if (password.text.isEmpty) {
                    setState(() {
                      passworderror = true;
                      passwordmessage = "Password is required";
                    });
                  } else if (password.text.length < 8) {
                    setState(() {
                      passworderror = true;
                      passwordmessage = "Password must have 8 Characters";
                    });
                  } else if (!RegExp(
                          r'^(?=.*?[a-z])(?=.*?[A-Z])(?=.*?[0-9])(?=.*?[!@#\$&*~]).{8,}$')
                      .hasMatch(password.text)) {
                    setState(() {
                      passworderror = true;
                      passwordmessage =
                          'Password must contain at least one uppercase letter, one lowercase letter, one number, and one special character';
                    });
                  } else {
                    setState(() {
                      passworderror = false;
                    });
                  }
                  if (confirmpassword.text.isEmpty) {
                    setState(() {
                      confirmpassworderror = true;
                      confirmpasswordmessage = "Confirm password is required";
                    });
                  } else if (confirmpassword.text != password.text) {
                    setState(() {
                      confirmpassworderror = true;
                      confirmpasswordmessage = "Passwords do not match";
                    });
                  } else {
                    setState(() {
                      confirmpassworderror = false;
                    });
                  }
                  if (!passworderror && !confirmpassworderror) {
                    changePassword();
                  }
                },
                child: Center(
                  child: Container(
                    height: MediaQuery.of(context).size.height * 0.06,
                    width: MediaQuery.of(context).size.width * 0.8,
                    decoration: BoxDecoration(
                      color: Color(0xFF152B51),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: loading
                          ? SpinKitFadingCircle(
                              color: Colors.white,
                              size: 40.0,
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "Change password",
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize:
                                          MediaQuery.of(context).size.width *
                                              0.04),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),

              SizedBox(
                height: MediaQuery.of(context).size.height * 0.02,
              ),
              GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                },
                child: Center(
                  child: Container(
                    height: MediaQuery.of(context).size.height * 0.06,
                    width: MediaQuery.of(context).size.width * 0.8,
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.black)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Cancel",
                          style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize:
                                  MediaQuery.of(context).size.width * 0.04),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

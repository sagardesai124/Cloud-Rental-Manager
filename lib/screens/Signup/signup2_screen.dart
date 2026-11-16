import 'dart:convert';
import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zxcvbn/zxcvbn.dart';

import '../../constant/constant.dart';
import '../Dashboard/dashboard_one.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
import 'package:three_zero_two_property/services/api_helpers.dart';

import '../../widgets/dialogbox.dart';
import '../Login/login_screen.dart';

class Signup2 extends StatefulWidget {
  String? firstname;
  String? lastname;
  String? email;
  Signup2({super.key, this.firstname, this.lastname, this.email});

  @override
  State<Signup2> createState() => _Signup2State();
}

class _Signup2State extends State<Signup2> {
  TextEditingController firstname = TextEditingController();
  TextEditingController lastname = TextEditingController();
  TextEditingController email = TextEditingController();
  TextEditingController companyname = TextEditingController();
  TextEditingController phonenumber = TextEditingController();
  TextEditingController password = TextEditingController();
  TextEditingController confirmpassword = TextEditingController();

  @override
  void dispose() {
    firstname.dispose();
    lastname.dispose();
    email.dispose();
    companyname.dispose();
    phonenumber.dispose();
    password.dispose();
    confirmpassword.dispose();
    super.dispose();
  }
  bool isChecked = false;
  //bool isChecked = false;
  bool companynameerror = false;
  bool phoneerror = false;
  bool passworderror = false;
  bool confirmpassworderror = false;
  bool loading = false;
  String companynamemessage = "";
  String confirmpasswordmessage = "";
  String phonemessage = "";
  String passwordmessage = "";
  bool showdialog = false;
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    firstname.text = widget.firstname ?? "";
    lastname.text = widget.lastname ?? "";
    email.text = widget.email ?? "";
  }

  String? _errorMessage;
  int _score = 0; // Initialize score as an int
  String _feedback = '';

  bool obsecure = true;
  bool conobsecure = true;
  @override
  Widget build(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    double height = MediaQuery.of(context).size.height;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.white,
        body: ListView(
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 16), // Safe area
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    height: 40,
                    width: 40,
                    decoration: BoxDecoration(
                      color: Colors.grey[200], // light grey
                      borderRadius: BorderRadius.circular(
                          10), // square-ish with smooth edges
                    ),
                    child: Icon(
                      Icons.arrow_back_ios_sharp,
                      color: Colors.black54,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: MediaQuery.of(context).size.height * 0.03),
            Image(
              image: AssetImage('assets/images/logo.png'),
              height: 40,
              width: width * .8,
              alignment: Alignment.center,
            ),
            SizedBox(height: MediaQuery.of(context).size.height * 0.02),
            Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: MediaQuery.of(context).size.width * 0.05),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Text(
                  //   "Welcome to 302 Rentals",
                  //   style: TextStyle(
                  //       color: Colors.black,
                  //       fontWeight: FontWeight.bold,
                  //       fontSize: MediaQuery.of(context).size.width * 0.05),
                  // ),
                  // SizedBox(height: MediaQuery.of(context).size.height * 0.013),
                  Text(
                    "Sign up for a free account",
                    style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: MediaQuery.of(context).size.width * 0.04),
                  ),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.025),
                  Row(
                    children: [
                      SizedBox(width: MediaQuery.of(context).size.width * 0.05),
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
                                          MediaQuery.of(context).size.width *
                                              0.00),
                                  child: TextField(
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.w500, // optional
                                    ),
                                    enabled: false,
                                    controller: firstname,
                                    cursorColor: blueColor,
                                    decoration: InputDecoration(
                                      border: InputBorder.none,
                                      contentPadding: EdgeInsets.all(14),
                                      prefixIcon: Padding(
                                        padding: const EdgeInsets.all(15.0),
                                        child: Image.asset(
                                          'assets/icons/user.png',
                                        ),
                                      ),
                                      hintText: "First Name",
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(width: MediaQuery.of(context).size.width * 0.05),
                    ],
                  ),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                  Row(
                    children: [
                      SizedBox(width: MediaQuery.of(context).size.width * 0.05),
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
                                          MediaQuery.of(context).size.width *
                                              0.00),
                                  child: Center(
                                    child: TextField(
                                      enabled: false,
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontWeight: FontWeight.w500, // optional
                                      ),
                                      controller: lastname,
                                      cursorColor: blueColor,
                                      decoration: InputDecoration(
                                        border: InputBorder.none,
                                        contentPadding: EdgeInsets.all(14),
                                        prefixIcon: Padding(
                                          padding: const EdgeInsets.all(15.0),
                                          child: Image.asset(
                                              'assets/icons/user.png'),
                                        ),
                                        hintText: "Last Name",
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(width: MediaQuery.of(context).size.width * 0.05),
                    ],
                  ),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                  Row(
                    children: [
                      SizedBox(width: MediaQuery.of(context).size.width * 0.05),
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
                                          MediaQuery.of(context).size.width *
                                              0.00),
                                  child: Center(
                                    child: TextField(
                                      keyboardType: TextInputType.emailAddress,
                                      controller: email,
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontWeight: FontWeight.w500, // optional
                                      ),
                                      enabled: false,
                                      cursorColor: blueColor,
                                      decoration: InputDecoration(
                                        border: InputBorder.none,
                                        contentPadding: EdgeInsets.all(14),
                                        prefixIcon: Padding(
                                          padding: const EdgeInsets.all(18.0),
                                          child: Image.asset(
                                              'assets/icons/email.png'),
                                        ),
                                        hintText: "Business Email",
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(width: MediaQuery.of(context).size.width * 0.05),
                    ],
                  ),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                  Row(
                    children: [
                      SizedBox(width: MediaQuery.of(context).size.width * 0.05),
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
                                          MediaQuery.of(context).size.width *
                                              0.00),
                                  child: Center(
                                    child: TextField(
                                      controller: companyname,
                                      onChanged: (value) {
                                        setState(() {
                                          companynameerror = false;
                                        });
                                      },
                                      cursorColor: blueColor,
                                      decoration: InputDecoration(
                                        enabledBorder: companynameerror
                                            ? OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                borderSide: BorderSide(
                                                    color: Colors
                                                        .red), // Set border color here
                                              )
                                            : InputBorder.none,
                                        border: InputBorder.none,
                                        contentPadding: EdgeInsets.all(15),
                                        prefixIcon: Padding(
                                          padding: const EdgeInsets.all(15.0),
                                          child: Image.asset(
                                              'assets/icons/home.png'),
                                        ),
                                        hintText: "Company Name",
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(width: MediaQuery.of(context).size.width * 0.05),
                    ],
                  ),
                  companynameerror
                      ? Center(
                          child: Text(
                          companynamemessage,
                          style: TextStyle(color: Colors.red),
                        ))
                      : Container(),

                  SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                  Row(
                    children: [
                      SizedBox(width: MediaQuery.of(context).size.width * 0.05),
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
                                          MediaQuery.of(context).size.width *
                                              0.00),
                                  child: Center(
                                    child: TextField(
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                        LengthLimitingTextInputFormatter(10),
                                        PhoneNumberFormatter(),
                                      ],
                                      onChanged: (value) {
                                        setState(() {
                                          phoneerror = false;
                                        });
                                      },
                                      controller: phonenumber,
                                      keyboardType: TextInputType.number,
                                      cursorColor: blueColor,
                                      decoration: InputDecoration(
                                        enabledBorder: phoneerror
                                            ? OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                borderSide: BorderSide(
                                                    color: Colors
                                                        .red), // Set border color here
                                              )
                                            : InputBorder.none,
                                        border: InputBorder.none,
                                        contentPadding: EdgeInsets.all(15),
                                        prefixIcon: Padding(
                                          padding: const EdgeInsets.all(15.0),
                                          child: Image.asset(
                                              'assets/icons/phone.png'),
                                        ),
                                        hintText: "Phone Number",
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(width: MediaQuery.of(context).size.width * 0.05),
                    ],
                  ),
                  phoneerror
                      ? Center(
                          child: Text(
                          phonemessage,
                          style: TextStyle(color: Colors.red),
                        ))
                      : Container(),

                  SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                  Row(
                    children: [
                      SizedBox(width: MediaQuery.of(context).size.width * 0.05),
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
                                          MediaQuery.of(context).size.width *
                                              0.00),
                                  child: Center(
                                    child: TextField(
                                      onChanged: (value) {
                                        setState(() {
                                          passworderror = false;
                                        });
                                      },
                                      obscureText: obsecure,
                                      controller: password,
                                      cursorColor: blueColor,
                                      decoration: InputDecoration(
                                        border: InputBorder.none,
                                        contentPadding: EdgeInsets.all(15),
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
                                        hintText: "Password",
                                        //  suffixIcon: Icon(),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(width: MediaQuery.of(context).size.width * 0.05),
                    ],
                  ),
                  passworderror
                      ? Center(
                          child: Text(
                          passwordmessage,
                          style: TextStyle(color: Colors.red),
                        ))
                      : Container(),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                  Row(
                    children: [
                      SizedBox(width: MediaQuery.of(context).size.width * 0.05),
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
                                          MediaQuery.of(context).size.width *
                                              0.00),
                                  child: Center(
                                    child: TextField(
                                      onChanged: (value) {
                                        setState(() {
                                          confirmpassworderror = false;
                                        });
                                      },
                                      obscureText: conobsecure,
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
                                        hintText: "Confirm Password",
                                        //  suffixIcon: Icon(),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(width: MediaQuery.of(context).size.width * 0.05),
                    ],
                  ),
                  confirmpassworderror
                      ? Center(
                          child: Text(
                          confirmpasswordmessage,
                          style: TextStyle(color: Colors.red),
                        ))
                      : Container(),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                  // Row(
                  //   children: [
                  //     SizedBox(width: MediaQuery.of(context).size.width * 0.05),
                  //     Container(
                  //       height: MediaQuery.of(context).size.height * 0.03,
                  //       width: MediaQuery.of(context).size.height * 0.03,
                  //       decoration: BoxDecoration(
                  //         color: Colors.white,
                  //         borderRadius: BorderRadius.circular(5),
                  //       ),
                  //       child: Checkbox(
                  //         activeColor: isChecked ? Colors.black : Colors.white,
                  //         checkColor: Colors.white,
                  //         value: isChecked, // assuming _isChecked is a boolean variable indicating whether the checkbox is checked or not
                  //         onChanged: ( value) {
                  //           setState(() {
                  //             isChecked = value ?? false; // ensure value is not null
                  //           });
                  //         },
                  //       ),
                  //     ),
                  //     SizedBox(width: MediaQuery.of(context).size.width * 0.02),
                  //     Text(
                  //       "I have read and accept CloudRentalManager terms and conditions ",
                  //       style: TextStyle(
                  //         fontSize: MediaQuery.of(context).size.width * 0.024,
                  //         color: Colors.black,
                  //       ),
                  //     ),
                  //     SizedBox(width: MediaQuery.of(context).size.width * 0.05),
                  //   ],
                  // ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(width: MediaQuery.of(context).size.width * 0.05),

                      // Checkbox
                      Container(
                        height: MediaQuery.of(context).size.height * 0.035,
                        width: MediaQuery.of(context).size.height * 0.035,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Checkbox(
                          activeColor: Colors.black,
                          checkColor: Colors.white,
                          value: isChecked,
                          onChanged: (value) {
                            setState(() {
                              isChecked = value ?? false;
                            });
                          },
                        ),
                      ),

                      SizedBox(width: MediaQuery.of(context).size.width * 0.02),

                      // Text that wraps
                      Expanded(
                        child: Text(
                          "   I have read and accept CloudRentalManager\n                      terms and conditions",
                          textAlign: TextAlign.justify,
                          style: TextStyle(
                            fontSize: MediaQuery.of(context).size.width * 0.03,
                            color: Colors.black,
                            height: 1.3, //
                          ),
                        ),
                      ),

                      SizedBox(width: MediaQuery.of(context).size.width * 0.05),
                    ],
                  ),

                  SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                  GestureDetector(
                    onTap: () {
                      if (companyname.text.trim().isEmpty) {
                        setState(() {
                          companynameerror = true;
                          companynamemessage = "Company Name is required";
                        });
                      } else {
                        setState(() {
                          companynameerror = false;
                        });
                      }
                      if (phonenumber.text.trim().isEmpty) {
                        setState(() {
                          phoneerror = true;
                          phonemessage = "Phone Number is required";
                        });
                      } else {
                        // Extract only digits from the formatted phone number
                        String digitsOnly =
                            phonenumber.text.replaceAll(RegExp(r'\D'), '');
                        if (digitsOnly.length != 10) {
                          setState(() {
                            phoneerror = true;
                            phonemessage = "Phone Number must be 10 digits";
                          });
                        } else {
                          setState(() {
                            phoneerror = false;
                          });
                        }
                      }
                      // if(password.text.isEmpty){
                      //   setState(() {
                      //     passworderror = true;
                      //     passwordmessage = "Password is required";
                      //   });
                      // }
                      // else if(password.text.length < 8){
                      //   setState(() {
                      //     passworderror = true;
                      //     passwordmessage = "Password must have 8 Characters";
                      //   });
                      // }
                      // else if (!_validatePassword(password.text)) {
                      //   setState(() {
                      //     passworderror = true;
                      //     passwordmessage = 'Password must contain at least one uppercase letter, one lowercase letter, one number, and one special character';
                      //     // _errorMessage
                      //   });
                      // }
                      // // else if (!RegExp(r'^(?=.*?[a-z])(?=.*?[A-Z])(?=.*?[0-9])(?=.*?[!@#\$&*~]).{8,}$').hasMatch(password.text)) {
                      // //  setState(() {
                      // //    passworderror = true;
                      // //    passwordmessage =  'Password must contain at least one uppercase letter, one lowercase letter, one number, and one special character';
                      // //
                      // //  });
                      // //
                      // // }
                      // else {
                      //   setState(() {
                      //     passworderror = false;
                      //   });
                      // }
                      if (password.text.trim().isEmpty) {
                        setState(() {
                          passworderror = true;
                          passwordmessage = "Password is required";
                        });
                      } else if (password.text.trim().length < 8) {
                        setState(() {
                          passworderror = true;
                          passwordmessage = "Password must have 8 Characters";
                        });
                      } else {
                        String? validationMessage =
                            ValidatePassword(password.text.trim());

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

                      if (confirmpassword.text.trim().isEmpty) {
                        setState(() {
                          confirmpassworderror = true;
                          confirmpasswordmessage =
                              "Confirm Password is required";
                        });
                      } else if (confirmpassword.text.trim() !=
                          password.text.trim()) {
                        setState(() {
                          confirmpassworderror = true;
                          confirmpasswordmessage = "Both Password is not match";
                        });
                      } else {
                        setState(() {
                          confirmpassworderror = false;
                        });
                      }
                      if (companynameerror == false &&
                          passworderror == false &&
                          confirmpassworderror == false &&
                          phoneerror == false) {
                        if (isChecked) {
                          loginsubmit();
                        } else {
                          Fluttertoast.showToast(
                              msg: "Please check the Terms & Condition",
                              toastLength: Toast.LENGTH_SHORT,
                              gravity: ToastGravity.CENTER,
                              timeInSecForIosWeb: 1,
                              backgroundColor: Colors.red,
                              textColor: Colors.white,
                              fontSize: 16.0);
                        }
                      }

                      /*  setState(() {
                        showdialog = true;
                      });
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return dialogbox();
                        },
                      );*/
                      //  dialogbox();
                      // Navigator.push(context, MaterialPageRoute(builder: (context)=>CustomBlurDialog()));
                    },
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
                                size: 50.0,
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    "Create your free account",
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize:
                                            MediaQuery.of(context).size.width *
                                                0.035),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 20,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFF152B51),
                            ),
                            child: Center(
                              child: Text(
                                "1",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          Text('About you',
                              style: TextStyle(
                                  fontSize: 10, fontFamily: 'muslish')),
                        ],
                      ),
                      SizedBox(
                        width: 2,
                      ),
                      Column(
                        children: [
                          Container(
                            width: 50,
                            height: 2,
                            color: Colors.grey,
                          ),
                          SizedBox(
                            height: 15,
                          )
                        ],
                      ),
                      SizedBox(
                        width: 2,
                      ),
                      Column(
                        children: [
                          Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFF152B51),
                            ),
                            child: Center(
                              child: Text(
                                "2",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          Text(
                            'Customize Account',
                            textAlign: TextAlign.center,
                            style:
                                TextStyle(fontSize: 10, fontFamily: 'muslish'),
                          ),
                        ],
                      ),
                      SizedBox(
                        width: 10,
                      ),
                      Column(
                        children: [
                          Container(
                            width: 50,
                            height: 2,
                            color: Colors.grey,
                          ),
                          SizedBox(
                            height: 15,
                          )
                        ],
                      ),
                      SizedBox(
                        width: 10,
                      ),
                      Column(
                        children: [
                          Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color:
                                  showdialog ? Color(0xFF152B51) : Colors.grey,
                            ),
                            child: Center(
                              child: Text(
                                "3",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          Text("Final",
                              style: TextStyle(
                                  fontSize: 10, fontFamily: 'muslish'))
                        ],
                      ),
                    ],
                  ),
                  SizedBox(
                    height: 20,
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> loginsubmit() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      loading = true;
    });

    final response =
        await apiPost(Uri.parse('${Api_url}/api/admin/register'), body: {
      "email": email.text.trim(),
      "password": password.text.trim(),
      "first_name": firstname.text.trim(),
      "last_name": lastname.text.trim(),
      "company_name": companyname.text.trim(),
      "phone_number": phonenumber.text.trim()
    });
    final jsonData = json.decode(response.body);
    if (jsonData["statusCode"] == 200) {
      prefs.setString('first_name', jsonData['data']['first_name']);
      prefs.setString('last_name', jsonData['data']['last_name']);
      setState(() {
        loading = false;
        showdialog = true;
      });
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return dialogbox();
        },
      );

      /*final List<dynamic> data = jsonData['data'];
      List<String> urls = [];
      List<String> banners = [];
      List<bool> banner_status = [];
      for (var item in data) {
        urls.add(item['url']);
        banners.add(item['id']);
        banner_status.add(item['status']);
      }
      for (var i = 0 ; i < banner_status.length;i++){
        setState(() {
          if(banner_status[i])
            selectedIndex = i;
        });
      }
      setState(() {
        imageUrls = urls;
        bannerid = banners;
        bannerstatus = banner_status;
        isLoading = false;
      });
      print(imageUrls);*/
    } else {
      Fluttertoast.showToast(msg: jsonData["message"]);
      setState(() {
        loading = false;
      });
    }
  }

  dialogbox() {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 1, sigmaY: 1),
      child: AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
              10.0), // Set your desired border radius here
        ),
        title: Image.asset(
          "assets/check.png",
          height: 36,
          width: 36,
        ),
        content: SizedBox(
          height: 160,
          child: Column(
            children: [
              Text(
                'Your account is being created!',
                style: TextStyle(fontSize: 14, fontFamily: 'mulish'),
              ),
              SizedBox(
                height: 20,
              ),
              Text(
                "Feel free to access your account. Once you sign up, we'll start you with a fresh account",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, fontFamily: 'mulish'),
              ),
              SizedBox(
                height: 20,
              ),
              GestureDetector(
                onTap: () {
                  // Navigator.pop(context);
                  Navigator.push(context,
                      MaterialPageRoute(builder: (context) => Login_Screen()));
                },
                child: Container(
                  width: 184,
                  height: 34,
                  decoration: BoxDecoration(
                      color: Color(0xFF152B51),
                      borderRadius: BorderRadius.circular(6)),
                  child: Center(
                    child: Text(
                      "Get Started With Login",
                      style:
                      TextStyle(color: Colors.white, fontFamily: 'mulish'),
                    ),
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}

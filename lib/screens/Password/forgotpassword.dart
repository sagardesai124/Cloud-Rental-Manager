import 'dart:convert';

import 'package:email_validator/email_validator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:three_zero_two_property/services/api_helpers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../constant/constant.dart';
import '../../widgets/test.dart';
import 'otp_vrify.dart';

class ForgotPassword extends StatefulWidget {
  const ForgotPassword({super.key});

  @override
  State<ForgotPassword> createState() => _ForgotPasswordState();
}

class _ForgotPasswordState extends State<ForgotPassword> {
  bool _isEmailSubmitted = false;
  bool _hasMultipleCompanies = false;
  bool loading = false;
  List<Map<String, String>> _companies = [];
  String _selectedCompany = '';
  String admin_id = "";
  String selectedrole = '';
  String passwordmessage = "";
  String companymessage = "";
  String emailmessage = "";
  String rolemessage = "";
  String? userId;
  bool get isEmailSubmitted => _isEmailSubmitted;
  bool get hasMultipleCompanies => _hasMultipleCompanies;
  List<Map<String, String>> get companies => _companies;
  String get selectedCompany => _selectedCompany;
  Future<void> submitEmail() async {
    // `loading` used to be set only inside sendOTP(), so nothing covered the
    // check_role request: the button showed no spinner and the in-flight guard
    // on the tap handler could not see this call, letting a double tap fire
    // two lookups. Set it here, synchronously, before the first await.
    setState(() {
      loading = true;
    });
    // Set once we hand off to sendOTP(), which owns `loading` from that point.
    // Clearing it in the finally would switch the spinner off underneath it.
    bool handedOffToSendOtp = false;
    try {
      // Make API call to check email
      final response = await apiPost(
        Uri.parse('${Api_url}/api/auth/check_role'),
        headers: {'Content-Type': 'application/json'},
        // Trimmed: the server trims before matching admin and staff, but
        // looks tenants and vendors up on the raw string (tenant_email: email
        // / vendor_email: email). A trailing space - which a phone keyboard
        // adds readily - therefore locked a tenant out of recovery while an
        // admin with the same space got straight in.
        body: jsonEncode({'email': email.text.trim()}),
      );
      if (response.statusCode != 200) {
        // The server answers a missing account and a deactivated one with 201,
        // and an empty email with 202 - each carries its own `message` and no
        // `data`. Showing that message beats the old blanket "Email does not
        // exist", which told a user their address was wrong even when the
        // server had returned a 500.
        // Default to a retryable message. Telling a user their email does not
        // exist because the API returned a 500/502/timeout is the worst
        // possible wording here: there is nothing to retry from their point of
        // view, so they give up or raise a ticket saying their account was
        // deleted.
        String message = "Couldn't check that email right now. Please try again.";
        try {
          final decoded = jsonDecode(response.body);
          final serverMessage = decoded is Map ? decoded['message'] : null;
          // 201 (no account / deactivated) and 202 (blank email) carry a
          // message written for the user. A 5xx carries "Error: <exception>",
          // which must never reach the screen.
          if (response.statusCode < 500 &&
              serverMessage is String &&
              serverMessage.trim().isNotEmpty) {
            message = serverMessage;
          }
        } catch (_) {
          // Non-JSON body (a proxy error page) - keep the retryable default.
        }
        Fluttertoast.showToast(msg: message);
        return;
      }
      final data = jsonDecode(response.body);
      // Read defensively rather than casting. The live server always sends a
      // non-empty `data` array on a 200, so this is belt-and-braces against a
      // shape change - but an unguarded `List<dynamic> roles = data['data']`
      // would throw on this screen, which a locked-out user has no way past.
      final roles = data is Map ? data['data'] : null;
      if (roles is! List || roles.isEmpty) {
        Fluttertoast.showToast(msg: "Email does not exist");
      } else {
        if (roles.length > 1) {
          setState(() {
            _hasMultipleCompanies = true;
            _companies = roles
                .map<Map<String, String>>((role) => {
                      'company': role['company_name'],
                      'admin_id': role['admin_id'],
                      'role': role['role'],
                      'user_id': role['user_id'],
                    })
                .toList();
            _isEmailSubmitted = true;
          });
        } else {
          setState(() {
            // The admin and non-admin branches here were byte-identical except
            // that the admin one had `_selectedCompany` commented out, so they
            // have been collapsed. `_selectedCompany` is assigned uniformly:
            // it is write-only in this screen today, but leaving one role
            // silently skipping it was the kind of difference that turns into
            // a blank company name the moment something starts reading it.
            _hasMultipleCompanies = false;
            _selectedCompany = roles[0]['company_name'] ?? '';
            selectedrole = roles[0]['role'];
            admin_id = roles[0]['admin_id'];
            userId = roles[0]["user_id"];
            _isEmailSubmitted = true;
          });
          // Trimmed to match the multi-company path below, which already
          // sends email.text.trim(). The two paths used to disagree.
          sendOTP(email.text.trim());
          handedOffToSendOtp = true;
        }
      }
    } catch (e) {
      // jsonDecode on a non-JSON body (a proxy error page, a 502) used to
      // throw uncaught on a screen with no session to fall back to.
      Fluttertoast.showToast(msg: friendlyErrorMessage(e));
    } finally {
      if (!handedOffToSendOtp && mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  TextEditingController email = TextEditingController();

  @override
  void dispose() {
    email.dispose();
    super.dispose();
  }
  bool emailerror = false;

  final GlobalKey formkey = GlobalKey<FormState>();
  void sendOTP(String email) async {
    setState(() {
      loading = true; // Show loading indicator while sending OTP
    });

    final response = await apiPost(
      Uri.parse('${Api_url}/api/admin/sendOTP'),
      body: {
        'email': email,
        'admin_id': admin_id,
        'role': selectedrole,
        'user_id': userId
      },
    );
    setState(() {
      loading = false; // Hide loading indicator after receiving response
    });

    final jsonData = json.decode(response.body);
    if (jsonData["statusCode"] == 200) {
      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => otp_verify(
                  email: email,
                  admin_id: admin_id,
                  role: selectedrole,
                  userId: userId!,
                )),
      );
      Fluttertoast.showToast(msg: "OTP sent successfully");
      setState(() {
        loading = false;
      });
    } else {
      Fluttertoast.showToast(msg: jsonData["message"]);
      setState(() {
        loading = false;
      });
    }
  }

  void selectCompany(
      String company, String role, String adminid, String user_id) {
    _selectedCompany = company;
    selectedrole = role; // Set role when selecting company
    admin_id = adminid;
    userId = user_id;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Form(
        key: formkey,
        child: ListView(
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.1,
            ),
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
                "Forgot Your Password ?",
                style: TextStyle(
                    color: Colors.black,
                    fontSize: MediaQuery.of(context).size.width * 0.034),
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
                Expanded(
                  child: Text(
                    "Enter your email address below, and we'll send you the OTP to reset your password.",
                    style: TextStyle(
                        color: Colors.black38,
                        fontSize: MediaQuery.of(context).size.width * 0.034),
                  ),
                ),
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.099,
                ),
              ],
            ),
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.028,
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
                      borderRadius: BorderRadius.circular(10),
                      color: Color.fromRGBO(196, 196, 196, .3),
                    ),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: TextField(
                            keyboardType: TextInputType.emailAddress,
                            onChanged: (value) {
                              setState(() {
                                emailerror = false;
                                _isEmailSubmitted = false;
                              });
                            },
                            controller: email,
                            cursorColor: blueColor,
                            decoration: InputDecoration(
                              enabledBorder: emailerror
                                  ? OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(
                                          color: Colors
                                              .red), // Set border color here
                                    )
                                  : InputBorder.none,
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.all(14),
                              prefixIcon: Container(
                                height: 20,
                                width: 20,
                                padding: EdgeInsets.all(13),
                                child: FaIcon(
                                  FontAwesomeIcons.envelope,
                                  size: 20,
                                  color: Colors.grey[600],
                                ),
                              ),
                              hintText: "Email",
                              hintStyle: TextStyle(
                                  color: Colors.grey[600], fontSize: 15),
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
            emailerror
                ? Center(
                    child: Text(
                    emailmessage,
                    style: TextStyle(
                      color: Colors.red,
                    ),
                  ))
                : Container(),
            if (isEmailSubmitted)
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.025,
                  ),
                  if (hasMultipleCompanies) ...[
                    SingleSelectionButtons(
                      buttonOptions: companies,
                      onSelected: (index) {
                        selectCompany(
                          companies[index]["company"]!,
                          companies[index]["role"]!,
                          companies[index]["admin_id"]!,
                          companies[index]["user_id"]!,
                        );
                      },
                    ),
                  ],

                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.025,
                  ),
                  // Login button
                ],
              ),

            if (isEmailSubmitted)
              Column(
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.01,
                  ),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        if (email.text.trim().isEmpty) {
                          setState(() {
                            emailerror = true;
                            emailmessage = "Email is required";
                          });
                        } else if (!EmailValidator.validate(
                            email.text.trim())) {
                          setState(() {
                            emailerror = true;
                            emailmessage = "Email is not valid";
                          });
                        } else {
                          setState(() {
                            emailerror = false;
                            //firstnamemessage = "Firstname is required";
                          });
                        }
                      });
                      if (selectedrole == "") {
                        // If email is valid, send OTP
                        Fluttertoast.showToast(
                            msg: "Please select the company");
                      } else if (!emailerror) {
                        // If email is valid, send OTP
                        sendOTP(email.text.trim());
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
                                      "Submit",
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: MediaQuery.of(context)
                                                  .size
                                                  .width *
                                              0.045),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            if (!isEmailSubmitted)
              Column(
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.06,
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
                      setState(() {
                        if (email.text.isEmpty) {
                          setState(() {
                            emailerror = true;
                            emailmessage = "Email is required";
                          });
                        } else if (!EmailValidator.validate(email.text)) {
                          setState(() {
                            emailerror = true;
                            emailmessage = "Email is not valid";
                          });
                        } else {
                          setState(() {
                            emailerror = false;
                            //firstnamemessage = "Firstname is required";
                          });
                        }
                      });
                      if (!emailerror) {
                        // If email is valid, send OTP
                        submitEmail();
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
                                      "Submit",
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: MediaQuery.of(context)
                                                  .size
                                                  .width *
                                              0.045),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.02,
            ),
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.01,
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
                                MediaQuery.of(context).size.width * 0.045),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.01,
            ),
          ],
        ),
      ),
    );
  }
}

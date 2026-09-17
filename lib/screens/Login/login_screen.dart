// import 'dart:convert';
//
// import 'package:email_validator/email_validator.dart';
// import 'package:flutter/cupertino.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/widgets.dart';
// import 'package:flutter_spinkit/flutter_spinkit.dart';
// import 'package:fluttertoast/fluttertoast.dart';
// import 'package:font_awesome_flutter/font_awesome_flutter.dart';
// import 'package:intl/intl.dart';
// import 'package:provider/provider.dart';
// import 'package:shared_preferences/shared_preferences.dart';
//
// import 'package:three_zero_two_property/screens/Signup/signup_screen.dart';
// import 'package:http/http.dart' as http;
import 'package:three_zero_two_property/services/app_log.dart';
import 'package:three_zero_two_property/services/api_helpers.dart';
//
// import '../../StaffModule/repository/staffpermission_provider.dart';
// import '../../StaffModule/screen/dashboard.dart';
// import '../../TenantsModule/repository/permission_provider.dart';
// import '../../TenantsModule/screen/dashboard.dart';
// import '../../VendorModule/repository/vendor_permission.dart';
// import '../../VendorModule/screen/mainScreen.dart';
// import '../../constant/constant.dart';
// import '../../provider/Plan Purchase/plancheckProvider.dart';
// import '../../provider/dateProvider.dart';
// import '../Dashboard/dashboard_one.dart';
// import '../Password/forgotpassword.dart';
// import '../Plans/PlansPurcharCard.dart';
//
// class Login_Screen extends StatefulWidget {
//   const Login_Screen({super.key});
//
//   @override
//   State<Login_Screen> createState() => _Login_ScreenState();
// }
//
// class _Login_ScreenState extends State<Login_Screen> {
//   TextEditingController password = TextEditingController();
//   TextEditingController company = TextEditingController();
//   TextEditingController email = TextEditingController();
//   TextEditingController twoFA = TextEditingController();
//
//   bool passworderror = false;
//   bool visiable_password = true;
//   bool emailerror = false;
//   bool companyerror = false;
//   bool roleerror = false;
//   bool required2FA = false;
//
//   bool requires2FA = false;
//   bool backupcode = false;
//   bool timerStart = false;
//   bool switchtoBackupcode = false;
//
//   String OtpId = "";
//
//   String _email = '';
//   bool _isEmailSubmitted = false;
//   bool _hasMultipleCompanies = false;
//   bool loading = false;
//   List<Map<String, String>> _companies = [];
//   String _selectedCompany = '';
//   String _password = '';
//   String selectedrole = '';
//   String passwordmessage = "";
//   String companymessage = "";
//   String emailmessage = "";
//   String rolemessage = "";
//   String required2FAmessage = "";
//   String twoFAMessage = "";
//   // String get email => _email;
//   bool get isEmailSubmitted => _isEmailSubmitted;
//   bool get hasMultipleCompanies => _hasMultipleCompanies;
//   List<Map<String, String>> get companies => _companies;
//   String get selectedCompany => _selectedCompany;
//   // String get password => _password;
//   String? adminId;
//   String? userId;
//   String? userName;
//   void setEmail(String email) {
//     print(email);
//     setState(() {
//       if (_email != email) {
//         _email = email;
//         _isEmailSubmitted = false;
//         _hasMultipleCompanies = false;
//         _companies = [];
//         _selectedCompany = '';
//         _password = '';
//       }
//     });
//   }
//
//   void selectCompany(String company, String role, String admin_id,
//       String user_id, String userName) {
//     _selectedCompany = company;
//     selectedrole = role;
//     adminId = admin_id;
//     userId = user_id;
//     userName = userName;
//     // Set role when selecting company
//     print(selectedrole);
//     print(admin_id);
//     print(selectedCompany);
//     print(userId);
//     setState(() {});
//   }
//
//   void login() {
//     // Implement login logic here
//     print(
//         'Logging in with email: $_email, company: $_selectedCompany, password: $_password');
//   }
//
//   void setPassword(String password) {
//     _password = password;
//   }
//
//   // Helper function to format error messages for better user experience
//   String _formatErrorMessage(String apiMessage) {
//     // Convert technical error messages to user-friendly ones
//     if (apiMessage.toLowerCase().contains('invalid') &&
//         (apiMessage.toLowerCase().contains('password') ||
//             apiMessage.toLowerCase().contains('admin'))) {
//       return "Login failed. Please check your credentials.";
//     }
//     if (apiMessage.toLowerCase().contains('email') &&
//         apiMessage.toLowerCase().contains('not found')) {
//       return "Email address not found.";
//     }
//     if (apiMessage.toLowerCase().contains('account') &&
//         apiMessage.toLowerCase().contains('disabled')) {
//       return "Your account has been disabled. Please contact support.";
//     }
//     if (apiMessage.toLowerCase().contains('network') ||
//         apiMessage.toLowerCase().contains('connection')) {
//       return "Network error. Please check your connection and try again.";
//     }
//     // Return the original message if no specific formatting is needed
//     return apiMessage;
//   }
//
//   Future<void> submitEmail() async {
//     print("Calling  ${email.text}");
//     // Make API call to check email
//     final response = await apiPost(
//       Uri.parse('$Api_url/api/auth/check_role'),
//       // Uri.parse('$Api_url/api/admin/check_role'),
//       headers: {'Content-Type': 'application/json'},
//       body: jsonEncode({'email': email.text.trim()}),
//     );
//     print(response.body);
//     if (response.statusCode == 200) {
//       final data = jsonDecode(response.body);
//       List<dynamic> roles = data['data'];
//       print(roles.length);
//       if (roles.isEmpty) {
//         Fluttertoast.showToast(msg: "Email address not found.");
//       } else {
//         if (roles.length > 1) {
//           setState(() {
//             _hasMultipleCompanies = true;
//             _companies = roles
//                 .map<Map<String, String>>((role) => {
//               'company': role['company_name'],
//               'role': role['role'],
//               'admin_id': role['admin_id'],
//               'user_id': role['user_id'],
//               'userName': role['userName'],
//             })
//                 .toList();
//             print("roles $roles");
//             _isEmailSubmitted = true;
//           });
//         } else {
//           setState(() {
//             if (roles[0]['role'] == "admin") {
//               _hasMultipleCompanies = false;
//               adminId = roles[0]["admin_id"];
//               userId = roles[0]["user_id"];
//               userName = roles[0]["userName"];
//
//               //_selectedCompany = roles[0]['company_name'];
//               selectedrole = roles[0]['role']; // Set role directly
//               _isEmailSubmitted = true;
//             } else {
//               print(roles[0]['role']);
//               _hasMultipleCompanies = false;
//               adminId = roles[0]["admin_id"];
//               _selectedCompany = roles[0]['company_name'];
//               userId = roles[0]["user_id"];
//               userName = roles[0]["userName"];
//               print(userId);
//               selectedrole = roles[0]['role']; // Set role directly
//               _isEmailSubmitted = true;
//             }
//           });
//         }
//       }
//     } else {
//       Fluttertoast.showToast(msg: "Email address not found.");
//     }
//   }
//
//   bool isChecked = false;
//   bool rememberMe = false;
//
//   @override
//   void initState() {
//     super.initState();
//     _loadSavedCredentials();
//   }
//
//   // Load saved credentials if Remember Me was previously enabled
//   Future<void> _loadSavedCredentials() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     bool? savedRememberMe = prefs.getBool('rememberMe');
//     String? savedEmail = prefs.getString('savedEmail');
//     String? savedPassword = prefs.getString('savedPassword');
//
//     print('🔍 Loading saved credentials:');
//     print('   rememberMe: $savedRememberMe');
//     print('   savedEmail: $savedEmail');
//     print('   savedPassword: ${savedPassword != null ? '***' : 'null'}');
//
//     if (savedRememberMe == true &&
//         savedEmail != null &&
//         savedPassword != null) {
//       print('✅ Auto-filling credentials and submitting email');
//       setState(() {
//         rememberMe = true;
//         isChecked = true;
//         email.text = savedEmail;
//         password.text = savedPassword;
//         // Auto-submit email to check for roles
//         submitEmail();
//       });
//     } else {
//       print('❌ No saved credentials found or Remember Me not enabled');
//     }
//   }
//
//   // Save credentials to SharedPreferences
//   Future<void> _saveCredentials() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     if (rememberMe) {
//       print('Saving credentials for Remember Me');
//       await prefs.setBool('rememberMe', true);
//       await prefs.setString('savedEmail', email.text.trim());
//       await prefs.setString('savedPassword', password.text.trim());
//       print('Credentials saved successfully');
//     } else {
//       print('Clearing Remember Me credentials');
//       await prefs.setBool('rememberMe', false);
//       await prefs.remove('savedEmail');
//       await prefs.remove('savedPassword');
//     }
//   }
//
//   // Clear saved credentials (call this on logout if needed)
//   static Future<void> clearSavedCredentials() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     await prefs.setBool('rememberMe', false);
//     await prefs.remove('savedEmail');
//     await prefs.remove('savedPassword');
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.white,
//       body: Padding(
//           padding: const EdgeInsets.all(0.0),
//           child: LayoutBuilder(builder: (context, contraints) {
//             if (contraints.maxWidth > 500) {
//               return Column(
//                 crossAxisAlignment: CrossAxisAlignment.center,
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   SizedBox(
//                     height: MediaQuery.of(context).size.height * 0.1,
//                   ),
//                   Image(
//                     image: const AssetImage('assets/images/logo.png'),
//                     height: MediaQuery.of(context).size.height * 0.07,
//                     width: MediaQuery.of(context).size.width * 0.9,
//                     fit: BoxFit.fill,
//                   ),
//                   SizedBox(
//                     height: MediaQuery.of(context).size.height * 0.025,
//                   ),
//                   // // Welcome
//                   // Center(
//                   //   child: Text(
//                   //     "Welcome to CRM",
//                   //     style: TextStyle(
//                   //       color: Colors.black,
//                   //       fontWeight: FontWeight.bold,
//                   //       fontSize: MediaQuery.of(context).size.width * 0.04,
//                   //     ),
//                   //   ),
//                   // ),
//                   // SizedBox(
//                   //   height: MediaQuery.of(context).size.height * 0.02,
//                   // ),
//                   // Login text
//                   Center(
//                     child: Text(
//                       "Sign In",
//                       style: TextStyle(
//                           color: Colors.black,
//                           fontWeight: FontWeight.bold,
//                           fontSize: MediaQuery.of(context).size.width * 0.046),
//                     ),
//                   ),
//                   SizedBox(
//                     height: MediaQuery.of(context).size.height * 0.05,
//                   ),
//
//                   SizedBox(
//                     height: MediaQuery.of(context).size.height * 0.01,
//                   ),
//                   // Email
//                   Row(
//                     children: [
//                       SizedBox(
//                         width: MediaQuery.of(context).size.width * 0.099,
//                       ),
//                       Expanded(
//                         flex: 1,
//                         child: Container(
//                           height: 60,
//                           decoration: BoxDecoration(
//                             borderRadius: BorderRadius.circular(10),
//                             color: const Color.fromRGBO(196, 196, 196, .3),
//                           ),
//                           child: Stack(
//                             children: [
//                               Positioned.fill(
//                                 child: TextField(
//                                   keyboardType: TextInputType.emailAddress,
//                                   onChanged: (value) {
//                                     setState(() {
//                                       emailerror = false;
//                                       _isEmailSubmitted = false;
//                                       _hasMultipleCompanies = false;
//                                       password.clear();
//                                     });
//                                   },
//                                   style: const TextStyle(fontSize: 20),
//                                   controller: email,
//                                   cursorColor: blueColor,
//                                   decoration: InputDecoration(
//                                     enabledBorder: emailerror
//                                         ? OutlineInputBorder(
//                                       borderRadius:
//                                       BorderRadius.circular(10),
//                                       borderSide: const BorderSide(
//                                           color: Colors
//                                               .red), // Set border color here
//                                     )
//                                         : InputBorder.none,
//                                     border: InputBorder.none,
//                                     contentPadding: const EdgeInsets.all(14),
//                                     prefixIcon: Container(
//                                       height: 25,
//                                       width: 25,
//                                       padding: const EdgeInsets.all(13),
//                                       child: FaIcon(
//                                         FontAwesomeIcons.envelope,
//                                         size: 25,
//                                         color: Colors.grey[600],
//                                       ),
//                                     ),
//                                     hintText: "Email Address",
//                                     hintStyle: TextStyle(
//                                         color: Colors.grey[600], fontSize: 20),
//                                   ),
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),
//                       ),
//                       SizedBox(
//                         width: MediaQuery.of(context).size.width * 0.095,
//                       ),
//                     ],
//                   ),
//                   emailerror
//                       ? Center(
//                       child: Text(
//                         emailmessage,
//                         style: const TextStyle(
//                           color: Colors.red,
//                         ),
//                       ))
//                       : Container(),
//
//                   SizedBox(
//                     height: MediaQuery.of(context).size.height * 0.025,
//                   ),
//                   if (!isEmailSubmitted)
//                     Column(
//                       children: [
//                         Column(
//                           children: [
//                             Row(
//                               mainAxisAlignment: MainAxisAlignment.end,
//                               children: [
//                                 GestureDetector(
//                                   onTap: () {
//                                     Navigator.push(
//                                         context,
//                                         MaterialPageRoute(
//                                             builder: (context) =>
//                                             const ForgotPassword()));
//                                   },
//                                   child: Text(
//                                     "Forgot password?",
//                                     style: TextStyle(
//                                         fontWeight: FontWeight.bold,
//                                         fontSize:
//                                         MediaQuery.of(context).size.width *
//                                             0.02,
//                                         color: const Color(0xFF152B51)),
//                                   ),
//                                 ),
//                                 SizedBox(
//                                   width:
//                                   MediaQuery.of(context).size.width * 0.099,
//                                 ),
//                               ],
//                             ),
//                             SizedBox(
//                               height:
//                               MediaQuery.of(context).size.height * 0.025,
//                             ),
//                           ],
//                         ),
//                         SizedBox(
//                           height: MediaQuery.of(context).size.height * 0.035,
//                         ),
//                         InkWell(
//                           onTap: () {
//                             if (email.text.isEmpty) {
//                               setState(() {
//                                 emailerror = true;
//                                 emailmessage = "Email is required";
//                               });
//                             } else if (!EmailValidator.validate(email.text)) {
//                               setState(() {
//                                 emailerror = true;
//                                 emailmessage = "Email is not valid";
//                               });
//                             } else {
//                               setState(() {
//                                 emailerror = false;
//                                 //firstnamemessage = "Firstname is required";
//                               });
//                               submitEmail();
//                             }
//                           },
//                           child: Center(
//                             child: Container(
//                               height: MediaQuery.of(context).size.height * 0.05,
//                               width: MediaQuery.of(context).size.width * 0.8,
//                               decoration: BoxDecoration(
//                                 color: blueColor,
//                                 borderRadius: BorderRadius.circular(10),
//                               ),
//                               child: Center(
//                                 child: loading
//                                     ? const SpinKitFadingCircle(
//                                   color: Colors.white,
//                                   size: 40.0,
//                                 )
//                                     : Row(
//                                   mainAxisAlignment:
//                                   MainAxisAlignment.center,
//                                   children: [
//                                     Text(
//                                       "Submit",
//                                       style: TextStyle(
//                                           color: Colors.white,
//                                           fontWeight: FontWeight.bold,
//                                           fontSize: MediaQuery.of(context)
//                                               .size
//                                               .width *
//                                               0.03),
//                                     ),
//                                   ],
//                                 ),
//                               ),
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//
//                   if (isEmailSubmitted)
//                     Column(
//                       mainAxisAlignment: MainAxisAlignment.center,
//                       crossAxisAlignment: CrossAxisAlignment.center,
//                       children: [
//                         Row(
//                           children: [
//                             SizedBox(
//                               width: MediaQuery.of(context).size.width * 0.099,
//                             ),
//                             Expanded(
//                               flex: 1,
//                               child: Container(
//                                 height: 60,
//                                 decoration: BoxDecoration(
//                                   borderRadius: BorderRadius.circular(10),
//                                   color:
//                                   const Color.fromRGBO(196, 196, 196, .3),
//                                 ),
//                                 child: Stack(
//                                   children: [
//                                     Positioned.fill(
//                                       child: TextField(
//                                         keyboardType: TextInputType.text,
//                                         onChanged: (value) {
//                                           setState(() {
//                                             passworderror = false;
//                                           });
//                                         },
//                                         style: const TextStyle(fontSize: 20),
//                                         controller: password,
//                                         obscureText: visiable_password,
//                                         cursorColor: blueColor,
//                                         decoration: InputDecoration(
//                                           enabledBorder: passworderror
//                                               ? OutlineInputBorder(
//                                             borderRadius:
//                                             BorderRadius.circular(10),
//                                             borderSide: const BorderSide(
//                                                 color: Colors
//                                                     .red), // Set border color here
//                                           )
//                                               : InputBorder.none,
//                                           border: InputBorder.none,
//                                           contentPadding:
//                                           const EdgeInsets.all(14),
//                                           prefixIcon: Container(
//                                             height: 25,
//                                             width: 25,
//                                             // color: Colors.blue,
//                                             padding: const EdgeInsets.all(13),
//                                             child: FaIcon(
//                                               FontAwesomeIcons.lock,
//                                               size: 25,
//                                               color: Colors.grey[600],
//                                             ),
//                                           ),
//                                           hintText: "Password",
//                                           hintStyle: TextStyle(
//                                               color: Colors.grey[600],
//                                               fontSize: 20),
//                                           suffixIcon: InkWell(
//                                             onTap: () {
//                                               setState(() {
//                                                 visiable_password =
//                                                 !visiable_password;
//                                               });
//                                             },
//                                             child: Icon(
//                                               visiable_password
//                                                   ? Icons
//                                                   .remove_red_eye_outlined
//                                                   : Icons
//                                                   .visibility_off_outlined,
//                                               color: Colors.grey[600],
//                                             ),
//                                           ),
//                                         ),
//                                       ),
//                                     ),
//                                   ],
//                                 ),
//                               ),
//                             ),
//                             SizedBox(
//                               width: MediaQuery.of(context).size.width * 0.099,
//                             ),
//                           ],
//                         ),
//                         passworderror
//                             ? Center(
//                             child: Text(
//                               passwordmessage,
//                               style: const TextStyle(color: Colors.red),
//                             ))
//                             : Container(),
//                         SizedBox(
//                           height: MediaQuery.of(context).size.height * 0.025,
//                         ),
//                         // Container(
//                         //   color: Colors.orange,
//                         //   height: 120,
//                         //   width: 120,
//                         // ),
//
//                         if (requires2FA) ...[
//                           // Row(
//                           //   children: [
//                           //     SizedBox(
//                           //       width: MediaQuery.of(context).size.width * 0.099,
//                           //     ),
//                           //     Expanded(
//                           //       flex: 1,
//                           //       child: Container(
//                           //         height: 60,
//                           //         decoration: BoxDecoration(
//                           //           borderRadius: BorderRadius.circular(10),
//                           //           color: const Color.fromRGBO(196, 196, 196, .3),
//                           //         ),
//                           //         child: Stack(
//                           //           children: [
//                           //             Positioned.fill(
//                           //               child: TextField(
//                           //                 keyboardType: TextInputType.text,
//                           //                 onChanged: (value) {
//                           //                   setState(() {
//                           //                     required2FA = false;
//                           //                   });
//                           //                 },
//                           //                 style: const TextStyle(fontSize: 20),
//                           //                 controller: password,
//                           //                // obscureText: visiable_password,
//                           //                 cursorColor: blueColor,
//                           //                 decoration: InputDecoration(
//                           //                   enabledBorder: required2FA
//                           //                       ? OutlineInputBorder(
//                           //                     borderRadius:
//                           //                     BorderRadius.circular(10),
//                           //                     borderSide: const BorderSide(
//                           //                         color: Colors
//                           //                             .red), // Set border color here
//                           //                   )
//                           //                       : InputBorder.none,
//                           //                   border: InputBorder.none,
//                           //                   contentPadding: const EdgeInsets.all(14),
//                           //                   prefixIcon: Container(
//                           //                     height: 25,
//                           //                     width: 25,
//                           //                     // color: Colors.blue,
//                           //                     padding: const EdgeInsets.all(13),
//                           //                     child: FaIcon(
//                           //                       FontAwesomeIcons.lock,
//                           //                       size: 25,
//                           //                       color: Colors.grey[600],
//                           //                     ),
//                           //                   ),
//                           //                   hintText: "Enter 6-digit code",
//                           //                   hintStyle: TextStyle(
//                           //                       color: Colors.grey[600],
//                           //                       fontSize: 20),
//                           //                   suffixIcon: InkWell(
//                           //                     onTap: () {
//                           //                       setState(() {
//                           //                         visiable_password =
//                           //                         !visiable_password;
//                           //                       });
//                           //                     },
//                           //                     child: Icon(
//                           //                       visiable_password
//                           //                           ? Icons
//                           //                           .remove_red_eye_outlined
//                           //                           : Icons
//                           //                           .visibility_off_outlined,
//                           //                       color: Colors.grey[600],
//                           //                     ),
//                           //                   ),
//                           //                 ),
//                           //               ),
//                           //             ),
//                           //           ],
//                           //         ),
//                           //       ),
//                           //     ),
//                           //     SizedBox(
//                           //       width: MediaQuery.of(context).size.width * 0.099,
//                           //     ),
//                           //   ],
//                           // ),
//                           // required2FA
//                           //     ? Center(
//                           //     child: Text(
//                           //       required2FAmessage,
//                           //       style: const TextStyle(color: Colors.red),
//                           //     ))
//                           //     : Container(),
//                           // SizedBox(
//                           //   height: MediaQuery.of(context).size.height * 0.025,
//                           // ),
//                         ],
//                         if (hasMultipleCompanies) ...[
//                           SingleSelectionButtons(
//                             buttonOptions: companies,
//                             onSelected: (index) {
//                               setState(() {
//                                 print(companies[index]);
//                                 adminId = companies[index]['admin_id'];
//                                 print(adminId);
//                               });
//                               selectCompany(
//                                   companies[index]["company"]!,
//                                   companies[index]["role"]!,
//                                   companies[index]["admin_id"]!,
//                                   companies[index]["user_id"]!,
//                                   companies[index]["userName"]!);
//                             },
//                           ),
//                         ],
//
//                         SizedBox(
//                           height: MediaQuery.of(context).size.height * 0.015,
//                         ),
//                         // Forgot password
//                         Row(
//                           mainAxisAlignment: MainAxisAlignment.end,
//                           children: [
//                             GestureDetector(
//                               onTap: () {
//                                 Navigator.push(
//                                     context,
//                                     MaterialPageRoute(
//                                         builder: (context) =>
//                                         const ForgotPassword()));
//                               },
//                               child: Text(
//                                 "Forgot password?",
//                                 style: TextStyle(
//                                     fontSize:
//                                     MediaQuery.of(context).size.width *
//                                         0.02,
//                                     color: Colors.blue),
//                               ),
//                             ),
//                             SizedBox(
//                               width: MediaQuery.of(context).size.width * 0.099,
//                             ),
//                           ],
//                         ),
//                         SizedBox(
//                           height: MediaQuery.of(context).size.height * 0.025,
//                         ),
//                         // Login button
//
//                         GestureDetector(
//                           onTap: () async {
//                             setState(() {
//                               if (email.text.isEmpty) {
//                                 setState(() {
//                                   emailerror = true;
//                                   emailmessage = "Email is required";
//                                 });
//                               } else if (!EmailValidator.validate(email.text)) {
//                                 setState(() {
//                                   emailerror = true;
//                                   emailmessage = "Email is not valid";
//                                 });
//                               } else {
//                                 setState(() {
//                                   emailerror = false;
//                                   //firstnamemessage = "Firstname is required";
//                                 });
//                               }
//                               if (password.text.isEmpty) {
//                                 setState(() {
//                                   passworderror = true;
//                                   passwordmessage = "Password is required";
//                                 });
//                               } else {
//                                 setState(() {
//                                   passworderror = false;
//                                   //firstnamemessage = "Firstname is required";
//                                 });
//                               }
//                               if (selectedrole == null) {
//                                 setState(() {
//                                   roleerror = true;
//                                   rolemessage = "Please select the role";
//                                 });
//                               } else {
//                                 setState(() {
//                                   roleerror = false;
//                                   //firstnamemessage = "Firstname is required";
//                                 });
//                               }
//                               if (selectedrole != "1" &&
//                                   selectedrole != null &&
//                                   company.text.isEmpty) {
//                                 setState(() {
//                                   companyerror = true;
//                                   companymessage = "Company Name is required";
//                                 });
//                               } else {
//                                 setState(() {
//                                   companyerror = false;
//                                   //firstnamemessage = "Firstname is required";
//                                 });
//                               }
//                             });
//                             if (selectedrole == "") {
//                               Fluttertoast.showToast(
//                                   msg: "Please select the company");
//                             } else if (emailerror == false &&
//                                 passworderror == false) {
//                               if (selectedrole == "admin") await loginsubmit();
//                               if (selectedrole != "admin")
//                                 await checkCompany(selectedCompany);
//                             }
//                           },
//                           child: Center(
//                             child: Container(
//                               height:
//                               MediaQuery.of(context).size.height * 0.045,
//                               width: MediaQuery.of(context).size.width * 0.8,
//                               decoration: BoxDecoration(
//                                 color: const Color(0xFF152B51),
//                                 borderRadius: BorderRadius.circular(10),
//                               ),
//                               child: Center(
//                                 child: loading
//                                     ? const SpinKitFadingCircle(
//                                   color: Colors.white,
//                                   size: 40.0,
//                                 )
//                                     : Row(
//                                   mainAxisAlignment:
//                                   MainAxisAlignment.center,
//                                   children: [
//                                     Text(
//                                       "Login",
//                                       style: TextStyle(
//                                           color: Colors.white,
//                                           fontWeight: FontWeight.bold,
//                                           fontSize: MediaQuery.of(context)
//                                               .size
//                                               .width *
//                                               0.03),
//                                     ),
//                                     // SizedBox(
//                                     //   height: MediaQuery.of(context)
//                                     //           .size
//                                     //           .width *
//                                     //       0.015,
//                                     // ),
//                                     // Icon(
//                                     //   Icons.arrow_forward_ios_sharp,
//                                     //   color: Colors.white,
//                                     //   size: MediaQuery.of(context)
//                                     //           .size
//                                     //           .width *
//                                     //       0.03,
//                                     // ),
//                                   ],
//                                 ),
//                               ),
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//
//                   // Register now
//                   SizedBox(
//                     height: MediaQuery.of(context).size.height * 0.04,
//                   ),
//                   Row(
//                     mainAxisAlignment: MainAxisAlignment.center,
//                     children: [
//                       Text(
//                         "Don't have an account ? ",
//                         style: TextStyle(
//                             color: const Color(0xFF152B51),
//                             fontSize: MediaQuery.of(context).size.width * 0.03),
//                       ),
//                       GestureDetector(
//                         onTap: () {
//                           Navigator.push(
//                               context,
//                               MaterialPageRoute(
//                                   builder: (context) => Signup()));
//                         },
//                         child: Container(
//                           child: Text(
//                             "Register now",
//                             style: TextStyle(
//                                 fontWeight: FontWeight.bold,
//                                 color: const Color(0xFF152B51),
//                                 fontSize:
//                                 MediaQuery.of(context).size.width * 0.03),
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                   SizedBox(
//                     height: MediaQuery.of(context).size.height * 0.04,
//                   ),
//                   // SizedBox(
//                   //   height: MediaQuery.of(context).size.height * 0.1,
//                   // ),
//                 ],
//               );
//             }
//
//             return SingleChildScrollView(
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.center,
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   if (!isEmailSubmitted &&
//                       MediaQuery.of(context).size.height > 700 &&
//                       hasMultipleCompanies)
//                     SizedBox(
//                       height: MediaQuery.of(context).size.height * 0.25,
//                     ),
//                   if (isEmailSubmitted &&
//                       MediaQuery.of(context).size.height > 700 &&
//                       !hasMultipleCompanies)
//                     SizedBox(
//                       height: MediaQuery.of(context).size.height * 0.15,
//                     ),
//                   if (!isEmailSubmitted &&
//                       MediaQuery.of(context).size.height > 700)
//                     SizedBox(
//                       height: MediaQuery.of(context).size.height * 0.15,
//                     ),
//                   if (MediaQuery.of(context).size.height < 670)
//                     SizedBox(
//                       height: MediaQuery.of(context).size.height * 0.1,
//                     ),
//                   SizedBox(
//                     height: MediaQuery.of(context).size.height * 0.1,
//                   ),
//                   Image(
//                     image: const AssetImage('assets/images/logo.png'),
//                     height: MediaQuery.of(context).size.height * 0.05,
//                     width: MediaQuery.of(context).size.width * 0.9,
//                   ),
//                   SizedBox(
//                     height: MediaQuery.of(context).size.height * 0.025,
//                   ),
//                   // // Welcome
//                   // Center(
//                   //   child: Text(
//                   //     "Welcome to CRM",
//                   //     style: TextStyle(
//                   //       color: Colors.black,
//                   //       fontWeight: FontWeight.bold,
//                   //       fontSize: MediaQuery.of(context).size.width * 0.05,
//                   //     ),
//                   //   ),
//                   // ),
//                   // SizedBox(
//                   //   height: MediaQuery.of(context).size.height * 0.02,
//                   // ),
//                   // Login text
//                   Center(
//                     child: Text(
//                       "Sign In",
//                       style: TextStyle(
//                           color: Colors.black,
//                           fontWeight: FontWeight.bold,
//                           fontSize: MediaQuery.of(context).size.width * 0.046),
//                     ),
//                   ),
//                   SizedBox(
//                     height: MediaQuery.of(context).size.height * 0.05,
//                   ),
//
//                   SizedBox(
//                     height: MediaQuery.of(context).size.height * 0.025,
//                   ),
//                   // Email
//                   Row(
//                     children: [
//                       SizedBox(
//                         width: MediaQuery.of(context).size.width * 0.099,
//                       ),
//                       Expanded(
//                         flex: 1,
//                         child: Container(
//                           height: 50,
//                           decoration: BoxDecoration(
//                             borderRadius: BorderRadius.circular(10),
//                             color: const Color.fromRGBO(196, 196, 196, .3),
//                           ),
//                           child: Stack(
//                             children: [
//                               Positioned.fill(
//                                 child: TextField(
//                                   keyboardType: TextInputType.emailAddress,
//                                   onChanged: (value) {
//                                     setState(() {
//                                       emailerror = false;
//                                       _isEmailSubmitted = false;
//                                       _hasMultipleCompanies = false;
//                                       password.clear();
//                                     });
//                                   },
//                                   controller: email,
//                                   cursorColor: blueColor,
//                                   decoration: InputDecoration(
//                                     enabledBorder: emailerror
//                                         ? OutlineInputBorder(
//                                       borderRadius:
//                                       BorderRadius.circular(10),
//                                       borderSide: const BorderSide(
//                                           color: Colors
//                                               .red), // Set border color here
//                                     )
//                                         : InputBorder.none,
//                                     border: InputBorder.none,
//                                     contentPadding: const EdgeInsets.all(14),
//                                     prefixIcon: Container(
//                                       height: 20,
//                                       width: 20,
//                                       padding: const EdgeInsets.all(13),
//                                       child: FaIcon(
//                                         FontAwesomeIcons.envelope,
//                                         size: 20,
//                                         color: Colors.grey[600],
//                                       ),
//                                     ),
//                                     hintText: "Email Address",
//                                     hintStyle: TextStyle(
//                                         color: Colors.grey[600], fontSize: 15),
//                                   ),
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),
//                       ),
//                       SizedBox(
//                         width: MediaQuery.of(context).size.width * 0.095,
//                       ),
//                     ],
//                   ),
//                   emailerror
//                       ? Center(
//                       child: Text(
//                         emailmessage,
//                         style: const TextStyle(
//                           color: Colors.red,
//                         ),
//                       ))
//                       : Container(),
//
//                   SizedBox(
//                     height: MediaQuery.of(context).size.height * 0.025,
//                   ),
//                   if (!isEmailSubmitted)
//                     Column(
//                       children: [
//                         Column(
//                           children: [
//                             Row(
//                               mainAxisAlignment: MainAxisAlignment.end,
//                               children: [
//                                 GestureDetector(
//                                   onTap: () {
//                                     Navigator.push(
//                                         context,
//                                         MaterialPageRoute(
//                                             builder: (context) =>
//                                             const ForgotPassword()));
//                                   },
//                                   child: Text(
//                                     "Forgot password?",
//                                     style: TextStyle(
//                                         fontWeight: FontWeight.bold,
//                                         fontSize:
//                                         MediaQuery.of(context).size.width *
//                                             0.035,
//                                         color: const Color(0xFF152B51)),
//                                   ),
//                                 ),
//                                 SizedBox(
//                                   width:
//                                   MediaQuery.of(context).size.width * 0.099,
//                                 ),
//                               ],
//                             ),
//                             SizedBox(
//                               height:
//                               MediaQuery.of(context).size.height * 0.025,
//                             ),
//                           ],
//                         ),
//                         SizedBox(
//                           height: MediaQuery.of(context).size.height * 0.035,
//                         ),
//                         InkWell(
//                           onTap: () {
//                             if (email.text.trim().isEmpty) {
//                               setState(() {
//                                 emailerror = true;
//                                 emailmessage = "Email is required";
//                               });
//                             } else if (!EmailValidator.validate(
//                                 email.text.trim())) {
//                               setState(() {
//                                 emailerror = true;
//                                 emailmessage = "Email is not valid";
//                               });
//                             } else {
//                               setState(() {
//                                 emailerror = false;
//                                 //firstnamemessage = "Firstname is required";
//                               });
//                               submitEmail();
//                             }
//                           },
//                           child: Center(
//                             child: Container(
//                               height: MediaQuery.of(context).size.height * 0.06,
//                               width: MediaQuery.of(context).size.width * 0.8,
//                               decoration: BoxDecoration(
//                                 //color: Color(0xFF7A8AA0),
//                                 color: blueColor,
//                                 borderRadius: BorderRadius.circular(10),
//                               ),
//                               child: Center(
//                                 child: loading
//                                     ? const SpinKitFadingCircle(
//                                   color: Colors.white,
//                                   size: 40.0,
//                                 )
//                                     : Row(
//                                   mainAxisAlignment:
//                                   MainAxisAlignment.center,
//                                   children: [
//                                     Text(
//                                       "Submit",
//                                       style: TextStyle(
//                                           color: Colors.white,
//                                           fontWeight: FontWeight.bold,
//                                           fontSize: MediaQuery.of(context)
//                                               .size
//                                               .width *
//                                               0.045),
//                                     ),
//                                   ],
//                                 ),
//                               ),
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//                   if (isEmailSubmitted)
//                     Column(
//                       mainAxisAlignment: MainAxisAlignment.center,
//                       crossAxisAlignment: CrossAxisAlignment.center,
//                       children: [
//                         Row(
//                           children: [
//                             SizedBox(
//                               width: MediaQuery.of(context).size.width * 0.099,
//                             ),
//                             Expanded(
//                               flex: 1,
//                               child: Container(
//                                 height: 50,
//                                 decoration: BoxDecoration(
//                                   borderRadius: BorderRadius.circular(10),
//                                   color:
//                                   const Color.fromRGBO(196, 196, 196, .3),
//                                 ),
//                                 child: Stack(
//                                   children: [
//                                     Positioned.fill(
//                                       child: TextField(
//                                         keyboardType: TextInputType.text,
//                                         onChanged: (value) {
//                                           setState(() {
//                                             passworderror = false;
//                                           });
//                                         },
//                                         controller: password,
//                                         obscureText: visiable_password,
//                                         cursorColor: blueColor,
//                                         decoration: InputDecoration(
//                                           enabledBorder: passworderror
//                                               ? OutlineInputBorder(
//                                             borderRadius:
//                                             BorderRadius.circular(10),
//                                             borderSide: const BorderSide(
//                                                 color: Colors
//                                                     .red), // Set border color here
//                                           )
//                                               : InputBorder.none,
//                                           border: InputBorder.none,
//                                           contentPadding:
//                                           const EdgeInsets.all(14),
//                                           prefixIcon: Container(
//                                             height: 20,
//                                             width: 20,
//                                             // color: Colors.blue,
//                                             padding: const EdgeInsets.all(13),
//                                             child: FaIcon(
//                                               FontAwesomeIcons.lock,
//                                               size: 20,
//                                               color: Colors.grey[600],
//                                             ),
//                                           ),
//                                           hintText: "Password",
//                                           hintStyle: TextStyle(
//                                               color: Colors.grey[600],
//                                               fontSize: 15),
//                                           suffixIcon: InkWell(
//                                             onTap: () {
//                                               setState(() {
//                                                 visiable_password =
//                                                 !visiable_password;
//                                               });
//                                             },
//                                             child: Icon(
//                                               visiable_password
//                                                   ? Icons
//                                                   .remove_red_eye_outlined
//                                                   : Icons
//                                                   .visibility_off_outlined,
//                                               color: Colors.grey[600],
//                                             ),
//                                           ),
//                                         ),
//                                       ),
//                                     ),
//                                   ],
//                                 ),
//                               ),
//                             ),
//                             SizedBox(
//                               width: MediaQuery.of(context).size.width * 0.099,
//                             ),
//                           ],
//                         ),
//                         passworderror
//                             ? Center(
//                             child: Text(
//                               passwordmessage,
//                               style: const TextStyle(color: Colors.red),
//                             ))
//                             : Container(),
//                         SizedBox(
//                           height: MediaQuery.of(context).size.height * 0.012,
//                         ),
//                         Row(
//                           children: [
//                             SizedBox(
//                               width: MediaQuery.of(context).size.width * 0.099,
//                             ),
//                             // Checkbox
//                             Container(
//                               height:
//                               MediaQuery.of(context).size.height * 0.035,
//                               width: MediaQuery.of(context).size.height * 0.035,
//                               decoration: BoxDecoration(
//                                 color: Colors.white,
//                                 borderRadius: BorderRadius.circular(5),
//                               ),
//                               child: Checkbox(
//                                 activeColor: blueColor,
//                                 checkColor: Colors.white,
//                                 value: isChecked,
//                                 onChanged: (value) {
//                                   setState(() {
//                                     isChecked = value ?? false;
//                                     rememberMe = value ?? false;
//                                   });
//                                 },
//                               ),
//                             ),
//
//                             SizedBox(
//                                 width:
//                                 MediaQuery.of(context).size.width * 0.02),
//
//                             // Text that wraps
//                             Expanded(
//                               child: Text(
//                                 " Remember Me",
//                                 textAlign: TextAlign.justify,
//                                 style: TextStyle(
//                                   fontWeight: FontWeight.bold,
//                                   fontSize:
//                                   MediaQuery.of(context).size.width * 0.033,
//                                   color: blueColor,
//                                   height: 1.3, //
//                                 ),
//                               ),
//                             ),
//
//                             SizedBox(
//                                 width:
//                                 MediaQuery.of(context).size.width * 0.05),
//                           ],
//                         ),
//                         SizedBox(
//                           height: MediaQuery.of(context).size.height * 0.012,
//                         ),
//                         if (requires2FA) ...[
//                           Row(
//                             children: [
//                               SizedBox(
//                                 width:
//                                 MediaQuery.of(context).size.width * 0.099,
//                               ),
//                               Expanded(
//                                 flex: 1,
//                                 child: Container(
//                                   height: 50,
//                                   decoration: BoxDecoration(
//                                     borderRadius: BorderRadius.circular(10),
//                                     color:
//                                     const Color.fromRGBO(196, 196, 196, .3),
//                                   ),
//                                   child: Stack(
//                                     children: [
//                                       Positioned.fill(
//                                         child: TextField(
//                                           keyboardType: TextInputType.text,
//                                           onChanged: (value) {
//                                             setState(() {
//                                               required2FA = false;
//                                             });
//                                           },
//                                           controller: twoFA,
//                                           // obscureText: visiable_password,
//                                           cursorColor: blueColor,
//                                           decoration: InputDecoration(
//                                             enabledBorder: required2FA
//                                                 ? OutlineInputBorder(
//                                               borderRadius:
//                                               BorderRadius.circular(
//                                                   10),
//                                               borderSide: const BorderSide(
//                                                   color: Colors
//                                                       .red), // Set border color here
//                                             )
//                                                 : InputBorder.none,
//                                             border: InputBorder.none,
//                                             contentPadding:
//                                             const EdgeInsets.all(14),
//                                             // prefixIcon: Container(
//                                             //   height: 20,
//                                             //   width: 20,
//                                             //   // color: Colors.blue,
//                                             //   padding: const EdgeInsets.all(13),
//                                             //   child: FaIcon(
//                                             //     FontAwesomeIcons.lock,
//                                             //     size: 20,
//                                             //     color: Colors.grey[600],
//                                             //   ),
//                                             // ),
//                                             hintText: switchtoBackupcode
//                                                 ? "Enter backup code"
//                                                 : "Enter 6 digit code",
//                                             hintStyle: TextStyle(
//                                                 color: Colors.grey[600],
//                                                 fontSize: 15),
//
//                                             // suffixIcon: InkWell(
//                                             //   onTap: () {
//                                             //     setState(() {
//                                             //       visiable_password =
//                                             //       !visiable_password;
//                                             //     });
//                                             //   },
//                                             //   child: Icon(
//                                             //     visiable_password
//                                             //         ? Icons
//                                             //         .remove_red_eye_outlined
//                                             //         : Icons
//                                             //         .visibility_off_outlined,
//                                             //     color: Colors.grey[600],
//                                             //   ),
//                                             // ),
//                                           ),
//                                         ),
//                                       ),
//                                     ],
//                                   ),
//                                 ),
//                               ),
//                               SizedBox(
//                                 width:
//                                 MediaQuery.of(context).size.width * 0.099,
//                               ),
//                             ],
//                           ),
//                           required2FA
//                               ? Center(
//                               child: Text(
//                                 required2FAmessage,
//                                 style: const TextStyle(color: Colors.red),
//                               ))
//                               : Container(),
//
//                           if (backupcode) ...[
//                             SizedBox(
//                               height: 10,
//                             ),
//                             if (!switchtoBackupcode)
//                               GestureDetector(
//                                 onTap: () {
//                                   setState(() {
//                                     switchtoBackupcode = !switchtoBackupcode;
//                                   });
//                                 },
//                                 child: Row(
//                                   mainAxisAlignment: MainAxisAlignment.end,
//                                   children: [
//                                     Text(
//                                       "Use backup code instead",
//                                       style: TextStyle(
//                                         fontSize:
//                                         MediaQuery.of(context).size.width *
//                                             0.035,
//                                         color: const Color(0xFF152B51),
//                                         fontWeight: FontWeight.bold,
//                                       ),
//                                     ),
//                                     SizedBox(
//                                       width: MediaQuery.of(context).size.width *
//                                           0.099,
//                                     ),
//                                   ],
//                                 ),
//                               ),
//                             if (switchtoBackupcode)
//                               GestureDetector(
//                                 onTap: () {
//                                   setState(() {
//                                     switchtoBackupcode = !switchtoBackupcode;
//                                   });
//                                 },
//                                 child: Row(
//                                   mainAxisAlignment: MainAxisAlignment.end,
//                                   children: [
//                                     Text(
//                                       "Use OTP instead",
//                                       style: TextStyle(
//                                         fontSize:
//                                         MediaQuery.of(context).size.width *
//                                             0.035,
//                                         color: const Color(0xFF152B51),
//                                         fontWeight: FontWeight.bold,
//                                       ),
//                                     ),
//                                     SizedBox(
//                                       width: MediaQuery.of(context).size.width *
//                                           0.099,
//                                     ),
//                                   ],
//                                 ),
//                               )
//                           ],
//                           SizedBox(
//                             height: MediaQuery.of(context).size.height * 0.025,
//                           ),
//                           // Row(
//                           //   children: [
//                           //     SizedBox(
//                           //       width: MediaQuery.of(context).size.width * 0.099,
//                           //     ),
//                           //     Expanded(
//                           //       flex: 1,
//                           //       child: Container(
//                           //         height: 60,
//                           //         decoration: BoxDecoration(
//                           //           borderRadius: BorderRadius.circular(10),
//                           //           color: const Color.fromRGBO(196, 196, 196, .3),
//                           //         ),
//                           //         child: Stack(
//                           //           children: [
//                           //             Positioned.fill(
//                           //               child: TextField(
//                           //                 keyboardType: TextInputType.text,
//                           //                 onChanged: (value) {
//                           //                   setState(() {
//                           //                     required2FA = false;
//                           //                   });
//                           //                 },
//                           //                 style: const TextStyle(fontSize: 20),
//                           //                 controller: password,
//                           //                // obscureText: visiable_password,
//                           //                 cursorColor: blueColor,
//                           //                 decoration: InputDecoration(
//                           //                   enabledBorder: required2FA
//                           //                       ? OutlineInputBorder(
//                           //                     borderRadius:
//                           //                     BorderRadius.circular(10),
//                           //                     borderSide: const BorderSide(
//                           //                         color: Colors
//                           //                             .red), // Set border color here
//                           //                   )
//                           //                       : InputBorder.none,
//                           //                   border: InputBorder.none,
//                           //                   contentPadding: const EdgeInsets.all(14),
//                           //                   prefixIcon: Container(
//                           //                     height: 25,
//                           //                     width: 25,
//                           //                     // color: Colors.blue,
//                           //                     padding: const EdgeInsets.all(13),
//                           //                     child: FaIcon(
//                           //                       FontAwesomeIcons.lock,
//                           //                       size: 25,
//                           //                       color: Colors.grey[600],
//                           //                     ),
//                           //                   ),
//                           //                   hintText: "Enter 6-digit code",
//                           //                   hintStyle: TextStyle(
//                           //                       color: Colors.grey[600],
//                           //                       fontSize: 20),
//                           //                   suffixIcon: InkWell(
//                           //                     onTap: () {
//                           //                       setState(() {
//                           //                         visiable_password =
//                           //                         !visiable_password;
//                           //                       });
//                           //                     },
//                           //                     child: Icon(
//                           //                       visiable_password
//                           //                           ? Icons
//                           //                           .remove_red_eye_outlined
//                           //                           : Icons
//                           //                           .visibility_off_outlined,
//                           //                       color: Colors.grey[600],
//                           //                     ),
//                           //                   ),
//                           //                 ),
//                           //               ),
//                           //             ),
//                           //           ],
//                           //         ),
//                           //       ),
//                           //     ),
//                           //     SizedBox(
//                           //       width: MediaQuery.of(context).size.width * 0.099,
//                           //     ),
//                           //   ],
//                           // ),
//                           // required2FA
//                           //     ? Center(
//                           //     child: Text(
//                           //       required2FAmessage,
//                           //       style: const TextStyle(color: Colors.red),
//                           //     ))
//                           //     : Container(),
//                           // SizedBox(
//                           //   height: MediaQuery.of(context).size.height * 0.025,
//                           // ),
//                         ],
//                         if (hasMultipleCompanies) ...[
//                           SingleSelectionButtons(
//                             buttonOptions: companies,
//                             onSelected: (index) {
//                               setState(() {
//                                 adminId = companies[index]['admin_id'];
//                                 userId = companies[index]['user_id'];
//                               });
//                               print(adminId);
//                               selectCompany(
//                                   companies[index]["company"]!,
//                                   companies[index]["role"]!,
//                                   companies[index]["admin_id"]!,
//                                   companies[index]["user_id"]!,
//                                   companies[index]["userName"]!);
//                             },
//                           ),
//                         ],
//
//                         SizedBox(
//                           height: MediaQuery.of(context).size.height * 0.015,
//                         ),
//                         // Forgot password
//                         Row(
//                           mainAxisAlignment: MainAxisAlignment.end,
//                           children: [
//                             SizedBox(
//                               width: MediaQuery.of(context).size.width * 0.11,
//                             ),
//                             GestureDetector(
//                               onTap: () {
//                                 Navigator.push(
//                                     context,
//                                     MaterialPageRoute(
//                                         builder: (context) =>
//                                         const ForgotPassword()));
//                               },
//                               child: Text(
//                                 "Forgot password?",
//                                 style: TextStyle(
//                                   fontSize:
//                                   MediaQuery.of(context).size.width * 0.035,
//                                   color: const Color(0xFF152B51),
//                                   fontWeight: FontWeight.bold,
//                                 ),
//                               ),
//                             ),
//                             SizedBox(
//                               width: MediaQuery.of(context).size.width * 0.099,
//                             ),
//                           ],
//                         ),
//                         SizedBox(
//                           height: MediaQuery.of(context).size.height * 0.025,
//                         ),
//                         // Login button
//                         GestureDetector(
//                           onTap: () async {
//                             setState(() {
//                               if (email.text.trim().isEmpty) {
//                                 setState(() {
//                                   emailerror = true;
//                                   emailmessage = "Email is required";
//                                 });
//                               } else if (!EmailValidator.validate(
//                                   email.text.trim())) {
//                                 setState(() {
//                                   emailerror = true;
//                                   emailmessage = "Email is not valid";
//                                 });
//                               } else {
//                                 setState(() {
//                                   emailerror = false;
//                                   //firstnamemessage = "Firstname is required";
//                                 });
//                               }
//                               if (password.text.trim().isEmpty) {
//                                 setState(() {
//                                   passworderror = true;
//                                   passwordmessage = "Password is required";
//                                 });
//                               } else {
//                                 setState(() {
//                                   passworderror = false;
//                                   //firstnamemessage = "Firstname is required";
//                                 });
//                               }
//                               if (requires2FA && twoFA.text.trim().isEmpty) {
//                                 setState(() {
//                                   required2FA = true;
//                                   required2FAmessage = "Code is required";
//                                 });
//                               } else {
//                                 setState(() {
//                                   required2FA = false;
//                                   //firstnamemessage = "Firstname is required";
//                                 });
//                               }
//                               if (selectedrole == null) {
//                                 setState(() {
//                                   roleerror = true;
//                                   rolemessage = "Please select the role";
//                                 });
//                               } else {
//                                 setState(() {
//                                   roleerror = false;
//                                   //firstnamemessage = "Firstname is required";
//                                 });
//                               }
//                               if (selectedrole != "1" &&
//                                   selectedrole != null &&
//                                   company.text.isEmpty) {
//                                 setState(() {
//                                   companyerror = true;
//                                   companymessage = "Company Name is required";
//                                 });
//                               } else {
//                                 setState(() {
//                                   companyerror = false;
//                                   //firstnamemessage = "Firstname is required";
//                                 });
//                               }
//                             });
//                             if (selectedrole == "") {
//                               Fluttertoast.showToast(
//                                   msg: "Please select the company");
//                             } else if (emailerror == false &&
//                                 passworderror == false &&
//                                 ((requires2FA && required2FA == false) ||
//                                     !requires2FA)) {
//                               if (requires2FA) await loginsubmitverify2fa();
//                               if (!requires2FA && selectedrole == "admin")
//                                 await loginsubmit();
//                               if (!requires2FA && selectedrole != "admin")
//                                 await checkCompany(selectedCompany);
//                               // Save authentication status to SharedPreferences
//                             }
//                           },
//                           child: Center(
//                             child: Container(
//                               height: MediaQuery.of(context).size.height * 0.06,
//                               width: MediaQuery.of(context).size.width * 0.8,
//                               decoration: BoxDecoration(
//                                 color: const Color(0xFF152B51),
//                                 borderRadius: BorderRadius.circular(10),
//                               ),
//                               child: Center(
//                                 child: loading
//                                     ? const SpinKitFadingCircle(
//                                   color: Colors.white,
//                                   size: 40.0,
//                                 )
//                                     : requires2FA
//                                     ? Row(
//                                   mainAxisAlignment:
//                                   MainAxisAlignment.center,
//                                   children: [
//                                     Text(
//                                       "Verify & Login",
//                                       style: TextStyle(
//                                           color: Colors.white,
//                                           fontWeight: FontWeight.bold,
//                                           fontSize:
//                                           MediaQuery.of(context)
//                                               .size
//                                               .width *
//                                               0.045),
//                                     ),
//                                     // SizedBox(
//                                     //   height: MediaQuery.of(context)
//                                     //           .size
//                                     //           .width *
//                                     //       0.015,
//                                     // ),
//                                     // Icon(
//                                     //   Icons.arrow_forward_ios_sharp,
//                                     //   color: Colors.white,
//                                     //   size: MediaQuery.of(context)
//                                     //           .size
//                                     //           .width *
//                                     //       0.045,
//                                     // ),
//                                   ],
//                                 )
//                                     : Row(
//                                   mainAxisAlignment:
//                                   MainAxisAlignment.center,
//                                   children: [
//                                     Text(
//                                       "Login",
//                                       style: TextStyle(
//                                           color: Colors.white,
//                                           fontWeight: FontWeight.bold,
//                                           fontSize:
//                                           MediaQuery.of(context)
//                                               .size
//                                               .width *
//                                               0.045),
//                                     ),
//                                     // SizedBox(
//                                     //   height: MediaQuery.of(context)
//                                     //           .size
//                                     //           .width *
//                                     //       0.015,
//                                     // ),
//                                     // Icon(
//                                     //   Icons.arrow_forward_ios_sharp,
//                                     //   color: Colors.white,
//                                     //   size: MediaQuery.of(context)
//                                     //           .size
//                                     //           .width *
//                                     //       0.045,
//                                     // ),
//                                   ],
//                                 ),
//                               ),
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//
//                   // Register now
//                   SizedBox(
//                     height: MediaQuery.of(context).size.height * 0.04,
//                   ),
//                   Row(
//                     mainAxisAlignment: MainAxisAlignment.center,
//                     children: [
//                       Text(
//                         "Don't have an account ? ",
//                         style: TextStyle(
//                             color: const Color(0xFF152B51),
//                             fontSize: MediaQuery.of(context).size.width * 0.04),
//                       ),
//                       GestureDetector(
//                         onTap: () {
//                           Navigator.push(
//                               context,
//                               MaterialPageRoute(
//                                   builder: (context) => Signup()));
//                         },
//                         child: Container(
//                           child: Text(
//                             "Register now",
//                             style: TextStyle(
//                                 fontWeight: FontWeight.bold,
//                                 color: const Color(0xFF152B51),
//                                 fontSize:
//                                 MediaQuery.of(context).size.width * 0.037),
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                   SizedBox(
//                     height: MediaQuery.of(context).size.height * 0.04,
//                   ),
//                   // SizedBox(
//                   //   height: MediaQuery.of(context).size.height * 0.1,
//                   // ),
//                 ],
//               ),
//             );
//           })),
//     );
//   }
//
//   Future<void> checkToken(String token) async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     // String? token = prefs.getString('token');
//
//     final response = await apiPost(
//       Uri.parse('${Api_url}/api/auth'),
//       headers: {
//         "authorization": "CRM $token",
//         "id": "CRM $adminId",
//         "Content-Type": "application/json"
//       },
//       body: json.encode({"token": token}),
//     );
//     print(response.body);
//     final jsonData = json.decode(response.body);
//
//     if (jsonData['id'] != "") {
//       print(jsonData);
//       //prefs.setString('checkedToken',jsonData["token"]);
//       String? adminId = jsonData['admin_id'];
//       print(jsonData);
//       String? companyName = jsonData['company_name'];
//
//       print('Admin ID: $adminId');
//       prefs.setString('checkedToken', token);
//       prefs.setString('adminId', adminId!);
//
//       prefs.setString('companyName', companyName!);
//       print('Company Name: $companyName');
//       prefs.setString("role", "Admin");
//       prefs.setString('first_name', jsonData['first_name']);
//       prefs.setString('last_name', jsonData['last_name']);
//       prefs.setString('first_name', jsonData['first_name']);
//
//       prefs.setString('last_name', jsonData['last_name']);
//       prefs.setString('email', jsonData['email']);
//       // prefs.setString('brand_logo', jsonData['brand_logo']);
//       // print("Saved brand logo: ${jsonData['brand_logo']}");
//       // prefs.setString('userid', jsonData['user_id'] ?? "");
//       prefs.setString('password', password.text);
//       // prefs.setString('userid', jsonData['user_id']);
//       String? brandLogo = jsonData['brand_logo'];
//
//       if (brandLogo != null &&
//           brandLogo.isNotEmpty &&
//           brandLogo.startsWith("data:image")) {
//         prefs.setString('brand_logo', brandLogo);
//         print("Saved brand logo.");
//       } else {
//         print("Warning: Brand logo missing or invalid.");
//         prefs.remove('brand_logo'); // Use default in drawer
//         // Optional: block login
//         /*
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Login failed: Invalid brand logo'))
//       );
//       return;
//       */
//       }
//
//       print("user id${userId}");
//       if (!mounted) return;
//
//       await Provider.of<checkPlanPurchaseProiver>(context, listen: false)
//           .fetchPlanPurchaseDetail();
//
//       // Access the expiration date
//       var provider =
//       Provider.of<checkPlanPurchaseProiver>(context, listen: false);
//       var expirationDateString =
//           provider.checkplanpurchaseModel?.data?.expirationDate;
//
//       DateTime? expirationDate;
//       if (expirationDateString != null) {
//         expirationDate = DateFormat('yyyy-MM-dd').parse(expirationDateString);
//       }
//
//       print('Expiration Date: $expirationDate');
//
//       DateTime now = DateTime.now();
//       String currentDate = DateFormat('yyyy-MM-dd').format(now);
//       print(currentDate);
//
//       bool isPlanActive = expirationDate != null && expirationDate.isAfter(now);
//
//       if (isPlanActive) {
//         print('The plan is active.');
//       } else {
//         print('The plan is not active.');
//       }
//       // Refresh DateProvider to load new user's date format preferences
//       await Provider.of<DateProvider>(context, listen: false).loadDateFormat();
//       Navigator.pushReplacement(
//           context,
//           MaterialPageRoute(
//               builder: (context) =>
//               isPlanActive ? Dashboard() : PlanPurchaseCard()));
//     } else {
//       print('Failed to check token');
//     }
//   }
//
//   Future<void> checkTokenStaff(String token) async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     // String? token = prefs.getString('token');
//     print("calling the staff login token");
//     //log();
//     final response = await apiPost(
//       Uri.parse('${Api_url}/api/auth'),
//       headers: {
//         "authorization": "CRM $token",
//         "id": "CRM $adminId",
//         "Content-Type": "application/json"
//       },
//       body: json.encode({"token": token}),
//     );
//     print(response.body);
//     final jsonData = json.decode(response.body);
//     if (jsonData['id'] != "") {
//       print(jsonData);
//       //prefs.setString('checkedToken',jsonData["token"]);
//       // String? adminId = jsonData['data']['admin_id'];
//       // print('Admin ID: $adminId');
//       // await Provider.of<StaffPermissionProvider>(context, listen: false).fetchPermissions();
//       prefs.setString("staff_id", jsonData["staffmember_id"]);
//       prefs.setString("role", "Staffmember");
//       print(jsonData["staffmember_firstName"]);
//       prefs.setString('companyName', selectedCompany!);
//       prefs.setString('checkedToken', token);
//       //  prefs.setString('adminId', adminId!);
//       String stafffirstname = jsonData['staffmember_name'];
//       List<String> firstname = stafffirstname.split(" ");
//       print(firstname);
//       prefs.setString('first_name', firstname.first);
//       prefs.setString('last_name', firstname.length > 1 ? firstname.last : "");
//       prefs.setString('staffemail', jsonData['staffmember_email']);
//       prefs.setString('staffmember_password', password.text);
//       //prefs.setString('user_id', jsonData['user_id']);
//       // String? userId = jsonData['user_id'];
//       await Provider.of<StaffPermissionProvider>(context, listen: false)
//           .fetchPermissions();
//       // Refresh DateProvider to load new user's date format preferences
//       await Provider.of<DateProvider>(context, listen: false).loadDateFormat();
//       Navigator.push(
//           context, MaterialPageRoute(builder: (context) => Dashboard_staff()));
//     } else {
//       print('Failed to check token');
//     }
//   }
//
//   Future<void> checkTokenTenant(String token) async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     // String? token = prefs.getString('token');
//     // List<Map<String,dynamic>> selectedroledata = roles.where((element) => element["role_id"] == selectedRole).toList();
//     // String rolename  =selectedroledata.first["role_name"];
//
//     final response = await apiPost(
//       Uri.parse('${Api_url}/api/auth'),
//       headers: {
//         "authorization": "CRM $token",
//         "id": "CRM $adminId",
//         "Content-Type": "application/json"
//       },
//       body: json.encode({"token": token}),
//     );
//     print(response.body);
//     final jsonData = json.decode(response.body);
//     if (jsonData['id'] != "") {
//       print(jsonData);
//       //prefs.setString('checkedToken',jsonData["token"]);
//       // String? adminId = jsonData['data']['admin_id'];
//       // print('Admin ID: $adminId');
//       prefs.setString("role", "Tenant");
//       prefs.setString('companyName', selectedCompany!);
//       print(jsonData["tenant_firstName"]);
//       prefs.setString("tenant_id", jsonData["tenant_id"]);
//       prefs.setString('checkedToken', token);
//       //  prefs.setString('adminId', adminId!);
//       prefs.setString('first_name', jsonData['tenant_firstName']);
//       prefs.setString('last_name', jsonData['tenant_lastName']);
//       prefs.setString('email', jsonData['tenant_email']);
//       prefs.setString('tenant_password', password.text);
//       //prefs.setString('user_id', jsonData['user_id']);
//       // String? userId = jsonData['user_id'];
//       await Provider.of<PermissionProvider>(context, listen: false)
//           .fetchPermissions();
//       // Refresh DateProvider to load new user's date format preferences
//       await Provider.of<DateProvider>(context, listen: false).loadDateFormat();
//       Navigator.push(context,
//           MaterialPageRoute(builder: (context) => Dashboard_tenants()));
//     } else {
//       print('Failed to check token');
//     }
//   }
//
//   Future<void> checkTokenVendor(String token) async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     // String? token = prefs.getString('token');
//     // List<Map<String,dynamic>> selectedroledata = roles.where((element) => element["role_id"] == selectedRole).toList();
//     // String rolename  =selectedroledata.first["role_name"];
//     // print('${Api_url}/api/${rolename.toLowerCase()}/token_check');
//     final response = await apiPost(
//       Uri.parse('${Api_url}/api/auth'),
//       headers: {
//         "authorization": "CRM $token",
//         "id": "CRM $adminId",
//         "Content-Type": "application/json"
//       },
//       body: json.encode({"token": token}),
//     );
//     print("vendor token ${response.body}");
//     final jsonData = json.decode(response.body);
//     if (jsonData['id'] != "") {
//       print(jsonData);
//       //prefs.setString('checkedToken',jsonData["token"]);
//       // String? adminId = jsonData['data']['admin_id'];
//       // print('Admin ID: $adminId');
//       String stafffirstname = jsonData['vendor_name'];
//       List<String> firstname = stafffirstname.split(" ");
//       print(firstname);
//       await Provider.of<PermissionProvider>(context, listen: false)
//           .fetchPermissions();
//       prefs.setString('first_name', firstname.first);
//       // prefs.setString('last_name', firstname.length > 1 ? firstname[1]: "");
//       prefs.setString('last_name', firstname.length > 1 ? firstname[1] : "");
//       prefs.setString('companyName', selectedCompany!);
//       prefs.setString("role", "Vendor");
//       print(jsonData["vendor_firstName"]);
//       prefs.setString("vendor_id", jsonData["vendor_id"]);
//       prefs.setString('checkedToken', token);
//       //  prefs.setString('user_id', jsonData['user_id']);
//       // String? userId = jsonData['user_id'];
//       //  prefs.setString('adminId', adminId!);
//       // prefs.setString('first_name', jsonData['${rolename.toLowerCase()}_firstName']);
//       // prefs.setString('last_name', jsonData['${rolename.toLowerCase()}_lastName']);
//       prefs.setString('email', jsonData['vendor_email']);
//       prefs.setString('vendor_password', password.text);
//       // prefs.setString('checkedToken', token);
//       //  prefs.setString('adminId', adminId!);
//       await Provider.of<VendorPermission>(context, listen: false)
//           .fetchPermissions();
//       // Refresh DateProvider to load new user's date format preferences
//       await Provider.of<DateProvider>(context, listen: false).loadDateFormat();
//       Navigator.push(
//           context, MaterialPageRoute(builder: (context) => MainScreen()));
//     } else {
//       print('Failed to check token');
//     }
//   }
//
//   Future<void> checkCompany(String token) async {
//     setState(() {
//       loading = true;
//     });
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     // String? token = prefs.getString('token');
//     print("${Uri.parse('${Api_url}/api/admin/check_company/${token}')}");
//     final response = await apiGet(
//       Uri.parse('${Api_url}/api/admin/check_company/${token}'),
//       headers: {
//         // "authorization": "CRM $token",
//         //"id":"CRM $id",
//         "Content-Type": "application/json"
//       },
//       // body: json.encode({"token": token}),
//     );
//     print(response.body);
//     final jsonData = json.decode(response.body);
//     //if (jsonData["data"]['id'] != "") {
//     print(jsonData);
//     if (jsonData["statusCode"] == 200) {
//       //prefs.setString('checkedToken',jsonData["token"]);
//       String? adminId = jsonData['data']['admin_id'];
//       print('Admin ID: $adminId');
//       prefs.setString('checkedToken', token);
//       prefs.setString('adminId', adminId!);
//       // prefs.setString('user_id', jsonData['user_id']);
//       //  String? userId = jsonData['user_id'];
//       loginsubmit_usingrole(adminId);
//     } else {
//       setState(() {
//         loading = false;
//       });
//     }
//   }
//
//   Future<void> loginsubmit_usingrole(String adminId) async {
//     setState(() {
//       loading = true;
//     });
//     // List<Map<String,dynamic>> selectedroledata = roles.where((element) => element["role_id"] == selectedRole).toList();
//
//     // SharedPreferences prefs = await SharedPreferences.getInstance();
//     // String? userid = prefs.getString("user_id");
//     String rolename = selectedrole;
//
//     print("${Api_url}/api/auth/login");
//     print(rolename);
//     // print({"email": email.text, "password": password.text,"admin_id":adminId,"company":company.text});
//     final response =
//     await apiPost(Uri.parse('${Api_url}/api/auth/login'), body: {
//       "email": email.text.trim(),
//       "password": password.text.trim(),
//       "admin_id": adminId,
//       "role": selectedrole == "staff" ? "staffmember" : rolename.toLowerCase(),
//       "company": selectedCompany,
//       "user_id": userId,
//       "rememberMe": rememberMe.toString(),
//     });
//     print(response.body);
//     await backupcodeapicall();
//     final jsonData = json.decode(response.body);
//     if (jsonData["statusCode"] == 200) {
//       print(jsonData);
//       SharedPreferences prefs = await SharedPreferences.getInstance();
//       prefs.setBool('isAuthenticated', true);
//       prefs.setString('token', jsonData["token"]);
//       prefs.setString('adminId', adminId);
//       prefs.setString('userId', userId!);
//
//       // Save credentials if Remember Me is enabled
//       await _saveCredentials();
//
//       print(rolename);
//       if (rolename == "staffmember" || selectedrole == "staff")
//         await checkTokenStaff(jsonData["token"]);
//       if (rolename == "tenant") await checkTokenTenant(jsonData["token"]);
//       if (rolename == "vendor") await checkTokenVendor(jsonData["token"]);
//
//       setState(() {
//         loading = false;
//       });
//     } else {
//       Fluttertoast.showToast(msg: _formatErrorMessage(jsonData["message"]));
//       if (jsonData["statusCode"] == 205) {
//         print("2FA ON");
//         setState(() {
//           requires2FA = true;
//           OtpId = jsonData["data"]["otp_id"];
//         });
//         await backupcodeapicall();
//       }
//       setState(() {
//         loading = false;
//       });
//     }
//   }
//
//   Future<void> loginsubmit() async {
//     setState(() {
//       loading = true;
//     });
//     print(selectedrole);
//     print({
//       "email": email.text.trim(),
//       "password": password.text.trim(),
//       "role": selectedrole,
//       "admin_id": adminId,
//       "user_id": userId,
//     });
//     print("userid${userId}");
//     final response =
//     await apiPost(Uri.parse('${Api_url}/api/auth/login'), body: {
//       "email": email.text.trim(),
//       "password": password.text.trim(),
//       "role": selectedrole,
//       "admin_id": adminId,
//       "user_id": userId,
//       "rememberMe": rememberMe.toString(),
//     });
//     print(response.body);
//     final jsonData = json.decode(response.body);
//
//     if (jsonData["statusCode"] == 200) {
//       print(jsonData);
//
//       SharedPreferences prefs = await SharedPreferences.getInstance();
//       prefs.setBool('isAuthenticated', true);
//       prefs.setString('token', jsonData["token"]);
//       prefs.setString('userId', userId!);
//
//       // Save credentials if Remember Me is enabled
//       await _saveCredentials();
//
//       print(jsonData);
//       //  print("required 2FA ${jsonData["data"]["requires2FA"]}");
//       await checkToken(jsonData["token"]);
//       //  await checkToken("token", "id");
//       // Navigator.push(
//       //     context, MaterialPageRoute(builder: (context) => Dashboard()));
//
//       setState(() {
//         loading = false;
//       });
//     } else {
//       Fluttertoast.showToast(msg: _formatErrorMessage(jsonData["message"]));
//       if (jsonData["statusCode"] == 205) {
//         print("2FA ON");
//         setState(() {
//           requires2FA = true;
//           OtpId = jsonData["data"]["otp_id"];
//         });
//         await backupcodeapicall();
//       }
//       setState(() {
//         loading = false;
//       });
//     }
//   }
//
//   Future<void> loginsubmitverify2fa() async {
//     setState(() {
//       loading = true;
//     });
//
//     print("userid${userId}");
//     print('${Api_url}/api/auth/verify-login-2fa');
//     print(OtpId);
//     final response = await apiPost(
//       Uri.parse('${Api_url}/api/auth/verify-login-2fa'),
//       headers: {
//         "Content-Type": "application/json",
//       },
//       body: jsonEncode({
//         "code": twoFA.text,
//         "is_backup_code": switchtoBackupcode,
//         "otp_id": switchtoBackupcode ? null : OtpId,
//         "user_type": selectedrole,
//         "user_id": userId,
//         "rememberMe": rememberMe,
//       }),
//     );
//     print(response.body);
//     final jsonData = json.decode(response.body);
//     if (jsonData["statusCode"] == 200) {
//       print(jsonData);
//
//       SharedPreferences prefs = await SharedPreferences.getInstance();
//       prefs.setBool('isAuthenticated', true);
//       prefs.setString('token', jsonData["token"]);
//       prefs.setString('userId', userId!);
//
//       // Save credentials if Remember Me is enabled
//       await _saveCredentials();
//
//       print(jsonData);
//       print(selectedrole);
//       //print("required 2FA ${jsonData["data"]["requires2FA"]}");
//       if (selectedrole == "staffmember" || selectedrole == "staff")
//         await checkTokenStaff(jsonData["token"]);
//       if (selectedrole == "tenant") await checkTokenTenant(jsonData["token"]);
//       if (selectedrole == "vendor") await checkTokenVendor(jsonData["token"]);
//       if (selectedrole == "admin") await checkToken(jsonData["token"]);
//       //  await checkToken("token", "id");
//       // Navigator.push(
//       //     context, MaterialPageRoute(builder: (context) => Dashboard()));
//
//       setState(() {
//         loading = false;
//       });
//     } else {
//       Fluttertoast.showToast(msg: _formatErrorMessage(jsonData["message"]));
//       if (jsonData["statusCode"] == 205) {
//         print("2FA ON");
//         setState(() {
//           requires2FA = true;
//         });
//       }
//       setState(() {
//         loading = false;
//       });
//     }
//   }
//
//   Future<void> backupcodeapicall() async {
//     // setState(() {
//     //   loading = true;
//     // });
//     print(selectedrole);
//
//     selectedrole =
//     selectedrole == "staffmember" ? "staff" : selectedrole.toLowerCase();
//
//     print("userid${userId}");
//     final response = await apiGet(Uri.parse(
//         '${Api_url}/api/backup-codes/backup-codes/${userId}?user_type=$selectedrole'));
//     print(response.body);
//     final jsonData = json.decode(response.body);
//     if (jsonData["statusCode"] == 200) {
//       print(jsonData);
//
//       //  await checkToken("token", "id");
//       // Navigator.push(
//       //     context, MaterialPageRoute(builder: (context) => Dashboard()));
//
//       setState(() {
//         backupcode = true;
//       });
//     } else {
//       //   Fluttertoast.showToast(msg: _formatErrorMessage(jsonData["message"]));
//       //   if (jsonData["statusCode"] == 205) {
//       //     print("2FA ON");
//       //     setState(() {
//       //       requires2FA = true;
//       //       OtpId = jsonData["data"]["otp_id"];
//       //     });
//       //   }
//       //   setState(() {
//       //     loading = false;
//       //   });
//     }
//   }
// }
//
// class SingleSelectionButtons extends StatefulWidget {
//   final List<Map<String, String>> buttonOptions;
//   final Function(int index) onSelected;
//
//   const SingleSelectionButtons({
//     super.key,
//     required this.buttonOptions,
//     required this.onSelected,
//   });
//
//   @override
//   _SingleSelectionButtonsState createState() => _SingleSelectionButtonsState();
// }
//
// class _SingleSelectionButtonsState extends State<SingleSelectionButtons> {
//   int _selectedIndex = -1;
//
//   @override
//   Widget build(BuildContext context) {
//     return LayoutBuilder(builder: (context, contraints) {
//       if (contraints.maxWidth > 500) {
//         return Container(
//           width: MediaQuery.of(context).size.width * .8,
//           child: Wrap(
//             spacing: 8.0,
//             runSpacing: 8.0,
//             alignment: WrapAlignment.start,
//             children: widget.buttonOptions.map((option) {
//               final index = widget.buttonOptions.indexOf(option);
//               return SizedBox(
//                 width: 320, // Adjusted width to make the button smaller
//                 child: ElevatedButton(
//                   onPressed: () {
//                     setState(() {
//                       _selectedIndex = index;
//                       print(index);
//                     });
//                     widget.onSelected(index);
//                   },
//                   style: ElevatedButton.styleFrom(
//                     padding:
//                     const EdgeInsets.symmetric(vertical: 10, horizontal: 5),
//                     foregroundColor:
//                     _selectedIndex == index ? Colors.white : blueColor,
//                     backgroundColor:
//                     _selectedIndex == index ? blueColor : Colors.white,
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(8.0),
//                     ),
//                     side: BorderSide(
//                       color: _selectedIndex == index ? blueColor : Colors.grey,
//                     ),
//                   ),
//                   child: Row(
//                     children: [
//                       Icon(
//                         _selectedIndex == index
//                             ? Icons.check_circle
//                             : Icons.radio_button_unchecked,
//                         color: _selectedIndex == index
//                             ? Colors.white
//                             : Colors.grey,
//                       ),
//                       const SizedBox(width: 5.0),
//                       Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           Text(
//                             option["company"]!,
//                             style: TextStyle(
//                                 fontWeight: FontWeight.bold,
//                                 color: _selectedIndex == index
//                                     ? Colors.white
//                                     : Colors.black,
//                                 fontSize: 18),
//                           ),
//                           Text(
//                             capitalizeFirstLetter(option["role"]!),
//                             style: TextStyle(
//                                 fontWeight: FontWeight.bold,
//                                 color: _selectedIndex == index
//                                     ? Colors.white
//                                     : Colors.black,
//                                 fontSize: 16),
//                           ),
//                         ],
//                       ),
//                     ],
//                   ),
//                 ),
//               );
//             }).toList(),
//           ),
//         );
//       }
//       return Container(
//         width: 350,
//         child: Wrap(
//           spacing: 8.0,
//           runSpacing: 8.0,
//           alignment: WrapAlignment.center,
//           children: widget.buttonOptions.map((option) {
//             final index = widget.buttonOptions.indexOf(option);
//             return SizedBox(
//               width: 320, // Adjusted width to make the button smaller
//               child: ElevatedButton(
//                 onPressed: () {
//                   setState(() {
//                     _selectedIndex = index;
//                     print(index);
//                   });
//                   widget.onSelected(index);
//                 },
//                 style: ElevatedButton.styleFrom(
//                   padding:
//                   const EdgeInsets.symmetric(vertical: 10, horizontal: 5),
//                   foregroundColor:
//                   _selectedIndex == index ? Colors.white : blueColor,
//                   backgroundColor:
//                   _selectedIndex == index ? blueColor : Colors.white,
//                   shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(8.0),
//                   ),
//                   side: BorderSide(
//                     color: _selectedIndex == index ? blueColor : grey,
//                   ),
//                 ),
//                 child: Row(
//                   crossAxisAlignment: CrossAxisAlignment.center,
//                   children: [
//                     // Icon(
//                     //   _selectedIndex == index
//                     //       ? (Icons.check_box)
//                     //       : Icons.check_box_outline_blank,
//                     //   color:
//                     //       _selectedIndex == index ? Colors.white : blueColor,
//                     //   size: 40,
//                     // ),
//                     const SizedBox(
//                       width: 10,
//                     ),
//                     Container(
//                       width: 30, // Set the width of the container
//                       height: 30, // Set the height of the container
//                       decoration: BoxDecoration(
//                         border: Border.all(
//                           color: _selectedIndex == index
//                               ? Colors.white
//                               : Colors.black, // Border color
//                           width: 2, // Set the border thickness
//                         ),
//                         borderRadius: BorderRadius.circular(
//                             3), // Optional: rounded corners
//                       ),
//                       child: Center(
//                         child: _selectedIndex == index
//                             ? const Icon(
//                           Icons.check_sharp,
//                           color: Colors.white, // Icon color when selected
//                           size: 25, // Set the icon size
//                         )
//                             : const SizedBox
//                             .shrink(), // This will create a blank space when not selected
//                       ),
//                     ),
//                     const SizedBox(width: 15),
//                     Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Row(
//                           children: [
//                             SizedBox(
//                               width: 250,
//                               child: Text(
//                                 "${option['userName']!} (${option['company']!})",
//                                 style: TextStyle(
//                                     fontWeight: FontWeight.bold,
//                                     color: _selectedIndex == index
//                                         ? Colors.white
//                                         : Colors.black,
//                                     fontSize: 16),
//                                 maxLines: 3,
//                               ),
//                             ),
//                           ],
//                         ),
//                         Text(
//                           capitalizeFirstLetter(option["role"]!),
//                           style: TextStyle(
//                               fontWeight: FontWeight.w500,
//                               color: _selectedIndex == index
//                                   ? Colors.white
//                                   : Colors.black,
//                               fontSize: 13),
//                         ),
//                       ],
//                     ),
//                   ],
//                 ),
//               ),
//             );
//           }).toList(),
//         ),
//       );
//     });
//   }
//
//   String capitalizeFirstLetter(String input) {
//     if (input.isEmpty) return input;
//     return input[0].toUpperCase() + input.substring(1);
//   }
// }
// /*import 'dart:convert';
//
// import 'package:dropdown_button2/dropdown_button2.dart';
// import 'package:email_validator/email_validator.dart';
// import 'package:flutter/cupertino.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/widgets.dart';
// import 'package:flutter_spinkit/flutter_spinkit.dart';
// import 'package:fluttertoast/fluttertoast.dart';
// import 'package:font_awesome_flutter/font_awesome_flutter.dart';
// import 'package:intl/intl.dart';
// import 'package:provider/provider.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:three_zero_two_property/VendorModule/screen/dashboard.dart';
// import 'package:three_zero_two_property/screens/Password/changepassword.dart';
//
// import 'package:three_zero_two_property/screens/Signup/signup_screen.dart';
// import 'package:http/http.dart' as http;
import 'package:three_zero_two_property/services/api_helpers.dart';
//
// import '../../StaffModule/repository/staffpermission_provider.dart';
// import '../../StaffModule/screen/dashboard.dart';
// import '../../TenantsModule/repository/permission_provider.dart';
// import '../../TenantsModule/screen/dashboard.dart';
// import '../../VendorModule/screen/mainScreen.dart';
// import '../../constant/constant.dart';
// import '../../provider/Plan Purchase/plancheckProvider.dart';
// import '../../provider/dateProvider.dart';
// import '../Dashboard/dashboard_one.dart';
// import '../Password/forgotpassword.dart';
// import '../Password/otp_vrify.dart';
// import '../Plans/PlansPurcharCard.dart';
//
// class Login_Screen extends StatefulWidget {
//   const Login_Screen({super.key});
//
//   @override
//   State<Login_Screen> createState() => _Login_ScreenState();
// }
//
// class _Login_ScreenState extends State<Login_Screen> {
//   TextEditingController password = TextEditingController();
//   TextEditingController company = TextEditingController();
//   TextEditingController email = TextEditingController();
//
//   bool passworderror = false;
//   bool visiable_password = true;
//   bool emailerror = false;
//   bool companyerror = false;
//   bool roleerror = false;
//
//   String _email = '';
//   bool _isEmailSubmitted = false;
//   bool _hasMultipleCompanies = false;
//   bool loading = false;
//   List<Map<String, String>> _companies = [];
//   String _selectedCompany = '';
//   String _password = '';
//   String selectedrole = '';
//   String passwordmessage = "";
//   String companymessage = "";
//   String emailmessage = "";
//   String rolemessage = "";
//   // String get email => _email;
//   bool get isEmailSubmitted => _isEmailSubmitted;
//   bool get hasMultipleCompanies => _hasMultipleCompanies;
//   List<Map<String, String>> get companies => _companies;
//   String get selectedCompany => _selectedCompany;
//   // String get password => _password;
//
//   void setEmail(String email) {
//     print(email);
//     setState(() {
//       if (_email != email) {
//         _email = email;
//         _isEmailSubmitted = false;
//         _hasMultipleCompanies = false;
//         _companies = [];
//         _selectedCompany = '';
//         _password = '';
//       }
//     });
//   }
//
//   void selectCompany(String company, String role) {
//     _selectedCompany = company;
//     selectedrole = role; // Set role when selecting company
//     print(selectedrole);
//     print(selectedCompany);
//     setState(() {});
//   }
//
//   void login() {
//     // Implement login logic here
//     print(
//         'Logging in with email: $_email, company: $_selectedCompany, password: $_password');
//   }
//
//   void setPassword(String password) {
//     _password = password;
//   }
//
//   // Helper function to format error messages for better user experience
//   String _formatErrorMessage(String apiMessage) {
//     // Convert technical error messages to user-friendly ones
//     if (apiMessage.toLowerCase().contains('invalid') &&
//         (apiMessage.toLowerCase().contains('password') ||
//          apiMessage.toLowerCase().contains('admin'))) {
//       return "Invalid username or password.";
//     }
//     if (apiMessage.toLowerCase().contains('email') &&
//         apiMessage.toLowerCase().contains('not found')) {
//       return "Email address not found.";
//     }
//     if (apiMessage.toLowerCase().contains('account') &&
//         apiMessage.toLowerCase().contains('disabled')) {
//       return "Your account has been disabled. Please contact support.";
//     }
//     if (apiMessage.toLowerCase().contains('network') ||
//         apiMessage.toLowerCase().contains('connection')) {
//       return "Network error. Please check your connection and try again.";
//     }
//     // Return the original message if no specific formatting is needed
//     return apiMessage;
//   }
//
//   Future<void> submitEmail() async {
//     print("Calling  ${email.text}");
//     // Make API call to check email
//     final response = await apiPost(
//       Uri.parse('$Api_url/api/admin/check_role'),
//       // Uri.parse('$Api_url/api/admin/check_role'),
//       headers: {'Content-Type': 'application/json'},
//       body: jsonEncode({'email': email.text}),
//     );
//     print(response.body);
//     if (response.statusCode == 200) {
//       final data = jsonDecode(response.body);
//       List<dynamic> roles = data['data'];
//       print(roles.length);
//       if (roles.isEmpty) {
//         Fluttertoast.showToast(msg: "Email address not found.");
//       } else {
//         if (roles.length > 1) {
//           setState(() {
//             _hasMultipleCompanies = true;
//             _companies = roles
//                 .map<Map<String, String>>((role) =>
//             {'company': role['company_name'], 'role': role['role']})
//                 .toList();
//             _isEmailSubmitted = true;
//           });
//         } else {
//           setState(() {
//             if (roles[0]['role'] == "admin") {
//               _hasMultipleCompanies = false;
//               //_selectedCompany = roles[0]['company_name'];
//               selectedrole = roles[0]['role']; // Set role directly
//               _isEmailSubmitted = true;
//             } else {
//               print(roles[0]['role']);
//               _hasMultipleCompanies = false;
//               _selectedCompany = roles[0]['company_name'];
//               selectedrole = roles[0]['role']; // Set role directly
//               _isEmailSubmitted = true;
//             }
//           });
//         }
//       }
//     } else {
//       Fluttertoast.showToast(msg: "Email address not found.");
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//
//     return Scaffold(
//       backgroundColor: Colors.white,
//       body: Padding(
//           padding: const EdgeInsets.all(0.0),
//           child: LayoutBuilder(
//               builder: (context,contraints) {
//                 if(contraints.maxWidth > 500){
//                   return Column(
//                     crossAxisAlignment: CrossAxisAlignment.center,
//                     mainAxisAlignment: MainAxisAlignment.center,
//                     children: [
//
//                       SizedBox(
//                         height: MediaQuery.of(context).size.height * 0.1,
//                       ),
//                       Image(
//                         image: AssetImage('assets/images/logo.png'),
//                         height: MediaQuery.of(context).size.height * 0.07,
//                         width: MediaQuery.of(context).size.width * 0.9,
//                         fit: BoxFit.fill,
//                       ),
//                       SizedBox(
//                         height: MediaQuery.of(context).size.height * 0.025,
//                       ),
//                       // Welcome
//                       Center(
//                         child: Text(
//                           "Welcome to 302 Rentals",
//                           style: TextStyle(
//                             color: Colors.black,
//                             fontWeight: FontWeight.bold,
//                             fontSize: MediaQuery.of(context).size.width * 0.04,
//                           ),
//                         ),
//                       ),
//                       SizedBox(
//                         height: MediaQuery.of(context).size.height * 0.02,
//                       ),
//                       // Login text
//                       Center(
//                         child: Text(
//                           "Please login here...",
//                           style: TextStyle(
//                               color: Colors.black,
//                               fontSize: MediaQuery.of(context).size.width * 0.03),
//                         ),
//                       ),
//                       SizedBox(
//                         height: MediaQuery.of(context).size.height * 0.05,
//                       ),
//
//
//                       SizedBox(
//                         height: MediaQuery.of(context).size.height * 0.01,
//                       ),
//                       // Email
//                       Row(
//                         children: [
//                           SizedBox(
//                             width: MediaQuery.of(context).size.width * 0.099,
//                           ),
//                           Expanded(
//                             flex: 1,
//                             child: Container(
//                               height: 60,
//                               decoration: BoxDecoration(
//                                 borderRadius: BorderRadius.circular(10),
//                                 color: Color.fromRGBO(196, 196, 196, .3),
//                               ),
//                               child: Stack(
//                                 children: [
//                                   Positioned.fill(
//                                     child: TextField(
//                                       keyboardType: TextInputType.emailAddress,
//                                       onChanged: (value) {
//                                         setState(() {
//                                           emailerror = false;
//                                           _isEmailSubmitted = false;
//                                           _hasMultipleCompanies = false;
//                                         });
//                                       },
//                                       style: TextStyle(
//                                           fontSize: 20
//                                       ),
//                                       controller: email,
//                                       cursorColor: blueColor,
//                                       decoration: InputDecoration(
//                                         enabledBorder: emailerror
//                                             ? OutlineInputBorder(
//                                           borderRadius: BorderRadius.circular(10),
//                                           borderSide: BorderSide(
//                                               color: Colors
//                                                   .red), // Set border color here
//                                         )
//                                             : InputBorder.none,
//                                         border: InputBorder.none,
//                                         contentPadding: EdgeInsets.all(14),
//
//                                         prefixIcon: Container(
//                                           height: 25,
//                                           width: 25,
//                                           padding: EdgeInsets.all(13),
//                                           child: FaIcon(
//                                             FontAwesomeIcons.envelope,
//                                             size: 25,
//                                             color: Colors.grey[600],
//                                           ),
//                                         ),
//                                         hintText: "Business Email",
//                                         hintStyle: TextStyle(
//                                             color: Colors.grey[600], fontSize: 20),
//                                       ),
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                             ),
//                           ),
//                           SizedBox(
//                             width: MediaQuery.of(context).size.width * 0.095,
//                           ),
//                         ],
//                       ),
//                       emailerror
//                           ? Center(
//                           child: Text(
//                             emailmessage,
//                             style: TextStyle(
//                               color: Colors.red,
//                             ),
//                           ))
//                           : Container(),
//
//                       SizedBox(
//                         height: MediaQuery.of(context).size.height * 0.025,
//                       ),
//                       if(!isEmailSubmitted)
//                         Column(
//                           children: [
//                             Column(
//                               children: [
//                                 Row(
//                                   mainAxisAlignment: MainAxisAlignment.end,
//                                   children: [
//
//
//                                     GestureDetector(
//                                       onTap: () {
//                                         Navigator.push(
//                                             context,
//                                             MaterialPageRoute(
//                                                 builder: (context) => ForgotPassword()));
//                                       },
//                                       child: Text(
//                                         "Forgot password?",
//                                         style: TextStyle(
//                                             fontSize: MediaQuery.of(context).size.width * 0.02,
//                                             color: Colors.blue),
//                                       ),
//                                     ),
//                                     SizedBox(
//                                       width: MediaQuery.of(context).size.width * 0.099,
//                                     ),
//                                   ],
//                                 ),
//                                 SizedBox(
//                                   height: MediaQuery.of(context).size.height * 0.025,
//                                 ),
//
//                               ],
//                             ),
//                             SizedBox(
//                               height: MediaQuery.of(context).size.height * 0.035,
//                             ),
//                             InkWell(
//                               onTap: (){
//                                 if (email.text.isEmpty) {
//                                   setState(() {
//                                     emailerror = true;
//                                     emailmessage = "Email is required";
//                                   });
//                                 } else if (!EmailValidator.validate(email.text)) {
//                                   setState(() {
//                                     emailerror = true;
//                                     emailmessage = "Email is not valid";
//                                   });
//                                 } else {
//                                   setState(() {
//                                     emailerror = false;
//                                     //firstnamemessage = "Firstname is required";
//                                   });
//                                   submitEmail();
//                                 }
//
//
//                               },
//                               child: Center(
//                                 child: Container(
//                                   height: MediaQuery.of(context).size.height * 0.05,
//                                   width: MediaQuery.of(context).size.width * 0.8,
//                                   decoration: BoxDecoration(
//                                     color: Colors.black,
//                                     borderRadius: BorderRadius.circular(10),
//                                   ),
//                                   child: Center(
//                                     child: loading
//                                         ? SpinKitFadingCircle(
//                                       color: Colors.white,
//                                       size: 40.0,
//                                     )
//                                         : Row(
//                                       mainAxisAlignment: MainAxisAlignment.center,
//                                       children: [
//                                         Text(
//                                           "Submit",
//                                           style: TextStyle(
//                                               color: Colors.white,
//                                               fontWeight: FontWeight.bold,
//                                               fontSize:
//                                               MediaQuery.of(context).size.width *
//                                                   0.03),
//                                         ),
//
//                                       ],
//                                     ),
//                                   ),
//                                 ),
//                               ),
//                             ),
//                           ],
//                         ),
//                       if(isEmailSubmitted)
//                         Column(
//                           mainAxisAlignment: MainAxisAlignment.center,
//                           crossAxisAlignment: CrossAxisAlignment.center,
//                           children: [
//
//                             Row(
//                               children: [
//                                 SizedBox(
//                                   width: MediaQuery.of(context).size.width * 0.099,
//                                 ),
//                                 Expanded(
//                                   flex: 1,
//                                   child: Container(
//                                     height: 60,
//                                     decoration: BoxDecoration(
//                                       borderRadius: BorderRadius.circular(10),
//                                       color: Color.fromRGBO(196, 196, 196, .3),
//                                     ),
//                                     child: Stack(
//                                       children: [
//                                         Positioned.fill(
//                                           child: TextField(
//                                             keyboardType: TextInputType.text,
//                                             onChanged: (value) {
//                                               setState(() {
//                                                 passworderror = false;
//                                               });
//                                             },
//                                             style: TextStyle(
//                                                 fontSize: 20
//                                             ),
//                                             controller: password,
//                                             obscureText: visiable_password,
//                                             cursorColor: blueColor,
//                                             decoration: InputDecoration(
//                                               enabledBorder: passworderror
//                                                   ? OutlineInputBorder(
//                                                 borderRadius: BorderRadius.circular(10),
//                                                 borderSide: BorderSide(
//                                                     color: Colors
//                                                         .red), // Set border color here
//                                               )
//                                                   : InputBorder.none,
//                                               border: InputBorder.none,
//                                               contentPadding: EdgeInsets.all(14),
//                                               prefixIcon: Container(
//                                                 height: 25,
//                                                 width: 25,
//                                                 // color: Colors.blue,
//                                                 padding: EdgeInsets.all(13),
//                                                 child: FaIcon(
//                                                   FontAwesomeIcons.lock,
//                                                   size: 25,
//                                                   color: Colors.grey[600],
//                                                 ),
//                                               ),
//                                               hintText: "Password",
//                                               hintStyle: TextStyle(
//                                                   color: Colors.grey[600], fontSize: 20),
//                                               suffixIcon: InkWell(
//                                                 onTap: () {
//                                                   setState(() {
//                                                     visiable_password = !visiable_password;
//                                                   });
//                                                 },
//                                                 child: Icon(
//                                                   visiable_password
//                                                       ? Icons.remove_red_eye_outlined
//                                                       : Icons.visibility_off_outlined,
//                                                   color: Colors.grey[600],
//                                                 ),
//                                               ),
//                                             ),
//                                           ),
//                                         ),
//                                       ],
//                                     ),
//                                   ),
//                                 ),
//
//                                 SizedBox(
//                                   width: MediaQuery.of(context).size.width * 0.099,
//                                 ),
//                               ],
//                             ),
//                             passworderror
//                                 ? Center(
//                                 child: Text(
//                                   passwordmessage,
//                                   style: TextStyle(color: Colors.red),
//                                 ))
//                                 : Container(),
//                             SizedBox(
//                               height: MediaQuery.of(context).size.height * 0.025,
//                             ),
//                             if (hasMultipleCompanies) ...[
//
//                               SingleSelectionButtons(
//                                 buttonOptions: companies,
//                                 onSelected: (index) {
//                                   selectCompany(companies[index]["company"]!,companies[index]["role"]!);
//                                 },
//                               ),
//                             ],
//
//
//                             SizedBox(
//                               height: MediaQuery.of(context).size.height * 0.015,
//                             ),
//                             // Forgot password
//                             Row(
//                               mainAxisAlignment: MainAxisAlignment.end,
//                               children: [
//
//
//                                 GestureDetector(
//                                   onTap: () {
//                                     Navigator.push(
//                                         context,
//                                         MaterialPageRoute(
//                                             builder: (context) => ForgotPassword()));
//                                   },
//                                   child: Text(
//                                     "Forgot password?",
//                                     style: TextStyle(
//                                         fontSize: MediaQuery.of(context).size.width * 0.02,
//                                         color: Colors.blue),
//                                   ),
//                                 ),
//                                 SizedBox(
//                                   width: MediaQuery.of(context).size.width * 0.099,
//                                 ),
//                               ],
//                             ),
//                             SizedBox(
//                               height: MediaQuery.of(context).size.height * 0.025,
//                             ),
//
//                             GestureDetector(
//                               onTap: () async {
//                                 setState(() {
//                                   if (email.text.isEmpty) {
//                                     setState(() {
//                                       emailerror = true;
//                                       emailmessage = "Email is required";
//                                     });
//                                   } else if (!EmailValidator.validate(email.text)) {
//                                     setState(() {
//                                       emailerror = true;
//                                       emailmessage = "Email is not valid";
//                                     });
//                                   } else {
//                                     setState(() {
//                                       emailerror = false;
//                                       //firstnamemessage = "Firstname is required";
//                                     });
//                                   }
//                                   if (password.text.isEmpty) {
//                                     setState(() {
//                                       passworderror = true;
//                                       passwordmessage = "Password is required";
//                                     });
//                                   } else {
//                                     setState(() {
//                                       passworderror = false;
//                                       //firstnamemessage = "Firstname is required";
//                                     });
//                                   }
//                                   if(selectedrole == null){
//                                     setState(() {
//                                       roleerror = true;
//                                       rolemessage = "Please select the role";
//                                     });
//                                   }
//                                   else{
//                                     setState(() {
//                                       roleerror = false;
//                                       //firstnamemessage = "Firstname is required";
//                                     });
//                                   }
//                                   if(selectedrole != "1" && selectedrole != null && company.text.isEmpty){
//                                     setState(() {
//                                       companyerror = true;
//                                       companymessage = "Company Name is required";
//                                     });
//                                   }
//                                   else{
//                                     setState(() {
//                                       companyerror = false;
//                                       //firstnamemessage = "Firstname is required";
//                                     });
//                                   }
//
//
//                                 });
//                                 if(selectedrole == ""){
//                                   Fluttertoast.showToast(msg: "Please select the company");
//                                 }
//                                 else if (emailerror == false && passworderror == false ) {
//
//                                   if(selectedrole == "admin")
//                                     await loginsubmit();
//                                   if(selectedrole != "admin")
//                                     await checkCompany(selectedCompany);
//                                   // Save authentication status to SharedPreferences
//
//                                 }
//                               },
//                               child: Center(
//                                 child: Container(
//                                   height: MediaQuery.of(context).size.height * 0.045,
//                                   width: MediaQuery.of(context).size.width * 0.8,
//                                   decoration: BoxDecoration(
//                                     color: Colors.black,
//                                     borderRadius: BorderRadius.circular(10),
//                                   ),
//                                   child: Center(
//                                     child: loading
//                                         ? SpinKitFadingCircle(
//                                       color: Colors.white,
//                                       size: 40.0,
//                                     )
//                                         : Row(
//                                       mainAxisAlignment: MainAxisAlignment.center,
//                                       children: [
//                                         Text(
//                                           "Login",
//                                           style: TextStyle(
//                                               color: Colors.white,
//                                               fontWeight: FontWeight.bold,
//                                               fontSize:
//                                               MediaQuery.of(context).size.width *
//                                                   0.03),
//                                         ),
//                                         SizedBox(
//                                           height:
//                                           MediaQuery.of(context).size.width * 0.015,
//                                         ),
//                                         Icon(
//                                           Icons.arrow_forward_ios_sharp,
//                                           color: Colors.white,
//                                           size:
//                                           MediaQuery.of(context).size.width * 0.03,
//                                         ),
//                                       ],
//                                     ),
//                                   ),
//                                 ),
//                               ),
//                             ),
//                           ],
//                         ),
//
//
//
//
//                       // Register now
//                       SizedBox(
//                         height: MediaQuery.of(context).size.height * 0.04,
//                       ),
//                       Row(
//                         mainAxisAlignment: MainAxisAlignment.center,
//                         children: [
//                           Text(
//                             "Don't have an account ? ",
//                             style: TextStyle(
//                                 color: Colors.black,
//                                 fontSize: MediaQuery.of(context).size.width * 0.03),
//                           ),
//                           GestureDetector(
//                             onTap: () {
//                               Navigator.push(context,
//                                   MaterialPageRoute(builder: (context) => Signup()));
//                             },
//                             child: Container(
//                               child: Text(
//                                 "Register now",
//                                 style: TextStyle(
//                                     fontWeight: FontWeight.bold,
//                                     color: Colors.blue,
//                                     fontSize:
//                                     MediaQuery.of(context).size.width * 0.03),
//                               ),
//                             ),
//                           ),
//                         ],
//                       ),
//                       SizedBox(
//                         height: MediaQuery.of(context).size.height * 0.04,
//                       ),
//                       // SizedBox(
//                       //   height: MediaQuery.of(context).size.height * 0.1,
//                       // ),
//                     ],
//                   );
//                 }
//
//                 return SingleChildScrollView(
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.center,
//                     mainAxisAlignment: MainAxisAlignment.center,
//                     children: [
//                       if(!isEmailSubmitted &&  MediaQuery.of(context).size.height > 700 && hasMultipleCompanies)
//                         SizedBox(
//                           height: MediaQuery.of(context).size.height * 0.25,
//                         ),
//                       if(isEmailSubmitted &&  MediaQuery.of(context).size.height > 700 && !hasMultipleCompanies)
//                         SizedBox(
//                           height: MediaQuery.of(context).size.height * 0.15,
//                         ),
//                       if(!isEmailSubmitted &&  MediaQuery.of(context).size.height > 700)
//                         SizedBox(
//                           height: MediaQuery.of(context).size.height * 0.15,
//                         ),
//                       if(MediaQuery.of(context).size.height < 670)
//                         SizedBox(
//                           height: MediaQuery.of(context).size.height * 0.1,
//                         ),
//                       SizedBox(
//                         height: MediaQuery.of(context).size.height * 0.1,
//                       ),
//                       Image(
//                         image: AssetImage('assets/images/logo.png'),
//                         height: MediaQuery.of(context).size.height * 0.05,
//                         width: MediaQuery.of(context).size.width * 0.9,
//                       ),
//                       SizedBox(
//                         height: MediaQuery.of(context).size.height * 0.025,
//                       ),
//                       // Welcome
//                       Center(
//                         child: Text(
//                           "Welcome to 302 Rentals",
//                           style: TextStyle(
//                             color: Colors.black,
//                             fontWeight: FontWeight.bold,
//                             fontSize: MediaQuery.of(context).size.width * 0.05,
//                           ),
//                         ),
//                       ),
//                       SizedBox(
//                         height: MediaQuery.of(context).size.height * 0.02,
//                       ),
//                       // Login text
//                       Center(
//                         child: Text(
//                           "Please login here...",
//                           style: TextStyle(
//                               color: Colors.black,
//                               fontSize: MediaQuery.of(context).size.width * 0.036),
//                         ),
//                       ),
//                       SizedBox(
//                         height: MediaQuery.of(context).size.height * 0.05,
//                       ),
//
//                       SizedBox(
//                         height: MediaQuery.of(context).size.height * 0.025,
//                       ),
//                       // Email
//                       Row(
//                         children: [
//                           SizedBox(
//                             width: MediaQuery.of(context).size.width * 0.099,
//                           ),
//                           Expanded(
//                             flex: 1,
//                             child: Container(
//                               height: 50,
//                               decoration: BoxDecoration(
//                                 borderRadius: BorderRadius.circular(10),
//                                 color: Color.fromRGBO(196, 196, 196, .3),
//                               ),
//                               child: Stack(
//                                 children: [
//                                   Positioned.fill(
//                                     child: TextField(
//                                       keyboardType: TextInputType.emailAddress,
//                                       onChanged: (value) {
//                                         setState(() {
//                                           emailerror = false;
//                                           _isEmailSubmitted = false;
//                                           _hasMultipleCompanies = false;
//                                         });
//                                       },
//                                       controller: email,
//                                       cursorColor: blueColor,
//                                       decoration: InputDecoration(
//                                         enabledBorder: emailerror
//                                             ? OutlineInputBorder(
//                                           borderRadius: BorderRadius.circular(10),
//                                           borderSide: BorderSide(
//                                               color: Colors
//                                                   .red), // Set border color here
//                                         )
//                                             : InputBorder.none,
//                                         border: InputBorder.none,
//                                         contentPadding: EdgeInsets.all(14),
//                                         prefixIcon: Container(
//                                           height: 20,
//                                           width: 20,
//                                           padding: EdgeInsets.all(13),
//                                           child: FaIcon(
//                                             FontAwesomeIcons.envelope,
//                                             size: 20,
//                                             color: Colors.grey[600],
//                                           ),
//                                         ),
//                                         hintText: "Business Email",
//                                         hintStyle: TextStyle(
//                                             color: Colors.grey[600], fontSize: 15),
//                                       ),
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                             ),
//                           ),
//                           SizedBox(
//                             width: MediaQuery.of(context).size.width * 0.095,
//                           ),
//                         ],
//                       ),
//                       emailerror
//                           ? Center(
//                           child: Text(
//                             emailmessage,
//                             style: TextStyle(
//                               color: Colors.red,
//                             ),
//                           ))
//                           : Container(),
//
//                       SizedBox(
//                         height: MediaQuery.of(context).size.height * 0.025,
//                       ),
//                       if(!isEmailSubmitted)
//                         Column(
//                           children: [
//                             Column(
//                               children: [
//                                 Row(
//                                   mainAxisAlignment: MainAxisAlignment.end,
//                                   children: [
//
//
//                                     GestureDetector(
//                                       onTap: () {
//                                         Navigator.push(
//                                             context,
//                                             MaterialPageRoute(
//                                                 builder: (context) => ForgotPassword()));
//                                       },
//                                       child: Text(
//                                         "Forgot password?",
//                                         style: TextStyle(
//                                             fontSize: MediaQuery.of(context).size.width * 0.035,
//                                             color: Colors.blue),
//                                       ),
//                                     ),
//                                     SizedBox(
//                                       width: MediaQuery.of(context).size.width * 0.099,
//                                     ),
//                                   ],
//                                 ),
//                                 SizedBox(
//                                   height: MediaQuery.of(context).size.height * 0.025,
//                                 ),
//
//                               ],
//                             ),
//                             SizedBox(
//                               height: MediaQuery.of(context).size.height * 0.035,
//                             ),
//                             InkWell(
//                               onTap: (){
//                                 if (email.text.isEmpty) {
//                                   setState(() {
//                                     emailerror = true;
//                                     emailmessage = "Email is required";
//                                   });
//                                 } else if (!EmailValidator.validate(email.text)) {
//                                   setState(() {
//                                     emailerror = true;
//                                     emailmessage = "Email is not valid";
//                                   });
//                                 } else {
//                                   setState(() {
//                                     emailerror = false;
//                                     //firstnamemessage = "Firstname is required";
//                                   });
//                                   submitEmail();
//                                 }
//
//
//                               },
//                               child: Center(
//                                 child: Container(
//                                   height: MediaQuery.of(context).size.height * 0.06,
//                                   width: MediaQuery.of(context).size.width * 0.8,
//                                   decoration: BoxDecoration(
//                                     color: Colors.black,
//                                     borderRadius: BorderRadius.circular(10),
//                                   ),
//                                   child: Center(
//                                     child: loading
//                                         ? SpinKitFadingCircle(
//                                       color: Colors.white,
//                                       size: 40.0,
//                                     )
//                                         : Row(
//                                       mainAxisAlignment: MainAxisAlignment.center,
//                                       children: [
//                                         Text(
//                                           "Submit",
//                                           style: TextStyle(
//                                               color: Colors.white,
//                                               fontWeight: FontWeight.bold,
//                                               fontSize:
//                                               MediaQuery.of(context).size.width *
//                                                   0.045),
//                                         ),
//
//                                       ],
//                                     ),
//                                   ),
//                                 ),
//                               ),
//                             ),
//                           ],
//                         ),
//                       if(isEmailSubmitted)
//                         Column(
//                           mainAxisAlignment: MainAxisAlignment.center,
//                           crossAxisAlignment: CrossAxisAlignment.center,
//                           children: [
//
//                             Row(
//                               children: [
//                                 SizedBox(
//                                   width: MediaQuery.of(context).size.width * 0.099,
//                                 ),
//                                 Expanded(
//                                   flex: 1,
//                                   child: Container(
//                                     height: 50,
//                                     decoration: BoxDecoration(
//                                       borderRadius: BorderRadius.circular(10),
//                                       color: Color.fromRGBO(196, 196, 196, .3),
//                                     ),
//                                     child: Stack(
//                                       children: [
//                                         Positioned.fill(
//                                           child: TextField(
//                                             keyboardType: TextInputType.text,
//                                             onChanged: (value) {
//                                               setState(() {
//                                                 passworderror = false;
//                                               });
//                                             },
//                                             controller: password,
//                                             obscureText: visiable_password,
//                                             cursorColor: blueColor,
//                                             decoration: InputDecoration(
//                                               enabledBorder: passworderror
//                                                   ? OutlineInputBorder(
//                                                 borderRadius: BorderRadius.circular(10),
//                                                 borderSide: BorderSide(
//                                                     color: Colors
//                                                         .red), // Set border color here
//                                               )
//                                                   : InputBorder.none,
//                                               border: InputBorder.none,
//                                               contentPadding: EdgeInsets.all(14),
//                                               prefixIcon: Container(
//                                                 height: 20,
//                                                 width: 20,
//                                                 // color: Colors.blue,
//                                                 padding: EdgeInsets.all(13),
//                                                 child: FaIcon(
//                                                   FontAwesomeIcons.lock,
//                                                   size: 20,
//                                                   color: Colors.grey[600],
//                                                 ),
//                                               ),
//                                               hintText: "Password",
//                                               hintStyle: TextStyle(
//                                                   color: Colors.grey[600], fontSize: 15),
//                                               suffixIcon: InkWell(
//                                                 onTap: () {
//                                                   setState(() {
//                                                     visiable_password = !visiable_password;
//                                                   });
//                                                 },
//                                                 child: Icon(
//                                                   visiable_password
//                                                       ? Icons.remove_red_eye_outlined
//                                                       : Icons.visibility_off_outlined,
//                                                   color: Colors.grey[600],
//                                                 ),
//                                               ),
//                                             ),
//                                           ),
//                                         ),
//                                       ],
//                                     ),
//                                   ),
//                                 ),
//
//                                 SizedBox(
//                                   width: MediaQuery.of(context).size.width * 0.099,
//                                 ),
//                               ],
//                             ),
//                             passworderror
//                                 ? Center(
//                                 child: Text(
//                                   passwordmessage,
//                                   style: TextStyle(color: Colors.red),
//                                 ))
//                                 : Container(),
//                             SizedBox(
//                               height: MediaQuery.of(context).size.height * 0.025,
//                             ),
//                             if (hasMultipleCompanies) ...[
//
//                               SingleSelectionButtons(
//                                 buttonOptions: companies,
//                                 onSelected: (index) {
//                                   selectCompany(companies[index]["company"]!,companies[index]["role"]!);
//                                 },
//                               ),
//                             ],
//
//
//                             SizedBox(
//                               height: MediaQuery.of(context).size.height * 0.015,
//                             ),
//                             // Forgot password
//                             Row(
//                               mainAxisAlignment: MainAxisAlignment.end,
//                               children: [
//                                 SizedBox(
//                                   width: MediaQuery.of(context).size.width * 0.11,
//                                 ),
//
//
//                                 GestureDetector(
//                                   onTap: () {
//                                     Navigator.push(
//                                         context,
//                                         MaterialPageRoute(
//                                             builder: (context) => ForgotPassword()));
//                                   },
//                                   child: Text(
//                                     "Forgot password?",
//                                     style: TextStyle(
//                                         fontSize: MediaQuery.of(context).size.width * 0.035,
//                                         color: Colors.blue),
//                                   ),
//                                 ),
//                                 SizedBox(
//                                   width: MediaQuery.of(context).size.width * 0.099,
//                                 ),
//                               ],
//                             ),
//                             SizedBox(
//                               height: MediaQuery.of(context).size.height * 0.025,
//                             ),
//                             // Login button
//
//                             GestureDetector(
//                               onTap: () async {
//                                 setState(() {
//                                   if (email.text.isEmpty) {
//                                     setState(() {
//                                       emailerror = true;
//                                       emailmessage = "Email is required";
//                                     });
//                                   } else if (!EmailValidator.validate(email.text)) {
//                                     setState(() {
//                                       emailerror = true;
//                                       emailmessage = "Email is not valid";
//                                     });
//                                   } else {
//                                     setState(() {
//                                       emailerror = false;
//                                       //firstnamemessage = "Firstname is required";
//                                     });
//                                   }
//                                   if (password.text.isEmpty) {
//                                     setState(() {
//                                       passworderror = true;
//                                       passwordmessage = "Password is required";
//                                     });
//                                   } else {
//                                     setState(() {
//                                       passworderror = false;
//                                       //firstnamemessage = "Firstname is required";
//                                     });
//                                   }
//                                   if(selectedrole == null){
//                                     setState(() {
//                                       roleerror = true;
//                                       rolemessage = "Please select the role";
//                                     });
//                                   }
//                                   else{
//                                     setState(() {
//                                       roleerror = false;
//                                       //firstnamemessage = "Firstname is required";
//                                     });
//                                   }
//                                   if(selectedrole != "1" && selectedrole != null && company.text.isEmpty){
//                                     setState(() {
//                                       companyerror = true;
//                                       companymessage = "Company Name is required";
//                                     });
//                                   }
//                                   else{
//                                     setState(() {
//                                       companyerror = false;
//                                       //firstnamemessage = "Firstname is required";
//                                     });
//                                   }
//
//
//                                 });
//                                 if(selectedrole == ""){
//                                   Fluttertoast.showToast(msg: "Please select the company");
//                                 }
//                                 else if (emailerror == false && passworderror == false ) {
//
//                                   if(selectedrole == "admin")
//                                     await loginsubmit();
//                                   if(selectedrole != "admin")
//                                     await checkCompany(selectedCompany);
//                                   // Save authentication status to SharedPreferences
//
//                                 }
//                               },
//                               child: Center(
//                                 child: Container(
//                                   height: MediaQuery.of(context).size.height * 0.06,
//                                   width: MediaQuery.of(context).size.width * 0.8,
//                                   decoration: BoxDecoration(
//                                     color: Colors.black,
//                                     borderRadius: BorderRadius.circular(10),
//                                   ),
//                                   child: Center(
//                                     child: loading
//                                         ? SpinKitFadingCircle(
//                                       color: Colors.white,
//                                       size: 40.0,
//                                     )
//                                         : Row(
//                                       mainAxisAlignment: MainAxisAlignment.center,
//                                       children: [
//                                         Text(
//                                           "Login",
//                                           style: TextStyle(
//                                               color: Colors.white,
//                                               fontWeight: FontWeight.bold,
//                                               fontSize:
//                                               MediaQuery.of(context).size.width *
//                                                   0.045),
//                                         ),
//                                         SizedBox(
//                                           height:
//                                           MediaQuery.of(context).size.width * 0.015,
//                                         ),
//                                         Icon(
//                                           Icons.arrow_forward_ios_sharp,
//                                           color: Colors.white,
//                                           size:
//                                           MediaQuery.of(context).size.width * 0.045,
//                                         ),
//                                       ],
//                                     ),
//                                   ),
//                                 ),
//                               ),
//                             ),
//                           ],
//                         ),
//
//
//
//
//                       // Register now
//                       SizedBox(
//                         height: MediaQuery.of(context).size.height * 0.04,
//                       ),
//                       Row(
//                         mainAxisAlignment: MainAxisAlignment.center,
//                         children: [
//                           Text(
//                             "Don't have an account ? ",
//                             style: TextStyle(
//                                 color: Colors.black,
//                                 fontSize: MediaQuery.of(context).size.width * 0.04),
//                           ),
//                           GestureDetector(
//                             onTap: () {
//                               Navigator.push(context,
//                                   MaterialPageRoute(builder: (context) => Signup()));
//                             },
//                             child: Container(
//                               child: Text(
//                                 "Register now",
//                                 style: TextStyle(
//                                     fontWeight: FontWeight.bold,
//                                     color: Colors.blue,
//                                     fontSize:
//                                     MediaQuery.of(context).size.width * 0.037),
//                               ),
//                             ),
//                           ),
//                         ],
//                       ),
//                       SizedBox(
//                         height: MediaQuery.of(context).size.height * 0.04,
//                       ),
//                       // SizedBox(
//                       //   height: MediaQuery.of(context).size.height * 0.1,
//                       // ),
//                     ],
//                   ),
//                 );
//               }
//           )
//
//
//       ),
//     );
//   }
//
//   Future<void> checkToken(String token) async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     // String? token = prefs.getString('token');
//
//     final response = await apiPost(
//       Uri.parse('${Api_url}/api/admin/token_check_api'),
//       headers: {
//         // "authorization": "CRM $token",
//         //"id":"CRM $id",
//         "Content-Type": "application/json"
//       },
//       body: json.encode({"token": token}),
//     );
//     print(response.body);
//     final jsonData = json.decode(response.body);
//
//     if (jsonData['id'] != "") {
//       print(jsonData);
//       //prefs.setString('checkedToken',jsonData["token"]);
//       String? adminId = jsonData['data']['admin_id'];
//       print(jsonData);
//       String? companyName = jsonData['data']['company_name'];
//
//       print('Admin ID: $adminId');
//       prefs.setString('checkedToken', token);
//       prefs.setString('adminId', adminId!);
//
//       prefs.setString('companyName', companyName!);
//       print('Company Name: $companyName');
//       prefs.setString("role", "Admin");
//       prefs.setString('first_name', jsonData['data']['first_name']);
//       prefs.setString('last_name', jsonData['data']['last_name']);
//       prefs.setString('first_name', jsonData['data']['first_name']);
//
//       prefs.setString('last_name', jsonData['data']['last_name']);
//       prefs.setString('email', jsonData['data']['email']);
//       prefs.setString('superadminId', jsonData['data']['superadmin_id']);
//       if (!mounted) return;
//
//       await Provider.of<checkPlanPurchaseProiver>(context, listen: false)
//           .fetchPlanPurchaseDetail();
//
//       // Access the expiration date
//       var provider =
//       Provider.of<checkPlanPurchaseProiver>(context, listen: false);
//       var expirationDateString =
//           provider.checkplanpurchaseModel?.data?.expirationDate;
//
//       DateTime? expirationDate;
//       if (expirationDateString != null) {
//         expirationDate = DateFormat('yyyy-MM-dd').parse(expirationDateString);
//       }
//
//       print('Expiration Date: $expirationDate');
//
//       DateTime now = DateTime.now();
//       String currentDate = DateFormat('yyyy-MM-dd').format(now);
//       print(currentDate);
//
//       bool isPlanActive = expirationDate != null && expirationDate.isAfter(now);
//
//       if (isPlanActive) {
//         print('The plan is active.');
//       } else {
//         print('The plan is not active.');
//       }
//       Navigator.pushReplacement(
//           context,
//           MaterialPageRoute(
//               builder: (context) =>
//               isPlanActive ? Dashboard() : PlanPurchaseCard()));
//     } else {
//       print('Failed to check token');
//     }
//   }
//
//   Future<void> checkTokenStaff(String token) async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     // String? token = prefs.getString('token');
//
//     final response = await apiPost(
//       Uri.parse('${Api_url}/api/staffmember/token_check'),
//       headers: {
//         // "authorization": "CRM $token",
//         //"id":"CRM $id",
//         "Content-Type": "application/json"
//       },
//       body: json.encode({"token": token}),
//     );
//     print(response.body);
//     final jsonData = json.decode(response.body);
//     if (jsonData['id'] != "") {
//       print(jsonData);
//       //prefs.setString('checkedToken',jsonData["token"]);
//       // String? adminId = jsonData['data']['admin_id'];
//       // print('Admin ID: $adminId');
//       // await Provider.of<StaffPermissionProvider>(context, listen: false).fetchPermissions();
//       prefs.setString("staff_id", jsonData["staffmember_id"]);
//       prefs.setString("role", "Staffmember");
//       print(jsonData["staffmember_firstName"]);
//       prefs.setString('companyName', selectedCompany!);
//       prefs.setString('checkedToken', token);
//       //  prefs.setString('adminId', adminId!);
//       String stafffirstname = jsonData['staffmember_name'];
//       List<String> firstname = stafffirstname.split(" ");
//       print(firstname);
//       prefs.setString('first_name', firstname.first);
//       prefs.setString('last_name', firstname[1]);
//       await Provider.of<StaffPermissionProvider>(context, listen: false)
//           .fetchPermissions();
//       Navigator.push(
//           context, MaterialPageRoute(builder: (context) => Dashboard_staff()));
//     } else {
//       print('Failed to check token');
//     }
//   }
//
//   Future<void> checkTokenTenant(String token) async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     // String? token = prefs.getString('token');
//     // List<Map<String,dynamic>> selectedroledata = roles.where((element) => element["role_id"] == selectedRole).toList();
//     // String rolename  =selectedroledata.first["role_name"];
//
//     final response = await apiPost(
//       Uri.parse('${Api_url}/api/tenant/token_check'),
//       headers: {
//         // "authorization": "CRM $token",
//         //"id":"CRM $id",
//         "Content-Type": "application/json"
//       },
//       body: json.encode({"token": token}),
//     );
//     print(response.body);
//     final jsonData = json.decode(response.body);
//     if (jsonData['id'] != "") {
//       print(jsonData);
//       //prefs.setString('checkedToken',jsonData["token"]);
//       // String? adminId = jsonData['data']['admin_id'];
//       // print('Admin ID: $adminId');
//       prefs.setString("role", "Tenant");
//       prefs.setString('companyName', selectedCompany!);
//       print(jsonData["tenant_firstName"]);
//       prefs.setString("tenant_id", jsonData["tenant_id"]);
//       prefs.setString('checkedToken', token);
//       //  prefs.setString('adminId', adminId!);
//       prefs.setString('first_name', jsonData['tenant_firstName']);
//       prefs.setString('last_name', jsonData['tenant_lastName']);
//       prefs.setString('email', jsonData['tenant_email']);
//       await Provider.of<PermissionProvider>(context, listen: false)
//           .fetchPermissions();
//       Navigator.push(context,
//           MaterialPageRoute(builder: (context) => Dashboard_tenants()));
//     } else {
//       print('Failed to check token');
//     }
//   }
//
//   Future<void> checkTokenVendor(String token) async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     // String? token = prefs.getString('token');
//     // List<Map<String,dynamic>> selectedroledata = roles.where((element) => element["role_id"] == selectedRole).toList();
//     // String rolename  =selectedroledata.first["role_name"];
//     // print('${Api_url}/api/${rolename.toLowerCase()}/token_check');
//     final response = await apiPost(
//       Uri.parse('${Api_url}/api/vendor/token_check'),
//       headers: {
//         // "authorization": "CRM $token",
//         //"id":"CRM $id",
//         "Content-Type": "application/json"
//       },
//       body: json.encode({"token": token}),
//     );
//     print("vendor token ${response.body}");
//     final jsonData = json.decode(response.body);
//     if (jsonData['id'] != "") {
//       print(jsonData);
//       //prefs.setString('checkedToken',jsonData["token"]);
//       // String? adminId = jsonData['data']['admin_id'];
//       // print('Admin ID: $adminId');
//       String stafffirstname = jsonData['vendor_name'];
//       List<String> firstname = stafffirstname.split(" ");
//       print(firstname);
//       await Provider.of<PermissionProvider>(context, listen: false)
//           .fetchPermissions();
//       prefs.setString('first_name', firstname.first);
//       prefs.setString('last_name', firstname[1]);
//       prefs.setString('companyName', selectedCompany!);
//       prefs.setString("role", "Vendor");
//       print(jsonData["vendor_firstName"]);
//       prefs.setString("vendor_id", jsonData["vendor_id"]);
//       prefs.setString('checkedToken', token);
//       //  prefs.setString('adminId', adminId!);
//       // prefs.setString('first_name', jsonData['${rolename.toLowerCase()}_firstName']);
//       // prefs.setString('last_name', jsonData['${rolename.toLowerCase()}_lastName']);
//       prefs.setString('email', jsonData['vendor_email']);
//       // prefs.setString('checkedToken', token);
//       //  prefs.setString('adminId', adminId!);
//
//       Navigator.push(context,
//           MaterialPageRoute(builder: (context) => MainScreen()));
//     } else {
//       print('Failed to check token');
//     }
//   }
//
//   Future<void> checkCompany(String token) async {
//     setState(() {
//       loading = true;
//     });
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     // String? token = prefs.getString('token');
//     print("${Uri.parse('${Api_url}/api/admin/check_company/${token}')}");
//     final response = await apiGet(
//       Uri.parse('${Api_url}/api/admin/check_company/${token}'),
//       headers: {
//         // "authorization": "CRM $token",
//         //"id":"CRM $id",
//         "Content-Type": "application/json"
//       },
//       // body: json.encode({"token": token}),
//     );
//     print(response.body);
//     final jsonData = json.decode(response.body);
//     //if (jsonData["data"]['id'] != "") {
//     print(jsonData);
//     if (jsonData["statusCode"] == 200) {
//       //prefs.setString('checkedToken',jsonData["token"]);
//       String? adminId = jsonData['data']['admin_id'];
//       print('Admin ID: $adminId');
//       prefs.setString('checkedToken', token);
//       prefs.setString('adminId', adminId!);
//
//       loginsubmit_usingrole(adminId);
//     } else {
//       setState(() {
//         loading = false;
//       });
//     }
//   }
//
//   Future<void> loginsubmit_usingrole(String adminId) async {
//     setState(() {
//       loading = true;
//     });
//     // List<Map<String,dynamic>> selectedroledata = roles.where((element) => element["role_id"] == selectedRole).toList();
//     String rolename = selectedrole;
//
//     print("${Api_url}/api/${rolename.toLowerCase()}/login");
//     // print({"email": email.text, "password": password.text,"admin_id":adminId,"company":company.text});
//     final response = await apiPost(
//         Uri.parse('${Api_url}/api/${rolename.toLowerCase()}/login'),
//         body: {
//           "email": email.text,
//           "password": password.text,
//           "admin_id": adminId,
//           "company": selectedCompany
//         });
//     print(response.body);
//     final jsonData = json.decode(response.body);
//     if (jsonData["statusCode"] == 200) {
//       print(jsonData);
//       SharedPreferences prefs = await SharedPreferences.getInstance();
//       prefs.setBool('isAuthenticated', true);
//       prefs.setString('token', jsonData["token"]);
//       prefs.setString('adminId', adminId);
//       print(rolename);
//       if (rolename == "staffmember") await checkTokenStaff(jsonData["token"]);
//       if (rolename == "tenant") await checkTokenTenant(jsonData["token"]);
//       if (rolename == "vendor") await checkTokenVendor(jsonData["token"]);
//
//       //  await checkToken("token", "id");
//       // Navigator.push(
//       //     context, MaterialPageRoute(builder: (context) => Dashboard()));
//
//       setState(() {
//         loading = false;
//       });
//     } else {
//       Fluttertoast.showToast(msg: _formatErrorMessage(jsonData["message"]));
//       setState(() {
//         loading = false;
//       });
//     }
//   }
//
//   Future<void> loginsubmit() async {
//     setState(() {
//       loading = true;
//     });
//     final response = await apiPost(Uri.parse('${Api_url}/api/admin/login'),
//         body: {"email": email.text, "password": password.text});
//     print(response.body);
//     final jsonData = json.decode(response.body);
//     if (jsonData["statusCode"] == 200) {
//       print(jsonData);
//       SharedPreferences prefs = await SharedPreferences.getInstance();
//       prefs.setBool('isAuthenticated', true);
//       prefs.setString('token', jsonData["token"]);
//
//       await checkToken(jsonData["token"]);
//       //  await checkToken("token", "id");
//       // Navigator.push(
//       //     context, MaterialPageRoute(builder: (context) => Dashboard()));
//
//       setState(() {
//         loading = false;
//       });
//     } else {
//       Fluttertoast.showToast(msg: _formatErrorMessage(jsonData["message"]));
//       setState(() {
//         loading = false;
//       });
//     }
//   }
// }
//
// class SingleSelectionButtons extends StatefulWidget {
//   final List<Map<String, String>> buttonOptions;
//   final Function(int index) onSelected;
//
//   const SingleSelectionButtons({
//     super.key,
//     required this.buttonOptions,
//     required this.onSelected,
//   });
//
//   @override
//   _SingleSelectionButtonsState createState() => _SingleSelectionButtonsState();
// }
//
// class _SingleSelectionButtonsState extends State<SingleSelectionButtons> {
//   int _selectedIndex = -1;
//
//   @override
//   Widget build(BuildContext context) {
//     return LayoutBuilder(
//         builder: (context,contraints) {
//
//           if(contraints.maxWidth > 500){
//             return Container(
//               width: MediaQuery.of(context).size.width * .8,
//               child: Wrap(
//                 spacing: 8.0,
//                 runSpacing: 8.0,
//                 alignment: WrapAlignment.start,
//                 children: widget.buttonOptions.map((option) {
//                   final index = widget.buttonOptions.indexOf(option);
//                   return SizedBox(
//                     width: 320, // Adjusted width to make the button smaller
//                     child: ElevatedButton(
//                       onPressed: () {
//                         setState(() {
//                           _selectedIndex = index;
//                           print(index);
//                         });
//                         widget.onSelected(index);
//                       },
//                       child: Row(
//                         children: [
//                           Icon(
//                             _selectedIndex == index
//                                 ? Icons.check_circle
//                                 : Icons.radio_button_unchecked,
//                             color: _selectedIndex == index ? Colors.white : Colors.grey,
//                           ),
//                           SizedBox(width: 5.0),
//                           Column(
//                             crossAxisAlignment: CrossAxisAlignment.start,
//                             children: [
//                               Text(
//                                 option["company"]!,
//                                 style: TextStyle(
//                                     fontWeight: FontWeight.bold,
//                                     color: _selectedIndex == index ? Colors.white : Colors.black,fontSize: 18
//                                 ),
//                               ),
//                               Text(
//                                 capitalizeFirstLetter( option["role"]!),
//                                 style: TextStyle(
//                                     fontWeight: FontWeight.bold,
//                                     color: _selectedIndex == index ? Colors.white : Colors.black,fontSize: 16
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ],
//                       ),
//                       style: ElevatedButton.styleFrom(
//                         padding: EdgeInsets.symmetric(vertical: 10,horizontal: 5),
//                         foregroundColor: _selectedIndex == index
//                             ? Colors.white
//                             : blueColor,
//                         backgroundColor: _selectedIndex == index
//                             ? blueColor
//                             : Colors.white,
//                         shape: RoundedRectangleBorder(
//                           borderRadius: BorderRadius.circular(8.0),
//                         ),
//                         side: BorderSide(
//                           color: _selectedIndex == index
//                               ? blueColor
//                               : Colors.grey,
//                         ),
//                       ),
//                     ),
//                   );
//                 }).toList(),
//               ),
//             );
//           }
//           return Container(
//             width: 350,
//             child: Wrap(
//               spacing: 8.0,
//               runSpacing: 8.0,
//               alignment: WrapAlignment.center,
//               children: widget.buttonOptions.map((option) {
//                 final index = widget.buttonOptions.indexOf(option);
//                 return SizedBox(
//                   width: 320, // Adjusted width to make the button smaller
//                   child: ElevatedButton(
//                     onPressed: () {
//                       setState(() {
//                         _selectedIndex = index;
//                         print(index);
//                       });
//                       widget.onSelected(index);
//                     },
//                     child: Row(
//                       children: [
//                         Icon(
//                           _selectedIndex == index
//                               ? Icons.check_circle
//                               : Icons.radio_button_unchecked,
//                           color: _selectedIndex == index ? Colors.white : Colors.grey,
//                         ),
//                         SizedBox(width: 5.0),
//                         Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             Text(
//                               option["company"]!,
//                               style: TextStyle(
//                                   fontWeight: FontWeight.bold,
//                                   color: _selectedIndex == index ? Colors.white : Colors.black,fontSize: 16
//                               ),
//                             ),
//                             Text(
//                               capitalizeFirstLetter( option["role"]!),
//                               style: TextStyle(
//                                   fontWeight: FontWeight.bold,
//                                   color: _selectedIndex == index ? Colors.white : Colors.black,fontSize: 12
//                               ),
//                             ),
//                           ],
//                         ),
//                       ],
//                     ),
//                     style: ElevatedButton.styleFrom(
//                       padding: EdgeInsets.symmetric(vertical: 10,horizontal: 5),
//                       foregroundColor: _selectedIndex == index
//                           ? Colors.white
//                           : blueColor,
//                       backgroundColor: _selectedIndex == index
//                           ? blueColor
//                           : Colors.white,
//                       shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.circular(8.0),
//                       ),
//                       side: BorderSide(
//                         color: _selectedIndex == index
//                             ? blueColor
//                             : Colors.grey,
//                       ),
//                     ),
//                   ),
//                 );
//               }).toList(),
//             ),
//           );
//         }
//     );
//   }
//
//   String capitalizeFirstLetter(String input) {
//     if (input.isEmpty) return input;
//     return input[0].toUpperCase() + input.substring(1);
//   }
// }*/

import 'dart:async';
import 'dart:convert';

import 'package:email_validator/email_validator.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:three_zero_two_property/screens/Signup/signup_screen.dart';
import 'package:http/http.dart' as http;
import 'package:three_zero_two_property/services/api_helpers.dart';

import '../../StaffModule/repository/staffpermission_provider.dart';
import '../../StaffModule/screen/dashboard.dart';
import '../../TenantsModule/repository/permission_provider.dart';
import '../../TenantsModule/screen/dashboard.dart';
import '../../VendorModule/repository/vendor_permission.dart';
import '../../VendorModule/screen/mainScreen.dart';
import '../../constant/constant.dart';
import '../../provider/Plan Purchase/plancheckProvider.dart';
import '../../provider/dateProvider.dart';
import '../Dashboard/dashboard_one.dart';
import '../Password/forgotpassword.dart';
import '../Plans/PlansPurcharCard.dart';

class Login_Screen extends StatefulWidget {
  const Login_Screen({super.key});

  @override
  State<Login_Screen> createState() => _Login_ScreenState();
}

class _Login_ScreenState extends State<Login_Screen> {
  TextEditingController password = TextEditingController();
  TextEditingController company = TextEditingController();
  TextEditingController email = TextEditingController();
  TextEditingController twoFA = TextEditingController();

  bool passworderror = false;
  bool visiable_password = true;
  bool emailerror = false;
  bool companyerror = false;
  bool roleerror = false;
  bool required2FA = false;

  bool requires2FA = false;
  bool backupcode = false;
  bool timerStart = false;
  bool switchtoBackupcode = false;

  // Countdown for the 2FA verification code, mirroring the Profile screen and
  // web: 10 minutes to use the code, and Resend unlocks once the first 60
  // seconds have passed (i.e. at 540s remaining).
  Timer? _twoFATimer;
  final ValueNotifier<int> twoFASeconds = ValueNotifier<int>(0);

  // The login body that produced the 2FA challenge. The two login paths send
  // different shapes (one maps the role and includes company), so Resend
  // replays this instead of rebuilding it and guessing.
  Map<String, dynamic>? _last2FALoginBody;
  bool _isResending2FA = false;

  // True only when the countdown actually ran out. Stopping the timer on a
  // successful verify must NOT read as expired.
  bool _twoFAExpired = false;

  /// True while the 2FA step is on screen AND its code has expired.
  ///
  /// The code entry field and the submit button are shared with the ordinary
  /// e-mail/password login, so they must only grey out when the 2FA step is the
  /// thing actually being shown — gating on `_twoFAExpired` alone would disable
  /// the normal login button too.
  ///
  /// Web disables both the field and the action the moment the countdown ends,
  /// and the profile screen already does the same (Profile_screen.dart:
  /// `enabled: !is2FACodeExpired` and `onPressed: … is2FACodeExpired ? null`).
  /// The login screen previously stayed visually active and only rejected the
  /// code on submit, so the two screens read differently for the same state.
  /// Resending clears `_twoFAExpired`, which restores both automatically.
  bool get _twoFALocked => requires2FA && _twoFAExpired;

  String OtpId = "";

  String _email = '';
  bool _isEmailSubmitted = false;
  bool _hasMultipleCompanies = false;
  bool loading = false;
  List<Map<String, String>> _companies = [];
  String _selectedCompany = '';
  String _password = '';
  String selectedrole = '';
  String passwordmessage = "";
  String companymessage = "";
  String emailmessage = "";
  String rolemessage = "";
  String required2FAmessage = "";
  String twoFAMessage = "";
  // String get email => _email;
  bool get isEmailSubmitted => _isEmailSubmitted;
  bool get hasMultipleCompanies => _hasMultipleCompanies;
  List<Map<String, String>> get companies => _companies;
  String get selectedCompany => _selectedCompany;
  // String get password => _password;
  String? adminId;
  String? userId;
  String? userName;
  void setEmail(String email) {
    setState(() {
      if (_email != email) {
        _email = email;
        _isEmailSubmitted = false;
        _hasMultipleCompanies = false;
        _companies = [];
        _selectedCompany = '';
        _password = '';
      }
    });
  }

  void selectCompany(String company, String role, String admin_id,
      String user_id, String userName) {
    _selectedCompany = company;
    selectedrole = role;
    adminId = admin_id;
    userId = user_id;
    userName = userName;
    // Set role when selecting company
    setState(() {});
  }

  void login() {
    // Implement login logic here
  }

  void setPassword(String password) {
    _password = password;
  }

  // Helper function to format error messages for better user experience
  String _formatErrorMessage(String apiMessage) {
    // Convert technical error messages to user-friendly ones
    if (apiMessage.toLowerCase().contains('invalid') &&
        (apiMessage.toLowerCase().contains('password') ||
            apiMessage.toLowerCase().contains('admin'))) {
      return "Login failed. Please check your credentials.";
    }
    if (apiMessage.toLowerCase().contains('email') &&
        apiMessage.toLowerCase().contains('not found')) {
      return "Email address not found.";
    }
    if (apiMessage.toLowerCase().contains('account') &&
        apiMessage.toLowerCase().contains('disabled')) {
      return "Your account has been disabled. Please contact support.";
    }
    if (apiMessage.toLowerCase().contains('network') ||
        apiMessage.toLowerCase().contains('connection')) {
      return "Network error. Please check your connection and try again.";
    }
    // Return the original message if no specific formatting is needed
    return apiMessage;
  }

  // NEW FLOW: Check credentials with email and password together
  Future<void> checkCredentials() async {
    setState(() {
      loading = true;
    });

    // Validate email and password
    if (email.text.trim().isEmpty) {
      setState(() {
        emailerror = true;
        emailmessage = "Email is required";
        loading = false;
      });
      return;
    }

    if (!EmailValidator.validate(email.text.trim())) {
      setState(() {
        emailerror = true;
        emailmessage = "Email is not valid";
        loading = false;
      });
      return;
    }

    if (password.text.trim().isEmpty) {
      setState(() {
        passworderror = true;
        passwordmessage = "Password is required";
        loading = false;
      });
      return;
    }

    setState(() {
      emailerror = false;
      passworderror = false;
    });


    try {
      final response = await apiPost(
        Uri.parse('$Api_url/api/auth/check-credentials'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email.text.trim(),
          'password': password.text.trim(),
        }),
      );


      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        bool shouldLogin = data['shouldLogin'] ?? false;
        List<dynamic> roles = data['data'] ?? [];

        if (roles.isEmpty) {
          Fluttertoast.showToast(msg: "Invalid email or password.");
          setState(() {
            loading = false;
          });
          return;
        }

        if (shouldLogin) {
          // Single account found - auto login
          setState(() {
            if (roles[0]['role'] == "admin") {
              _hasMultipleCompanies = false;
              adminId = roles[0]["admin_id"];
              userId = roles[0]["user_id"];
              userName = roles[0]["userName"];
              selectedrole = roles[0]['role'];
            } else {
              _hasMultipleCompanies = false;
              adminId = roles[0]["admin_id"];
              _selectedCompany = roles[0]['company_name'];
              userId = roles[0]["user_id"];
              userName = roles[0]["userName"];
              selectedrole = roles[0]['role'];
            }
            _isEmailSubmitted = true;
            loading = false;
          });

          // Proceed with login
          if (selectedrole == "admin") {
            await loginsubmit();
          } else {
            await checkCompany(_selectedCompany);
          }
        } else {
          // Multiple accounts found - show selection
          setState(() {
            _hasMultipleCompanies = true;
            _companies = roles
                .map<Map<String, String>>((role) => {
                      'company': role['company_name'],
                      'role': role['role'],
                      'admin_id': role['admin_id'],
                      'user_id': role['user_id'],
                      'userName': role['userName'],
                    })
                .toList();
            _isEmailSubmitted = true;
            loading = false;
          });
        }
      } else {
        final data = jsonDecode(response.body);
        Fluttertoast.showToast(
            msg: _formatErrorMessage(
                data['message'] ?? "Invalid email or password."));
        setState(() {
          loading = false;
        });
      }
    } catch (e) {
      logError("Error checking credentials: $e");
      Fluttertoast.showToast(msg: "Network error. Please try again.");
      setState(() {
        loading = false;
      });
    }
  }

  // OLD FLOW: Commented out for future reference
  // Future<void> submitEmail() async {
  //   print("Calling  ${email.text}");
  //   // Make API call to check email
  //   final response = await apiPost(
  //     Uri.parse('$Api_url/api/auth/check_role'),
  //     // Uri.parse('$Api_url/api/admin/check_role'),
  //     headers: {'Content-Type': 'application/json'},
  //     body: jsonEncode({'email': email.text.trim()}),
  //   );
  //   print(response.body);
  //   if (response.statusCode == 200) {
  //     final data = jsonDecode(response.body);
  //     List<dynamic> roles = data['data'];
  //     print(roles.length);
  //     if (roles.isEmpty) {
  //       Fluttertoast.showToast(msg: "Email address not found.");
  //     } else {
  //       if (roles.length > 1) {
  //         setState(() {
  //           _hasMultipleCompanies = true;
  //           _companies = roles
  //               .map<Map<String, String>>((role) => {
  //                     'company': role['company_name'],
  //                     'role': role['role'],
  //                     'admin_id': role['admin_id'],
  //                     'user_id': role['user_id'],
  //                     'userName': role['userName'],
  //                   })
  //               .toList();
  //           print("roles $roles");
  //           _isEmailSubmitted = true;
  //         });
  //       } else {
  //         setState(() {
  //           if (roles[0]['role'] == "admin") {
  //             _hasMultipleCompanies = false;
  //             adminId = roles[0]["admin_id"];
  //             userId = roles[0]["user_id"];
  //             userName = roles[0]["userName"];

  //             //_selectedCompany = roles[0]['company_name'];
  //             selectedrole = roles[0]['role']; // Set role directly
  //             _isEmailSubmitted = true;
  //           } else {
  //             print(roles[0]['role']);
  //             _hasMultipleCompanies = false;
  //             adminId = roles[0]["admin_id"];
  //             _selectedCompany = roles[0]['company_name'];
  //             userId = roles[0]["user_id"];
  //             userName = roles[0]["userName"];
  //             print(userId);
  //             selectedrole = roles[0]['role']; // Set role directly
  //             _isEmailSubmitted = true;
  //           }
  //         });
  //       }
  //     }
  //   } else {
  //     Fluttertoast.showToast(msg: "Email address not found.");
  //   }
  // }

  bool isChecked = false;
  bool rememberMe = false;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  @override
  void dispose() {
    _twoFATimer?.cancel();
    twoFASeconds.dispose();
    super.dispose();
  }

  /// Starts the 10 minute countdown for a freshly issued 2FA code.
  void _start2FATimer() {
    _twoFATimer?.cancel();
    twoFASeconds.value = 600;
    if (_twoFAExpired) {
      setState(() {
        _twoFAExpired = false;
      });
    }
    _twoFATimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (twoFASeconds.value > 1) {
        twoFASeconds.value--;
      } else {
        twoFASeconds.value = 0;
        timer.cancel();
        twoFA.clear();
        if (mounted) {
          setState(() {
            _twoFAExpired = true;
          });
        }
        Fluttertoast.showToast(
          msg: 'Verification code expired',
          backgroundColor: Colors.red,
        );
      }
    });
  }

  /// Stops the countdown without marking the code expired — used once the code
  /// has been accepted.
  void _stop2FATimer() {
    _twoFATimer?.cancel();
    twoFASeconds.value = 0;
  }

  String _twoFATimerString() {
    if (twoFASeconds.value <= 0) return '0m 0s';
    return '${twoFASeconds.value ~/ 60}m ${twoFASeconds.value % 60}s';
  }

  /// Resend re-posts the login request and reads the fresh `otp_id` out of the
  /// 205 response — the same approach web takes, as there is no dedicated
  /// resend endpoint for login 2FA.
  Future<void> _resend2FACode() async {
    // Locked for the first 60 seconds after a code is issued.
    if (twoFASeconds.value > 540) return;
    if (_isResending2FA || _last2FALoginBody == null) return;

    setState(() {
      _isResending2FA = true;
    });

    final response = await apiPost(Uri.parse('${Api_url}/api/auth/login'),
        body: _last2FALoginBody);
    final jsonData = json.decode(response.body);

    setState(() {
      _isResending2FA = false;
    });

    if (jsonData["statusCode"] == 205) {
      setState(() {
        requires2FA = true;
        if (jsonData["data"] != null && jsonData["data"]["otp_id"] != null) {
          OtpId = jsonData["data"]["otp_id"];
        }
      });
      twoFA.clear();
      _start2FATimer();
      Fluttertoast.showToast(msg: "New verification code sent");
    } else {
      final dynamic message = jsonData["message"];
      Fluttertoast.showToast(
          msg: message is String
              ? _formatErrorMessage(message)
              : "Failed to resend verification code");
    }
  }

  /// Timer text plus the Resend control, shown under the 2FA code field.
  Widget _build2FATimerRow() {
    return ValueListenableBuilder<int>(
      valueListenable: twoFASeconds,
      builder: (context, value, child) {
        // Disabled during the 60s cooldown and while a resend is in flight —
        // same gating web applies to its resend control.
        final bool canResend = value <= 540 && !_isResending2FA;
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (value > 0)
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: "Code will expire in ",
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    TextSpan(
                      text: _twoFATimerString(),
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              )
            else if (_twoFAExpired)
              Text(
                "Code expired",
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              )
            else
              const SizedBox.shrink(),
            GestureDetector(
              onTap: canResend ? _resend2FACode : null,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.refresh,
                        color: canResend ? blueColor : Colors.grey.shade600,
                        size: 16),
                    const SizedBox(width: 4),
                    Text(
                      "Resend Code",
                      style: TextStyle(
                        fontSize: 14,
                        color: canResend ? blueColor : Colors.grey.shade600,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // Load saved credentials if Remember Me was previously enabled
  Future<void> _loadSavedCredentials() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool? savedRememberMe = prefs.getBool('rememberMe');
    String? savedEmail = prefs.getString('savedEmail');
    String? savedPassword = prefs.getString('savedPassword');


    if (savedRememberMe == true &&
        savedEmail != null &&
        savedPassword != null) {
      setState(() {
        rememberMe = true;
        isChecked = true;
        email.text = savedEmail;
        password.text = savedPassword;
        // Fields are pre-filled only; user must tap Login to authenticate.
      });
    } else {
    }
  }

  // Save credentials to SharedPreferences
  Future<void> _saveCredentials() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (rememberMe) {
      await prefs.setBool('rememberMe', true);
      await prefs.setString('savedEmail', email.text.trim());
      await prefs.setString('savedPassword', password.text.trim());
    } else {
      await prefs.setBool('rememberMe', false);
      await prefs.remove('savedEmail');
      await prefs.remove('savedPassword');
    }
  }

  // Clear saved credentials (call this on logout if needed)
  static Future<void> clearSavedCredentials() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('rememberMe', false);
    await prefs.remove('savedEmail');
    await prefs.remove('savedPassword');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
          padding: const EdgeInsets.all(0.0),
          child: LayoutBuilder(builder: (context, contraints) {
            if (contraints.maxWidth > 500) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.1,
                  ),
                  Image(
                    image: const AssetImage('assets/images/logo.png'),
                    height: MediaQuery.of(context).size.height * 0.07,
                    width: MediaQuery.of(context).size.width * 0.9,
                    fit: BoxFit.fill,
                  ),
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.025,
                  ),
                  // // Welcome
                  // Center(
                  //   child: Text(
                  //     "Welcome to CRM",
                  //     style: TextStyle(
                  //       color: Colors.black,
                  //       fontWeight: FontWeight.bold,
                  //       fontSize: MediaQuery.of(context).size.width * 0.04,
                  //     ),
                  //   ),
                  // ),
                  // SizedBox(
                  //   height: MediaQuery.of(context).size.height * 0.02,
                  // ),
                  // Login text
                  Center(
                    child: Text(
                      "Sign In",
                      style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: MediaQuery.of(context).size.width * 0.046),
                    ),
                  ),
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.05,
                  ),

                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.01,
                  ),
                  // Email
                  Row(
                    children: [
                      SizedBox(
                        width: MediaQuery.of(context).size.width * 0.099,
                      ),
                      Expanded(
                        flex: 1,
                        child: Container(
                          height: 60,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: const Color.fromRGBO(196, 196, 196, .3),
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
                                      _hasMultipleCompanies = false;
                                      // Don't clear password anymore - both fields shown together
                                    });
                                  },
                                  style: const TextStyle(fontSize: 20),
                                  controller: email,
                                  cursorColor: blueColor,
                                  decoration: InputDecoration(
                                    enabledBorder: emailerror
                                        ? OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            borderSide: const BorderSide(
                                                color: Colors
                                                    .red), // Set border color here
                                          )
                                        : InputBorder.none,
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.all(14),
                                    prefixIcon: Container(
                                      height: 25,
                                      width: 25,
                                      padding: const EdgeInsets.all(13),
                                      child: FaIcon(
                                        FontAwesomeIcons.envelope,
                                        size: 25,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    hintText: "Email Address",
                                    hintStyle: TextStyle(
                                        color: Colors.grey[600], fontSize: 20),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(
                        width: MediaQuery.of(context).size.width * 0.095,
                      ),
                    ],
                  ),
                  emailerror
                      ? Center(
                          child: Text(
                          emailmessage,
                          style: const TextStyle(
                            color: Colors.red,
                          ),
                        ))
                      : Container(),

                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.025,
                  ),
                  // Password field - now shown from the start
                  Row(
                    children: [
                      SizedBox(
                        width: MediaQuery.of(context).size.width * 0.099,
                      ),
                      Expanded(
                        flex: 1,
                        child: Container(
                          height: 60,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: const Color.fromRGBO(196, 196, 196, .3),
                          ),
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: TextField(
                                  keyboardType: TextInputType.text,
                                  onChanged: (value) {
                                    setState(() {
                                      passworderror = false;
                                      _isEmailSubmitted = false;
                                      _hasMultipleCompanies = false;
                                    });
                                  },
                                  style: const TextStyle(fontSize: 20),
                                  controller: password,
                                  obscureText: visiable_password,
                                  cursorColor: blueColor,
                                  decoration: InputDecoration(
                                    enabledBorder: passworderror
                                        ? OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            borderSide: const BorderSide(
                                                color: Colors
                                                    .red), // Set border color here
                                          )
                                        : InputBorder.none,
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.all(14),
                                    prefixIcon: Container(
                                      height: 25,
                                      width: 25,
                                      // color: Colors.blue,
                                      padding: const EdgeInsets.all(13),
                                      child: FaIcon(
                                        FontAwesomeIcons.lock,
                                        size: 25,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    hintText: "Password",
                                    hintStyle: TextStyle(
                                        color: Colors.grey[600], fontSize: 20),
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
                                        color: Colors.grey[600],
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
                      ? Center(
                          child: Text(
                          passwordmessage,
                          style: const TextStyle(color: Colors.red),
                        ))
                      : Container(),
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.025,
                  ),
                  // Container(
                  //   color: Colors.orange,
                  //   height: 120,
                  //   width: 120,
                  // ),

                  // Forgot password
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) =>
                                      const ForgotPassword()));
                        },
                        child: Text(
                          "Forgot password?",
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize:
                                  MediaQuery.of(context).size.width * 0.02,
                              color: const Color(0xFF152B51)),
                        ),
                      ),
                      SizedBox(
                        width: MediaQuery.of(context).size.width * 0.099,
                      ),
                    ],
                  ),
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.025,
                  ),

                  // Company selection (shown when multiple accounts found)
                  if (hasMultipleCompanies) ...[
                    SingleSelectionButtons(
                      buttonOptions: companies,
                      onSelected: (index) {
                        setState(() {
                          adminId = companies[index]['admin_id'];
                        });
                        selectCompany(
                            companies[index]["company"]!,
                            companies[index]["role"]!,
                            companies[index]["admin_id"]!,
                            companies[index]["user_id"]!,
                            companies[index]["userName"]!);
                      },
                    ),
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.025,
                    ),
                  ],

                  // 2FA field (if required)
                  if (requires2FA) ...[
                    Row(
                      children: [
                        SizedBox(
                          width: MediaQuery.of(context).size.width * 0.099,
                        ),
                        Expanded(
                          flex: 1,
                          child: Container(
                            height: 60,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              color: const Color.fromRGBO(196, 196, 196, .3),
                            ),
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: TextField(
                                    keyboardType: TextInputType.text,
                                    // Greyed out once the countdown ends, the
                                    // same as the profile screen and web.
                                    // Resending clears the flag and re-enables
                                    // it automatically.
                                    enabled: !_twoFALocked,
                                    onChanged: (value) {
                                      setState(() {
                                        required2FA = false;
                                      });
                                    },
                                    style: const TextStyle(fontSize: 20),
                                    controller: twoFA,
                                    cursorColor: blueColor,
                                    decoration: InputDecoration(
                                      enabledBorder: required2FA
                                          ? OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              borderSide: const BorderSide(
                                                  color: Colors.red),
                                            )
                                          : InputBorder.none,
                                      border: InputBorder.none,
                                      contentPadding: const EdgeInsets.all(14),
                                      hintText: switchtoBackupcode
                                          ? "Enter backup code"
                                          : "Enter 6 digit code",
                                      hintStyle: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 20),
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
                    required2FA
                        ? Center(
                            child: Text(
                            required2FAmessage,
                            style: const TextStyle(color: Colors.red),
                          ))
                        : Container(),
                    // Code expiry countdown + Resend, matching the Profile
                    // screen. A backup code neither expires nor can be
                    // resent, so this is OTP mode only.
                    if (!switchtoBackupcode)
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal:
                              MediaQuery.of(context).size.width * 0.099,
                          vertical: 8,
                        ),
                        child: _build2FATimerRow(),
                      ),
                    if (backupcode) ...[
                      SizedBox(
                        height: 10,
                      ),
                      if (!switchtoBackupcode)
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              switchtoBackupcode = !switchtoBackupcode;
                            });
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                "Use backup code instead",
                                style: TextStyle(
                                  fontSize:
                                      MediaQuery.of(context).size.width * 0.02,
                                  color: const Color(0xFF152B51),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(
                                width:
                                    MediaQuery.of(context).size.width * 0.099,
                              ),
                            ],
                          ),
                        ),
                      if (switchtoBackupcode)
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              switchtoBackupcode = !switchtoBackupcode;
                            });
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                "Use OTP instead",
                                style: TextStyle(
                                  fontSize:
                                      MediaQuery.of(context).size.width * 0.02,
                                  color: const Color(0xFF152B51),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(
                                width:
                                    MediaQuery.of(context).size.width * 0.099,
                              ),
                            ],
                          ),
                        )
                    ],
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.025,
                    ),
                  ],

                  // Submit/Login button
                  if (!hasMultipleCompanies ||
                      (hasMultipleCompanies && selectedrole.isNotEmpty) ||
                      requires2FA)
                    GestureDetector(
                      onTap: () async {
                        // Handle 2FA verification
                        if (requires2FA) {
                          if (twoFA.text.trim().isEmpty) {
                            setState(() {
                              required2FA = true;
                              required2FAmessage = "Code is required";
                            });
                            return;
                          }
                          // Web requires the full 6 digits before verifying.
                          if (!switchtoBackupcode &&
                              twoFA.text.trim().length != 6) {
                            setState(() {
                              required2FA = true;
                              required2FAmessage =
                                  "Please enter the complete 6-digit code";
                            });
                            return;
                          }
                          if (_twoFAExpired) {
                            Fluttertoast.showToast(
                                msg:
                                    "Verification code expired. Please resend the code.");
                            return;
                          }
                          await loginsubmitverify2fa();
                          return;
                        }

                        if (hasMultipleCompanies && selectedrole.isEmpty) {
                          Fluttertoast.showToast(
                              msg: "Please select the company");
                          return;
                        }

                        if (!hasMultipleCompanies) {
                          // First time - check credentials
                          await checkCredentials();
                        } else {
                          // Company selected - proceed with login
                          if (emailerror == false && passworderror == false) {
                            if (selectedrole == "admin") {
                              await loginsubmit();
                            } else {
                              await checkCompany(selectedCompany);
                            }
                          }
                        }
                      },
                      child: Center(
                        child: Container(
                          height: MediaQuery.of(context).size.height * 0.045,
                          width: MediaQuery.of(context).size.width * 0.8,
                          decoration: BoxDecoration(
                            // Greyed out while the 2FA code is expired, so the
                            // action reads as unavailable rather than looking
                            // tappable and failing on submit. Matches the
                            // profile screen's disabled Verify button. The
                            // guard inside onTap stays as the safety net.
                            color: _twoFALocked
                                ? Colors.grey
                                : const Color(0xFF152B51),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: loading
                                ? const SpinKitFadingCircle(
                                    color: Colors.white,
                                    size: 40.0,
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        requires2FA
                                            ? "Verify & Login"
                                            : "Login",
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: MediaQuery.of(context)
                                                    .size
                                                    .width *
                                                0.03),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    ),

                  // Register now
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.04,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Don't have an account ? ",
                        style: TextStyle(
                            color: const Color(0xFF152B51),
                            fontSize: MediaQuery.of(context).size.width * 0.03),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => Signup()));
                        },
                        child: Container(
                          child: Text(
                            "Register now",
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF152B51),
                                fontSize:
                                    MediaQuery.of(context).size.width * 0.03),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.04,
                  ),
                  // SizedBox(
                  //   height: MediaQuery.of(context).size.height * 0.1,
                  // ),
                ],
              );
            }

            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (!isEmailSubmitted &&
                      MediaQuery.of(context).size.height > 700 &&
                      hasMultipleCompanies)
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.25,
                    ),
                  if (isEmailSubmitted &&
                      MediaQuery.of(context).size.height > 700 &&
                      !hasMultipleCompanies)
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.15,
                    ),
                  if (!isEmailSubmitted &&
                      MediaQuery.of(context).size.height > 700)
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.15,
                    ),
                  if (MediaQuery.of(context).size.height < 670)
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.1,
                    ),
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.1,
                  ),
                  Image(
                    image: const AssetImage('assets/images/logo.png'),
                    height: MediaQuery.of(context).size.height * 0.05,
                    width: MediaQuery.of(context).size.width * 0.9,
                  ),
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.025,
                  ),
                  // // Welcome
                  // Center(
                  //   child: Text(
                  //     "Welcome to CRM",
                  //     style: TextStyle(
                  //       color: Colors.black,
                  //       fontWeight: FontWeight.bold,
                  //       fontSize: MediaQuery.of(context).size.width * 0.05,
                  //     ),
                  //   ),
                  // ),
                  // SizedBox(
                  //   height: MediaQuery.of(context).size.height * 0.02,
                  // ),
                  // Login text
                  Center(
                    child: Text(
                      "Sign In",
                      style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: MediaQuery.of(context).size.width * 0.046),
                    ),
                  ),
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.05,
                  ),

                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.025,
                  ),
                  // Email
                  Row(
                    children: [
                      SizedBox(
                        width: MediaQuery.of(context).size.width * 0.099,
                      ),
                      Expanded(
                        flex: 1,
                        child: Container(
                          height: 50,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: const Color.fromRGBO(196, 196, 196, .3),
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
                                      _hasMultipleCompanies = false;
                                      // Don't clear password anymore - both fields shown together
                                    });
                                  },
                                  controller: email,
                                  cursorColor: blueColor,
                                  decoration: InputDecoration(
                                    enabledBorder: emailerror
                                        ? OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            borderSide: const BorderSide(
                                                color: Colors
                                                    .red), // Set border color here
                                          )
                                        : InputBorder.none,
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.all(14),
                                    prefixIcon: Container(
                                      height: 20,
                                      width: 20,
                                      padding: const EdgeInsets.all(13),
                                      child: FaIcon(
                                        FontAwesomeIcons.envelope,
                                        size: 20,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    hintText: "Email Address",
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
                        width: MediaQuery.of(context).size.width * 0.095,
                      ),
                    ],
                  ),
                  emailerror
                      ? Center(
                          child: Text(
                          emailmessage,
                          style: const TextStyle(
                            color: Colors.red,
                          ),
                        ))
                      : Container(),

                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.025,
                  ),
                  // Password field - now shown from the start
                  Row(
                    children: [
                      SizedBox(
                        width: MediaQuery.of(context).size.width * 0.099,
                      ),
                      Expanded(
                        flex: 1,
                        child: Container(
                          height: 50,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: const Color.fromRGBO(196, 196, 196, .3),
                          ),
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: TextField(
                                  keyboardType: TextInputType.text,
                                  onChanged: (value) {
                                    setState(() {
                                      passworderror = false;
                                      _isEmailSubmitted = false;
                                      _hasMultipleCompanies = false;
                                    });
                                  },
                                  controller: password,
                                  obscureText: visiable_password,
                                  cursorColor: blueColor,
                                  decoration: InputDecoration(
                                    enabledBorder: passworderror
                                        ? OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            borderSide: const BorderSide(
                                                color: Colors
                                                    .red), // Set border color here
                                          )
                                        : InputBorder.none,
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.all(14),
                                    prefixIcon: Container(
                                      height: 20,
                                      width: 20,
                                      // color: Colors.blue,
                                      padding: const EdgeInsets.all(13),
                                      child: FaIcon(
                                        FontAwesomeIcons.lock,
                                        size: 20,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    hintText: "Password",
                                    hintStyle: TextStyle(
                                        color: Colors.grey[600], fontSize: 15),
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
                                        color: Colors.grey[600],
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
                      ? Center(
                          child: Text(
                          passwordmessage,
                          style: const TextStyle(color: Colors.red),
                        ))
                      : Container(),
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.012,
                  ),
                  // Remember Me checkbox
                  Row(
                    children: [
                      SizedBox(
                        width: MediaQuery.of(context).size.width * 0.099,
                      ),
                      // Checkbox
                      Container(
                        height: MediaQuery.of(context).size.height * 0.035,
                        width: MediaQuery.of(context).size.height * 0.035,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Checkbox(
                          activeColor: blueColor,
                          checkColor: Colors.white,
                          value: isChecked,
                          onChanged: (value) {
                            setState(() {
                              isChecked = value ?? false;
                              rememberMe = value ?? false;
                            });
                          },
                        ),
                      ),

                      SizedBox(width: MediaQuery.of(context).size.width * 0.02),

                      // Text that wraps
                      Expanded(
                        child: Text(
                          " Remember Me",
                          textAlign: TextAlign.justify,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: MediaQuery.of(context).size.width * 0.033,
                            color: blueColor,
                            height: 1.3, //
                          ),
                        ),
                      ),

                      SizedBox(width: MediaQuery.of(context).size.width * 0.05),
                    ],
                  ),
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.012,
                  ),

                  // Forgot password
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      SizedBox(
                        width: MediaQuery.of(context).size.width * 0.11,
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) =>
                                      const ForgotPassword()));
                        },
                        child: Text(
                          "Forgot password?",
                          style: TextStyle(
                            fontSize: MediaQuery.of(context).size.width * 0.035,
                            color: const Color(0xFF152B51),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: MediaQuery.of(context).size.width * 0.099,
                      ),
                    ],
                  ),
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.025,
                  ),

                  // Company selection (shown when multiple accounts found)
                  if (hasMultipleCompanies) ...[
                    SingleSelectionButtons(
                      buttonOptions: companies,
                      onSelected: (index) {
                        setState(() {
                          adminId = companies[index]['admin_id'];
                          userId = companies[index]['user_id'];
                        });
                        selectCompany(
                            companies[index]["company"]!,
                            companies[index]["role"]!,
                            companies[index]["admin_id"]!,
                            companies[index]["user_id"]!,
                            companies[index]["userName"]!);
                      },
                    ),
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.025,
                    ),
                  ],

                  // 2FA field (if required)
                  if (requires2FA) ...[
                    Row(
                      children: [
                        SizedBox(
                          width: MediaQuery.of(context).size.width * 0.099,
                        ),
                        Expanded(
                          flex: 1,
                          child: Container(
                            height: 50,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              color: const Color.fromRGBO(196, 196, 196, .3),
                            ),
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: TextField(
                                    keyboardType: TextInputType.text,
                                    // Greyed out once the countdown ends, the
                                    // same as the profile screen and web.
                                    // Resending clears the flag and re-enables
                                    // it automatically.
                                    enabled: !_twoFALocked,
                                    onChanged: (value) {
                                      setState(() {
                                        required2FA = false;
                                      });
                                    },
                                    controller: twoFA,
                                    cursorColor: blueColor,
                                    decoration: InputDecoration(
                                      enabledBorder: required2FA
                                          ? OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              borderSide: const BorderSide(
                                                  color: Colors.red),
                                            )
                                          : InputBorder.none,
                                      border: InputBorder.none,
                                      contentPadding: const EdgeInsets.all(14),
                                      hintText: switchtoBackupcode
                                          ? "Enter backup code"
                                          : "Enter 6 digit code",
                                      hintStyle: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 15),
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
                    required2FA
                        ? Center(
                            child: Text(
                            required2FAmessage,
                            style: const TextStyle(color: Colors.red),
                          ))
                        : Container(),
                    // Code expiry countdown + Resend, matching the Profile
                    // screen. A backup code neither expires nor can be
                    // resent, so this is OTP mode only.
                    if (!switchtoBackupcode)
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal:
                              MediaQuery.of(context).size.width * 0.099,
                          vertical: 8,
                        ),
                        child: _build2FATimerRow(),
                      ),
                    if (backupcode) ...[
                      SizedBox(
                        height: 10,
                      ),
                      if (!switchtoBackupcode)
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              switchtoBackupcode = !switchtoBackupcode;
                            });
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                "Use backup code instead",
                                style: TextStyle(
                                  fontSize:
                                      MediaQuery.of(context).size.width * 0.035,
                                  color: const Color(0xFF152B51),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(
                                width:
                                    MediaQuery.of(context).size.width * 0.099,
                              ),
                            ],
                          ),
                        ),
                      if (switchtoBackupcode)
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              switchtoBackupcode = !switchtoBackupcode;
                            });
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                "Use OTP instead",
                                style: TextStyle(
                                  fontSize:
                                      MediaQuery.of(context).size.width * 0.035,
                                  color: const Color(0xFF152B51),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(
                                width:
                                    MediaQuery.of(context).size.width * 0.099,
                              ),
                            ],
                          ),
                        )
                    ],
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.025,
                    ),
                  ],

                  // Submit/Login button
                  if (!hasMultipleCompanies ||
                      (hasMultipleCompanies && selectedrole.isNotEmpty) ||
                      requires2FA)
                    GestureDetector(
                      onTap: () async {
                        // Handle 2FA verification
                        if (requires2FA) {
                          if (twoFA.text.trim().isEmpty) {
                            setState(() {
                              required2FA = true;
                              required2FAmessage = "Code is required";
                            });
                            return;
                          }
                          // Web requires the full 6 digits before verifying.
                          if (!switchtoBackupcode &&
                              twoFA.text.trim().length != 6) {
                            setState(() {
                              required2FA = true;
                              required2FAmessage =
                                  "Please enter the complete 6-digit code";
                            });
                            return;
                          }
                          if (_twoFAExpired) {
                            Fluttertoast.showToast(
                                msg:
                                    "Verification code expired. Please resend the code.");
                            return;
                          }
                          await loginsubmitverify2fa();
                          return;
                        }

                        if (hasMultipleCompanies && selectedrole.isEmpty) {
                          Fluttertoast.showToast(
                              msg: "Please select the company");
                          return;
                        }

                        if (!hasMultipleCompanies) {
                          // First time - check credentials
                          await checkCredentials();
                        } else {
                          // Company selected - proceed with login
                          if (emailerror == false && passworderror == false) {
                            if (selectedrole == "admin") {
                              await loginsubmit();
                            } else {
                              await checkCompany(selectedCompany);
                            }
                          }
                        }
                      },
                      child: Center(
                        child: Container(
                          height: MediaQuery.of(context).size.height * 0.06,
                          width: MediaQuery.of(context).size.width * 0.8,
                          decoration: BoxDecoration(
                            // Greyed out while the 2FA code is expired, so the
                            // action reads as unavailable rather than looking
                            // tappable and failing on submit. Matches the
                            // profile screen's disabled Verify button. The
                            // guard inside onTap stays as the safety net.
                            color: _twoFALocked
                                ? Colors.grey
                                : const Color(0xFF152B51),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: loading
                                ? const SpinKitFadingCircle(
                                    color: Colors.white,
                                    size: 40.0,
                                  )
                                : requires2FA
                                    ? Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            "Verify & Login",
                                            style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: MediaQuery.of(context)
                                                        .size
                                                        .width *
                                                    0.045),
                                          ),
                                        ],
                                      )
                                    : Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            "Login",
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

                  // Register now
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.04,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Don't have an account ? ",
                        style: TextStyle(
                            color: const Color(0xFF152B51),
                            fontSize: MediaQuery.of(context).size.width * 0.04),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => Signup()));
                        },
                        child: Container(
                          child: Text(
                            "Register now",
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF152B51),
                                fontSize:
                                    MediaQuery.of(context).size.width * 0.037),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.04,
                  ),
                  // SizedBox(
                  //   height: MediaQuery.of(context).size.height * 0.1,
                  // ),
                ],
              ),
            );
          })),
    );
  }

  /// Web parity (Functions.js `alertAndLogin`): when session verification
  /// fails, web removes the token/ID cookies so the user lands back on login.
  /// Mobile must do the same — the caller persists `token` + `isAuthenticated`
  /// BEFORE verification runs, so without this a rejected session stays on the
  /// device and the next launch walks into the dashboard with a token the
  /// server already refused.
  ///
  /// Remember-Me credentials (`savedEmail`/`savedPassword`) are deliberately
  /// left alone — web keeps those too; they only prefill the login form.
  Future<void> _clearFailedSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('isAuthenticated');
    await prefs.remove('token');
    await prefs.remove('checkedToken');
    await prefs.remove('userId');
  }

  Future<void> checkToken(String token) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    // String? token = prefs.getString('token');

    final response = await apiPost(
      Uri.parse('${Api_url}/api/auth'),
      headers: {
        "authorization": "CRM $token",
        "id": "CRM $adminId",
        "Content-Type": "application/json"
      },
      body: json.encode({"token": token}),
    );
    final dynamic jsonData;
    try {
      jsonData = json.decode(response.body);
    } on FormatException {
      // Non-JSON body (e.g. an HTML 502 page) — fail with a message instead
      // of throwing and leaving the login button spinning forever.
      await _clearFailedSession();
      if (mounted) {
        Fluttertoast.showToast(msg: "Login failed. Please try again.");
      }
      return;
    }

    // Web parity (Client Functions.js verifyToken): the server reports an
    // invalid session as HTTP 200 with statusCode 401 in the BODY (e.g.
    // "Password has been changed. Please login again.").
    if (jsonData is Map && jsonData['statusCode'] == 401) {
      await _clearFailedSession();
      if (mounted) {
        Fluttertoast.showToast(
            msg: jsonData['message']?.toString() ??
                "Session expired. Please login again.");
      }
      return;
    }

    // Web parity: success is judged by the presence of `role` on the
    // response (`response.data?.role`). The /api/auth payload is the user
    // document spread — it has `_id`/`admin_id`/`role`, never a bare `id`.
    if (response.statusCode == 200 &&
        jsonData is Map &&
        jsonData['role'] != null) {
      //prefs.setString('checkedToken',jsonData["token"]);
      String? adminId = jsonData['admin_id'];
      String? companyName = jsonData['company_name'];

      prefs.setString('checkedToken', token);
      prefs.setString('adminId', adminId ?? "");

      prefs.setString('companyName', companyName ?? "");
      prefs.setString("role", "Admin");
      prefs.setString('first_name', jsonData['first_name'] ?? "");
      prefs.setString('last_name', jsonData['last_name'] ?? "");
      prefs.setString('email', jsonData['email'] ?? "");
      // prefs.setString('brand_logo', jsonData['brand_logo']);
      // print("Saved brand logo: ${jsonData['brand_logo']}");
      // prefs.setString('userid', jsonData['user_id'] ?? "");
      prefs.setString('password', password.text);
      // prefs.setString('userid', jsonData['user_id']);
      String? brandLogo = jsonData['brand_logo'];

      if (brandLogo != null &&
          brandLogo.isNotEmpty &&
          brandLogo.startsWith("data:image")) {
        prefs.setString('brand_logo', brandLogo);
      } else {
        prefs.remove('brand_logo'); // Use default in drawer
        // Optional: block login
        /*
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login failed: Invalid brand logo'))
      );
      return;
      */
      }

      if (!mounted) return;

      await Provider.of<checkPlanPurchaseProiver>(context, listen: false)
          .fetchPlanPurchaseDetail();

      // Access the expiration date
      var provider =
          Provider.of<checkPlanPurchaseProiver>(context, listen: false);
      var expirationDateString =
          provider.checkplanpurchaseModel?.data?.expirationDate;

      DateTime? expirationDate;
      if (expirationDateString != null) {
        expirationDate = DateFormat('yyyy-MM-dd').parse(expirationDateString);
      }


      DateTime now = DateTime.now();
      String currentDate = DateFormat('yyyy-MM-dd').format(now);

      bool isPlanActive = expirationDate != null && expirationDate.isAfter(now);

      if (isPlanActive) {
      } else {
      }
      // Refresh DateProvider to load new user's date format preferences
      await Provider.of<DateProvider>(context, listen: false).loadDateFormat();
      Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (context) =>
                  isPlanActive ? Dashboard() : PlanPurchaseCard()));
    } else {
      // Web parity: web surfaces a message and returns to login instead of
      // failing silently ("User Not Found" arrives as HTTP 201).
      await _clearFailedSession();
      if (mounted) {
        Fluttertoast.showToast(
            msg: (jsonData is Map ? jsonData['message']?.toString() : null) ??
                "Login failed. Please try again.");
      }
    }
  }

  Future<void> checkTokenStaff(String token) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    // String? token = prefs.getString('token');
    //log();
    final response = await apiPost(
      Uri.parse('${Api_url}/api/auth'),
      headers: {
        "authorization": "CRM $token",
        // Must be the staff member's OWN id (same as web) so the server
        // resolves the staff branch — sending adminId hits the admin branch
        // and 401s at companies with multiple co-admins.
        "id": "CRM $userId",
        "Content-Type": "application/json"
      },
      body: json.encode({"token": token}),
    );
    final dynamic jsonData;
    try {
      jsonData = json.decode(response.body);
    } on FormatException {
      // Non-JSON body (e.g. an HTML 502 page) — fail with a message instead of
      // throwing and leaving the login button spinning forever.
      await _clearFailedSession();
      if (mounted) {
        Fluttertoast.showToast(msg: "Login failed. Please try again.");
      }
      return;
    }
    // Web parity (Functions.js verifyToken): an invalid session arrives as
    // HTTP 200 with statusCode 401 in the BODY (e.g. "Password has been
    // changed. Please login again.").
    if (jsonData is Map && jsonData['statusCode'] == 401) {
      await _clearFailedSession();
      if (mounted) {
        Fluttertoast.showToast(
            msg: jsonData['message']?.toString() ??
                "Session expired. Please login again.");
      }
      return;
    }
    if (jsonData["staffmember_id"] != null) {
      //prefs.setString('checkedToken',jsonData["token"]);
      // String? adminId = jsonData['data']['admin_id'];
      // print('Admin ID: $adminId');
      // await Provider.of<StaffPermissionProvider>(context, listen: false).fetchPermissions();
      prefs.setString("staff_id", jsonData["staffmember_id"]);
      prefs.setString("role", "Staffmember");
      prefs.setString('companyName', selectedCompany);
      prefs.setString('checkedToken', token);
      //  prefs.setString('adminId', adminId!);
      String stafffirstname = jsonData['staffmember_name'];
      List<String> firstname = stafffirstname.split(" ");
      prefs.setString('first_name', firstname.first);
      prefs.setString('last_name', firstname.length > 1 ? firstname.last : "");
      prefs.setString('staffemail', jsonData['staffmember_email']);
      prefs.setString('staffmember_password', password.text);
      //prefs.setString('user_id', jsonData['user_id']);
      // String? userId = jsonData['user_id'];
      await Provider.of<StaffPermissionProvider>(context, listen: false)
          .fetchPermissions();
      // Refresh DateProvider to load new user's date format preferences
      await Provider.of<DateProvider>(context, listen: false).loadDateFormat();
      // pushReplacement, not push: the dashboard must be the FIRST route.
      // Admin already did this; Staff/Tenant/Vendor did not, which left
      // Login_Screen underneath the dashboard — so back from the dashboard
      // returned to login, and the drawer's stack-replacing navigation
      // would have landed there too.
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (context) => Dashboard_staff()));
    } else {
      // Web parity: web clears the session and returns the user to login.
      await _clearFailedSession();
      Fluttertoast.showToast(
          msg: _formatErrorMessage(
              jsonData["message"] ?? "Login failed. Please try again."));
    }
  }

  Future<void> checkTokenTenant(String token) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    // String? token = prefs.getString('token');
    // List<Map<String,dynamic>> selectedroledata = roles.where((element) => element["role_id"] == selectedRole).toList();
    // String rolename  =selectedroledata.first["role_name"];

    final response = await apiPost(
      Uri.parse('${Api_url}/api/auth'),
      headers: {
        "authorization": "CRM $token",
        // Tenant's OWN id (same as web) — adminId here resolves the wrong
        // user branch on the server.
        "id": "CRM $userId",
        "Content-Type": "application/json"
      },
      body: json.encode({"token": token}),
    );
    final dynamic jsonData;
    try {
      jsonData = json.decode(response.body);
    } on FormatException {
      // Non-JSON body (e.g. an HTML 502 page) — fail with a message instead of
      // throwing and leaving the login button spinning forever.
      await _clearFailedSession();
      if (mounted) {
        Fluttertoast.showToast(msg: "Login failed. Please try again.");
      }
      return;
    }
    // Web parity (Functions.js verifyToken): an invalid session arrives as
    // HTTP 200 with statusCode 401 in the BODY.
    if (jsonData is Map && jsonData['statusCode'] == 401) {
      await _clearFailedSession();
      if (mounted) {
        Fluttertoast.showToast(
            msg: jsonData['message']?.toString() ??
                "Session expired. Please login again.");
      }
      return;
    }
    if (jsonData["tenant_id"] != null) {
      //prefs.setString('checkedToken',jsonData["token"]);
      // String? adminId = jsonData['data']['admin_id'];
      // print('Admin ID: $adminId');
      prefs.setString("role", "Tenant");
      prefs.setString('companyName', selectedCompany);
      prefs.setString("tenant_id", jsonData["tenant_id"]);
      prefs.setString('checkedToken', token);
      //  prefs.setString('adminId', adminId!);
      prefs.setString('first_name', jsonData['tenant_firstName']);
      prefs.setString('last_name', jsonData['tenant_lastName']);
      prefs.setString('email', jsonData['tenant_email']);
      prefs.setString('tenant_password', password.text);
      //prefs.setString('user_id', jsonData['user_id']);
      // String? userId = jsonData['user_id'];
      await Provider.of<PermissionProvider>(context, listen: false)
          .fetchPermissions();
      // Refresh DateProvider to load new user's date format preferences
      await Provider.of<DateProvider>(context, listen: false).loadDateFormat();
      // pushReplacement — see the note on the Staff branch.
      Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (context) => Dashboard_tenants()));
    } else {
      // Web parity: web clears the session and returns the user to login.
      await _clearFailedSession();
      Fluttertoast.showToast(
          msg: _formatErrorMessage(
              jsonData["message"] ?? "Login failed. Please try again."));
    }
  }

  Future<void> checkTokenVendor(String token) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    // String? token = prefs.getString('token');
    // List<Map<String,dynamic>> selectedroledata = roles.where((element) => element["role_id"] == selectedRole).toList();
    // String rolename  =selectedroledata.first["role_name"];
    // print('${Api_url}/api/${rolename.toLowerCase()}/token_check');
    final response = await apiPost(
      Uri.parse('${Api_url}/api/auth'),
      headers: {
        "authorization": "CRM $token",
        // Vendor's OWN id (same as web) — adminId here resolves the wrong
        // user branch on the server.
        "id": "CRM $userId",
        "Content-Type": "application/json"
      },
      body: json.encode({"token": token}),
    );
    final dynamic jsonData;
    try {
      jsonData = json.decode(response.body);
    } on FormatException {
      // Non-JSON body (e.g. an HTML 502 page) — fail with a message instead of
      // throwing and leaving the login button spinning forever.
      await _clearFailedSession();
      if (mounted) {
        Fluttertoast.showToast(msg: "Login failed. Please try again.");
      }
      return;
    }
    // Web parity (Functions.js verifyToken): an invalid session arrives as
    // HTTP 200 with statusCode 401 in the BODY.
    if (jsonData is Map && jsonData['statusCode'] == 401) {
      await _clearFailedSession();
      if (mounted) {
        Fluttertoast.showToast(
            msg: jsonData['message']?.toString() ??
                "Session expired. Please login again.");
      }
      return;
    }
    if (jsonData["vendor_id"] != null) {
      //prefs.setString('checkedToken',jsonData["token"]);
      // String? adminId = jsonData['data']['admin_id'];
      // print('Admin ID: $adminId');
      String stafffirstname = jsonData['vendor_name'];
      List<String> firstname = stafffirstname.split(" ");
      await Provider.of<PermissionProvider>(context, listen: false)
          .fetchPermissions();
      prefs.setString('first_name', firstname.first);
      // prefs.setString('last_name', firstname.length > 1 ? firstname[1]: "");
      prefs.setString('last_name', firstname.length > 1 ? firstname[1] : "");
      prefs.setString('companyName', selectedCompany);
      prefs.setString("role", "Vendor");
      prefs.setString("vendor_id", jsonData["vendor_id"]);
      prefs.setString('checkedToken', token);
      //  prefs.setString('user_id', jsonData['user_id']);
      // String? userId = jsonData['user_id'];
      //  prefs.setString('adminId', adminId!);
      // prefs.setString('first_name', jsonData['${rolename.toLowerCase()}_firstName']);
      // prefs.setString('last_name', jsonData['${rolename.toLowerCase()}_lastName']);
      prefs.setString('email', jsonData['vendor_email']);
      prefs.setString('vendor_password', password.text);
      // prefs.setString('checkedToken', token);
      //  prefs.setString('adminId', adminId!);
      await Provider.of<VendorPermission>(context, listen: false)
          .fetchPermissions();
      // Refresh DateProvider to load new user's date format preferences
      await Provider.of<DateProvider>(context, listen: false).loadDateFormat();
      // pushReplacement — see the note on the Staff branch.
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (context) => MainScreen()));
    } else {
      // Web parity: web clears the session and returns the user to login.
      await _clearFailedSession();
      Fluttertoast.showToast(
          msg: _formatErrorMessage(
              jsonData["message"] ?? "Login failed. Please try again."));
    }
  }

  Future<void> checkCompany(String token) async {
    setState(() {
      loading = true;
    });
    SharedPreferences prefs = await SharedPreferences.getInstance();
    // String? token = prefs.getString('token');
    final response = await apiGet(
      Uri.parse('${Api_url}/api/admin/check_company/${token}'),
      headers: {
        // "authorization": "CRM $token",
        //"id":"CRM $id",
        "Content-Type": "application/json"
      },
      // body: json.encode({"token": token}),
    );
    final jsonData = json.decode(response.body);
    //if (jsonData["data"]['id'] != "") {
    if (jsonData["statusCode"] == 200) {
      //prefs.setString('checkedToken',jsonData["token"]);
      String? adminId = jsonData['data']['admin_id'];
      prefs.setString('checkedToken', token);
      prefs.setString('adminId', adminId!);
      // prefs.setString('user_id', jsonData['user_id']);
      //  String? userId = jsonData['user_id'];
      loginsubmit_usingrole(adminId);
    } else {
      setState(() {
        loading = false;
      });
    }
  }

  Future<void> loginsubmit_usingrole(String adminId) async {
    setState(() {
      loading = true;
    });
    // List<Map<String,dynamic>> selectedroledata = roles.where((element) => element["role_id"] == selectedRole).toList();

    // SharedPreferences prefs = await SharedPreferences.getInstance();
    // String? userid = prefs.getString("user_id");
    String rolename = selectedrole;

    // print({"email": email.text, "password": password.text,"admin_id":adminId,"company":company.text});
    // Remembered so Resend can replay the exact body that triggered 2FA.
    _last2FALoginBody = {
      "email": email.text.trim(),
      "password": password.text.trim(),
      "admin_id": adminId,
      "role": selectedrole == "staff" ? "staffmember" : rolename.toLowerCase(),
      "company": selectedCompany,
      "user_id": userId,
      "rememberMe": rememberMe.toString(),
    };
    final response = await apiPost(Uri.parse('${Api_url}/api/auth/login'),
        body: _last2FALoginBody);
    await backupcodeapicall();
    final jsonData = json.decode(response.body);
    if (jsonData["statusCode"] == 200) {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      prefs.setBool('isAuthenticated', true);
      prefs.setString('token', jsonData["token"]);
      prefs.setString('adminId', adminId);
      prefs.setString('userId', userId!);

      // Save credentials if Remember Me is enabled
      await _saveCredentials();

      if (rolename == "staffmember" || selectedrole == "staff")
        await checkTokenStaff(jsonData["token"]);
      if (rolename == "tenant") await checkTokenTenant(jsonData["token"]);
      if (rolename == "vendor") await checkTokenVendor(jsonData["token"]);

      setState(() {
        loading = false;
      });
    } else {
      Fluttertoast.showToast(msg: _formatErrorMessage(jsonData["message"]));
      if (jsonData["statusCode"] == 205) {
        setState(() {
          requires2FA = true;
          OtpId = jsonData["data"]["otp_id"];
        });
        _start2FATimer();
        await backupcodeapicall();
      }
      setState(() {
        loading = false;
      });
    }
  }

  Future<void> loginsubmit() async {
    setState(() {
      loading = true;
    });
    final response =
        await apiPost(Uri.parse('${Api_url}/api/auth/login'), body: {
      "email": email.text.trim(),
      "password": password.text.trim(),
      "role": selectedrole,
      "admin_id": adminId,
      "user_id": userId,
      "rememberMe": rememberMe.toString(),
    });
    // Remembered so Resend can replay the exact body that triggered 2FA.
    _last2FALoginBody = {
      "email": email.text.trim(),
      "password": password.text.trim(),
      "role": selectedrole,
      "admin_id": adminId,
      "user_id": userId,
      "rememberMe": rememberMe.toString(),
    };
    final jsonData = json.decode(response.body);

    if (jsonData["statusCode"] == 200) {

      SharedPreferences prefs = await SharedPreferences.getInstance();
      prefs.setBool('isAuthenticated', true);
      prefs.setString('token', jsonData["token"]);
      prefs.setString('userId', userId!);

      // Save credentials if Remember Me is enabled
      await _saveCredentials();

      //  print("required 2FA ${jsonData["data"]["requires2FA"]}");
      await checkToken(jsonData["token"]);
      //  await checkToken("token", "id");
      // Navigator.push(
      //     context, MaterialPageRoute(builder: (context) => Dashboard()));

      setState(() {
        loading = false;
      });
    } else {
      Fluttertoast.showToast(msg: _formatErrorMessage(jsonData["message"]));
      if (jsonData["statusCode"] == 205) {
        setState(() {
          requires2FA = true;
          OtpId = jsonData["data"]["otp_id"];
        });
        _start2FATimer();
        await backupcodeapicall();
      }
      setState(() {
        loading = false;
      });
    }
  }

  Future<void> loginsubmitverify2fa() async {
    setState(() {
      loading = true;
    });

    final response = await apiPost(
      Uri.parse('${Api_url}/api/auth/verify-login-2fa'),
      headers: {
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "code": twoFA.text,
        "is_backup_code": switchtoBackupcode,
        "otp_id": switchtoBackupcode ? null : OtpId,
        "user_type": selectedrole,
        "user_id": userId,
        "rememberMe": rememberMe,
      }),
    );
    final jsonData = json.decode(response.body);
    if (jsonData["statusCode"] == 200) {

      // Code accepted — the countdown is no longer relevant.
      _stop2FATimer();

      SharedPreferences prefs = await SharedPreferences.getInstance();
      prefs.setBool('isAuthenticated', true);
      prefs.setString('token', jsonData["token"]);
      prefs.setString('userId', userId!);

      // Save credentials if Remember Me is enabled
      await _saveCredentials();

      //print("required 2FA ${jsonData["data"]["requires2FA"]}");
      if (selectedrole == "staffmember" || selectedrole == "staff")
        await checkTokenStaff(jsonData["token"]);
      if (selectedrole == "tenant") await checkTokenTenant(jsonData["token"]);
      if (selectedrole == "vendor") await checkTokenVendor(jsonData["token"]);
      if (selectedrole == "admin") await checkToken(jsonData["token"]);
      //  await checkToken("token", "id");
      // Navigator.push(
      //     context, MaterialPageRoute(builder: (context) => Dashboard()));

      setState(() {
        loading = false;
      });
    } else {
      Fluttertoast.showToast(msg: _formatErrorMessage(jsonData["message"]));
      if (jsonData["statusCode"] == 205) {
        setState(() {
          requires2FA = true;
        });
        // A rejected code does not re-issue the OTP, so the server-side
        // expiry is unchanged — keep the running countdown instead of
        // resetting it (which would also re-lock Resend for 60s). Only
        // start one if none is running and the code has not already expired.
        if (twoFASeconds.value == 0 && !_twoFAExpired) _start2FATimer();
      }
      setState(() {
        loading = false;
      });
    }
  }

  Future<void> backupcodeapicall() async {
    // setState(() {
    //   loading = true;
    // });

    selectedrole =
        selectedrole == "staffmember" ? "staff" : selectedrole.toLowerCase();

    final response = await apiGet(Uri.parse(
        '${Api_url}/api/backup-codes/backup-codes/${userId}?user_type=$selectedrole'));
    final jsonData = json.decode(response.body);
    if (jsonData["statusCode"] == 200) {

      //  await checkToken("token", "id");
      // Navigator.push(
      //     context, MaterialPageRoute(builder: (context) => Dashboard()));

      setState(() {
        backupcode = true;
      });
    } else {
      //   Fluttertoast.showToast(msg: _formatErrorMessage(jsonData["message"]));
      //   if (jsonData["statusCode"] == 205) {
      //     print("2FA ON");
      //     setState(() {
      //       requires2FA = true;
      //       OtpId = jsonData["data"]["otp_id"];
      //     });
      //   }
      //   setState(() {
      //     loading = false;
      //   });
    }
  }
}

class SingleSelectionButtons extends StatefulWidget {
  final List<Map<String, String>> buttonOptions;
  final Function(int index) onSelected;

  const SingleSelectionButtons({
    super.key,
    required this.buttonOptions,
    required this.onSelected,
  });

  @override
  _SingleSelectionButtonsState createState() => _SingleSelectionButtonsState();
}

class _SingleSelectionButtonsState extends State<SingleSelectionButtons> {
  int _selectedIndex = -1;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, contraints) {
      if (contraints.maxWidth > 500) {
        return Container(
          width: MediaQuery.of(context).size.width * .8,
          child: Wrap(
            spacing: 8.0,
            runSpacing: 8.0,
            alignment: WrapAlignment.start,
            children: widget.buttonOptions.map((option) {
              final index = widget.buttonOptions.indexOf(option);
              return SizedBox(
                width: 320, // Adjusted width to make the button smaller
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _selectedIndex = index;
                    });
                    widget.onSelected(index);
                  },
                  style: ElevatedButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(vertical: 10, horizontal: 5),
                    foregroundColor:
                        _selectedIndex == index ? Colors.white : blueColor,
                    backgroundColor:
                        _selectedIndex == index ? blueColor : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    side: BorderSide(
                      color: _selectedIndex == index ? blueColor : Colors.grey,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _selectedIndex == index
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        color: _selectedIndex == index
                            ? Colors.white
                            : Colors.grey,
                      ),
                      const SizedBox(width: 5.0),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            option["company"]!,
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _selectedIndex == index
                                    ? Colors.white
                                    : Colors.black,
                                fontSize: 18),
                          ),
                          Text(
                            capitalizeFirstLetter(option["role"]!),
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _selectedIndex == index
                                    ? Colors.white
                                    : Colors.black,
                                fontSize: 16),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        );
      }
      return Container(
        width: 350,
        child: Wrap(
          spacing: 8.0,
          runSpacing: 8.0,
          alignment: WrapAlignment.center,
          children: widget.buttonOptions.map((option) {
            final index = widget.buttonOptions.indexOf(option);
            return SizedBox(
              width: 320, // Adjusted width to make the button smaller
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    _selectedIndex = index;
                  });
                  widget.onSelected(index);
                },
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(vertical: 10, horizontal: 5),
                  foregroundColor:
                      _selectedIndex == index ? Colors.white : blueColor,
                  backgroundColor:
                      _selectedIndex == index ? blueColor : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  side: BorderSide(
                    color: _selectedIndex == index ? blueColor : grey,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Icon(
                    //   _selectedIndex == index
                    //       ? (Icons.check_box)
                    //       : Icons.check_box_outline_blank,
                    //   color:
                    //       _selectedIndex == index ? Colors.white : blueColor,
                    //   size: 40,
                    // ),
                    const SizedBox(
                      width: 10,
                    ),
                    Container(
                      width: 30, // Set the width of the container
                      height: 30, // Set the height of the container
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: _selectedIndex == index
                              ? Colors.white
                              : Colors.black, // Border color
                          width: 2, // Set the border thickness
                        ),
                        borderRadius: BorderRadius.circular(
                            3), // Optional: rounded corners
                      ),
                      child: Center(
                        child: _selectedIndex == index
                            ? const Icon(
                                Icons.check_sharp,
                                color: Colors.white, // Icon color when selected
                                size: 25, // Set the icon size
                              )
                            : const SizedBox
                                .shrink(), // This will create a blank space when not selected
                      ),
                    ),
                    const SizedBox(width: 15),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            SizedBox(
                              width: 250,
                              child: Text(
                                "${option['userName']!} (${option['company']!})",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: _selectedIndex == index
                                        ? Colors.white
                                        : Colors.black,
                                    fontSize: 16),
                                maxLines: 3,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          capitalizeFirstLetter(option["role"]!),
                          style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: _selectedIndex == index
                                  ? Colors.white
                                  : Colors.black,
                              fontSize: 13),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      );
    });
  }

  String capitalizeFirstLetter(String input) {
    if (input.isEmpty) return input;
    return input[0].toUpperCase() + input.substring(1);
  }
}
/*import 'dart:convert';

import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:email_validator/email_validator.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:three_zero_two_property/VendorModule/screen/dashboard.dart';
import 'package:three_zero_two_property/screens/Password/changepassword.dart';

import 'package:three_zero_two_property/screens/Signup/signup_screen.dart';
import 'package:http/http.dart' as http;
import 'package:three_zero_two_property/services/api_helpers.dart';

import '../../StaffModule/repository/staffpermission_provider.dart';
import '../../StaffModule/screen/dashboard.dart';
import '../../TenantsModule/repository/permission_provider.dart';
import '../../TenantsModule/screen/dashboard.dart';
import '../../VendorModule/screen/mainScreen.dart';
import '../../constant/constant.dart';
import '../../provider/Plan Purchase/plancheckProvider.dart';
import '../../provider/dateProvider.dart';
import '../Dashboard/dashboard_one.dart';
import '../Password/forgotpassword.dart';
import '../Password/otp_vrify.dart';
import '../Plans/PlansPurcharCard.dart';

class Login_Screen extends StatefulWidget {
  const Login_Screen({super.key});

  @override
  State<Login_Screen> createState() => _Login_ScreenState();
}

class _Login_ScreenState extends State<Login_Screen> {
  TextEditingController password = TextEditingController();
  TextEditingController company = TextEditingController();
  TextEditingController email = TextEditingController();

  bool passworderror = false;
  bool visiable_password = true;
  bool emailerror = false;
  bool companyerror = false;
  bool roleerror = false;

  String _email = '';
  bool _isEmailSubmitted = false;
  bool _hasMultipleCompanies = false;
  bool loading = false;
  List<Map<String, String>> _companies = [];
  String _selectedCompany = '';
  String _password = '';
  String selectedrole = '';
  String passwordmessage = "";
  String companymessage = "";
  String emailmessage = "";
  String rolemessage = "";
  // String get email => _email;
  bool get isEmailSubmitted => _isEmailSubmitted;
  bool get hasMultipleCompanies => _hasMultipleCompanies;
  List<Map<String, String>> get companies => _companies;
  String get selectedCompany => _selectedCompany;
  // String get password => _password;

  void setEmail(String email) {
    print(email);
    setState(() {
      if (_email != email) {
        _email = email;
        _isEmailSubmitted = false;
        _hasMultipleCompanies = false;
        _companies = [];
        _selectedCompany = '';
        _password = '';
      }
    });
  }

  void selectCompany(String company, String role) {
    _selectedCompany = company;
    selectedrole = role; // Set role when selecting company
    print(selectedrole);
    print(selectedCompany);
    setState(() {});
  }

  void login() {
    // Implement login logic here
    print(
        'Logging in with email: $_email, company: $_selectedCompany, password: $_password');
  }

  void setPassword(String password) {
    _password = password;
  }

  // Helper function to format error messages for better user experience
  String _formatErrorMessage(String apiMessage) {
    // Convert technical error messages to user-friendly ones
    if (apiMessage.toLowerCase().contains('invalid') &&
        (apiMessage.toLowerCase().contains('password') ||
         apiMessage.toLowerCase().contains('admin'))) {
      return "Invalid username or password.";
    }
    if (apiMessage.toLowerCase().contains('email') &&
        apiMessage.toLowerCase().contains('not found')) {
      return "Email address not found.";
    }
    if (apiMessage.toLowerCase().contains('account') &&
        apiMessage.toLowerCase().contains('disabled')) {
      return "Your account has been disabled. Please contact support.";
    }
    if (apiMessage.toLowerCase().contains('network') ||
        apiMessage.toLowerCase().contains('connection')) {
      return "Network error. Please check your connection and try again.";
    }
    // Return the original message if no specific formatting is needed
    return apiMessage;
  }

  Future<void> submitEmail() async {
    // Make API call to check email
    final response = await apiPost(
      Uri.parse('$Api_url/api/admin/check_role'),
      // Uri.parse('$Api_url/api/admin/check_role'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email.text}),
    );
    print(response.body);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      List<dynamic> roles = data['data'];
      print(roles.length);
      if (roles.isEmpty) {
        Fluttertoast.showToast(msg: "Email address not found.");
      } else {
        if (roles.length > 1) {
          setState(() {
            _hasMultipleCompanies = true;
            _companies = roles
                .map<Map<String, String>>((role) =>
            {'company': role['company_name'], 'role': role['role']})
                .toList();
            _isEmailSubmitted = true;
          });
        } else {
          setState(() {
            if (roles[0]['role'] == "admin") {
              _hasMultipleCompanies = false;
              //_selectedCompany = roles[0]['company_name'];
              selectedrole = roles[0]['role']; // Set role directly
              _isEmailSubmitted = true;
            } else {
              print(roles[0]['role']);
              _hasMultipleCompanies = false;
              _selectedCompany = roles[0]['company_name'];
              selectedrole = roles[0]['role']; // Set role directly
              _isEmailSubmitted = true;
            }
          });
        }
      }
    } else {
      Fluttertoast.showToast(msg: "Email address not found.");
    }
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
          padding: const EdgeInsets.all(0.0),
          child: LayoutBuilder(
              builder: (context,contraints) {
                if(contraints.maxWidth > 500){
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [

                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.1,
                      ),
                      Image(
                        image: AssetImage('assets/images/logo.png'),
                        height: MediaQuery.of(context).size.height * 0.07,
                        width: MediaQuery.of(context).size.width * 0.9,
                        fit: BoxFit.fill,
                      ),
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.025,
                      ),
                      // Welcome
                      Center(
                        child: Text(
                          "Welcome to 302 Rentals",
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: MediaQuery.of(context).size.width * 0.04,
                          ),
                        ),
                      ),
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.02,
                      ),
                      // Login text
                      Center(
                        child: Text(
                          "Please login here...",
                          style: TextStyle(
                              color: Colors.black,
                              fontSize: MediaQuery.of(context).size.width * 0.03),
                        ),
                      ),
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.05,
                      ),


                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.01,
                      ),
                      // Email
                      Row(
                        children: [
                          SizedBox(
                            width: MediaQuery.of(context).size.width * 0.099,
                          ),
                          Expanded(
                            flex: 1,
                            child: Container(
                              height: 60,
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
                                          _hasMultipleCompanies = false;
                                        });
                                      },
                                      style: TextStyle(
                                          fontSize: 20
                                      ),
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
                                          height: 25,
                                          width: 25,
                                          padding: EdgeInsets.all(13),
                                          child: FaIcon(
                                            FontAwesomeIcons.envelope,
                                            size: 25,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        hintText: "Business Email",
                                        hintStyle: TextStyle(
                                            color: Colors.grey[600], fontSize: 20),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(
                            width: MediaQuery.of(context).size.width * 0.095,
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

                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.025,
                      ),
                      if(!isEmailSubmitted)
                        Column(
                          children: [
                            Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [


                                    GestureDetector(
                                      onTap: () {
                                        Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                                builder: (context) => ForgotPassword()));
                                      },
                                      child: Text(
                                        "Forgot password?",
                                        style: TextStyle(
                                            fontSize: MediaQuery.of(context).size.width * 0.02,
                                            color: Colors.blue),
                                      ),
                                    ),
                                    SizedBox(
                                      width: MediaQuery.of(context).size.width * 0.099,
                                    ),
                                  ],
                                ),
                                SizedBox(
                                  height: MediaQuery.of(context).size.height * 0.025,
                                ),

                              ],
                            ),
                            SizedBox(
                              height: MediaQuery.of(context).size.height * 0.035,
                            ),
                            InkWell(
                              onTap: (){
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
                                  submitEmail();
                                }


                              },
                              child: Center(
                                child: Container(
                                  height: MediaQuery.of(context).size.height * 0.05,
                                  width: MediaQuery.of(context).size.width * 0.8,
                                  decoration: BoxDecoration(
                                    color: Colors.black,
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
                                              fontSize:
                                              MediaQuery.of(context).size.width *
                                                  0.03),
                                        ),

                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      if(isEmailSubmitted)
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [

                            Row(
                              children: [
                                SizedBox(
                                  width: MediaQuery.of(context).size.width * 0.099,
                                ),
                                Expanded(
                                  flex: 1,
                                  child: Container(
                                    height: 60,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(10),
                                      color: Color.fromRGBO(196, 196, 196, .3),
                                    ),
                                    child: Stack(
                                      children: [
                                        Positioned.fill(
                                          child: TextField(
                                            keyboardType: TextInputType.text,
                                            onChanged: (value) {
                                              setState(() {
                                                passworderror = false;
                                              });
                                            },
                                            style: TextStyle(
                                                fontSize: 20
                                            ),
                                            controller: password,
                                            obscureText: visiable_password,
                                            cursorColor: blueColor,
                                            decoration: InputDecoration(
                                              enabledBorder: passworderror
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
                                                height: 25,
                                                width: 25,
                                                // color: Colors.blue,
                                                padding: EdgeInsets.all(13),
                                                child: FaIcon(
                                                  FontAwesomeIcons.lock,
                                                  size: 25,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                              hintText: "Password",
                                              hintStyle: TextStyle(
                                                  color: Colors.grey[600], fontSize: 20),
                                              suffixIcon: InkWell(
                                                onTap: () {
                                                  setState(() {
                                                    visiable_password = !visiable_password;
                                                  });
                                                },
                                                child: Icon(
                                                  visiable_password
                                                      ? Icons.remove_red_eye_outlined
                                                      : Icons.visibility_off_outlined,
                                                  color: Colors.grey[600],
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
                                ? Center(
                                child: Text(
                                  passwordmessage,
                                  style: TextStyle(color: Colors.red),
                                ))
                                : Container(),
                            SizedBox(
                              height: MediaQuery.of(context).size.height * 0.025,
                            ),
                            if (hasMultipleCompanies) ...[

                              SingleSelectionButtons(
                                buttonOptions: companies,
                                onSelected: (index) {
                                  selectCompany(companies[index]["company"]!,companies[index]["role"]!);
                                },
                              ),
                            ],


                            SizedBox(
                              height: MediaQuery.of(context).size.height * 0.015,
                            ),
                            // Forgot password
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [


                                GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (context) => ForgotPassword()));
                                  },
                                  child: Text(
                                    "Forgot password?",
                                    style: TextStyle(
                                        fontSize: MediaQuery.of(context).size.width * 0.02,
                                        color: Colors.blue),
                                  ),
                                ),
                                SizedBox(
                                  width: MediaQuery.of(context).size.width * 0.099,
                                ),
                              ],
                            ),
                            SizedBox(
                              height: MediaQuery.of(context).size.height * 0.025,
                            ),

                            GestureDetector(
                              onTap: () async {
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
                                  if (password.text.isEmpty) {
                                    setState(() {
                                      passworderror = true;
                                      passwordmessage = "Password is required";
                                    });
                                  } else {
                                    setState(() {
                                      passworderror = false;
                                      //firstnamemessage = "Firstname is required";
                                    });
                                  }
                                  if(selectedrole == null){
                                    setState(() {
                                      roleerror = true;
                                      rolemessage = "Please select the role";
                                    });
                                  }
                                  else{
                                    setState(() {
                                      roleerror = false;
                                      //firstnamemessage = "Firstname is required";
                                    });
                                  }
                                  if(selectedrole != "1" && selectedrole != null && company.text.isEmpty){
                                    setState(() {
                                      companyerror = true;
                                      companymessage = "Company Name is required";
                                    });
                                  }
                                  else{
                                    setState(() {
                                      companyerror = false;
                                      //firstnamemessage = "Firstname is required";
                                    });
                                  }


                                });
                                if(selectedrole == ""){
                                  Fluttertoast.showToast(msg: "Please select the company");
                                }
                                else if (emailerror == false && passworderror == false ) {

                                  if(selectedrole == "admin")
                                    await loginsubmit();
                                  if(selectedrole != "admin")
                                    await checkCompany(selectedCompany);
                                  // Save authentication status to SharedPreferences

                                }
                              },
                              child: Center(
                                child: Container(
                                  height: MediaQuery.of(context).size.height * 0.045,
                                  width: MediaQuery.of(context).size.width * 0.8,
                                  decoration: BoxDecoration(
                                    color: Colors.black,
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
                                          "Login",
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize:
                                              MediaQuery.of(context).size.width *
                                                  0.03),
                                        ),
                                        SizedBox(
                                          height:
                                          MediaQuery.of(context).size.width * 0.015,
                                        ),
                                        Icon(
                                          Icons.arrow_forward_ios_sharp,
                                          color: Colors.white,
                                          size:
                                          MediaQuery.of(context).size.width * 0.03,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),




                      // Register now
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.04,
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Don't have an account ? ",
                            style: TextStyle(
                                color: Colors.black,
                                fontSize: MediaQuery.of(context).size.width * 0.03),
                          ),
                          GestureDetector(
                            onTap: () {
                              Navigator.push(context,
                                  MaterialPageRoute(builder: (context) => Signup()));
                            },
                            child: Container(
                              child: Text(
                                "Register now",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                    fontSize:
                                    MediaQuery.of(context).size.width * 0.03),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.04,
                      ),
                      // SizedBox(
                      //   height: MediaQuery.of(context).size.height * 0.1,
                      // ),
                    ],
                  );
                }

                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if(!isEmailSubmitted &&  MediaQuery.of(context).size.height > 700 && hasMultipleCompanies)
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.25,
                        ),
                      if(isEmailSubmitted &&  MediaQuery.of(context).size.height > 700 && !hasMultipleCompanies)
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.15,
                        ),
                      if(!isEmailSubmitted &&  MediaQuery.of(context).size.height > 700)
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.15,
                        ),
                      if(MediaQuery.of(context).size.height < 670)
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
                        height: MediaQuery.of(context).size.height * 0.025,
                      ),
                      // Welcome
                      Center(
                        child: Text(
                          "Welcome to 302 Rentals",
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: MediaQuery.of(context).size.width * 0.05,
                          ),
                        ),
                      ),
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.02,
                      ),
                      // Login text
                      Center(
                        child: Text(
                          "Please login here...",
                          style: TextStyle(
                              color: Colors.black,
                              fontSize: MediaQuery.of(context).size.width * 0.036),
                        ),
                      ),
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.05,
                      ),

                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.025,
                      ),
                      // Email
                      Row(
                        children: [
                          SizedBox(
                            width: MediaQuery.of(context).size.width * 0.099,
                          ),
                          Expanded(
                            flex: 1,
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
                                          _hasMultipleCompanies = false;
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
                                        hintText: "Business Email",
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
                            width: MediaQuery.of(context).size.width * 0.095,
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

                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.025,
                      ),
                      if(!isEmailSubmitted)
                        Column(
                          children: [
                            Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [


                                    GestureDetector(
                                      onTap: () {
                                        Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                                builder: (context) => ForgotPassword()));
                                      },
                                      child: Text(
                                        "Forgot password?",
                                        style: TextStyle(
                                            fontSize: MediaQuery.of(context).size.width * 0.035,
                                            color: Colors.blue),
                                      ),
                                    ),
                                    SizedBox(
                                      width: MediaQuery.of(context).size.width * 0.099,
                                    ),
                                  ],
                                ),
                                SizedBox(
                                  height: MediaQuery.of(context).size.height * 0.025,
                                ),

                              ],
                            ),
                            SizedBox(
                              height: MediaQuery.of(context).size.height * 0.035,
                            ),
                            InkWell(
                              onTap: (){
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
                                  submitEmail();
                                }


                              },
                              child: Center(
                                child: Container(
                                  height: MediaQuery.of(context).size.height * 0.06,
                                  width: MediaQuery.of(context).size.width * 0.8,
                                  decoration: BoxDecoration(
                                    color: Colors.black,
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
                                              fontSize:
                                              MediaQuery.of(context).size.width *
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
                      if(isEmailSubmitted)
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [

                            Row(
                              children: [
                                SizedBox(
                                  width: MediaQuery.of(context).size.width * 0.099,
                                ),
                                Expanded(
                                  flex: 1,
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
                                            keyboardType: TextInputType.text,
                                            onChanged: (value) {
                                              setState(() {
                                                passworderror = false;
                                              });
                                            },
                                            controller: password,
                                            obscureText: visiable_password,
                                            cursorColor: blueColor,
                                            decoration: InputDecoration(
                                              enabledBorder: passworderror
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
                                                // color: Colors.blue,
                                                padding: EdgeInsets.all(13),
                                                child: FaIcon(
                                                  FontAwesomeIcons.lock,
                                                  size: 20,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                              hintText: "Password",
                                              hintStyle: TextStyle(
                                                  color: Colors.grey[600], fontSize: 15),
                                              suffixIcon: InkWell(
                                                onTap: () {
                                                  setState(() {
                                                    visiable_password = !visiable_password;
                                                  });
                                                },
                                                child: Icon(
                                                  visiable_password
                                                      ? Icons.remove_red_eye_outlined
                                                      : Icons.visibility_off_outlined,
                                                  color: Colors.grey[600],
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
                                ? Center(
                                child: Text(
                                  passwordmessage,
                                  style: TextStyle(color: Colors.red),
                                ))
                                : Container(),
                            SizedBox(
                              height: MediaQuery.of(context).size.height * 0.025,
                            ),
                            if (hasMultipleCompanies) ...[

                              SingleSelectionButtons(
                                buttonOptions: companies,
                                onSelected: (index) {
                                  selectCompany(companies[index]["company"]!,companies[index]["role"]!);
                                },
                              ),
                            ],


                            SizedBox(
                              height: MediaQuery.of(context).size.height * 0.015,
                            ),
                            // Forgot password
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                SizedBox(
                                  width: MediaQuery.of(context).size.width * 0.11,
                                ),


                                GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (context) => ForgotPassword()));
                                  },
                                  child: Text(
                                    "Forgot password?",
                                    style: TextStyle(
                                        fontSize: MediaQuery.of(context).size.width * 0.035,
                                        color: Colors.blue),
                                  ),
                                ),
                                SizedBox(
                                  width: MediaQuery.of(context).size.width * 0.099,
                                ),
                              ],
                            ),
                            SizedBox(
                              height: MediaQuery.of(context).size.height * 0.025,
                            ),
                            // Login button

                            GestureDetector(
                              onTap: () async {
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
                                  if (password.text.isEmpty) {
                                    setState(() {
                                      passworderror = true;
                                      passwordmessage = "Password is required";
                                    });
                                  } else {
                                    setState(() {
                                      passworderror = false;
                                      //firstnamemessage = "Firstname is required";
                                    });
                                  }
                                  if(selectedrole == null){
                                    setState(() {
                                      roleerror = true;
                                      rolemessage = "Please select the role";
                                    });
                                  }
                                  else{
                                    setState(() {
                                      roleerror = false;
                                      //firstnamemessage = "Firstname is required";
                                    });
                                  }
                                  if(selectedrole != "1" && selectedrole != null && company.text.isEmpty){
                                    setState(() {
                                      companyerror = true;
                                      companymessage = "Company Name is required";
                                    });
                                  }
                                  else{
                                    setState(() {
                                      companyerror = false;
                                      //firstnamemessage = "Firstname is required";
                                    });
                                  }


                                });
                                if(selectedrole == ""){
                                  Fluttertoast.showToast(msg: "Please select the company");
                                }
                                else if (emailerror == false && passworderror == false ) {

                                  if(selectedrole == "admin")
                                    await loginsubmit();
                                  if(selectedrole != "admin")
                                    await checkCompany(selectedCompany);
                                  // Save authentication status to SharedPreferences

                                }
                              },
                              child: Center(
                                child: Container(
                                  height: MediaQuery.of(context).size.height * 0.06,
                                  width: MediaQuery.of(context).size.width * 0.8,
                                  decoration: BoxDecoration(
                                    color: Colors.black,
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
                                          "Login",
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize:
                                              MediaQuery.of(context).size.width *
                                                  0.045),
                                        ),
                                        SizedBox(
                                          height:
                                          MediaQuery.of(context).size.width * 0.015,
                                        ),
                                        Icon(
                                          Icons.arrow_forward_ios_sharp,
                                          color: Colors.white,
                                          size:
                                          MediaQuery.of(context).size.width * 0.045,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),




                      // Register now
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.04,
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Don't have an account ? ",
                            style: TextStyle(
                                color: Colors.black,
                                fontSize: MediaQuery.of(context).size.width * 0.04),
                          ),
                          GestureDetector(
                            onTap: () {
                              Navigator.push(context,
                                  MaterialPageRoute(builder: (context) => Signup()));
                            },
                            child: Container(
                              child: Text(
                                "Register now",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                    fontSize:
                                    MediaQuery.of(context).size.width * 0.037),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.04,
                      ),
                      // SizedBox(
                      //   height: MediaQuery.of(context).size.height * 0.1,
                      // ),
                    ],
                  ),
                );
              }
          )


      ),
    );
  }

  Future<void> checkToken(String token) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    // String? token = prefs.getString('token');

    final response = await apiPost(
      Uri.parse('${Api_url}/api/admin/token_check_api'),
      headers: {
        // "authorization": "CRM $token",
        //"id":"CRM $id",
        "Content-Type": "application/json"
      },
      body: json.encode({"token": token}),
    );
    print(response.body);
    final jsonData = json.decode(response.body);

    if (jsonData['id'] != "") {
      print(jsonData);
      //prefs.setString('checkedToken',jsonData["token"]);
      String? adminId = jsonData['data']['admin_id'];
      print(jsonData);
      String? companyName = jsonData['data']['company_name'];

      prefs.setString('checkedToken', token);
      prefs.setString('adminId', adminId!);

      prefs.setString('companyName', companyName!);
      prefs.setString("role", "Admin");
      prefs.setString('first_name', jsonData['data']['first_name']);
      prefs.setString('last_name', jsonData['data']['last_name']);
      prefs.setString('first_name', jsonData['data']['first_name']);

      prefs.setString('last_name', jsonData['data']['last_name']);
      prefs.setString('email', jsonData['data']['email']);
      prefs.setString('superadminId', jsonData['data']['superadmin_id']);
      if (!mounted) return;

      await Provider.of<checkPlanPurchaseProiver>(context, listen: false)
          .fetchPlanPurchaseDetail();

      // Access the expiration date
      var provider =
      Provider.of<checkPlanPurchaseProiver>(context, listen: false);
      var expirationDateString =
          provider.checkplanpurchaseModel?.data?.expirationDate;

      DateTime? expirationDate;
      if (expirationDateString != null) {
        expirationDate = DateFormat('yyyy-MM-dd').parse(expirationDateString);
      }


      DateTime now = DateTime.now();
      String currentDate = DateFormat('yyyy-MM-dd').format(now);
      print(currentDate);

      bool isPlanActive = expirationDate != null && expirationDate.isAfter(now);

      if (isPlanActive) {
        print('The plan is active.');
      } else {
        print('The plan is not active.');
      }
      Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (context) =>
              isPlanActive ? Dashboard() : PlanPurchaseCard()));
    } else {
      print('Failed to check token');
    }
  }

  Future<void> checkTokenStaff(String token) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    // String? token = prefs.getString('token');

    final response = await apiPost(
      Uri.parse('${Api_url}/api/staffmember/token_check'),
      headers: {
        // "authorization": "CRM $token",
        //"id":"CRM $id",
        "Content-Type": "application/json"
      },
      body: json.encode({"token": token}),
    );
    print(response.body);
    final jsonData = json.decode(response.body);
    if (jsonData['id'] != "") {
      print(jsonData);
      //prefs.setString('checkedToken',jsonData["token"]);
      // String? adminId = jsonData['data']['admin_id'];
      // print('Admin ID: $adminId');
      // await Provider.of<StaffPermissionProvider>(context, listen: false).fetchPermissions();
      prefs.setString("staff_id", jsonData["staffmember_id"]);
      prefs.setString("role", "Staffmember");
      print(jsonData["staffmember_firstName"]);
      prefs.setString('companyName', selectedCompany);
      prefs.setString('checkedToken', token);
      //  prefs.setString('adminId', adminId!);
      String stafffirstname = jsonData['staffmember_name'];
      List<String> firstname = stafffirstname.split(" ");
      print(firstname);
      prefs.setString('first_name', firstname.first);
      prefs.setString('last_name', firstname[1]);
      await Provider.of<StaffPermissionProvider>(context, listen: false)
          .fetchPermissions();
      Navigator.push(
          context, MaterialPageRoute(builder: (context) => Dashboard_staff()));
    } else {
      print('Failed to check token');
    }
  }

  Future<void> checkTokenTenant(String token) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    // String? token = prefs.getString('token');
    // List<Map<String,dynamic>> selectedroledata = roles.where((element) => element["role_id"] == selectedRole).toList();
    // String rolename  =selectedroledata.first["role_name"];

    final response = await apiPost(
      Uri.parse('${Api_url}/api/tenant/token_check'),
      headers: {
        // "authorization": "CRM $token",
        //"id":"CRM $id",
        "Content-Type": "application/json"
      },
      body: json.encode({"token": token}),
    );
    print(response.body);
    final jsonData = json.decode(response.body);
    if (jsonData['id'] != "") {
      print(jsonData);
      //prefs.setString('checkedToken',jsonData["token"]);
      // String? adminId = jsonData['data']['admin_id'];
      // print('Admin ID: $adminId');
      prefs.setString("role", "Tenant");
      prefs.setString('companyName', selectedCompany);
      print(jsonData["tenant_firstName"]);
      prefs.setString("tenant_id", jsonData["tenant_id"]);
      prefs.setString('checkedToken', token);
      //  prefs.setString('adminId', adminId!);
      prefs.setString('first_name', jsonData['tenant_firstName']);
      prefs.setString('last_name', jsonData['tenant_lastName']);
      prefs.setString('email', jsonData['tenant_email']);
      await Provider.of<PermissionProvider>(context, listen: false)
          .fetchPermissions();
      Navigator.push(context,
          MaterialPageRoute(builder: (context) => Dashboard_tenants()));
    } else {
      print('Failed to check token');
    }
  }

  Future<void> checkTokenVendor(String token) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    // String? token = prefs.getString('token');
    // List<Map<String,dynamic>> selectedroledata = roles.where((element) => element["role_id"] == selectedRole).toList();
    // String rolename  =selectedroledata.first["role_name"];
    // print('${Api_url}/api/${rolename.toLowerCase()}/token_check');
    final response = await apiPost(
      Uri.parse('${Api_url}/api/vendor/token_check'),
      headers: {
        // "authorization": "CRM $token",
        //"id":"CRM $id",
        "Content-Type": "application/json"
      },
      body: json.encode({"token": token}),
    );
    final jsonData = json.decode(response.body);
    if (jsonData['id'] != "") {
      print(jsonData);
      //prefs.setString('checkedToken',jsonData["token"]);
      // String? adminId = jsonData['data']['admin_id'];
      // print('Admin ID: $adminId');
      String stafffirstname = jsonData['vendor_name'];
      List<String> firstname = stafffirstname.split(" ");
      print(firstname);
      await Provider.of<PermissionProvider>(context, listen: false)
          .fetchPermissions();
      prefs.setString('first_name', firstname.first);
      prefs.setString('last_name', firstname[1]);
      prefs.setString('companyName', selectedCompany);
      prefs.setString("role", "Vendor");
      print(jsonData["vendor_firstName"]);
      prefs.setString("vendor_id", jsonData["vendor_id"]);
      prefs.setString('checkedToken', token);
      //  prefs.setString('adminId', adminId!);
      // prefs.setString('first_name', jsonData['${rolename.toLowerCase()}_firstName']);
      // prefs.setString('last_name', jsonData['${rolename.toLowerCase()}_lastName']);
      prefs.setString('email', jsonData['vendor_email']);
      // prefs.setString('checkedToken', token);
      //  prefs.setString('adminId', adminId!);

      Navigator.push(context,
          MaterialPageRoute(builder: (context) => MainScreen()));
    } else {
      print('Failed to check token');
    }
  }

  Future<void> checkCompany(String token) async {
    setState(() {
      loading = true;
    });
    SharedPreferences prefs = await SharedPreferences.getInstance();
    // String? token = prefs.getString('token');
    final response = await apiGet(
      Uri.parse('${Api_url}/api/admin/check_company/${token}'),
      headers: {
        // "authorization": "CRM $token",
        //"id":"CRM $id",
        "Content-Type": "application/json"
      },
      // body: json.encode({"token": token}),
    );
    print(response.body);
    final jsonData = json.decode(response.body);
    //if (jsonData["data"]['id'] != "") {
    print(jsonData);
    if (jsonData["statusCode"] == 200) {
      //prefs.setString('checkedToken',jsonData["token"]);
      String? adminId = jsonData['data']['admin_id'];
      prefs.setString('checkedToken', token);
      prefs.setString('adminId', adminId!);

      loginsubmit_usingrole(adminId);
    } else {
      setState(() {
        loading = false;
      });
    }
  }

  Future<void> loginsubmit_usingrole(String adminId) async {
    setState(() {
      loading = true;
    });
    // List<Map<String,dynamic>> selectedroledata = roles.where((element) => element["role_id"] == selectedRole).toList();
    String rolename = selectedrole;

    // print({"email": email.text, "password": password.text,"admin_id":adminId,"company":company.text});
    final response = await apiPost(
        Uri.parse('${Api_url}/api/${rolename.toLowerCase()}/login'),
        body: {
          "email": email.text,
          "password": password.text,
          "admin_id": adminId,
          "company": selectedCompany
        });
    print(response.body);
    final jsonData = json.decode(response.body);
    if (jsonData["statusCode"] == 200) {
      print(jsonData);
      SharedPreferences prefs = await SharedPreferences.getInstance();
      prefs.setBool('isAuthenticated', true);
      prefs.setString('token', jsonData["token"]);
      prefs.setString('adminId', adminId);
      print(rolename);
      if (rolename == "staffmember") await checkTokenStaff(jsonData["token"]);
      if (rolename == "tenant") await checkTokenTenant(jsonData["token"]);
      if (rolename == "vendor") await checkTokenVendor(jsonData["token"]);

      //  await checkToken("token", "id");
      // Navigator.push(
      //     context, MaterialPageRoute(builder: (context) => Dashboard()));

      setState(() {
        loading = false;
      });
    } else {
      Fluttertoast.showToast(msg: _formatErrorMessage(jsonData["message"]));
      setState(() {
        loading = false;
      });
    }
  }

  Future<void> loginsubmit() async {
    setState(() {
      loading = true;
    });
    final response = await apiPost(Uri.parse('${Api_url}/api/admin/login'),
        body: {"email": email.text, "password": password.text});
    print(response.body);
    final jsonData = json.decode(response.body);
    if (jsonData["statusCode"] == 200) {
      print(jsonData);
      SharedPreferences prefs = await SharedPreferences.getInstance();
      prefs.setBool('isAuthenticated', true);
      prefs.setString('token', jsonData["token"]);

      await checkToken(jsonData["token"]);
      //  await checkToken("token", "id");
      // Navigator.push(
      //     context, MaterialPageRoute(builder: (context) => Dashboard()));

      setState(() {
        loading = false;
      });
    } else {
      Fluttertoast.showToast(msg: _formatErrorMessage(jsonData["message"]));
      setState(() {
        loading = false;
      });
    }
  }
}

class SingleSelectionButtons extends StatefulWidget {
  final List<Map<String, String>> buttonOptions;
  final Function(int index) onSelected;

  const SingleSelectionButtons({
    super.key,
    required this.buttonOptions,
    required this.onSelected,
  });

  @override
  _SingleSelectionButtonsState createState() => _SingleSelectionButtonsState();
}

class _SingleSelectionButtonsState extends State<SingleSelectionButtons> {
  int _selectedIndex = -1;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
        builder: (context,contraints) {

          if(contraints.maxWidth > 500){
            return Container(
              width: MediaQuery.of(context).size.width * .8,
              child: Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                alignment: WrapAlignment.start,
                children: widget.buttonOptions.map((option) {
                  final index = widget.buttonOptions.indexOf(option);
                  return SizedBox(
                    width: 320, // Adjusted width to make the button smaller
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _selectedIndex = index;
                          print(index);
                        });
                        widget.onSelected(index);
                      },
                      child: Row(
                        children: [
                          Icon(
                            _selectedIndex == index
                                ? Icons.check_circle
                                : Icons.radio_button_unchecked,
                            color: _selectedIndex == index ? Colors.white : Colors.grey,
                          ),
                          SizedBox(width: 5.0),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                option["company"]!,
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: _selectedIndex == index ? Colors.white : Colors.black,fontSize: 18
                                ),
                              ),
                              Text(
                                capitalizeFirstLetter( option["role"]!),
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: _selectedIndex == index ? Colors.white : Colors.black,fontSize: 16
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 10,horizontal: 5),
                        foregroundColor: _selectedIndex == index
                            ? Colors.white
                            : blueColor,
                        backgroundColor: _selectedIndex == index
                            ? blueColor
                            : Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        side: BorderSide(
                          color: _selectedIndex == index
                              ? blueColor
                              : Colors.grey,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            );
          }
          return Container(
            width: 350,
            child: Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              alignment: WrapAlignment.center,
              children: widget.buttonOptions.map((option) {
                final index = widget.buttonOptions.indexOf(option);
                return SizedBox(
                  width: 320, // Adjusted width to make the button smaller
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _selectedIndex = index;
                        print(index);
                      });
                      widget.onSelected(index);
                    },
                    child: Row(
                      children: [
                        Icon(
                          _selectedIndex == index
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          color: _selectedIndex == index ? Colors.white : Colors.grey,
                        ),
                        SizedBox(width: 5.0),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              option["company"]!,
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _selectedIndex == index ? Colors.white : Colors.black,fontSize: 16
                              ),
                            ),
                            Text(
                              capitalizeFirstLetter( option["role"]!),
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _selectedIndex == index ? Colors.white : Colors.black,fontSize: 12
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 10,horizontal: 5),
                      foregroundColor: _selectedIndex == index
                          ? Colors.white
                          : blueColor,
                      backgroundColor: _selectedIndex == index
                          ? blueColor
                          : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      side: BorderSide(
                        color: _selectedIndex == index
                            ? blueColor
                            : Colors.grey,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          );
        }
    );
  }

  String capitalizeFirstLetter(String input) {
    if (input.isEmpty) return input;
    return input[0].toUpperCase() + input.substring(1);
  }
}*/

import 'package:email_validator/email_validator.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:keyboard_actions/keyboard_actions.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../constant/constant.dart';
import '../../../widgets/appbar.dart';
import 'package:three_zero_two_property/widgets/drawer_tiles.dart';

import '../../../../Model/vendor.dart';

import '../../../repository/vendor_repository.dart';
import '../../../../widgets/titleBar.dart';
import '../../../widgets/custom_drawer.dart';

// class edit_vendor extends StatefulWidget {
//   String? vender_id;
//   edit_vendor({super.key, this.vender_id});
//
//   @override
//   State<edit_vendor> createState() => _edit_vendorState();
// }
//
// class _edit_vendorState extends State<edit_vendor> {
//   String? initialVendorName;
//   String? initialPhoneNumber;
//   String? initialEmail;
//   String? initialPassword;
//   Future<void> _fetchVendor() async {
//     setState(() {
//       isLoading = true;
//     });
//
//     try {
//       final vendor = await vendorRepository.getVendor(widget.vender_id!);
//
//       initialVendorName = vendor.vendorName;
//       initialPhoneNumber = vendor.vendorPhoneNumber;
//       initialEmail = vendor.vendorEmail;
//       initialPassword = vendor.vendorPassword;
//
//       firstName.text = vendor.vendorName!;
//       phoneNumber.text = formatPhoneNumberedit(vendor.vendorPhoneNumber!);
//       email.text = vendor.vendorEmail!;
//       passWord.text = vendor.vendorPassword!;
//     } catch (e) {
//       ScaffoldMessenger.of(context)
//           .showSnackBar(SnackBar(content: Text('Failed to fetch vendor data')));
//     } finally {
//       setState(() {
//         isLoading = false;
//       });
//     }
//   }
//
//   final TextEditingController firstName = TextEditingController();
//
//   final TextEditingController phoneNumber = TextEditingController();
//   bool obsecure = true;
//
//   final TextEditingController email = TextEditingController();
//
//   GlobalKey<FormState> _formkey = GlobalKey<FormState>();
//   final TextEditingController passWord = TextEditingController();
//   bool isLoading = false;
//   bool formValid = false;
//   @override
//   void initState() {
//     // TODO: implement initState
//     super.initState();
//     _fetchVendor();
//   }
//
//   final VendorRepository vendorRepository =
//       VendorRepository(baseUrl: 'https://yourapiurl.com');
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: widget_302_Staff.App_Bar(context: context),
//       backgroundColor: Colors.white,
//       drawer: CustomDrawerStaff(
//         currentpage: "Vendors",
//         dropdown: true,
//       ),
//       body: LayoutBuilder(
//         builder: (context, constraints) {
//           if (constraints.maxWidth > 500) {
//             return Form(
//               key: _formkey,
//               child: SingleChildScrollView(
//                 child: Padding(
//                   padding: const EdgeInsets.all(16.0),
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       SizedBox(
//                         height: 25,
//                       ),
//                       titleBar(
//                         width: MediaQuery.of(context).size.width * .95,
//                         title: 'Edit Vendor',
//                       ),
//                       Padding(
//                         padding: const EdgeInsets.all(12.0),
//                         child: Container(
//                           padding: const EdgeInsets.all(16.0),
//                           width: double.infinity,
//                           decoration: BoxDecoration(
//                               borderRadius: BorderRadius.circular(10.0),
//                               border: Border.all(
//                                 color: Color.fromRGBO(21, 43, 103, 1),
//                               )),
//                           child: Column(
//                             crossAxisAlignment: CrossAxisAlignment.start,
//                             children: [
//                               Text('Vendor Name *',
//                                   style: TextStyle(
//                                       fontSize: 13,
//                                       fontWeight: FontWeight.bold,
//                                       color: blueColor)),
//                               SizedBox(
//                                 height: 10,
//                               ),
//                               CustomTextField(
//                                 keyboardType: TextInputType.text,
//                                 hintText: 'Enter vendor name',
//                                 controller: firstName,
//                                 validator: (value) {
//                                   if (value == null || value.isEmpty) {
//                                     return 'please enter the vendor name';
//                                   }
//                                   return null;
//                                 },
//                               ),
//                               /* SizedBox(
//                           height: 10,
//                         ),
//                         Text('Last Name *',
//                             style: TextStyle(
//                                 fontSize: 13,
//                                 fontWeight: FontWeight.bold,
//                                 color: blueColor)),
//                         SizedBox(
//                           height: 10,
//                         ),
//                         CustomTextField(
//                           keyboardType: TextInputType.text,
//                           hintText: 'Enter last name',
//                           controller: lastName,
//                           validator: (value) {
//                             if (value == null || value.isEmpty) {
//                               return 'please enter the last name';
//                             }
//                             return null;
//                           },
//                         ),*/
//                               SizedBox(
//                                 height: 10,
//                               ),
//                               Text('Phone Number *',
//                                   style: TextStyle(
//                                       fontSize: 13,
//                                       fontWeight: FontWeight.bold,
//                                       color: blueColor)),
//                               SizedBox(
//                                 height: 10,
//                               ),
//                               CustomTextField(
//                                 keyboardType: TextInputType.number,
//                                 inputFormatters: [
//                                   FilteringTextInputFormatter.digitsOnly,
//                                   LengthLimitingTextInputFormatter(10),
//                                   PhoneNumberFormatter(),
//                                 ],
//                                 // keyboardType: TextInputType.numberWithOptions(
//                                 //     signed: true, decimal: true),
//                                 hintText: 'Enter phone number',
//                                 controller: phoneNumber,
//                                 validator: (value) {
//                                   if (value == null || value.isEmpty) {
//                                     return 'please enter the phone number';
//                                   }
//                                   return null;
//                                 },
//                               ),
//                               /*  SizedBox(
//                           height: 10,
//                         ),
//                         Text('Work Number',
//                             style: TextStyle(
//                                 fontSize: 13,
//                                 fontWeight: FontWeight.bold,
//                                 color: blueColor)),
//                         SizedBox(
//                           height: 10,
//                         ),
//                         CustomTextField(
//                           keyboardType: TextInputType.number,
//                           hintText: 'Enter work number',
//                           controller: workNumber,
//                         ),*/
//                               SizedBox(
//                                 height: 10,
//                               ),
//                               Text('Email *',
//                                   style: TextStyle(
//                                       fontSize: 13,
//                                       fontWeight: FontWeight.bold,
//                                       color: blueColor)),
//                               SizedBox(
//                                 height: 10,
//                               ),
//                               CustomTextField(
//                                 keyboardType: TextInputType.emailAddress,
//                                 hintText: 'Enter email',
//                                 controller: email,
//                                 validator: (value) {
//                                   if (value == null || value.isEmpty) {
//                                     return 'please enter email';
//                                   }
//                                   return null;
//                                 },
//                                 email: true,
//                               ),
//                               /* SizedBox(
//                           height: 10,
//                         ),
//                         Text('Alternative Email',
//                             style: TextStyle(
//                                 fontSize: 13,
//                                 fontWeight: FontWeight.bold,
//                                 color: blueColor)),
//                         SizedBox(
//                           height: 10,
//                         ),
//                         CustomTextField(
//                           keyboardType: TextInputType.emailAddress,
//                           hintText: 'Enter alternative email',
//                           controller: alterEmail,
//                         ),*/
//                               SizedBox(
//                                 height: 10,
//                               ),
//                               Text('Password *',
//                                   style: TextStyle(
//                                       fontSize: 13,
//                                       fontWeight: FontWeight.bold,
//                                       color: blueColor)),
//                               SizedBox(
//                                 height: 10,
//                               ),
//                               Row(
//                                 children: [
//                                   Expanded(
//                                     child: CustomTextField(
//                                       keyboardType: TextInputType.text,
//                                       obscureText: obsecure,
//                                       hintText: 'Enter password',
//                                       controller: passWord,
//                                       validator: (value) {
//                                         if (value == null) {
//                                           return 'please enter password';
//                                         }
//                                         return null;
//                                       },
//                                       pass: true,
//                                     ),
//                                   ),
//                                   SizedBox(
//                                       width:
//                                           10), // Add some space between the widgets
//                                   InkWell(
//                                     onTap: () {
//                                       setState(() {
//                                         obsecure = !obsecure;
//                                       });
//                                     },
//                                     child: Container(
//                                       width: 38,
//                                       height: 50,
//                                       child: Center(
//                                         child: FaIcon(
//                                           !obsecure
//                                               ? FontAwesomeIcons.eyeSlash
//                                               : FontAwesomeIcons.eye,
//                                           size: 20,
//                                           color: Colors.black,
//                                         ),
//                                       ),
//                                       decoration: BoxDecoration(
//                                         color: Colors.white,
//                                         boxShadow: [
//                                           BoxShadow(
//                                             color: Colors.black26,
//                                             offset: Offset(1.2, 1.2),
//                                             blurRadius: 3.0,
//                                             spreadRadius: 1.0,
//                                           ),
//                                         ],
//                                         border: Border.all(
//                                             width: 0, color: Colors.white),
//                                         borderRadius:
//                                             BorderRadius.circular(6.0),
//                                       ),
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                               SizedBox(
//                                 height: 16,
//                               ),
//                               Row(
//                                 mainAxisAlignment: MainAxisAlignment.start,
//                                 children: [
//                                   Container(
//                                     height: 50,
//                                     width: 140,
//                                     decoration: BoxDecoration(
//                                       borderRadius: BorderRadius.circular(8.0),
//                                     ),
//                                     child: ElevatedButton(
//                                       style: ElevatedButton.styleFrom(
//                                         backgroundColor:
//                                             blueColor,
//                                         shape: RoundedRectangleBorder(
//                                           borderRadius:
//                                               BorderRadius.circular(8.0),
//                                         ),
//                                       ),
//                                       onPressed: () async {
//                                         setState(() {
//                                           formValid = true;
//                                         });
//                                         if (_formkey.currentState!.validate()) {
//                                           setState(() {
//                                             formValid = false;
//                                           });
//
//                                           await addTenant();
//                                         }
//                                       },
//                                       child: isLoading
//                                           ? Center(
//                                               child: SpinKitFadingCircle(
//                                                 color: Colors.white,
//                                                 size: 55.0,
//                                               ),
//                                             )
//                                           : Text(
//                                               'Edit Vendor',
//                                               style: TextStyle(
//                                                   color: Color(0xFFf7f8f9)),
//                                             ),
//                                     ),
//                                   ),
//                                   SizedBox(
//                                     width: 8,
//                                   ),
//                                   Container(
//                                       height: 50,
//                                       width: 140,
//                                       decoration: BoxDecoration(
//                                           borderRadius:
//                                               BorderRadius.circular(8.0)),
//                                       child: ElevatedButton(
//                                           style: ElevatedButton.styleFrom(
//                                               backgroundColor:
//                                                   Color(0xFFffffff),
//                                               shape: RoundedRectangleBorder(
//                                                   borderRadius:
//                                                       BorderRadius.circular(
//                                                           8.0))),
//                                           onPressed: () {
//                                             Navigator.pop(context);
//                                           },
//                                           child: Text(
//                                             'Cancel',
//                                             style: TextStyle(
//                                                 color: Color(0xFF748097)),
//                                           )))
//                                 ],
//                               ),
//                             ],
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//             );
//           } else {
//             return Form(
//               key: _formkey,
//               child: SingleChildScrollView(
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     SizedBox(
//                       height: 25,
//                     ),
//                     titleBar(
//                       width: MediaQuery.of(context).size.width * .94,
//                       title: 'Edit Vendor',
//                     ),
//                     Padding(
//                       padding: const EdgeInsets.all(12.0),
//                       child: Container(
//                         padding: const EdgeInsets.all(16.0),
//                         width: double.infinity,
//                         decoration: BoxDecoration(
//                             borderRadius: BorderRadius.circular(10.0),
//                             border: Border.all(
//                               color: Color.fromRGBO(21, 43, 103, 1),
//                             )),
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             Text('Vendor Name *',
//                                 style: TextStyle(
//                                     fontSize: 13,
//                                     fontWeight: FontWeight.bold,
//                                     color: blueColor)),
//                             SizedBox(
//                               height: 10,
//                             ),
//                             CustomTextField(
//                               keyboardType: TextInputType.text,
//                               hintText: 'Enter vendor name',
//                               controller: firstName,
//                               validator: (value) {
//                                 if (value == null || value.isEmpty) {
//                                   return 'please enter the vendor name';
//                                 }
//                                 return null;
//                               },
//                             ),
//                             /* SizedBox(
//                         height: 10,
//                       ),
//                       Text('Last Name *',
//                           style: TextStyle(
//                               fontSize: 13,
//                               fontWeight: FontWeight.bold,
//                               color: blueColor)),
//                       SizedBox(
//                         height: 10,
//                       ),
//                       CustomTextField(
//                         keyboardType: TextInputType.text,
//                         hintText: 'Enter last name',
//                         controller: lastName,
//                         validator: (value) {
//                           if (value == null || value.isEmpty) {
//                             return 'please enter the last name';
//                           }
//                           return null;
//                         },
//                       ),*/
//                             SizedBox(
//                               height: 10,
//                             ),
//                             Text('Phone Number *',
//                                 style: TextStyle(
//                                     fontSize: 13,
//                                     fontWeight: FontWeight.bold,
//                                     color: blueColor)),
//                             SizedBox(
//                               height: 10,
//                             ),
//                             CustomTextField(
//                               keyboardType: TextInputType.number,
//                               inputFormatters: [
//                                 FilteringTextInputFormatter.digitsOnly,
//                                 LengthLimitingTextInputFormatter(10),
//                                 PhoneNumberFormatter(),
//                               ],
//                               // keyboardType: TextInputType.numberWithOptions(
//                               //     signed: true, decimal: true),
//                               hintText: 'Enter phone number',
//                               controller: phoneNumber,
//                               validator: (value) {
//                                 if (value == null || value.isEmpty) {
//                                   return 'please enter the phone number';
//                                 }
//                                 return null;
//                               },
//                             ),
//                             /*  SizedBox(
//                         height: 10,
//                       ),
//                       Text('Work Number',
//                           style: TextStyle(
//                               fontSize: 13,
//                               fontWeight: FontWeight.bold,
//                               color: blueColor)),
//                       SizedBox(
//                         height: 10,
//                       ),
//                       CustomTextField(
//                         keyboardType: TextInputType.number,
//                         hintText: 'Enter work number',
//                         controller: workNumber,
//                       ),*/
//                             SizedBox(
//                               height: 10,
//                             ),
//                             Text('Email *',
//                                 style: TextStyle(
//                                     fontSize: 13,
//                                     fontWeight: FontWeight.bold,
//                                     color: blueColor)),
//                             SizedBox(
//                               height: 10,
//                             ),
//                             CustomTextField(
//                               keyboardType: TextInputType.emailAddress,
//                               hintText: 'Enter email',
//                               controller: email,
//                               validator: (value) {
//                                 if (value == null || value.isEmpty) {
//                                   return 'please enter email';
//                                 }
//                                 return null;
//                               },
//                               email: true,
//                             ),
//                             /* SizedBox(
//                         height: 10,
//                       ),
//                       Text('Alternative Email',
//                           style: TextStyle(
//                               fontSize: 13,
//                               fontWeight: FontWeight.bold,
//                               color: blueColor)),
//                       SizedBox(
//                         height: 10,
//                       ),
//                       CustomTextField(
//                         keyboardType: TextInputType.emailAddress,
//                         hintText: 'Enter alternative email',
//                         controller: alterEmail,
//                       ),*/
//                             SizedBox(
//                               height: 10,
//                             ),
//                             Text('Password *',
//                                 style: TextStyle(
//                                     fontSize: 13,
//                                     fontWeight: FontWeight.bold,
//                                     color: blueColor)),
//                             SizedBox(
//                               height: 10,
//                             ),
//                             Row(
//                               children: [
//                                 Expanded(
//                                   child: CustomTextField(
//                                     keyboardType: TextInputType.text,
//                                     obscureText: obsecure,
//                                     hintText: 'Enter password',
//                                     controller: passWord,
//                                     validator: (value) {
//                                       if (value == null) {
//                                         return 'please enter password';
//                                       }
//                                       return null;
//                                     },
//                                     pass: true,
//                                   ),
//                                 ),
//                                 SizedBox(
//                                     width:
//                                         10), // Add some space between the widgets
//                                 InkWell(
//                                   onTap: () {
//                                     setState(() {
//                                       obsecure = !obsecure;
//                                     });
//                                   },
//                                   child: Container(
//                                     width: 38,
//                                     height: 50,
//                                     child: Center(
//                                       child: FaIcon(
//                                         !obsecure
//                                             ? FontAwesomeIcons.eyeSlash
//                                             : FontAwesomeIcons.eye,
//                                         size: 20,
//                                         color: Colors.black,
//                                       ),
//                                     ),
//                                     decoration: BoxDecoration(
//                                       color: Colors.white,
//                                       boxShadow: [
//                                         BoxShadow(
//                                           color: Colors.black26,
//                                           offset: Offset(1.2, 1.2),
//                                           blurRadius: 3.0,
//                                           spreadRadius: 1.0,
//                                         ),
//                                       ],
//                                       border: Border.all(
//                                           width: 0, color: Colors.white),
//                                       borderRadius: BorderRadius.circular(6.0),
//                                     ),
//                                   ),
//                                 ),
//                               ],
//                             ),
//                             SizedBox(
//                               height: 16,
//                             ),
//                             Row(
//                               mainAxisAlignment: MainAxisAlignment.start,
//                               children: [
//                                 Container(
//                                   height: 50,
//                                   width: 140,
//                                   decoration: BoxDecoration(
//                                     borderRadius: BorderRadius.circular(8.0),
//                                   ),
//                                   child: ElevatedButton(
//                                     style: ElevatedButton.styleFrom(
//                                       backgroundColor:
//                                           blueColor,
//                                       shape: RoundedRectangleBorder(
//                                         borderRadius:
//                                             BorderRadius.circular(8.0),
//                                       ),
//                                     ),
//                                     onPressed: () async {
//                                       if (_formkey.currentState!.validate()) {
//                                         bool isFormValid = true;
//
//                                         // Validate each field and update the state accordingly
//                                         if (firstName.text.isEmpty) {
//                                           setState(() {
//                                             isFormValid = false;
//                                           });
//                                         }
//
//                                         if (phoneNumber.text.isEmpty) {
//                                           setState(() {
//                                             isFormValid = false;
//                                           });
//                                         }
//
//                                         if (email.text.isEmpty) {
//                                           setState(() {
//                                             isFormValid = false;
//                                           });
//                                         }
//
//                                         // Check for changes
//                                         bool hasChanges = firstName.text !=
//                                             initialVendorName ||
//                                             phoneNumber.text !=
//                                                 initialPhoneNumber ||
//                                             email.text != initialEmail ||
//                                             passWord.text != initialPassword;
//
//                                         if (!hasChanges) {
//                                           print(
//                                               "No changes made, API call not necessary.");
//                                           Navigator.of(context).pop(
//                                               false); // Optionally navigate back
//                                           return;
//                                         }
//
//                                         if (!isFormValid) {
//                                           return; // Exit early if the form is not valid
//                                         }
//
//                                         // Proceed with API call
//                                         setState(() {
//                                           isLoading = true; // Start loading
//                                         });
//
//                                         SharedPreferences prefs =
//                                         await SharedPreferences
//                                             .getInstance();
//                                         String adminId =
//                                         prefs.getString("adminId")!;
//
//                                         final vendor = Vendor(
//                                           adminId: adminId,
//                                           vendorName: firstName.text,
//                                           vendorPhoneNumber: phoneNumber.text,
//                                           vendorEmail: email.text,
//                                           vendorPassword: passWord.text,
//                                         );
//
//                                         final success = await vendorRepository
//                                             .update_vendor(
//                                             vendor, widget.vender_id!);
//                                         setState(() {
//                                           isLoading = false; // Stop loading
//                                         });
//
//                                         if (success) {
//                                           Fluttertoast.showToast(
//                                               msg:
//                                               "Vendor Edited successfully");
//                                           Navigator.of(context).pop(true);
//                                         }
//                                       } else {
//                                         print("Failed to edit vendor");
//                                         // ScaffoldMessenger.of(context)
//                                         //     .showSnackBar(SnackBar(
//                                         //         content: Text(
//                                         //             'Failed to edit vendor')));
//                                       }
//                                     },
//                                     child: isLoading
//                                         ? Center(
//                                             child: SpinKitFadingCircle(
//                                               color: Colors.white,
//                                               size: 55.0,
//                                             ),
//                                           )
//                                         : Text(
//                                             'Edit Vendor',
//                                             style: TextStyle(
//                                                 fontWeight: FontWeight.bold,
//                                                 color: Color(0xFFf7f8f9)),
//                                           ),
//                                   ),
//                                 ),
//                                 SizedBox(
//                                   width: 8,
//                                 ),
//                                 Container(
//                                     height: 50,
//                                     width: 140,
//                                     decoration: BoxDecoration(
//                                         borderRadius:
//                                             BorderRadius.circular(8.0)),
//                                     child: ElevatedButton(
//                                         style: ElevatedButton.styleFrom(
//                                             backgroundColor: Color(0xFFffffff),
//                                             shape: RoundedRectangleBorder(
//                                                 borderRadius:
//                                                     BorderRadius.circular(
//                                                         8.0))),
//                                         onPressed: () {
//                                           Navigator.pop(context);
//                                         },
//                                         child: Text(
//                                           'Cancel',
//                                           style: TextStyle(
//                                               color: Color(0xFF748097)),
//                                         )))
//                               ],
//                             ),
//                           ],
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             );
//           }
//         },
//       ),
//     );
//   }
//
//   Future<void> addTenant() async {
//     setState(() {
//       isLoading = true;
//     });
//
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     String adminId = prefs.getString("adminId")!;
//
//     final vendor = Vendor(
//       adminId: adminId,
//       vendorName: firstName.text,
//       vendorPhoneNumber: phoneNumber.text,
//       vendorEmail: email.text,
//       vendorPassword: passWord.text,
//     );
//
//     final success =
//         await vendorRepository.update_vendor(vendor, widget.vender_id!);
//     if (success) {
//       //   ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Vendor added successfully')));
//     } else {
//       ScaffoldMessenger.of(context)
//           .showSnackBar(SnackBar(content: Text('Failed to add vendor')));
//     }
//     setState(() {
//       isLoading = false;
//     });
//
//     if (success) {
//       print('Form is valid');
//       Fluttertoast.showToast(msg: "Vendor Edited successfully");
//       Navigator.of(context).pop(true);
//     } else {
//       print('Form is invalid');
//     }
//   }
// }
//
// class CustomTextField extends StatefulWidget {
//   final String hintText;
//   final TextEditingController? controller;
//   final TextInputType keyboardType;
//   final String? Function(String?)? validator;
//   final bool obscureText;
//   final Function(String)? onChanged;
//   final Function(String)? onChanged2;
//   final Widget? suffixIcon;
//   final IconData? prefixIcon;
//   final void Function()? onSuffixIconPressed;
//   final void Function()? onTap;
//   final bool readOnnly;
//   final bool? email;
//   final bool? pass;
//   final List<TextInputFormatter>? inputFormatters;
//
//   CustomTextField({
//     Key? key,
//     this.controller,
//     required this.hintText,
//     this.obscureText = false,
//     this.keyboardType = TextInputType.emailAddress,
//     this.readOnnly = false,
//     this.prefixIcon,
//     this.suffixIcon,
//     this.validator,
//     this.onSuffixIconPressed,
//     this.onTap,
//     this.onChanged,
//     this.onChanged2,
//     this.email,
//     this.pass,
//     this.inputFormatters
//     // Initialize onTap
//   }) : super(key: key);
//
//   @override
//   CustomTextFieldState createState() => CustomTextFieldState();
// }
//
// class CustomTextFieldState extends State<CustomTextField> {
//   String? _errorMessage;
//   TextEditingController _textController =
//       TextEditingController(); // Add this line
//
//   late FocusNode _focusNode;
//   @override
//   void dispose() {
//     _textController.dispose(); // Dispose the controller when not needed anymore
//     super.dispose();
//     _focusNode.dispose();
//   }
//
//   @override
//   void initState() {
//     super.initState();
//     _textController = widget.controller ?? TextEditingController();
//     _focusNode = FocusNode();
//   }
//
//   KeyboardActionsConfig _buildConfig(BuildContext context) {
//     return KeyboardActionsConfig(
//       actions: [
//         KeyboardActionsItem(
//           focusNode: _focusNode,
//           toolbarButtons: [
//             (node) {
//               return GestureDetector(
//                 onTap: () {
//                   if (widget.onChanged2 != null) {
//                     widget.onChanged2!(_textController.text);
//                   }
//                   node.unfocus(); // Dismiss the keyboard
//                 },
//                 child: Padding(
//                   padding: EdgeInsets.all(14.0),
//                   child: Text(
//                     "Done",
//                     style: TextStyle(
//                         color: Colors.blue, fontWeight: FontWeight.bold),
//                   ),
//                 ),
//               );
//             },
//           ],
//         ),
//       ],
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final shouldUseKeyboardActions =
//         widget.keyboardType == TextInputType.number;
//     Widget textfield = Stack(
//       clipBehavior: Clip.none,
//       children: <Widget>[
//         FormField<String>(
//           validator: (value) {
//             if (widget.controller!.text.isEmpty) {
//               setState(() {
//                 _errorMessage = 'Please ${widget.hintText}';
//               });
//               return '';
//             } else if (widget.keyboardType == TextInputType.number) {
//               String formattedPhoneNumber = widget.controller!.text
//                   .replaceAll(RegExp(r'\D'), '');
//
//               // Removed the empty check
//               if (formattedPhoneNumber.length != 10) {
//                 setState(() {
//                   _errorMessage = "Phone number must be 10 digits";
//                 });
//                 return '';
//               }
//             }else if (widget.pass != null) {
//               String? validationMessage = ValidatePassword(widget.controller!.text);
//               if (validationMessage != null) {
//                 setState(() {
//                   _errorMessage =
//                       validationMessage;
//                 });
//                 return '';
//               }
//             }
//             else if (widget.email != null) {
//               if (!EmailValidator.validate(widget.controller!.text)) {
//                 setState(() {
//                   _errorMessage = "Email is not valid";
//                 });
//                 return '';
//               }
//             }
//             setState(() {
//               _errorMessage = null;
//             });
//             return null;
//           },
//           builder: (FormFieldState<String> state) {
//             return Column(
//               children: <Widget>[
//                 Container(
//                   height: 50,
//                   padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 0),
//                   decoration: BoxDecoration(
//                     color: Colors.white,
//                     borderRadius: BorderRadius.circular(8.0),
//                     //border: Border.all(color: blueColor),
//                     boxShadow: [
//                       BoxShadow(
//                         color: Colors.black.withOpacity(0.2),
//                         offset: Offset(4, 4),
//                         blurRadius: 3,
//                       ),
//                     ],
//                   ),
//                   child: TextFormField(
//                     onTap: widget.onTap,
//                     obscureText: widget.obscureText,
//                     readOnly: widget.readOnnly,
//                     keyboardType: widget.keyboardType,
//                     focusNode: _focusNode,
//                     validator: (value) {
//                       if (value == null || value.isEmpty) {
//                         state.validate();
//                       }
//                       return null;
//                     },
//                     controller: widget.controller,
//                     inputFormatters:widget.inputFormatters ?? [],
//                     decoration: InputDecoration(
//                       suffixIcon: widget.suffixIcon,
//                       hintStyle:
//                           TextStyle(fontSize: 13, color: Color(0xFFb0b6c3)),
//                       border: InputBorder.none,
//                       hintText: widget.hintText,
//                     ),
//                   ),
//                 ),
//                 if (state.hasError)
//                   SizedBox(height: 24), // Reserve space for error message
//               ],
//             );
//           },
//         ),
//         if (_errorMessage != null)
//           Positioned(
//             top: 60,
//             left: 8,
//             child: Text(
//               _errorMessage!,
//               style: TextStyle(
//                 color: Colors.red,
//                 fontSize: 12.0,
//               ),
//             ),
//           ),
//       ],
//     );
//     return shouldUseKeyboardActions
//         ? SizedBox(
//             height: 60,
//             width: MediaQuery.of(context).size.width * .98,
//             child: KeyboardActions(
//               config: _buildConfig(context),
//               child: textfield,
//             ),
//           )
//         : textfield;
//   }
// }

class edit_vendor extends StatefulWidget {
  String? vender_id;
  edit_vendor({super.key, this.vender_id});

  @override
  State<edit_vendor> createState() => _edit_vendorState();
}

class _edit_vendorState extends State<edit_vendor> {
  String? initialVendorName;
  String? initialPhoneNumber;
  String? initialEmail;
  String? initialPassword;
  String? initialTradeType;
  bool? initialIs1099;
  String? selectedTradeType;
  final List<String> _tradeTypes = ['General', 'Drywall', 'Electrical', 'HVAC', 'Landscaping', 'Painting', 'Plumbing', 'Roofing'];
  bool isloading = false;
  Future<void> _fetchVendor() async {
    setState(() {
      isloading = true;
    });

    try {
      final vendor = await vendorRepository.getVendor(widget.vender_id!);
      initialVendorName = vendor.vendorName;
      initialPhoneNumber = vendor.vendorPhoneNumber;
      initialEmail = vendor.vendorEmail;
      initialPassword = vendor.vendorPassword;

      // Null-safe assignment: a vendor with no password (setup-email flow)
      // previously threw here on `!`, aborting before Trade Type was set and
      // showing "Failed to fetch vendor data". Match web (null-safe pre-fill).
      firstName.text = vendor.vendorName ?? '';
      phoneNumber.text = (vendor.vendorPhoneNumber ?? '').isNotEmpty
          ? formatPhoneNumberedit(vendor.vendorPhoneNumber!)
          : '';
      email.text = vendor.vendorEmail ?? '';
      passWord.text = vendor.vendorPassword ?? '';
      conpassWord.text =
          vendor.vendorPassword ?? ''; // Pre-fill confirm password field
      initialTradeType = vendor.trade;
      initialIs1099 = vendor.is1099 ?? false;
      is1099 = vendor.is1099 ?? false;
      // Only pre-select when the saved value maps to a dropdown option,
      // otherwise DropdownButton asserts ("exactly one item with value").
      if (vendor.trade != null && vendor.trade!.trim().isNotEmpty) {
        final String t = (vendor.trade ?? '').toLowerCase().trim();
        if (_tradeTypes.any((type) => type.toLowerCase() == t)) {
          selectedTradeType = t;
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to fetch vendor data')));
    } finally {
      setState(() {
        isloading = false;
      });
    }
  }

  final TextEditingController firstName = TextEditingController();

  final TextEditingController phoneNumber = TextEditingController();
  bool obsecure = true;
  bool conobsecure = true;

  final TextEditingController email = TextEditingController();

  GlobalKey<FormState> _formkey = GlobalKey<FormState>();
  final TextEditingController passWord = TextEditingController();
  final TextEditingController conpassWord = TextEditingController();
  bool isLoading = false;
  bool formValid = false;
  bool tradeError = false;

  /// Web parity: the 1099 reporting checkbox. Prefilled from the fetched
  /// vendor in _fetchVendor so an edit never silently clears a flag that was
  /// set on web (the update payload always includes this field).
  bool is1099 = false;

  /// Web parity: "Tax ID (EIN/SSN)". Staff render the SAME web component as
  /// admins (AddVendor.jsx), so the field is present here too. No masked
  /// current-value hint: reading the stored tax id back is admin-only (the
  /// server answers 403), which is exactly what web shows Staff.
  final TextEditingController taxId = TextEditingController();
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _fetchVendor();
  }

  final VendorRepository vendorRepository =
      VendorRepository(baseUrl: 'https://yourapiurl.com');

  /// Phone numbers are shown formatted but stored as digits, so the two forms
  /// can only be compared once the formatting is stripped.
  String _digitsOnly(String? value) =>
      (value ?? '').replaceAll(RegExp(r'\D'), '');

  @override
  void dispose() {
    firstName.dispose();
    phoneNumber.dispose();
    email.dispose();
    passWord.dispose();
    conpassWord.dispose();
    taxId.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget_302_Staff.App_Bar(context: context),
      backgroundColor: Colors.white,
      drawer: CustomDrawerStaff(
        currentpage: "Vendors",
        dropdown: true,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth > 500) {
            return Form(
              key: _formkey,
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      titleBar(
                        width: MediaQuery.of(context).size.width * .95,
                        title: 'Edit Vendor',
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Container(
                          padding: const EdgeInsets.all(16.0),
                          width: double.infinity,
                          decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10.0),
                              border: Border.all(
                                color: const Color(0xFFE0E0E0),
                              )),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Vendor Name *',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: blueColor)),
                              const SizedBox(
                                height: 10,
                              ),
                              CustomTextField(
                                keyboardType: TextInputType.text,
                                hintText: 'Enter vendor name',
                                controller: firstName,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'please enter the vendor name';
                                  }
                                  return null;
                                },
                              ),
                              /* SizedBox(
                          height: 10,
                        ),
                        Text('Last Name *',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: blueColor)),
                        SizedBox(
                          height: 10,
                        ),
                        CustomTextField(
                          keyboardType: TextInputType.text,
                          hintText: 'Enter last name',
                          controller: lastName,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'please enter the last name';
                            }
                            return null;
                          },
                        ),*/
                              const SizedBox(
                                height: 10,
                              ),
                              Text('Phone Number *',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: blueColor)),
                              const SizedBox(
                                height: 10,
                              ),
                              CustomTextField(
                                keyboardType: TextInputType.number,
                                // keyboardType: TextInputType.numberWithOptions(
                                //     signed: true, decimal: true),
                                hintText: 'Enter phone number',
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(10),
                                  PhoneNumberFormatter(),
                                ],
                                controller: phoneNumber,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'please enter the phone number';
                                  }
                                  return null;
                                },
                                phone: true,
                              ),
                              /*  SizedBox(
                          height: 10,
                        ),
                        Text('Work Number',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: blueColor)),
                        SizedBox(
                          height: 10,
                        ),
                        CustomTextField(
                          keyboardType: TextInputType.number,
                          hintText: 'Enter work number',
                          controller: workNumber,
                        ),*/
                              const SizedBox(
                                height: 10,
                              ),
                              Text('Email *',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: blueColor)),
                              const SizedBox(
                                height: 10,
                              ),
                              CustomTextField(
                                keyboardType: TextInputType.emailAddress,
                                hintText: 'Enter email',
                                controller: email,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'please enter email';
                                  }
                                  return null;
                                },
                                email: true,
                              ),
                              /* SizedBox(
                          height: 10,
                        ),
                        Text('Alternative Email',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: blueColor)),
                        SizedBox(
                          height: 10,
                        ),
                        CustomTextField(
                          keyboardType: TextInputType.emailAddress,
                          hintText: 'Enter alternative email',
                          controller: alterEmail,
                        ),*/
                              const SizedBox(
                                height: 10,
                              ),
                              Text('Trade Type *',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: blueColor)),
                              const SizedBox(
                                height: 10,
                              ),
                              Container(
                                height: 50,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8.0),
                                  border: Border.all(color: const Color(0xFFE0E0E0), width: 1.0),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: selectedTradeType,
                                    hint: const Text('Select trade type', style: TextStyle(fontSize: 13, color: Color(0xFFb0b6c3))),
                                    isExpanded: true,
                                    menuMaxHeight: 250,
                                    items: _tradeTypes.map((type) {
                                      return DropdownMenuItem<String>(
                                        value: type.toLowerCase(),
                                        child: Text(type, style: const TextStyle(fontSize: 14)),
                                      );
                                    }).toList(),
                                    onChanged: (value) {
                                      setState(() {
                                        selectedTradeType = value;
                                        tradeError = false;
                                      });
                                    },
                                  ),
                                ),
                              ),
                              if (tradeError)
                                const Padding(
                                  padding: EdgeInsets.only(top: 6.0, left: 4.0),
                                  child: Text('Please select trade type.',
                                      style: TextStyle(color: Colors.red, fontSize: 12)),
                                ),
                              const SizedBox(
                                height: 10,
                              ),
                              Text('Password',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: blueColor)),
                              const SizedBox(
                                height: 10,
                              ),
                              Row(
                                children: [
                                  Expanded(
                                    child: CustomTextField(
                                      keyboardType: TextInputType.text,
                                      obscureText: obsecure,
                                      hintText: 'Enter password',
                                      controller: passWord,
                                      optional: true,
                                      validator: (value) {
                                        if (value == null) {
                                          return 'please enter password';
                                        }
                                        return null;
                                      },
                                      suffixIcon: GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            obsecure = !obsecure;
                                          });
                                        },
                                        child: Icon(
                                          !obsecure
                                              ? CupertinoIcons.eye_slash_fill
                                              : CupertinoIcons.eye_fill,
                                          color: Colors.grey,
                                        ),
                                      ),
                                      pass: true,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(
                                height: 10,
                              ),
                              Text('Confirm Password',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: blueColor)),
                              const SizedBox(
                                height: 10,
                              ),
                              Row(
                                children: [
                                  Expanded(
                                    child: CustomTextField(
                                      keyboardType: TextInputType.text,
                                      obscureText: conobsecure,
                                      hintText: 'Re-enter password',
                                      controller: conpassWord,
                                      optional: true,
                                      validator: (value) {
                                        if (value == null) {
                                          return 'please enter confirm password';
                                        }
                                        return null;
                                      },
                                      pass: true,
                                      passwordController: passWord,
                                      suffixIcon: GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            conobsecure = !conobsecure;
                                          });
                                        },
                                        child: Icon(
                                          !conobsecure
                                              ? CupertinoIcons.eye_slash_fill
                                              : CupertinoIcons.eye_fill,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(
                                height: 16,
                              ),
                              // Web parity: the 1099 flag sits after Confirm Password,
                              // as the last field on the form.
                              InkWell(
                                onTap: () => setState(() {
                                  is1099 = !is1099;
                                  if (!is1099) taxId.clear();
                                }),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      height: 24,
                                      width: 24,
                                      child: Checkbox(
                                        value: is1099,
                                        onChanged: (v) => setState(() {
                                          is1099 = v ?? false;
                                          if (!is1099) taxId.clear();
                                        }),
                                        activeColor: blueColor,
                                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    const Flexible(
                                      child: Text('This vendor receives 1099 forms',
                                          style: TextStyle(fontSize: 13, color: Colors.black87)),
                                    ),
                                  ],
                                ),
                              ),
                              // Web parity: Tax ID shows only while the 1099 box is ticked.
                              if (is1099) ...[
                                const SizedBox(height: 14),
                                Text('Tax ID (EIN/SSN)',
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: blueColor)),
                                const SizedBox(height: 10),
                                CustomTextField(
                                  keyboardType: TextInputType.text,
                                  hintText: 'Enter Tax ID (e.g., XX-XXXXXXX)',
                                  controller: taxId,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(RegExp(r'[0-9-]')),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 18),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: SizedBox(
                                      height: 50,
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: blueColor,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8.0),
                                          ),
                                        ),
                                        onPressed: isLoading ? null : () async {
                                          // Validate the form fields AND the trade
                                          // dropdown together, so the trade error
                                          // shows even when a Form field (e.g. an
                                          // empty password) is also invalid.
                                          final bool isValid = _formkey.currentState!.validate();
                                          final bool tradeMissing = selectedTradeType == null || selectedTradeType!.isEmpty;
                                          setState(() { tradeError = tradeMissing; });
                                          if (!isValid || tradeMissing) return;

                                          // Same fields and the same trimmed comparison as
                                          // web (AddVendor.jsx checkForChanges). The one
                                          // difference is forced: web never reformats the
                                          // loaded phone, this form does — the field is
                                          // filled as "(555) 123-4567" while
                                          // initialPhoneNumber holds raw digits — so a
                                          // trimmed compare read every untouched form as
                                          // changed and fired a real PUT. Comparing digits
                                          // restores web's behaviour.
                                          bool hasChanges = firstName.text.trim() != (initialVendorName ?? '').trim() ||
                                              _digitsOnly(phoneNumber.text) != _digitsOnly(initialPhoneNumber) ||
                                              email.text.trim() != (initialEmail ?? '').trim() ||
                                              passWord.text.trim() != (initialPassword ?? '').trim() ||
                                              (selectedTradeType ?? '').trim() !=
                                                  (initialTradeType ?? '').trim() ||
                                                  is1099 != (initialIs1099 ?? false) ||
                                                  (is1099 && taxId.text.trim().isNotEmpty);

                                          if (!hasChanges) { Navigator.of(context).pop(false); return; }

                                          setState(() { isLoading = true; });
                                          try {
                                            SharedPreferences prefs = await SharedPreferences.getInstance();
                                            String adminId = prefs.getString("adminId")!;

                                            // Web trims every string in the payload
                                            // (AddVendor.jsx handleSubmit), and the
                                            // narrow layout below already did — this
                                            // one didn't, so the same edit saved with
                                            // stray spaces depending on screen width.
                                            final vendor = Vendor(
                                              adminId: adminId,
                                              vendorName: firstName.text.trim(),
                                              vendorPhoneNumber: phoneNumber.text.trim(),
                                              vendorEmail: email.text.trim(),
                                              vendorPassword: passWord.text.trim(),
                                              trade: selectedTradeType,
                                              is1099: is1099,
                                              taxId: is1099 ? taxId.text.trim() : null,
                                            );
                                            // Web parity: surface the server's own reason
                                            // (duplicate phone/email) instead of a generic failure.
                                            final saveError = await vendorRepository.update_vendor(vendor, widget.vender_id!);
                                            if (!mounted) return;
                                            if (saveError == null) {
                                              Fluttertoast.showToast(msg: "Vendor Edited successfully");
                                              Navigator.of(context).pop(true);
                                            } else {
                                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(saveError)));
                                            }
                                          } catch (e) {
                                            // Suppressed in release by the zone-level print filter in main().
                                            print('[vendor save] exception: $e');
                                            if (mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to edit vendor')));
                                            }
                                          } finally {
                                            if (mounted) setState(() { isLoading = false; });
                                          }
                                        },
                                        child: isLoading
                                            ? const Center(child: SpinKitFadingCircle(color: Colors.white, size: 55.0))
                                            : const Text('Edit Vendor', style: TextStyle(color: Color(0xFFf7f8f9))),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: SizedBox(
                                      height: 50,
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFFffffff),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8.0),
                                          ),
                                        ),
                                        onPressed: () { Navigator.pop(context); },
                                        child: const Text('Cancel', style: TextStyle(color: Color(0xFF748097))),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          } else {
            return Form(
              key: _formkey,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                      child: titleBar(
                        width: MediaQuery.of(context).size.width - 24,
                        title: 'Edit Vendor',
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Container(
                        padding: const EdgeInsets.all(16.0),
                        width: double.infinity,
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10.0),
                            border: Border.all(
                              color: const Color(0xFFE0E0E0),
                            )),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Vendor Name *',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: blueColor)),
                            const SizedBox(height: 10),
                            CustomTextField(
                              keyboardType: TextInputType.text,
                              hintText: 'Enter vendor name',
                              controller: firstName,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'please enter the vendor name';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 10),
                            Text('Phone Number *',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: blueColor)),
                            const SizedBox(height: 10),
                            CustomTextField(
                              keyboardType: TextInputType.number,
                              hintText: 'Enter phone number',
                              controller: phoneNumber,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'please enter the phone number';
                                }
                                return null;
                              },
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(10),
                                PhoneNumberFormatter(),
                              ],
                              phone: true,
                            ),
                            const SizedBox(height: 10),
                            Text('Email *',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: blueColor)),
                            const SizedBox(height: 10),
                            CustomTextField(
                              keyboardType: TextInputType.emailAddress,
                              hintText: 'Enter email',
                              controller: email,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'please enter email';
                                }
                                return null;
                              },
                              email: true,
                            ),
                            const SizedBox(height: 10),
                            Text('Trade Type *',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: blueColor)),
                            const SizedBox(height: 10),
                            Container(
                              height: 50,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8.0),
                                border: Border.all(color: const Color(0xFFE0E0E0), width: 1.0),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 12.0),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: selectedTradeType,
                                  hint: const Text('Select trade type',
                                      style: TextStyle(fontSize: 13, color: Color(0xFFb0b6c3))),
                                  isExpanded: true,
                                  menuMaxHeight: 250,
                                  items: _tradeTypes.map((type) {
                                    return DropdownMenuItem<String>(
                                      value: type.toLowerCase(),
                                      child: Text(type, style: const TextStyle(fontSize: 14)),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      selectedTradeType = value;
                                      tradeError = false;
                                    });
                                  },
                                ),
                              ),
                            ),
                            if (tradeError)
                              const Padding(
                                padding: EdgeInsets.only(top: 6.0, left: 4.0),
                                child: Text('Please select trade type.',
                                    style: TextStyle(color: Colors.red, fontSize: 12)),
                              ),
                            const SizedBox(height: 10),
                            Text('Password',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: blueColor)),
                            const SizedBox(height: 10),
                            CustomTextField(
                              keyboardType: TextInputType.text,
                              obscureText: obsecure,
                              hintText: 'Enter password',
                              controller: passWord,
                              optional: true,
                              validator: (value) {
                                if (value == null) {
                                  return 'please enter password';
                                }
                                return null;
                              },
                              suffixIcon: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    obsecure = !obsecure;
                                  });
                                },
                                child: Icon(
                                  !obsecure
                                      ? CupertinoIcons.eye_slash_fill
                                      : CupertinoIcons.eye_fill,
                                  color: Colors.grey,
                                ),
                              ),
                              pass: true,
                            ),
                            const SizedBox(height: 10),
                            Text('Confirm Password',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: blueColor)),
                            const SizedBox(height: 10),
                            CustomTextField(
                              keyboardType: TextInputType.text,
                              obscureText: conobsecure,
                              hintText: 'Re-enter password',
                              controller: conpassWord,
                              optional: true,
                              validator: (value) {
                                if (value == null) {
                                  return 'please enter confirm password';
                                }
                                return null;
                              },
                              pass: true,
                              passwordController: passWord,
                              suffixIcon: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    conobsecure = !conobsecure;
                                  });
                                },
                                child: Icon(
                                  !conobsecure
                                      ? CupertinoIcons.eye_slash_fill
                                      : CupertinoIcons.eye_fill,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                            const SizedBox(height: 35),
                            // Web parity: the 1099 flag sits after Confirm Password,
                            // as the last field on the form.
                            InkWell(
                              onTap: () => setState(() {
                                  is1099 = !is1099;
                                  if (!is1099) taxId.clear();
                                }),
                              child: Row(
                                children: [
                                  SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: Checkbox(
                                      value: is1099,
                                      onChanged: (v) => setState(() {
                                          is1099 = v ?? false;
                                          if (!is1099) taxId.clear();
                                        }),
                                      activeColor: blueColor,
                                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  const Flexible(
                                    child: Text('This vendor receives 1099 forms',
                                        style: TextStyle(fontSize: 13, color: Colors.black87)),
                                  ),
                                ],
                              ),
                            ),
                            // Web parity: Tax ID shows only while the 1099 box is ticked.
                            if (is1099) ...[
                              const SizedBox(height: 14),
                              Text('Tax ID (EIN/SSN)',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: blueColor)),
                              const SizedBox(height: 10),
                              CustomTextField(
                                keyboardType: TextInputType.text,
                                hintText: 'Enter Tax ID (e.g., XX-XXXXXXX)',
                                controller: taxId,
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(RegExp(r'[0-9-]')),
                                ],
                              ),
                            ],
                            const SizedBox(height: 18),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: SizedBox(
                                    height: 50,
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: blueColor,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8.0),
                                        ),
                                      ),
                                      onPressed: isLoading ? null : () async {
                                        // Validate the form fields AND the trade
                                        // dropdown together, so the trade error
                                        // shows even when a Form field (e.g. an
                                        // empty password) is also invalid.
                                        final bool isValid = _formkey.currentState!.validate();
                                        final bool tradeMissing = selectedTradeType == null || selectedTradeType!.isEmpty;
                                        setState(() { tradeError = tradeMissing; });
                                        if (!isValid || tradeMissing) return;

                                        // Same normalisation as the wide layout above:
                                        // the formatted phone field never matched the
                                        // raw stored digits, so this guard was always
                                        // true and every Update fired a real PUT.
                                        bool hasChanges = firstName.text.trim() != (initialVendorName ?? '').trim() ||
                                            _digitsOnly(phoneNumber.text) != _digitsOnly(initialPhoneNumber) ||
                                            email.text.trim() != (initialEmail ?? '').trim() ||
                                            passWord.text.trim() != (initialPassword ?? '').trim() ||
                                            (selectedTradeType ?? '').trim() !=
                                                (initialTradeType ?? '').trim() ||
                                                is1099 != (initialIs1099 ?? false) ||
                                                  (is1099 && taxId.text.trim().isNotEmpty);

                                        if (!hasChanges) { Navigator.of(context).pop(false); return; }

                                        setState(() { isLoading = true; });
                                        try {
                                          SharedPreferences prefs = await SharedPreferences.getInstance();
                                          String adminId = prefs.getString("adminId")!;

                                          final vendor = Vendor(
                                            adminId: adminId,
                                            vendorName: firstName.text.trim(),
                                            vendorPhoneNumber: phoneNumber.text.trim(),
                                            vendorEmail: email.text.trim(),
                                            vendorPassword: passWord.text.trim(),
                                            trade: selectedTradeType,
                                            is1099: is1099,
                                            taxId: is1099 ? taxId.text.trim() : null,
                                          );
                                          // Web parity: surface the server's own reason
                                          // (duplicate phone/email) instead of a generic failure.
                                          final saveError = await vendorRepository
                                              .update_vendor(vendor, widget.vender_id!);
                                          if (!mounted) return;
                                          if (saveError == null) {
                                            Fluttertoast.showToast(msg: "Vendor Edited successfully");
                                            Navigator.of(context).pop(true);
                                          } else {
                                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(saveError)));
                                          }
                                        } catch (e) {
                                          // Suppressed in release by the zone-level print filter in main().
                                          print('[vendor save] exception: $e');
                                          if (mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to edit vendor')));
                                          }
                                        } finally {
                                          if (mounted) setState(() { isLoading = false; });
                                        }
                                      },
                                      child: isLoading
                                          ? const Center(child: SpinKitFadingCircle(color: Colors.white, size: 55.0))
                                          : const Text('Edit Vendor', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFf7f8f9))),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: SizedBox(
                                    height: 50,
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFFffffff),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8.0),
                                        ),
                                      ),
                                      onPressed: () { Navigator.pop(context); },
                                      child: const Text('Cancel', style: TextStyle(color: Color(0xFF748097))),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
        },
      ),
    );
  }
}

                              // const SizedBox(
                                // height: 10,
                              // ),
                              // Text('Password *',
                                  // style: TextStyle(
                                      // fontSize: 13,
                                      // fontWeight: FontWeight.bold,
                                      // color: blueColor)),
                              // const SizedBox(
                                // height: 10,
                              // ),
                              // CustomTextField(
                                // keyboardType: TextInputType.text,
                                // obscureText: obsecure,
                                // hintText: 'Enter password',
                                // controller: passWord,
                                // validator: (value) {
                                  // if (value == null) {
                                    // return 'please enter password';
                                  // }
                                  // return null;
                                // },
                                // pass: true,
                                // suffixIcon: GestureDetector(
                                  // onTap: () {
                                    // setState(() {
                                      // obsecure = !obsecure;
                                    // });
                                  // },
                                  // child: Icon(
                                    // !obsecure
                                        // ? CupertinoIcons.eye_slash_fill
                                        // : CupertinoIcons.eye_fill,
                                    // color: Colors.grey,
                                  // ),
                                // ),
                              // ),
                              // const SizedBox(
                                // height: 10,
                              // ),
                              // //confirm password
                              // Text('Confirm Password *',
                                  // style: TextStyle(
                                      // fontSize: 13,
                                      // fontWeight: FontWeight.bold,
                                      // color: blueColor)),
                              // const SizedBox(
                                // height: 10,
                              // ),
                              // CustomTextField(
                                // keyboardType: TextInputType.text,
                                // obscureText: conobsecure,
                                // hintText: 'Enter confirm password',
                                // controller: conpassWord,
                                // validator: (value) {
                                  // if (value == null) {
                                    // return 'please enter confirm password';
                                  // }
                                  // return null;
                                // },
                                // pass: true,
                                // passwordController: passWord,
                                // suffixIcon: GestureDetector(
                                  // onTap: () {
                                    // setState(() {
                                      // conobsecure = !conobsecure;
                                    // });
                                  // },
                                  // child: Icon(
                                    // !conobsecure
                                        // ? CupertinoIcons.eye_slash_fill
                                        // : CupertinoIcons.eye_fill,
                                    // color: Colors.grey,
                                  // ),
                                // ),
                              // ),
                              // const SizedBox(
                                // height: 16,
                              // ),
                              // Row(
                                // mainAxisAlignment: MainAxisAlignment.start,
                                // children: [
                                  // Expanded(
                                    // child: SizedBox(
                                      // height: 50,
                                      // child: ElevatedButton(
                                        // style: ElevatedButton.styleFrom(
                                          // backgroundColor: blueColor,
                                          // shape: RoundedRectangleBorder(
                                            // borderRadius: BorderRadius.circular(8.0),
                                          // ),
                                        // ),
                                        // onPressed: () async {
                                          // bool isFormValid = true;
                                          // if (firstName.text.isEmpty) setState(() { isFormValid = false; });
                                          // if (phoneNumber.text.isEmpty) setState(() { isFormValid = false; });
                                          // if (email.text.isEmpty) setState(() { isFormValid = false; });

                                          // bool hasChanges = firstName.text != initialVendorName ||
                                              // phoneNumber.text != initialPhoneNumber ||
                                              // email.text != initialEmail ||
                                              // passWord.text != initialPassword ||
                                              // selectedTradeType != initialTradeType;

                                          // if (!hasChanges) { Navigator.of(context).pop(false); return; }
                                          // if (!isFormValid) return;

                                          // setState(() { isLoading = true; });
                                          // SharedPreferences prefs = await SharedPreferences.getInstance();
                                          // String adminId = prefs.getString("adminId")!;

                                          // final vendor = Vendor(
                                            // adminId: adminId,
                                            // vendorName: firstName.text,
                                            // vendorPhoneNumber: phoneNumber.text,
                                            // vendorEmail: email.text,
                                            // vendorPassword: passWord.text,
                                            // trade: selectedTradeType,
                                          // );
                                          // final success = await vendorRepository.update_vendor(vendor, widget.vender_id!);
                                          // setState(() { isLoading = false; });
                                          // if (success) {
                                            // Fluttertoast.showToast(msg: "Vendor Edited successfully");
                                            // Navigator.of(context).pop(true);
                                          // } else {
                                            // ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to edit vendor')));
                                          // }
                                        // },
                                        // child: isLoading
                                            // ? const Center(child: SpinKitFadingCircle(color: Colors.white, size: 55.0))
                                            // : const Text('Edit Vendor', style: TextStyle(color: Color(0xFFf7f8f9))),
                                      // ),
                                    // ),
                                  // ),
                                  // const SizedBox(width: 8),
                                  // Expanded(
                                    // child: SizedBox(
                                      // height: 50,
                                      // child: ElevatedButton(
                                        // style: ElevatedButton.styleFrom(
                                          // backgroundColor: const Color(0xFFffffff),
                                          // shape: RoundedRectangleBorder(
                                            // borderRadius: BorderRadius.circular(8.0),
                                          // ),
                                        // ),
                                        // onPressed: () { Navigator.pop(context); },
                                        // child: const Text('Cancel', style: TextStyle(color: Color(0xFF748097))),
                                      // ),
                                    // ),
                                  // ),
                                // ],
                              // ),
                            // ],
                          // ),
                        // ),
                      // ),
                    // ],
                  // ),
                // ),
              // ),
            // );
          // } else {
            // return Form(
              // key: _formkey,
              // child: SingleChildScrollView(
                // child: Column(
                  // crossAxisAlignment: CrossAxisAlignment.start,
                  // children: [

                    // // titleBar(
                    // //   width: MediaQuery.of(context).size.width * .94,
                    // //   title: 'Edit Vendor',
                    // // ),
                    // Padding(
                      // padding: const EdgeInsets.all(15.0),
                      // child: ClipRRect(
                        // borderRadius: BorderRadius.circular(5.0),
                        // child: Container(
                          // height: 50.0,
                          // padding: EdgeInsets.only(top: 9, left: 10),
                          // width: MediaQuery.of(context).size.width * .99,
                          // margin: const EdgeInsets.only(bottom: 6.0),
                          // //Same as `blurRadius` i guess
                          // decoration: BoxDecoration(
                            // borderRadius: BorderRadius.circular(8.0),
                            // color: blueColor,
                            // boxShadow: [
                              // BoxShadow(
                                // color: Colors.grey,
                                // offset: Offset(0.0, 1.0), //(x,y)
                                // blurRadius: 6.0,
                              // ),
                            // ],
                          // ),
                          // child: Text(
                            // "Edit Vendor",
                            // style: TextStyle(
                                // color: Colors.white,
                                // fontWeight: FontWeight.bold,
                                // fontSize:
                                    // MediaQuery.of(context).size.width < 500
                                        // ? 18
                                        // : 20),
                          // ),
                        // ),
                      // ),
                    // ),
                    // Padding(
                      // padding: const EdgeInsets.all(12.0),
                      // child: Container(
                        // padding: const EdgeInsets.all(16.0),
                        // width: double.infinity,
                        // decoration: BoxDecoration(
                            // borderRadius: BorderRadius.circular(10.0),
                            // border: Border.all(
                              // color: const Color(0xFFE0E0E0),
                            // )),
                        // child: Column(
                          // crossAxisAlignment: CrossAxisAlignment.start,
                          // children: [
                            // Text('Vendor Name *',
                                // style: TextStyle(
                                    // fontSize: 13,
                                    // fontWeight: FontWeight.bold,
                                    // color: blueColor)),
                            // const SizedBox(
                              // height: 10,
                            // ),
                            // CustomTextField(
                              // keyboardType: TextInputType.text,
                              // hintText: 'Enter vendor name',
                              // controller: firstName,
                              // validator: (value) {
                                // if (value == null || value.isEmpty) {
                                  // return 'please enter the vendor name';
                                // }
                                // return null;
                              // },
                            // ),
                            // /* SizedBox(
                        // height: 10,
                      // ),
                      // Text('Last Name *',
                          // style: TextStyle(
                              // fontSize: 13,
                              // fontWeight: FontWeight.bold,
                              // color: blueColor)),
                      // SizedBox(
                        // height: 10,
                      // ),
                      // CustomTextField(
                        // keyboardType: TextInputType.text,
                        // hintText: 'Enter last name',
                        // controller: lastName,
                        // validator: (value) {
                          // if (value == null || value.isEmpty) {
                            // return 'please enter the last name';
                          // }
                          // return null;
                        // },
                      // ),*/
                            // const SizedBox(
                              // height: 10,
                            // ),
                            // Text('Phone Number *',
                                // style: TextStyle(
                                    // fontSize: 13,
                                    // fontWeight: FontWeight.bold,
                                    // color: blueColor)),
                            // const SizedBox(
                              // height: 10,
                            // ),
                            // CustomTextField(
                              // keyboardType: TextInputType.number,
                              // // keyboardType: TextInputType.numberWithOptions(
                              // //     signed: true, decimal: true),
                              // hintText: 'Enter phone number',
                              // controller: phoneNumber,
                              // validator: (value) {
                                // if (value == null || value.isEmpty) {
                                  // return 'please enter the phone number';
                                // }
                                // return null;
                              // },
                              // inputFormatters: [
                                // FilteringTextInputFormatter.digitsOnly,
                                // LengthLimitingTextInputFormatter(10),
                                // PhoneNumberFormatter(),
                              // ],
                              // phone: true,
                            // ),
                            // /*  SizedBox(
                        // height: 10,
                      // ),
                      // Text('Work Number',
                          // style: TextStyle(
                              // fontSize: 13,
                              // fontWeight: FontWeight.bold,
                              // color: blueColor)),
                      // SizedBox(
                        // height: 10,
                      // ),
                      // CustomTextField(
                        // keyboardType: TextInputType.number,
                        // hintText: 'Enter work number',
                        // controller: workNumber,
                      // ),*/
                            // const SizedBox(
                              // height: 10,
                            // ),
                            // Text('Email *',
                                // style: TextStyle(
                                    // fontSize: 13,
                                    // fontWeight: FontWeight.bold,
                                    // color: blueColor)),
                            // const SizedBox(
                              // height: 10,
                            // ),
                            // CustomTextField(
                              // keyboardType: TextInputType.emailAddress,
                              // hintText: 'Enter email',
                              // controller: email,
                              // validator: (value) {
                                // if (value == null || value.isEmpty) {
                                  // return 'please enter email';
                                // }
                                // return null;
                              // },
                              // email: true,
                            // ),
                            // /* SizedBox(
                        // height: 10,
                      // ),
                      // Text('Alternative Email',
                          // style: TextStyle(
                              // fontSize: 13,
                              // fontWeight: FontWeight.bold,
                              // color: blueColor)),
                      // SizedBox(
                        // height: 10,
                      // ),
                      // CustomTextField(
                        // keyboardType: TextInputType.emailAddress,
                        // hintText: 'Enter alternative email',
                        // controller: alterEmail,
                      // ),*/
                            // const SizedBox(
                              // height: 10,
                            // ),
                            // Text('Trade Type *',
                                // style: TextStyle(
                                    // fontSize: 13,
                                    // fontWeight: FontWeight.bold,
                                    // color: blueColor)),
                            // const SizedBox(
                              // height: 10,
                            // ),
                            // Container(
                              // height: 50,
                              // decoration: BoxDecoration(
                                // color: Colors.white,
                                // borderRadius: BorderRadius.circular(8.0),
                                // border: Border.all(color: const Color(0xFFE0E0E0), width: 1.0),
                              // ),
                              // padding: const EdgeInsets.symmetric(horizontal: 12.0),
                              // child: DropdownButtonHideUnderline(
                                // child: DropdownButton<String>(
                                  // value: selectedTradeType,
                                  // hint: const Text('Select trade type', style: TextStyle(fontSize: 13, color: Color(0xFFb0b6c3))),
                                  // isExpanded: true,
                                    // menuMaxHeight: 250,
                                  // items: _tradeTypes.map((type) {
                                    // return DropdownMenuItem<String>(
                                      // value: type.toLowerCase(),
                                      // child: Text(type, style: const TextStyle(fontSize: 14)),
                                    // );
                                  // }).toList(),
                                  // onChanged: (value) {
                                    // setState(() {
                                      // selectedTradeType = value;
                                    // });
                                  // },
                                // ),
                              // ),
                            // ),
                            // const SizedBox(
                              // height: 10,
                            // ),
                            // Text('Password *',
                                // style: TextStyle(
                                    // fontSize: 13,
                                    // fontWeight: FontWeight.bold,
                                    // color: blueColor)),
                            // const SizedBox(
                              // height: 10,
                            // ),
                            // Row(
                              // children: [
                                // Expanded(
                                  // child: CustomTextField(
                                    // keyboardType: TextInputType.text,
                                    // obscureText: obsecure,
                                    // hintText: 'Enter password',
                                    // controller: passWord,
                                    // validator: (value) {
                                      // if (value == null) {
                                        // return 'please enter password';
                                      // }
                                      // return null;
                                    // },
                                    // pass: true,
                                    // suffixIcon: GestureDetector(
                                      // onTap: () {
                                        // setState(() {
                                          // obsecure = !obsecure;
                                        // });
                                      // },
                                      // child: Icon(
                                        // !obsecure
                                            // ? CupertinoIcons.eye_slash_fill
                                            // : CupertinoIcons.eye_fill,
                                        // color: Colors.grey,
                                      // ),
                                    // ),
                                  // ),
                                // ),
                                // // const SizedBox(
                                // //     width:
                                // //         10), // Add some space between the widgets
                                // // InkWell(
                                // //   onTap: () {
                                // //     setState(() {
                                // //       obsecure = !obsecure;
                                // //     });
                                // //   },
                                // //   child: Container(
                                // //     width: 38,
                                // //     height: 50,
                                // //     child: Center(
                                // //       child: FaIcon(
                                // //         !obsecure
                                // //             ? FontAwesomeIcons.eyeSlash
                                // //             : FontAwesomeIcons.eye,
                                // //         size: 20,
                                // //         color: Colors.black,
                                // //       ),
                                // //     ),
                                // //     decoration: BoxDecoration(
                                // //       color: Colors.white,
                                // //       boxShadow: [
                                // //         const BoxShadow(
                                // //           color: Colors.black26,
                                // //           offset: Offset(1.2, 1.2),
                                // //           blurRadius: 3.0,
                                // //           spreadRadius: 1.0,
                                // //         ),
                                // //       ],
                                // //       border: Border.all(
                                // //           width: 0, color: Colors.white),
                                // //       borderRadius: BorderRadius.circular(6.0),
                                // //     ),
                                // //   ),
                                // // ),
                              // ],
                            // ),
                            // const SizedBox(
                              // height: 10,
                            // ),
                            // //confirm password
                            // Text('Confirm Password *',
                                // style: TextStyle(
                                    // fontSize: 13,
                                    // fontWeight: FontWeight.bold,
                                    // color: blueColor)),
                            // const SizedBox(
                              // height: 10,
                            // ),
                            // Row(
                              // children: [
                                // Expanded(
                                  // child: CustomTextField(
                                    // keyboardType: TextInputType.text,
                                    // obscureText: conobsecure,
                                    // hintText: 'Enter confirm password',
                                    // controller: conpassWord,
                                    // validator: (value) {
                                      // if (value == null) {
                                        // return 'please enter confirm password';
                                      // }
                                      // return null;
                                    // },
                                    // pass: true,
                                    // suffixIcon: GestureDetector(
                                      // onTap: () {
                                        // setState(() {
                                          // conobsecure = !conobsecure;
                                        // });
                                      // },
                                      // child: Icon(
                                        // !conobsecure
                                            // ? CupertinoIcons.eye_slash_fill
                                            // : CupertinoIcons.eye_fill,
                                        // color: Colors.grey,
                                      // ),
                                    // ),
                                    // passwordController: passWord,
                                  // ),
                                // ),
                                // // const SizedBox(
                                // //     width:
                                // //         10), // Add some space between the widgets
                                // // InkWell(
                                // //   onTap: () {
                                // //     setState(() {
                                // //       conobsecure = !conobsecure;
                                // //     });
                                // //   },
                                // //   child: Container(
                                // //     width: 38,
                                // //     height: 50,
                                // //     child: Center(
                                // //       child: FaIcon(
                                // //         !conobsecure
                                // //             ? FontAwesomeIcons.eyeSlash
                                // //             : FontAwesomeIcons.eye,
                                // //         size: 20,
                                // //         color: Colors.black,
                                // //       ),
                                // //     ),
                                // //     decoration: BoxDecoration(
                                // //       color: Colors.white,
                                // //       boxShadow: [
                                // //         const BoxShadow(
                                // //           color: Colors.black26,
                                // //           offset: Offset(1.2, 1.2),
                                // //           blurRadius: 3.0,
                                // //           spreadRadius: 1.0,
                                // //         ),
                                // //       ],
                                // //       border: Border.all(
                                // //           width: 0, color: Colors.white),
                                // //       borderRadius: BorderRadius.circular(6.0),
                                // //     ),
                                // //   ),
                                // // ),
                              // ],
                            // ),
                            // const SizedBox(
                              // height: 35,
                            // ),
                            // Row(
                              // mainAxisAlignment: MainAxisAlignment.start,
                              // children: [
                                // Expanded(
                                  // child: SizedBox(
                                    // height: 50,
                                    // child: ElevatedButton(
                                      // style: ElevatedButton.styleFrom(
                                        // backgroundColor: blueColor,
                                        // shape: RoundedRectangleBorder(
                                          // borderRadius: BorderRadius.circular(8.0),
                                        // ),
                                      // ),
                                    // onPressed: () async {
                                      // if (_formkey.currentState!.validate()) {
                                        // bool isFormValid = true;

                                        // // Validate each field and update the state accordingly
                                        // if (firstName.text.trim().isEmpty) {
                                          // setState(() {
                                            // isFormValid = false;
                                          // });
                                        // }

                                        // if (phoneNumber.text.trim().isEmpty) {
                                          // setState(() {
                                            // isFormValid = false;
                                          // });
                                        // }

                                        // if (email.text.trim().isEmpty) {
                                          // setState(() {
                                            // isFormValid = false;
                                          // });
                                        // }

                                        // // Check for changes
                                        // bool hasChanges = firstName.text !=
                                                // initialVendorName ||
                                            // phoneNumber.text !=
                                                // initialPhoneNumber ||
                                            // email.text != initialEmail ||
                                            // passWord.text != initialPassword ||
                                            // selectedTradeType != initialTradeType;

                                        // if (!hasChanges) {
                                          // print(
                                              // "No changes made, API call not necessary.");
                                          // Navigator.of(context).pop(
                                              // false); // Optionally navigate back
                                          // return;
                                        // }

                                        // if (!isFormValid) {
                                          // return; // Exit early if the form is not valid
                                        // }

                                        // // Proceed with API call
                                        // setState(() {
                                          // isLoading = true; // Start loading
                                        // });

                                        // SharedPreferences prefs =
                                            // await SharedPreferences
                                                // .getInstance();
                                        // String adminId =
                                            // prefs.getString("adminId")!;

                                        // final vendor = Vendor(
                                          // adminId: adminId,
                                          // vendorName: firstName.text.trim(),
                                          // vendorPhoneNumber:
                                              // phoneNumber.text.trim(),
                                          // vendorEmail: email.text.trim(),
                                          // vendorPassword: passWord.text.trim(),
                                          // trade: selectedTradeType,
                                        // );

                                        // final success = await vendorRepository
                                            // .update_vendor(
                                                // vendor, widget.vender_id!);
                                        // setState(() {
                                          // isLoading = false; // Stop loading
                                        // });

                                        // if (success) {
                                          // Fluttertoast.showToast(
                                              // msg:
                                                  // "Vendor Edited successfully");
                                          // Navigator.of(context).pop(true);
                                        // }
                                      // } else {
                                        // print("Failed to edit vendor");
                                        // // ScaffoldMessenger.of(context)
                                        // //     .showSnackBar(SnackBar(
                                        // //         content: Text(
                                        // //             'Failed to edit vendor')));
                                      // }
                                    // },
                                    // // onPressed: () async {
                                    // //   setState(() {
                                    // //     formValid = true;
                                    // //   });
                                    // //   if (_formkey.currentState!.validate()) {
                                    // //     setState(() {
                                    // //       formValid = false;
                                    // //     });
                                    // //
                                    // //     await addTenant();
                                    // //   }
                                    // // },
                                    // child: isLoading
                                        // ? const Center(child: SpinKitFadingCircle(color: Colors.white, size: 55.0))
                                        // : const Text('Update Vendor', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFf7f8f9))),
                                    // ),
                                  // ),
                                // ),
                                // const SizedBox(width: 8),
                                // Expanded(
                                  // child: SizedBox(
                                    // height: 50,
                                    // child: ElevatedButton(
                                      // style: ElevatedButton.styleFrom(
                                        // backgroundColor: const Color(0xFFffffff),
                                        // shape: RoundedRectangleBorder(
                                          // borderRadius: BorderRadius.circular(8.0),
                                        // ),
                                      // ),
                                      // onPressed: () { Navigator.pop(context); },
                                      // child: const Text('Cancel', style: TextStyle(color: Color(0xFF748097))),
                                    // ),
                                  // ),
                                // ),
                              // ],
                            // ),
                          // ],
                        // ),
                      // ),
                    // ),
                  // ],
                // ),
              // ),
            // );
          // }
        // },
      // ),
    // );
  // }

  // Future<void> addTenant() async {
    // setState(() {
      // isLoading = true;
    // });

    // SharedPreferences prefs = await SharedPreferences.getInstance();
    // String adminId = prefs.getString("adminId")!;

    // final vendor = Vendor(
      // adminId: adminId,
      // vendorName: firstName.text,
      // vendorPhoneNumber: phoneNumber.text,
      // vendorEmail: email.text,
      // vendorPassword: passWord.text,
    // );

    // final success =
        // await vendorRepository.update_vendor(vendor, widget.vender_id!);
    // if (success) {
      // //   ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Vendor added successfully')));
    // } else {
      // ScaffoldMessenger.of(context)
          // .showSnackBar(const SnackBar(content: Text('Failed to add vendor')));
    // }
    // setState(() {
      // isLoading = false;
    // });

    // if (success) {
      // print('Form is valid');
      // Fluttertoast.showToast(msg: "Vendor Edited successfully");
      // Navigator.of(context).pop(true);
    // } else {
      // print('Form is invalid');
    // }
  // }
// }

// // class CustomTextField extends StatefulWidget {
// //   final String hintText;
// //   final TextEditingController? controller;
// //   final TextInputType keyboardType;
// //   final String? Function(String?)? validator;
// //   final bool obscureText;
// //
// //   final Widget? suffixIcon;
// //   final IconData? prefixIcon;
// //   final void Function()? onSuffixIconPressed;
// //   final void Function()? onTap;
// //   final bool readOnnly;
// //
// //   CustomTextField({
// //     Key? key,
// //     this.controller,
// //     required this.hintText,
// //     this.obscureText = false,
// //     this.keyboardType = TextInputType.emailAddress,
// //     this.readOnnly = false,
// //     this.prefixIcon,
// //     this.suffixIcon,
// //     this.validator,
// //     this.onSuffixIconPressed,
// //     this.onTap, // Initialize onTap
// //   }) : super(key: key);
// //
// //   @override
// //   CustomTextFieldState createState() => CustomTextFieldState();
// // }
// //
// // class CustomTextFieldState extends State<CustomTextField> {
// //   String? _errorMessage;
// //   TextEditingController _textController =
// //       TextEditingController(); // Add this line
// //
// //   @override
// //   void dispose() {
// //     _textController.dispose(); // Dispose the controller when not needed anymore
// //     super.dispose();
// //   }
// //
// //   @override
// //   Widget build(BuildContext context) {
// //     return Stack(
// //       clipBehavior: Clip.none,
// //       children: <Widget>[
// //         FormField<String>(
// //           validator: (value) {
// //             if (widget.controller!.text.isEmpty) {
// //               setState(() {
// //                 _errorMessage = 'Please ${widget.hintText}';
// //               });
// //               return '';
// //             }
// //             setState(() {
// //               _errorMessage = null;
// //             });
// //             return null;
// //           },
// //           builder: (FormFieldState<String> state) {
// //             return Column(
// //               children: <Widget>[
// //                 Container(
// //                   height: 50,
// //                   padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 0),
// //                   decoration: BoxDecoration(
// //                     color: Colors.white,
// //                     borderRadius: BorderRadius.circular(8.0),
// //                     //border: Border.all(color: blueColor),
// //                     boxShadow: [
// //                       BoxShadow(
// //                         color: Colors.black.withOpacity(0.2),
// //                         offset: Offset(4, 4),
// //                         blurRadius: 3,
// //                       ),
// //                     ],
// //                   ),
// //                   child: TextFormField(
// //                     onTap: widget.onTap,
// //                     obscureText: widget.obscureText,
// //                     readOnly: widget.readOnnly,
// //                     keyboardType: widget.keyboardType,
// //                     validator: (value) {
// //                       if (value == null || value.isEmpty) {
// //                         state.validate();
// //                       }
// //                       return null;
// //                     },
// //                     controller: widget.controller,
// //                     decoration: InputDecoration(
// //                       suffixIcon: widget.suffixIcon,
// //                       hintStyle:
// //                           TextStyle(fontSize: 13, color: Color(0xFFb0b6c3)),
// //                       border: InputBorder.none,
// //                       hintText: widget.hintText,
// //                     ),
// //                   ),
// //                 ),
// //                 if (state.hasError)
// //                   SizedBox(height: 24), // Reserve space for error message
// //               ],
// //             );
// //           },
// //         ),
// //         if (_errorMessage != null)
// //           Positioned(
// //             top: 60,
// //             left: 8,
// //             child: Text(
// //               _errorMessage!,
// //               style: TextStyle(
// //                 color: Colors.red,
// //                 fontSize: 12.0,
// //               ),
// //             ),
// //           ),
// //       ],
// //     );
// //   }
// // }

// class CustomTextField extends StatefulWidget {
  // final String hintText;
  // final TextEditingController? controller;
  // final TextInputType keyboardType;
  // final String? Function(String?)? validator;
  // final bool obscureText;
  // final Function(String)? onChanged;
  // final Function(String)? onChanged2;
  // final Widget? suffixIcon;
  // final IconData? prefixIcon;
  // final void Function()? onSuffixIconPressed;
  // final void Function()? onTap;
  // final bool readOnnly;
  // final bool? email;
  // final bool? pass;
  // final bool? phone;
  // final List<TextInputFormatter>? inputFormatters;
  // final TextEditingController?
      // passwordController; // For confirm password field to compare with

  // CustomTextField({
    // Key? key,
    // this.controller,
    // required this.hintText,
    // this.obscureText = false,
    // this.keyboardType = TextInputType.emailAddress,
    // this.readOnnly = false,
    // this.prefixIcon,
    // this.suffixIcon,
    // this.validator,
    // this.onSuffixIconPressed,
    // this.onTap,
    // this.onChanged,
    // this.onChanged2,
    // this.email,
    // this.pass,
    // this.phone,
    // this.inputFormatters,
    // this.passwordController, // Used when this is a confirm password field
    // // Initialize onTap
  // }) : super(key: key);

  // @override
  // CustomTextFieldState createState() => CustomTextFieldState();
// }

// class CustomTextFieldState extends State<CustomTextField> {
  // String? _errorMessage;
  // TextEditingController _textController =
      // TextEditingController(); // Add this line

  // late FocusNode _focusNode;

  // @override
  // void initState() {
    // super.initState();
    // _textController = widget.controller ?? TextEditingController();
    // _focusNode = FocusNode();

    // // Listen to changes for real-time validation
    // if (widget.passwordController != null && widget.controller != null) {
      // widget.passwordController!.addListener(_validateConfirmPassword);
      // widget.controller!.addListener(_validateConfirmPassword);
    // }
  // }

  // void _validateConfirmPassword() {
    // if (widget.passwordController != null && widget.controller != null) {
      // setState(() {
        // // Trigger validation when either field changes
      // });
    // }
  // }

  // @override
  // void dispose() {
    // if (widget.passwordController != null) {
      // widget.passwordController!.removeListener(_validateConfirmPassword);
    // }
    // if (widget.controller != null) {
      // widget.controller!.removeListener(_validateConfirmPassword);
    // }
    // _textController.dispose(); // Dispose the controller when not needed anymore
    // _focusNode.dispose();
    // super.dispose();
  // }

  // KeyboardActionsConfig _buildConfig(BuildContext context) {
    // return KeyboardActionsConfig(
      // actions: [
        // KeyboardActionsItem(
          // focusNode: _focusNode,
          // toolbarButtons: [
            // (node) {
              // return GestureDetector(
                // onTap: () {
                  // if (widget.onChanged2 != null) {
                    // widget.onChanged2!(_textController.text);
                  // }
                  // node.unfocus(); // Dismiss the keyboard
                // },
                // child: const Padding(
                  // padding: EdgeInsets.all(14.0),
                  // child: Text(
                    // "Done",
                    // style: TextStyle(
                        // color: Colors.blue, fontWeight: FontWeight.bold),
                  // ),
                // ),
              // );
            // },
          // ],
        // ),
      // ],
    // );
  // }

  // @override
  // Widget build(BuildContext context) {
    // final shouldUseKeyboardActions =
        // widget.keyboardType == TextInputType.number;
    // Widget textfield = Stack(
      // clipBehavior: Clip.none,
      // children: <Widget>[
        // FormField<String>(
          // validator: (value) {
            // if (widget.controller!.text.trim().isEmpty) {
              // setState(() {
                // String hintTextLower = widget.hintText.isEmpty
                    // ? widget.hintText
                    // : widget.hintText[0].toLowerCase() +
                        // widget.hintText.substring(1);
                // _errorMessage = 'Please $hintTextLower';
              // });
              // return '';
            // } else if (widget.phone != null) {
              // String formattedPhoneNumber =
                  // widget.controller!.text.trim().replaceAll(RegExp(r'\D'), '');

              // // Removed the empty check
              // if (formattedPhoneNumber.length != 10) {
                // setState(() {
                  // _errorMessage = "Phone number must be 10 digits";
                // });
                // return '';
              // }
            // } else if (widget.email != null) {
              // if (!EmailValidator.validate(widget.controller!.text.trim())) {
                // setState(() {
                  // _errorMessage = "Email is not valid";
                // });
                // return '';
              // }
            // } else if (widget.pass != null) {
              // // If passwordController is provided, this is a confirm password field
              // // Skip password strength validation and only check password match
              // if (widget.passwordController != null &&
                  // widget.controller != null) {
                // if (widget.controller!.text.trim() !=
                    // widget.passwordController!.text.trim()) {
                  // setState(() {
                    // _errorMessage = "Passwords do not match";
                  // });
                  // return '';
                // }
              // } else {
                // // Regular password field - validate password strength
                // String? validationMessage =
                    // ValidatePassword(widget.controller!.text.trim());
                // if (validationMessage != null) {
                  // setState(() {
                    // _errorMessage = validationMessage;
                  // });
                  // return '';
                // }
              // }
            // }

            // setState(() {
              // _errorMessage = null;
            // });

            // return null;
          // },
          // builder: (FormFieldState<String> state) {
            // return Column(
              // children: <Widget>[
                // Container(
                  // height: 50,
                  // padding:
                      // const EdgeInsets.symmetric(horizontal: 16.0, vertical: 0),
                  // decoration: BoxDecoration(
                    // color: Colors.white,
                    // borderRadius: BorderRadius.circular(8.0),
                    // border: Border.all(color: const Color(0xFFE0E0E0), width: 1.0),
                  // ),
                  // child: TextFormField(
                    // onTap: widget.onTap,
                    // obscureText: widget.obscureText,
                    // readOnly: widget.readOnnly,
                    // keyboardType: widget.keyboardType,
                    // focusNode: _focusNode,
                    // onChanged: (value) {
                      // if (widget.onChanged != null) {
                        // widget.onChanged!(value);
                      // }
                      // // Trigger validation on change for real-time feedback
                      // if (widget.passwordController != null ||
                          // widget.pass != null ||
                          // widget.phone != null) {
                        // state.didChange(value);
                      // }
                    // },
                    // inputFormatters: widget.inputFormatters ?? [],
                    // validator: (value) {
                      // if (value == null || value.isEmpty) {
                        // state.validate();
                      // }
                      // return null;
                    // },
                    // controller: widget.controller,
                    // decoration: InputDecoration(
                      // suffixIcon: widget.suffixIcon,
                      // hintStyle: const TextStyle(
                          // fontSize: 13, color: Color(0xFFb0b6c3)),
                      // border: InputBorder.none,
                      // hintText: widget.hintText,
                    // ),
                  // ),
                // ),
                // if (state.hasError)
                  // const SizedBox(height: 24), // Reserve space for error message
              // ],
            // );
          // },
        // ),
        // if (_errorMessage != null)
          // Positioned(
            // top: 60,
            // left: 8,
            // child: Text(
              // _errorMessage!,
              // style: const TextStyle(
                // color: Colors.red,
                // fontSize: 12.0,
              // ),
            // ),
          // ),
      // ],
    // );
    // return shouldUseKeyboardActions
        // ? SizedBox(
            // height: _errorMessage != null ? 75 : 60,
            // width: MediaQuery.of(context).size.width * .98,
            // child: KeyboardActions(
              // config: _buildConfig(context),
              // child: textfield,
            // ),
          // )
        // : textfield;
  // }
// }
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
  final bool readOnnly;

  /// When true this field may be left blank, and every other rule below is
  /// skipped while it is. Used for the Password / Confirm Password pair on
  /// this EDIT screen - see the note on the validator.
  ///
  /// This previously disabled the validator outright (`optional != null ?
  /// null : ...`), which would also have skipped the strength and match
  /// checks on a password the user HAD typed. Nothing passed it, so nothing
  /// depended on that meaning.
  final bool? optional;
  final bool? pass;
  final bool? email;
  final bool? phone;
  final List<TextInputFormatter>? inputFormatters;
  final TextEditingController?
      passwordController;

  CustomTextField({
    Key? key,
    this.controller,
    required this.hintText,
    this.obscureText = false,
    this.keyboardType = TextInputType.emailAddress,
    this.readOnnly = false,
    this.prefixIcon,
    this.suffixIcon,
    this.validator,
    this.onSuffixIconPressed,
    this.onTap,
    this.onChanged,
    this.optional,
    this.onChanged2,
    this.pass,
    this.email,
    this.phone,
    this.inputFormatters,
    this.passwordController,
  }) : super(key: key);

  @override
  CustomTextFieldState createState() => CustomTextFieldState();
}

class CustomTextFieldState extends State<CustomTextField> {
  String? _errorMessage;
  TextEditingController _textController =
      TextEditingController();

  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _textController = widget.controller ?? TextEditingController();
    _focusNode = FocusNode();

    if (widget.passwordController != null && widget.controller != null) {
      widget.passwordController!.addListener(_validateConfirmPassword);
      widget.controller!.addListener(_validateConfirmPassword);
    }
  }

  void _validateConfirmPassword() {
    if (widget.passwordController != null && widget.controller != null) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    if (widget.passwordController != null) {
      widget.passwordController!.removeListener(_validateConfirmPassword);
    }
    if (widget.controller != null) {
      widget.controller!.removeListener(_validateConfirmPassword);
    }
    // Only dispose the controller this widget CREATED. When the caller
    // passes one in it belongs to them — disposing it here double-disposed
    // it (the screen's own dispose() releases it too), which threw
    // "A TextEditingController was used after being disposed" on teardown.
    if (widget.controller == null) {
      _textController.dispose();
    }
    _focusNode.dispose();
    super.dispose();
  }

  KeyboardActionsConfig _buildConfig(BuildContext context) {
    return KeyboardActionsConfig(
      actions: [
        KeyboardActionsItem(
          focusNode: _focusNode,
          toolbarButtons: [
            (node) {
              return GestureDetector(
                onTap: () {
                  if (widget.onChanged2 != null) {
                    widget.onChanged2!(_textController.text);
                  }
                  node.unfocus();
                },
                child: const Padding(
                  padding: EdgeInsets.all(14.0),
                  child: Text(
                    "Done",
                    style: TextStyle(
                        color: Colors.blue, fontWeight: FontWeight.bold),
                  ),
                ),
              );
            },
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final shouldUseKeyboardActions =
        widget.keyboardType == TextInputType.number;
    Widget textfield = Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        FormField<String>(
          validator: (value) {
                  // CRM-4068, web parity (AddVendor.jsx:76-95): on the EDIT
                  // screen the password pair is optional. Leaving both blank
                  // preserves the existing password - the server already does
                  // this, deleting vendor_password from the update when it
                  // arrives empty (Vendor.js:713-717). It matters because the
                  // vendor GET stopped returning the password hash
                  // (Vendor.js:595, deliberate - it is a credential), so these
                  // boxes can never pre-fill any more and the blanket "every
                  // field is required" rule below blocked EVERY vendor edit,
                  // even one that only changed the name. When a password IS
                  // typed, the strength and match rules still run.
                  if (widget.optional == true) {
                    final bool selfEmpty =
                        (widget.controller?.text ?? '').trim().isEmpty;
                    final bool pairEmpty =
                        widget.passwordController == null ||
                            widget.passwordController!.text.trim().isEmpty;
                    if (selfEmpty && pairEmpty) {
                      setState(() {
                        _errorMessage = null;
                      });
                      return null;
                    }
                  }
                  if (widget.controller!.text.trim().isEmpty) {
                    setState(() {
                      String hintTextLower = widget.hintText.isEmpty
                          ? widget.hintText
                          : widget.hintText[0].toLowerCase() +
                              widget.hintText.substring(1);
                      _errorMessage = 'Please $hintTextLower';
                    });
                    return '';
                  } else if (widget.phone != null) {
                    String formattedPhoneNumber = widget.controller!.text
                        .trim()
                        .replaceAll(RegExp(r'\D'), '');
                    if (formattedPhoneNumber.length != 10) {
                      setState(() {
                        _errorMessage = "Phone number must be 10 digits";
                      });
                      return '';
                    }
                  } else if (widget.email != null) {
                    if (!EmailValidator.validate(
                        widget.controller!.text.trim())) {
                      setState(() {
                        _errorMessage = "Email is not valid";
                      });
                      return '';
                    }
                  } else if (widget.pass != null) {
                    if (widget.passwordController != null &&
                        widget.controller != null) {
                      if (widget.controller!.text.trim() !=
                          widget.passwordController!.text.trim()) {
                        setState(() {
                          _errorMessage = "Passwords do not match";
                        });
                        return '';
                      }
                    } else {
                      String? validationMessage =
                          ValidatePassword(widget.controller!.text.trim());
                      if (validationMessage != null) {
                        setState(() {
                          _errorMessage = validationMessage;
                        });
                        return '';
                      }
                    }
                  }
                  setState(() {
                    _errorMessage = null;
                  });
                  return null;
                },
          builder: (FormFieldState<String> state) {
            return Column(
              children: <Widget>[
                Container(
                  height: 50,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16.0, vertical: 0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8.0),
                    border: Border.all(color: const Color(0xFFE0E0E0), width: 1.0),
                  ),
                  child: TextFormField(
                    onTap: widget.onTap,
                    obscureText: widget.obscureText,
                    readOnly: widget.readOnnly,
                    keyboardType: widget.keyboardType,
                    focusNode: _focusNode,
                    onChanged: (value) {
                      if (widget.onChanged != null) {
                        widget.onChanged!(value);
                      }
                      if (widget.passwordController != null ||
                          widget.pass != null) {
                        state.didChange(value);
                      }
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        state.validate();
                      }
                      return null;
                    },
                    controller: widget.controller,
                    inputFormatters: widget.inputFormatters ?? [],
                    decoration: InputDecoration(
                      suffixIcon: widget.suffixIcon,
                      hintStyle: const TextStyle(
                          fontSize: 13, color: Color(0xFFb0b6c3)),
                      border: InputBorder.none,
                      hintText: widget.hintText,
                    ),
                  ),
                ),
                if (state.hasError)
                  const SizedBox(height: 24),
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
    return shouldUseKeyboardActions
        ? SizedBox(
            height: _errorMessage != null ? 75 : 60,
            width: MediaQuery.of(context).size.width * .98,
            child: KeyboardActions(
              config: _buildConfig(context),
              child: textfield,
            ),
          )
        : textfield;
  }
}

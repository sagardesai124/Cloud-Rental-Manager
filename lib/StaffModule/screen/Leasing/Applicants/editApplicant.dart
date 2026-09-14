import 'package:three_zero_two_property/services/app_log.dart';
import 'dart:convert';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/services.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:three_zero_two_property/services/api_helpers.dart';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:three_zero_two_property/Model/lease.dart';
import 'package:three_zero_two_property/StaffModule/repository/applicants.dart';
import 'package:three_zero_two_property/constant/constant.dart';

import 'package:three_zero_two_property/screens/Rental/Tenants/add_tenants.dart';
import '../../../widgets/appbar.dart';
import 'package:three_zero_two_property/widgets/drawer_tiles.dart';
import 'package:three_zero_two_property/widgets/titleBar.dart';

import '../../../../model/ApplicantModel.dart';
import '../../../widgets/custom_drawer.dart';
class EditApplicant extends StatefulWidget {
  Datum applicant;

  final String applicantId;
  EditApplicant({
    required this.applicantId,
    required this.applicant,
  });

  @override
  State<EditApplicant> createState() => _EditApplicantState();
}

class _EditApplicantState extends State<EditApplicant> {
  String? initialFirstName;
  String? initialLastName;
  String? initialEmail;
  String? initialMobileNumber;
  String? initialHomeNumber;
  String? initialBusinessNumber;
  String? initialTelephoneNumber;
  @override
  void initState() {
    // TODO: implement initState
    firstName.text = widget.applicant.applicantFirstName!;
    lastName.text = widget.applicant.applicantLastName!;
    email.text = widget.applicant.applicantEmail!;
    mobileNumber.text = widget.applicant.applicantPhoneNumber == null
        ? ''
        : formatPhoneNumberedit(widget.applicant.applicantPhoneNumber!.toString());
    homeNumber.text = widget.applicant.applicantHomeNumber == null
        ? ''
        : formatPhoneNumberedit(widget.applicant.applicantHomeNumber!.toString());
    bussinessNumber.text = widget.applicant.applicantBusinessNumber == null
        ? ''
        : formatPhoneNumberedit(widget.applicant.applicantBusinessNumber!.toString());
    telePhoneNumber.text = widget.applicant.applicantTelephoneNumber == null
        ? ''
        :formatPhoneNumberedit( widget.applicant.applicantTelephoneNumber!.toString());

    initialFirstName = widget.applicant.applicantFirstName;
    initialLastName = widget.applicant.applicantLastName;
    initialEmail = widget.applicant.applicantEmail;
    initialMobileNumber = widget.applicant.applicantPhoneNumber?.toString();
    initialHomeNumber = widget.applicant.applicantHomeNumber?.toString();
    initialBusinessNumber =
        widget.applicant.applicantBusinessNumber?.toString();
    initialTelephoneNumber =
        widget.applicant.applicantTelephoneNumber?.toString();

    super.initState();
  }

  final TextEditingController firstName = TextEditingController();
  final TextEditingController lastName = TextEditingController();
  final TextEditingController email = TextEditingController();
  final TextEditingController mobileNumber = TextEditingController();
  final TextEditingController homeNumber = TextEditingController();
  final TextEditingController bussinessNumber = TextEditingController();
  final TextEditingController telePhoneNumber = TextEditingController();
  final TextEditingController referenceEmail = TextEditingController();

  bool _isLoading = true;
  bool _Loading = false;
  bool isLoading = false;
  String? errorMessage;
  Map<String, String> properties = {}; // Mapping of rental_id to rental_address
  Map<String, String> units = {}; // Mapping of unit_id to rental_unit

  String? _selectedPropertyId;
  String? _selectedProperty;
  String? _selectedUnitId;
  String? _selectedUnit;

  // Future<void> _loadProperties() async {
  //   SharedPreferences prefs = await SharedPreferences.getInstance();
  //   String? id = prefs.getString("adminId");

  //   setState(() {
  //     _isLoading = true;
  //   });

  //   try {
  //     final response =
  //         await apiGet(Uri.parse('${Api_url}/api/rentals/rentals/$id'));
  //     print('${Api_url}/api/rentals/rentals/$id');

  //     if (response.statusCode == 200) {
  //       List jsonResponse = json.decode(response.body)['data'];
  //       Map<String, String> addresses = {};
  //       jsonResponse.forEach((data) {
  //         addresses[data['rental_id'].toString()] =
  //             data['rental_adress'].toString();
  //       });

  //       setState(() {
  //         properties = addresses;
  //         _isLoading = false;
  //       });
  //     } else {
  //       throw Exception('Failed to load data');
  //     }
  //   } catch (e) {
  //     setState(() {
  //       _isLoading = false;
  //     });
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(content: Text('Failed to fetch properties: $e')),
  //     );
  //   }
  // }

  // Future<void> _loadUnits(String rentalId) async {
  //   setState(() {
  //     _isLoading = true;
  //   });

  //   try {
  //     final response =
  //         await apiGet(Uri.parse('$Api_url/api/unit/rental_unit/$rentalId'));
  //     print('$Api_url/api/unit/rental_unit/$rentalId');

  //     if (response.statusCode == 200) {
  //       List jsonResponse = json.decode(response.body)['data'];
  //       Map<String, String> unitAddresses = {};
  //       jsonResponse.forEach((data) {
  //         unitAddresses[data['unit_id'].toString()] =
  //             data['rental_unit'].toString();
  //       });

  //       setState(() {
  //         units = unitAddresses;
  //         _isLoading = false;
  //       });
  //     } else {
  //       throw Exception('Failed to load units');
  //     }
  //   } catch (e) {
  //     setState(() {
  //       _isLoading = false;
  //     });
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(content: Text('Failed to fetch units: $e')),
  //     );
  //   }
  // }

  GlobalKey<FormState> _formkey = GlobalKey<FormState>();
  String renderId = '';
  String unitId = '';
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget_302_Staff.App_Bar(context: context),
      backgroundColor: const Color(0xFFF4F6F9),
      drawer:CustomDrawerStaff(currentpage: "Applicants",dropdown: true,),
      body: SingleChildScrollView(
        child: Form(
          key: _formkey,
          child: Column(
            children: [
              const SizedBox(
                height: 12,
              ),
              titleBar(
                width: MediaQuery.of(context).size.width * .91,
                title: 'Edit Applicant',
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(
                        color: const Color(0xFFDBE0E5),
                      ),
                      borderRadius: BorderRadius.circular(12.0)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(
                          height: 8,
                        ),
                        const Text('First Name *',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color.fromRGBO(21, 43, 81, 1))),
                        const SizedBox(
                          height: 4,
                        ),
                        CustomTextField(
                          showElevation: false,
                          borderColor: const Color(0xFFDBE0E5),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter first name';
                            }
                            return null;
                          },
                          keyboardType: TextInputType.text,
                          hintText: 'Enter first name',
                          controller: firstName,
                        ),
                        const SizedBox(
                          height: 8,
                        ),
                        const Text('Last Name *',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color.fromRGBO(21, 43, 81, 1))),
                        const SizedBox(
                          height: 4,
                        ),
                        CustomTextField(
                          showElevation: false,
                          borderColor: const Color(0xFFDBE0E5),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter last name';
                            }
                            return null;
                          },
                          keyboardType: TextInputType.text,
                          hintText: 'Enter last name',
                          controller: lastName,
                        ),
                        const SizedBox(
                          height: 8,
                        ),
                        const Text('Email*',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color.fromRGBO(21, 43, 81, 1))),
                        const SizedBox(
                          height: 4,
                        ),
                        CustomTextField(
                          showElevation: false,
                          borderColor: const Color(0xFFDBE0E5),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter email';
                            }
                            return null;
                          },
                          email: true,
                          keyboardType: TextInputType.text,
                          hintText: 'Enter email',
                          controller: email,
                        ),
                        const SizedBox(
                          height: 8,
                        ),
                        const Text('Cell Phone Number *',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color.fromRGBO(21, 43, 81, 1))),
                        const SizedBox(
                          height: 4,
                        ),
                        CustomTextField(
                          showElevation: false,
                          borderColor: const Color(0xFFDBE0E5),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter cell phone number';
                            }
                            return null;
                          },
                          keyboardType: TextInputType.number,
                          // keyboardType: TextInputType.numberWithOptions(
                          //     signed: true, decimal: true),
                          hintText: 'Enter cell phone number',
                          controller: mobileNumber,
                          otherController: homeNumber,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(10),
                            PhoneNumberFormatter(),
                          ],
                          phone: true,
                        ),
                        const SizedBox(
                          height: 8,
                        ),
                        const Text('Home Phone Number',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color.fromRGBO(21, 43, 81, 1))),
                        const SizedBox(
                          height: 4,
                        ),
                        CustomTextField(
                          showElevation: false,
                          borderColor: const Color(0xFFDBE0E5),
                          // validator: (value) {
                          //   if (value == null || value.isEmpty) {
                          //     return 'Please enter home number';
                          //   }
                          //   return null;
                          // },
                          // keyboardType: TextInputType.numberWithOptions(
                          //     signed: true, decimal: true),
                          keyboardType: TextInputType.number,
                          hintText: 'Enter home phone number',
                          controller: homeNumber,
                          otherController: mobileNumber,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(10),
                            PhoneNumberFormatter(),
                          ],
                          optional: true,
                          phone: true,
                        ),
                        const SizedBox(
                          height: 8,
                        ),
                        const Text('Work Phone Number',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color.fromRGBO(21, 43, 81, 1))),
                        const SizedBox(
                          height: 4,
                        ),
                        CustomTextField(
                          showElevation: false,
                          borderColor: const Color(0xFFDBE0E5),
                          // validator: (value) {
                          //   if (value == null || value.isEmpty) {
                          //     return 'Please enter business number';
                          //   }
                          //   return null;
                          // },
                          // keyboardType: TextInputType.numberWithOptions(
                          //     signed: true, decimal: true),
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(10),
                            PhoneNumberFormatter(),
                          ],
                          hintText: 'Enter work phone number',
                          controller: bussinessNumber,
                          otherController: homeNumber,
                          businessController: mobileNumber,
                          optional: true,
                          phone: true,
                        ),
                        const SizedBox(
                          height: 8,
                        ),
                        // Web parity: Reference Email shown instead of the
                        // Telephone Number field (telephone is still sent
                        // unchanged in the payload, exactly like the web).
                        const Text('Reference Email',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color.fromRGBO(21, 43, 81, 1))),
                        const SizedBox(
                          height: 4,
                        ),
                        CustomTextField(
                          showElevation: false,
                          borderColor: const Color(0xFFDBE0E5),
                          keyboardType: TextInputType.emailAddress,
                          hintText: 'Enter reference email',
                          controller: referenceEmail,
                          optional: true,
                          email: true,
                        ),

                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 30.0),
                child: Row(
                  children: [
                    Container(
                      height: 50,
                      width: (MediaQuery.of(context).size.width - 44) / 2,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: blueColor,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10.0),
                          ),
                        ),
                        onPressed: () async {
                          if (_formkey.currentState!.validate()) {
                            bool isFormValid = true;

                            // Validate each field and update the state accordingly
                            if (firstName.text.isEmpty) {
                              setState(() {
                                isFormValid = false;
                              });
                            }

                            if (lastName.text.isEmpty) {
                              setState(() {
                                isFormValid = false;
                              });
                            }

                            if (email.text.isEmpty) {
                              setState(() {
                                isFormValid = false;
                              });
                            }

                            // Check for changes
                            bool hasChanges = firstName.text !=
                                initialFirstName ||
                                lastName.text != initialLastName ||
                                email.text != initialEmail ||
                                mobileNumber.text != initialMobileNumber ||
                                homeNumber.text != initialHomeNumber ||
                                bussinessNumber.text != initialBusinessNumber ||
                                telePhoneNumber.text != initialTelephoneNumber;

                            if (!hasChanges) {
                              Navigator.of(context)
                                  .pop(false); // Optionally navigate back
                              return;
                            }

                            if (!isFormValid) {
                              return; // Exit early if the form is not valid
                            }

                            // Proceed with API call
                            SharedPreferences prefs =
                            await SharedPreferences.getInstance();
                            String? adminId = prefs.getString("adminId");

                            if (adminId != null) {
                              try {
                                setState(() {
                                  isLoading = true;
                                });
                                // Create the applicant data map.
                                // Empty fields fall back to '' like the Admin
                                // screen. This used to write the literal
                                // string 'N/A' into the record, which then
                                // round-tripped into the form and every
                                // display as if it were real data.
                                Map<String, dynamic> applicantData = {
                                  "applicant_firstName":
                                  firstName.text.trim().isNotEmpty
                                      ? firstName.text.trim()
                                      : '',
                                  "applicant_lastName": lastName.text.trim().isNotEmpty
                                      ? lastName.text.trim()
                                      : '',
                                  "applicant_email": email.text.trim().isNotEmpty
                                      ? email.text.trim()
                                      : '',
                                  "applicant_phoneNumber":
                                  mobileNumber.text.trim().isNotEmpty
                                      ? mobileNumber.text.trim()
                                      : '',
                                  "applicant_homeNumber":
                                  homeNumber.text.trim().isNotEmpty
                                      ? homeNumber.text.trim()
                                      : '',
                                  "applicant_telephoneNumber":
                                  telePhoneNumber.text.trim().isNotEmpty
                                      ? telePhoneNumber.text.trim()
                                      : '',
                                  "applicant_businessNumber":
                                  bussinessNumber.text.trim().isNotEmpty
                                      ? bussinessNumber.text.trim()
                                      : '',
                                };

                                // Make the API call using updateApplicants
                                final response =
                                await ApplicantRepository.updateApplicants(
                                  applicantId: widget.applicantId,
                                  applicantData: applicantData,
                                );

                                Fluttertoast.showToast(
                                    msg: "Applicant updated successfully");
                                Navigator.of(context).pop(true);
                                setState(() {
                                  widget.applicant.applicant!
                                      .applicantFirstName = firstName.text;
                                  widget.applicant.applicant!
                                      .applicantLastName = lastName.text;
                                  widget.applicant.applicant!
                                      .applicantPhoneNumber = mobileNumber.text;
                                  widget.applicant.applicant!
                                      .applicantHomeNumber = homeNumber.text;
                                  widget.applicant.applicant!
                                      .applicantBusinessNumber =
                                      bussinessNumber.text;
                                  widget.applicant.applicant!
                                      .applicantTelephoneNumber =
                                      telePhoneNumber.text;
                                  widget.applicant.applicant!.applicantEmail =
                                      email.text;
                                  isLoading = false;
                                });
                              } catch (e) {
                                setState(() {
                                  isLoading = false;
                                });
                              }
                            }
                          } else {
                            setState(() {
                              isLoading = false;
                              errorMessage = "Admin ID not found";
                            });
                            //  Fluttertoast.showToast(msg: "Admin ID not found");
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
                                'Update Applicant',
                                style: TextStyle(
                                    color: Color(0xFFf7f8f9),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15),
                              ),
                      ),
                    ),
                    const SizedBox(
                      width: 12,
                    ),
                    Container(
                        height: 50,
                        width: (MediaQuery.of(context).size.width - 44) / 2,
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10.0)),
                        child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFffffff),
                                elevation: 0,
                                side: const BorderSide(
                                    color: Color(0xFFDBE0E5)),
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(10.0))),
                            onPressed: () {
                              Navigator.pop(context);
                              firstName.clear();
                              lastName.clear();
                              email.clear();
                              mobileNumber.clear();
                              bussinessNumber.clear();
                              homeNumber.clear();
                              telePhoneNumber.clear();
                              referenceEmail.clear();
                              _selectedProperty = null;
                              _selectedUnit = null;
                            },
                            child: const Text(
                              'Cancel',
                              style: TextStyle(
                                  color: Color(0xFF748097),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15),
                            ))),

                  ],
                ),
              ),
              SizedBox(
                height: 10,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submitApplicantAndLease() async {
    setState(() {
      _Loading = true;
    });
    try {
      // Handle successful response

      // print('Response: $response');
    } catch (e) {
      // Handle error
      logError('Error posting applicant and lease: $e');
    } finally {
      setState(() {
        _Loading = false;
      });
    }
  }
}

import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:three_zero_two_property/services/api_helpers.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:three_zero_two_property/Model/applicant_summery_model.dart';
import 'package:three_zero_two_property/constant/constant.dart';
import 'package:three_zero_two_property/widgets/us_state_dropdown.dart';
import 'package:three_zero_two_property/provider/edit_applicant.dart';
import 'package:three_zero_two_property/provider/editapplicationsummaryForm.dart';
import 'package:three_zero_two_property/repository/applicant_summery_repo.dart';

import 'package:three_zero_two_property/widgets/CustomDateField.dart';
import 'package:three_zero_two_property/widgets/CustomTextField.dart';

class EditApplicantSummary extends StatefulWidget {
  String applicantId;

  EditApplicantSummary({required this.applicantId});

  @override
  State<EditApplicantSummary> createState() => _EditApplicantSummaryState();
}


class _EditApplicantSummaryState extends State<EditApplicantSummary> {
  bool checked = true;
  final _formEditKey = GlobalKey<FormState>();

  final TextEditingController _applicantStreetAddressController =
  TextEditingController();
  final TextEditingController _applicantCityController =
  TextEditingController();
  final TextEditingController _applicantStateController =
  TextEditingController();
  final TextEditingController _applicantCountryController =
  TextEditingController();
  final TextEditingController _applicantPostalCodeController =
  TextEditingController();
  final TextEditingController _applicantFirstNameController =
  TextEditingController();
  final TextEditingController _applicantLastNameController =
  TextEditingController();
  final TextEditingController _applicantEmailController =
  TextEditingController();
  final TextEditingController _applicantPhoneNumberController =
  TextEditingController();
  final TextEditingController _applicantBirthdateController =
  TextEditingController();

  final TextEditingController _agreeByController = TextEditingController();
  final TextEditingController _emergencyFirstNameController =
  TextEditingController();
  final TextEditingController _emergencyLastNameController =
  TextEditingController();
  final TextEditingController _emergencyRelationshipController =
  TextEditingController();
  final TextEditingController _emergencyEmailController =
  TextEditingController();
  final TextEditingController _emergencyPhoneNumberController =
  TextEditingController();

  final TextEditingController _rentalAddressController =
  TextEditingController();
  final TextEditingController _rentalCityController = TextEditingController();
  final TextEditingController _rentalStateController = TextEditingController();
  final TextEditingController _rentalCountryController =
  TextEditingController();
  final TextEditingController _rentalPostcodeController =
  TextEditingController();
  final TextEditingController _rentalOwnerFirstNameController =
  TextEditingController();
  final TextEditingController _rentalOwnerLastNameController =
  TextEditingController();
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();
  final TextEditingController _rentController = TextEditingController();
  final TextEditingController _leavingReasonController =
  TextEditingController();
  final TextEditingController _rentalOwnerEmailController =
  TextEditingController();
  final TextEditingController _rentalOwnerPhoneNumberController =
  TextEditingController();

  final TextEditingController _employmentNameController =
  TextEditingController();
  final TextEditingController _employmentStreetAddressController =
  TextEditingController();
  final TextEditingController _employmentCityController =
  TextEditingController();
  final TextEditingController _employmentStateController =
  TextEditingController();
  final TextEditingController _employmentCountryController =
  TextEditingController();
  final TextEditingController _employmentPostalCodeController =
  TextEditingController();
  final TextEditingController _employmentPrimaryEmailController =
  TextEditingController();
  final TextEditingController _employmentPhoneNumberController =
  TextEditingController();
  final TextEditingController _employmentPositionController =
  TextEditingController();
  final TextEditingController _supervisorFirstNameController =
  TextEditingController();
  final TextEditingController _supervisorLastNameController =
  TextEditingController();
  final TextEditingController _supervisorTitleController =
  TextEditingController();

  @override
  void dispose() {
    // Dispose controllers
    _emergencyFirstNameController.dispose();
    _emergencyLastNameController.dispose();
    _emergencyRelationshipController.dispose();
    _emergencyEmailController.dispose();
    _emergencyPhoneNumberController.dispose();

    _rentalAddressController.dispose();
    _rentalCityController.dispose();
    _rentalStateController.dispose();
    _rentalCountryController.dispose();
    _rentalPostcodeController.dispose();
    _rentalOwnerFirstNameController.dispose();
    _rentalOwnerLastNameController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    _rentController.dispose();
    _leavingReasonController.dispose();
    _rentalOwnerEmailController.dispose();
    _rentalOwnerPhoneNumberController.dispose();

    _employmentNameController.dispose();
    _employmentStreetAddressController.dispose();
    _employmentCityController.dispose();
    _employmentStateController.dispose();
    _employmentCountryController.dispose();
    _employmentPostalCodeController.dispose();
    _employmentPrimaryEmailController.dispose();
    _employmentPhoneNumberController.dispose();
    _employmentPositionController.dispose();
    _supervisorFirstNameController.dispose();
    _supervisorLastNameController.dispose();
    _supervisorTitleController.dispose();

    _applicantStreetAddressController.dispose();
    _applicantCityController.dispose();
    _applicantStateController.dispose();
    _applicantCountryController.dispose();
    _applicantPostalCodeController.dispose();
    _applicantFirstNameController.dispose();
    _applicantLastNameController.dispose();
    _applicantEmailController.dispose();
    _applicantPhoneNumberController.dispose();
    _agreeByController.dispose();

    super.dispose();
  }

  Future<ApplicantContentDetails> fetchApplicantDetails(
      String applicantId) async
  {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? adminId = prefs.getString('adminId');
    String? token = prefs.getString('token');
    try {
      final response = await apiGet(
        Uri.parse('$Api_url/api/applicant/applicant_details/$applicantId'),
        headers: {
          "id": "CRM ${prefs.getString('staff_id') ?? adminId}",
          "authorization": "CRM $token",
          'Content-Type': 'application/json; charset=UTF-8',
        },
      );

      if (response.statusCode == 200) {
        return ApplicantContentDetails.fromJson(json.decode(response.body));
      } else {
        throw Exception('Failed to load applicant details');
      }
    } catch (e) {
      throw Exception('Failed to load applicant details');
    }
  }


  @override
  void initState() {
    super.initState();
    // setState(() {
    //   _applicantFirstNameController.text = applicantName;
    // });

    fetchAndSetApplicantDetails();
  }

  Future<void> fetchAndSetApplicantDetails() async
  {
    final applicantDetails = await fetchApplicantDetails(widget.applicantId);
    if (applicantDetails.data != null) {
      Provider.of<ApplicantDetailsProvider>(context, listen: false)
          .setApplicantDetails(applicantDetails.data!);

      setState(() {
        _applicantStreetAddressController.text =
            applicantDetails.data!.applicantStreetAddress ?? '';
        _applicantCityController.text =
            applicantDetails.data!.applicantCity ?? '';
        _applicantStateController.text =
            applicantDetails.data!.applicantState ?? '';
        _applicantCountryController.text =
            applicantDetails.data!.applicantCountry ?? '';
        _applicantPostalCodeController.text =
            applicantDetails.data!.applicantPostalCode ?? '';
        _applicantFirstNameController.text =
            applicantDetails.data!.applicantFirstName ?? '';
        _applicantLastNameController.text =
            applicantDetails.data!.applicantLastName ?? '';
        _applicantEmailController.text =
            applicantDetails.data!.applicantEmail ?? '';
        _applicantPhoneNumberController.text =
            formatPhoneNumberedit( applicantDetails.data!.applicantPhoneNumber ?? '');
        _emergencyFirstNameController.text =
            applicantDetails.data!.emergencyContact?.firstName ?? '';
        _emergencyLastNameController.text =
            applicantDetails.data!.emergencyContact?.lastName ?? '';
        _emergencyRelationshipController.text =
            applicantDetails.data!.emergencyContact?.relationship ?? '';
        _emergencyEmailController.text =
            applicantDetails.data!.emergencyContact?.email ?? '';
        _emergencyPhoneNumberController.text =
            formatPhoneNumberedit( (applicantDetails.data!.emergencyContact?.phoneNumber.toString()) ??
                '');
           

        // Set rental details
        _rentalAddressController.text =
            applicantDetails.data!.rentalHistory?.rentalAdress ?? '';
        _rentalCityController.text =
            applicantDetails.data!.rentalHistory?.rentalCity ?? '';
        _rentalStateController.text =
            applicantDetails.data!.rentalHistory?.rentalState ?? '';
        _rentalCountryController.text =
            applicantDetails.data!.rentalHistory?.rentalCountry ?? '';
        _rentalPostcodeController.text =
            applicantDetails.data!.rentalHistory?.rentalPostcode ?? '';
        _rentalOwnerFirstNameController.text =
            applicantDetails.data!.rentalHistory?.rentalOwnerFirstName ?? '';
        _rentalOwnerLastNameController.text =
            applicantDetails.data!.rentalHistory?.rentalOwnerLastName ?? '';
        _startDateController.text =
            applicantDetails.data!.rentalHistory?.startDate ?? '';
        _endDateController.text =
            applicantDetails.data!.rentalHistory?.endDate ?? '';
        _rentController.text = applicantDetails.data!.rentalHistory?.rent ?? '';
        _leavingReasonController.text =
            applicantDetails.data!.rentalHistory?.leavingReason ?? '';
        _rentalOwnerEmailController.text =
            applicantDetails.data!.rentalHistory?.rentalOwnerPrimaryEmail ?? '';
        _rentalOwnerPhoneNumberController.text =formatPhoneNumberedit( (applicantDetails
            .data!.rentalHistory?.rentalOwnerPhoneNumber
            .toString()) ??
            '');

        // Set employment details
        _employmentNameController.text =
            applicantDetails.data!.employment?.name ?? '';
        _employmentStreetAddressController.text =
            applicantDetails.data!.employment?.streetAddress ?? '';
        _employmentCityController.text =
            applicantDetails.data!.employment?.city ?? '';
        _employmentStateController.text =
            applicantDetails.data!.employment?.state ?? '';
        _employmentCountryController.text =
            applicantDetails.data!.employment?.country ?? '';
        _employmentPostalCodeController.text =
            applicantDetails.data!.employment?.postalCode ?? '';
        _employmentPrimaryEmailController.text =
            applicantDetails.data!.employment?.employmentPrimaryEmail ?? '';
        _employmentPhoneNumberController.text = formatPhoneNumberedit('${applicantDetails
            .data!.employment?.employmentPhoneNumber
            .toString()}');

        _employmentPositionController.text =
            applicantDetails.data!.employment?.employmentPosition ?? '';
        _supervisorFirstNameController.text =
            applicantDetails.data!.employment?.supervisorFirstName ?? '';
        _supervisorLastNameController.text =
            applicantDetails.data!.employment?.supervisorLastName ?? '';
        _supervisorTitleController.text =
            applicantDetails.data!.employment?.supervisorTitle ?? '';
      });
    }
  }
  bool isCheckboxError = false;
  @override
  Widget build(BuildContext context) {
    final editFormState = Provider.of<EditFormState>(context);
    return Container(
      child: Form(
        key: _formEditKey,
        child:
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: Text('Edit Applicant Details',
                      softWrap: true,
                      overflow: TextOverflow.fade,
                      style: TextStyle(
                          color: blueColor,
                          fontSize: 18,
                          fontWeight: FontWeight.w500)),
                ),
                GestureDetector(
                  onTap: () {
                    editFormState.setEditForm(!editFormState.showEditForm);
                  },
                  child: Container(
                    child: Material(
                      borderRadius: BorderRadius.circular(4.0),
                      elevation: 4,
                      child: Container(
                        decoration: BoxDecoration(
                          color: blueColor,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                              color:blueColor),
                        ),
                        child: const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w500),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(
              height: 16,
            ),
            Text(
              'Applicant information',
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w500, color: blueColor),
            ),
            const SizedBox(
              height: 5,
            ),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                  border: Border.all(
                    color:  blueColor,
                  ),
                  borderRadius: BorderRadius.circular(10.0)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'First name',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[500]),
                    ),
                    const SizedBox(
                      height: 5,
                    ),
                    NewCustomTextField(
                      hintText: 'First Name',

                      controller: _applicantFirstNameController,
                    ),
                    const SizedBox(
                      height: 12,
                    ),
                    Text(
                      'Last Name',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[500]),
                    ),
                    const SizedBox(
                      height: 5,
                    ),
                    NewCustomTextField(
                      hintText: 'Last Name',
                      controller: _applicantLastNameController,
                    ),
                    const SizedBox(
                      height: 12,
                    ),
                    Text(
                      'Date Of Birth',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[500]),
                    ),
                    const SizedBox(
                      height: 5,
                    ),
                    CustomDateField(
                      hintText: 'Pick date of birth',
                      controller:
                      _applicantBirthdateController,
                    ),
                    const SizedBox(
                      height: 12,
                    ),
                    Text(
                      'Email',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[500]),
                    ),
                    const SizedBox(
                      height: 5,
                    ),
                    NewCustomTextField(
                      hintText: 'Email',
                      email: true,
                      alterController:
                      _emergencyEmailController,
                      controller: _applicantEmailController,
                      keyboardType:
                      TextInputType.emailAddress,

                    ),
                    const SizedBox(
                      height: 12,
                    ),
                    Text(
                      'Phone Number',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[500]),
                    ),
                    const SizedBox(
                      height: 5,
                    ),
                    NewCustomTextField(
                      hintText: 'Phone Number',
                      phone: true,
                      keyboardType: TextInputType.number,
                      controller: _applicantPhoneNumberController,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                        PhoneNumberFormatter(),
                      ],
                      otherController: _emergencyPhoneNumberController,
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            //Applicant Street Address
            const SizedBox(
              height: 16.0,
            ),
            Text(
              'Applicant Street Address',
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w500, color: blueColor),
            ),
            const SizedBox(
              height: 5,
            ),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(
                  color:  blueColor,
                ),
                borderRadius: BorderRadius.circular(10.0),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Street Address',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[500]),
                    ),
                    const SizedBox(
                      height: 5,
                    ),
                    NewCustomTextField(
                      hintText: 'Street Address',
                      optional: true,
                      controller: _applicantStreetAddressController,
                    ),
                    const SizedBox(
                      height: 12,
                    ),
                    Text(
                      'City',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[500]),
                    ),
                    const SizedBox(
                      height: 5,
                    ),
                    NewCustomTextField(
                      optional: true,
                      hintText: 'City',
                      controller: _applicantCityController,
                    ),
                    const SizedBox(
                      height: 12,
                    ),
                    Text(
                      'State',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[500]),
                    ),
                    const SizedBox(
                      height: 5,
                    ),
                    UsStateDropdown(
                      controller: _applicantStateController,
                      hintText: 'Select state',
                    ),
                    const SizedBox(
                      height: 12,
                    ),
                    Text(
                      'Country',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[500]),
                    ),
                    const SizedBox(
                      height: 5,
                    ),
                    NewCustomTextField(
                      optional: true,
                      hintText: 'Country',
                      controller: _applicantCountryController,
                    ),
                    const SizedBox(
                      height: 12,
                    ),
                    Text(
                      'Postal Code',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[500]),
                    ),
                    const SizedBox(
                      height: 5,
                    ),
                    NewCustomTextField(
                      optional: true,
                      hintText: 'Postal Code',
                      controller: _applicantPostalCodeController,
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            const SizedBox(
              height: 16,
            ),
            Text(
              'Emergency contact',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: blueColor,
              ),
            ),
            const SizedBox(
              height: 5,
            ),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(
                  color:  blueColor,
                ),
                borderRadius: BorderRadius.circular(10.0),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'First Name',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[500],
                      ),
                    ),
                    const SizedBox(
                      height: 5,
                    ),
                    NewCustomTextField(
                      optional: true,
                      hintText: 'First Name',
                      controller: _emergencyFirstNameController,
                    ),
                    const SizedBox(
                      height: 12,
                    ),
                    Text(
                      'Last Name',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[500],
                      ),
                    ),
                    const SizedBox(
                      height: 5,
                    ),
                    NewCustomTextField(
                      optional: true,
                      hintText: 'Last Name',
                      controller: _emergencyLastNameController,
                    ),
                    const SizedBox(
                      height: 12,
                    ),
                    Text(
                      'Relationship',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[500],
                      ),
                    ),
                    const SizedBox(
                      height: 5,
                    ),
                    NewCustomTextField(
                      optional: true,
                      hintText: 'Relationship',
                      controller: _emergencyRelationshipController,
                    ),
                    const SizedBox(
                      height: 12,
                    ),
                    Text(
                      'Email',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[500],
                      ),
                    ),
                    const SizedBox(
                      height: 5,
                    ),
                    NewCustomTextField(
                      optional: true,
                      hintText: 'Email',
                      email: true,
                      alterController:
                      _applicantEmailController,
                      controller: _emergencyEmailController,

                    ),
                    const SizedBox(
                      height: 12,
                    ),
                    Text(
                      'Phone Number',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[500],
                      ),
                    ),
                    const SizedBox(
                      height: 5,
                    ),
                    NewCustomTextField(
                      optional: true,
                      phone: true,
                      hintText: 'Phone Number',
                      keyboardType: TextInputType.number,
                      controller: _emergencyPhoneNumberController,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                        PhoneNumberFormatter(),
                      ],
                      otherController: _applicantPhoneNumberController,
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            const SizedBox(
              height: 16,
            ),
            Text(
              'Rental history',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: blueColor,
              ),
            ),
            const SizedBox(
              height: 5,
            ),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(
                  color:  blueColor,
                ),
                borderRadius: BorderRadius.circular(10.0),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rental Address',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[500],
                      ),
                    ),
                    const SizedBox(
                      height: 5,
                    ),
                    NewCustomTextField(
                      optional: true,
                      hintText: 'Rental Address',
                      controller: _rentalAddressController,
                    ),
                    const SizedBox(
                      height: 12,
                    ),
                    Text(
                      'City',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[500],
                      ),
                    ),
                    const SizedBox(
                      height: 5,
                    ),
                    NewCustomTextField(
                      hintText: 'City',
                      optional: true,
                      controller: _rentalCityController,
                    ),
                    const SizedBox(
                      height: 12,
                    ),
                    Text(
                      'State',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[500],
                      ),
                    ),
                    const SizedBox(
                      height: 5,
                    ),
                    UsStateDropdown(
                      controller: _rentalStateController,
                      hintText: 'Select state',
                    ),
                    const SizedBox(
                      height: 12,
                    ),
                    Text(
                      'Country',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[500],
                      ),
                    ),
                    const SizedBox(
                      height: 5,
                    ),
                    NewCustomTextField(
                      optional: true,
                      hintText: 'Country',
                      controller: _rentalCountryController,
                    ),
                    const SizedBox(
                      height: 12,
                    ),
                    Text(
                      'Postcode',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[500],
                      ),
                    ),
                    const SizedBox(
                      height: 5,
                    ),
                    NewCustomTextField(
                      optional: true,
                      hintText: 'Postcode',
                      controller: _rentalPostcodeController,
                    ),
                    const SizedBox(
                      height: 12,
                    ),
                    Text(
                      'Start Date',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[500],
                      ),
                    ),
                    const SizedBox(
                      height: 5,
                    ),
                    NewCustomTextField(
                      optional: true,
                      hintText: 'Start Date',
                      controller: _startDateController,
                    ),
                    const SizedBox(
                      height: 12,
                    ),
                    Text(
                      'End Date',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[500],
                      ),
                    ),
                    const SizedBox(
                      height: 5,
                    ),
                    NewCustomTextField(
                      optional: true,
                      hintText: 'End Date',
                      controller: _endDateController,
                    ),
                    const SizedBox(
                      height: 12,
                    ),
                    Text(
                      'Rent Amount',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[500],
                      ),
                    ),
                    const SizedBox(
                      height: 5,
                    ),
                    NewCustomTextField(
                      optional: true,
                      hintText: 'Rent Amount',
                      controller: _rentController,
                    ),
                    const SizedBox(
                      height: 12,
                    ),
                    Text(
                      'Reason for Leaving',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[500],
                      ),
                    ),
                    const SizedBox(
                      height: 5,
                    ),
                    NewCustomTextField(
                      hintText: 'Reason for Leaving',
                      optional: true,
                      controller: _leavingReasonController,
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            const SizedBox(
              height: 16,
            ),
            Text(
              'Rental owner information',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: blueColor,
              ),
            ),
            const SizedBox(
              height: 5,
            ),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(
                  color:  blueColor,
                ),
                borderRadius: BorderRadius.circular(10.0),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'First Name',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[500],
                      ),
                    ),
                    const SizedBox(
                      height: 5,
                    ),
                    NewCustomTextField(
                      hintText: 'First Name',
                      optional: true,
                      controller: _rentalOwnerFirstNameController,
                    ),
                    const SizedBox(
                      height: 12,
                    ),
                    Text(
                      'Last Name',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[500],
                      ),
                    ),
                    const SizedBox(
                      height: 5,
                    ),
                    NewCustomTextField(
                      hintText: 'Last Name',
                      optional: true,
                      controller: _rentalOwnerLastNameController,
                    ),
                    const SizedBox(
                      height: 12,
                    ),
                    Text(
                      'Email',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[500],
                      ),
                    ),
                    const SizedBox(
                      height: 5,
                    ),
                    NewCustomTextField(
                      hintText: 'Email',
                      optional: true,
                      email: true,
                      controller:
                      _rentalOwnerEmailController,
                      alterController: _applicantEmailController,
                      emrgencyController: _emergencyEmailController,
                    ),
                    const SizedBox(
                      height: 12,
                    ),
                    Text(
                      'Phone Number',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[500],
                      ),
                    ),
                    const SizedBox(
                      height: 5,
                    ),
                    NewCustomTextField(
                      hintText: 'Phone Number',
                      optional: true,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter
                            .digitsOnly,
                        LengthLimitingTextInputFormatter(
                            10),
                        PhoneNumberFormatter(),
                      ],
                      phone: true,
                      otherController:
                      _emergencyPhoneNumberController,
                      businessController:
                      _applicantPhoneNumberController,
                      controller: _rentalOwnerPhoneNumberController,
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            const SizedBox(
              height: 16,
            ),
            Text(
              'Employment',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: blueColor,
              ),
            ),
            const SizedBox(
              height: 5,
            ),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(
                  color:  blueColor,
                ),
                borderRadius: BorderRadius.circular(10.0),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Company Name',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[500],
                      ),
                    ),
                    const SizedBox(
                      height: 5,
                    ),
                    NewCustomTextField(
                      hintText: 'Company Name',
                      optional: true,
                      controller: _employmentNameController,
                    ),
                    const SizedBox(
                      height: 12,
                    ),
                    Text(
                      'Street Address',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[500],
                      ),
                    ),
                    const SizedBox(
                      height: 5,
                    ),
                    NewCustomTextField(
                      hintText: 'Street Address',
                      optional: true,
                      controller: _employmentStreetAddressController,
                    ),
                    const SizedBox(
                      height: 12,
                    ),
                    Text(
                      'City',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[500],
                      ),
                    ),
                    const SizedBox(
                      height: 5,
                    ),
                    NewCustomTextField(
                      optional: true,
                      hintText: 'City',
                      controller: _employmentCityController,
                    ),
                    const SizedBox(
                      height: 12,
                    ),
                    Text(
                      'State',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[500],
                      ),
                    ),
                    const SizedBox(
                      height: 5,
                    ),
                    UsStateDropdown(
                      controller: _employmentStateController,
                      hintText: 'Select state',
                    ),
                    const SizedBox(
                      height: 12,
                    ),
                    Text(
                      'Country',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[500],
                      ),
                    ),
                    const SizedBox(
                      height: 5,
                    ),
                    NewCustomTextField(
                      optional: true,
                      hintText: 'Country',
                      controller: _employmentCountryController,
                    ),
                    const SizedBox(
                      height: 12,
                    ),
                    Text(
                      'Postal Code',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[500],
                      ),
                    ),
                    const SizedBox(
                      height: 5,
                    ),
                    NewCustomTextField(
                      optional: true,
                      hintText: 'Postal Code',
                      controller: _employmentPostalCodeController,
                    ),
                    const SizedBox(
                      height: 12,
                    ),
                    Text(
                      'Primary Email',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[500],
                      ),
                    ),
                    const SizedBox(
                      height: 5,
                    ),
                    NewCustomTextField(
                      hintText: 'Primary Email',
                      optional: true,
                      email: true,
                      keyboardType: TextInputType.number,
                      controller: _employmentPrimaryEmailController,
                      emailController:_applicantEmailController,
                      alterController: _rentalOwnerEmailController,
                      emrgencyController: _emergencyEmailController,
                    ),
                    const SizedBox(
                      height: 12,
                    ),
                    Text(
                      'Phone Number',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[500],
                      ),
                    ),
                    const SizedBox(
                      height: 5,
                    ),
                    NewCustomTextField(
                      hintText: 'Phone Number',
                      optional: true,
                      phone: true,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter
                            .digitsOnly,
                        LengthLimitingTextInputFormatter(
                            10),
                        PhoneNumberFormatter(),
                      ],
                      otherController:
                      _rentalOwnerPhoneNumberController,
                      businessController:
                      _emergencyPhoneNumberController,
                      telephoneController:
                      _applicantPhoneNumberController,
                      controller: _employmentPhoneNumberController,
                    ),
                    const SizedBox(
                      height: 12,
                    ),
                    Text(
                      'Position',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[500],
                      ),
                    ),
                    const SizedBox(
                      height: 5,
                    ),
                    NewCustomTextField(
                      hintText: 'Position',
                      optional: true,
                      controller: _employmentPositionController,
                    ),
                    const SizedBox(
                      height: 12,
                    ),
                    Text(
                      'Supervisor First Name',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[500],
                      ),
                    ),
                    const SizedBox(
                      height: 5,
                    ),
                    NewCustomTextField(
                      hintText: 'Supervisor First Name',
                      optional: true,
                      controller: _supervisorFirstNameController,
                    ),
                    const SizedBox(
                      height: 12,
                    ),
                    Text(
                      'Supervisor Last Name',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[500],
                      ),
                    ),
                    const SizedBox(
                      height: 5,
                    ),
                    NewCustomTextField(
                      hintText: 'Supervisor Last Name',
                      optional: true,
                      controller: _supervisorLastNameController,
                    ),
                    const SizedBox(
                      height: 12,
                    ),
                    Text(
                      'Supervisor Title',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[500],
                      ),
                    ),
                    const SizedBox(
                      height: 5,
                    ),
                    NewCustomTextField(
                      hintText: 'Supervisor Title',
                      optional: true,
                      controller: _supervisorTitleController,
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(
                bottom: 16.0,
                top: 16.0,
              ),
              child: Text('Terms and conditions',
                  softWrap: true,
                  overflow: TextOverflow.fade,
                  style: TextStyle(
                      color: blueColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w500)),
            ),
            Padding(
              padding: const EdgeInsets.only(
                bottom: 16.0,
                top: 16.0,
              ),
              child: Text(
                  '''I understand that this is a routine application to establish credit, character, employment, and rental history. I also understand that this is NOT an agreement to rent and that all applications must be approved. I authorize verification of references given. I declare that the statements above are true and correct, and I agree that the Rental owner may terminate my agreement entered into in reliance on any misstatement made above.''',
                  softWrap: true,
                  overflow: TextOverflow.fade,
                  style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 16,
                      fontWeight: FontWeight.w500)),
            ),

            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Checkbox(value: checked,    onChanged: (value) {
                  setState(() {
                    checked = value!;
                    isCheckboxError = !checked; // Update error state dynamically
                  });
                }),
                Padding(
                  padding: const EdgeInsets.only(
                    left: 4.0,
                  ),
                  child: Text('Agreed to*',
                      softWrap: true,
                      overflow: TextOverflow.fade,
                      style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 16,
                          fontWeight: FontWeight.w400)),
                ),
              ],
            ),
            if (isCheckboxError)
              Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: Text(
                  'You must agree to the terms and conditions.',
                  style: TextStyle(color: Colors.red, fontSize: 14),
                ),
              ),
            const SizedBox(
              height: 5,
            ),
            Padding(
              padding: const EdgeInsets.only(
                left: 4.0,
              ),
              child: Text('Agreed by',
                  softWrap: true,
                  overflow: TextOverflow.fade,
                  style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 16,
                      fontWeight: FontWeight.w600)),
            ),
            const SizedBox(
              height: 10,
            ),
            NewCustomTextField(
              hintText: 'Agreed by...',
              controller: _agreeByController,
            ),
            Padding(
              padding: const EdgeInsets.only(
                bottom: 16.0,
                top: 16.0,
              ),
              child: RichText(
                  text: TextSpan(children: [
                    TextSpan(
                        text:
                        'By submitting this application, I (1) am giving permission to run a background check on me, which may include obtaining my credit report from a consumer reporting agency; and (2) agreeing to the ',
                        style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 16,
                            fontWeight: FontWeight.w500)),
                    TextSpan(
                        text: 'Privacy Policy',
                        style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                            fontWeight: FontWeight.w500)),
                    TextSpan(
                        text: ' and ',
                        style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 16,
                            fontWeight: FontWeight.w500)),
                    TextSpan(
                        text: 'Terms of Service.',
                        style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                            fontWeight: FontWeight.w500)),
                  ])),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: blueColor),
              onPressed: () async {
                setState(() {
                  isCheckboxError = !checked; // Validate checkbox when submitting
                });
                if (_formEditKey.currentState!.validate()) {
                  SharedPreferences prefs =
                  await SharedPreferences.getInstance();
                  String? adminId = prefs.getString('adminId');
                  // printAllFields();
                  Data data = Data(
                    emergencyContact: EmergencyContact(
                      firstName: _emergencyFirstNameController.text,
                      lastName: _emergencyLastNameController.text,
                      relationship: _emergencyRelationshipController.text,
                      email: _emergencyEmailController.text,
                      phoneNumber:
                     _emergencyPhoneNumberController.text,
                    ),
                    rentalHistory: RentalHistory(
                      rentalAdress: _rentalAddressController.text,
                      rentalCity: _rentalCityController.text,
                      rentalState: _rentalStateController.text,
                      rentalCountry: _rentalCountryController.text,
                      rentalPostcode: _rentalPostcodeController.text,
                      rentalOwnerFirstName:
                      _rentalOwnerFirstNameController.text,
                      rentalOwnerLastName: _rentalOwnerLastNameController.text,
                      startDate: _startDateController.text,
                      endDate: _endDateController.text,
                      rent: _rentController.text,
                      leavingReason: _leavingReasonController.text,
                      rentalOwnerPrimaryEmail: _rentalOwnerEmailController.text,
                      rentalOwnerPhoneNumber:
                     _rentalOwnerPhoneNumberController.text,
                    ),
                    employment: Employment(
                      name: _employmentNameController.text,
                      streetAddress: _employmentStreetAddressController.text,
                      city: _employmentCityController.text,
                      state: _employmentStateController.text,
                      country: _employmentCountryController.text,
                      postalCode: _employmentPostalCodeController.text,
                      employmentPrimaryEmail:
                      _employmentPrimaryEmailController.text,
                      employmentPhoneNumber:
                     _employmentPhoneNumberController.text,
                      employmentPosition: _employmentPositionController.text,
                      supervisorFirstName: _supervisorFirstNameController.text,
                      supervisorLastName: _supervisorLastNameController.text,
                      supervisorTitle: _supervisorTitleController.text,
                    ),

                    applicantId: widget
                        .applicantId, // Assuming this value is not set from a controller
                    adminId:
                    adminId, // Assuming this value is not set from a controller
                    applicantStreetAddress:
                    _applicantStreetAddressController.text,
                    applicantCity: _applicantCityController.text,
                    applicantState: _applicantStateController.text,
                    applicantCountry: _applicantCountryController.text,
                    applicantPostalCode: _applicantPostalCodeController.text,
                    agreeBy: _agreeByController.text,

                    applicantFirstName: _applicantFirstNameController.text,
                    applicantLastName: _applicantLastNameController.text,
                    applicantEmail: _applicantEmailController.text,
                    applicantPhoneNumber: _applicantPhoneNumberController.text,
                    isApplicantDataEmpty: false, // Default value
                  );
                  ApplicantSummeryRepository applicantSummeryRepository =
                  ApplicantSummeryRepository();
                  bool success = await applicantSummeryRepository
                      .editApplicantSummaryForm(data, widget.applicantId);
                  if (success == true) {
                    Navigator.pop(context);
                    editFormState.setEditForm(!editFormState.showEditForm);
                  } else {
                  }
                } else {
                  if (!checked) {
                    // Fluttertoast.showToast(
                    //     msg: 'You must agree to the terms and conditions.');
                  }
                  setState(() {}); // Rebuild to show the error message
                }
              },
              child: const Text('Save Applicant'),
            ),
          ],
        ),
      ),
    );
  }
}



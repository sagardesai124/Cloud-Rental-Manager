import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// import 'package:flutter/widgets.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:three_zero_two_property/Model/applicant_summery_model.dart';
import 'package:three_zero_two_property/constant/constant.dart';
import 'package:three_zero_two_property/provider/dateProvider.dart';
import 'package:three_zero_two_property/provider/editapplicationsummaryForm.dart';
import '../../../../repository/applicant_summery_repo.dart';
import 'SummaryEditApplicant.dart';
import 'package:three_zero_two_property/widgets/application_details_view.dart';
import 'package:three_zero_two_property/widgets/application_edit_form.dart';
import 'package:three_zero_two_property/screens/Leasing/Applicants/editApplicant.dart';
import 'package:three_zero_two_property/widgets/CustomDateField.dart';
import 'package:three_zero_two_property/widgets/CustomEmailField.dart';
import 'package:three_zero_two_property/widgets/CustomTextField.dart';

class ApplicantContent extends StatefulWidget {
  final String applicant_id;
  applicant_summery_details applicantDetail;
  ApplicantContent({required this.applicant_id, required this.applicantDetail});

  @override
  State<ApplicantContent> createState() => _ApplicantContentState();
}

class _ApplicantContentState extends State<ApplicantContent> {
  bool checked = false;
  bool showEditForm = false;
  final _formKey = GlobalKey<FormState>();
  final _formEditKey = GlobalKey<FormState>();

  // Controllers for each input field

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

  late Future<ApplicantContentDetails> futureApplicantDetails;
  bool showAddForm = false;

  @override
  void initState() {
    super.initState();
    futureApplicantDetails =
        ApplicantSummeryRepository().fetchApplicantDetails(widget.applicant_id);
    fetchApplicantInForm();
  }

  void fetchApplicantInForm() {
    // Delayed execution to set the values after 1 second
    Future.delayed(const Duration(seconds: 1), () {
      setState(() {
        _applicantFirstNameController.text =
            widget.applicantDetail.applicantFirstName ?? '';
        _applicantLastNameController.text =
            widget.applicantDetail.applicantLastName ?? '';
        _applicantEmailController.text =
            widget.applicantDetail.applicantEmail ?? '';
        _applicantPhoneNumberController.text =
            widget.applicantDetail.applicantPhoneNumber ?? '';
      });
    });
  }
  bool isCheckboxError = false;
  @override
  Widget build(BuildContext context) {
    final editFormState = Provider.of<EditFormState>(context);
    double screenHeight = MediaQuery.of(context).size.height;
    double screenWidth = MediaQuery.of(context).size.width;
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: FutureBuilder<ApplicantContentDetails>(
        future: futureApplicantDetails,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Padding(
              padding: const EdgeInsets.only(top: 200),
              child: Center(
                  child: SpinKitSpinningLines(
                color: blueColor,
                size: 40.0,
              )),
            );
          } else if (snapshot.hasError) {
            return Center(child: Text(friendlyErrorMessage(snapshot.error), textAlign: TextAlign.center));
          } else if (snapshot.hasData) {
            var data = snapshot.data!.data;


            // Web-parity "Enter Applicant Details" form (edit + manual-entry
            // add). Replaces the legacy inline form for both flows.
            if (showEditForm || showAddForm) {
              return SingleChildScrollView(
                child: ApplicationEditForm(
                  raw: snapshot.data!.raw ?? const {},
                  applicantId: widget.applicant_id,
                  dateFormat:
                      Provider.of<DateProvider>(context, listen: false)
                          .dateFormat,
                  onSave: (payload) => ApplicantSummeryRepository()
                      .saveApplicationRaw(payload, widget.applicant_id),
                  onCancel: () => setState(() {
                    showEditForm = false;
                    showAddForm = false;
                  }),
                  // Web parity: after a successful save, return to the
                  // Applicants table (it refetches on return).
                  onSaved: () {
                    showEditForm = false;
                    showAddForm = false;
                    Navigator.of(context).pop();
                  },
                ),
              );
            }

            // Web-parity Application tab (read view): when application data
            // exists, render the new-schema sections. The legacy display
            // below is bypassed (kept for reference); the empty-state, add
            // form and both edit-form flows continue to use the original
            // branches untouched.
            if (data!.isApplicantDataEmpty != true &&
                !editFormState.showEditForm &&
                !showEditForm) {
              final dateProvider =
                  Provider.of<DateProvider>(context, listen: false);
              return SingleChildScrollView(
                child: ApplicationDetailsView(
                  raw: snapshot.data!.raw ?? const {},
                  dateFormat: dateProvider.dateFormat,
                  onEdit: () {
                    setState(() {
                      showEditForm = true;
                    });
                  },
                ),
              );
            }

            return SingleChildScrollView(
              child: data!.isApplicantDataEmpty == true
                  ? showAddForm == true
                      ? Container(
                          child: Form(
                            key: _formKey,
                            child:
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                  MainAxisAlignment.spaceEvenly,
                                  children: [
                                    Expanded(
                                      child: Text('Enter Applicant Details',
                                          softWrap: true,
                                          overflow: TextOverflow.fade,
                                          style: TextStyle(
                                              color: blueColor,
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold)),
                                    ),
                                    GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          showAddForm = false;
                                        });
                                      },
                                      child: Container(
                                        child: Material(
                                          borderRadius:
                                          BorderRadius.circular(4.0),
                                          elevation: 4,
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: blueColor,
                                              borderRadius:
                                              BorderRadius.circular(4),
                                              border:
                                              Border.all(color: blueColor),
                                            ),
                                            child: const Padding(
                                              padding: EdgeInsets.all(8.0),
                                              child: Text(
                                                'Cancel',
                                                style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 15,
                                                    fontWeight:
                                                    FontWeight.bold),
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
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: blueColor),
                                ),
                                const SizedBox(
                                  height: 8,
                                ),
                                Container(
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                      border: Border.all(
                                        color: blueColor,
                                      ),
                                      borderRadius:
                                      BorderRadius.circular(10.0)),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Column(
                                      crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'First name',
                                          style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: blueColor),
                                        ),
                                        const SizedBox(
                                          height: 5,
                                        ),
                                        NewCustomTextField(
                                          hintText: 'First Name',
                                          controller:
                                          _applicantFirstNameController,
                                          keyboardType: TextInputType.text,
                                          validator: (value) {
                                            if (value == null ||
                                                value.isEmpty) {
                                              return 'Please enter first name';
                                            }

                                            return null;
                                          },
                                        ),
                                        const SizedBox(
                                          height: 12,
                                        ),
                                        Text(
                                          'Last Name',
                                          style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: blueColor),
                                        ),
                                        const SizedBox(
                                          height: 5,
                                        ),
                                        NewCustomTextField(
                                          hintText: 'Last Name',
                                          controller:
                                          _applicantLastNameController,
                                          validator: (value) {
                                            if (value == null ||
                                                value.isEmpty) {
                                              return 'Please enter last name';
                                            }

                                            return null;
                                          },
                                        ),
                                        const SizedBox(
                                          height: 12,
                                        ),
                                        Text(
                                          'Birth Date',
                                          style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: blueColor),
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
                                          'Email ',
                                          style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: blueColor),
                                        ),
                                        const SizedBox(
                                          height: 5,
                                        ),
                                        NewCustomTextField(
                                          hintText: 'Enter your email',
                                          email: true,
                                          alterController: _emergencyEmailController,
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
                                              fontWeight: FontWeight.bold,
                                              color: blueColor),
                                        ),
                                        const SizedBox(
                                          height: 5,
                                        ),
                                        NewCustomTextField(
                                          hintText: 'Phone Number',
                                          otherController: _emergencyPhoneNumberController,

                                          controller:
                                          _applicantPhoneNumberController,
                                          keyboardType: TextInputType.number,
                                          inputFormatters: [
                                            FilteringTextInputFormatter.digitsOnly,
                                            LengthLimitingTextInputFormatter(10),
                                            PhoneNumberFormatter(),
                                          ],
                                          validator: (value) {
                                            if (value == null ||
                                                value.isEmpty) {
                                              return 'Please enter phone number';
                                            }

                                            return null;
                                          },
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
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: blueColor),
                                ),
                                const SizedBox(
                                  height: 5,
                                ),
                                Container(
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: blueColor,
                                    ),
                                    borderRadius: BorderRadius.circular(10.0),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Column(
                                      crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Street Address',
                                          style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: blueColor),
                                        ),
                                        const SizedBox(
                                          height: 5,
                                        ),
                                        NewCustomTextField(
                                          optional: true,
                                          hintText: 'Street Address',
                                          controller:
                                          _applicantStreetAddressController,
                                        ),
                                        const SizedBox(
                                          height: 12,
                                        ),
                                        Text(
                                          'City',
                                          style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: blueColor),
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
                                              fontWeight: FontWeight.bold,
                                              color: blueColor),
                                        ),
                                        const SizedBox(
                                          height: 5,
                                        ),
                                        NewCustomTextField(
                                          optional: true,
                                          hintText: 'State',
                                          controller: _applicantStateController,
                                        ),
                                        const SizedBox(
                                          height: 12,
                                        ),
                                        Text(
                                          'Country',
                                          style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: blueColor),
                                        ),
                                        const SizedBox(
                                          height: 5,
                                        ),
                                        NewCustomTextField(
                                          optional: true,
                                          hintText: 'Country',
                                          controller:
                                          _applicantCountryController,
                                        ),
                                        const SizedBox(
                                          height: 12,
                                        ),
                                        Text(
                                          'Postal Code',
                                          style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: blueColor),
                                        ),
                                        const SizedBox(
                                          height: 5,
                                        ),
                                        NewCustomTextField(
                                          optional: true,
                                          hintText: 'Postal Code',
                                          controller:
                                          _applicantPostalCodeController,
                                          keyboardType: TextInputType.number,
                                          inputFormatters: [
                                            FilteringTextInputFormatter.digitsOnly,
                                          ],
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
                                    fontWeight: FontWeight.bold,
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
                                      color: blueColor,
                                    ),
                                    borderRadius: BorderRadius.circular(10.0),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Column(
                                      crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'First Name',
                                          style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: blueColor
                                          ),
                                        ),
                                        const SizedBox(
                                          height: 5,
                                        ),
                                        NewCustomTextField(
                                          optional: true,
                                          hintText: 'First Name',
                                          controller:
                                          _emergencyFirstNameController,
                                        ),
                                        const SizedBox(
                                          height: 12,
                                        ),
                                        Text(
                                          'Last Name',
                                          style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: blueColor
                                          ),
                                        ),
                                        const SizedBox(
                                          height: 5,
                                        ),
                                        NewCustomTextField(
                                          optional: true,
                                          hintText: 'Last Name',
                                          controller:
                                          _emergencyLastNameController,
                                        ),
                                        const SizedBox(
                                          height: 12,
                                        ),
                                        Text(
                                          'Relationship',
                                          style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: blueColor
                                          ),
                                        ),
                                        const SizedBox(
                                          height: 5,
                                        ),
                                        NewCustomTextField(
                                          optional: true,
                                          hintText: 'Relationship',
                                          controller:
                                          _emergencyRelationshipController,
                                        ),
                                        const SizedBox(
                                          height: 12,
                                        ),
                                        Text(
                                          'Email',
                                          style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: blueColor
                                          ),
                                        ),
                                        const SizedBox(
                                          height: 5,
                                        ),
                                        NewCustomTextField(
                                          hintText: 'Email',
                                          optional: true,
                                          email: true,
                                          alterController: _applicantEmailController,
                                          controller: _emergencyEmailController,
                                        ),
                                        const SizedBox(
                                          height: 12,
                                        ),
                                        Text(
                                          'Phone Number',
                                          style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: blueColor
                                          ),
                                        ),
                                        const SizedBox(
                                          height: 5,
                                        ),
                                        NewCustomTextField(
                                          keyboardType: TextInputType.number,
                                          inputFormatters: [
                                            FilteringTextInputFormatter.digitsOnly,
                                            LengthLimitingTextInputFormatter(10),
                                            PhoneNumberFormatter(),
                                          ],
                                          phone: true,
                                          optional: true,
                                          otherController: _applicantPhoneNumberController,
                                          hintText: 'Phone Number',
                                          controller:
                                          _emergencyPhoneNumberController,
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
                                  'Rental historys',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
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
                                      color: blueColor,
                                    ),
                                    borderRadius: BorderRadius.circular(10.0),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Column(
                                      crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Rental Address',
                                          style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: blueColor
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
                                              fontWeight: FontWeight.bold,
                                              color: blueColor
                                          ),
                                        ),
                                        const SizedBox(
                                          height: 5,
                                        ),
                                        NewCustomTextField(
                                          optional: true,
                                          hintText: 'City',
                                          controller: _rentalCityController,
                                        ),
                                        const SizedBox(
                                          height: 12,
                                        ),
                                        Text(
                                          'State',
                                          style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: blueColor
                                          ),
                                        ),
                                        const SizedBox(
                                          height: 5,
                                        ),
                                        NewCustomTextField(
                                          optional: true,
                                          hintText: 'State',
                                          controller: _rentalStateController,
                                        ),
                                        const SizedBox(
                                          height: 12,
                                        ),
                                        Text(
                                          'Country',
                                          style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: blueColor
                                          ),
                                        ),
                                        const SizedBox(
                                          height: 5,
                                        ),
                                        NewCustomTextField(
                                          hintText: 'Country',
                                          optional: true,
                                          controller: _rentalCountryController,
                                        ),
                                        const SizedBox(
                                          height: 12,
                                        ),
                                        Text(
                                          'Postcode',
                                          style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: blueColor
                                          ),
                                        ),
                                        const SizedBox(
                                          height: 5,
                                        ),
                                        NewCustomTextField(
                                          optional: true,
                                          hintText: 'Postcode',
                                          controller: _rentalPostcodeController,
                                          keyboardType: TextInputType.number,
                                          inputFormatters: [
                                            FilteringTextInputFormatter.digitsOnly,
                                          ],
                                        ),
                                        const SizedBox(
                                          height: 12,
                                        ),
                                        Text(
                                          'Start Date',
                                          style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: blueColor
                                          ),
                                        ),
                                        const SizedBox(
                                          height: 5,
                                        ),
                                        NewCustomTextField(
                                          hintText: 'Start Date',
                                          optional: true,
                                          controller: _startDateController,
                                        ),
                                        const SizedBox(
                                          height: 12,
                                        ),
                                        Text(
                                          'End Date',
                                          style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: blueColor
                                          ),
                                        ),
                                        const SizedBox(
                                          height: 5,
                                        ),
                                        NewCustomTextField(
                                          hintText: 'End Date',
                                          optional: true,
                                          controller: _endDateController,
                                        ),
                                        const SizedBox(
                                          height: 12,
                                        ),
                                        Text(
                                          'Rent Amount',
                                          style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: blueColor
                                          ),
                                        ),
                                        const SizedBox(
                                          height: 5,
                                        ),
                                        NewCustomTextField(
                                          hintText: 'Rent Amount',
                                          optional: true,
                                          controller: _rentController,
                                        ),
                                        const SizedBox(
                                          height: 12,
                                        ),
                                        Text(
                                          'Reason for Leaving',
                                          style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: blueColor
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
                                    fontWeight: FontWeight.bold,
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
                                      color: blueColor,
                                    ),
                                    borderRadius: BorderRadius.circular(10.0),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Column(
                                      crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'First Name',
                                          style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: blueColor
                                          ),
                                        ),
                                        const SizedBox(
                                          height: 5,
                                        ),
                                        NewCustomTextField(
                                          optional: true,
                                          hintText: 'First Name',
                                          controller:
                                          _rentalOwnerFirstNameController,
                                        ),
                                        const SizedBox(
                                          height: 12,
                                        ),
                                        Text(
                                          'Last Name',
                                          style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: blueColor
                                          ),
                                        ),
                                        const SizedBox(
                                          height: 5,
                                        ),
                                        NewCustomTextField(
                                          optional: true,
                                          hintText: 'Last Name',
                                          controller:
                                          _rentalOwnerLastNameController,
                                        ),
                                        const SizedBox(
                                          height: 12,
                                        ),
                                        Text(
                                          'Email',
                                          style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: blueColor
                                          ),
                                        ),
                                        const SizedBox(
                                          height: 5,
                                        ),
                                        NewCustomTextField(
                                          optional: true,
                                          hintText: 'Email',
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
                                              fontWeight: FontWeight.bold,
                                              color: blueColor
                                          ),
                                        ),
                                        const SizedBox(
                                          height: 5,
                                        ),
                                        NewCustomTextField(
                                          optional: true,
                                          hintText: 'Phone Number',
                                          keyboardType: TextInputType.number,
                                          inputFormatters: [
                                            FilteringTextInputFormatter.digitsOnly,
                                            LengthLimitingTextInputFormatter(10),
                                            PhoneNumberFormatter(),
                                          ],
                                          phone: true,
                                          otherController: _emergencyPhoneNumberController,
                                          businessController: _applicantPhoneNumberController,
                                          controller:
                                          _rentalOwnerPhoneNumberController,
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
                                    fontWeight: FontWeight.bold,
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
                                      color: blueColor,
                                    ),
                                    borderRadius: BorderRadius.circular(10.0),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Column(
                                      crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Company Name',
                                          style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: blueColor
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
                                              fontWeight: FontWeight.bold,
                                              color: blueColor
                                          ),
                                        ),
                                        const SizedBox(
                                          height: 5,
                                        ),
                                        NewCustomTextField(
                                          hintText: 'Street Address',
                                          optional: true,
                                          controller:
                                          _employmentStreetAddressController,
                                        ),
                                        const SizedBox(
                                          height: 12,
                                        ),
                                        Text(
                                          'City',
                                          style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: blueColor
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
                                              fontWeight: FontWeight.bold,
                                              color: blueColor
                                          ),
                                        ),
                                        const SizedBox(
                                          height: 5,
                                        ),
                                        NewCustomTextField(
                                          hintText: 'State',
                                          optional: true,
                                          controller:
                                          _employmentStateController,
                                        ),
                                        const SizedBox(
                                          height: 12,
                                        ),
                                        Text(
                                          'Country',
                                          style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: blueColor
                                          ),
                                        ),
                                        const SizedBox(
                                          height: 5,
                                        ),
                                        NewCustomTextField(
                                          hintText: 'Country',
                                          optional: true,
                                          controller:
                                          _employmentCountryController,
                                        ),
                                        const SizedBox(
                                          height: 12,
                                        ),
                                        Text(
                                          'Postal Code',
                                          style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: blueColor
                                          ),
                                        ),
                                        const SizedBox(
                                          height: 5,
                                        ),
                                        NewCustomTextField(
                                          hintText: 'Postal Code',
                                          optional: true,
                                          controller:
                                          _employmentPostalCodeController,
                                          keyboardType: TextInputType.number,
                                          inputFormatters: [
                                            FilteringTextInputFormatter.digitsOnly,
                                          ],
                                        ),
                                        const SizedBox(
                                          height: 12,
                                        ),
                                        Text(
                                          'Primary Email',
                                          style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: blueColor
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
                                          controller:
                                          _employmentPrimaryEmailController,
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
                                              fontWeight: FontWeight.bold,
                                              color: blueColor
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
                                            FilteringTextInputFormatter.digitsOnly,
                                            LengthLimitingTextInputFormatter(10),
                                            PhoneNumberFormatter(),
                                          ],
                                          otherController: _rentalOwnerPhoneNumberController,
                                          businessController: _emergencyPhoneNumberController,
                                          telephoneController: _applicantPhoneNumberController,
                                          controller:
                                          _employmentPhoneNumberController,
                                        ),
                                        const SizedBox(
                                          height: 12,
                                        ),
                                        Text(
                                          'Position',
                                          style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: blueColor
                                          ),
                                        ),
                                        const SizedBox(
                                          height: 5,
                                        ),
                                        NewCustomTextField(
                                          hintText: 'Position',
                                          optional: true,
                                          controller:
                                          _employmentPositionController,
                                        ),
                                        const SizedBox(
                                          height: 12,
                                        ),
                                        Text(
                                          'Supervisor First Name',
                                          style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: blueColor
                                          ),
                                        ),
                                        const SizedBox(
                                          height: 5,
                                        ),
                                        NewCustomTextField(
                                          hintText: 'Supervisor First Name',
                                          optional: true,
                                          controller:
                                          _supervisorFirstNameController,
                                        ),
                                        const SizedBox(
                                          height: 12,
                                        ),
                                        Text(
                                          'Supervisor Last Name',
                                          style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: blueColor
                                          ),
                                        ),
                                        const SizedBox(
                                          height: 5,
                                        ),
                                        NewCustomTextField(
                                          hintText: 'Supervisor Last Name',
                                          optional: true,
                                          controller:
                                          _supervisorLastNameController,
                                        ),
                                        const SizedBox(
                                          height: 12,
                                        ),
                                        Text(
                                          'Supervisor Title',
                                          style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: blueColor
                                          ),
                                        ),
                                        const SizedBox(
                                          height: 5,
                                        ),
                                        NewCustomTextField(
                                          hintText: 'Supervisor Title',
                                          optional: true,
                                          controller:
                                          _supervisorTitleController,
                                        ),
                                        const SizedBox(height: 16),
                                      ],
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(

                                    bottom: 17.0,
                                    left: 8,
                                    right: 8,
                                    top: 16.0,
                                  ),
                                  child: Text('Terms and conditions',
                                      softWrap: true,
                                      overflow: TextOverflow.fade,
                                      style: TextStyle(
                                          color: blueColor,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold)),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: 16.0,
                                    top: 16.0,
                                    left: 8,
                                    right: 8,
                                  ),
                                  child: Text(
                                      '''I understand that this is a routine application to establish credit, character, employment, and rental history. I also understand that this is NOT an agreement to rent and that all applications must be approved. I authorize verification of references given. I declare that the statements above are true and correct, and I agree that the Rental owner may terminate my agreement entered into in reliance on any misstatement made above.''',
                                      softWrap: true,
                                      textAlign: TextAlign.justify,
                                      overflow: TextOverflow.fade,
                                      style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500)),
                                ),

                                Row(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    Checkbox(
                                        value: checked,
                                        onChanged: (value) {
                                          setState(() {
                                            checked = value!;
                                            isCheckboxError = !checked; // Update error state dynamically
                                          });
                                        }),

                                    Padding(
                                      padding: const EdgeInsets.only(

                                        left: 8,
                                        right: 8,
                                      ),
                                      child: Text('Agreed to**',
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
                                  const Padding(
                                    padding: EdgeInsets.only(left: 8.0),
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
                                    left: 10,
                                    right: 10,
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
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: NewCustomTextField(
                                    hintText: 'Agreed by...',
                                    controller: _agreeByController,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(
                                    left: 8,
                                    right: 8,
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
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: blueColor),
                                    onPressed: () async {
                                      setState(() {
                                        isCheckboxError = !checked; // Validate checkbox when submitting
                                      });
                                      if (_formKey.currentState!.validate() && checked) {
                                        SharedPreferences prefs =
                                        await SharedPreferences.getInstance();
                                        String? adminId =
                                        prefs.getString('adminId');
                                        // printAllFields();
                                        Data data = Data(
                                          emergencyContact: EmergencyContact(
                                            firstName:
                                            _emergencyFirstNameController
                                                .text.trim(),
                                            lastName:
                                            _emergencyLastNameController.text.trim(),
                                            relationship:
                                            _emergencyRelationshipController
                                                .text.trim(),
                                            email: _emergencyEmailController.text.trim(),
                                            phoneNumber:
                                                _emergencyPhoneNumberController
                                                    .text.trim(),
                                          ),
                                          rentalHistory: RentalHistory(
                                            rentalAdress:
                                            _rentalAddressController.text.trim(),
                                            rentalCity:
                                            _rentalCityController.text.trim(),
                                            rentalState:
                                            _rentalStateController.text.trim(),
                                            rentalCountry:
                                            _rentalCountryController.text.trim(),
                                            rentalPostcode:
                                            _rentalPostcodeController.text.trim(),
                                            rentalOwnerFirstName:
                                            _rentalOwnerFirstNameController
                                                .text.trim(),
                                            rentalOwnerLastName:
                                            _rentalOwnerLastNameController
                                                .text.trim(),
                                            startDate: _startDateController.text.trim(),
                                            endDate: _endDateController.text.trim(),
                                            rent: _rentController.text.trim(),
                                            leavingReason:
                                            _leavingReasonController.text.trim(),
                                            rentalOwnerPrimaryEmail:
                                            _rentalOwnerEmailController.text.trim(),
                                            rentalOwnerPhoneNumber:
                                                _rentalOwnerPhoneNumberController
                                                    .text.trim(),
                                          ),
                                          employment: Employment(
                                            name: _employmentNameController.text.trim(),
                                            streetAddress:
                                            _employmentStreetAddressController
                                                .text.trim(),
                                            city: _employmentCityController.text.trim(),
                                            state:
                                            _employmentStateController.text.trim(),
                                            country:
                                            _employmentCountryController.text.trim(),
                                            postalCode:
                                            _employmentPostalCodeController
                                                .text.trim(),
                                            employmentPrimaryEmail:
                                            _employmentPrimaryEmailController
                                                .text.trim(),
                                            employmentPhoneNumber:
                                                _employmentPhoneNumberController
                                                    .text.trim(),
                                            employmentPosition:
                                            _employmentPositionController
                                                .text.trim(),
                                            supervisorFirstName:
                                            _supervisorFirstNameController
                                                .text.trim(),
                                            supervisorLastName:
                                            _supervisorLastNameController
                                                .text.trim(),
                                            supervisorTitle:
                                            _supervisorTitleController.text.trim(),
                                          ),

                                          applicantId: widget.applicantDetail
                                              .applicantId, // Assuming this value is not set from a controller
                                          adminId:
                                          adminId, // Assuming this value is not set from a controller
                                          applicantStreetAddress:
                                          _applicantStreetAddressController
                                              .text.trim(),
                                          applicantCity:
                                          _applicantCityController.text.trim(),
                                          applicantState:
                                          _applicantStateController.text.trim(),
                                          applicantCountry:
                                          _applicantCountryController.text.trim(),
                                          applicantPostalCode:
                                          _applicantPostalCodeController.text.trim(),
                                          agreeBy: _agreeByController.text.trim(),

                                          applicantFirstName:
                                          _applicantFirstNameController.text.trim(),
                                          applicantLastName:
                                          _applicantLastNameController.text.trim(),
                                          applicantEmail:
                                          _applicantEmailController.text.trim(),
                                          applicantPhoneNumber:
                                          _applicantPhoneNumberController
                                              .text.trim(),
                                          isApplicantDataEmpty:
                                          false, // Default value
                                        );
                                        ApplicantSummeryRepository
                                        applicantSummeryRepository =
                                        ApplicantSummeryRepository();
                                        bool success =
                                        await ApplicantSummeryRepository()
                                            .addApplicantSummaryForm(
                                            data, widget.applicant_id);
                                        if (success == true) {
                                          Fluttertoast.showToast(
                                              msg:
                                              'Applicant Added Successfully');
                                        }
                                        // No failure toast here: addApplicantSummaryForm already raises the
                                        // server's own reason, which is the only place that text exists. A
                                        // generic 'Failed to add applicant' on top of it put two messages on
                                        // screen for one tap, the second contradicting the first. The repo
                                        // owns failure, this screen owns success - the split its comment
                                        // already describes.
                                      } else {
                                        if (!checked) {
                                          // Fluttertoast.showToast(
                                          //     msg: 'You must agree to the terms and conditions.');
                                        }
                                        setState(
                                                () {}); // Rebuild to show the error message
                                      }
                                    },
                                    child: const Text('Save Applicantt',style: TextStyle(fontWeight: FontWeight.bold),),
                                  ),
                                ),

                              ],
                            ),
                          ),
                        )
                      : Container(
                          child: screenWidth > 500
                              ? Column(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 16.0,
                                        top: 16.0,
                                      ),
                                      child: Text(
                                          'A rental application is not associated with the applicant. A link to the online rental application can be either emailed directly to the applicant for completion or the application details can be entered manually.',
                                          softWrap: true,
                                          overflow: TextOverflow.fade,
                                          style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 15,
                                              fontWeight: FontWeight.w500)),
                                    ),
                                    const SizedBox(
                                      height: 18,
                                    ),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Container(
                                            width: double.infinity,
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                  color: blueColor),
                                            ),
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 12,
                                                      horizontal: 8),
                                              child: Text(
                                                'Email link to online rental application',
                                                style: TextStyle(
                                                    color: blueColor,
                                                    fontSize: 15,
                                                    fontWeight:
                                                        FontWeight.w500),
                                                textAlign: TextAlign.center,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(
                                          width: 10,
                                        ),
                                        Expanded(
                                          child: GestureDetector(
                                            onTap: () {
                                              setState(() {
                                                showAddForm = true;
                                              });
                                            },
                                            child: Container(
                                              width: double.infinity,
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                border: Border.all(
                                                    color: blueColor),
                                              ),
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        vertical: 12,
                                                        horizontal: 8),
                                                child: Text(
                                                  'Manually enter application details',
                                                  style: TextStyle(
                                                      color: blueColor,
                                                      fontSize: 15,
                                                      fontWeight:
                                                          FontWeight.w500),
                                                  textAlign: TextAlign.center,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(
                                      height: 18,
                                    ),
                                  ],
                                )
                              : Column(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 16.0,
                                        top: 16.0,
                                      ),
                                      child: Text(
                                          'A rental application is not associated with the applicant. A link to the online rental application can be either emailed directly to the applicant for completion or the application details can be entered manually.',
                                          softWrap: true,
                                          overflow: TextOverflow.fade,
                                          style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 15,
                                              fontWeight: FontWeight.w500)),
                                    ),
                                    GestureDetector(
                                      onTap: () async {
                                        ApplicantSummeryRepository
                                            applicantsummeryRepository =
                                            ApplicantSummeryRepository();
                                        int reponse =
                                            await applicantsummeryRepository
                                                .sendMail(widget.applicant_id);
                                        if (reponse == 200) {
                                          Fluttertoast.showToast(
                                              msg: 'Mail Send Successfully');
                                        } else {
                                          Fluttertoast.showToast(
                                              msg:
                                                  'Failed to send mail try again later');
                                        }
                                      },
                                      child: Container(
                                        width: double.infinity,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                              color: blueColor),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 12, horizontal: 8),
                                          child: Text(
                                            'Email link to online rental application',
                                            style: TextStyle(
                                                color: blueColor,
                                                fontSize: 15,
                                                fontWeight: FontWeight.w500),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(
                                      height: 18,
                                    ),
                                    GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          showAddForm = true;
                                        });
                                      },
                                      child: Container(
                                        width: double.infinity,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                              color: blueColor),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 12, horizontal: 8),
                                          child: Text(
                                            'Manually enter application details',
                                            style: TextStyle(
                                                color: blueColor,
                                                fontSize: 15,
                                                fontWeight: FontWeight.w500),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                        )
                  : editFormState.showEditForm
                      ? EditApplicantSummary(
                          applicantId: widget.applicant_id,
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            data!.rentalHistory != null
                                ? Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.all(0.0),
                                        child: Material(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              border: Border.all(
                                                  color: blueColor


),
                                            ),
                                            child: Padding(
                                              padding: const EdgeInsets.only(
                                                  left: 16,
                                                  right: 16,
                                                  top: 16,
                                                  bottom: 16),
                                              child: Column(
                                                children: [
                                                  Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceBetween,
                                                    children: [
                                                      Flexible(
                                                        flex: 3,
                                                        child: Container(
                                                          child: Text(
                                                            "Applicant Information",
                                                            style: TextStyle(
                                                                color: const Color
                                                                    .fromRGBO(
                                                                    21,
                                                                    43,
                                                                    81,
                                                                    1),
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                fontSize: MediaQuery.of(
                                                                            context)
                                                                        .size
                                                                        .width *
                                                                    .045),
                                                          ),
                                                        ),
                                                      ),
                                                      Flexible(
                                                        child: ElevatedButton(
                                                          onPressed: () {
                                                            editFormState
                                                                .setEditForm(
                                                                    true);
                                                            // setState(() {
                                                            //   showEditForm =
                                                            //       true;
                                                            // });
                                                          },
                                                          child: Text(
                                                            "Edit", // Updated text to differentiate from the first one
                                                            style: TextStyle(
                                                                color: Colors
                                                                    .white,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                fontSize: MediaQuery.of(
                                                                            context)
                                                                        .size
                                                                        .width *
                                                                    .045),
                                                          ),
                                                          style: ElevatedButton
                                                              .styleFrom(
                                                                  // Button color
                                                                  backgroundColor:
                                                                      blueColor),
                                                        ),
                                                      ),
                                                    ],
                                                  ),

                                                  const SizedBox(
                                                    height: 10,
                                                  ),
                                                  // Unit ID
                                                  const Row(
                                                    children: [
                                                      SizedBox(
                                                        width: 2,
                                                      ),
                                                      Text(
                                                        "Applicant Name",
                                                        style: TextStyle(
                                                            color: Color(
                                                                0xFF8A95A8),
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 12),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(
                                                    height: 5,
                                                  ),
                                                  Row(
                                                    children: [
                                                      const SizedBox(width: 2),
                                                      Text(
                                                        '${(data.applicantFirstName ?? '').isEmpty ? 'N/A' : data.applicantFirstName} ${(data.applicantLastName ?? '').isEmpty ? 'N/A' : data.applicantLastName}',
                                                        style:  TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: blueColor


,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 2),
                                                    ],
                                                  ),
                                                  const SizedBox(
                                                    height: 18,
                                                  ),
// Applicant Birth Date
                                                  const Row(
                                                    children: [
                                                      SizedBox(
                                                        width: 2,
                                                      ),
                                                      Text(
                                                        "Applicant Birth Date",
                                                        style: TextStyle(
                                                            color: Color(
                                                                0xFF8A95A8),
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 12),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(
                                                    height: 5,
                                                  ),
                                                  Row(
                                                    children: [
                                                      const SizedBox(width: 2),
                                                      Text(
                                                        '${(data.applicantFirstName ?? '').isEmpty ? 'N/A' : data.applicantFirstName}',
                                                        style:  TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: blueColor


,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 2),
                                                    ],
                                                  ),
                                                  const SizedBox(
                                                    height: 18,
                                                  ),
// Applicant Current Address
                                                  const Row(
                                                    children: [
                                                      SizedBox(
                                                        width: 2,
                                                      ),
                                                      Text(
                                                        "Applicant Current Address",
                                                        style: TextStyle(
                                                            color: Color(
                                                                0xFF8A95A8),
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 12),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(
                                                    height: 5,
                                                  ),
                                                  Row(
                                                    children: [
                                                      const SizedBox(width: 2),
                                                      Text(
                                                        '${(data.applicantCity ?? '').isEmpty ? 'N/A' : data.applicantCity}',
                                                        style:  TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: blueColor


,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 2),
                                                    ],
                                                  ),
                                                  const SizedBox(
                                                    height: 18,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                : showEditForm
                                    ? Form(
                                        key: _formEditKey,
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                      'Edit Applicant Details',
                                                      softWrap: true,
                                                      overflow:
                                                          TextOverflow.fade,
                                                      style: TextStyle(
                                                          color: blueColor,
                                                          fontSize: 17,
                                                          fontWeight:
                                                              FontWeight.bold)),
                                                ),
                                                GestureDetector(
                                                  onTap: () {
                                                    setState(() {
                                                      showEditForm = false;
                                                    });
                                                  },
                                                  child: Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 16,
                                                        vertical: 9),
                                                    decoration: BoxDecoration(
                                                      color: Colors.white,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8),
                                                      border: Border.all(
                                                          color: const Color(
                                                              0xFFDBE0E5)),
                                                    ),
                                                    child: const Text(
                                                      'Cancel',
                                                      style: TextStyle(
                                                          color: Color(
                                                              0xFF748097),
                                                          fontSize: 13,
                                                          fontWeight:
                                                              FontWeight.w600),
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
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: blueColor),
                                            ),
                                            const SizedBox(
                                              height: 5,
                                            ),
                                            Container(
                                              width: double.infinity,
                                              decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  border: Border.all(
                                                    color: const Color(0xFFDBE0E5),
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(12.0)),
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.all(16.0),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      'First name',
                                                      style: TextStyle(
                                                          fontSize: 13,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color:
                                                              const Color.fromRGBO(21, 43, 81, 1)),
                                                    ),
                                                    const SizedBox(
                                                      height: 5,
                                                    ),
                                                    NewCustomTextField(
                                                      showElevation: false,
                                                      borderColor: const Color(0xFFDBE0E5),
                                                      hintText: 'First Name',
                                                      controller:
                                                          _applicantFirstNameController,
                                                    ),
                                                    const SizedBox(
                                                      height: 12,
                                                    ),
                                                    Text(
                                                      'Last Name',
                                                      style: TextStyle(
                                                          fontSize: 13,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color:
                                                              const Color.fromRGBO(21, 43, 81, 1)),
                                                    ),
                                                    const SizedBox(
                                                      height: 5,
                                                    ),
                                                    NewCustomTextField(
                                                      showElevation: false,
                                                      borderColor: const Color(0xFFDBE0E5),
                                                      hintText: 'Last Name',
                                                      controller:
                                                          _applicantLastNameController,
                                                    ),
                                                    const SizedBox(
                                                      height: 12,
                                                    ),
                                                    Text(
                                                      'Phone Number',
                                                      style: TextStyle(
                                                          fontSize: 13,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color:
                                                              const Color.fromRGBO(21, 43, 81, 1)),
                                                    ),
                                                    const SizedBox(
                                                      height: 5,
                                                    ),
                                                    CustomDateField(
                                                      borderColor: const Color(0xFFDBE0E5),
                                                      borderRadius: 8,
                                                      hintText:
                                                          'Pick date of birth',
                                                      controller:
                                                          _applicantBirthdateController,
                                                    ),
                                                    const SizedBox(
                                                      height: 12,
                                                    ),
                                                    Text(
                                                      'Email',
                                                      style: TextStyle(
                                                          fontSize: 13,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color:
                                                              const Color.fromRGBO(21, 43, 81, 1)),
                                                    ),
                                                    const SizedBox(
                                                      height: 5,
                                                    ),
                                                    NewCustomTextField(
                                                      showElevation: false,
                                                      borderColor: const Color(0xFFDBE0E5),
                                                      hintText: 'Email',
                                                      controller:
                                                          _applicantEmailController,
                                                    ),
                                                    const SizedBox(
                                                      height: 12,
                                                    ),
                                                    Text(
                                                      'Phone Number',
                                                      style: TextStyle(
                                                          fontSize: 13,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color:
                                                              const Color.fromRGBO(21, 43, 81, 1)),
                                                    ),
                                                    const SizedBox(
                                                      height: 5,
                                                    ),
                                                    NewCustomTextField(
                                                      showElevation: false,
                                                      borderColor: const Color(0xFFDBE0E5),
                                                      hintText: 'Phone Number',
                                                      controller:
                                                          _applicantPhoneNumberController,
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
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: blueColor),
                                            ),
                                            const SizedBox(
                                              height: 5,
                                            ),
                                            Container(
                                              width: double.infinity,
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                border: Border.all(
                                                  color: const Color(0xFFDBE0E5),
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(12.0),
                                              ),
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.all(16.0),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      'Street Address',
                                                      style: TextStyle(
                                                          fontSize: 13,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color:
                                                              const Color.fromRGBO(21, 43, 81, 1)),
                                                    ),
                                                    const SizedBox(
                                                      height: 5,
                                                    ),
                                                    NewCustomTextField(
                                                      showElevation: false,
                                                      borderColor: const Color(0xFFDBE0E5),
                                                      hintText:
                                                          'Street Address',
                                                      controller:
                                                          _applicantStreetAddressController,
                                                    ),
                                                    const SizedBox(
                                                      height: 12,
                                                    ),
                                                    Text(
                                                      'City',
                                                      style: TextStyle(
                                                          fontSize: 13,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color:
                                                              const Color.fromRGBO(21, 43, 81, 1)),
                                                    ),
                                                    const SizedBox(
                                                      height: 5,
                                                    ),
                                                    NewCustomTextField(
                                                      showElevation: false,
                                                      borderColor: const Color(0xFFDBE0E5),
                                                      hintText: 'City',
                                                      controller:
                                                          _applicantCityController,
                                                    ),
                                                    const SizedBox(
                                                      height: 12,
                                                    ),
                                                    Text(
                                                      'State',
                                                      style: TextStyle(
                                                          fontSize: 13,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color:
                                                              const Color.fromRGBO(21, 43, 81, 1)),
                                                    ),
                                                    const SizedBox(
                                                      height: 5,
                                                    ),
                                                    NewCustomTextField(
                                                      showElevation: false,
                                                      borderColor: const Color(0xFFDBE0E5),
                                                      hintText: 'State',
                                                      controller:
                                                          _applicantStateController,
                                                    ),
                                                    const SizedBox(
                                                      height: 12,
                                                    ),
                                                    Text(
                                                      'Country',
                                                      style: TextStyle(
                                                          fontSize: 13,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color:
                                                              const Color.fromRGBO(21, 43, 81, 1)),
                                                    ),
                                                    const SizedBox(
                                                      height: 5,
                                                    ),
                                                    NewCustomTextField(
                                                      showElevation: false,
                                                      borderColor: const Color(0xFFDBE0E5),
                                                      hintText: 'Country',
                                                      controller:
                                                          _applicantCountryController,
                                                    ),
                                                    const SizedBox(
                                                      height: 12,
                                                    ),
                                                    Text(
                                                      'Postal Code',
                                                      style: TextStyle(
                                                          fontSize: 13,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color:
                                                              const Color.fromRGBO(21, 43, 81, 1)),
                                                    ),
                                                    const SizedBox(
                                                      height: 5,
                                                    ),
                                                    NewCustomTextField(
                                                      showElevation: false,
                                                      borderColor: const Color(0xFFDBE0E5),
                                                      hintText: 'Postal Code',
                                                      controller:
                                                          _applicantPostalCodeController,
                                                      keyboardType: TextInputType.number,
                                                      inputFormatters: [
                                                        FilteringTextInputFormatter.digitsOnly,
                                                      ],
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
                                                fontWeight: FontWeight.bold,
                                                color: blueColor,
                                              ),
                                            ),
                                            const SizedBox(
                                              height: 5,
                                            ),
                                            Container(
                                              width: double.infinity,
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                border: Border.all(
                                                  color: const Color(0xFFDBE0E5),
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(12.0),
                                              ),
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.all(16.0),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      'First Name',
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: const Color.fromRGBO(21, 43, 81, 1),
                                                      ),
                                                    ),
                                                    const SizedBox(
                                                      height: 5,
                                                    ),
                                                    NewCustomTextField(
                                                      showElevation: false,
                                                      borderColor: const Color(0xFFDBE0E5),
                                                      hintText: 'First Name',
                                                      controller:
                                                          _emergencyFirstNameController,
                                                    ),
                                                    const SizedBox(
                                                      height: 12,
                                                    ),
                                                    Text(
                                                      'Last Name',
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: const Color.fromRGBO(21, 43, 81, 1),
                                                      ),
                                                    ),
                                                    const SizedBox(
                                                      height: 5,
                                                    ),
                                                    NewCustomTextField(
                                                      showElevation: false,
                                                      borderColor: const Color(0xFFDBE0E5),
                                                      hintText: 'Last Name',
                                                      controller:
                                                          _emergencyLastNameController,
                                                    ),
                                                    const SizedBox(
                                                      height: 12,
                                                    ),
                                                    Text(
                                                      'Relationship',
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: const Color.fromRGBO(21, 43, 81, 1),
                                                      ),
                                                    ),
                                                    const SizedBox(
                                                      height: 5,
                                                    ),
                                                    NewCustomTextField(
                                                      showElevation: false,
                                                      borderColor: const Color(0xFFDBE0E5),
                                                      hintText: 'Relationship',
                                                      controller:
                                                          _emergencyRelationshipController,
                                                    ),
                                                    const SizedBox(
                                                      height: 12,
                                                    ),
                                                    Text(
                                                      'Email',
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: const Color.fromRGBO(21, 43, 81, 1),
                                                      ),
                                                    ),
                                                    const SizedBox(
                                                      height: 5,
                                                    ),
                                                    NewCustomTextField(
                                                      showElevation: false,
                                                      borderColor: const Color(0xFFDBE0E5),
                                                      hintText: 'Email',
                                                      controller:
                                                          _emergencyEmailController,
                                                    ),
                                                    const SizedBox(
                                                      height: 12,
                                                    ),
                                                    Text(
                                                      'Phone Number',
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: const Color.fromRGBO(21, 43, 81, 1),
                                                      ),
                                                    ),
                                                    const SizedBox(
                                                      height: 5,
                                                    ),
                                                    NewCustomTextField(
                                                      showElevation: false,
                                                      borderColor: const Color(0xFFDBE0E5),
                                                      hintText: 'Phone Number',
                                                      controller:
                                                          _emergencyPhoneNumberController,
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
                                                fontWeight: FontWeight.bold,
                                                color: blueColor,
                                              ),
                                            ),
                                            const SizedBox(
                                              height: 5,
                                            ),
                                            Container(
                                              width: double.infinity,
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                border: Border.all(
                                                  color: const Color(0xFFDBE0E5),
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(12.0),
                                              ),
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.all(16.0),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      'Rental Address',
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: const Color.fromRGBO(21, 43, 81, 1),
                                                      ),
                                                    ),
                                                    const SizedBox(
                                                      height: 5,
                                                    ),
                                                    NewCustomTextField(
                                                      showElevation: false,
                                                      borderColor: const Color(0xFFDBE0E5),
                                                      hintText:
                                                          'Rental Address',
                                                      controller:
                                                          _rentalAddressController,
                                                    ),
                                                    const SizedBox(
                                                      height: 12,
                                                    ),
                                                    Text(
                                                      'City',
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: const Color.fromRGBO(21, 43, 81, 1),
                                                      ),
                                                    ),
                                                    const SizedBox(
                                                      height: 5,
                                                    ),
                                                    NewCustomTextField(
                                                      showElevation: false,
                                                      borderColor: const Color(0xFFDBE0E5),
                                                      hintText: 'City',
                                                      controller:
                                                          _rentalCityController,
                                                    ),
                                                    const SizedBox(
                                                      height: 12,
                                                    ),
                                                    Text(
                                                      'State',
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: const Color.fromRGBO(21, 43, 81, 1),
                                                      ),
                                                    ),
                                                    const SizedBox(
                                                      height: 5,
                                                    ),
                                                    NewCustomTextField(
                                                      showElevation: false,
                                                      borderColor: const Color(0xFFDBE0E5),
                                                      hintText: 'State',
                                                      controller:
                                                          _rentalStateController,
                                                    ),
                                                    const SizedBox(
                                                      height: 12,
                                                    ),
                                                    Text(
                                                      'Country',
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: const Color.fromRGBO(21, 43, 81, 1),
                                                      ),
                                                    ),
                                                    const SizedBox(
                                                      height: 5,
                                                    ),
                                                    NewCustomTextField(
                                                      showElevation: false,
                                                      borderColor: const Color(0xFFDBE0E5),
                                                      hintText: 'Country',
                                                      controller:
                                                          _rentalCountryController,
                                                    ),
                                                    const SizedBox(
                                                      height: 12,
                                                    ),
                                                    Text(
                                                      'Postcode',
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: const Color.fromRGBO(21, 43, 81, 1),
                                                      ),
                                                    ),
                                                    const SizedBox(
                                                      height: 5,
                                                    ),
                                                    NewCustomTextField(
                                                      showElevation: false,
                                                      borderColor: const Color(0xFFDBE0E5),
                                                      hintText: 'Postcode',
                                                      controller:
                                                          _rentalPostcodeController,
                                                      keyboardType: TextInputType.number,
                                                      inputFormatters: [
                                                        FilteringTextInputFormatter.digitsOnly,
                                                      ],
                                                    ),
                                                    const SizedBox(
                                                      height: 12,
                                                    ),
                                                    Text(
                                                      'Start Date',
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: const Color.fromRGBO(21, 43, 81, 1),
                                                      ),
                                                    ),
                                                    const SizedBox(
                                                      height: 5,
                                                    ),
                                                    NewCustomTextField(
                                                      showElevation: false,
                                                      borderColor: const Color(0xFFDBE0E5),
                                                      hintText: 'Start Date',
                                                      controller:
                                                          _startDateController,
                                                    ),
                                                    const SizedBox(
                                                      height: 12,
                                                    ),
                                                    Text(
                                                      'End Date',
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: const Color.fromRGBO(21, 43, 81, 1),
                                                      ),
                                                    ),
                                                    const SizedBox(
                                                      height: 5,
                                                    ),
                                                    NewCustomTextField(
                                                      showElevation: false,
                                                      borderColor: const Color(0xFFDBE0E5),
                                                      hintText: 'End Date',
                                                      controller:
                                                          _endDateController,
                                                    ),
                                                    const SizedBox(
                                                      height: 12,
                                                    ),
                                                    Text(
                                                      'Rent Amount',
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: const Color.fromRGBO(21, 43, 81, 1),
                                                      ),
                                                    ),
                                                    const SizedBox(
                                                      height: 5,
                                                    ),
                                                    NewCustomTextField(
                                                      showElevation: false,
                                                      borderColor: const Color(0xFFDBE0E5),
                                                      hintText: 'Rent Amount',
                                                      controller:
                                                          _rentController,
                                                    ),
                                                    const SizedBox(
                                                      height: 12,
                                                    ),
                                                    Text(
                                                      'Reason for Leaving',
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: const Color.fromRGBO(21, 43, 81, 1),
                                                      ),
                                                    ),
                                                    const SizedBox(
                                                      height: 5,
                                                    ),
                                                    NewCustomTextField(
                                                      showElevation: false,
                                                      borderColor: const Color(0xFFDBE0E5),
                                                      hintText:
                                                          'Reason for Leaving',
                                                      controller:
                                                          _leavingReasonController,
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
                                                fontWeight: FontWeight.bold,
                                                color: blueColor,
                                              ),
                                            ),
                                            const SizedBox(
                                              height: 5,
                                            ),
                                            Container(
                                              width: double.infinity,
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                border: Border.all(
                                                  color: const Color(0xFFDBE0E5),
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(12.0),
                                              ),
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.all(16.0),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      'First Name',
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: const Color.fromRGBO(21, 43, 81, 1),
                                                      ),
                                                    ),
                                                    const SizedBox(
                                                      height: 5,
                                                    ),
                                                    NewCustomTextField(
                                                      showElevation: false,
                                                      borderColor: const Color(0xFFDBE0E5),
                                                      hintText: 'First Name',
                                                      controller:
                                                          _rentalOwnerFirstNameController,
                                                    ),
                                                    const SizedBox(
                                                      height: 12,
                                                    ),
                                                    Text(
                                                      'Last Name',
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: const Color.fromRGBO(21, 43, 81, 1),
                                                      ),
                                                    ),
                                                    const SizedBox(
                                                      height: 5,
                                                    ),
                                                    NewCustomTextField(
                                                      showElevation: false,
                                                      borderColor: const Color(0xFFDBE0E5),
                                                      hintText: 'Last Name',
                                                      controller:
                                                          _rentalOwnerLastNameController,
                                                    ),
                                                    const SizedBox(
                                                      height: 12,
                                                    ),
                                                    Text(
                                                      'Email',
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: const Color.fromRGBO(21, 43, 81, 1),
                                                      ),
                                                    ),
                                                    const SizedBox(
                                                      height: 5,
                                                    ),
                                                    NewCustomTextField(
                                                      showElevation: false,
                                                      borderColor: const Color(0xFFDBE0E5),
                                                      hintText: 'Email',
                                                      controller:
                                                          _rentalOwnerEmailController,
                                                    ),
                                                    const SizedBox(
                                                      height: 12,
                                                    ),
                                                    Text(
                                                      'Phone Number',
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: const Color.fromRGBO(21, 43, 81, 1),
                                                      ),
                                                    ),
                                                    const SizedBox(
                                                      height: 5,
                                                    ),
                                                    NewCustomTextField(
                                                      showElevation: false,
                                                      borderColor: const Color(0xFFDBE0E5),
                                                      hintText: 'Phone Number',
                                                      controller:
                                                          _rentalOwnerPhoneNumberController,
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
                                                fontWeight: FontWeight.bold,
                                                color: blueColor,
                                              ),
                                            ),
                                            const SizedBox(
                                              height: 5,
                                            ),
                                            Container(
                                              width: double.infinity,
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                border: Border.all(
                                                  color: const Color(0xFFDBE0E5),
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(12.0),
                                              ),
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.all(16.0),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      'Company Name',
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: const Color.fromRGBO(21, 43, 81, 1),
                                                      ),
                                                    ),
                                                    const SizedBox(
                                                      height: 5,
                                                    ),
                                                    NewCustomTextField(
                                                      showElevation: false,
                                                      borderColor: const Color(0xFFDBE0E5),
                                                      hintText: 'Company Name',
                                                      controller:
                                                          _employmentNameController,
                                                    ),
                                                    const SizedBox(
                                                      height: 12,
                                                    ),
                                                    Text(
                                                      'Street Address',
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: const Color.fromRGBO(21, 43, 81, 1),
                                                      ),
                                                    ),
                                                    const SizedBox(
                                                      height: 5,
                                                    ),
                                                    NewCustomTextField(
                                                      showElevation: false,
                                                      borderColor: const Color(0xFFDBE0E5),
                                                      hintText:
                                                          'Street Address',
                                                      controller:
                                                          _employmentStreetAddressController,
                                                    ),
                                                    const SizedBox(
                                                      height: 12,
                                                    ),
                                                    Text(
                                                      'City',
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: const Color.fromRGBO(21, 43, 81, 1),
                                                      ),
                                                    ),
                                                    const SizedBox(
                                                      height: 5,
                                                    ),
                                                    NewCustomTextField(
                                                      showElevation: false,
                                                      borderColor: const Color(0xFFDBE0E5),
                                                      hintText: 'City',
                                                      controller:
                                                          _employmentCityController,
                                                    ),
                                                    const SizedBox(
                                                      height: 12,
                                                    ),
                                                    Text(
                                                      'State',
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: const Color.fromRGBO(21, 43, 81, 1),
                                                      ),
                                                    ),
                                                    const SizedBox(
                                                      height: 5,
                                                    ),
                                                    NewCustomTextField(
                                                      showElevation: false,
                                                      borderColor: const Color(0xFFDBE0E5),
                                                      hintText: 'State',
                                                      controller:
                                                          _employmentStateController,
                                                    ),
                                                    const SizedBox(
                                                      height: 12,
                                                    ),
                                                    Text(
                                                      'Country',
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: const Color.fromRGBO(21, 43, 81, 1),
                                                      ),
                                                    ),
                                                    const SizedBox(
                                                      height: 5,
                                                    ),
                                                    NewCustomTextField(
                                                      showElevation: false,
                                                      borderColor: const Color(0xFFDBE0E5),
                                                      hintText: 'Country',
                                                      controller:
                                                          _employmentCountryController,
                                                    ),
                                                    const SizedBox(
                                                      height: 12,
                                                    ),
                                                    Text(
                                                      'Postal Code',
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: const Color.fromRGBO(21, 43, 81, 1),
                                                      ),
                                                    ),
                                                    const SizedBox(
                                                      height: 5,
                                                    ),
                                                    NewCustomTextField(
                                                      showElevation: false,
                                                      borderColor: const Color(0xFFDBE0E5),
                                                      hintText: 'Postal Code',
                                                      controller:
                                                          _employmentPostalCodeController,
                                                      keyboardType: TextInputType.number,
                                                      inputFormatters: [
                                                        FilteringTextInputFormatter.digitsOnly,
                                                      ],
                                                    ),
                                                    const SizedBox(
                                                      height: 12,
                                                    ),
                                                    Text(
                                                      'Primary Email',
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: const Color.fromRGBO(21, 43, 81, 1),
                                                      ),
                                                    ),
                                                    const SizedBox(
                                                      height: 5,
                                                    ),
                                                    NewCustomTextField(
                                                      showElevation: false,
                                                      borderColor: const Color(0xFFDBE0E5),
                                                      hintText: 'Primary Email',
                                                      controller:
                                                          _employmentPrimaryEmailController,
                                                    ),
                                                    const SizedBox(
                                                      height: 12,
                                                    ),
                                                    Text(
                                                      'Phone Number',
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: const Color.fromRGBO(21, 43, 81, 1),
                                                      ),
                                                    ),
                                                    const SizedBox(
                                                      height: 5,
                                                    ),
                                                    NewCustomTextField(
                                                      showElevation: false,
                                                      borderColor: const Color(0xFFDBE0E5),
                                                      hintText: 'Phone Number',
                                                      controller:
                                                          _employmentPhoneNumberController,
                                                    ),
                                                    const SizedBox(
                                                      height: 12,
                                                    ),
                                                    Text(
                                                      'Position',
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: const Color.fromRGBO(21, 43, 81, 1),
                                                      ),
                                                    ),
                                                    const SizedBox(
                                                      height: 5,
                                                    ),
                                                    NewCustomTextField(
                                                      showElevation: false,
                                                      borderColor: const Color(0xFFDBE0E5),
                                                      hintText: 'Position',
                                                      controller:
                                                          _employmentPositionController,
                                                    ),
                                                    const SizedBox(
                                                      height: 12,
                                                    ),
                                                    Text(
                                                      'Supervisor First Name',
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: const Color.fromRGBO(21, 43, 81, 1),
                                                      ),
                                                    ),
                                                    const SizedBox(
                                                      height: 5,
                                                    ),
                                                    NewCustomTextField(
                                                      showElevation: false,
                                                      borderColor: const Color(0xFFDBE0E5),
                                                      hintText:
                                                          'Supervisor First Name',
                                                      controller:
                                                          _supervisorFirstNameController,
                                                    ),
                                                    const SizedBox(
                                                      height: 12,
                                                    ),
                                                    Text(
                                                      'Supervisor Last Name',
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: const Color.fromRGBO(21, 43, 81, 1),
                                                      ),
                                                    ),
                                                    const SizedBox(
                                                      height: 5,
                                                    ),
                                                    NewCustomTextField(
                                                      showElevation: false,
                                                      borderColor: const Color(0xFFDBE0E5),
                                                      hintText:
                                                          'Supervisor Last Name',
                                                      controller:
                                                          _supervisorLastNameController,
                                                    ),
                                                    const SizedBox(
                                                      height: 12,
                                                    ),
                                                    Text(
                                                      'Supervisor Title',
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: const Color.fromRGBO(21, 43, 81, 1),
                                                      ),
                                                    ),
                                                    const SizedBox(
                                                      height: 5,
                                                    ),
                                                    NewCustomTextField(
                                                      showElevation: false,
                                                      borderColor: const Color(0xFFDBE0E5),
                                                      hintText:
                                                          'Supervisor Title',
                                                      controller:
                                                          _supervisorTitleController,
                                                    ),
                                                    const SizedBox(height: 16),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            /* Web parity: Terms & conditions paragraph + "Agreed to" checkbox removed from edit form; kept commented.
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                bottom: 16.0,
                                                top: 16.0,
                                              ),
                                              child: Text(
                                                  'Terms and conditions',
                                                  softWrap: true,
                                                  overflow: TextOverflow.fade,
                                                  style: TextStyle(
                                                      color: blueColor,
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.w500)),
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
                                                      fontWeight:
                                                          FontWeight.w500)),
                                            ),

                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.start,
                                              children: [
                                                Checkbox(
                                                    value: checked,
                                                    onChanged: (value) {}),
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                    left: 4.0,
                                                  ),
                                                  child: Text('Agreed to*',
                                                      softWrap: true,
                                                      overflow:
                                                          TextOverflow.fade,
                                                      style: TextStyle(
                                                          color:
                                                              const Color.fromRGBO(21, 43, 81, 1),
                                                          fontSize: 14,
                                                          fontWeight:
                                                              FontWeight.w600)),
                                                ),
                                              ],
                                            ),
                                            */
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                left: 4.0,
                                              ),
                                              child: Text('Agreed by',
                                                  softWrap: true,
                                                  overflow: TextOverflow.fade,
                                                  style: TextStyle(
                                                      color: const Color.fromRGBO(21, 43, 81, 1),
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.bold)),
                                            ),
                                            const SizedBox(
                                              height: 10,
                                            ),
                                            NewCustomTextField(
                                              showElevation: false,
                                              borderColor: const Color(0xFFDBE0E5),
                                              hintText: 'Agreed by...',
                                              controller: _agreeByController,
                                            ),
                                            /* Web parity: Privacy Policy / Terms of Service block removed from edit form; kept commented.
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
                                                        fontWeight:
                                                            FontWeight.w500)),
                                                TextSpan(
                                                    text: 'Privacy Policy',
                                                    style: TextStyle(
                                                        color: Colors.grey[600],
                                                        fontSize: 16,
                                                        fontWeight:
                                                            FontWeight.w500)),
                                                TextSpan(
                                                    text: ' and ',
                                                    style: TextStyle(
                                                        color: Colors.grey[500],
                                                        fontSize: 16,
                                                        fontWeight:
                                                            FontWeight.w500)),
                                                TextSpan(
                                                    text: 'Terms of Service.',
                                                    style: TextStyle(
                                                        color: Colors.grey[600],
                                                        fontSize: 16,
                                                        fontWeight:
                                                            FontWeight.w500)),
                                              ])),
                                            ),
                                            */
                                            SizedBox(
                                              width: double.infinity,
                                              height: 50,
                                              child: ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                  backgroundColor: blueColor,
                                                  elevation: 0,
                                                  shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(10))),
                                              onPressed: () async {
                                                if (_formKey.currentState!
                                                    .validate()) {
                                                  SharedPreferences prefs =
                                                      await SharedPreferences
                                                          .getInstance();
                                                  String? adminId = prefs
                                                      .getString('adminId');
                                                  // printAllFields();
                                                  Data data = Data(
                                                    emergencyContact:
                                                        EmergencyContact(
                                                      firstName:
                                                          _emergencyFirstNameController
                                                              .text.trim(),
                                                      lastName:
                                                          _emergencyLastNameController
                                                              .text.trim(),
                                                      relationship:
                                                          _emergencyRelationshipController
                                                              .text.trim(),
                                                      email:
                                                          _emergencyEmailController
                                                              .text.trim(),
                                                      phoneNumber:
                                                          _emergencyPhoneNumberController
                                                              .text.trim(),
                                                    ),
                                                    rentalHistory:
                                                        RentalHistory(
                                                      rentalAdress:
                                                          _rentalAddressController
                                                              .text.trim(),
                                                      rentalCity:
                                                          _rentalCityController
                                                              .text.trim(),
                                                      rentalState:
                                                          _rentalStateController
                                                              .text.trim(),
                                                      rentalCountry:
                                                          _rentalCountryController
                                                              .text.trim(),
                                                      rentalPostcode:
                                                          _rentalPostcodeController
                                                              .text.trim(),
                                                      rentalOwnerFirstName:
                                                          _rentalOwnerFirstNameController
                                                              .text.trim(),
                                                      rentalOwnerLastName:
                                                          _rentalOwnerLastNameController
                                                              .text.trim(),
                                                      startDate:
                                                          _startDateController
                                                              .text.trim(),
                                                      endDate:
                                                          _endDateController
                                                              .text.trim(),
                                                      rent:
                                                          _rentController.text.trim(),
                                                      leavingReason:
                                                          _leavingReasonController
                                                              .text.trim(),
                                                      rentalOwnerPrimaryEmail:
                                                          _rentalOwnerEmailController
                                                              .text.trim(),
                                                      rentalOwnerPhoneNumber:

                                                              _rentalOwnerPhoneNumberController
                                                                  .text.trim(),
                                                    ),
                                                    employment: Employment(
                                                      name:
                                                          _employmentNameController
                                                              .text.trim(),
                                                      streetAddress:
                                                          _employmentStreetAddressController
                                                              .text.trim(),
                                                      city:
                                                          _employmentCityController
                                                              .text.trim(),
                                                      state:
                                                          _employmentStateController
                                                              .text.trim(),
                                                      country:
                                                          _employmentCountryController
                                                              .text.trim(),
                                                      postalCode:
                                                          _employmentPostalCodeController
                                                              .text.trim(),
                                                      employmentPrimaryEmail:
                                                          _employmentPrimaryEmailController
                                                              .text.trim(),
                                                      employmentPhoneNumber:

                                                              _employmentPhoneNumberController
                                                                  .text.trim(),
                                                      employmentPosition:
                                                          _employmentPositionController
                                                              .text.trim(),
                                                      supervisorFirstName:
                                                          _supervisorFirstNameController
                                                              .text.trim(),
                                                      supervisorLastName:
                                                          _supervisorLastNameController
                                                              .text.trim(),
                                                      supervisorTitle:
                                                          _supervisorTitleController
                                                              .text.trim(),
                                                    ),

                                                    applicantId: widget
                                                        .applicantDetail
                                                        .applicantId, // Assuming this value is not set from a controller
                                                    adminId:
                                                        adminId, // Assuming this value is not set from a controller
                                                    applicantStreetAddress:
                                                        _applicantStreetAddressController
                                                            .text.trim(),
                                                    applicantCity:
                                                        _applicantCityController
                                                            .text.trim(),
                                                    applicantState:
                                                        _applicantStateController
                                                            .text.trim(),
                                                    applicantCountry:
                                                        _applicantCountryController
                                                            .text.trim(),
                                                    applicantPostalCode:
                                                        _applicantPostalCodeController
                                                            .text.trim(),
                                                    agreeBy:
                                                        _agreeByController.text.trim(),

                                                    applicantFirstName:
                                                        _applicantFirstNameController
                                                            .text.trim(),
                                                    applicantLastName:
                                                        _applicantLastNameController
                                                            .text.trim(),
                                                    applicantEmail:
                                                        _applicantEmailController
                                                            .text.trim(),
                                                    applicantPhoneNumber:
                                                        _applicantPhoneNumberController
                                                            .text.trim(),
                                                    isApplicantDataEmpty:
                                                        false, // Default value
                                                  );
                                                  ApplicantSummeryRepository
                                                      applicantSummeryRepository =
                                                      ApplicantSummeryRepository();
                                                  bool success =
                                                      await ApplicantSummeryRepository()
                                                          .addApplicantSummaryForm(
                                                              data,
                                                              widget
                                                                  .applicant_id);
                                                  if (success == true) {
                                                    Fluttertoast.showToast(
                                                        msg:
                                                            'Applicant Added Successfully');
                                                  }
                                                  // No failure toast here: addApplicantSummaryForm already raises the
                                                  // server's own reason, which is the only place that text exists. A
                                                  // generic 'Failed to add applicant' on top of it put two messages on
                                                  // screen for one tap, the second contradicting the first. The repo
                                                  // owns failure, this screen owns success - the split its comment
                                                  // already describes.
                                                } else {
                                                  setState(
                                                      () {}); // Rebuild to show the error message
                                                }
                                              },
                                              child: const Text(
                                                    'Save Applicant',
                                                    style: TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 16,
                                                        fontWeight: FontWeight.w600),
                                                  ),
                                            ),
                                            ),
                                          ],
                                        ),
                                      )
                                    : showEditForm
                                        ? EditApplicantSummary(
                                            applicantId: widget.applicant_id,
                                          )
                                        : LayoutBuilder(
                                            builder: (context, contraints) {
                                            if (contraints.maxWidth > 500) {
                                              return Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.all(
                                                            0.0),
                                                    child: Material(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              10),
                                                      child: Container(
                                                        decoration:
                                                            BoxDecoration(
                                                          color: Colors.white,
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(10),
                                                          border: Border.all(
                                                              color: const Color
                                                                  .fromRGBO(21,
                                                                  43, 81, 1)),
                                                        ),
                                                        child: Padding(
                                                          padding:
                                                              const EdgeInsets
                                                                  .only(
                                                                  left: 16,
                                                                  right: 16,
                                                                  top: 16,
                                                                  bottom: 16),
                                                          child: Column(
                                                            children: [
                                                              Row(
                                                                mainAxisAlignment:
                                                                    MainAxisAlignment
                                                                        .spaceBetween,
                                                                children: [
                                                                  Flexible(
                                                                    flex: 3,
                                                                    child:
                                                                        Container(
                                                                      child:
                                                                          Text(
                                                                        "Applicant Information",
                                                                        style: TextStyle(
                                                                            color: const Color.fromRGBO(
                                                                                21,
                                                                                43,
                                                                                81,
                                                                                1),
                                                                            fontWeight:
                                                                                FontWeight.bold,
                                                                            fontSize: MediaQuery.of(context).size.width * .03),
                                                                      ),
                                                                    ),
                                                                  ),
                                                                  Flexible(
                                                                    child:
                                                                        ElevatedButton(
                                                                      onPressed:
                                                                          () {
                                                                        setState(
                                                                            () {
                                                                          showEditForm =
                                                                              true;
                                                                        });
                                                                      },
                                                                      child:
                                                                          Text(
                                                                        "Edit", // Updated text to differentiate from the first one
                                                                        style: TextStyle(
                                                                            color:
                                                                                Colors.white,
                                                                            fontWeight: FontWeight.bold,
                                                                            fontSize: MediaQuery.of(context).size.width * .03),
                                                                      ),
                                                                      style: ElevatedButton.styleFrom(
                                                                          // Button color
                                                                          backgroundColor: blueColor),
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                              const SizedBox(
                                                                height: 10,
                                                              ),
                                                              // Unit ID

                                                              Row(
                                                                children: [
                                                                  Expanded(
                                                                    child:
                                                                        Column(
                                                                      children: [
                                                                        const Row(
                                                                          children: [
                                                                            SizedBox(
                                                                              width: 2,
                                                                            ),
                                                                            Text(
                                                                              "Applicant Name",
                                                                              style: TextStyle(color: Color(0xFF8A95A8), fontWeight: FontWeight.bold, fontSize: 18),
                                                                            ),
                                                                          ],
                                                                        ),
                                                                        const SizedBox(
                                                                          height:
                                                                              5,
                                                                        ),
                                                                        Row(
                                                                          children: [
                                                                            const SizedBox(width: 2),
                                                                            Text(
                                                                              '${data.applicantFirstName} ${data.applicantLastName}',
                                                                              style:  TextStyle(
                                                                                fontWeight: FontWeight.bold,
                                                                                fontSize: 16,
                                                                                color: blueColor,
                                                                              ),
                                                                            ),
                                                                            const SizedBox(width: 2),
                                                                          ],
                                                                        ),
                                                                      ],
                                                                    ),
                                                                  ),
                                                                  const SizedBox(
                                                                    width: 18,
                                                                  ),
                                                                  Expanded(
                                                                    child:
                                                                        Column(
                                                                      children: [
                                                                        const Row(
                                                                          children: [
                                                                            SizedBox(
                                                                              width: 2,
                                                                            ),
                                                                            Text(
                                                                              "Applicant Birth Date",
                                                                              style: TextStyle(color: Color(0xFF8A95A8), fontWeight: FontWeight.bold, fontSize: 18),
                                                                            ),
                                                                          ],
                                                                        ),
                                                                        const SizedBox(
                                                                          height:
                                                                              5,
                                                                        ),
                                                                        Row(
                                                                          children: [
                                                                            const SizedBox(width: 2),
                                                                            Text(
                                                                              '${data.applicantCity ?? 'N/A'}',
                                                                              style:  TextStyle(
                                                                                fontWeight: FontWeight.bold,
                                                                                fontSize: 16,
                                                                                color: blueColor,
                                                                              ),
                                                                            ),
                                                                            const SizedBox(width: 2),
                                                                          ],
                                                                        ),
                                                                      ],
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),

                                                              // Rental Owner

                                                              const SizedBox(
                                                                height: 18,
                                                              ),
                                                              // Tenant
                                                              Row(
                                                                children: [
                                                                  Expanded(
                                                                    child:
                                                                        Column(
                                                                      children: [
                                                                        const Row(
                                                                          children: [
                                                                            SizedBox(
                                                                              width: 2,
                                                                            ),
                                                                            Text(
                                                                              "Applicant Current Address",
                                                                              style: TextStyle(color: Color(0xFF8A95A8), fontWeight: FontWeight.bold, fontSize: 18),
                                                                            ),
                                                                          ],
                                                                        ),
                                                                        const SizedBox(
                                                                          height:
                                                                              5,
                                                                        ),
                                                                        Row(
                                                                          children: [
                                                                            const SizedBox(width: 2),
                                                                            Text(
                                                                              '${data.applicantStreetAddress ?? 'N/A'}',
                                                                              style:  TextStyle(
                                                                                fontWeight: FontWeight.bold,
                                                                                fontSize: 16,
                                                                                color: blueColor,
                                                                              ),
                                                                            ),
                                                                            const SizedBox(width: 2),
                                                                          ],
                                                                        ),
                                                                      ],
                                                                    ),
                                                                  ),
                                                                  const SizedBox(
                                                                    width: 18,
                                                                  ),
                                                                  Expanded(
                                                                    child:
                                                                        Column(
                                                                      children: [
                                                                        const Row(
                                                                          children: [
                                                                            SizedBox(
                                                                              width: 2,
                                                                            ),
                                                                            Text(
                                                                              "Applicant Email",
                                                                              style: TextStyle(color: Color(0xFF8A95A8), fontWeight: FontWeight.bold, fontSize: 18),
                                                                            ),
                                                                          ],
                                                                        ),
                                                                        const SizedBox(
                                                                          height:
                                                                              5,
                                                                        ),
                                                                        Row(
                                                                          children: [
                                                                            const SizedBox(width: 2),
                                                                            Text(
                                                                              '${data.applicantEmail ?? 'N/A'}',
                                                                              style:  TextStyle(
                                                                                fontWeight: FontWeight.bold,
                                                                                fontSize: 16,
                                                                                color: blueColor,
                                                                              ),
                                                                            ),
                                                                            const SizedBox(width: 2),
                                                                          ],
                                                                        ),
                                                                      ],
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),

                                                              // Tenant

                                                              const SizedBox(
                                                                height: 18,
                                                              ),
                                                              // Tenant
                                                              const Row(
                                                                children: [
                                                                  SizedBox(
                                                                    width: 2,
                                                                  ),
                                                                  Text(
                                                                    "Applicant Phone",
                                                                    style: TextStyle(
                                                                        color: Color(
                                                                            0xFF8A95A8),
                                                                        fontWeight:
                                                                            FontWeight
                                                                                .bold,
                                                                        fontSize:
                                                                            18),
                                                                  ),
                                                                ],
                                                              ),
                                                              const SizedBox(
                                                                height: 5,
                                                              ),
                                                              Row(
                                                                children: [
                                                                  const SizedBox(
                                                                      width: 2),
                                                                  Text(
                                                                    formatPhoneNumber('${data.applicantPhoneNumber}'),
                                                                    // '${data.applicantPhoneNumber ?? 'N/A'}',
                                                                    style:
                                                                        const TextStyle(
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .bold,
                                                                      fontSize:
                                                                          16,
                                                                      color: Color
                                                                          .fromRGBO(
                                                                              21,
                                                                              43,
                                                                              83,
                                                                              1),
                                                                    ),
                                                                  ),
                                                                  const SizedBox(
                                                                      width: 2),
                                                                ],
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),

                                                  // Add more fields as needed
                                                ],
                                              );
                                            }
                                            return Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.all(0.0),
                                                  child: Material(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            10),
                                                    child: Container(
                                                      decoration: BoxDecoration(
                                                        color: Colors.white,
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(10),
                                                        border: Border.all(
                                                            color: const Color
                                                                .fromRGBO(
                                                                21, 43, 81, 1)),
                                                      ),
                                                      child: Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .only(
                                                                left: 16,
                                                                right: 16,
                                                                top: 16,
                                                                bottom: 16),
                                                        child: Column(
                                                          children: [
                                                            Row(
                                                              mainAxisAlignment:
                                                                  MainAxisAlignment
                                                                      .spaceBetween,
                                                              children: [
                                                                Flexible(
                                                                  flex: 3,
                                                                  child:
                                                                      Container(
                                                                    child: Text(
                                                                      "Applicant Information",
                                                                      style: TextStyle(
                                                                          color: const Color
                                                                              .fromRGBO(
                                                                              21,
                                                                              43,
                                                                              81,
                                                                              1),
                                                                          fontWeight: FontWeight
                                                                              .bold,
                                                                          fontSize:
                                                                              MediaQuery.of(context).size.width * .045),
                                                                    ),
                                                                  ),
                                                                ),
                                                                Flexible(
                                                                  child:
                                                                      ElevatedButton(
                                                                    onPressed:
                                                                        () {
                                                                      setState(
                                                                          () {
                                                                        showEditForm =
                                                                            true;
                                                                      });
                                                                    },
                                                                    child: Text(
                                                                      "Edit", // Updated text to differentiate from the first one
                                                                      style: TextStyle(
                                                                          color: Colors
                                                                              .white,
                                                                          fontWeight: FontWeight
                                                                              .bold,
                                                                          fontSize:
                                                                              MediaQuery.of(context).size.width * .045),
                                                                    ),
                                                                    style: ElevatedButton
                                                                        .styleFrom(
                                                                            // Button color
                                                                            backgroundColor:
                                                                                blueColor),
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                            const SizedBox(
                                                              height: 10,
                                                            ),
                                                            // Unit ID
                                                            const Row(
                                                              children: [
                                                                SizedBox(
                                                                  width: 2,
                                                                ),
                                                                Text(
                                                                  "Applicant Name",
                                                                  style: TextStyle(
                                                                      color: Color(
                                                                          0xFF8A95A8),
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .bold,
                                                                      fontSize:
                                                                          12),
                                                                ),
                                                              ],
                                                            ),
                                                            const SizedBox(
                                                              height: 5,
                                                            ),
                                                            Row(
                                                              children: [
                                                                const SizedBox(
                                                                    width: 2),
                                                                Text(
                                                                  '${data.applicantFirstName} ${data.applicantLastName}',
                                                                  style:
                                                                       TextStyle(
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                    color: blueColor


,
                                                                  ),
                                                                ),
                                                                const SizedBox(
                                                                    width: 2),
                                                              ],
                                                            ),
                                                            const SizedBox(
                                                              height: 18,
                                                            ),
                                                            // Rental Owner
                                                            const Row(
                                                              children: [
                                                                SizedBox(
                                                                  width: 2,
                                                                ),
                                                                Text(
                                                                  "Applicant Birth Date",
                                                                  style: TextStyle(
                                                                      color: Color(
                                                                          0xFF8A95A8),
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .bold,
                                                                      fontSize:
                                                                          12),
                                                                ),
                                                              ],
                                                            ),
                                                            const SizedBox(
                                                              height: 5,
                                                            ),
                                                            Row(
                                                              children: [
                                                                const SizedBox(
                                                                    width: 2),
                                                                Text(
                                                                  '${data.applicantCity ?? 'N/A'}',
                                                                  style:
                                                                       TextStyle(
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                    color: blueColor


,
                                                                  ),
                                                                ),
                                                                const SizedBox(
                                                                    width: 2),
                                                              ],
                                                            ),
                                                            const SizedBox(
                                                              height: 18,
                                                            ),
                                                            // Tenant
                                                            const Row(
                                                              children: [
                                                                SizedBox(
                                                                  width: 2,
                                                                ),
                                                                Text(
                                                                  "Applicant Current Address",
                                                                  style: TextStyle(
                                                                      color: Color(
                                                                          0xFF8A95A8),
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .bold,
                                                                      fontSize:
                                                                          12),
                                                                ),
                                                              ],
                                                            ),
                                                            const SizedBox(
                                                              height: 5,
                                                            ),
                                                            Row(
                                                              children: [
                                                                const SizedBox(
                                                                    width: 2),
                                                                Text(
                                                                  '${data.applicantStreetAddress ?? 'N/A'}',
                                                                  style:
                                                                       TextStyle(
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                    color: blueColor


,
                                                                  ),
                                                                ),
                                                                const SizedBox(
                                                                    width: 2),
                                                              ],
                                                            ),

                                                            const SizedBox(
                                                              height: 18,
                                                            ),
                                                            // Tenant
                                                            const Row(
                                                              children: [
                                                                SizedBox(
                                                                  width: 2,
                                                                ),
                                                                Text(
                                                                  "Applicant Email",
                                                                  style: TextStyle(
                                                                      color: Color(
                                                                          0xFF8A95A8),
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .bold,
                                                                      fontSize:
                                                                          12),
                                                                ),
                                                              ],
                                                            ),
                                                            const SizedBox(
                                                              height: 5,
                                                            ),
                                                            Row(
                                                              children: [
                                                                const SizedBox(
                                                                    width: 2),
                                                                Text(
                                                                  '${data.applicantEmail ?? 'N/A'}',
                                                                  style:
                                                                       TextStyle(
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                    color: blueColor


,
                                                                  ),
                                                                ),
                                                                const SizedBox(
                                                                    width: 2),
                                                              ],
                                                            ),
                                                            const SizedBox(
                                                              height: 18,
                                                            ),
                                                            // Tenant
                                                            const Row(
                                                              children: [
                                                                SizedBox(
                                                                  width: 2,
                                                                ),
                                                                Text(
                                                                  "Applicant Phone",
                                                                  style: TextStyle(
                                                                      color: Color(
                                                                          0xFF8A95A8),
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .bold,
                                                                      fontSize:
                                                                          12),
                                                                ),
                                                              ],
                                                            ),
                                                            const SizedBox(
                                                              height: 5,
                                                            ),
                                                            Row(
                                                              children: [
                                                                const SizedBox(
                                                                    width: 2),
                                                                Text(
                                                                  formatPhoneNumber('${data.applicantPhoneNumber}',),
                                                                  // '${data.applicantPhoneNumber ?? 'N/A'}',
                                                                  style:
                                                                       TextStyle(
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                    color: blueColor


,
                                                                  ),
                                                                ),
                                                                const SizedBox(
                                                                    width: 2),
                                                              ],
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),

                                                // Add more fields as needed
                                              ],
                                            );
                                          }),
                            const SizedBox(
                              height: 16.0,
                            ),
                            data!.rentalHistory != null
                                ? Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.all(0.0),
                                        child: Material(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              border: Border.all(
                                                  color: blueColor


),
                                            ),
                                            child: Padding(
                                              padding: const EdgeInsets.only(
                                                  left: 16,
                                                  right: 16,
                                                  top: 16,
                                                  bottom: 16),
                                              child: Column(
                                                children: [
                                                  Row(
                                                    children: [
                                                      const SizedBox(
                                                        width: 2,
                                                      ),
                                                      Text(
                                                        "Rental History",
                                                        style: TextStyle(
                                                            color: const Color
                                                                .fromRGBO(
                                                                21, 43, 81, 1),
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: MediaQuery.of(
                                                                        context)
                                                                    .size
                                                                    .width *
                                                                .045),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(
                                                    height: 10,
                                                  ),
                                                  // Unit ID
                                                  const Row(
                                                    children: [
                                                      SizedBox(
                                                        width: 2,
                                                      ),
                                                      Text(
                                                        "Rental Address",
                                                        style: TextStyle(
                                                            color: Color(
                                                                0xFF8A95A8),
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 12),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(
                                                    height: 5,
                                                  ),
                                                  Row(
                                                    children: [
                                                      const SizedBox(width: 2),
                                                      Flexible(
                                                        child: Text(
                                                          '${(data.rentalHistory?.rentalAdress ?? 'N/A').isEmpty ? 'N/A' : data.rentalHistory!.rentalAdress}, '
                                                          '${(data.rentalHistory?.rentalCity ?? 'N/A').isEmpty ? 'N/A' : data.rentalHistory!.rentalCity}, '
                                                          '${(data.rentalHistory?.rentalState ?? 'N/A').isEmpty ? 'N/A' : data.rentalHistory!.rentalState}, '
                                                          '${(data.rentalHistory?.rentalCountry ?? 'N/A').isEmpty ? 'N/A' : data.rentalHistory!.rentalCountry}, '
                                                          '${(data.rentalHistory?.rentalPostcode ?? 'N/A').isEmpty ? 'N/A' : data.rentalHistory!.rentalPostcode}',
                                                          style:
                                                              const TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color:
                                                                Color.fromRGBO(
                                                                    21,
                                                                    43,
                                                                    83,
                                                                    1),
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 2),
                                                    ],
                                                  ),
                                                  const SizedBox(
                                                    height: 24,
                                                  ),
// Rental Owner
                                                  Row(
                                                    children: [
                                                      Expanded(
                                                        child: Container(
                                                          child: Column(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                              const SizedBox(
                                                                width: 2,
                                                              ),
                                                              const Text(
                                                                "Rental Dates",
                                                                style: TextStyle(
                                                                    color: Color(
                                                                        0xFF8A95A8),
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                    fontSize:
                                                                        12),
                                                              ),
                                                              const SizedBox(
                                                                height: 5,
                                                              ),
                                                              Text(
                                                                '${(data.rentalHistory?.startDate ?? 'N/A').isEmpty ? 'N/A' : data.rentalHistory!.startDate} to ${(data.rentalHistory?.endDate ?? 'N/A').isEmpty ? 'N/A' : data.rentalHistory!.endDate}',
                                                                style:
                                                                    const TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  color: Color
                                                                      .fromRGBO(
                                                                          21,
                                                                          43,
                                                                          83,
                                                                          1),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                      Expanded(
                                                        child: Container(
                                                          child: Column(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                              const SizedBox(
                                                                width: 2,
                                                              ),
                                                              const Text(
                                                                "Monthly Rent",
                                                                style: TextStyle(
                                                                    color: Color(
                                                                        0xFF8A95A8),
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                    fontSize:
                                                                        12),
                                                              ),
                                                              const SizedBox(
                                                                height: 5,
                                                              ),
                                                              Text(
                                                                '${(data.rentalHistory?.rent ?? 'N/A').isEmpty ? 'N/A' : data.rentalHistory!.rent}',
                                                                style:
                                                                    const TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  color: Color
                                                                      .fromRGBO(
                                                                          21,
                                                                          43,
                                                                          83,
                                                                          1),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(
                                                    height: 24,
                                                  ),
// Tenant
                                                  Row(
                                                    children: [
                                                      Expanded(
                                                        child: Container(
                                                          child: Column(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                              const SizedBox(
                                                                width: 2,
                                                              ),
                                                              const Text(
                                                                "Reason of Leaving",
                                                                style: TextStyle(
                                                                    color: Color(
                                                                        0xFF8A95A8),
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                    fontSize:
                                                                        12),
                                                              ),
                                                              const SizedBox(
                                                                height: 5,
                                                              ),
                                                              Text(
                                                                '${(data.rentalHistory?.leavingReason ?? 'N/A').isEmpty ? 'N/A' : data.rentalHistory!.leavingReason}',
                                                                style:
                                                                    const TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  color: Color
                                                                      .fromRGBO(
                                                                          21,
                                                                          43,
                                                                          83,
                                                                          1),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                      Expanded(
                                                        child: Container(
                                                          child: Column(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                              const SizedBox(
                                                                width: 2,
                                                              ),
                                                              const Text(
                                                                "Rental Owner Name",
                                                                style: TextStyle(
                                                                    color: Color(
                                                                        0xFF8A95A8),
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                    fontSize:
                                                                        12),
                                                              ),
                                                              const SizedBox(
                                                                height: 5,
                                                              ),
                                                              Text(
                                                                '${(data.rentalHistory?.rentalOwnerFirstName ?? 'N/A').isEmpty ? 'N/A' : data.rentalHistory!.rentalOwnerFirstName} ${(data.rentalHistory?.rentalOwnerLastName ?? 'N/A').isEmpty ? 'N/A' : data.rentalHistory!.rentalOwnerLastName}',
                                                                style:
                                                                    const TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  color: Color
                                                                      .fromRGBO(
                                                                          21,
                                                                          43,
                                                                          83,
                                                                          1),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),

                                                  const SizedBox(
                                                    height: 24,
                                                  ),
                                                  Row(
                                                    children: [
                                                      Expanded(
                                                        child: Container(
                                                          child: Column(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                              const SizedBox(
                                                                width: 2,
                                                              ),
                                                              const Text(
                                                                "Rental Owner Phone",
                                                                style: TextStyle(
                                                                    color: Color(
                                                                        0xFF8A95A8),
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                    fontSize:
                                                                        12),
                                                              ),
                                                              const SizedBox(
                                                                height: 5,
                                                              ),
                                                              Text(
                                                                formatPhoneNumber('${data.rentalHistory!.rentalOwnerPhoneNumber}',),
                                                                // '${data.rentalHistory!.rentalOwnerPhoneNumber ?? 'N/A'}',
                                                                style:
                                                                    const TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  color: Color
                                                                      .fromRGBO(
                                                                          21,
                                                                          43,
                                                                          83,
                                                                          1),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                      Expanded(
                                                        child: Container(
                                                          child: Column(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                              const SizedBox(
                                                                width: 2,
                                                              ),
                                                              const Text(
                                                                "Rental Owner Email",
                                                                style: TextStyle(
                                                                    color: Color(
                                                                        0xFF8A95A8),
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                    fontSize:
                                                                        12),
                                                              ),
                                                              const SizedBox(
                                                                height: 5,
                                                              ),
                                                              Text(
                                                                '${data.rentalHistory!.rentalOwnerPrimaryEmail ?? 'N/A'}',
                                                                style:
                                                                    const TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  color: Color
                                                                      .fromRGBO(
                                                                          21,
                                                                          43,
                                                                          83,
                                                                          1),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(
                                                    height: 18,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                : showEditForm
                                    ? Container()
                                    : LayoutBuilder(
                                        builder: (context, constraint) {
                                        if (constraint.maxWidth > 600) {
                                          return Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Padding(
                                                padding:
                                                    const EdgeInsets.all(0.0),
                                                child: Material(
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                  child: Container(
                                                    decoration: BoxDecoration(
                                                      color: Colors.white,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              10),
                                                      border: Border.all(
                                                          color: blueColor


),
                                                    ),
                                                    child: Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                              left: 16,
                                                              right: 16,
                                                              top: 16,
                                                              bottom: 16),
                                                      child: Column(
                                                        children: [
                                                          Row(
                                                            children: [
                                                              const SizedBox(
                                                                width: 2,
                                                              ),
                                                              Text(
                                                                "Rental History",
                                                                style: TextStyle(
                                                                    color: const Color
                                                                        .fromRGBO(
                                                                        21,
                                                                        43,
                                                                        81,
                                                                        1),
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                    fontSize: MediaQuery.of(context)
                                                                            .size
                                                                            .width *
                                                                        .03),
                                                              ),
                                                            ],
                                                          ),
                                                          const SizedBox(
                                                            height: 10,
                                                          ),
                                                          // Unit ID
                                                          const Row(
                                                            children: [
                                                              SizedBox(
                                                                width: 2,
                                                              ),
                                                              Text(
                                                                "Rental Address",
                                                                style: TextStyle(
                                                                    color: Color(
                                                                        0xFF8A95A8),
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                    fontSize:
                                                                        18),
                                                              ),
                                                            ],
                                                          ),
                                                          const SizedBox(
                                                            height: 5,
                                                          ),
                                                          const Row(
                                                            children: [
                                                              SizedBox(
                                                                  width: 2),
                                                              Text(
                                                                'N/A',
                                                                style:
                                                                    TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  fontSize: 16,
                                                                  color: Color
                                                                      .fromRGBO(
                                                                          21,
                                                                          43,
                                                                          83,
                                                                          1),
                                                                ),
                                                              ),
                                                              SizedBox(
                                                                  width: 2),
                                                            ],
                                                          ),
                                                          const SizedBox(
                                                            height: 18,
                                                          ),
                                                          // Rental Owner
                                                          Row(
                                                            children: [
                                                              Expanded(
                                                                child:
                                                                    Container(
                                                                  child:
                                                                       Column(
                                                                    crossAxisAlignment:
                                                                        CrossAxisAlignment
                                                                            .start,
                                                                    children: [
                                                                      const SizedBox(
                                                                        width:
                                                                            2,
                                                                      ),
                                                                      const Text(
                                                                        "Rental Dates",
                                                                        style: TextStyle(
                                                                            color:
                                                                                Color(0xFF8A95A8),
                                                                            fontWeight: FontWeight.bold,
                                                                            fontSize: 18),
                                                                      ),
                                                                      const SizedBox(
                                                                        height:
                                                                            5,
                                                                      ),
                                                                      Text(
                                                                        'N/A',
                                                                        style:
                                                                            TextStyle(
                                                                          fontWeight:
                                                                              FontWeight.bold,
                                                                          fontSize:
                                                                              16,
                                                                          color: blueColor


,
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                ),
                                                              ),
                                                              Expanded(
                                                                child:
                                                                    Container(
                                                                  child:
                                                                       Column(
                                                                    crossAxisAlignment:
                                                                        CrossAxisAlignment
                                                                            .start,
                                                                    children: [
                                                                      const SizedBox(
                                                                        width:
                                                                            2,
                                                                      ),
                                                                      const Text(
                                                                        "Monthly Rent",
                                                                        style: TextStyle(
                                                                            color:
                                                                                Color(0xFF8A95A8),
                                                                            fontWeight: FontWeight.bold,
                                                                            fontSize: 18),
                                                                      ),
                                                                      const SizedBox(
                                                                        height:
                                                                            5,
                                                                      ),
                                                                      Text(
                                                                        'N/A',
                                                                        style:
                                                                            TextStyle(
                                                                          fontWeight:
                                                                              FontWeight.bold,
                                                                          fontSize:
                                                                              16,
                                                                          color: blueColor


,
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                          const SizedBox(
                                                            height: 18,
                                                          ),
                                                          Row(
                                                            children: [
                                                              Expanded(
                                                                child:
                                                                    Container(
                                                                  child:
                                                                       Column(
                                                                    crossAxisAlignment:
                                                                        CrossAxisAlignment
                                                                            .start,
                                                                    children: [
                                                                      const SizedBox(
                                                                        width:
                                                                            2,
                                                                      ),
                                                                      const Text(
                                                                        "Reason of Leaving",
                                                                        style: TextStyle(
                                                                            color:
                                                                                Color(0xFF8A95A8),
                                                                            fontWeight: FontWeight.bold,
                                                                            fontSize: 18),
                                                                      ),
                                                                      const SizedBox(
                                                                        height:
                                                                            5,
                                                                      ),
                                                                      Text(
                                                                        'N/A',
                                                                        style:
                                                                            TextStyle(
                                                                          fontWeight:
                                                                              FontWeight.bold,
                                                                          fontSize:
                                                                              16,
                                                                          color: blueColor


,
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                ),
                                                              ),
                                                              Expanded(
                                                                child:
                                                                    Container(
                                                                  child:
                                                                       Column(
                                                                    crossAxisAlignment:
                                                                        CrossAxisAlignment
                                                                            .start,
                                                                    children: [
                                                                      const SizedBox(
                                                                        width:
                                                                            2,
                                                                      ),
                                                                      const Text(
                                                                        "Rental Owner Name",
                                                                        style: TextStyle(
                                                                            color:
                                                                                Color(0xFF8A95A8),
                                                                            fontWeight: FontWeight.bold,
                                                                            fontSize: 18),
                                                                      ),
                                                                      const SizedBox(
                                                                        height:
                                                                            5,
                                                                      ),
                                                                      Text(
                                                                        'N/A',
                                                                        style:
                                                                            TextStyle(
                                                                          fontWeight:
                                                                              FontWeight.bold,
                                                                          fontSize:
                                                                              16,
                                                                          color: blueColor


,
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                ),
                                                              ),
                                                            ],
                                                          ),

                                                          const SizedBox(
                                                            height: 24,
                                                          ),
                                                          Row(
                                                            children: [
                                                              Expanded(
                                                                child:
                                                                    Container(
                                                                  child: Column(
                                                                    crossAxisAlignment:
                                                                        CrossAxisAlignment
                                                                            .start,
                                                                    children: [
                                                                      const SizedBox(
                                                                        width:
                                                                            2,
                                                                      ),
                                                                      const Text(
                                                                        "Rental Owner Phone",
                                                                        style: TextStyle(
                                                                            color:
                                                                                Color(0xFF8A95A8),
                                                                            fontWeight: FontWeight.bold,
                                                                            fontSize: 18),
                                                                      ),
                                                                      const SizedBox(
                                                                        height:
                                                                            5,
                                                                      ),
                                                                      Text(
                                                                        formatPhoneNumber( '${data.rentalHistory?.rentalOwnerPhoneNumber}'),
                                                                        // '${(data.rentalHistory?.rentalOwnerPhoneNumber ?? 'N/A').toString().isEmpty ? 'N/A' : 'N/A'}',
                                                                        style:
                                                                             TextStyle(
                                                                          fontWeight:
                                                                              FontWeight.bold,
                                                                          fontSize:
                                                                              16,
                                                                          color: blueColor


,
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                ),
                                                              ),
                                                              Expanded(
                                                                child:
                                                                    Container(
                                                                  child: Column(
                                                                    crossAxisAlignment:
                                                                        CrossAxisAlignment
                                                                            .start,
                                                                    children: [
                                                                      const SizedBox(
                                                                        width:
                                                                            2,
                                                                      ),
                                                                      const Text(
                                                                        "Rental Owner Email",
                                                                        style: TextStyle(
                                                                            color:
                                                                                Color(0xFF8A95A8),
                                                                            fontWeight: FontWeight.bold,
                                                                            fontSize: 18),
                                                                      ),
                                                                      const SizedBox(
                                                                        height:
                                                                            5,
                                                                      ),
                                                                      Text(
                                                                        '${(data.rentalHistory?.rentalOwnerPrimaryEmail ?? 'N/A').isEmpty ? 'N/A' : 'N/A'}',
                                                                        style:
                                                                             TextStyle(
                                                                          fontWeight:
                                                                              FontWeight.bold,
                                                                          fontSize:
                                                                              16,
                                                                          color: blueColor


,
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                ),
                                                              ),
                                                            ],
                                                          ),

                                                          const SizedBox(
                                                            height: 5,
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          );
                                        }
                                        return Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Padding(
                                              padding:
                                                  const EdgeInsets.all(0.0),
                                              child: Material(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                    color: Colors.white,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            10),
                                                    border: Border.all(
                                                        color: const Color
                                                            .fromRGBO(
                                                            21, 43, 81, 1)),
                                                  ),
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                            left: 16,
                                                            right: 16,
                                                            top: 16,
                                                            bottom: 16),
                                                    child: Column(
                                                      children: [
                                                        Row(
                                                          children: [
                                                            const SizedBox(
                                                              width: 2,
                                                            ),
                                                            Text(
                                                              "Rental History",
                                                              style: TextStyle(
                                                                  color: const Color
                                                                      .fromRGBO(
                                                                      21,
                                                                      43,
                                                                      81,
                                                                      1),
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  fontSize: MediaQuery.of(
                                                                              context)
                                                                          .size
                                                                          .width *
                                                                      .045),
                                                            ),
                                                          ],
                                                        ),
                                                        const SizedBox(
                                                          height: 10,
                                                        ),
                                                        // Unit ID
                                                        const Row(
                                                          children: [
                                                            SizedBox(
                                                              width: 2,
                                                            ),
                                                            Text(
                                                              "Rental Address",
                                                              style: TextStyle(
                                                                  color: Color(
                                                                      0xFF8A95A8),
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  fontSize: 12),
                                                            ),
                                                          ],
                                                        ),
                                                        const SizedBox(
                                                          height: 5,
                                                        ),
                                                         Row(
                                                          children: [
                                                            const SizedBox(width: 2),
                                                            Text(
                                                              'N/A',
                                                              style: TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                color: blueColor


,
                                                              ),
                                                            ),
                                                            const SizedBox(width: 2),
                                                          ],
                                                        ),
                                                        const SizedBox(
                                                          height: 18,
                                                        ),
                                                        // Rental Owner
                                                        Row(
                                                          children: [
                                                            Expanded(
                                                              child: Container(
                                                                child:
                                                                     Column(
                                                                  crossAxisAlignment:
                                                                      CrossAxisAlignment
                                                                          .start,
                                                                  children: [
                                                                    const SizedBox(
                                                                      width: 2,
                                                                    ),
                                                                    const Text(
                                                                      "Rental Dates",
                                                                      style: TextStyle(
                                                                          color: Color(
                                                                              0xFF8A95A8),
                                                                          fontWeight: FontWeight
                                                                              .bold,
                                                                          fontSize:
                                                                              12),
                                                                    ),
                                                                    const SizedBox(
                                                                      height: 5,
                                                                    ),
                                                                    Text(
                                                                      'N/A',
                                                                      style:
                                                                          TextStyle(
                                                                        fontWeight:
                                                                            FontWeight.bold,
                                                                        color: blueColor


,
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                            ),
                                                            Expanded(
                                                              child: Container(
                                                                child:
                                                                    Column(
                                                                  crossAxisAlignment:
                                                                      CrossAxisAlignment
                                                                          .start,
                                                                  children: [
                                                                    const SizedBox(
                                                                      width: 2,
                                                                    ),
                                                                    const Text(
                                                                      "Monthly Rent",
                                                                      style: TextStyle(
                                                                          color: Color(
                                                                              0xFF8A95A8),
                                                                          fontWeight: FontWeight
                                                                              .bold,
                                                                          fontSize:
                                                                              12),
                                                                    ),
                                                                    const SizedBox(
                                                                      height: 5,
                                                                    ),
                                                                    Text(
                                                                      'N/A',
                                                                      style:
                                                                          TextStyle(
                                                                        fontWeight:
                                                                            FontWeight.bold,
                                                                        color: blueColor


,
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                        const SizedBox(
                                                          height: 18,
                                                        ),
                                                        Row(
                                                          children: [
                                                            Expanded(
                                                              child: Container(
                                                                child:
                                                                     Column(
                                                                  crossAxisAlignment:
                                                                      CrossAxisAlignment
                                                                          .start,
                                                                  children: [
                                                                    const SizedBox(
                                                                      width: 2,
                                                                    ),
                                                                    const Text(
                                                                      "Reason of Leaving",
                                                                      style: TextStyle(
                                                                          color: Color(
                                                                              0xFF8A95A8),
                                                                          fontWeight: FontWeight
                                                                              .bold,
                                                                          fontSize:
                                                                              12),
                                                                    ),
                                                                    const SizedBox(
                                                                      height: 5,
                                                                    ),
                                                                    Text(
                                                                      'N/A',
                                                                      style:
                                                                          TextStyle(
                                                                        fontWeight:
                                                                            FontWeight.bold,
                                                                        color: blueColor


,
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                            ),
                                                            Expanded(
                                                              child: Container(
                                                                child:
                                                                     Column(
                                                                  crossAxisAlignment:
                                                                      CrossAxisAlignment
                                                                          .start,
                                                                  children: [
                                                                    const SizedBox(
                                                                      width: 2,
                                                                    ),
                                                                    const Text(
                                                                      "Rental Owner Name",
                                                                      style: TextStyle(
                                                                          color: Color(
                                                                              0xFF8A95A8),
                                                                          fontWeight: FontWeight
                                                                              .bold,
                                                                          fontSize:
                                                                              12),
                                                                    ),
                                                                    const SizedBox(
                                                                      height: 5,
                                                                    ),
                                                                    Text(
                                                                      'N/A',
                                                                      style:
                                                                          TextStyle(
                                                                        fontWeight:
                                                                            FontWeight.bold,
                                                                        color: blueColor


,
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        ),

                                                        const SizedBox(
                                                          height: 24,
                                                        ),
                                                        Row(
                                                          children: [
                                                            Expanded(
                                                              child: Container(
                                                                child: Column(
                                                                  crossAxisAlignment:
                                                                      CrossAxisAlignment
                                                                          .start,
                                                                  children: [
                                                                    const SizedBox(
                                                                      width: 2,
                                                                    ),
                                                                    const Text(
                                                                      "Rental Owner Phone",
                                                                      style: TextStyle(
                                                                          color: Color(
                                                                              0xFF8A95A8),
                                                                          fontWeight: FontWeight
                                                                              .bold,
                                                                          fontSize:
                                                                              12),
                                                                    ),
                                                                    const SizedBox(
                                                                      height: 5,
                                                                    ),
                                                                    Text(
                                                                      formatPhoneNumber( '${data.rentalHistory?.rentalOwnerPhoneNumber}'),
                                                                     // '${(data.rentalHistory?.rentalOwnerPhoneNumber ?? 'N/A').toString().isEmpty ? 'N/A' : 'N/A'}',
                                                                      style:
                                                                           TextStyle(
                                                                        fontWeight:
                                                                            FontWeight.bold,
                                                                        color: blueColor


,
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                            ),
                                                            Expanded(
                                                              child: Container(
                                                                child: Column(
                                                                  crossAxisAlignment:
                                                                      CrossAxisAlignment
                                                                          .start,
                                                                  children: [
                                                                    const SizedBox(
                                                                      width: 2,
                                                                    ),
                                                                    const Text(
                                                                      "Rental Owner Email",
                                                                      style: TextStyle(
                                                                          color: Color(
                                                                              0xFF8A95A8),
                                                                          fontWeight: FontWeight
                                                                              .bold,
                                                                          fontSize:
                                                                              12),
                                                                    ),
                                                                    const SizedBox(
                                                                      height: 5,
                                                                    ),
                                                                    Text(
                                                                      '${(data.rentalHistory?.rentalOwnerPrimaryEmail ?? 'N/A').isEmpty ? 'N/A' : 'N/A'}',
                                                                      style:
                                                                           TextStyle(
                                                                        fontWeight:
                                                                            FontWeight.bold,
                                                                        color: blueColor


,
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        ),

                                                        const SizedBox(
                                                          height: 5,
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        );
                                      }),
                            const SizedBox(
                              height: 16,
                            ),
                            data!.emergencyContact != null
                                ? Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.all(0.0),
                                        child: Material(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              border: Border.all(
                                                  color: blueColor


),
                                            ),
                                            child: Padding(
                                              padding: const EdgeInsets.only(
                                                  left: 16,
                                                  right: 16,
                                                  top: 16,
                                                  bottom: 16),
                                              child: Column(
                                                children: [
                                                  Row(
                                                    children: [
                                                      const SizedBox(
                                                        width: 2,
                                                      ),
                                                      Text(
                                                        "Emergency Contact Information",
                                                        style: TextStyle(
                                                            color: const Color
                                                                .fromRGBO(
                                                                21, 43, 81, 1),
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: MediaQuery.of(
                                                                        context)
                                                                    .size
                                                                    .width *
                                                                .045),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(
                                                    height: 10,
                                                  ),
                                                  // Unit ID
                                                  const Row(
                                                    children: [
                                                      SizedBox(
                                                        width: 2,
                                                      ),
                                                      Text(
                                                        "Emergency Contact Name",
                                                        style: TextStyle(
                                                            color: Color(
                                                                0xFF8A95A8),
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 12),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(
                                                    height: 5,
                                                  ),
                                                  Row(
                                                    children: [
                                                      const SizedBox(width: 2),
                                                      Text(
                                                        '${(data.emergencyContact?.firstName ?? 'N/A').isEmpty ? '' : data.emergencyContact!.firstName} ${(data.emergencyContact?.lastName ?? 'N/A').isEmpty ? 'N/A' : data.emergencyContact!.lastName}',
                                                        style:  TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: blueColor


,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 2),
                                                    ],
                                                  ),
                                                  const SizedBox(
                                                    height: 18,
                                                  ),
// Emergency Contact Relationship
                                                  const Row(
                                                    children: [
                                                      SizedBox(
                                                        width: 2,
                                                      ),
                                                      Text(
                                                        "Emergency Contact Relationship",
                                                        style: TextStyle(
                                                            color: Color(
                                                                0xFF8A95A8),
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 12),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(
                                                    height: 5,
                                                  ),
                                                  Row(
                                                    children: [
                                                      const SizedBox(width: 2),
                                                      Text(
                                                        '${(data.emergencyContact?.relationship ?? 'N/A').isEmpty ? 'N/A' : data.emergencyContact!.relationship}',
                                                        style:  TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: blueColor


,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 2),
                                                    ],
                                                  ),
                                                  const SizedBox(
                                                    height: 18,
                                                  ),
// Emergency Contact Email
                                                  const Row(
                                                    children: [
                                                      SizedBox(
                                                        width: 2,
                                                      ),
                                                      Text(
                                                        "Emergency Contact Email",
                                                        style: TextStyle(
                                                            color: Color(
                                                                0xFF8A95A8),
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 12),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(
                                                    height: 5,
                                                  ),
                                                  Row(
                                                    children: [
                                                      const SizedBox(width: 2),
                                                      Text(
                                                        '${(data.emergencyContact?.email ?? 'N/A').isEmpty ? 'N/A' : data.emergencyContact!.email}',
                                                        style:  TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: blueColor


,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 2),
                                                    ],
                                                  ),
                                                  const SizedBox(
                                                    height: 18,
                                                  ),
// Emergency Contact Phone
                                                  const Row(
                                                    children: [
                                                      SizedBox(
                                                        width: 2,
                                                      ),
                                                      Text(
                                                        "Emergency Contact Phone",
                                                        style: TextStyle(
                                                            color: Color(
                                                                0xFF8A95A8),
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 12),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(
                                                    height: 5,
                                                  ),
                                                  Row(
                                                    children: [
                                                      const SizedBox(width: 2),
                                                      Text(
                                                          formatPhoneNumber('${data.emergencyContact?.phoneNumber}'),
                                                       // '${(data.emergencyContact?.phoneNumber ?? 'N/A').toString().isEmpty ? 'N/A' : data.emergencyContact!.phoneNumber}',
                                                        style:  TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: blueColor


,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 2),
                                                    ],
                                                  ),
                                                  const SizedBox(
                                                    height: 18,
                                                  ),

                                                  const SizedBox(
                                                    height: 5,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                : showEditForm
                                    ? Container()
                                    : LayoutBuilder(
                                        builder: (context, contraints) {
                                        if (contraints.maxWidth > 600) {
                                          return Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Padding(
                                                padding:
                                                    const EdgeInsets.all(0.0),
                                                child: Material(
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                  child: Container(
                                                    decoration: BoxDecoration(
                                                      color: Colors.white,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              10),
                                                      border: Border.all(
                                                          color: blueColor


),
                                                    ),
                                                    child: Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                              left: 16,
                                                              right: 16,
                                                              top: 16,
                                                              bottom: 16),
                                                      child: Column(
                                                        children: [
                                                          Row(
                                                            children: [
                                                              const SizedBox(
                                                                width: 2,
                                                              ),
                                                              Text(
                                                                "Emergency Contact Information",
                                                                style: TextStyle(
                                                                    color: const Color
                                                                        .fromRGBO(
                                                                        21,
                                                                        43,
                                                                        81,
                                                                        1),
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                    fontSize: MediaQuery.of(context)
                                                                            .size
                                                                            .width *
                                                                        .03),
                                                              ),
                                                            ],
                                                          ),
                                                          const SizedBox(
                                                            height: 10,
                                                          ),
                                                          // Unit ID
                                                          Row(
                                                            children: [
                                                              Expanded(
                                                                child: Column(
                                                                  children: [
                                                                    const Row(
                                                                      children: [
                                                                        SizedBox(
                                                                          width:
                                                                              2,
                                                                        ),
                                                                        Text(
                                                                          "Emergency Contact Name",
                                                                          style: TextStyle(
                                                                              color: Color(0xFF8A95A8),
                                                                              fontWeight: FontWeight.bold,
                                                                              fontSize: 18),
                                                                        ),
                                                                      ],
                                                                    ),
                                                                    const SizedBox(
                                                                      height: 5,
                                                                    ),
                                                                     Row(
                                                                      children: [
                                                                        const SizedBox(
                                                                            width:
                                                                                2),
                                                                        Text(
                                                                          'N/A',
                                                                          style:
                                                                              TextStyle(
                                                                            fontWeight:
                                                                                FontWeight.bold,
                                                                            fontSize:
                                                                                16,
                                                                            color: blueColor


,
                                                                          ),
                                                                        ),
                                                                        const SizedBox(
                                                                            width:
                                                                                2),
                                                                      ],
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                              const SizedBox(
                                                                width: 18,
                                                              ),
                                                              Expanded(
                                                                child: Column(
                                                                  children: [
                                                                    const Row(
                                                                      children: [
                                                                        SizedBox(
                                                                          width:
                                                                              2,
                                                                        ),
                                                                        Text(
                                                                          "Emergency Contact Relationship",
                                                                          style: TextStyle(
                                                                              color: Color(0xFF8A95A8),
                                                                              fontWeight: FontWeight.bold,
                                                                              fontSize: 18),
                                                                        ),
                                                                      ],
                                                                    ),
                                                                    const SizedBox(
                                                                      height: 5,
                                                                    ),
                                                                     Row(
                                                                      children: [
                                                                        const SizedBox(
                                                                            width:
                                                                                2),
                                                                        Text(
                                                                          'N/A',
                                                                          style:
                                                                              TextStyle(
                                                                            fontWeight:
                                                                                FontWeight.bold,
                                                                            fontSize:
                                                                                16,
                                                                            color: blueColor


,
                                                                          ),
                                                                        ),
                                                                        const SizedBox(
                                                                            width:
                                                                                2),
                                                                      ],
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                            ],
                                                          ),

                                                          // Rental Owner

                                                          const SizedBox(
                                                            height: 18,
                                                          ),
                                                          // Tenant
                                                           Row(
                                                            children: [
                                                              Expanded(
                                                                child: Column(
                                                                  children: [
                                                                    const Row(
                                                                      children: [
                                                                        SizedBox(
                                                                          width:
                                                                              2,
                                                                        ),
                                                                        Text(
                                                                          "Emergency Contact Email",
                                                                          style: TextStyle(
                                                                              color: Color(0xFF8A95A8),
                                                                              fontWeight: FontWeight.bold,
                                                                              fontSize: 18),
                                                                        ),
                                                                      ],
                                                                    ),
                                                                    const SizedBox(
                                                                      height: 5,
                                                                    ),
                                                                    Row(
                                                                      children: [
                                                                        const SizedBox(
                                                                            width:
                                                                                2),
                                                                        Text(
                                                                          'N/A',
                                                                          style:
                                                                              TextStyle(
                                                                            fontWeight:
                                                                                FontWeight.bold,
                                                                            fontSize:
                                                                                16,
                                                                            color: blueColor


,
                                                                          ),
                                                                        ),
                                                                        const SizedBox(
                                                                            width:
                                                                                2),
                                                                      ],
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                              const SizedBox(
                                                                width: 18,
                                                              ),
                                                              // Tenant
                                                              Expanded(
                                                                child: Column(
                                                                  children: [
                                                                    const Row(
                                                                      children: [
                                                                        SizedBox(
                                                                          width:
                                                                              2,
                                                                        ),
                                                                        Text(
                                                                          "Emergency Contact Phone",
                                                                          style: TextStyle(
                                                                              color: Color(0xFF8A95A8),
                                                                              fontWeight: FontWeight.bold,
                                                                              fontSize: 18),
                                                                        ),
                                                                      ],
                                                                    ),
                                                                    const SizedBox(
                                                                      height: 5,
                                                                    ),
                                                                    Row(
                                                                      children: [
                                                                        const SizedBox(
                                                                            width:
                                                                                2),
                                                                        Text(
                                                                          'N/A',
                                                                          style:
                                                                              TextStyle(
                                                                            fontWeight:
                                                                                FontWeight.bold,
                                                                            fontSize:
                                                                                16,
                                                                            color: blueColor


,
                                                                          ),
                                                                        ),
                                                                        const SizedBox(
                                                                            width:
                                                                                2),
                                                                      ],
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                            ],
                                                          ),

                                                          const SizedBox(
                                                            height: 5,
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          );
                                        }
                                        return Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Padding(
                                              padding:
                                                  const EdgeInsets.all(0.0),
                                              child: Material(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                    color: Colors.white,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            10),
                                                    border: Border.all(
                                                        color: const Color
                                                            .fromRGBO(
                                                            21, 43, 81, 1)),
                                                  ),
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                            left: 16,
                                                            right: 16,
                                                            top: 16,
                                                            bottom: 16),
                                                    child: Column(
                                                      children: [
                                                        Row(
                                                          children: [
                                                            const SizedBox(
                                                              width: 2,
                                                            ),
                                                            Text(
                                                              "Emergency Contact Information",
                                                              style: TextStyle(
                                                                  color: const Color
                                                                      .fromRGBO(
                                                                      21,
                                                                      43,
                                                                      81,
                                                                      1),
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  fontSize: MediaQuery.of(
                                                                              context)
                                                                          .size
                                                                          .width *
                                                                      .045),
                                                            ),
                                                          ],
                                                        ),
                                                        const SizedBox(
                                                          height: 10,
                                                        ),
                                                        // Unit ID
                                                        const Row(
                                                          children: [
                                                            SizedBox(
                                                              width: 2,
                                                            ),
                                                            Text(
                                                              "Emergency Contact Name",
                                                              style: TextStyle(
                                                                  color: Color(
                                                                      0xFF8A95A8),
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  fontSize: 12),
                                                            ),
                                                          ],
                                                        ),
                                                        const SizedBox(
                                                          height: 5,
                                                        ),
                                                         Row(
                                                          children: [
                                                            const SizedBox(width: 2),
                                                            Text(
                                                              'N/A',
                                                              style: TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                color: blueColor


,
                                                              ),
                                                            ),
                                                            const SizedBox(width: 2),
                                                          ],
                                                        ),
                                                        const SizedBox(
                                                          height: 18,
                                                        ),
                                                        // Rental Owner
                                                        const Row(
                                                          children: [
                                                            SizedBox(
                                                              width: 2,
                                                            ),
                                                            Text(
                                                              "Emergency Contact Relationship",
                                                              style: TextStyle(
                                                                  color: Color(
                                                                      0xFF8A95A8),
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  fontSize: 12),
                                                            ),
                                                          ],
                                                        ),
                                                        const SizedBox(
                                                          height: 5,
                                                        ),
                                                         Row(
                                                          children: [
                                                            const SizedBox(width: 2),
                                                            Text(
                                                              'N/A',
                                                              style: TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                color: blueColor


,
                                                              ),
                                                            ),
                                                            const SizedBox(width: 2),
                                                          ],
                                                        ),
                                                        const SizedBox(
                                                          height: 18,
                                                        ),
                                                        // Tenant
                                                        const Row(
                                                          children: [
                                                            SizedBox(
                                                              width: 2,
                                                            ),
                                                            Text(
                                                              "Emergency Contact Email",
                                                              style: TextStyle(
                                                                  color: Color(
                                                                      0xFF8A95A8),
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  fontSize: 12),
                                                            ),
                                                          ],
                                                        ),
                                                        const SizedBox(
                                                          height: 5,
                                                        ),
                                                         Row(
                                                          children: [
                                                            const SizedBox(width: 2),
                                                            Text(
                                                              'N/A',
                                                              style: TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                color: blueColor


,
                                                              ),
                                                            ),
                                                            const SizedBox(width: 2),
                                                          ],
                                                        ),
                                                        const SizedBox(
                                                          height: 18,
                                                        ),
                                                        // Tenant
                                                        const Row(
                                                          children: [
                                                            SizedBox(
                                                              width: 2,
                                                            ),
                                                            Text(
                                                              "Emergency Contact Phone",
                                                              style: TextStyle(
                                                                  color: Color(
                                                                      0xFF8A95A8),
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  fontSize: 12),
                                                            ),
                                                          ],
                                                        ),
                                                        const SizedBox(
                                                          height: 5,
                                                        ),
                                                         Row(
                                                          children: [
                                                            const SizedBox(width: 2),
                                                            Text(
                                                              'N/A',
                                                              style: TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                color: blueColor


,
                                                              ),
                                                            ),
                                                            const SizedBox(width: 2),
                                                          ],
                                                        ),
                                                        const SizedBox(
                                                          height: 5,
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        );
                                      }),
                            const SizedBox(
                              height: 16,
                            ),
                            data!.employment != null
                                ? Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.all(0.0),
                                        child: Material(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              border: Border.all(
                                                  color: blueColor


),
                                            ),
                                            child: Padding(
                                              padding: const EdgeInsets.only(
                                                  left: 16,
                                                  right: 16,
                                                  top: 16,
                                                  bottom: 16),
                                              child: Column(
                                                children: [
                                                  Row(
                                                    children: [
                                                      const SizedBox(
                                                        width: 2,
                                                      ),
                                                      Text(
                                                        "Employment",
                                                        style: TextStyle(
                                                            color: const Color
                                                                .fromRGBO(
                                                                21, 43, 81, 1),
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: MediaQuery.of(
                                                                        context)
                                                                    .size
                                                                    .width *
                                                                .045),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(
                                                    height: 10,
                                                  ),
                                                  // Unit ID
                                                  const Row(
                                                    children: [
                                                      SizedBox(
                                                        width: 2,
                                                      ),
                                                      Text(
                                                        "Employer Address",
                                                        style: TextStyle(
                                                            color: Color(
                                                                0xFF8A95A8),
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 12),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(
                                                    height: 5,
                                                  ),
                                                  Row(
                                                    children: [
                                                      const SizedBox(width: 2),
                                                      Flexible(
                                                        child: Text(
                                                          '${(data.employment?.streetAddress?.isEmpty ?? true) ? 'N/A' : data.employment!.streetAddress}, '
                                                          '${(data.employment?.city?.isEmpty ?? true) ? 'N/A' : data.employment!.city}, '
                                                          '${(data.employment?.state?.isEmpty ?? true) ? 'N/A' : data.employment!.state}, '
                                                          '${(data.employment?.country?.isEmpty ?? true) ? 'N/A' : data.employment!.country}, '
                                                          '${(data.employment?.postalCode?.isEmpty ?? true) ? 'N/A' : data.employment!.postalCode}',
                                                          style:
                                                              const TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color:
                                                                Color.fromRGBO(
                                                                    21,
                                                                    43,
                                                                    83,
                                                                    1),
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 2),
                                                    ],
                                                  ),
                                                  const SizedBox(
                                                    height: 24,
                                                  ),
                                                  Row(
                                                    children: [
                                                      Expanded(
                                                        child: Container(
                                                          child: Column(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                              const SizedBox(
                                                                width: 2,
                                                              ),
                                                              const Text(
                                                                "Employer Name",
                                                                style: TextStyle(
                                                                    color: Color(
                                                                        0xFF8A95A8),
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                    fontSize:
                                                                        12),
                                                              ),
                                                              const SizedBox(
                                                                height: 5,
                                                              ),
                                                              Text(
                                                                '${(data.employment?.name?.isEmpty ?? true) ? 'N/A' : data.employment!.name}',
                                                                style:
                                                                    const TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  color: Color
                                                                      .fromRGBO(
                                                                          21,
                                                                          43,
                                                                          83,
                                                                          1),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                      Expanded(
                                                        child: Container(
                                                          child: Column(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                              const SizedBox(
                                                                width: 2,
                                                              ),
                                                              const Text(
                                                                "Employer Phone Number",
                                                                style: TextStyle(
                                                                    color: Color(
                                                                        0xFF8A95A8),
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                    fontSize:
                                                                        12),
                                                              ),
                                                              const SizedBox(
                                                                height: 5,
                                                              ),
                                                              Text(
          formatPhoneNumber('${data.employment?.employmentPhoneNumber}'),
                                                                // '${(data.employment?.employmentPhoneNumber?.toString().isEmpty ?? true) ? 'N/A' : data.employment!.employmentPhoneNumber}',
                                                                style:
                                                                    const TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  color: Color
                                                                      .fromRGBO(
                                                                          21,
                                                                          43,
                                                                          83,
                                                                          1),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(
                                                    height: 24,
                                                  ),
                                                  Row(
                                                    children: [
                                                      Expanded(
                                                        child: Container(
                                                          child: Column(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                              const SizedBox(
                                                                width: 2,
                                                              ),
                                                              const Text(
                                                                "Employer Email",
                                                                style: TextStyle(
                                                                    color: Color(
                                                                        0xFF8A95A8),
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                    fontSize:
                                                                        12),
                                                              ),
                                                              const SizedBox(
                                                                height: 5,
                                                              ),
                                                              Text(
                                                                '${(data.employment?.employmentPrimaryEmail?.isEmpty ?? true) ? 'N/A' : data.employment!.employmentPrimaryEmail}',
                                                                style:
                                                                    const TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  color: Color
                                                                      .fromRGBO(
                                                                          21,
                                                                          43,
                                                                          83,
                                                                          1),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                      Expanded(
                                                        child: Container(
                                                          child: Column(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                              const SizedBox(
                                                                width: 2,
                                                              ),
                                                              const Text(
                                                                "Employer Position",
                                                                style: TextStyle(
                                                                    color: Color(
                                                                        0xFF8A95A8),
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                    fontSize:
                                                                        12),
                                                              ),
                                                              const SizedBox(
                                                                height: 5,
                                                              ),
                                                              Text(
                                                                '${(data.employment?.employmentPosition?.isEmpty ?? true) ? 'N/A' : data.employment!.employmentPosition}',
                                                                style:
                                                                    const TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  color: Color
                                                                      .fromRGBO(
                                                                          21,
                                                                          43,
                                                                          83,
                                                                          1),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(
                                                    height: 24,
                                                  ),
                                                  Row(
                                                    children: [
                                                      Expanded(
                                                        child: Container(
                                                          child: Column(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                              const SizedBox(
                                                                width: 2,
                                                              ),
                                                              const Text(
                                                                "Supervisor Name",
                                                                style: TextStyle(
                                                                    color: Color(
                                                                        0xFF8A95A8),
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                    fontSize:
                                                                        12),
                                                              ),
                                                              const SizedBox(
                                                                height: 5,
                                                              ),
                                                              Text(
                                                                '${(data.employment?.supervisorFirstName?.isEmpty ?? true) ? 'N/A' : data.employment!.supervisorFirstName} '
                                                                '${(data.employment?.supervisorLastName?.isEmpty ?? true) ? 'N/A' : data.employment!.supervisorLastName}',
                                                                style:
                                                                    const TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  color: Color
                                                                      .fromRGBO(
                                                                          21,
                                                                          43,
                                                                          83,
                                                                          1),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                      Expanded(
                                                        child: Container(
                                                          child: Column(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                              const SizedBox(
                                                                width: 2,
                                                              ),
                                                              const Text(
                                                                "Supervisor Title",
                                                                style: TextStyle(
                                                                    color: Color(
                                                                        0xFF8A95A8),
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                    fontSize:
                                                                        12),
                                                              ),
                                                              const SizedBox(
                                                                height: 5,
                                                              ),
                                                              Text(
                                                                '${(data.employment?.supervisorTitle?.isEmpty ?? true) ? 'N/A' : data.employment!.supervisorTitle}',
                                                                style:
                                                                    const TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  color: Color
                                                                      .fromRGBO(
                                                                          21,
                                                                          43,
                                                                          83,
                                                                          1),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),

                                                  // Tenant
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                : showEditForm
                                    ? Container()
                                    : LayoutBuilder(
                                        builder: (context, contraints) {
                                        if (contraints.maxWidth > 500) {
                                          return Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Padding(
                                                padding:
                                                    const EdgeInsets.all(0.0),
                                                child: Material(
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                  child: Container(
                                                    decoration: BoxDecoration(
                                                      color: Colors.white,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              10),
                                                      border: Border.all(
                                                          color: blueColor


),
                                                    ),
                                                    child: Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                              left: 16,
                                                              right: 16,
                                                              top: 16,
                                                              bottom: 16),
                                                      child: Column(
                                                        children: [
                                                          Row(
                                                            children: [
                                                              const SizedBox(
                                                                width: 2,
                                                              ),
                                                              Text(
                                                                "Employment",
                                                                style: TextStyle(
                                                                    color: const Color
                                                                        .fromRGBO(
                                                                        21,
                                                                        43,
                                                                        81,
                                                                        1),
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                    fontSize: MediaQuery.of(context)
                                                                            .size
                                                                            .width *
                                                                        .03),
                                                              ),
                                                            ],
                                                          ),
                                                          const SizedBox(
                                                            height: 10,
                                                          ),
                                                          // Unit ID
                                                          const SizedBox(
                                                            height: 10,
                                                          ),
                                                          // Unit ID
                                                          const Row(
                                                            children: [
                                                              SizedBox(
                                                                width: 2,
                                                              ),
                                                              Text(
                                                                "Employer Address",
                                                                style: TextStyle(
                                                                    color: Color(
                                                                        0xFF8A95A8),
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                    fontSize:
                                                                        18),
                                                              ),
                                                            ],
                                                          ),
                                                          const SizedBox(
                                                            height: 5,
                                                          ),
                                                          const Row(
                                                            children: [
                                                              SizedBox(
                                                                  width: 2),
                                                              Text(
                                                                'N/A',
                                                                style:
                                                                    TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  fontSize: 16,
                                                                  color: Color
                                                                      .fromRGBO(
                                                                          21,
                                                                          43,
                                                                          83,
                                                                          1),
                                                                ),
                                                              ),
                                                              SizedBox(
                                                                  width: 2),
                                                            ],
                                                          ),
                                                          const SizedBox(
                                                            height: 10,
                                                          ),
                                                          const SizedBox(
                                                            height: 18,
                                                          ),
                                                          Row(
                                                            children: [
                                                              Expanded(
                                                                child:
                                                                    Container(
                                                                  child:
                                                                       Column(
                                                                    crossAxisAlignment:
                                                                        CrossAxisAlignment
                                                                            .start,
                                                                    children: [
                                                                      const SizedBox(
                                                                        width:
                                                                            2,
                                                                      ),
                                                                      const Text(
                                                                        "Employer Name",
                                                                        style: TextStyle(
                                                                            color:
                                                                                Color(0xFF8A95A8),
                                                                            fontWeight: FontWeight.bold,
                                                                            fontSize: 18),
                                                                      ),
                                                                      const SizedBox(
                                                                        height:
                                                                            5,
                                                                      ),
                                                                      Text(
                                                                        'N/A',
                                                                        style:
                                                                            TextStyle(
                                                                          fontWeight:
                                                                              FontWeight.bold,
                                                                          fontSize:
                                                                              16,
                                                                          color: blueColor


,
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                ),
                                                              ),
                                                              Expanded(
                                                                child:
                                                                    Container(
                                                                  child:
                                                                       Column(
                                                                    crossAxisAlignment:
                                                                        CrossAxisAlignment
                                                                            .start,
                                                                    children: [
                                                                      const SizedBox(
                                                                        width:
                                                                            2,
                                                                      ),
                                                                      const Text(
                                                                        "Employer Phone Number",
                                                                        style: TextStyle(
                                                                            color:
                                                                                Color(0xFF8A95A8),
                                                                            fontWeight: FontWeight.bold,
                                                                            fontSize: 18),
                                                                      ),
                                                                      const SizedBox(
                                                                        height:
                                                                            5,
                                                                      ),
                                                                      Text(
                                                                        'N/A',
                                                                        style:
                                                                            TextStyle(
                                                                          fontWeight:
                                                                              FontWeight.bold,
                                                                          fontSize:
                                                                              16,
                                                                          color: blueColor


,
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                ),
                                                              ),
                                                            ],
                                                          ),

                                                          // Unit ID

                                                          const SizedBox(
                                                            height: 18,
                                                          ),
                                                          Row(
                                                            children: [
                                                              Expanded(
                                                                child:
                                                                    Container(
                                                                  child:
                                                                       Column(
                                                                    crossAxisAlignment:
                                                                        CrossAxisAlignment
                                                                            .start,
                                                                    children: [
                                                                      const SizedBox(
                                                                        width:
                                                                            2,
                                                                      ),
                                                                      const Text(
                                                                        "Employer Email",
                                                                        style: TextStyle(
                                                                            color:
                                                                                Color(0xFF8A95A8),
                                                                            fontWeight: FontWeight.bold,
                                                                            fontSize: 18),
                                                                      ),
                                                                      const SizedBox(
                                                                        height:
                                                                            5,
                                                                      ),
                                                                      Text(
                                                                        'N/A',
                                                                        style:
                                                                            TextStyle(
                                                                          fontWeight:
                                                                              FontWeight.bold,
                                                                          fontSize:
                                                                              16,
                                                                          color: blueColor


,
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                ),
                                                              ),
                                                              Expanded(
                                                                child:
                                                                    Container(
                                                                  child:
                                                                       Column(
                                                                    crossAxisAlignment:
                                                                        CrossAxisAlignment
                                                                            .start,
                                                                    children: [
                                                                      const SizedBox(
                                                                        width:
                                                                            2,
                                                                      ),
                                                                      const Text(
                                                                        "Position Held",
                                                                        style: TextStyle(
                                                                            color:
                                                                                Color(0xFF8A95A8),
                                                                            fontWeight: FontWeight.bold,
                                                                            fontSize: 18),
                                                                      ),
                                                                      const SizedBox(
                                                                        height:
                                                                            5,
                                                                      ),
                                                                      Text(
                                                                        'N/A',
                                                                        style:
                                                                            TextStyle(
                                                                          fontWeight:
                                                                              FontWeight.bold,
                                                                          fontSize:
                                                                              16,
                                                                          color: blueColor


,
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                ),
                                                              ),
                                                            ],
                                                          ),

                                                          const SizedBox(
                                                            height: 18,
                                                          ),
                                                          Row(
                                                            children: [
                                                              Expanded(
                                                                child:
                                                                    Container(
                                                                  child:
                                                                       Column(
                                                                    crossAxisAlignment:
                                                                        CrossAxisAlignment
                                                                            .start,
                                                                    children: [
                                                                      const SizedBox(
                                                                        width:
                                                                            2,
                                                                      ),
                                                                      const Text(
                                                                        "Supervisor Title",
                                                                        style: TextStyle(
                                                                            color:
                                                                                Color(0xFF8A95A8),
                                                                            fontWeight: FontWeight.bold,
                                                                            fontSize: 12),
                                                                      ),
                                                                      const SizedBox(
                                                                        height:
                                                                            5,
                                                                      ),
                                                                      Text(
                                                                        'N/A',
                                                                        style:
                                                                            TextStyle(
                                                                          fontWeight:
                                                                              FontWeight.bold,
                                                                          fontSize:
                                                                              16,
                                                                          color: blueColor


,
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                ),
                                                              ),
                                                              Expanded(
                                                                child:
                                                                    Container(
                                                                  child:
                                                                       Column(
                                                                    crossAxisAlignment:
                                                                        CrossAxisAlignment
                                                                            .start,
                                                                    children: [
                                                                      const SizedBox(
                                                                        width:
                                                                            2,
                                                                      ),
                                                                      const Text(
                                                                        "Supervisor Name",
                                                                        style: TextStyle(
                                                                            color:
                                                                                Color(0xFF8A95A8),
                                                                            fontWeight: FontWeight.bold,
                                                                            fontSize: 18),
                                                                      ),
                                                                      const SizedBox(
                                                                        height:
                                                                            5,
                                                                      ),
                                                                      Text(
                                                                        'N/A',
                                                                        style:
                                                                            TextStyle(
                                                                          fontWeight:
                                                                              FontWeight.bold,
                                                                          fontSize:
                                                                              16,
                                                                          color: blueColor


,
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                ),
                                                              ),
                                                            ],
                                                          ),

                                                          const SizedBox(
                                                            height: 5,
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          );
                                        }
                                        return Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Padding(
                                              padding:
                                                  const EdgeInsets.all(0.0),
                                              child: Material(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                    color: Colors.white,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            10),
                                                    border: Border.all(
                                                        color: const Color
                                                            .fromRGBO(
                                                            21, 43, 81, 1)),
                                                  ),
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                            left: 16,
                                                            right: 16,
                                                            top: 16,
                                                            bottom: 16),
                                                    child: Column(
                                                      children: [
                                                        Row(
                                                          children: [
                                                            const SizedBox(
                                                              width: 2,
                                                            ),
                                                            Text(
                                                              "Employment",
                                                              style: TextStyle(
                                                                  color: const Color
                                                                      .fromRGBO(
                                                                      21,
                                                                      43,
                                                                      81,
                                                                      1),
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  fontSize: MediaQuery.of(
                                                                              context)
                                                                          .size
                                                                          .width *
                                                                      .045),
                                                            ),
                                                          ],
                                                        ),
                                                        const SizedBox(
                                                          height: 10,
                                                        ),
                                                        // Unit ID
                                                        const SizedBox(
                                                          height: 10,
                                                        ),
                                                        // Unit ID
                                                        const Row(
                                                          children: [
                                                            SizedBox(
                                                              width: 2,
                                                            ),
                                                            Text(
                                                              "Employer Address",
                                                              style: TextStyle(
                                                                  color: Color(
                                                                      0xFF8A95A8),
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  fontSize: 12),
                                                            ),
                                                          ],
                                                        ),
                                                        const SizedBox(
                                                          height: 5,
                                                        ),
                                                         Row(
                                                          children: [
                                                            const SizedBox(width: 2),
                                                            Text(
                                                              'N/A',
                                                              style: TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                color: blueColor


,
                                                              ),
                                                            ),
                                                            const SizedBox(width: 2),
                                                          ],
                                                        ),
                                                        const SizedBox(
                                                          height: 10,
                                                        ),
                                                        const SizedBox(
                                                          height: 18,
                                                        ),
                                                        Row(
                                                          children: [
                                                            Expanded(
                                                              child: Container(
                                                                child:
                                                                     Column(
                                                                  crossAxisAlignment:
                                                                      CrossAxisAlignment
                                                                          .start,
                                                                  children: [
                                                                    const SizedBox(
                                                                      width: 2,
                                                                    ),
                                                                    const Text(
                                                                      "Employer Name",
                                                                      style: TextStyle(
                                                                          color: Color(
                                                                              0xFF8A95A8),
                                                                          fontWeight: FontWeight
                                                                              .bold,
                                                                          fontSize:
                                                                              12),
                                                                    ),
                                                                    const SizedBox(
                                                                      height: 5,
                                                                    ),
                                                                    Text(
                                                                      'N/A',
                                                                      style:
                                                                          TextStyle(
                                                                        fontWeight:
                                                                            FontWeight.bold,
                                                                        color: blueColor


,
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                            ),
                                                            Expanded(
                                                              child: Container(
                                                                child:
                                                                     Column(
                                                                  crossAxisAlignment:
                                                                      CrossAxisAlignment
                                                                          .start,
                                                                  children: [
                                                                    const SizedBox(
                                                                      width: 2,
                                                                    ),
                                                                    const Text(
                                                                      "Employer Phone Number",
                                                                      style: TextStyle(
                                                                          color: Color(
                                                                              0xFF8A95A8),
                                                                          fontWeight: FontWeight
                                                                              .bold,
                                                                          fontSize:
                                                                              12),
                                                                    ),
                                                                    const SizedBox(
                                                                      height: 5,
                                                                    ),
                                                                    Text(
                                                                      'N/A',
                                                                      style:
                                                                          TextStyle(
                                                                        fontWeight:
                                                                            FontWeight.bold,
                                                                        color: blueColor


,
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        ),

                                                        // Unit ID

                                                        const SizedBox(
                                                          height: 18,
                                                        ),
                                                        Row(
                                                          children: [
                                                            Expanded(
                                                              child: Container(
                                                                child:
                                                                     Column(
                                                                  crossAxisAlignment:
                                                                      CrossAxisAlignment
                                                                          .start,
                                                                  children: [
                                                                    const SizedBox(
                                                                      width: 2,
                                                                    ),
                                                                    const Text(
                                                                      "Employer Email",
                                                                      style: TextStyle(
                                                                          color: Color(
                                                                              0xFF8A95A8),
                                                                          fontWeight: FontWeight
                                                                              .bold,
                                                                          fontSize:
                                                                              12),
                                                                    ),
                                                                    const SizedBox(
                                                                      height: 5,
                                                                    ),
                                                                    Text(
                                                                      'N/A',
                                                                      style:
                                                                          TextStyle(
                                                                        fontWeight:
                                                                            FontWeight.bold,
                                                                        color: blueColor


,
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                            ),
                                                            Expanded(
                                                              child: Container(
                                                                child:
                                                                     Column(
                                                                  crossAxisAlignment:
                                                                      CrossAxisAlignment
                                                                          .start,
                                                                  children: [
                                                                    const SizedBox(
                                                                      width: 2,
                                                                    ),
                                                                    const Text(
                                                                      "Position Held",
                                                                      style: TextStyle(
                                                                          color: Color(
                                                                              0xFF8A95A8),
                                                                          fontWeight: FontWeight
                                                                              .bold,
                                                                          fontSize:
                                                                              12),
                                                                    ),
                                                                    const SizedBox(
                                                                      height: 5,
                                                                    ),
                                                                    Text(
                                                                      'N/A',
                                                                      style:
                                                                          TextStyle(
                                                                        fontWeight:
                                                                            FontWeight.bold,
                                                                        color: blueColor


,
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        ),

                                                        const SizedBox(
                                                          height: 18,
                                                        ),
                                                        Row(
                                                          children: [
                                                            Expanded(
                                                              child: Container(
                                                                child:
                                                                     Column(
                                                                  crossAxisAlignment:
                                                                      CrossAxisAlignment
                                                                          .start,
                                                                  children: [
                                                                    const SizedBox(
                                                                      width: 2,
                                                                    ),
                                                                    const Text(
                                                                      "Supervisor Title",
                                                                      style: TextStyle(
                                                                          color: Color(
                                                                              0xFF8A95A8),
                                                                          fontWeight: FontWeight
                                                                              .bold,
                                                                          fontSize:
                                                                              12),
                                                                    ),
                                                                    const SizedBox(
                                                                      height: 5,
                                                                    ),
                                                                    Text(
                                                                      'N/A',
                                                                      style:
                                                                          TextStyle(
                                                                        fontWeight:
                                                                            FontWeight.bold,
                                                                        color: blueColor


,
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                            ),
                                                            Expanded(
                                                              child: Container(
                                                                child:
                                                                     Column(
                                                                  crossAxisAlignment:
                                                                      CrossAxisAlignment
                                                                          .start,
                                                                  children: [
                                                                    const SizedBox(
                                                                      width: 2,
                                                                    ),
                                                                    const Text(
                                                                      "Supervisor Name",
                                                                      style: TextStyle(
                                                                          color: Color(
                                                                              0xFF8A95A8),
                                                                          fontWeight: FontWeight
                                                                              .bold,
                                                                          fontSize:
                                                                              12),
                                                                    ),
                                                                    const SizedBox(
                                                                      height: 5,
                                                                    ),
                                                                    Text(
                                                                      'N/A',
                                                                      style:
                                                                          TextStyle(
                                                                        fontWeight:
                                                                            FontWeight.bold,
                                                                        color: blueColor


,
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        ),

                                                        const SizedBox(
                                                          height: 5,
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        );
                                      }),
                          ],
                        ),
            );
          } else {
            return const Padding(
              padding:  EdgeInsets.only(top: 200),
              child: Center(child: Text('No data available')),
            );
          }
        },
      ),
    );
  }

  void printAllFields() {
  }
}

import 'package:three_zero_two_property/services/app_log.dart';
import 'dart:convert';
import 'dart:io';

import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:email_validator/email_validator.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:keyboard_actions/keyboard_actions.dart';
import 'package:keyboard_actions/keyboard_actions_config.dart';
import 'package:provider/provider.dart';
import 'package:rflutter_alert/rflutter_alert.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:three_zero_two_property/StaffModule/repository/Property_type.dart';
import 'package:three_zero_two_property/StaffModule/repository/Staffmember.dart';
import 'package:three_zero_two_property/StaffModule/repository/rental_properties.dart';
import 'package:three_zero_two_property/StaffModule/screen/Rental/Properties/add_rentalowners.dart';
import 'package:three_zero_two_property/model/staffmember.dart';

import '../../../../provider/dateProvider.dart';
import '../../../widgets/appbar.dart';

import '../../../../Model/propertytype.dart';
import '../../../../constant/constant.dart';
import '../../../../model/add_property.dart';
import '../../../../model/rental_properties.dart';
import '../../../../provider/add_property.dart';

import '../../../widgets/drawer_tiles.dart';
import '../../../../widgets/rental_widget.dart';
import 'package:http/http.dart' as http;
import 'package:three_zero_two_property/services/api_helpers.dart';

import '../../../widgets/custom_drawer.dart';

class Add_new_property extends StatefulWidget {
  propertytype? property;
  Staffmembers? staff;
  bool? isEdit;

  Add_new_property({super.key, this.property, this.staff, this.isEdit});

  @override
  State<Add_new_property> createState() => _Add_new_propertyState();
}

class _Add_new_propertyState extends State<Add_new_property> {
  List<String> months = ['Residential', "Commercial"];
  List<Widget> fields = [];
  int? selectedIndex;
  List<ProcessorGroup> _processorGroups = [];

  final List<String> items = [
    'Residential',
    "Commercial",
  ];
  String? selectedStaff;

  bool isLoading = false;
  String? selectedValue;
  bool isChecked = false;
  bool isChecked2 = false;
  bool showproperty = false;
  String selectedMonth = 'Residential';

  TextEditingController city = TextEditingController();
  TextEditingController state = TextEditingController();
  TextEditingController country = TextEditingController();
  TextEditingController postalcode = TextEditingController();
  TextEditingController address = TextEditingController();
  TextEditingController subtype = TextEditingController();

  bool addresserror = false;
  bool cityerror = false;
  bool stateerror = false;
  bool countryerror = false;
  bool postalcodeerror = false;
  bool subtypeerror = false;
  bool propertyTypeError = false;

  String addressmessage = "";
  String citymessage = "";
  String statemessage = "";
  String countrymessage = "";
  String postalcodemessage = "";
  String subtypemessage = "";
  String propertyTypeErrorMessage = "";
  //add rental owner

  TextEditingController firstname = TextEditingController();

  TextEditingController comname = TextEditingController();
  TextEditingController primaryemail = TextEditingController();
  TextEditingController alternativeemail = TextEditingController();
  TextEditingController phonenum = TextEditingController();
  TextEditingController homenum = TextEditingController();
  TextEditingController businessnum = TextEditingController();
  TextEditingController street2 = TextEditingController();
  TextEditingController city2 = TextEditingController();
  TextEditingController state2 = TextEditingController();
  TextEditingController county2 = TextEditingController();
  TextEditingController code2 = TextEditingController();
  TextEditingController proid = TextEditingController();

  bool firstnameerror = false;

  bool comnameerror = false;
  bool primaryemailerror = false;
  bool alternativeerror = false;
  bool phonenumerror = false;
  bool homenumerror = false;
  bool businessnumerror = false;
  bool street2error = false;
  bool city2error = false;
  bool state2error = false;
  bool county2error = false;
  bool code2error = false;
  bool proiderror = false;

  String firstnamemessage = "";

  String comnamemessage = "";
  String primaryemailmessage = "";
  String alternativemessage = "";
  String phonenummessage = "";
  String homenummessage = "";
  String businessnummessage = "";
  String street2message = "";
  String city2message = "";
  String state2message = "";
  String county2message = "";
  String code2message = "";
  String proidmessage = "";

  // Insured Value Information
  TextEditingController datePlacedInService = TextEditingController();
  List<HistoricalInsuredValue> historicalInsuredValues = [];
  bool datePlacedInServiceError = false;
  String datePlacedInServiceMessage = "";

  TextEditingController searchController = TextEditingController();

  late Future<List<Staffmembers>> futureStaffMembers;
  String? selectedStaffmember;

  Future<List<propertytype>>? futureProperties;
  String? selectedProperty;
  Future<List<RentalOwners>>? futureRentalOwner;

  Map<String, List<propertytype>> groupPropertiesByType(
      List<propertytype> properties) {
    Map<String, List<propertytype>> groupedProperties = {};
    for (var property in properties) {
      if (!groupedProperties.containsKey(property.propertyType)) {
        groupedProperties[property.propertyType!] = [];
      }
      groupedProperties[property.propertyType!]!.add(property);
    }

    // Sort the values (property lists) for each property type and subtype
    groupedProperties.forEach((key, value) {
      value.sort((a, b) => (a.propertysubType ?? '')
          .toLowerCase()
          .compareTo((b.propertysubType ?? '').toLowerCase()));
    });

    // Sort property types alphabetically (A-Z)
    var sortedKeys = groupedProperties.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    Map<String, List<propertytype>> sortedGroupedProperties = {};
    for (var key in sortedKeys) {
      sortedGroupedProperties[key] = groupedProperties[key]!;
    }

    return sortedGroupedProperties;
  }

  List<Owner> owners = [];
  List<Owner> filteredOwners = [];
  List<bool> selected = [];

  Future<void> fetchOwners() async {
    setState(() {
      isLoading = true;
    });
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString("adminId");
    String? token = prefs.getString('token');
    String? staffid = prefs.getString("staff_id");
    final response = await apiGet(
      Uri.parse('${Api_url}/api/rentals/rental-owners/$id'),
      headers: {
        "id": "CRM $staffid",
        "authorization": "CRM $token",
      },
    );

    if (response.statusCode == 200) {
      List<dynamic> data = json.decode(response.body);
      owners = data.map((item) => Owner.fromJson(item)).toList();
      filteredOwners = List.from(owners);
      selected = List<bool>.filled(owners.length, false);
    } else {
      // Handle error
    }
    setState(() {
      isLoading = false;
    });
  }

  void filterOwners(String query) {
    setState(() {
      filteredOwners = owners.where((owner) {
        final fullName = '${owner.rentalOwnername} '.toLowerCase();
        return fullName.contains(query.toLowerCase());
      }).toList();
    });
  }

  @override
  void initState() {
    super.initState();
    filteredOwners = owners;
    selected = List<bool>.generate(owners.length, (index) => false);
    // searchController.addListener(() { });
    // futureMember = StaffMemberRepository().fetchStaffmembers();
    futureProperties = PropertyTypeRepository().fetchPropertyTypes();
    futureStaffMembers = StaffMemberRepository().fetchStaffmembers();
    propertyGroups = [];
    // Add property group based on selected subproperty type
    addPropertyGroup();
    fetchOwners();
  }

  reload_Screen() {
    setState(() {
      futureProperties = PropertyTypeRepository().fetchPropertyTypes();
      futureStaffMembers = StaffMemberRepository().fetchStaffmembers();
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    datePlacedInService.dispose();
    for (var item in historicalInsuredValues) {
      item.yearController.dispose();
      item.valueController.dispose();
    }
    super.dispose();
  }

  // Insured Value Information helper methods
  void addHistoricalInsuredValue() {
    setState(() {
      historicalInsuredValues.add(HistoricalInsuredValue(
        yearController: TextEditingController(),
        valueController: TextEditingController(),
      ));
    });
  }

  void removeHistoricalInsuredValue(int index) {
    setState(() {
      historicalInsuredValues[index].yearController.dispose();
      historicalInsuredValues[index].valueController.dispose();
      historicalInsuredValues.removeAt(index);
    });
  }

  Future<void> _selectDatePlacedInService() async {


    final DateTime? picked = await showDatePicker(
      context: context,
      // initial date is select date or datetime.now()
      initialDate: datePlacedInService.text.isEmpty
          ? DateTime.now()
          : DateFormat('MM/dd/yyyy').parse(datePlacedInService.text),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: blueColor,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        final dateProvider = Provider.of<DateProvider>(context, listen: false);
        String apiFormatDate = DateFormat('yyyy-MM-dd').format(picked);
        datePlacedInService.text =
            dateProvider.formatCurrentDate(apiFormatDate);
        datePlacedInServiceError = false;
      });
    }
  }

  List<String> _generateYearList() {
    int currentYear = DateTime.now().year;
    List<String> years = [];
    for (int i = currentYear; i >= currentYear - 50; i--) {
      years.add(i.toString());
    }
    return years;
  }

  Owner? selectedOwner;
  Owner? rentalOwnerId;
  Owner? getSelectedOwner() {
    for (int i = 0; i < selected.length; i++) {
      if (selected[i]) {
        return filteredOwners[i];
      }
    }
    return null;
  }

  void onAddButtonTapped() {
    for (int i = 0; i < selected.length; i++) {
      if (selected[i]) {
        setState(() {
          selectedOwner = filteredOwners[i];
        });
        return;
      }
    }
    // Show a message to select an owner
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Please select an owner.'),
    ));
  }

  List<List<TextEditingController>> propertyGroupControllers = [];

  bool iserror = false;
  bool iserror2 = false;
  GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  TextEditingController name = TextEditingController();
  TextEditingController designation = TextEditingController();
  TextEditingController phonenumber = TextEditingController();
  TextEditingController email = TextEditingController();
  TextEditingController password = TextEditingController();
  bool nameerror = false;
  bool designationerror = false;
  bool phonenumbererror = false;
  bool emailerror = false;
  bool passworderror = false;
  propertytype? selectedpropertytypedata = propertytype();
  propertytype? id = propertytype();
  String? sid = "";
  String? showdata;

//  propertytype? selectedpropertytype = propertytype();
  String? selectedpropertytype;
  //propertytype? selectedIsMultiUnit;
  bool selectedIsMultiUnit = false;
  String namemessage = "";
  String designationmessage = "";
  String phonenumbermessage = "";
  String emailmessage = "";
  String passwordmessage = "";

  bool loading = false;
  List<Widget> units = [];

  void removePropertyGroup(int index) {
    setState(() {
      propertyGroups.removeAt(index);
    });
  }

  Future<void> getImage(int index) async {
    final pickedFile =
        await ImagePicker().pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      // try {
      String? filename = await uploadImage(File(pickedFile.path));
      setState(() {
        propertyGroupImagenames[index] = filename!;
        //  _uploadedFilename = filename;
      });
      // } catch (e) {
      // print('Error uploading image: $e');
      //}09
    }
    setState(() {
      if (pickedFile != null) {
        propertyGroupImages[index] = File(pickedFile.path);
      } else {
      }
    });
  }

  List<List<Widget>> propertyGroups = [];
  //  List<List<TextEditingController>> propertyGroupControllers = [];
  List<File?> propertyGroupImages = [];
  List<String?> propertyGroupImagenames = [];
  File? _image;
  Future<String?> uploadImage(File imageFile) async {
    // API URL
    //   final String uploadUrl = 'http://192.168.1.17:4000/api/images/upload';
    final String uploadUrl = '${image_upload_url}/api/images/upload';

    var request = http.MultipartRequest('POST', Uri.parse(uploadUrl));
    if (imageFile != null) {
      request.files
          .add(await http.MultipartFile.fromPath('files', imageFile!.path));
    }
    // Create a multipart request
//    var request = http.MultipartRequest('POST', Uri.parse(uploadUrl));

    // Attach the file in the 'image' field
    // var multipartFile = await http.MultipartFile.fromPath(
    //   'files',
    //   imageFile.path,
    // //  contentType: MediaType('image', 'jpeg'), // Adjust based on your file type
    // );
    //
    // // Add the file to the request
    // request.files.add(multipartFile);

    // Send the request
    var response = await apiSend(request);
    // Parse the response
    var responseData = await http.Response.fromStream(response);
    var responseBody = json.decode(responseData.body);

    // Extract the filename from the response
    if (responseBody['status'] == 'ok') {
      List file = responseBody['files'];
      return file.first["filename"];
    } else {
      throw Exception('Failed to upload file: ${responseBody['message']}');
    }
  }

  Widget customTextField(String label, TextEditingController Controller) {
    return FormField<String>(
      validator: (value) {
        if (Controller.text.isEmpty) {
          return 'required';
        }
        return null;
      },
      builder: (FormFieldState<String> state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: TextFormField(
                controller: Controller,
                cursorColor: Colors.black,
                decoration: InputDecoration(
                  hintText: label,
                  // labelText: label,
                  // labelStyle: TextStyle(color: Colors.grey[700]),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF8A95A8)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        const BorderSide(color: Color(0xFF8A95A8), width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      vertical: 10.0, horizontal: 10.0),
                ),
              ),
            ),
            if (state.hasError)
              Padding(
                padding: const EdgeInsets.only(left: 5, top: 4),
                child: Text(
                  state.errorText!,
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 14,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget photo(int index) {
    return StatefulBuilder(
      builder: (BuildContext context, StateSetter setState) {
        return Column(
          children: [
            Row(
              children: [
                const SizedBox(
                  width: 5,
                ),
                Text(
                  'Photo',
                  style: TextStyle(
                      color: blueColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 18),
                ),
              ],
            ),
            const SizedBox(height: 8.0),
            if (propertyGroupImages[index] == null)
              Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      getImage(index).then((_) {
                        setState(
                            () {}); // Rebuild the widget after selecting the image
                      });
                    },
                    child: Image.asset(
                      'assets/images/addimage.png',
                      height: 40,
                      width: 40,
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 10),
            if (propertyGroupImages[index] != null)
              Column(
                children: [
                  // Text(
                  //   '+ Add',
                  //   style: TextStyle(color: Colors.green,fontWeight: FontWeight.bold,fontSize: 18),
                  // ),
                  Row(
                    children: [
                      const SizedBox(
                        width: 80,
                      ),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            propertyGroupImages[index] =
                                null; // Clear the selected image
                          });
                        },
                        child: const Icon(
                          Icons.close,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 8),
                        child: Image.file(
                          propertyGroupImages[index]!,
                          height: 100,
                          width: 100,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
          ],
        );
      },
    );
  }

  static const List<String> roomsArray = [
    "1 Bed",
    "2 Bed",
    "3 Bed",
    "4 Bed",
    "5 Bed",
    "6 Bed",
    "7 Bed",
    "8 Bed",
    "9 Bed",
    "9+ Bed",
  ];

  static const List<String> bathArray = [
    "1 Bath",
    "1.5 Bath",
    "2 Bath",
    "2.5 Bath",
    "3 Bath",
    "3.5 Bath",
    "4 Bath",
    "4.5 Bath",
    "5 Bath",
    "5+ Bath",
  ];

  Widget customDropdownField(
    String hint,
    List<String> items,
    TextEditingController controller,
  ) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: DropdownButtonFormField<String>(
        value: controller.text.isNotEmpty ? controller.text : null,
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
        hint: Text(hint),
        items: items.map((String value) {
          return DropdownMenuItem<String>(
            value: value,
            child: Text(value),
          );
        }).toList(),
        onChanged: (String? newValue) {
          controller.text = newValue ?? '';
        },
        validator: (value) =>
            value == null || value.isEmpty ? 'Required' : null,
      ),
    );
  }

  void addPropertyGroup() {
    List<Widget> fields = [];
    List<TextEditingController> controllers = [];


    if (selectedpropertytype == 'Commercial' && selectedIsMultiUnit == true) {
      var unitController = TextEditingController();
      var unitAddressController = TextEditingController();
      var sqftController = TextEditingController();

      fields = [
        customTextField('Unit', unitController),
        customTextField('Unit Address', unitAddressController),
        customTextField('SQft', sqftController),

        const SizedBox(
          height: 10,
        ),
        photo(propertyGroups.length), // Pass the index
      ];

      controllers = [unitController, unitAddressController, sqftController];
    } else if (selectedpropertytype == 'Residential' &&
        selectedIsMultiUnit == true) {
      var unitController = TextEditingController();
      var unitAddressController = TextEditingController();
      var sqftController = TextEditingController();
      var bathController = TextEditingController();
      var bedController = TextEditingController();

      fields = [
        customTextField('Unit', unitController),
        customTextField('Unit Address', unitAddressController),
        customTextField('SQft', sqftController),
        customDropdownField('Bath', bathArray, bathController),
        customDropdownField('Bed', roomsArray, bedController),
        // customTextField('Bath', bathController),
        // customTextField('Bed', bedController),

        const SizedBox(
          height: 10,
        ),
        photo(propertyGroups.length), // Pass the index
      ];

      controllers = [
        unitController,
        unitAddressController,
        sqftController,
        bathController,
        bedController
      ];
    } else if (selectedpropertytype == 'Residential') {
      var sqftController = TextEditingController();
      var bathController = TextEditingController();
      var bedController = TextEditingController();

      fields = [
        customTextField('SQft', sqftController),
        customDropdownField('Bath', bathArray, bathController),
        customDropdownField('Bed', roomsArray, bedController),
        // customTextField('Bath', bathController),
        // customTextField('Bed', bedController),

        const SizedBox(
          height: 10,
        ),
        photo(propertyGroups.length), // Pass the index
      ];

      controllers = [sqftController, bathController, bedController];
    } else if (selectedpropertytype == 'Commercial') {
      var sqftController = TextEditingController();

      fields = [
        customTextField('SQft', sqftController),

        const SizedBox(
          height: 10,
        ),
        photo(propertyGroups.length), // Pass the index
      ];

      controllers = [sqftController];
    }

    setState(() {
      propertyGroups.add(fields);
      propertyGroupControllers.add(controllers);
      propertyGroupImages.add(null);
      propertyGroupImagenames.add(null);
      // Initialize with null for the new group
    });
  }

  void displayPropertyData() {
    // Check if the first element is blank and remove it if it is
    if (propertyGroupControllers.isNotEmpty) {
      List<TextEditingController> firstControllers =
          propertyGroupControllers[0];
      bool isFirstBlank =
          firstControllers.every((controller) => controller.text.isEmpty);

      if (isFirstBlank) {
        propertyGroupControllers.removeAt(0);
      }
    }


    for (int i = 0; i < propertyGroupControllers.length; i++) {
      List<TextEditingController> controllers = propertyGroupControllers[i];
      for (int j = 0; j < controllers.length; j++) {
      }
    }
  }

  void handleEdit(RentalOwner rental) async {
    // Handle edit action
    // print('Edit ${rental.sId}');
    // // final result = await Navigator.push(
    // //     context,
    // //     MaterialPageRoute(
    // //         builder: (context) => Edit_staff_member(
    // //           staff: rental,
    // //         )));
    // if (result == true) {
    //   setState(() {
    //     futureStaffMembers = StaffMemberRepository().fetchStaffmembers();
    //   });
    // }
  }
  RentalOwner? Ownersdetails;
  List<OwnersDetails> OwnersdetailsGroups = [];
  bool hasError = false;

  final FocusNode _nodeText1 = FocusNode();
  KeyboardActionsConfig _buildConfig(BuildContext context) {
    return KeyboardActionsConfig(
      keyboardActionsPlatform: KeyboardActionsPlatform.ALL,
      keyboardBarColor: Colors.grey[200],
      nextFocus: true,
      actions: [
        KeyboardActionsItem(
          focusNode: _nodeText1,
        ),
      ],
    );
  }

  bool showError = false;
  @override
  Widget build(BuildContext context) {
    // print(selectedIsMultiUnit);
    // print(selectedProperty);
    final ownerDetails =
        Provider.of<OwnerDetailsProvider>(context).OwnerDetails;

    final firstnameController =
        TextEditingController(text: ownerDetails?.rentalOwnerName);
    final comnameController =
        TextEditingController(text: ownerDetails?.rentalOwnerCompanyName);
    final primaryemailController =
        TextEditingController(text: ownerDetails?.rentalOwnerPrimaryEmail);
    final phonenumController =
        TextEditingController(text: ownerDetails?.rentalOwnerPhoneNumber);
    final cityController = TextEditingController(text: ownerDetails?.city);
    final stateController = TextEditingController(text: ownerDetails?.state);
    final countyController = TextEditingController(text: ownerDetails?.country);
    final codeController =
        TextEditingController(text: ownerDetails?.postalCode);
    return Scaffold(
      appBar: widget_302_Staff.App_Bar(context: context),
      backgroundColor: Colors.white,
      drawer: CustomDrawerStaff(
        currentpage: "Properties",
        dropdown: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(25.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(5.0),
                  child: Container(
                    height: 50.0,
                    padding: const EdgeInsets.only(top: 10, left: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(5.0),
                      color: blueColor,
                      boxShadow: [
                        const BoxShadow(
                          color: Colors.grey,
                          offset: Offset(0.0, 1.0),
                          blurRadius: 6.0,
                        ),
                      ],
                    ),
                    child: const Text(
                      "Add Property",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 25),
                //dropdown
                Material(
                  elevation: 6,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: blueColor),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.only(
                          left: 10, right: 10, top: 10, bottom: 10),
                      child: Column(
                        children: [
                          // Row(
                          //   children: [
                          //     SizedBox(
                          //       width: 15,
                          //     ),
                          //     Text(
                          //       "New Property ",
                          //       style: TextStyle(
                          //           fontWeight: FontWeight.bold,
                          //           color: blueColor,
                          //           fontSize:
                          //               MediaQuery.of(context).size.width < 500
                          //                   ? 17
                          //                   : 18),
                          //     ),
                          //   ],
                          // ),
                          // SizedBox(
                          //   height: 10,
                          // ),
                          Row(
                            children: [
                              const SizedBox(
                                width: 15,
                              ),
                              Text(
                                "Property Information",
                                style: TextStyle(
                                    color: const Color(0xFF8A95A8),
                                    fontWeight: FontWeight.bold,
                                    fontSize:
                                        MediaQuery.of(context).size.width < 500
                                            ? 16
                                            : 18),
                              ),
                            ],
                          ),
                          const SizedBox(
                            height: 10,
                          ),
                          Row(
                            children: [
                              const SizedBox(
                                width: 15,
                              ),
                              Text(
                                "What is the property type?",
                                style: TextStyle(
                                    color: blueColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize:
                                        MediaQuery.of(context).size.width < 500
                                            ? 15
                                            : 18),
                              ),
                            ],
                          ),
                          const SizedBox(
                            height: 10,
                          ),
                          Row(
                            children: [
                              const SizedBox(
                                width: 5,
                              ),
                              FutureBuilder<List<propertytype>>(
                                future: futureProperties,
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return const Center(
                                        child: SpinKitFadingCircle(
                                      color: Colors.black,
                                      size: 40.0,
                                    ));
                                  } else if (snapshot.hasError) {
                                    return Text(friendlyErrorMessage(snapshot.error), textAlign: TextAlign.center);
                                  } else if (!snapshot.hasData ||
                                      snapshot.data!.isEmpty) {
                                    return const Text('No properties found');
                                  } else {
                                    Map<String, List<propertytype>>
                                        groupedProperties =
                                        groupPropertiesByType(snapshot.data!);
                                    return Column(
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.all(10.0),
                                          child: Container(
                                            // height: MediaQuery.of(context)
                                            //         .size
                                            //         .height *
                                            //     .05,
                                            height: 50,
                                            width: MediaQuery.of(context)
                                                    .size
                                                    .width *
                                                .6,
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              border: Border.all(
                                                color: const Color(0xFF8A95A8),
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: DropdownButtonHideUnderline(
                                              child: DropdownButton2<String>(
                                                value: selectedProperty,
                                                hint: Text(
                                                  'Add Property Type',
                                                  style: TextStyle(
                                                    fontSize:
                                                        MediaQuery.of(context)
                                                                    .size
                                                                    .width <
                                                                500
                                                            ? 15
                                                            : 18,
                                                    color:
                                                        const Color(0xFF8A95A8),
                                                  ),
                                                ),
                                                onChanged: (String? newValue) {
                                                  if (newValue ==
                                                      'Edit_properties') {
                                                    // Prevent the dropdown from changing the selected item
                                                    setState(() {
                                                      selectedProperty = null;
                                                    });
                                                    // Show the dialog
                                                    subtype.text = "";
                                                    selectedValue = null;
                                                    showDialog(
                                                      context: context,
                                                      builder: (BuildContext
                                                          context) {
                                                        bool isChecked =
                                                            false; // Moved isChecked inside the StatefulBuilder
                                                        return StatefulBuilder(
                                                          builder: (BuildContext
                                                                  context,
                                                              StateSetter
                                                                  setState) {
                                                            return Dialog(
                                                              // Inline "add a property type" from the property form. Restyled to the
                                                              // house card system used by the Property Type screens; fields and the
                                                              // save call are exactly as before. No image field on purpose: web's
                                                              // inline AddpropertyModal has none either (only Settings' dialog does),
                                                              // so the type falls back to the default image, matching web.
                                                              backgroundColor: Colors.transparent,
                                                              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                                              child: ConstrainedBox(
                                                                constraints: const BoxConstraints(maxWidth: 480),
                                                                child: Container(
                                                                  decoration: BoxDecoration(
                                                                    color: Colors.white,
                                                                    borderRadius: BorderRadius.circular(16),
                                                                    border: Border.all(color: borderClr),
                                                                    boxShadow: [
                                                                      BoxShadow(
                                                                        color: Colors.black.withOpacity(0.06),
                                                                        blurRadius: 16,
                                                                        offset: const Offset(0, 6),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                  padding: const EdgeInsets.all(20),
                                                                  child: SingleChildScrollView(
                                                                    child: Column(
                                                                      mainAxisSize: MainAxisSize.min,
                                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                                      children: [
                                                                        // Header: title leads, close control trails.
                                                                        Row(
                                                                          children: [
                                                                            Expanded(
                                                                              child: Text(
                                                                                'New Property Type',
                                                                                style: TextStyle(
                                                                                  fontSize: 18,
                                                                                  fontWeight: FontWeight.bold,
                                                                                  color: navyClr,
                                                                                ),
                                                                              ),
                                                                            ),
                                                                            Material(
                                                                              color: Colors.transparent,
                                                                              child: InkWell(
                                                                                borderRadius: BorderRadius.circular(18),
                                                                                onTap: () => Navigator.pop(context),
                                                                                child: Container(
                                                                                  width: 36,
                                                                                  height: 36,
                                                                                  decoration: const BoxDecoration(
                                                                                    color: Color(0xFFF2F4F7),
                                                                                    shape: BoxShape.circle,
                                                                                  ),
                                                                                  child: const Icon(Icons.close,
                                                                                      size: 20, color: Colors.black54),
                                                                                ),
                                                                              ),
                                                                            ),
                                                                          ],
                                                                        ),
                                                                        const SizedBox(height: 18),

                                                                        // Property Type *
                                                                        Padding(
                                                                          padding: const EdgeInsets.only(bottom: 8),
                                                                          child: RichText(
                                                                            text: TextSpan(
                                                                              text: 'Property Type',
                                                                              style: TextStyle(
                                                                                  fontSize: 14, fontWeight: FontWeight.bold, color: navyClr),
                                                                              children: [
                                                                                TextSpan(
                                                                                    text: ' *',
                                                                                    style: TextStyle(
                                                                                        color: redClr, fontWeight: FontWeight.bold)),
                                                                              ],
                                                                            ),
                                                                          ),
                                                                        ),
                                                                        DropdownButtonHideUnderline(
                                                                          child: DropdownButton2<String>(
                                                                            isExpanded: true,
                                                                            hint: Text(
                                                                              'Select type',
                                                                              style: TextStyle(
                                                                                  fontSize: 15,
                                                                                  fontWeight: FontWeight.w600,
                                                                                  color: mutedClr),
                                                                              overflow: TextOverflow.ellipsis,
                                                                            ),
                                                                            items: items
                                                                                .map((String item) => DropdownMenuItem<String>(
                                                                                      value: item,
                                                                                      // Item padding lives here, not on menuItemStyleData: the package
                                                                                      // derives the closed button's inner inset from half that value.
                                                                                      child: Padding(
                                                                                        padding: const EdgeInsets.symmetric(horizontal: 14),
                                                                                        child: Text(
                                                                                          item,
                                                                                          style: TextStyle(
                                                                                              fontSize: 15,
                                                                                              fontWeight: FontWeight.w600,
                                                                                              color: navyClr),
                                                                                          overflow: TextOverflow.ellipsis,
                                                                                        ),
                                                                                      ),
                                                                                    ))
                                                                                .toList(),
                                                                            // The closed button renders the item with menuItemStyleData's own
                                                                            // padding on top of the button's, so the selected value sat further
                                                                            // in than the text field below it. This draws the closed state
                                                                            // itself, with no padding, leaving only the button's 14.
                                                                            selectedItemBuilder: (context) => items
                                                                                .map((String item) => Align(
                                                                                      alignment: Alignment.centerLeft,
                                                                                      child: Text(
                                                                                        item,
                                                                                        style: TextStyle(
                                                                                          fontSize: 15,
                                                                                          fontWeight: FontWeight.w600,
                                                                                          color: navyClr,
                                                                                        ),
                                                                                        overflow: TextOverflow.ellipsis,
                                                                                      ),
                                                                                    ))
                                                                                .toList(),
                                                                            value: selectedValue,
                                                                            onChanged: (value) {
                                                                              setState(() {
                                                                                selectedValue = value;
                                                                              });
                                                                            },
                                                                            buttonStyleData: ButtonStyleData(
                                                                              height: 52,
                                                                              padding: const EdgeInsets.only(left: 14, right: 12),
                                                                              decoration: BoxDecoration(
                                                                                color: Colors.white,
                                                                                borderRadius: BorderRadius.circular(10),
                                                                                border: Border.all(color: outlineClr),
                                                                              ),
                                                                            ),
                                                                            iconStyleData: IconStyleData(
                                                                              icon: Icon(Icons.keyboard_arrow_down_rounded, color: mutedClr),
                                                                              iconSize: 24,
                                                                            ),
                                                                            dropdownStyleData: DropdownStyleData(
                                                                              maxHeight: 220,
                                                                              decoration: BoxDecoration(
                                                                                color: Colors.white,
                                                                                borderRadius: BorderRadius.circular(12),
                                                                              ),
                                                                            ),
                                                                            // Zero here on purpose: the package derives the CLOSED button's
                                                                            // inner padding from half of this value, which pushed the selected
                                                                            // value further in than the text field below it. Each item carries
                                                                            // its own padding instead, so the open menu is unchanged.
                                                                            menuItemStyleData: const MenuItemStyleData(
                                                                              height: 44,
                                                                              padding: EdgeInsets.zero,
                                                                            ),
                                                                          ),
                                                                        ),
                                                                        const SizedBox(height: 18),

                                                                        // Property Sub Type *
                                                                        Padding(
                                                                          padding: const EdgeInsets.only(bottom: 8),
                                                                          child: RichText(
                                                                            text: TextSpan(
                                                                              text: 'Property Sub Type',
                                                                              style: TextStyle(
                                                                                  fontSize: 14, fontWeight: FontWeight.bold, color: navyClr),
                                                                              children: [
                                                                                TextSpan(
                                                                                    text: ' *',
                                                                                    style: TextStyle(
                                                                                        color: redClr, fontWeight: FontWeight.bold)),
                                                                              ],
                                                                            ),
                                                                          ),
                                                                        ),
                                                                        Container(
                                                                          decoration: BoxDecoration(
                                                                            color: Colors.white,
                                                                            borderRadius: BorderRadius.circular(10),
                                                                            border: Border.all(color: outlineClr),
                                                                          ),
                                                                          padding: const EdgeInsets.symmetric(horizontal: 14),
                                                                          child: TextFormField(
                                                                            controller: subtype,
                                                                            style: TextStyle(
                                                                                fontSize: 15, fontWeight: FontWeight.w600, color: navyClr),
                                                                            decoration: InputDecoration(
                                                                              border: InputBorder.none,
                                                                              isDense: true,
                                                                              contentPadding: const EdgeInsets.symmetric(vertical: 16),
                                                                              hintText: 'e.g. Townhome',
                                                                              hintStyle: TextStyle(
                                                                                  color: mutedClr,
                                                                                  fontWeight: FontWeight.w500,
                                                                                  fontSize: 15),
                                                                            ),
                                                                          ),
                                                                        ),
                                                                        const SizedBox(height: 18),

                                                                        // Multi Unit
                                                                        Row(
                                                                          children: [
                                                                            SizedBox(
                                                                              width: 24,
                                                                              height: 24,
                                                                              child: Checkbox(
                                                                                value: isChecked,
                                                                                onChanged: (value) {
                                                                                  setState(() {
                                                                                    isChecked = value ?? false;
                                                                                  });
                                                                                },
                                                                                activeColor: navyClr,
                                                                                checkColor: Colors.white,
                                                                                side: BorderSide(color: checkOffClr, width: 1.5),
                                                                                shape: RoundedRectangleBorder(
                                                                                    borderRadius: BorderRadius.circular(6)),
                                                                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                                                visualDensity: VisualDensity.compact,
                                                                              ),
                                                                            ),
                                                                            const SizedBox(width: 12),
                                                                            Expanded(
                                                                              child: Text(
                                                                                'Multi Unit',
                                                                                style: TextStyle(
                                                                                    fontSize: 15,
                                                                                    fontWeight: FontWeight.w600,
                                                                                    color: navyClr),
                                                                              ),
                                                                            ),
                                                                          ],
                                                                        ),

                                                                        if (iserror) ...[
                                                                          const SizedBox(height: 14),
                                                                          Text(
                                                                            'Please fill in all fields correctly.',
                                                                            style: TextStyle(
                                                                                color: redClr, fontWeight: FontWeight.w600, fontSize: 13),
                                                                          ),
                                                                        ],
                                                                        const SizedBox(height: 22),

                                                                        // Actions
                                                                        Row(
                                                                          children: [
                                                                            Expanded(
                                                                              child: OutlinedButton(
                                                                                onPressed: isLoading ? null : () => Navigator.pop(context),
                                                                                style: OutlinedButton.styleFrom(
                                                                                  backgroundColor: Colors.white,
                                                                                  side: BorderSide(color: outlineClr),
                                                                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                                                                  shape: RoundedRectangleBorder(
                                                                                      borderRadius: BorderRadius.circular(10)),
                                                                                ),
                                                                                child: Text(
                                                                                  'Cancel',
                                                                                  style: TextStyle(
                                                                                      color: mutedClr,
                                                                                      fontWeight: FontWeight.bold,
                                                                                      fontSize: 15),
                                                                                ),
                                                                              ),
                                                                            ),
                                                                            const SizedBox(width: 12),
                                                                            Expanded(
                                                                              child: ElevatedButton(
                                                                                // Save logic unchanged from the previous dialog, including
                                                                                // the un-trimmed subtype check it always had.
                                                                                onPressed: isLoading
                                                                                    ? null
                                                                                    : () async {
                                                                                        if (selectedValue == null ||
                                                                                            subtype.text.isEmpty) {
                                                                                          setState(() {
                                                                                            iserror = true;
                                                                                          });
                                                                                        } else {
                                                                                          setState(() {
                                                                                            isLoading = true;
                                                                                            iserror = false;
                                                                                          });
                                                                                          SharedPreferences prefs =
                                                                                              await SharedPreferences.getInstance();
                                                                                          String? id = prefs.getString("adminId");
                                                                                          PropertyTypeRepository()
                                                                                              .addPropertyType(
                                                                                            adminId: id!,
                                                                                            propertyType: selectedValue,
                                                                                            propertySubType: subtype.text,
                                                                                            isMultiUnit: isChecked,
                                                                                          )
                                                                                              .then((value) {
                                                                                            setState(() {
                                                                                              isLoading = false;
                                                                                            });
                                                                                            reload_Screen();
                                                                            Navigator.pop(context, true);
                                                                                          }).catchError((e) {
                                                                                            setState(() {
                                                                                              isLoading = false;
                                                                                            });
                                                                                          });
                                                                                        }
                                                                                      },
                                                                                style: ElevatedButton.styleFrom(
                                                                                  backgroundColor: navyClr,
                                                                                  disabledBackgroundColor: navyClr.withOpacity(0.6),
                                                                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                                                                  elevation: 0,
                                                                                  shape: RoundedRectangleBorder(
                                                                                      borderRadius: BorderRadius.circular(10)),
                                                                                ),
                                                                                child: isLoading
                                                                                    ? const SpinKitFadingCircle(
                                                                                        color: Colors.white, size: 22.0)
                                                                                    : const Text(
                                                                                        'Add',
                                                                                        style: TextStyle(
                                                                                            color: Colors.white,
                                                                                            fontWeight: FontWeight.bold,
                                                                                            fontSize: 15),
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
                                                            );
                                                          },
                                                        );
                                                      },
                                                    );
                                                  } else {
                                                    setState(() {
                                                      // selectedIsMultiUnit = snapshot.data!.where((element) => element.isMultiunit == newValue ).first;
                                                      selectedpropertytypedata =
                                                          snapshot.data!
                                                              .where((element) =>
                                                                  element
                                                                      .propertysubType ==
                                                                  newValue)
                                                              .first;
                                                      selectedProperty =
                                                          newValue;
                                                      propertyGroups = [];
                                                      // Call the method here
                                                      selectedpropertytype =
                                                          selectedpropertytypedata!
                                                              .propertyType;
                                                      selectedIsMultiUnit =
                                                          selectedpropertytypedata!
                                                              .isMultiunit!;
                                                    });
                                                    propertyGroups.clear();
                                                    addPropertyGroup();
                                                    propertyTypeError = false;
                                                    showError =
                                                        selectedProperty ==
                                                            null;
                                                  }
                                                },
                                                items: [
                                                  ...groupedProperties.entries
                                                      .expand((entry) {
                                                    return [
                                                      DropdownMenuItem<String>(
                                                        enabled: false,
                                                        child: Text(
                                                          entry.key,
                                                          style:
                                                              const TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  color: Color
                                                                      .fromRGBO(
                                                                          21,
                                                                          43,
                                                                          81,
                                                                          1)),
                                                        ),
                                                      ),
                                                      ...entry.value
                                                          .map((item) {
                                                        return DropdownMenuItem<
                                                            String>(
                                                          value: item
                                                              .propertysubType,
                                                          child: Padding(
                                                            padding:
                                                                const EdgeInsets
                                                                    .only(
                                                                    left: 16.0),
                                                            child: Text(
                                                              item.propertysubType ??
                                                                  '',
                                                              style:
                                                                  const TextStyle(
                                                                color: Colors
                                                                    .black,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w400,
                                                              ),
                                                            ),
                                                          ),
                                                        );
                                                      }).toList(),
                                                    ];
                                                  }).toList(),
                                                  const DropdownMenuItem<
                                                      String>(
                                                    value: 'Edit_properties',
                                                    child: Row(
                                                      children: [
                                                        Icon(Icons.add,
                                                            size:
                                                                15), // Adjusted icon size
                                                        SizedBox(width: 6),
                                                        Text(
                                                            'Add New properties',
                                                            style: TextStyle(
                                                                fontSize:
                                                                    16 //MediaQuery.of(context).size.width * .03
                                                                )), // Adjusted text size
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                                isExpanded: true,
                                                buttonStyleData:
                                                    ButtonStyleData(
                                                  height: 50,
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 8,
                                                      vertical: 4),
                                                  decoration: BoxDecoration(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            10),
                                                    color: Colors.transparent,
                                                  ),
                                                ),
                                                dropdownStyleData:
                                                    DropdownStyleData(
                                                  maxHeight: 300,
                                                  decoration: BoxDecoration(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            10),
                                                    color: Colors.white,
                                                  ),
                                                  scrollbarTheme:
                                                      ScrollbarThemeData(
                                                    radius:
                                                        const Radius.circular(
                                                            40),
                                                    thickness:
                                                        MaterialStateProperty
                                                            .all(6),
                                                    thumbVisibility:
                                                        MaterialStateProperty
                                                            .all(true),
                                                  ),
                                                ),
                                                menuItemStyleData:
                                                    const MenuItemStyleData(
                                                  height: 40,
                                                  padding: EdgeInsets.symmetric(
                                                      horizontal: 16,
                                                      vertical: 8),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(
                                          height: 2,
                                        ),
                                        if (showError)
                                          const Row(
                                            // mainAxisAlignment:
                                            // MainAxisAlignment.start,
                                            // crossAxisAlignment:
                                            // CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Please select a property type.',
                                                style: TextStyle(
                                                    color: Colors.red),
                                              ),
                                            ],
                                          ),
                                      ],
                                    );
                                  }
                                },
                              ),
                            ],
                          ),
                          propertyTypeError
                              ? Row(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    const SizedBox(
                                      width: 15,
                                    ),
                                    Text(
                                      propertyTypeErrorMessage,
                                      style: TextStyle(
                                          color: Colors.red,
                                          fontSize: MediaQuery.of(context)
                                                  .size
                                                  .width *
                                              .03),
                                    ),
                                  ],
                                )
                              : Container(),
                          const SizedBox(
                            height: 10,
                          ),
                          Row(
                            children: [
                              const SizedBox(
                                width: 15,
                              ),
                              Text(
                                "What is the street  address?",
                                style: TextStyle(
                                    color: blueColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize:
                                        MediaQuery.of(context).size.width < 500
                                            ? 15
                                            : 18),
                              ),
                            ],
                          ),
                          const SizedBox(
                            height: 5,
                          ),
                          Row(
                            children: [
                              const SizedBox(
                                width: 15,
                              ),
                              Text(
                                "Address",
                                style: TextStyle(
                                    color: const Color(0xFF8A95A8),
                                    fontWeight: FontWeight.bold,
                                    fontSize:
                                        MediaQuery.of(context).size.width < 500
                                            ? 14
                                            : 18),
                              ),
                            ],
                          ),
                          const SizedBox(
                            height: 8,
                          ),
                          Row(
                            children: [
                              const SizedBox(
                                width: 15,
                              ),
                              Expanded(
                                child: Container(
                                  height: 50,
                                  decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(10),
                                      color: Colors.white,
                                      border: Border.all(color: greyColor)
                                      // color: Color.fromRGBO(196, 196, 196, .3),
                                      ),
                                  child: Stack(
                                    children: [
                                      Positioned.fill(
                                        child: TextField(
                                          style: TextStyle(
                                            color: Colors.black,
                                            fontSize: MediaQuery.of(context)
                                                        .size
                                                        .width <
                                                    500
                                                ? 14
                                                : 15,
                                          ),
                                          keyboardType: TextInputType
                                              .text, // Adjust as needed
                                          onChanged: (value) {
                                            setState(() {
                                              addresserror = false;
                                            });
                                          },
                                          controller: address,
                                          cursorColor: blueColor,
                                          decoration: InputDecoration(
                                            enabledBorder: addresserror
                                                ? OutlineInputBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            10),
                                                    borderSide: const BorderSide(
                                                        color: Colors
                                                            .red), // Set border color here
                                                  )
                                                : InputBorder.none,
                                            border: InputBorder.none,
                                            contentPadding:
                                                const EdgeInsets.all(14),
                                            // prefixIcon: Container(
                                            //   height: 20,
                                            //   width: 20,
                                            //   padding: EdgeInsets.all(13),
                                            //   child: FaIcon(
                                            //     FontAwesomeIcons.locationArrow, // Replace with your icon
                                            //     size: 20,
                                            //     color: Colors.grey[600],
                                            //   ),
                                            // ),
                                            hintText: "Enter address",
                                            hintStyle: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: MediaQuery.of(context)
                                                          .size
                                                          .width <
                                                      500
                                                  ? 14
                                                  : 18,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(
                                width: 15,
                              ),
                            ],
                          ),
                          addresserror
                              ? Row(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    const SizedBox(
                                      width: 15,
                                    ),
                                    Text(
                                      addressmessage,
                                      style: const TextStyle(color: Colors.red),
                                    ),
                                  ],
                                )
                              : Container(),
                          const SizedBox(
                            height: 10,
                          ),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 15.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // First Column
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "City",
                                        style: TextStyle(
                                          color: const Color(0xFF8A95A8),
                                          fontWeight: FontWeight.bold,
                                          fontSize: MediaQuery.of(context)
                                                      .size
                                                      .width <
                                                  500
                                              ? 14.5
                                              : 18,
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      Container(
                                        height: 50,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          border: Border.all(
                                              color: const Color(0xFF8A95A8)),
                                        ),
                                        child: Stack(
                                          children: [
                                            Positioned.fill(
                                              child: TextField(
                                                keyboardType:
                                                    TextInputType.text,
                                                controller: city,
                                                style: TextStyle(
                                                  color: Colors.black,
                                                  fontSize:
                                                      MediaQuery.of(context)
                                                                  .size
                                                                  .width <
                                                              500
                                                          ? 14
                                                          : 15,
                                                ),
                                                onChanged: (value) {
                                                  setState(() {
                                                    cityerror = false;
                                                  });
                                                },
                                                cursorColor: blueColor,
                                                decoration: InputDecoration(
                                                  enabledBorder: cityerror
                                                      ? OutlineInputBorder(
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(10),
                                                          borderSide:
                                                              const BorderSide(
                                                                  color: Colors
                                                                      .red), // Error border color
                                                        )
                                                      : InputBorder.none,
                                                  border: InputBorder.none,
                                                  contentPadding:
                                                      const EdgeInsets.all(14),
                                                  hintText: "Enter city",
                                                  hintStyle: TextStyle(
                                                    color:
                                                        const Color(0xFF8A95A8),
                                                    fontSize:
                                                        MediaQuery.of(context)
                                                                    .size
                                                                    .width <
                                                                500
                                                            ? 14
                                                            : 18,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      cityerror
                                          ? Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.start,
                                              children: [
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                          left: 5),
                                                  child: Text(
                                                    citymessage,
                                                    style: const TextStyle(color: Colors.red),
                                                  ),
                                                ),
                                              ],
                                            )
                                          : Container(),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                // Second Column
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "State",
                                        style: TextStyle(
                                          color: const Color(0xFF8A95A8),
                                          fontWeight: FontWeight.bold,
                                          fontSize: MediaQuery.of(context)
                                                      .size
                                                      .width <
                                                  500
                                              ? 14.5
                                              : 18,
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      Container(
                                        height: 50,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          border: Border.all(
                                              color: const Color(0xFF8A95A8)),
                                        ),
                                        child: Stack(
                                          children: [
                                            Positioned.fill(
                                              child: TextField(
                                                keyboardType:
                                                    TextInputType.text,
                                                controller: state,
                                                style: TextStyle(
                                                  color: Colors.black,
                                                  fontSize:
                                                      MediaQuery.of(context)
                                                                  .size
                                                                  .width <
                                                              500
                                                          ? 14
                                                          : 15,
                                                ),
                                                onChanged: (value) {
                                                  setState(() {
                                                    stateerror = false;
                                                  });
                                                },
                                                cursorColor: blueColor,
                                                decoration: InputDecoration(
                                                  enabledBorder: stateerror
                                                      ? OutlineInputBorder(
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(10),
                                                          borderSide:
                                                              const BorderSide(
                                                                  color: Colors
                                                                      .red), // Error border color
                                                        )
                                                      : InputBorder.none,
                                                  border: InputBorder.none,
                                                  contentPadding:
                                                      const EdgeInsets.all(14),
                                                  hintText: "Enter state",
                                                  hintStyle: TextStyle(
                                                    color:
                                                        const Color(0xFF8A95A8),
                                                    fontSize:
                                                        MediaQuery.of(context)
                                                                    .size
                                                                    .width <
                                                                500
                                                            ? 14
                                                            : 18,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      stateerror
                                          ? Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.start,
                                              children: [
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                          left: 5),
                                                  child: Text(
                                                    statemessage,
                                                    style: const TextStyle(color: Colors.red),
                                                  ),
                                                ),
                                              ],
                                            )
                                          : Container(),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(
                            height: 10,
                          ),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 15.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // First Column
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Country",
                                        style: TextStyle(
                                          color: const Color(0xFF8A95A8),
                                          fontWeight: FontWeight.bold,
                                          fontSize: MediaQuery.of(context)
                                                      .size
                                                      .width <
                                                  500
                                              ? 14.5
                                              : 18,
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      Container(
                                        height: 50,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          border: Border.all(
                                              color: const Color(0xFF8A95A8)),
                                        ),
                                        child: Stack(
                                          children: [
                                            Positioned.fill(
                                              child: TextField(
                                                keyboardType:
                                                    TextInputType.text,
                                                controller: country,
                                                style: TextStyle(
                                                  color: Colors.black,
                                                  fontSize:
                                                      MediaQuery.of(context)
                                                                  .size
                                                                  .width <
                                                              500
                                                          ? 14
                                                          : 15,
                                                ),
                                                onChanged: (value) {
                                                  setState(() {
                                                    countryerror = false;
                                                  });
                                                },
                                                cursorColor: blueColor,
                                                decoration: InputDecoration(
                                                  enabledBorder: countryerror
                                                      ? OutlineInputBorder(
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(10),
                                                          borderSide:
                                                              const BorderSide(
                                                                  color: Colors
                                                                      .red), // Error border color
                                                        )
                                                      : InputBorder.none,
                                                  border: InputBorder.none,
                                                  contentPadding:
                                                      const EdgeInsets.all(14),
                                                  hintText: "Enter country",
                                                  hintStyle: TextStyle(
                                                    color:
                                                        const Color(0xFF8A95A8),
                                                    fontSize:
                                                        MediaQuery.of(context)
                                                                    .size
                                                                    .width <
                                                                500
                                                            ? 14
                                                            : 18,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      countryerror
                                          ? Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.start,
                                              children: [
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                          left: 5),
                                                  child: Text(
                                                    countrymessage,
                                                    style: const TextStyle(color: Colors.red),
                                                  ),
                                                ),
                                              ],
                                            )
                                          : Container(),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                // Second Column
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Zip Code",
                                        style: TextStyle(
                                          color: const Color(0xFF8A95A8),
                                          fontWeight: FontWeight.bold,
                                          fontSize: MediaQuery.of(context)
                                                      .size
                                                      .width <
                                                  500
                                              ? 14.5
                                              : 18,
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      Container(
                                        height: 50,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          border: Border.all(
                                              color: const Color(0xFF8A95A8)),
                                        ),
                                        child: Stack(
                                          children: [
                                            Positioned.fill(
                                              child: TextField(
                                                focusNode: _nodeText1,
                                                controller: postalcode,
                                                style: TextStyle(
                                                  color: Colors.black,
                                                  fontSize:
                                                      MediaQuery.of(context)
                                                                  .size
                                                                  .width <
                                                              500
                                                          ? 14
                                                          : 15,
                                                ),
                                                onChanged: (value) {
                                                  setState(() {
                                                    postalcodeerror = false;
                                                  });
                                                },
                                                keyboardType:
                                                    TextInputType.number,
                                                inputFormatters: [
                                                  FilteringTextInputFormatter
                                                      .digitsOnly,
                                                ],
                                                cursorColor: blueColor,
                                                decoration: InputDecoration(
                                                  enabledBorder: postalcodeerror
                                                      ? OutlineInputBorder(
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(10),
                                                          borderSide:
                                                              const BorderSide(
                                                                  color: Colors
                                                                      .red), // Error border color
                                                        )
                                                      : InputBorder.none,
                                                  border: InputBorder.none,
                                                  contentPadding:
                                                      const EdgeInsets.all(14),
                                                  hintText: "Enter zip code",
                                                  hintStyle: TextStyle(
                                                    color:
                                                        const Color(0xFF8A95A8),
                                                    fontSize:
                                                        MediaQuery.of(context)
                                                                    .size
                                                                    .width <
                                                                500
                                                            ? 14
                                                            : 18,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      postalcodeerror
                                          ? Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.start,
                                              children: [
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                          left: 5),
                                                  child: Text(
                                                    postalcodemessage,
                                                    style: const TextStyle(color: Colors.red),
                                                  ),
                                                ),
                                              ],
                                            )
                                          : Container(),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(
                            height: 10,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 25),
                // Insured Value Information
                Material(
                  elevation: 6,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: blueColor),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.only(
                          left: 10, right: 10, top: 10, bottom: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const SizedBox(width: 15),
                              Text(
                                "Insured Value Information",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: blueColor,
                                  fontSize:
                                      MediaQuery.of(context).size.width < 500
                                          ? 16.5
                                          : 20,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 15),
                          Row(
                            children: [
                              const SizedBox(width: 15),
                              Text(
                                "Date Placed in Service *",
                                style: TextStyle(
                                  color: const Color(0xFF8A95A8),
                                  fontWeight: FontWeight.bold,
                                  fontSize:
                                      MediaQuery.of(context).size.width < 500
                                          ? 14.5
                                          : 18,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 15.0),
                            child: Container(
                              height: 50,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                color: Colors.white,
                                border: Border.all(
                                  color: datePlacedInServiceError
                                      ? Colors.red
                                      : const Color(0xFFDBE0E5),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.withOpacity(0.1),
                                    spreadRadius: 1,
                                    blurRadius: 3,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: TextField(
                                      controller: datePlacedInService,
                                      readOnly: true,
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontSize:
                                            MediaQuery.of(context).size.width <
                                                    500
                                                ? 14
                                                : 15,
                                      ),
                                      cursorColor: blueColor,
                                      decoration: InputDecoration(
                                        enabledBorder: InputBorder.none,
                                        border: InputBorder.none,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 14, vertical: 14),
                                        hintText: "MM/DD/YYYY",
                                        hintStyle: TextStyle(
                                          color: Colors.grey[400],
                                          fontSize:
                                              MediaQuery.of(context).size.width <
                                                      500
                                                  ? 14
                                                  : 15,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    right: 12,
                                    top: 0,
                                    bottom: 0,
                                    child: Center(
                                      child: GestureDetector(
                                        onTap: _selectDatePlacedInService,
                                        child: Icon(
                                          Icons.calendar_today,
                                          color: const Color(0xFF8A95A8),
                                          size: MediaQuery.of(context)
                                                          .size
                                                          .width <
                                                      500
                                              ? 18
                                              : 20,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (datePlacedInServiceError)
                            Padding(
                              padding: const EdgeInsets.only(left: 15, top: 5),
                              child: Text(
                                datePlacedInServiceMessage,
                                style: const TextStyle(color: Colors.red),
                              ),
                            ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              const SizedBox(width: 15),
                              Text(
                                "Historical Insured Values",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: blueColor,
                                  fontSize:
                                      MediaQuery.of(context).size.width < 500
                                          ? 16.5
                                          : 20,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 15),
                          if (historicalInsuredValues.isNotEmpty)
                            ...historicalInsuredValues.asMap().entries.map((entry) {
                              int index = entry.key;
                              HistoricalInsuredValue item = entry.value;
                              return Padding(
                                padding: const EdgeInsets.only(
                                    bottom: 15, left: 15, right: 0),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "YEAR *",
                                            style: TextStyle(
                                              color: const Color(0xFF8A95A8),
                                              fontWeight: FontWeight.bold,
                                              fontSize: MediaQuery.of(context).size.width < 500 ? 14.5 : 16,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Container(
                                            height: 50,
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(10),
                                              color: Colors.white,
                                              border: Border.all(
                                                color: item.yearError ? Colors.red : const Color(0xFFDBE0E5),
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.grey.withOpacity(0.1),
                                                  spreadRadius: 1,
                                                  blurRadius: 3,
                                                  offset: const Offset(0, 1),
                                                ),
                                              ],
                                            ),
                                            child: DropdownButtonHideUnderline(
                                              child: DropdownButton2<String>(
                                                value: item.year,
                                                hint: Text(
                                                  'Select Year',
                                                  style: TextStyle(
                                                    fontSize: MediaQuery.of(context).size.width < 500 ? 14 : 15,
                                                    color: Colors.grey[400],
                                                  ),
                                                ),
                                                onChanged: (String? newValue) {
                                                  setState(() {
                                                    item.year = newValue;
                                                    item.yearError = false;
                                                  });
                                                },
                                                items: _generateYearList().map((String year) {
                                                  return DropdownMenuItem<String>(
                                                    value: year,
                                                    child: Text(year, style: TextStyle(fontSize: MediaQuery.of(context).size.width < 500 ? 14 : 15)),
                                                  );
                                                }).toList(),
                                                isExpanded: true,
                                                buttonStyleData: ButtonStyleData(height: 50, padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 14), decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: Colors.transparent)),
                                                dropdownStyleData: DropdownStyleData(maxHeight: 300, decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: Colors.white)),
                                                menuItemStyleData: const MenuItemStyleData(height: 40, padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
                                              ),
                                            ),
                                          ),
                                          if (item.yearError)
                                            Padding(
                                              padding: const EdgeInsets.only(top: 5, left: 2),
                                              child: Text("Required", style: TextStyle(color: Colors.red, fontSize: 12)),
                                            ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "VALUE (\$) *",
                                            style: TextStyle(
                                              color: const Color(0xFF8A95A8),
                                              fontWeight: FontWeight.bold,
                                              fontSize: MediaQuery.of(context).size.width < 500 ? 14.5 : 16,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Container(
                                            height: 50,
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(10),
                                              color: Colors.white,
                                              border: Border.all(color: item.valueError ? Colors.red : const Color(0xFFDBE0E5)),
                                              boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 1, blurRadius: 3, offset: const Offset(0, 1))],
                                            ),
                                            child: TextField(
                                              controller: item.valueController,
                                              keyboardType: TextInputType.numberWithOptions(decimal: true),
                                              style: TextStyle(color: Colors.black, fontSize: MediaQuery.of(context).size.width < 500 ? 14 : 15),
                                              onChanged: (value) => setState(() => item.valueError = false),
                                              cursorColor: blueColor,
                                              decoration: InputDecoration(
                                                enabledBorder: InputBorder.none,
                                                border: InputBorder.none,
                                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                                hintText: "Enter value..",
                                                hintStyle: TextStyle(color: Colors.grey[400], fontSize: MediaQuery.of(context).size.width < 500 ? 14 : 15),
                                              ),
                                            ),
                                          ),
                                          if (item.valueError)
                                            Padding(
                                              padding: const EdgeInsets.only(top: 5, left: 2),
                                              child: Text("Required", style: TextStyle(color: Colors.red, fontSize: 12)),
                                            ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    Padding(
                                      padding: const EdgeInsets.only(top: 35),
                                      child: InkWell(
                                        onTap: () => removeHistoricalInsuredValue(index),
                                        child: Container(
                                          padding: const EdgeInsets.all(5),
                                          child: FaIcon(FontAwesomeIcons.trashCan, color: Colors.red, size: MediaQuery.of(context).size.width < 500 ? 18 : 20),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          const SizedBox(height: 10),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 15.0),
                            child: GestureDetector(
                              onTap: addHistoricalInsuredValue,
                              child: Container(
                                height: 40,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: blueColor,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.2), spreadRadius: 1, blurRadius: 3, offset: const Offset(0, 1))],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.add, color: Colors.white, size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      "Add Historical Insured Value",
                                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: MediaQuery.of(context).size.width < 500 ? 13 : 15),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 25),
                //rental
                Material(
                  elevation: 6,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: blueColor),
                    ),
                    child: Padding(
                        padding: const EdgeInsets.only(
                            left: 10, right: 10, top: 10, bottom: 10),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                const SizedBox(
                                  width: 15,
                                ),
                                Text(
                                  "Owner Information",
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: blueColor,
                                      fontSize:
                                          MediaQuery.of(context).size.width <
                                                  500
                                              ? 16.5
                                              : 20),
                                ),
                              ],
                            ),
                            const SizedBox(
                              height: 10,
                            ),
                            Row(
                              children: [
                                const SizedBox(
                                  width: 15,
                                ),
                                Expanded(
                                  child: Text(
                                    "Who is the property owner ? (Required)",
                                    style: TextStyle(
                                        color: const Color(0xFF8A95A8),
                                        //  fontWeight: FontWeight.bold,
                                        fontSize:
                                            MediaQuery.of(context).size.width <
                                                    500
                                                ? 14.5
                                                : 18),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(
                              height: 10,
                            ),
                            Row(
                              children: [
                                const SizedBox(
                                  width: 15,
                                ),
                                Expanded(
                                  child: Text(
                                    "This information will be used to help prepare owner draws and 1099s",
                                    style: TextStyle(
                                        color: const Color(0xFF8A95A8),
                                        //  fontWeight: FontWeight.bold,
                                        fontSize:
                                            MediaQuery.of(context).size.width <
                                                    500
                                                ? 14.5
                                                : 18),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(
                              height: 10,
                            ),
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) =>
                                            AddRentalowners()));
                              },
                              child: Row(
                                children: [
                                  const SizedBox(width: 10),
                                  Icon(Icons.add,
                                      size: 25, color: Colors.green[400]),
                                  const SizedBox(width: 9),
                                  Text(
                                    "Add Rental Owner",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green[500],
                                      fontSize:
                                          MediaQuery.of(context).size.width <
                                                  500
                                              ? 15
                                              : 18,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(
                              height: 5,
                            ),
                            if (hasError &&
                                Provider.of<OwnerDetailsProvider>(context)
                                        .OwnerDetails ==
                                    null)
                              const Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    width: 15,
                                  ),
                                  Text(
                                    'required',
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            const SizedBox(
                              height: 5,
                            ),
                            Consumer<OwnerDetailsProvider>(
                              builder: (context, provider, child) {
                                Ownersdetails = provider.OwnerDetails;
                                return Ownersdetails != null
                                    ? Column(
                                        children: [
                                          const SizedBox(height: 10),
                                          Row(
                                            children: [
                                              const SizedBox(width: 20),
                                              Text(
                                                "Owners Information",
                                                style: TextStyle(
                                                    fontSize:
                                                        MediaQuery.of(context)
                                                                    .size
                                                                    .width <
                                                                500
                                                            ? 15
                                                            : 17,
                                                    fontWeight:
                                                        FontWeight.bold),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 10),
                                          Row(
                                            children: [
                                              const SizedBox(width: 15),
                                              Expanded(
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            5),
                                                    border: Border.all(
                                                        color: blueColor),
                                                  ),
                                                  child: DataTable(
                                                    border: TableBorder(
                                                      horizontalInside:
                                                          BorderSide(
                                                        color: blueColor,
                                                        width: 1.0,
                                                      ),
                                                    ),
                                                    columnSpacing: 10,
                                                    headingRowHeight:
                                                        MediaQuery.of(context)
                                                                    .size
                                                                    .width <
                                                                500
                                                            ? 40
                                                            : 40,
                                                    dataRowHeight:
                                                        MediaQuery.of(context)
                                                                    .size
                                                                    .width <
                                                                500
                                                            ? 40
                                                            : 40,
                                                    columns: [
                                                      DataColumn(
                                                        label: Expanded(
                                                          child: Text(
                                                            'Name',
                                                            style: TextStyle(
                                                                fontSize: MediaQuery.of(context)
                                                                            .size
                                                                            .width <
                                                                        500
                                                                    ? 14
                                                                    : 18,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold),
                                                          ),
                                                        ),
                                                      ),
                                                      DataColumn(
                                                        label: Expanded(
                                                          child: Text(
                                                            'PhoneNumber',
                                                            style: TextStyle(
                                                                fontSize: MediaQuery.of(context)
                                                                            .size
                                                                            .width <
                                                                        500
                                                                    ? 14
                                                                    : 18,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold),
                                                          ),
                                                        ),
                                                      ),
                                                      DataColumn(
                                                        label: Expanded(
                                                          child: Text(
                                                            'Action',
                                                            style: TextStyle(
                                                                fontSize: MediaQuery.of(context)
                                                                            .size
                                                                            .width <
                                                                        500
                                                                    ? 14
                                                                    : 18,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold),
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                    rows: [
                                                      DataRow(
                                                        cells: [
                                                          DataCell(
                                                            Text(
                                                              Ownersdetails!
                                                                      .rentalOwnerName ??
                                                                  'N/A',
                                                              style: TextStyle(
                                                                  fontSize:
                                                                      MediaQuery.of(context).size.width <
                                                                              500
                                                                          ? 14
                                                                          : 18),
                                                            ),
                                                          ),
                                                          DataCell(
                                                            Text(
                                                              Ownersdetails!
                                                                      .rentalOwnerPhoneNumber ??
                                                                  'N/A',
                                                              style: TextStyle(
                                                                  fontSize:
                                                                      MediaQuery.of(context).size.width <
                                                                              500
                                                                          ? 14
                                                                          : 18),
                                                            ),
                                                          ),
                                                          DataCell(
                                                            Row(
                                                              children: [
                                                                InkWell(
                                                                  onTap: () {
                                                                    Navigator
                                                                        .push(
                                                                      context,
                                                                      MaterialPageRoute(
                                                                        builder:
                                                                            (context) =>
                                                                                AddRentalowners(
                                                                          OwnersDetails:
                                                                              Ownersdetails,
                                                                          isEdit:
                                                                              true,
                                                                        ),
                                                                      ),
                                                                    );
                                                                  },
                                                                  child:
                                                                      Container(
                                                                    padding:
                                                                        EdgeInsets
                                                                            .zero,
                                                                    child:
                                                                        FaIcon(
                                                                      FontAwesomeIcons
                                                                          .edit,
                                                                      size: MediaQuery.of(context).size.width <
                                                                              500
                                                                          ? 17
                                                                          : 20,
                                                                    ),
                                                                  ),
                                                                ),
                                                                const SizedBox(
                                                                    width: 4),
                                                                InkWell(
                                                                  onTap: () {
                                                                    provider
                                                                        .clearOwners();
                                                                    setState(
                                                                        () {
                                                                      RentalOwner?
                                                                          owner;
                                                                      Ownersdetails =
                                                                          owner;
                                                                    });
                                                                  },
                                                                  child:
                                                                      Container(
                                                                    padding:
                                                                        EdgeInsets
                                                                            .zero,
                                                                    child:
                                                                        FaIcon(
                                                                      FontAwesomeIcons
                                                                          .trashCan,
                                                                      size: MediaQuery.of(context).size.width <
                                                                              500
                                                                          ? 17
                                                                          : 20,
                                                                    ),
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 15),
                                            ],
                                          ),
                                        ],
                                      )
                                    : const Text('');
                              },
                            ),
                          ],
                        )),
                  ),
                ),
                const SizedBox(height: 25),
                Material(
                  elevation: 6,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: blueColor),
                    ),
                    child: Padding(
                        padding: const EdgeInsets.only(
                            left: 10, right: 10, top: 10, bottom: 10),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                const SizedBox(
                                  width: 15,
                                ),
                                Expanded(
                                  child: Text(
                                    "Who will be primary manager of this Property ?",
                                    style: TextStyle(
                                        color: const Color(0xFF8A95A8),
                                        //  fontWeight: FontWeight.bold,
                                        fontSize:
                                            MediaQuery.of(context).size.width <
                                                    500
                                                ? 14.5
                                                : 18),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(
                              height: 10,
                            ),
                            Row(
                              children: [
                                const SizedBox(
                                  width: 15,
                                ),
                                Expanded(
                                  child: Text(
                                    "If staff member has not yet been added as user in your account ,they can be added to the account"
                                    ",than as the manager later through the property's summary details.",
                                    style: TextStyle(
                                        color: const Color(0xFF8A95A8),
                                        //  fontWeight: FontWeight.bold,
                                        fontSize:
                                            MediaQuery.of(context).size.width <
                                                    500
                                                ? 14
                                                : 18),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(
                              height: 10,
                            ),
                            Row(
                              children: [
                                const SizedBox(
                                  width: 15,
                                ),
                                Text(
                                  "Manage (Optional)",
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: blueColor,
                                      fontSize: 15),
                                ),
                              ],
                            ),
                            const SizedBox(
                              height: 10,
                            ),
                            Row(
                              children: [
                                FutureBuilder<List<Staffmembers>>(
                                  future: futureStaffMembers,
                                  builder: (context, snapshot) {
                                    if (snapshot.connectionState ==
                                        ConnectionState.waiting) {
                                      return const Center(
                                          child: SpinKitFadingCircle(
                                        color: Colors.black,
                                        size: 40.0,
                                      ));
                                    } else if (snapshot.hasError) {
                                      return Text(friendlyErrorMessage(snapshot.error), textAlign: TextAlign.center);
                                    } else if (!snapshot.hasData ||
                                        snapshot.data!.isEmpty) {
                                      return const Text(
                                          'No staff members found');
                                    } else {
                                      List<Staffmembers> staffMembers =
                                          snapshot.data!;

                                      // Sort staff members alphabetically by name (A-Z)
                                      staffMembers.sort((a, b) =>
                                          (a.staffmemberName ?? '')
                                              .toLowerCase()
                                              .compareTo(
                                                  (b.staffmemberName ?? '')
                                                      .toLowerCase()));

                                      List<DropdownMenuItem<String>>
                                          dropdownItems = staffMembers
                                              .map<DropdownMenuItem<String>>(
                                                  (Staffmembers staffMember) {
                                        return DropdownMenuItem<String>(
                                          value: staffMember.sId,
                                          onTap: () {
                                            setState(() {
                                              sid = staffMember.staffmemberId;
                                            });
                                          },
                                          child: Text(
                                            staffMember.staffmemberName ?? '',
                                            style:
                                                const TextStyle(fontSize: 14),
                                          ),
                                        );
                                      }).toList();
                                      // Add the special "Add new property" item
                                      dropdownItems.add(
                                        DropdownMenuItem<String>(
                                          value: 'Edit_properties',
                                          child: GestureDetector(
                                            onTap: () {
                                              name.clear();
                                              designation.clear();
                                              phonenumber.clear();
                                              email.clear();
                                              password.clear();
                                              nameerror = false;
                                              designationerror = false;
                                              phonenumbererror = false;
                                              emailerror = false;
                                              passworderror = false;
                                              Navigator.of(context).pop();
                                              showDialog(
                                                context: context,
                                                builder:
                                                    (BuildContext context) {
                                                  bool isChecked =
                                                      false; // Moved isChecked inside the StatefulBuilder
                                                  return StatefulBuilder(
                                                    builder: (BuildContext
                                                            context,
                                                        StateSetter setState) {
                                                      return Dialog(
                                                        backgroundColor:
                                                            Colors.white,
                                                        surfaceTintColor:
                                                            Colors.white,
                                                        child: Padding(
                                                          padding:
                                                              const EdgeInsets
                                                                  .only(
                                                                  left: 10,
                                                                  right: 5,
                                                                  bottom: 20,
                                                                  top: 10),
                                                          child:
                                                              SingleChildScrollView(
                                                            child: Column(
                                                              children: [
                                                                Row(
                                                                  children: [
                                                                    const Spacer(),
                                                                    InkWell(
                                                                      onTap:
                                                                          () {
                                                                        Navigator.pop(
                                                                            context);
                                                                      },
                                                                      child:
                                                                          Container(
                                                                        //    color: Colors.redAccent,
                                                                        padding:
                                                                            EdgeInsets.zero,
                                                                        child:
                                                                            const FaIcon(
                                                                          FontAwesomeIcons
                                                                              .xmark,
                                                                          size:
                                                                              20,
                                                                          color:
                                                                              Color(0xFF8A95A8),
                                                                        ),
                                                                      ),
                                                                    ),
                                                                    const SizedBox(
                                                                      width: 5,
                                                                    ),
                                                                  ],
                                                                ),
                                                                Row(
                                                                  children: [
                                                                    const SizedBox(
                                                                      width: 15,
                                                                    ),
                                                                    Text(
                                                                      "New Staff Member",
                                                                      style: TextStyle(
                                                                          color:
                                                                              blueColor,
                                                                          fontWeight: FontWeight
                                                                              .bold,
                                                                          fontSize:
                                                                              18),
                                                                    ),
                                                                  ],
                                                                ),
                                                                const SizedBox(
                                                                  height: 10,
                                                                ),
                                                                const Row(
                                                                  children: [
                                                                    SizedBox(
                                                                      width: 15,
                                                                    ),
                                                                    Text(
                                                                      "Staff member name..*",
                                                                      style: TextStyle(
                                                                          color: Color(
                                                                              0xFF8A95A8),
                                                                          fontWeight: FontWeight
                                                                              .bold,
                                                                          fontSize:
                                                                              13),
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
                                                                            15),
                                                                    Material(
                                                                      elevation:
                                                                          4,
                                                                      child:
                                                                          Container(
                                                                        height:
                                                                            50,
                                                                        width: MediaQuery.of(context).size.width *
                                                                            .63,
                                                                        decoration:
                                                                            BoxDecoration(
                                                                          borderRadius:
                                                                              BorderRadius.circular(2),
                                                                          border:
                                                                              Border.all(
                                                                            color:
                                                                                const Color(0xFF8A95A8),
                                                                          ),
                                                                        ),
                                                                        child:
                                                                            Stack(
                                                                          children: [
                                                                            Positioned.fill(
                                                                              child: TextField(
                                                                                onChanged: (value) {
                                                                                  setState(() {
                                                                                    nameerror = false;
                                                                                  });
                                                                                },
                                                                                controller: name,
                                                                                cursorColor: blueColor,
                                                                                decoration: InputDecoration(
                                                                                  hintText: "Enter a staff member name here..*",
                                                                                  hintStyle: const TextStyle(
                                                                                    fontSize: 13,
                                                                                    color: Color(0xFF8A95A8),
                                                                                  ),
                                                                                  enabledBorder: nameerror
                                                                                      ? OutlineInputBorder(
                                                                                          borderRadius: BorderRadius.circular(2),
                                                                                          borderSide: const BorderSide(
                                                                                            color: Colors.red,
                                                                                          ),
                                                                                        )
                                                                                      : InputBorder.none,
                                                                                  border: InputBorder.none,
                                                                                  contentPadding: const EdgeInsets.all(12),
                                                                                ),
                                                                              ),
                                                                            ),
                                                                          ],
                                                                        ),
                                                                      ),
                                                                    ),
                                                                    const SizedBox(
                                                                        width:
                                                                            20),
                                                                  ],
                                                                ),
                                                                nameerror
                                                                    ? Row(
                                                                        children: [
                                                                          const SizedBox(
                                                                            width:
                                                                                12,
                                                                          ),
                                                                          Expanded(
                                                                            child:
                                                                                Text(
                                                                              namemessage,
                                                                              style: const TextStyle(color: Colors.red, fontSize: 14),
                                                                            ),
                                                                          ),
                                                                          const SizedBox(
                                                                            width:
                                                                                20,
                                                                          ),
                                                                        ],
                                                                      )
                                                                    : Container(),
                                                                const SizedBox(
                                                                  height: 10,
                                                                ),
                                                                const Row(
                                                                  children: [
                                                                    SizedBox(
                                                                      width: 15,
                                                                    ),
                                                                    Text(
                                                                      "Designation...*",
                                                                      style: TextStyle(
                                                                          // color: Colors.grey,
                                                                          color: Color(0xFF8A95A8),
                                                                          fontWeight: FontWeight.bold,
                                                                          fontSize: 13),
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
                                                                            15),
                                                                    Material(
                                                                      elevation:
                                                                          4,
                                                                      child:
                                                                          Container(
                                                                        height:
                                                                            50,
                                                                        width: MediaQuery.of(context).size.width *
                                                                            .63,
                                                                        decoration:
                                                                            BoxDecoration(
                                                                          borderRadius:
                                                                              BorderRadius.circular(2),
                                                                          border:
                                                                              Border.all(
                                                                            color:
                                                                                const Color(0xFF8A95A8),
                                                                          ),
                                                                        ),
                                                                        child:
                                                                            Stack(
                                                                          children: [
                                                                            Positioned.fill(
                                                                              child: TextField(
                                                                                onChanged: (value) {
                                                                                  setState(() {
                                                                                    designationerror = false;
                                                                                  });
                                                                                },
                                                                                controller: designation,
                                                                                cursorColor: blueColor,
                                                                                decoration: InputDecoration(
                                                                                  hintText: "Enter Designation here..*",
                                                                                  hintStyle: const TextStyle(
                                                                                    fontSize: 13,
                                                                                    color: Color(0xFF8A95A8),
                                                                                  ),
                                                                                  enabledBorder: designationerror
                                                                                      ? OutlineInputBorder(
                                                                                          borderRadius: BorderRadius.circular(2),
                                                                                          borderSide: const BorderSide(
                                                                                            color: Colors.red,
                                                                                          ),
                                                                                        )
                                                                                      : InputBorder.none,
                                                                                  border: InputBorder.none,
                                                                                  contentPadding: const EdgeInsets.all(12),
                                                                                ),
                                                                              ),
                                                                            ),
                                                                          ],
                                                                        ),
                                                                      ),
                                                                    ),
                                                                    const SizedBox(
                                                                        width:
                                                                            20),
                                                                  ],
                                                                ),
                                                                designationerror
                                                                    ? Row(
                                                                        children: [
                                                                          const SizedBox(
                                                                            width:
                                                                                12,
                                                                          ),
                                                                          Expanded(
                                                                            child:
                                                                                Text(
                                                                              designationmessage,
                                                                              style: const TextStyle(color: Colors.red, fontSize: 14),
                                                                            ),
                                                                          ),
                                                                          const SizedBox(
                                                                            width:
                                                                                20,
                                                                          ),
                                                                        ],
                                                                      )
                                                                    : Container(),
                                                                const SizedBox(
                                                                  height: 10,
                                                                ),
                                                                const Row(
                                                                  children: [
                                                                    SizedBox(
                                                                      width: 15,
                                                                    ),
                                                                    Text(
                                                                      "Phone Number...",
                                                                      style: TextStyle(
                                                                          // color: Colors.grey,
                                                                          color: Color(0xFF8A95A8),
                                                                          fontWeight: FontWeight.bold,
                                                                          fontSize: 13),
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
                                                                            15),
                                                                    Material(
                                                                      elevation:
                                                                          4,
                                                                      child:
                                                                          Container(
                                                                        height:
                                                                            50,
                                                                        width: MediaQuery.of(context).size.width *
                                                                            .63,
                                                                        decoration:
                                                                            BoxDecoration(
                                                                          borderRadius:
                                                                              BorderRadius.circular(2),
                                                                          border:
                                                                              Border.all(
                                                                            color:
                                                                                const Color(0xFF8A95A8),
                                                                          ),
                                                                        ),
                                                                        child:
                                                                            Stack(
                                                                          children: [
                                                                            Positioned.fill(
                                                                              child: TextField(
                                                                                onChanged: (value) {
                                                                                  setState(() {
                                                                                    phonenumbererror = false;
                                                                                  });
                                                                                },
                                                                                controller: phonenumber,
                                                                                inputFormatters: [
                                                                                  FilteringTextInputFormatter.digitsOnly,
                                                                                  LengthLimitingTextInputFormatter(10),
                                                                                  PhoneNumberFormatter(),
                                                                                ],
                                                                                keyboardType: TextInputType.number,
                                                                                cursorColor: blueColor,
                                                                                decoration: InputDecoration(
                                                                                  hintText: "Enter Phone Number here..*",
                                                                                  hintStyle: const TextStyle(
                                                                                    fontSize: 13,
                                                                                    color: Color(0xFF8A95A8),
                                                                                  ),
                                                                                  enabledBorder: phonenumbererror
                                                                                      ? OutlineInputBorder(
                                                                                          borderRadius: BorderRadius.circular(2),
                                                                                          borderSide: const BorderSide(
                                                                                            color: Colors.red,
                                                                                          ),
                                                                                        )
                                                                                      : InputBorder.none,
                                                                                  border: InputBorder.none,
                                                                                  contentPadding: const EdgeInsets.all(12),
                                                                                ),
                                                                              ),
                                                                            ),
                                                                          ],
                                                                        ),
                                                                      ),
                                                                    ),
                                                                    const SizedBox(
                                                                        width:
                                                                            20),
                                                                  ],
                                                                ),
                                                                phonenumbererror
                                                                    ? Row(
                                                                        children: [
                                                                          const SizedBox(
                                                                            width:
                                                                                12,
                                                                          ),
                                                                          Expanded(
                                                                            child:
                                                                                Text(
                                                                              phonenumbermessage,
                                                                              style: const TextStyle(color: Colors.red, fontSize: 14),
                                                                            ),
                                                                          ),
                                                                          const SizedBox(
                                                                            width:
                                                                                20,
                                                                          ),
                                                                        ],
                                                                      )
                                                                    : Container(),
                                                                const SizedBox(
                                                                  height: 10,
                                                                ),
                                                                const Row(
                                                                  children: [
                                                                    SizedBox(
                                                                      width: 15,
                                                                    ),
                                                                    Text(
                                                                      "Email...*",
                                                                      style: TextStyle(
                                                                          // color: Colors.grey,
                                                                          color: Color(0xFF8A95A8),
                                                                          fontWeight: FontWeight.bold,
                                                                          fontSize: 13),
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
                                                                            15),
                                                                    Material(
                                                                      elevation:
                                                                          4,
                                                                      child:
                                                                          Container(
                                                                        height:
                                                                            50,
                                                                        width: MediaQuery.of(context).size.width *
                                                                            .63,
                                                                        decoration:
                                                                            BoxDecoration(
                                                                          borderRadius:
                                                                              BorderRadius.circular(2),
                                                                          border:
                                                                              Border.all(
                                                                            color:
                                                                                const Color(0xFF8A95A8),
                                                                          ),
                                                                        ),
                                                                        child:
                                                                            Stack(
                                                                          children: [
                                                                            Positioned.fill(
                                                                              child: TextField(
                                                                                onChanged: (value) {
                                                                                  setState(() {
                                                                                    emailerror = false;
                                                                                  });
                                                                                },
                                                                                controller: email,
                                                                                cursorColor: blueColor,
                                                                                decoration: InputDecoration(
                                                                                  hintText: "Enter Email here..*",
                                                                                  hintStyle: const TextStyle(
                                                                                    fontSize: 13,
                                                                                    color: Color(0xFF8A95A8),
                                                                                  ),
                                                                                  enabledBorder: emailerror
                                                                                      ? OutlineInputBorder(
                                                                                          borderRadius: BorderRadius.circular(2),
                                                                                          borderSide: const BorderSide(
                                                                                            color: Colors.red,
                                                                                          ),
                                                                                        )
                                                                                      : InputBorder.none,
                                                                                  border: InputBorder.none,
                                                                                  contentPadding: const EdgeInsets.all(12),
                                                                                ),
                                                                              ),
                                                                            ),
                                                                          ],
                                                                        ),
                                                                      ),
                                                                    ),
                                                                    const SizedBox(
                                                                        width:
                                                                            20),
                                                                  ],
                                                                ),
                                                                emailerror
                                                                    ? Row(
                                                                        children: [
                                                                          const SizedBox(
                                                                            width:
                                                                                12,
                                                                          ),
                                                                          Expanded(
                                                                            child:
                                                                                Text(
                                                                              emailmessage,
                                                                              style: const TextStyle(color: Colors.red, fontSize: 14),
                                                                            ),
                                                                          ),
                                                                          const SizedBox(
                                                                            width:
                                                                                20,
                                                                          ),
                                                                        ],
                                                                      )
                                                                    : Container(),
                                                                const SizedBox(
                                                                  height: 10,
                                                                ),
                                                                const Row(
                                                                  children: [
                                                                    SizedBox(
                                                                      width: 15,
                                                                    ),
                                                                    Text(
                                                                      "Password...*",
                                                                      style: TextStyle(
                                                                          // color: Colors.grey,
                                                                          color: Color(0xFF8A95A8),
                                                                          fontWeight: FontWeight.bold,
                                                                          fontSize: 13),
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
                                                                            15),
                                                                    Material(
                                                                      elevation:
                                                                          4,
                                                                      child:
                                                                          Container(
                                                                        height:
                                                                            50,
                                                                        width: MediaQuery.of(context).size.width *
                                                                            .63,
                                                                        decoration:
                                                                            BoxDecoration(
                                                                          borderRadius:
                                                                              BorderRadius.circular(2),
                                                                          border:
                                                                              Border.all(
                                                                            color:
                                                                                const Color(0xFF8A95A8),
                                                                          ),
                                                                        ),
                                                                        child:
                                                                            Stack(
                                                                          children: [
                                                                            Positioned.fill(
                                                                              child: TextField(
                                                                                onChanged: (value) {
                                                                                  setState(() {
                                                                                    passworderror = false;
                                                                                  });
                                                                                },
                                                                                controller: password,
                                                                                cursorColor: blueColor,
                                                                                decoration: InputDecoration(
                                                                                  hintText: "Enter Password here..*",
                                                                                  hintStyle: const TextStyle(
                                                                                    fontSize: 13,
                                                                                    color: Color(0xFF8A95A8),
                                                                                  ),
                                                                                  enabledBorder: passworderror
                                                                                      ? OutlineInputBorder(
                                                                                          borderRadius: BorderRadius.circular(2),
                                                                                          borderSide: const BorderSide(
                                                                                            color: Colors.red,
                                                                                          ),
                                                                                        )
                                                                                      : InputBorder.none,
                                                                                  border: InputBorder.none,
                                                                                  contentPadding: const EdgeInsets.all(12),
                                                                                ),
                                                                              ),
                                                                            ),
                                                                          ],
                                                                        ),
                                                                      ),
                                                                    ),
                                                                    const SizedBox(
                                                                        width:
                                                                            20),
                                                                  ],
                                                                ),
                                                                passworderror
                                                                    ? Row(
                                                                        children: [
                                                                          const SizedBox(
                                                                            width:
                                                                                12,
                                                                          ),
                                                                          Expanded(
                                                                            child:
                                                                                Text(
                                                                              passwordmessage,
                                                                              style: const TextStyle(color: Colors.red, fontSize: 14),
                                                                            ),
                                                                          ),
                                                                          const SizedBox(
                                                                            width:
                                                                                20,
                                                                          ),
                                                                        ],
                                                                      )
                                                                    : Container(),
                                                                const SizedBox(
                                                                  height: 20,
                                                                ),
                                                                Row(
                                                                  children: [
                                                                    if (MediaQuery.of(context)
                                                                            .size
                                                                            .width >
                                                                        500)
                                                                      SizedBox(
                                                                        width: MediaQuery.of(context).size.width *
                                                                            0.013,
                                                                      ),
                                                                    if (MediaQuery.of(context)
                                                                            .size
                                                                            .width <
                                                                        500)
                                                                      SizedBox(
                                                                        width: MediaQuery.of(context).size.width *
                                                                            0.035,
                                                                      ),
                                                                    //                                                                   GestureDetector(
                                                                    //                                                                     onTap:
                                                                    //                                                                         () async {
                                                                    //                                                                       if (name
                                                                    //                                                                           .text
                                                                    //                                                                           .isEmpty) {
                                                                    //                                                                         setState(
                                                                    //                                                                             () {
                                                                    //                                                                           nameerror =
                                                                    //                                                                               true;
                                                                    //                                                                           namemessage =
                                                                    //                                                                               "required";
                                                                    //                                                                         });
                                                                    //                                                                       } else {
                                                                    //                                                                         setState(
                                                                    //                                                                             () {
                                                                    //                                                                           nameerror =
                                                                    //                                                                               false;
                                                                    //                                                                         });
                                                                    //                                                                       }
                                                                    //                                                                       if (designation
                                                                    //                                                                           .text
                                                                    //                                                                           .isEmpty) {
                                                                    //                                                                         setState(
                                                                    //                                                                             () {
                                                                    //                                                                           designationerror =
                                                                    //                                                                               true;
                                                                    //                                                                           designationmessage =
                                                                    //                                                                               "required";
                                                                    //                                                                         });
                                                                    //                                                                       } else {
                                                                    //                                                                         setState(
                                                                    //                                                                             () {
                                                                    //                                                                           designationerror =
                                                                    //                                                                               false;
                                                                    //                                                                         });
                                                                    //                                                                       }
                                                                    //                                                                       if (phonenumber
                                                                    //                                                                           .text
                                                                    //                                                                           .isEmpty) {
                                                                    //                                                                         setState(
                                                                    //                                                                             () {
                                                                    //                                                                           phonenumbererror =
                                                                    //                                                                               true;
                                                                    //                                                                           phonenumbermessage =
                                                                    //                                                                               "required";
                                                                    //                                                                         });
                                                                    //                                                                       } else {
                                                                    //                                                                         setState(
                                                                    //                                                                             () {
                                                                    //                                                                           phonenumbererror =
                                                                    //                                                                               false;
                                                                    //                                                                         });
                                                                    //                                                                       }
                                                                    //                                                                       if (email
                                                                    //                                                                           .text
                                                                    //                                                                           .isEmpty) {
                                                                    //                                                                         setState(
                                                                    //                                                                             () {
                                                                    //                                                                           emailerror =
                                                                    //                                                                               true;
                                                                    //                                                                           emailmessage =
                                                                    //                                                                               "required";
                                                                    //                                                                         });
                                                                    //                                                                       } else {
                                                                    //                                                                         setState(
                                                                    //                                                                             () {
                                                                    //                                                                           emailerror =
                                                                    //                                                                               false;
                                                                    //                                                                         });
                                                                    //                                                                       }
                                                                    //                                                                       if (password
                                                                    //                                                                           .text
                                                                    //                                                                           .isEmpty) {
                                                                    //                                                                         setState(
                                                                    //                                                                             () {
                                                                    //                                                                           passworderror =
                                                                    //                                                                               true;
                                                                    //                                                                           passwordmessage =
                                                                    //                                                                               "required";
                                                                    //                                                                         });
                                                                    //                                                                       } else {
                                                                    //                                                                         setState(
                                                                    //                                                                             () {
                                                                    //                                                                           passworderror =
                                                                    //                                                                               false;
                                                                    //                                                                         });
                                                                    //                                                                       }
                                                                    //                                                                       if (!nameerror &&
                                                                    //                                                                           !designationerror &&
                                                                    //                                                                           !phonenumbererror &&
                                                                    //                                                                           !emailerror &&
                                                                    //                                                                           !phonenumbererror) {
                                                                    //                                                                         setState(
                                                                    //                                                                             () {
                                                                    //                                                                           loading =
                                                                    //                                                                               true;
                                                                    //                                                                         });
                                                                    //                                                                       }
                                                                    //                                                                       SharedPreferences
                                                                    //                                                                           prefs =
                                                                    //                                                                           await SharedPreferences
                                                                    //                                                                               .getInstance();
                                                                    //                                                                       String?
                                                                    //                                                                           adminId =
                                                                    //                                                                           prefs.getString(
                                                                    //                                                                               "adminId");
                                                                    //                                                                       if (adminId !=
                                                                    //                                                                           null) {
                                                                    //                                                                         try {
                                                                    //                                                                           await StaffMemberRepository()
                                                                    //                                                                               .addStaffMember(
                                                                    //                                                                             adminId:
                                                                    //                                                                                 adminId,
                                                                    //                                                                             staffmemberName:
                                                                    //                                                                                 name.text,
                                                                    //                                                                             staffmemberDesignation:
                                                                    //                                                                                 designation.text,
                                                                    //                                                                             staffmemberPhoneNumber:
                                                                    //                                                                                 phonenumber.text,
                                                                    //                                                                             staffmemberEmail:
                                                                    //                                                                                 email.text,
                                                                    //                                                                             staffmemberPassword:
                                                                    //                                                                                 password.text,
                                                                    //                                                                           );
                                                                    //                                                                           setState(
                                                                    //                                                                               () {
                                                                    //                                                                             loading =
                                                                    //                                                                                 false;
                                                                    //                                                                           });
                                                                    //                                                                           Navigator.of(context)
                                                                    //                                                                               .pop(true);
                                                                    //                                                                         } catch (e) {
                                                                    //                                                                           setState(
                                                                    //                                                                               () {
                                                                    //                                                                             loading =
                                                                    //                                                                                 false;
                                                                    //                                                                           });
                                                                    //                                                                           // Handle error
                                                                    //                                                                         }
                                                                    //                                                                       }
                                                                    //                                                                     },
                                                                    //                                                                     child:
                                                                    //                                                                         ClipRRect(
                                                                    //                                                                       borderRadius:
                                                                    //                                                                           BorderRadius.circular(
                                                                    //                                                                               5.0),
                                                                    //                                                                       child:
                                                                    //                                                                           Container(
                                                                    //                                                                         height:
                                                                    //                                                                             30.0,
                                                                    //                                                                         width: MediaQuery.of(context).size.width *
                                                                    //                                                                             .36,
                                                                    //                                                                         decoration:
                                                                    //                                                                             BoxDecoration(
                                                                    //                                                                           borderRadius:
                                                                    //                                                                               BorderRadius.circular(5.0),
                                                                    //                                                                           color: blueColor
                                                                    //
                                                                    //
                                                                    // ,
                                                                    //                                                                           boxShadow: [
                                                                    //                                                                             BoxShadow(
                                                                    //                                                                               color: Colors.grey,
                                                                    //                                                                               offset: Offset(0.0, 1.0), //(x,y)
                                                                    //                                                                               blurRadius: 6.0,
                                                                    //                                                                             ),
                                                                    //                                                                           ],
                                                                    //                                                                         ),
                                                                    //                                                                         child:
                                                                    //                                                                             Center(
                                                                    //                                                                           child:
                                                                    //                                                                               Text(
                                                                    //                                                                             "Add staff Member",
                                                                    //                                                                             style: TextStyle(
                                                                    //                                                                                 color: Colors.white,
                                                                    //                                                                                 fontWeight: FontWeight.bold,
                                                                    //                                                                                 fontSize: MediaQuery.of(context).size.width < 500 ? 15 : 18),
                                                                    //                                                                           ),
                                                                    //                                                                         ),
                                                                    //                                                                       ),
                                                                    //                                                                     ),
                                                                    //                                                                   ),
                                                                    GestureDetector(
                                                                      onTap:
                                                                          () async {
                                                                        // Reset error states
                                                                        setState(
                                                                            () {
                                                                          nameerror =
                                                                              false;
                                                                          designationerror =
                                                                              false;
                                                                          phonenumbererror =
                                                                              false;
                                                                          emailerror =
                                                                              false;
                                                                          passworderror =
                                                                              false;
                                                                        });

                                                                        // Validate fields
                                                                        bool
                                                                            isValid =
                                                                            true;

                                                                        if (name
                                                                            .text
                                                                            .isEmpty) {
                                                                          setState(
                                                                              () {
                                                                            nameerror =
                                                                                true;
                                                                            namemessage =
                                                                                "required";
                                                                          });
                                                                          isValid =
                                                                              false;
                                                                        }

                                                                        if (designation
                                                                            .text
                                                                            .isEmpty) {
                                                                          setState(
                                                                              () {
                                                                            designationerror =
                                                                                true;
                                                                            designationmessage =
                                                                                "required";
                                                                          });
                                                                          isValid =
                                                                              false;
                                                                        }

                                                                        // Validate phone number
                                                                        String formattedPhoneNumber = phonenumber.text.replaceAll(
                                                                            RegExp(r'\D'),
                                                                            '');
                                                                        if (formattedPhoneNumber
                                                                            .isEmpty) {
                                                                          setState(
                                                                              () {
                                                                            phonenumbererror =
                                                                                true;
                                                                            phonenumbermessage =
                                                                                "required";
                                                                          });
                                                                          isValid =
                                                                              false;
                                                                        } else if (formattedPhoneNumber.length !=
                                                                            10) {
                                                                          setState(
                                                                              () {
                                                                            phonenumbererror =
                                                                                true;
                                                                            phonenumbermessage =
                                                                                "must be 10 digits";
                                                                          });
                                                                          isValid =
                                                                              false;
                                                                        } else {
                                                                          setState(
                                                                              () {
                                                                            phonenumbererror =
                                                                                false;
                                                                          });
                                                                        }

                                                                        // Validate email
                                                                        if (email
                                                                            .text
                                                                            .isEmpty) {
                                                                          setState(
                                                                              () {
                                                                            emailerror =
                                                                                true;
                                                                            emailmessage =
                                                                                "required";
                                                                          });
                                                                          isValid =
                                                                              false;
                                                                        } else if (!EmailValidator.validate(
                                                                            email.text)) {
                                                                          setState(
                                                                              () {
                                                                            emailerror =
                                                                                true;
                                                                            emailmessage =
                                                                                "Email is not valid";
                                                                          });
                                                                          isValid =
                                                                              false;
                                                                        } else {
                                                                          setState(
                                                                              () {
                                                                            emailerror =
                                                                                false;
                                                                          });
                                                                        }

                                                                        // Validate password
                                                                        if (password
                                                                            .text
                                                                            .isEmpty) {
                                                                          setState(
                                                                              () {
                                                                            passworderror =
                                                                                true;
                                                                            passwordmessage =
                                                                                "required";
                                                                          });
                                                                          isValid =
                                                                              false;
                                                                        } else if (password.text.length <
                                                                            8) {
                                                                          setState(
                                                                              () {
                                                                            passworderror =
                                                                                true;
                                                                            passwordmessage =
                                                                                "at least 8 characters";
                                                                          });
                                                                          isValid =
                                                                              false;
                                                                        } else {
                                                                          String?
                                                                              validationMessage =
                                                                              ValidatePassword(password.text);
                                                                          if (validationMessage !=
                                                                              null) {
                                                                            setState(() {
                                                                              passworderror = true;
                                                                              passwordmessage = validationMessage; // Use the dynamic message
                                                                            });
                                                                            isValid =
                                                                                false;
                                                                          } else {
                                                                            setState(() {
                                                                              passworderror = false; // No error
                                                                            });
                                                                          }
                                                                        }

                                                                        // If all fields are valid, proceed to add the staff member
                                                                        if (isValid) {
                                                                          setState(
                                                                              () {
                                                                            loading =
                                                                                true;
                                                                          });

                                                                          SharedPreferences
                                                                              prefs =
                                                                              await SharedPreferences.getInstance();
                                                                          String?
                                                                              adminId =
                                                                              prefs.getString("adminId");

                                                                          if (adminId !=
                                                                              null) {
                                                                            try {
                                                                              await StaffMemberRepository().addStaffMember(
                                                                                adminId: adminId,
                                                                                staffmemberName: name.text,
                                                                                staffmemberDesignation: designation.text,
                                                                                staffmemberPhoneNumber: phonenumber.text,
                                                                                staffmemberEmail: email.text,
                                                                                staffmemberPassword: password.text,
                                                                              );
                                                                              setState(() {
                                                                                loading = false;
                                                                              });
                                                                              Navigator.of(context).pop(true);
                                                                            } catch (e) {
                                                                              setState(() {
                                                                                loading = false;
                                                                              });
                                                                              // Handle error
                                                                            }
                                                                          }
                                                                        }
                                                                      },
                                                                      child:
                                                                          ClipRRect(
                                                                        borderRadius:
                                                                            BorderRadius.circular(5.0),
                                                                        child:
                                                                            Container(
                                                                          height:
                                                                              37.0,
                                                                          width:
                                                                              MediaQuery.of(context).size.width * .36,
                                                                          decoration:
                                                                              BoxDecoration(
                                                                            borderRadius:
                                                                                BorderRadius.circular(5.0),
                                                                            color:
                                                                                blueColor,
                                                                            boxShadow: [
                                                                              const BoxShadow(
                                                                                color: Colors.grey,
                                                                                offset: Offset(0.0, 1.0), //(x,y)
                                                                                blurRadius: 6.0,
                                                                              ),
                                                                            ],
                                                                          ),
                                                                          child:
                                                                              Center(
                                                                            child: loading
                                                                                ? const SpinKitFadingCircle(
                                                                                    color: Colors.white,
                                                                                    size: 25.0,
                                                                                  )
                                                                                : Text(
                                                                                    "Add Staff Member",
                                                                                    style: TextStyle(
                                                                                      color: Colors.white,
                                                                                      fontWeight: FontWeight.bold,
                                                                                      fontSize: MediaQuery.of(context).size.width < 500 ? 14 : 18,
                                                                                    ),
                                                                                  ),
                                                                          ),
                                                                        ),
                                                                      ),
                                                                    ),
                                                                    const SizedBox(
                                                                      width: 15,
                                                                    ),
                                                                    InkWell(
                                                                      onTap:
                                                                          () {
                                                                        Navigator.pop(
                                                                            context);
                                                                      },
                                                                      child: const Text(
                                                                          "Cancel"),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                      );
                                                    },
                                                  );
                                                },
                                              );
                                            },
                                            child: Row(
                                              children: [
                                                const Icon(
                                                  Icons.add,
                                                  size: 16,
                                                ),
                                                const SizedBox(width: 3),
                                                Text(
                                                  'Add New Staffmember',
                                                  style: TextStyle(
                                                      fontSize:
                                                          MediaQuery.of(context)
                                                                      .size
                                                                      .width <
                                                                  500
                                                              ? 12
                                                              : 14),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );

                                      return Padding(
                                        padding: const EdgeInsets.all(10.0),
                                        child: Container(
                                          // height: MediaQuery.of(context)
                                          //         .size
                                          //         .height *
                                          //     .05,
                                          height: 50,
                                          width: MediaQuery.of(context)
                                                  .size
                                                  .width *
                                              .5,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                              color: const Color(0xFF8A95A8),
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          child: DropdownButtonHideUnderline(
                                            child: DropdownButton2<String>(
                                              value: selectedStaff,
                                              hint: Text(
                                                'Select',
                                                style: TextStyle(
                                                  fontSize:
                                                      MediaQuery.of(context)
                                                                  .size
                                                                  .width <
                                                              500
                                                          ? 15
                                                          : 18,
                                                  color:
                                                      const Color(0xFF8A95A8),
                                                ),
                                              ),
                                              onChanged: (String? newValue) {
                                                if (newValue ==
                                                    'Edit_properties') {
                                                  // Prevent the dropdown from changing the selected item
                                                  setState(() {
                                                    selectedStaff = null;
                                                  });
                                                  // // Show the dialog
                                                  // showDialog(
                                                  //   context: context,
                                                  //   builder:
                                                  //       (BuildContext context) {
                                                  //     //  bool isChecked = false; // Moved isChecked inside the StatefulBuilder
                                                  //     return StatefulBuilder(
                                                  //       builder: (BuildContext
                                                  //               context,
                                                  //           StateSetter
                                                  //               setState) {
                                                  //         return AlertDialog(
                                                  //           backgroundColor:
                                                  //               Colors.white,
                                                  //           surfaceTintColor:
                                                  //               Colors.white,
                                                  //           title: Text(
                                                  //             "Add Rental Owner",
                                                  //             style: TextStyle(
                                                  //                 fontWeight:
                                                  //                     FontWeight
                                                  //                         .bold,
                                                  //                 color: Color
                                                  //                     .fromRGBO(
                                                  //                         21,
                                                  //                         43,
                                                  //                         81,
                                                  //                         1),
                                                  //                 fontSize: 15),
                                                  //           ),
                                                  //           content:
                                                  //               SingleChildScrollView(
                                                  //                   child:
                                                  //                       Column(
                                                  //             children: [],
                                                  //           )),
                                                  //         );
                                                  //       },
                                                  //     );
                                                  //   },
                                                  // );
                                                } else {
                                                  setState(() {
                                                    selectedStaff = newValue;
                                                  });
                                                }
                                              },
                                              items: dropdownItems,
                                              isExpanded: true,
                                              buttonStyleData: ButtonStyleData(
                                                height: 50,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 4),
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                  color: Colors.transparent,
                                                ),
                                              ),
                                              dropdownStyleData:
                                                  DropdownStyleData(
                                                maxHeight: 300,
                                                width: MediaQuery.of(context)
                                                        .size
                                                        .width *
                                                    .5,
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                  color: Colors.white,
                                                ),
                                                offset: const Offset(0, -5),
                                                scrollbarTheme:
                                                    ScrollbarThemeData(
                                                  radius:
                                                      const Radius.circular(40),
                                                  thickness:
                                                      MaterialStateProperty.all(
                                                          6),
                                                  thumbVisibility:
                                                      MaterialStateProperty.all(
                                                          true),
                                                ),
                                              ),
                                              menuItemStyleData:
                                                  const MenuItemStyleData(
                                                height: 40,
                                                padding: EdgeInsets.symmetric(
                                                    horizontal: 16,
                                                    vertical: 8),
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                ),
                              ],
                            ),
                          ],
                        )),
                  ),
                ),
                const SizedBox(
                  height: 20,
                ),
                if (selectedpropertytypedata != null &&
                    selectedpropertytypedata!.propertyType == "Residential")
                  Material(
                    elevation: 6,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: blueColor),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.only(
                            left: 10, right: 10, top: 10, bottom: 10),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                const SizedBox(
                                  width: 10,
                                ),
                                Text(
                                  'RESIDENTIAL UNIT',
                                  style: TextStyle(
                                    color: blueColor,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(
                                  width: 10,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8.0),
                            Row(
                              children: [
                                const SizedBox(
                                  width: 10,
                                ),
                                Text(
                                  'Enter Residential Units',
                                  style: TextStyle(
                                    color: blueColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            if (propertyGroups.isNotEmpty)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SingleChildScrollView(
                                    child: Column(
                                      children: propertyGroups.map((group) {
                                        int index =
                                            propertyGroups.indexOf(group);
                                        return Padding(
                                          padding: const EdgeInsets.only(
                                              left: 16, right: 16),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              // Align(
                                              //   alignment:
                                              //       Alignment.centerRight,
                                              //   child: InkWell(
                                              //     onTap: () =>
                                              //         removePropertyGroup(
                                              //             index),
                                              //     child: Icon(Icons.close,
                                              //         color: Colors.black),
                                              //   ),
                                              // ),
                                              Align(
                                                alignment:
                                                    Alignment.centerRight,
                                                child: Visibility(
                                                  visible:
                                                      !(selectedpropertytype ==
                                                              'Residential' &&
                                                          selectedIsMultiUnit ==
                                                              false &&
                                                          index == 0),
                                                  child: InkWell(
                                                    onTap: () =>
                                                        removePropertyGroup(
                                                            index),
                                                    child: const Icon(
                                                        Icons.close,
                                                        color: Colors.black),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 5),
                                              ...group,
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ],
                              ),
                            const SizedBox(
                              height: 15,
                            ),
                            if (selectedpropertytypedata?.isMultiunit == true)
                              GestureDetector(
                                onTap: () {
                                  // if (selectedProperty != null) {
                                  //   addPropertyGroup();
                                  // }
                                  addPropertyGroup();
                                },
                                child: Row(
                                  children: [
                                    SizedBox(
                                        width:
                                            MediaQuery.of(context).size.width *
                                                0.02),
                                    Container(
                                      height: 40,
                                      width: MediaQuery.of(context).size.width *
                                          .35,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        // borderRadius: BorderRadius.circular(3),
                                        borderRadius:
                                            BorderRadius.circular(5.0),
                                        border: Border.all(color: blueColor),
                                        // boxShadow: [
                                        //   BoxShadow(
                                        //     color: Colors.grey,
                                        //     offset: Offset(0.0, 1.0), //(x,y)
                                        //     blurRadius: 6.0,
                                        //   ),
                                        // ],
                                      ),
                                      child: Center(
                                        child: Text(
                                          "Add another unit",
                                          style: TextStyle(
                                              color: blueColor,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (selectedpropertytypedata != null &&
                    selectedpropertytypedata!.propertyType == "Commercial")
                  Material(
                    elevation: 6,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: blueColor),
                      ),
                      child: Padding(
                          padding: const EdgeInsets.only(
                              left: 10, right: 10, top: 10, bottom: 10),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  const SizedBox(
                                    width: 10,
                                  ),
                                  Text(
                                    'COMMERCIAL UNIT',
                                    style: TextStyle(
                                      color: blueColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(
                                    width: 10,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8.0),
                              Row(
                                children: [
                                  const SizedBox(
                                    width: 10,
                                  ),
                                  Text(
                                    'Enter Commercial Units',
                                    style: TextStyle(
                                      color: blueColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              if (propertyGroups.isNotEmpty)
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SingleChildScrollView(
                                      child: Column(
                                        children: propertyGroups.map((group) {
                                          int index =
                                              propertyGroups.indexOf(group);
                                          return Padding(
                                            padding: const EdgeInsets.only(
                                                left: 16, right: 16),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                // Align(
                                                //   alignment:
                                                //       Alignment.centerRight,
                                                //   child: InkWell(
                                                //     onTap: () =>
                                                //         removePropertyGroup(
                                                //             index),
                                                //     child: Icon(Icons.close,
                                                //         color: Colors.black),
                                                //   ),
                                                // ),
                                                Align(
                                                  alignment:
                                                      Alignment.centerRight,
                                                  child: Visibility(
                                                    visible:
                                                        !(selectedpropertytype ==
                                                                'Commercial' &&
                                                            selectedIsMultiUnit ==
                                                                false &&
                                                            index == 0),
                                                    child: InkWell(
                                                      onTap: () =>
                                                          removePropertyGroup(
                                                              index),
                                                      child: const Icon(
                                                          Icons.close,
                                                          color: Colors.black),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(height: 5),
                                                ...group,
                                              ],
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                  ],
                                ),
                              const SizedBox(height: 15),
                              if (selectedpropertytypedata?.isMultiunit == true)
                                GestureDetector(
                                  onTap: () {
                                    addPropertyGroup();
                                  },
                                  child: Row(
                                    children: [
                                      SizedBox(
                                          width: MediaQuery.of(context)
                                                  .size
                                                  .width *
                                              0.02),
                                      Container(
                                        height: 40,
                                        width:
                                            MediaQuery.of(context).size.width *
                                                .35,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          // borderRadius: BorderRadius.circular(3),
                                          borderRadius:
                                              BorderRadius.circular(5.0),
                                          border: Border.all(color: blueColor),
                                          // boxShadow: [
                                          //   BoxShadow(
                                          //     color: Colors.grey,
                                          //     offset: Offset(0.0, 1.0), //(x,y)
                                          //     blurRadius: 6.0,
                                          //   ),
                                          // ],
                                        ),
                                        child: Center(
                                          child: Text(
                                            "Add another unit",
                                            style: TextStyle(
                                                color: blueColor,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          )),
                    ),
                  ),
                if (iserror2)
                  const Text(
                    "required",
                    style: TextStyle(color: Colors.redAccent),
                  ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    //SizedBox(width: MediaQuery.of(context).size.width * 0.01),
                    GestureDetector(
                      onTap: () async {
                        if (_formKey.currentState!.validate()) {
                          //  final ownerDetails = Provider.of<OwnerDetailsProvider>(context).OwnerDetails;
                          /*  List<ProcessorLists> selectedProcessors = _processorGroups
                            .where((group) => group.isChecked)
                            .map((group) => ProcessorLists(processorId: group.controller.text.trim())) // Create ProcessorList objects
                            .where((processor) => processor.processorId!.isNotEmpty) // Filter out empty IDs
                            .toList();*/
                          if (selectedProperty == null) {
                            setState(() {
                              showError = true;
                            });
                          } else {
                            setState(() {
                              showError = false;
                            });
                          }
                          if (address.text.trim().isEmpty) {
                            setState(() {
                              addresserror = true;
                              addressmessage = "required";
                            });
                          } else {
                            setState(() {
                              addresserror = false;
                            });
                          }
                          if (city.text.trim().isEmpty) {
                            setState(() {
                              cityerror = true;
                              citymessage = "required";
                            });
                          } else {
                            setState(() {
                              cityerror = false;
                            });
                          }
                          if (state.text.trim().isEmpty) {
                            setState(() {
                              stateerror = true;
                              statemessage = "required";
                            });
                          } else {
                            setState(() {
                              stateerror = false;
                            });
                          }
                          if (country.text.trim().isEmpty) {
                            setState(() {
                              countryerror = true;
                              countrymessage = "required";
                            });
                          } else {
                            setState(() {
                              countryerror = false;
                            });
                          }
                          if (postalcode.text.trim().isEmpty) {
                            setState(() {
                              postalcodeerror = true;
                              postalcodemessage = "required";
                            });
                          } else {
                            setState(() {
                              postalcodeerror = false;
                            });
                          }
                          if (Ownersdetails == null) {
                            setState(() {
                              hasError = true;
                              postalcodemessage = "required";
                            });
                          } else {
                            setState(() {
                              hasError = false;
                            });
                          }
                          // Web marks this required (Rentals.jsx placed_in_service),
                          // and the asterisk on the label already promises it.
                          if (datePlacedInService.text.trim().isEmpty) {
                            setState(() {
                              datePlacedInServiceError = true;
                              datePlacedInServiceMessage =
                                  "Please enter date placed in service";
                            });
                          } else {
                            setState(() {
                              datePlacedInServiceError = false;
                            });
                          }
                          if (!addresserror &&
                              !cityerror &&
                              !stateerror &&
                              !countryerror &&
                              !postalcodeerror &&
                              !datePlacedInServiceError &&
                              !hasError) {
                            setState(() {
                              loading = true;
                            });
                            RentalOwner? ownerDetails = context
                                .read<OwnerDetailsProvider>()
                                .ownerDetails;
                            String processorId = context
                                    .read<OwnerDetailsProvider>()
                                    .selectedprocessorlist ??
                                "";
                            List<Map<String, String>> processorIds =
                                ownerDetails!.processorList!.map((processor) {
                              return {
                                'processor_id': processor.processorId ?? "",
                              };
                            }).toList();
                            SharedPreferences prefs =
                                await SharedPreferences.getInstance();
                            String? adminId = prefs.getString("adminId");
                            final updatedOwner = RentalOwner(
                              rentalOwnerId:
                                  ownerDetails!.rentalOwnerId ?? null,
                              rentalOwnerName: firstnameController.text.trim(),
                              rentalOwnerCompanyName:
                                  comnameController.text.trim(),
                              rentalOwnerPrimaryEmail:
                                  primaryemailController.text.trim(),
                              rentalOwnerPhoneNumber:
                                  phonenumController.text.trim(),
                              city: cityController.text.trim(),
                              state: stateController.text.trim(),
                              country: countyController.text.trim(),
                              postalCode: codeController.text.trim(),
                            );
                            Provider.of<OwnerDetailsProvider>(context,
                                    listen: false)
                                .setOwnerDetails(updatedOwner);
                            RentalOwners owners = RentalOwners(
                              rentalownersid: updatedOwner.rentalOwnerId,
                              adminId: adminId,
                              firstName: updatedOwner.rentalOwnerName,
                              companyName: updatedOwner.rentalOwnerCompanyName,
                              primaryEmail:
                                  updatedOwner.rentalOwnerPrimaryEmail,
                              phoneNumber: updatedOwner.rentalOwnerPhoneNumber,
                              city: updatedOwner.city,
                              state: updatedOwner.state,
                              country: updatedOwner.country,
                              postalCode: updatedOwner.postalCode,
                              processorid: processorIds!,
                            );
                            if (adminId != null) {
                              //  try {
                              // Format placed_in_service date to yyyy-MM-dd
                              String? formattedPlacedInService;
                              if (datePlacedInService.text.isNotEmpty) {
                                try {
                                  DateTime? parsedDate;
                                  List<String> dateFormats = [
                                    'yyyy-MM-dd', 'yyyy-M-d', 'dd-MM-yyyy',
                                    'd-M-yyyy', 'M/d/yyyy', 'MM/dd/yyyy',
                                  ];
                                  for (String format in dateFormats) {
                                    try {
                                      parsedDate = DateFormat(format)
                                          .parse(datePlacedInService.text);
                                      break;
                                    } catch (e) {
                                      continue;
                                    }
                                  }
                                  if (parsedDate != null) {
                                    formattedPlacedInService =
                                        DateFormat('yyyy-MM-dd')
                                            .format(parsedDate);
                                  }
                                } catch (e) {
                                  logError(
                                      'Error formatting placed_in_service date: $e');
                                }
                              }
                              // Create InsuredValue list from historicalInsuredValues
                              List<InsuredValue> insuredValuesList = [];
                              for (var item in historicalInsuredValues) {
                                if (item.year != null &&
                                    item.year!.isNotEmpty &&
                                    item.valueController.text.isNotEmpty) {
                                  String cleanValue = item.valueController.text
                                      .replaceAll(',', '');
                                  insuredValuesList.add(InsuredValue(
                                    year: item.year,
                                    insuredValue: cleanValue,
                                  ));
                                }
                              }
                              Rental rentals = Rental(
                                  adminId: adminId,
                                  propertyId:
                                      selectedpropertytypedata!.propertyId,
                                  address: address.text.trim(),
                                  city: city.text.trim(),
                                  state: state.text.trim(),
                                  country: country.text.trim(),
                                  postcode: postalcode.text.trim(),
                                  staffMemberId: sid,
                                  processor_id: processorId,
                                  placedInService: formattedPlacedInService,
                                  insuredValues: insuredValuesList.isNotEmpty
                                      ? insuredValuesList
                                      : null);
                              List<Unit> units = [];
                              if (propertyGroupControllers.isNotEmpty) {
                                List<TextEditingController> firstControllers =
                                    propertyGroupControllers[0];
                                bool isFirstBlank = firstControllers.every(
                                    (controller) =>
                                        controller.text.trim().isEmpty);

                                if (isFirstBlank) {
                                  propertyGroupControllers.removeAt(0);
                                }
                              }
                              if (selectedpropertytype == 'Commercial' &&
                                  selectedIsMultiUnit == true) {
                                for (int i = 0;
                                    i < propertyGroupControllers.length;
                                    i++) {
                                  if (units.length <= i) {
                                    units.add(Unit());
                                  }
                                  List<TextEditingController> controllers =
                                      propertyGroupControllers[i];
                                  units[i].unit = controllers[0].text.trim();
                                  units[i].address = controllers[1].text.trim();
                                  units[i].sqft = controllers[2].text.trim();
                                  units[i].Image = propertyGroupImagenames[i];
                                  //      units[i].bath = controllers[3].text;
                                  //     units[i].bed = controllers[4].text;

//                                  units[i].unit = controllers[0].text;
                                }
                                units.removeWhere((unit) =>
                                    unit.unit!.isEmpty ||
                                    unit.address!.isEmpty ||
                                    unit.sqft!.isEmpty);
                              } else if (selectedpropertytype ==
                                      'Residential' &&
                                  selectedIsMultiUnit == true) {
                                for (int i = 0;
                                    i < propertyGroupControllers.length;
                                    i++) {
                                  if (units.length <= i) {
                                    units.add(Unit());
                                  }
                                  List<TextEditingController> controllers =
                                      propertyGroupControllers[i];
                                  units[i].unit = controllers[0].text.trim();
                                  units[i].address = controllers[1].text.trim();
                                  units[i].sqft = controllers[2].text.trim();
                                  units[i].bath = controllers[3].text.trim();
                                  units[i].bed = controllers[4].text.trim();
                                  units[i].Image = propertyGroupImagenames[i];
//                                  units[i].unit = controllers[0].text;
                                }
                                units.removeWhere((unit) =>
                                    unit.unit!.isEmpty ||
                                    unit.address!.isEmpty ||
                                    unit.sqft!.isEmpty ||
                                    unit.bath!.isEmpty ||
                                    unit.bed!.isEmpty);
                              } else if (selectedpropertytype ==
                                  'Residential') {
                                for (int i = 0;
                                    i < propertyGroupControllers.length;
                                    i++) {
                                  if (units.length <= i) {
                                    units.add(Unit());
                                  }
                                  List<TextEditingController> controllers =
                                      propertyGroupControllers[i];
                                  units[i].sqft = controllers[0].text.trim();
                                  units[i].bath = controllers[1].text.trim();
                                  units[i].bed = controllers[2].text.trim();
                                  units[i].Image = propertyGroupImagenames[i];
//                                  units[i].unit = controllers[0].text;
                                }
                                units.removeWhere((unit) =>
                                    unit.bath!.isEmpty ||
                                    unit.bed!.isEmpty ||
                                    unit.sqft!.isEmpty);
                              } else if (selectedpropertytype == 'Commercial') {
                                for (int i = 0;
                                    i < propertyGroupControllers.length;
                                    i++) {
                                  if (units.length <= i) {
                                    units.add(Unit());
                                  }
                                  List<TextEditingController> controllers =
                                      propertyGroupControllers[i];
                                  units[i].sqft = controllers[0].text.trim();
                                  units[i].Image = propertyGroupImagenames[i];
                                  //units[i].address = controllers[1].text;
                                  //units[i].sqft = controllers[2].text;
//                                  units[i].unit = controllers[0].text;
                                }

                                units.removeWhere((unit) => unit.sqft!.isEmpty);
                              }
                              final DateFormat formatter =
                                  DateFormat('yyyy-MM-dd HH:mm:ss');
                              String notificationTime =
                                  formatter.format(DateTime.now());
                              RentalRequest rentalrequest = RentalRequest(
                                rentalOwner: owners,
                                rental: rentals,
                                units: units,
                                notificationTime: notificationTime,
                              );
                              await Rental_PropertiesRepository()
                                  .createRental(rentalrequest)
                                  .then((value) {
                                setState(() {
                                  loading = false;
                                });
                                Navigator.of(context).pop(true);
                              });

                              // await  Rental_PropertiesRepository().addProperties(
                              //   adminId: adminId!,
                              //   property_id: widget.property?.propertyId,
                              //   rental_adress: address.text,
                              //   rental_city: city.text,
                              //   rental_state: state.text,
                              //   rental_country: country.text,
                              //   rental_postcode: postalcode.text,
                              //   staffmember_id: widget.staff!.staffmemberId,
                              //   processor_id: proid.text,
                              // );

                              //  } catch (e) {
                              //   print(e);
                            }
                          }
                        } else {
                        }
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(5.0),
                        child: Container(
                          height: 45,
                          width: MediaQuery.of(context).size.width * .35,
                          decoration: BoxDecoration(
                            color: blueColor,
                            boxShadow: [
                              const BoxShadow(
                                color: Colors.grey,
                                offset: Offset(0.0, 1.0),
                                blurRadius: 6.0,
                              ),
                            ],
                          ),
                          child: Center(
                            child: loading
                                ? const SpinKitFadingCircle(
                                    color: Colors.white,
                                    size: 25.0,
                                  )
                                : const Text(
                                    "Create Property",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 15),
                    InkWell(
                        onTap: () {
                          // displayPropertyData();
                          Navigator.pop(context);
                        },
                        child: Text(
                          "Cancel",
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: blueColor),
                        )),
                  ],
                ),
                const Column(
                  children: [
                    //SetshowRentalOwnerTable(),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProcessorGroup(int index) {
    ProcessorGroup group = _processorGroups[index];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          SizedBox(
            width: 20.0,
            height: 20.0,
            child: Checkbox(
              value: group.isChecked,
              onChanged: (value) {
                setState(() {
                  group.isChecked = value ?? false;
                });
              },
              activeColor: blueColor,
            ),
          ),
          SizedBox(width: MediaQuery.of(context).size.width * .02),
          Expanded(
            child: Material(
              elevation: 3,
              borderRadius: BorderRadius.circular(5),
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(5),
                  color: Colors.white,
                  border: Border.all(color: const Color(0xFF8A95A8)),
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: TextField(
                        controller: group.controller,
                        cursorColor: blueColor,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.only(
                              top: 12.5, bottom: 12.5, left: 15),
                          hintText: "Enter processor",
                          hintStyle: TextStyle(
                            color: Color(0xFF8A95A8),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(width: MediaQuery.of(context).size.width * .02),
          InkWell(
            onTap: () {
              _removeGroup(index);
            },
            child: Container(
              padding: EdgeInsets.zero,
              child: FaIcon(
                FontAwesomeIcons.trashCan,
                size: 20,
                color: blueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  SetshowRentalOwnerTable() {
    const Row(
      children: [
        Text("Hello"),
      ],
    );
  }

  void _addNewGroup() {
    setState(() {
      _processorGroups.add(ProcessorGroup(
          isChecked: false, controller: TextEditingController()));
    });
  }

  void _removeGroup(int index) {
    setState(() {
      _processorGroups.removeAt(index);
    });
  }

  List<Widget> generateOwnerWidgets(
      List<Owner> filteredOwners, BuildContext context) {
    return List<Widget>.generate(filteredOwners.length, (index) {
      Owner owner = filteredOwners[index];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (owner.processorList.isNotEmpty) ...[
            const Row(
              children: [
                Text(
                  "Merchant Id",
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF8A95A8),
                      fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Column(
              children: [
                Container(
                  height: 150,
                  child: ListView.builder(
                    itemCount: _processorGroups.length,
                    itemBuilder: (context, index) {
                      ProcessorGroup group = _processorGroups[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 20.0,
                              height: 20.0,
                              child: Checkbox(
                                value: group.isChecked,
                                onChanged: (value) {
                                  setState(() {
                                    group.isChecked = value ?? false;
                                  });
                                },
                                activeColor: blueColor,
                              ),
                            ),
                            SizedBox(
                                width: MediaQuery.of(context).size.width * .02),
                            Expanded(
                              child: Material(
                                elevation: 3,
                                borderRadius: BorderRadius.circular(5),
                                child: Container(
                                  height: 50,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(5),
                                    color: Colors.white,
                                    border: Border.all(
                                        color: const Color(0xFF8A95A8)),
                                  ),
                                  child: Stack(
                                    children: [
                                      Positioned.fill(
                                        child: TextField(
                                          controller: group.controller,
                                          cursorColor: blueColor,
                                          decoration: const InputDecoration(
                                            border: InputBorder.none,
                                            contentPadding: EdgeInsets.only(
                                                top: 12.5,
                                                bottom: 12.5,
                                                left: 15),
                                            hintText: "Enter processor",
                                            hintStyle: TextStyle(
                                              color: Color(0xFF8A95A8),
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(
                                width: MediaQuery.of(context).size.width * .02),
                            InkWell(
                              onTap: () {
                                _removeGroup(index);
                              },
                              child: Container(
                                padding: EdgeInsets.zero,
                                child: FaIcon(
                                  FontAwesomeIcons.trashCan,
                                  size: 20,
                                  color: blueColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: _addNewGroup,
                  child: const Text("Add Processor Group"),
                ),
              ],
            ),
            SizedBox(height: MediaQuery.of(context).size.height * 0.01),
            const Row(
              children: [
                // Handle error display here if needed
              ],
            ),
          ],
        ],
      );
    });
  }

  Future<Map<String, dynamic>> addRentals({
    required String? adminId,
    required String? rentalowner_id,
    required String? processor_list,
    required String? rentalOwner_firstName,
    required String? rentalOwner_lastName,
    required String? rentalOwner_companyName,
    required String? rentalOwner_primaryEmail,
    required String? rentalOwner_phoneNumber,
    required String? rentalOwner_businessNumber,
  }) async {
    final Map<String, dynamic> data = {
      'admin_id': adminId,
      'rentalowner_id': rentalowner_id,
      'processor_list': processor_list,
      'rentalOwner_firstName': rentalOwner_firstName,
      'rentalOwner_lastName': rentalOwner_lastName,
      ' rentalOwner_companyName': rentalOwner_companyName,
      '  rentalOwner_primaryEmail': rentalOwner_primaryEmail,
      ' rentalOwner_phoneNumber': rentalOwner_phoneNumber,
      ' rentalOwner_businessNumber': rentalOwner_businessNumber,
    };

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString("adminId");
    String? token = prefs.getString('token');
    final http.Response response = await apiPost(
      Uri.parse('${Api_url}/api/rentals/rentals'),
      headers: <String, String>{
        "authorization": "CRM $token",
        "id": "CRM ${prefs.getString('staff_id') ?? id}",
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(data),
    );

    String? rental_id = prefs.getString("adminId");
    var responseData = json.decode(response.body);

    if (responseData["statusCode"] == 200) {
      Fluttertoast.showToast(msg: responseData["message"]);
      return json.decode(response.body);
    } else {
      Fluttertoast.showToast(msg: responseData["message"]);
      throw Exception('Failed to add property type');
    }
  }

  void handleAddrentalOwner() {
    if (rentalOwnerId != null) {
      Fluttertoast.showToast(
          msg: "Rental Owner Added Successfully!",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.TOP,
          timeInSecForIosWeb: 1,
          backgroundColor: Colors.red,
          textColor: Colors.white,
          fontSize: 16.0);
    }
    // setDisplay(false);
  }
}

class Owner {
  final String id;
  final String rentalOwnerId;
  final String adminId;
  final String rentalOwnername;
  final String companyName;
  final String primaryEmail;
  final String alternateEmail;
  final String phoneNumber;
  final String? homeNumber;
  final String? businessNumber;
  final String birthDate;
  final String startDate;
  final String endDate;
  final String taxpayerId;
  final String identityType;
  final String streetAddress;
  final String city;
  final String state;
  final String country;
  final String postalCode;
  final String createdAt;
  final String updatedAt;
  final bool isDelete;
  final List<Processor> processorList;

  Owner({
    required this.id,
    required this.rentalOwnerId,
    required this.adminId,
    required this.rentalOwnername,
    required this.companyName,
    required this.primaryEmail,
    required this.alternateEmail,
    required this.phoneNumber,
    required this.homeNumber,
    required this.businessNumber,
    required this.birthDate,
    required this.startDate,
    required this.endDate,
    required this.taxpayerId,
    required this.identityType,
    required this.streetAddress,
    required this.city,
    required this.state,
    required this.country,
    required this.postalCode,
    required this.createdAt,
    required this.updatedAt,
    required this.isDelete,
    required this.processorList,
  });

  factory Owner.fromJson(Map<String, dynamic> json) {
    var list = json['processor_list'] as List;
    List<Processor> processorList =
        list.map((i) => Processor.fromJson(i)).toList();

    return Owner(
      id: json['_id'],
      rentalOwnerId: json['rentalowner_id'] ?? "",
      adminId: json['admin_id'] ?? "",
      rentalOwnername: json['rentalOwner_name'] ?? "",

      companyName: json['rentalOwner_companyName'] ?? "",
      primaryEmail: json['rentalOwner_primaryEmail'] ?? "",
      alternateEmail: json['rentalOwner_alternateEmail'] ?? "",
      phoneNumber: json['rentalOwner_phoneNumber'] ?? "",
      homeNumber: json['rentalOwner_homeNumber'] ?? "", // Nullable field
      businessNumber:
          json['rentalOwner_businessNumber'] ?? "", // Nullable field
      birthDate: json['birth_date'] ?? "",
      startDate: json['start_date'] ?? "",
      endDate: json['end_date'] ?? "",
      taxpayerId: json['texpayer_id'] ?? "",
      identityType: json['text_identityType'] ?? "",
      streetAddress: json['street_address'] ?? "",
      city: json['city'] ?? "",
      state: json['state'] ?? "",
      country: json['country'] ?? "",
      postalCode: json['postal_code'] ?? "",
      createdAt: json['createdAt'] ?? "",
      updatedAt: json['updatedAt'] ?? "",
      isDelete: json['is_delete'],
      processorList: processorList,
    );
  }
}

// class Processor {
//   final String processorId;
//   final String id;
//
//   Processor({required this.processorId, required this.id});
//
//   factory Processor.fromJson(Map<String, dynamic> json) {
//     return Processor(
//       processorId: json['processor_id'],
//       id: json['_id'],
//     );
//   }
// }
class Processor {
  final String processorId;
  final String id;

  Processor({required this.processorId, required this.id});

  factory Processor.fromJson(Map<String, dynamic> json) {
    return Processor(
      processorId: json['processor_id'],
      id: json['_id'],
    );
  }
}

class ProcessorGroup {
  bool isChecked;
  TextEditingController controller;

  ProcessorGroup({required this.isChecked, required this.controller});
}

class OwnersDetails {
  RentalOwner? Ownersdetails;
  OwnersDetails({
    required this.Ownersdetails,
  });
}

class HistoricalInsuredValue {
  String? year;
  String? insuredValue;
  TextEditingController yearController;
  TextEditingController valueController;
  bool yearError;
  bool valueError;

  HistoricalInsuredValue({
    this.year,
    this.insuredValue,
    required this.yearController,
    required this.valueController,
    this.yearError = false,
    this.valueError = false,
  });
}

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
import 'package:shared_preferences/shared_preferences.dart';
import 'package:three_zero_two_property/model/staffmember.dart';
import 'package:three_zero_two_property/repository/Staffmember.dart';
import 'package:three_zero_two_property/repository/rental_properties.dart';
import 'package:three_zero_two_property/screens/Rental/Properties/add_rentalowners.dart';
import 'package:three_zero_two_property/widgets/appbar.dart';
import 'package:three_zero_two_property/widgets/amenities_picker.dart';
import 'package:three_zero_two_property/widgets/us_state_dropdown.dart';
import '../../../Model/propertytype.dart';
import '../../../constant/constant.dart';
import '../../../model/add_property.dart';
import '../../../model/rental_properties.dart';
import '../../../provider/add_property.dart';
import '../../../provider/dateProvider.dart';
import '../../../repository/Property_type.dart';
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

  TextEditingController searchController = TextEditingController();

  // Insured Value Information
  TextEditingController datePlacedInService = TextEditingController();
  List<HistoricalInsuredValue> historicalInsuredValues = [];
  bool datePlacedInServiceError = false;
  String datePlacedInServiceMessage = "";

  late Future<List<Staffmembers>> futureStaffMembers;
  String? selectedStaffmember;

  Future<List<propertytype>>? futureProperties;
  String? selectedProperty;
  Future<List<RentalOwners>>? futureRentalOwner;
  Map<String, List<propertytype>> groupPropertiesByType(
      List<propertytype> properties) {
    Map<String, List<propertytype>> groupedProperties = {};

    // First group by property type
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
  reload_Screen() {
    setState(() {
      futureProperties = PropertyTypeRepository().fetchPropertyTypes();
      futureStaffMembers = StaffMemberRepository().fetchStaffmembers();
    });
  }

  Future<void> fetchOwners() async {
    setState(() {
      isLoading = true;
    });
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString("adminId");
    String? token = prefs.getString('token');
    final response = await apiGet(
      Uri.parse('${Api_url}/api/rentals/rental-owners/$id'),
      headers: {
        "id": "CRM $id",
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

  @override
  void dispose() {
    searchController.dispose();
    datePlacedInService.dispose();
    for (var item in historicalInsuredValues) {
      item.yearController.dispose();
      item.valueController.dispose();
    }
    for (final n in propertyGroupAmenities) {
      n.dispose();
    }
    propertyAmenities.dispose();
    super.dispose();
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
        // print('Image selected: ${pickedFile.path}');
        // print('Before: ${propertyGroupImages.length}');
        propertyGroupImages[index] = File(pickedFile.path);
        // print('After : ${propertyGroupImages.length}');
      } else {
        // print('No image selected.');
      }
    });
  }

  List<List<Widget>> propertyGroups = [];
  //  List<List<TextEditingController>> propertyGroupControllers = [];
  List<File?> propertyGroupImages = [];
  List<String?> propertyGroupImagenames = [];
  // Per-unit amenities (residential only, like web). Index-aligned with
  // propertyGroupImagenames. Notifiers because the unit widgets are built once
  // and stored, so a plain setState would not re-render them.
  List<ValueNotifier<List<String>>> propertyGroupAmenities = [];
  // Web shows Property Amenities only when "Advertise on Zillow" is ticked,
  // and a new property starts with it off. Mobile has no Zillow switch, so
  // on Add the card stays hidden, matching web's default.
  bool _zillowAdvertise = false;
  // Building/community level amenities (web property_amenities).
  final ValueNotifier<List<String>> propertyAmenities =
      ValueNotifier(<String>[]);
  File? _image;
  Future<String?> uploadImage(File imageFile) async {
    // print(imageFile.path!);
    // API URL
    //   final String uploadUrl = 'http://192.168.1.17:4000/api/images/upload';
    final String uploadUrl = '${image_upload_url}/api/images/upload';

    var request = http.MultipartRequest('POST', Uri.parse(uploadUrl));
    if (imageFile != null) {
      request.files
          .add(await http.MultipartFile.fromPath('files', imageFile!.path));
    }

    var response = await apiSend(request);
    // Parse the response
    var responseData = await http.Response.fromStream(response);
    // print(responseData.body);
    var responseBody = json.decode(responseData.body);

    // Extract the filename from the response
    if (responseBody['status'] == 'ok') {
      List file = responseBody['files'];
      // print(file.first["filename"]);
      // print(file.first.runtimeType);
      return file.first["filename"];
    } else {
      throw Exception('Failed to upload file: ${responseBody['message']}');
    }
  }

  // Widget customTextField(String label, TextEditingController Controller) {
  //   return Padding(
  //     padding: const EdgeInsets.symmetric(vertical: 5),
  //     child: TextFormField(
  //       controller: Controller,
  //       cursorColor: Colors.black,
  //       decoration: InputDecoration(
  //         hintText: label,
  //         // labelText: label,
  //         // labelStyle: TextStyle(color: Colors.grey[700]),
  //         filled: true,
  //         fillColor: Colors.white,
  //         border: OutlineInputBorder(
  //           borderRadius: BorderRadius.circular(8),
  //           borderSide: BorderSide.none,
  //         ),
  //         enabledBorder: OutlineInputBorder(
  //           borderRadius: BorderRadius.circular(8),
  //           borderSide: BorderSide(color: Color(0xFF8A95A8)),
  //         ),
  //         focusedBorder: OutlineInputBorder(
  //           borderRadius: BorderRadius.circular(8),
  //           borderSide: BorderSide(color: Color(0xFF8A95A8), width: 2),
  //         ),
  //         contentPadding:
  //             EdgeInsets.symmetric(vertical: 10.0, horizontal: 10.0),
  //       ),
  //     ),
  //   );
  // }

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

  // Exactly web's Half Baths options (Rentals.jsx: ["0","0.5",..,"4"]).
  // Stored as-is; the server keeps half_baths as a String.
  static const List<String> halfBathArray = [
    "0",
    "0.5",
    "1",
    "1.5",
    "2",
    "2.5",
    "3",
    "3.5",
    "4",
  ];
  // ---- Redesign helpers (web-aligned Add Property form) ------------------
  // Same house style as the Add Tenant redesign (add_tenants.dart
  // _sectionCard/_fieldLabel/_bottomActionBar). Presentation only: these own
  // no state, and every callback they take is passed in from the call site.

  static const Color _pfHintClr = Color(0xFF94A1B4);
  static const TextStyle _pfInputText = TextStyle(fontSize: 14, color: navyClr);
  static const TextStyle _pfTableHead =
      TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: navyClr);
  static const TextStyle _pfTableCell = TextStyle(fontSize: 13, color: navyClr);
  static const Widget _pfGap = SizedBox(height: 16);

  Widget _pfSectionCard({
    String? title,
    String? subtitle,
    Widget? trailing,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderClr),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            // Wrap rather than Row: on a narrow phone the trailing action
            // drops under the title instead of squeezing it.
            SizedBox(
              width: double.infinity,
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 10,
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: navyClr,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: navyClr,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (trailing != null) trailing,
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          ...children,
        ],
      ),
    );
  }

  Widget _pfFieldLabel(String text, {bool required = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      // scaleDown keeps a long label on one line inside a half-width column,
      // so the two boxes of a row stay level. Text.rich (not RichText) so the
      // app-wide Poppins still applies.
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text.rich(
          TextSpan(
            text: text,
            children: required
                ? const [
                    TextSpan(
                      text: ' *',
                      style: TextStyle(
                        color: redClr,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ]
                : const [],
          ),
          maxLines: 1,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: navyClr,
          ),
        ),
      ),
    );
  }

  InputDecoration _pfInputDecoration({
    String? hint,
    bool error = false,
    Widget? suffixIcon,
    EdgeInsetsGeometry contentPadding =
        const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  }) {
    OutlineInputBorder side(Color color, double width) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color, width: width),
        );
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: _pfHintClr, fontSize: 14),
      filled: true,
      fillColor: Colors.white,
      isDense: true,
      contentPadding: contentPadding,
      suffixIcon: suffixIcon,
      border: side(outlineClr, 1),
      enabledBorder: side(error ? Colors.red : outlineClr, 1),
      focusedBorder: side(error ? Colors.red : navyClr, 1.5),
      errorBorder: side(Colors.red, 1),
      focusedErrorBorder: side(Colors.red, 1.5),
    );
  }

  Widget _pfErrorText(String message) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        message,
        style: const TextStyle(color: Colors.red, fontSize: 13),
      ),
    );
  }

  Widget _pfHelperText(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        text,
        style: const TextStyle(fontSize: 13, color: mutedClr),
      ),
    );
  }

  Widget _pfTwoCol(Widget left, Widget right) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: left),
        const SizedBox(width: 12),
        Expanded(child: right),
      ],
    );
  }

  // Two checkbox tiles side by side; stacked only when the unit card is too
  // narrow for "Furnished" to fit on one line.
  Widget _pfTileRow(Widget left, Widget right) {
    // Side by side only when each tile has room for "Furnished" on one line
    // (row >= 300); on narrower phones stack them so no word breaks mid-way.
    return LayoutBuilder(
      builder: (context, box) => box.maxWidth >= 300
          ? IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: left),
                  const SizedBox(width: 12),
                  Expanded(child: right),
                ],
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [left, const SizedBox(height: 12), right],
            ),
    );
  }

  Widget _pfAddLink(String text, {required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: navyClr,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: navyClr,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pfIconAction({
    required IconData icon,
    required Color color,
    required Color background,
    required VoidCallback onTap,
  }) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, color: color, size: 18),
        ),
      ),
    );
  }

  Widget _pfUnitCard({required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderClr),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
  /// Per-unit date field (Availability Date). Read-only like Date Placed in
  /// Service: tapping opens the picker and the controller holds the value in
  /// the user's display format; [_toApiDate] converts it at submit.
  Widget customUnitDateField(String label, TextEditingController controller,
      {String placeholder = 'MM/DD/YYYY'}) {
    return FormField<String>(
      validator: (_) => controller.text.trim().isEmpty ? 'required' : null,
      builder: (FormFieldState<String> state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _pfFieldLabel(label, required: true),
            TextFormField(
              controller: controller,
              readOnly: true,
              style: _pfInputText,
              cursorColor: navyClr,
              onTap: () async {
                final DateTime? picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime(DateTime.now().year + 10),
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
                  final dateProvider =
                      Provider.of<DateProvider>(context, listen: false);
                  setState(() {
                    controller.text = dateProvider.formatCurrentDate(
                        DateFormat('yyyy-MM-dd').format(picked));
                  });
                  state.didChange(controller.text);
                }
              },
              decoration: _pfInputDecoration(
                hint: placeholder,
                error: state.hasError,
                suffixIcon: const Icon(
                  Icons.calendar_today_outlined,
                  color: navyClr,
                  size: 18,
                ),
              ),
            ),
            if (state.hasError)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  state.errorText!,
                  style: const TextStyle(color: Colors.red, fontSize: 14),
                ),
              ),
          ],
        );
      },
    );
  }

  /// Displayed date -> yyyy-MM-dd for the payload. Same parse order the form
  /// already uses for placed_in_service; returns null if nothing parses, so a
  /// blank field is omitted rather than sent as garbage.
  String? _toApiDate(String text) {
    if (text.trim().isEmpty) return null;
    for (final format in const [
      'yyyy-MM-dd',
      'yyyy-M-d',
      'yyyy-MMM-dd',
      'dd-MM-yyyy',
      'd-M-yyyy',
      'M/d/yyyy',
      'MM/dd/yyyy',
    ]) {
      try {
        return DateFormat('yyyy-MM-dd').format(DateFormat(format).parse(text));
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  // Web's exact option VALUES and labels (Rentals.jsx getOptionLabel blocks).
  // The value is what the server stores; the label is only what we display.
  static const Map<String, String> parkingTypeOptions = {
    '': 'Select type',
    'surfaceLot': 'Surface Lot',
    'garageLot': 'Garage Lot',
    'coveredLot': 'Covered Lot',
    'street': 'Street',
    'other': 'Other',
    'none': 'None',
  };
  static const Map<String, String> leaseTermOptions = {
    'ContactForDetails': 'Contact for Details',
    'Monthly': 'Monthly',
    'SixMonths': '6 Months',
    'OneYear': '1 Year',
  };
  static const Map<String, String> depositTypeOptions = {
    'flatFee': 'Flat Fee',
    'range': 'Range',
    'percentage': '% of Rent',
    'multiplier': 'Multiplier of Rent',
  };
  static const Map<String, String> depositRefundableOptions = {
    'refundable': 'Refundable',
    'nonRefundable': 'Non-Refundable',
    'partiallyRefundable': 'Partially Refundable',
  };

  /// Dropdown over a value->label map: the controller always holds the server
  /// VALUE while the user sees the label, so nothing has to be translated at
  /// save time. Optional, so unlike customDropdownField it does not validate.
  /// Checkbox backed by a TextEditingController holding 'true'/'false', so it
  /// slots into the same positional controller list as every other unit field.
  Widget customCheckboxField(String label, TextEditingController controller) {
    // Unit widgets are pre-built into a stored list, so setState never repaints
    // this box. Listen to the controller itself so the tick follows the value
    // and a second tap can untick it.
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, current, _) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: outlineClr),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: current.text == 'true',
                activeColor: navyClr,
                checkColor: Colors.white,
                side: const BorderSide(color: checkOffClr, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                onChanged: (checked) =>
                    controller.text = (checked ?? false).toString(),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: navyClr,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget customValueDropdown(
    String label,
    Map<String, String> options,
    TextEditingController controller, {
    String placeholder = 'Select',
    bool showRequired = false,
  }) {
    final current = options.containsKey(controller.text) ? controller.text : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _pfFieldLabel(label, required: showRequired),
        DropdownButtonFormField<String>(
          value: current,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, color: navyClr),
          style: _pfInputText,
          dropdownColor: Colors.white,
          decoration: _pfInputDecoration(
              contentPadding: const EdgeInsets.fromLTRB(16, 12, 12, 12)),
          hint: Text(
            placeholder,
            style: const TextStyle(color: _pfHintClr, fontSize: 14),
          ),
          items: options.entries
              .map((e) => DropdownMenuItem<String>(
                    value: e.key,
                    child: Text(e.value),
                  ))
              .toList(),
          onChanged: (v) => setState(() => controller.text = v ?? ''),
        ),
      ],
    );
  }

  /// Free-text unit field that is optional (customTextField always requires).
  Widget customOptionalField(String label, TextEditingController controller,
      {int maxLines = 1, bool money = false, String? placeholder}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _pfFieldLabel(label),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: money
              ? const TextInputType.numberWithOptions(decimal: true)
              : null,
          inputFormatters: money
              ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))]
              : null,
          style: _pfInputText,
          cursorColor: navyClr,
          decoration: _pfInputDecoration(hint: placeholder),
        ),
      ],
    );
  }

  Widget customDropdownField(
    String label,
    List<String> items,
    TextEditingController controller, {
    String placeholder = 'Select',
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _pfFieldLabel(label, required: true),
        DropdownButtonFormField<String>(
          value: controller.text.isNotEmpty ? controller.text : null,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, color: navyClr),
          style: _pfInputText,
          dropdownColor: Colors.white,
          decoration: _pfInputDecoration(
              contentPadding: const EdgeInsets.fromLTRB(16, 12, 12, 12)),
          hint: Text(
            placeholder,
            style: const TextStyle(color: _pfHintClr, fontSize: 14),
          ),
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
      ],
    );
  }

  Widget customTextField(String label, TextEditingController Controller,
      {bool money = false, String? placeholder}) {
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
            _pfFieldLabel(label, required: true),
            TextFormField(
              controller: Controller,
              // Rent/deposit are Numbers on the server; web strips everything but
              // digits and '.', so '1,850' or '$1850' must not be typeable.
              keyboardType: money
                  ? const TextInputType.numberWithOptions(decimal: true)
                  : null,
              inputFormatters: money
                  ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))]
                  : null,
              style: _pfInputText,
              cursorColor: navyClr,
              decoration: _pfInputDecoration(
                // labelText: label,
                // labelStyle: TextStyle(color: Colors.grey[700]),
                hint: placeholder,
                error: state.hasError,
              ),
            ),
            if (state.hasError)
              Padding(
                padding: const EdgeInsets.only(top: 6),
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

  // Unit Amenities (residential only, like web). Builder defers the list
  // lookup to build time: the notifier is appended after the fields are built.
  Widget unitAmenitiesField(int index) {
    return Builder(
      builder: (_) => ValueListenableBuilder<List<String>>(
        valueListenable: propertyGroupAmenities[index],
        builder: (_, value, __) => AmenitiesField(
          label: 'Unit Amenities',
          value: value,
          isStaff: false,
          onChanged: (v) => propertyGroupAmenities[index].value = v,
        ),
      ),
    );
  }

  Widget photo(int index) {
    return StatefulBuilder(
      builder: (BuildContext context, StateSetter setState) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _pfFieldLabel('Photo'),
            if (propertyGroupImages[index] == null)
              GestureDetector(
                onTap: () {
                  getImage(index).then((_) {
                    setState(
                        () {}); // Rebuild the widget after selecting the image
                  });
                },
                child: CustomPaint(
                  foregroundPainter: const _PfDashedBorderPainter(),
                  child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Column(
                    children: [
                      Icon(Icons.file_upload_outlined,
                          color: navyClr, size: 26),
                      SizedBox(height: 8),
                      Text(
                        'Add Unit Photo',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: navyClr,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        '.png, .jpg, .jpeg',
                        style: TextStyle(fontSize: 12, color: mutedClr),
                      ),
                    ],
                  ),
                ),
                ),
              ),
            if (propertyGroupImages[index] != null)
              Stack(
                children: [
                  // Text(
                  //   '+ Add',
                  //   style: TextStyle(color: Colors.green,fontWeight: FontWeight.bold,fontSize: 18),
                  // ),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(
                      propertyGroupImages[index]!,
                      height: 100,
                      width: 100,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          propertyGroupImages[index] =
                              null; // Clear the selected image
                        });
                      },
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: borderClr),
                        ),
                        child: const Icon(
                          Icons.close,
                          color: mutedClr,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        );
      },
    );
  }

  void addPropertyGroup() {
    // This unit's slot in the per-unit lists = where its controllers land
    // once Create strips the blank head slot. propertyGroups.length collided
    // after a unit was removed (two cards shared one photo/amenity slot).
    // Read it from the images list: Create strips only the controllers, so a
    // unit added after a failed Create would otherwise take the previous
    // unit's photo/amenity slot.
    final int slot = propertyGroupImages.length - 1;
    // print("hello");
    List<Widget> fields = [];
    List<TextEditingController> controllers = [];

    // print(selectedpropertytype);

    if (selectedpropertytype == 'Commercial' && selectedIsMultiUnit == true) {
      var unitController = TextEditingController();
      var unitAddressController = TextEditingController();
      var sqftController = TextEditingController();
      var unitDescriptionController = TextEditingController();

      fields = [
        customTextField('Unit Number', unitController,
            placeholder: 'Enter unit number'),
        _pfGap,
        customTextField('Unit Address', unitAddressController,
            placeholder: 'Enter unit address'),
        _pfGap,
        customTextField('SQFT', sqftController, placeholder: 'Enter Sqft'),
        _pfGap,
        customOptionalField('Unit Description', unitDescriptionController,
            maxLines: 3, placeholder: 'Enter unit-level description...'),
        _pfHelperText(
            'Describe unit features, layout, appliances, and unique qualities'),
        _pfGap,
        photo(slot), // Pass the index
      ];

      // Unit Description is appended LAST (index 3) so indices 0-2 never shift.
      controllers = [
        unitController,
        unitAddressController,
        sqftController,
        unitDescriptionController,
      ];
    } else if (selectedpropertytype == 'Residential' &&
        selectedIsMultiUnit == true) {
      var unitController = TextEditingController();
      var unitAddressController = TextEditingController();
      var sqftController = TextEditingController();
      var bathController = TextEditingController();
      var bedController = TextEditingController();
      var rentPriceController = TextEditingController();
      var halfBathsController = TextEditingController();
      var availabilityDateController = TextEditingController();
      var parkingTypeController = TextEditingController();
      var leaseTermController = TextEditingController(text: 'ContactForDetails');
      var securityDepositController = TextEditingController();
      var depositTypeController = TextEditingController(text: 'flatFee');
      var depositMaxController = TextEditingController();
      var depositRefundableController =
          TextEditingController(text: 'refundable');
      var petPolicyController = TextEditingController();
      var furnishedController = TextEditingController(text: 'false');
      var smokingController = TextEditingController(text: 'false');
      var unitDescriptionController = TextEditingController();

      fields = [
        customTextField('Unit', unitController, placeholder: 'Enter unit'),
        _pfGap,
        customTextField('Unit Address', unitAddressController,
            placeholder: 'Enter unit address'),
        _pfGap,
        _pfTwoCol(
          customTextField('SQFT', sqftController, placeholder: 'Enter Sqft'),
          customTextField('Rent Price (\$)', rentPriceController,
              money: true, placeholder: 'Enter rent price'),
        ),
        _pfGap,
        _pfTwoCol(
          customDropdownField('Bed', roomsArray, bedController),
          customDropdownField('Baths', bathArray, bathController),
        ),
        _pfGap,
        _pfTwoCol(
          customDropdownField('Half Baths', halfBathArray, halfBathsController),
          customValueDropdown(
              'Parking Type', parkingTypeOptions, parkingTypeController,
              placeholder: 'Select type'),
        ),
        _pfGap,
        customUnitDateField('Availability Date', availabilityDateController),
        _pfGap,
        customValueDropdown(
            'Lease Term', leaseTermOptions, leaseTermController,
            showRequired: true),
        _pfGap,
        _pfTwoCol(
          customOptionalField('Security Deposit (\$)', securityDepositController,
              money: true, placeholder: '0'),
          customValueDropdown(
              'Deposit Type', depositTypeOptions, depositTypeController),
        ),
        // Web only shows Deposit Max when the type is a range.
        // The unit's widgets are built once and stored, so a plain `if` here
        // would be frozen at build time. Listen to the type controller so the
        // field appears/disappears live, like web.
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: depositTypeController,
          builder: (_, v, __) => v.text == 'range'
              ? Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: customOptionalField(
                      'Deposit Max (\$)', depositMaxController,
                      money: true, placeholder: '0'),
                )
              : const SizedBox.shrink(),
        ),
        _pfGap,
        customValueDropdown('Deposit Refundable?', depositRefundableOptions,
            depositRefundableController),
        _pfGap,
        customOptionalField('Pet Policy', petPolicyController,
            maxLines: 3,
            placeholder:
                'Additional pet policy notes (e.g., Max 2 pets, \$500 deposit)'),
        _pfGap,
        unitAmenitiesField(slot),
        _pfGap,
        _pfTileRow(
          customCheckboxField('Furnished', furnishedController),
          customCheckboxField('Smoking Allowed', smokingController),
        ),
        _pfGap,
        customOptionalField('Unit Description', unitDescriptionController,
            maxLines: 3, placeholder: 'Enter unit-level description...'),
        _pfHelperText(
            'Describe unit features, layout, appliances, and unique qualities'),
        _pfGap,
        photo(slot), // Pass the index
      ];

      controllers = [
        unitController,
        unitAddressController,
        sqftController,
        bathController,
        bedController,
        rentPriceController,
        halfBathsController,
        availabilityDateController,
        parkingTypeController,
        leaseTermController,
        securityDepositController,
        depositTypeController,
        depositMaxController,
        depositRefundableController,
        petPolicyController,
        furnishedController,
        smokingController,
        unitDescriptionController,
      ];
    } else if (selectedpropertytype == 'Residential') {
      var sqftController = TextEditingController();
      var bathController = TextEditingController();
      var bedController = TextEditingController();
      var rentPriceController = TextEditingController();
      var halfBathsController = TextEditingController();
      var availabilityDateController = TextEditingController();
      var parkingTypeController = TextEditingController();
      var leaseTermController = TextEditingController(text: 'ContactForDetails');
      var securityDepositController = TextEditingController();
      var depositTypeController = TextEditingController(text: 'flatFee');
      var depositMaxController = TextEditingController();
      var depositRefundableController =
          TextEditingController(text: 'refundable');
      var petPolicyController = TextEditingController();
      var furnishedController = TextEditingController(text: 'false');
      var smokingController = TextEditingController(text: 'false');
      var unitDescriptionController = TextEditingController();

      fields = [
        _pfTwoCol(
          customTextField('SQFT', sqftController, placeholder: 'Enter Sqft'),
          customTextField('Rent Price (\$)', rentPriceController,
              money: true, placeholder: 'Enter rent price'),
        ),
        _pfGap,
        _pfTwoCol(
          customDropdownField('Bed', roomsArray, bedController),
          customDropdownField('Baths', bathArray, bathController),
        ),
        _pfGap,
        _pfTwoCol(
          customDropdownField('Half Baths', halfBathArray, halfBathsController),
          customValueDropdown(
              'Parking Type', parkingTypeOptions, parkingTypeController,
              placeholder: 'Select type'),
        ),
        _pfGap,
        customUnitDateField('Availability Date', availabilityDateController),
        _pfGap,
        customValueDropdown(
            'Lease Term', leaseTermOptions, leaseTermController,
            showRequired: true),
        _pfGap,
        _pfTwoCol(
          customOptionalField('Security Deposit (\$)', securityDepositController,
              money: true, placeholder: '0'),
          customValueDropdown(
              'Deposit Type', depositTypeOptions, depositTypeController),
        ),
        // Web only shows Deposit Max when the type is a range.
        // The unit's widgets are built once and stored, so a plain `if` here
        // would be frozen at build time. Listen to the type controller so the
        // field appears/disappears live, like web.
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: depositTypeController,
          builder: (_, v, __) => v.text == 'range'
              ? Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: customOptionalField(
                      'Deposit Max (\$)', depositMaxController,
                      money: true, placeholder: '0'),
                )
              : const SizedBox.shrink(),
        ),
        _pfGap,
        customValueDropdown('Deposit Refundable?', depositRefundableOptions,
            depositRefundableController),
        _pfGap,
        customOptionalField('Pet Policy', petPolicyController,
            maxLines: 3,
            placeholder:
                'Additional pet policy notes (e.g., Max 2 pets, \$500 deposit)'),
        _pfGap,
        unitAmenitiesField(slot),
        _pfGap,
        _pfTileRow(
          customCheckboxField('Furnished', furnishedController),
          customCheckboxField('Smoking Allowed', smokingController),
        ),
        _pfGap,
        customOptionalField('Unit Description', unitDescriptionController,
            maxLines: 3, placeholder: 'Enter unit-level description...'),
        _pfHelperText(
            'Describe unit features, layout, appliances, and unique qualities'),
        _pfGap,
        photo(slot), // Pass the index
      ];

      controllers = [
        sqftController,
        bathController,
        bedController,
        rentPriceController,
        halfBathsController,
        availabilityDateController,
        parkingTypeController,
        leaseTermController,
        securityDepositController,
        depositTypeController,
        depositMaxController,
        depositRefundableController,
        petPolicyController,
        furnishedController,
        smokingController,
        unitDescriptionController,
      ];
    } else if (selectedpropertytype == 'Commercial') {
      var sqftController = TextEditingController();
      var unitDescriptionController = TextEditingController();

      fields = [
        customTextField('SQFT', sqftController, placeholder: 'Enter Sqft'),
        _pfGap,
        customOptionalField('Unit Description', unitDescriptionController,
            maxLines: 3, placeholder: 'Enter unit-level description...'),
        _pfHelperText(
            'Describe unit features, layout, appliances, and unique qualities'),
        _pfGap,
        photo(slot), // Pass the index
      ];

      // Unit Description is appended LAST (index 1) so index 0 never shifts.
      controllers = [sqftController, unitDescriptionController];
    }

    setState(() {
      propertyGroups.add(fields);
      propertyGroupControllers.add(controllers);
      propertyGroupImages.add(null);
      propertyGroupImagenames.add(null);
      propertyGroupAmenities.add(ValueNotifier<List<String>>(<String>[]));
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

    // print(propertyGroupControllers.length);

    for (int i = 0; i < propertyGroupControllers.length; i++) {
      List<TextEditingController> controllers = propertyGroupControllers[i];
      for (int j = 0; j < controllers.length; j++) {
        // print(controllers[j].text);
      }
    }
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
    // add last 50 years to the list
    List<String> years = [];
    for (int i = currentYear; i >= currentYear - 50; i--) {
      years.add(i.toString());
    }
    return years.toList();
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
      appBar: widget_302.App_Bar(context: context),
      backgroundColor: pageBg,
      drawer: CustomDrawer(
        currentpage: "Properties",
        dropdown: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header bar (house style: navy, radius 14).
                ClipRRect(
                  borderRadius: BorderRadius.circular(14.0),
                  child: Container(
                    height: 50.0,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    alignment: Alignment.centerLeft,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14.0),
                      color: navyClr,
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
                const SizedBox(height: 20),
                //dropdown
                _pfSectionCard(
                  title: 'Property Information',
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
                          _pfFieldLabel('Property Type', required: true),
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        SizedBox(
                                          // height: MediaQuery.of(context)
                                          //         .size
                                          //         .height *
                                          //     .05,
                                          width: double.infinity,
                                          child: DropdownButtonHideUnderline(
                                              child: DropdownButton2<String>(
                                                value: selectedProperty,
                                                hint: const Text(
                                                  'Add Property Type',
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    color: _pfHintClr,
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
                                                      // print(snapshot.data!
                                                      //     .where((element) =>
                                                      //         element
                                                      //             .propertysubType ==
                                                      //         newValue)
                                                      //     .first
                                                      //     .isMultiunit);
                                                      // selectedIsMultiUnit = snapshot.data!.where((element) => element.isMultiunit == newValue ).first;
                                                      selectedpropertytypedata =
                                                          snapshot.data!
                                                              .where((element) =>
                                                                  element
                                                                      .propertysubType ==
                                                                  newValue)
                                                              .first;
                                                      // print(selectedProperty);
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
                                                    // A type change used to clear only the unit cards. The per-unit lists
                                                    // kept the old type's unit, so the save read the wrong unit (amenities
                                                    // and photo lost) or crashed (Commercial multi -> Residential single).
                                                    // Put them back to the one blank head slot initState leaves; Create
                                                    // strips that slot, so the new unit saves from the index it writes to.
                                                    propertyGroupControllers
                                                      ..clear()
                                                      ..add(<TextEditingController>[]);
                                                    propertyGroupImages
                                                      ..clear()
                                                      ..add(null);
                                                    propertyGroupImagenames
                                                      ..clear()
                                                      ..add(null);
                                                    propertyGroupAmenities
                                                      ..clear()
                                                      ..add(ValueNotifier<List<String>>(<String>[]));
                                                    addPropertyGroup();
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
                                                // Closed-button text only, one entry per item above (group header,
                                                // sub types, then the add row), so the chosen sub type sits flush
                                                // left like the other fields instead of carrying the menu indent.
                                                selectedItemBuilder: (context) => [
                                                  ...groupedProperties.entries.expand((entry) => [
                                                        const SizedBox.shrink(),
                                                        ...entry.value.map(
                                                          (item) => Align(
                                                            alignment: Alignment.centerLeft,
                                                            child: Text(
                                                              item.propertysubType ?? '',
                                                              style: _pfInputText,
                                                              overflow: TextOverflow.ellipsis,
                                                            ),
                                                          ),
                                                        ),
                                                      ]),
                                                  const SizedBox.shrink(),
                                                ],
                                                isExpanded: true,
                                                buttonStyleData:
                                                    ButtonStyleData(
                                                  height: 48,
                                                  padding: const EdgeInsets
                                                      .only(right: 12),
                                                  decoration: BoxDecoration(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12),
                                                    color: Colors.white,
                                                    border: Border.all(
                                                        color: showError
                                                            ? Colors.red
                                                            : outlineClr),
                                                  ),
                                                ),
                                                iconStyleData:
                                                    const IconStyleData(
                                                  icon: Icon(
                                                      Icons
                                                          .keyboard_arrow_down,
                                                      color: navyClr),
                                                  iconSize: 22,
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
                                        if (showError)
                                          const Padding(
                                            padding: EdgeInsets.only(top: 6),
                                            child: Text(
                                              'Please select a property type.',
                                              style: TextStyle(
                                                  color: Colors.red,
                                                  fontSize: 13),
                                            ),
                                          ),
                                      ],
                                    );
                                  }
                                },
                              ),
                          propertyTypeError
                              ? Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    propertyTypeErrorMessage,
                                    style: const TextStyle(
                                        color: Colors.red, fontSize: 13),
                                  ),
                                )
                              : Container(),
                          const SizedBox(height: 16),
                          _pfFieldLabel('Address', required: true),
                          // color: Color.fromRGBO(196, 196, 196, .3),
                          TextField(
                            style: _pfInputText,
                            keyboardType: TextInputType
                                .text, // Adjust as needed
                            onChanged: (value) {
                              setState(() {
                                addresserror = false;
                              });
                            },
                            controller: address,
                            cursorColor: navyClr,
                            decoration: _pfInputDecoration(
                              hint: "Enter street address",
                              error: addresserror,
                            ),
                          ),
                          addresserror
                              ? _pfErrorText(addressmessage)
                              : Container(),
                          const SizedBox(height: 16),
                          _pfTwoCol(
                            // First Column
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _pfFieldLabel('City', required: true),
                                TextField(
                                  keyboardType: TextInputType.text,
                                  controller: city,
                                  style: _pfInputText,
                                  onChanged: (value) {
                                    setState(() {
                                      cityerror = false;
                                    });
                                  },
                                  cursorColor: navyClr,
                                  decoration: _pfInputDecoration(
                                    hint: "Enter city",
                                    error: cityerror,
                                  ),
                                ),
                                cityerror
                                    ? _pfErrorText(citymessage)
                                    : Container(),
                              ],
                            ),
                            // Second Column
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _pfFieldLabel('State', required: true),
                                UsStateDropdown(
                                  controller: state,
                                  hintText: 'Select state',
                                  borderColor: stateerror ? redClr : null,
                                  onChanged: (value) {
                                    setState(() {
                                      stateerror = false;
                                    });
                                  },
                                ),
                                stateerror
                                    ? _pfErrorText(statemessage)
                                    : Container(),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          _pfTwoCol(
                            // First Column
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _pfFieldLabel('Zip Code', required: true),
                                TextField(
                                  focusNode: _nodeText1,
                                  controller: postalcode,
                                  style: _pfInputText,
                                  onChanged: (value) {
                                    setState(() {
                                      postalcodeerror = false;
                                    });
                                  },
                                  // keyboardType: TextInputType
                                  //     .numberWithOptions(
                                  //         signed: true,
                                  //         decimal: true),
                                  keyboardType:
                                      TextInputType.number,
                                  //  inputFormatters: [
                                  //   FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                                  //   TextInputFormatter.withFunction((oldValue, newValue) {
                                  //     return TextEditingValue(
                                  //       text: newValue.text.toUpperCase(),
                                  //       selection: newValue.selection,
                                  //     );
                                  //   }),
                                  // ],
                                  inputFormatters: [
                                    FilteringTextInputFormatter
                                        .digitsOnly,
                                  ],
                                  cursorColor: navyClr,
                                  decoration: _pfInputDecoration(
                                    hint: "Enter zip code",
                                    error: postalcodeerror,
                                  ),
                                ),
                                postalcodeerror
                                    ? _pfErrorText(postalcodemessage)
                                    : Container(),
                              ],
                            ),
                            // Second Column
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _pfFieldLabel('Country', required: true),
                                TextField(
                                  keyboardType: TextInputType.text,
                                  controller: country,
                                  style: _pfInputText,
                                  onChanged: (value) {
                                    setState(() {
                                      countryerror = false;
                                    });
                                  },
                                  cursorColor: navyClr,
                                  decoration: _pfInputDecoration(
                                    hint: "Enter country",
                                    error: countryerror,
                                  ),
                                ),
                                countryerror
                                    ? _pfErrorText(countrymessage)
                                    : Container(),
                              ],
                            ),
                          ),
                  ],
                ),
                const SizedBox(height: 16),
                // Property Amenities (residential only, like web).
                if (selectedpropertytypedata != null &&
                    selectedpropertytypedata!.propertyType ==
                        "Residential" &&
                    _zillowAdvertise) ...[
                  _pfSectionCard(
                    children: [
                        ValueListenableBuilder<List<String>>(
                          valueListenable: propertyAmenities,
                          builder: (_, value, __) => AmenitiesField(
                            label:
                                'Property Amenities (Building/Community Level)',
                            value: value,
                            isStaff: false,
                            emptyText:
                                'No property amenities — click "Add Amenities" to select from the catalog or add custom.',
                            onChanged: (v) => propertyAmenities.value = v,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(
                    height: 16,
                  ),
                ],
                //rental
                _pfSectionCard(
                  title: 'Owner Information',
                  children: [
                            //  fontWeight: FontWeight.bold,
                            const Text.rich(
                              TextSpan(
                                text: 'Who is the property owner?',
                                children: [
                                  TextSpan(
                                    text: ' (Required)',
                                    style: TextStyle(
                                      color: mutedClr,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: navyClr,
                              ),
                            ),
                            const SizedBox(height: 6),
                            //  fontWeight: FontWeight.bold,
                            const Text(
                              "This information will be used to help prepare owner draws and 1099s.",
                              style: TextStyle(fontSize: 14, color: mutedClr),
                            ),
                            const SizedBox(height: 14),
                            _pfAddLink(
                              "Add Rental Owner",
                              onTap: () {
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) =>
                                            AddRentalowners()));
                              },
                            ),
                            if (hasError &&
                                Provider.of<OwnerDetailsProvider>(context)
                                        .OwnerDetails ==
                                    null)
                              const Padding(
                                padding: EdgeInsets.only(top: 6),
                                child: Text(
                                  'required',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            Consumer<OwnerDetailsProvider>(
                              builder: (context, provider, child) {
                                Ownersdetails = provider.OwnerDetails;
                                return Ownersdetails != null
                                    ? Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const SizedBox(height: 20),
                                          const Text(
                                            "Rental Owner Information",
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: navyClr,
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          Container(
                                            width: double.infinity,
                                            clipBehavior: Clip.antiAlias,
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border:
                                                  Border.all(color: borderClr),
                                            ),
                                            child: Column(
                                              children: [
                                                Container(
                                                  color: tintBg,
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 12,
                                                      vertical: 12),
                                                  child: const Row(
                                                    children: [
                                                      Expanded(
                                                        flex: 4,
                                                        child: Text('Name',
                                                            style:
                                                                _pfTableHead),
                                                      ),
                                                      SizedBox(width: 8),
                                                      Expanded(
                                                        flex: 5,
                                                        child: Text(
                                                            'Phone Number',
                                                            style:
                                                                _pfTableHead),
                                                      ),
                                                      SizedBox(width: 8),
                                                      SizedBox(
                                                        width: 80,
                                                        child: Text('Action',
                                                            style:
                                                                _pfTableHead),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                Padding(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 12,
                                                      vertical: 10),
                                                  child: Row(
                                                    children: [
                                                      Expanded(
                                                        flex: 4,
                                                        child: Text(
                                                          Ownersdetails!
                                                                  .rentalOwnerName ??
                                                              'N/A',
                                                          style: _pfTableCell,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Expanded(
                                                        flex: 5,
                                                        child: Text(
                                                          Ownersdetails!
                                                                  .rentalOwnerPhoneNumber ??
                                                              'N/A',
                                                          style: _pfTableCell,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      SizedBox(
                                                        width: 80,
                                                        child: Row(
                                                          children: [
                                                            _pfIconAction(
                                                              icon: Icons
                                                                  .edit_outlined,
                                                              color: const Color(
                                                                  0xFF2C72E0),
                                                              background:
                                                                  const Color(
                                                                      0xFFE8F0FC),
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
                                                            ),
                                                            const SizedBox(
                                                                width: 8),
                                                            _pfIconAction(
                                                              icon: Icons
                                                                  .delete_outline,
                                                              color: redClr,
                                                              background:
                                                                  const Color(
                                                                      0xFFFBE9E7),
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
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      )
                                    : const Text('');
                              },
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 20),
                              child: Container(
                                height: 1,
                                color: const Color(0xFFEAEEF4),
                              ),
                            ),
                            //  fontWeight: FontWeight.bold,
                            const Text(
                              "Who will be the primary manager of this property?",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: navyClr,
                              ),
                            ),
                            const SizedBox(height: 6),
                            //  fontWeight: FontWeight.bold,
                            const Text(
                              "If staff member has not yet been added as user in your account ,they can be added to the account"
                              ",than as the manager later through the property's summary details.",
                              style: TextStyle(fontSize: 14, color: mutedClr),
                            ),
                            const SizedBox(height: 16),
                            _pfFieldLabel('Manager (Optional)'),
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
                                                                      "Staff member name *",
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
                                                                                  hintText: "Enter a staff member name here *",
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
                                                                      "Designation *",
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
                                                                                  hintText: "Enter Designation here *",
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
                                                                      "Phone Number *",
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
                                                                                  hintText: "Enter Phone Number here *",
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
                                                                      "Email *",
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
                                                                                  hintText: "Enter Email here *",
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
                                                                      "Password *",
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
                                                                                  hintText: "Enter Password here",
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
                                                                              reload_Screen();
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

                                      return SizedBox(
                                          // height: MediaQuery.of(context)
                                          //         .size
                                          //         .height *
                                          //     .05,
                                          width: double.infinity,
                                          child: DropdownButtonHideUnderline(
                                            child: DropdownButton2<String>(
                                              value: selectedStaff,
                                              hint: const Text(
                                                'Select',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: _pfHintClr,
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
                                                height: 48,
                                                padding: const EdgeInsets.only(
                                                    right: 12),
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  color: Colors.white,
                                                  border: Border.all(
                                                      color: outlineClr),
                                                ),
                                              ),
                                              iconStyleData:
                                                  const IconStyleData(
                                                icon: Icon(
                                                    Icons.keyboard_arrow_down,
                                                    color: navyClr),
                                                iconSize: 22,
                                              ),
                                              dropdownStyleData:
                                                  DropdownStyleData(
                                                maxHeight: 300,
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
                                      );
                                    }
                                  },
                                ),
                  ],
                ),
                const SizedBox(
                  height: 16,
                ),
                //Insured Value Information
                _pfSectionCard(
                  title: "Insured Value Information",
                  children: [
                          _pfFieldLabel("Date Placed in Service",
                              required: true),
                          TextField(
                            controller: datePlacedInService,
                            readOnly: true,
                            style: _pfInputText,
                            cursorColor: navyClr,
                            decoration: _pfInputDecoration(
                              hint: "MM/DD/YYYY",
                              error: datePlacedInServiceError,
                              suffixIcon: GestureDetector(
                                onTap: _selectDatePlacedInService,
                                child: const Icon(
                                  Icons.calendar_today_outlined,
                                  color: navyClr,
                                  size: 18,
                                ),
                              ),
                            ),
                          ),
                          if (datePlacedInServiceError)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                datePlacedInServiceMessage,
                                style: const TextStyle(color: Colors.red),
                              ),
                            ),
                          const SizedBox(height: 20),
                          const Text(
                            "Historical Insured Values",
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: navyClr,
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (historicalInsuredValues.isNotEmpty)
                            ...historicalInsuredValues
                                .asMap()
                                .entries
                                .map((entry) {
                              int index = entry.key;
                              HistoricalInsuredValue item = entry.value;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          _pfFieldLabel("Year",
                                              required: true),
                                          DropdownButtonHideUnderline(
                                            child: DropdownButton2<String>(
                                              value: item.year,
                                              hint: const Text(
                                                'Select Year',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: _pfHintClr,
                                                ),
                                              ),
                                              onChanged: (String? newValue) {
                                                setState(() {
                                                  item.year = newValue;
                                                  item.yearError = false;
                                                });
                                              },
                                              items: _generateYearList()
                                                  .map((String year) {
                                                return DropdownMenuItem<
                                                    String>(
                                                  value: year,
                                                  child: Text(
                                                    year,
                                                    style: _pfInputText,
                                                  ),
                                                );
                                              }).toList(),
                                              isExpanded: true,
                                              buttonStyleData:
                                                  ButtonStyleData(
                                                height: 48,
                                                padding: const EdgeInsets
                                                    .only(right: 12),
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          12),
                                                  color: Colors.white,
                                                  border: Border.all(
                                                    color: item.yearError
                                                        ? Colors.red
                                                        : outlineClr,
                                                  ),
                                                ),
                                              ),
                                              iconStyleData:
                                                  const IconStyleData(
                                                icon: Icon(
                                                    Icons.keyboard_arrow_down,
                                                    color: navyClr),
                                                iconSize: 22,
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
                                          if (item.yearError)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                  top: 5, left: 2),
                                              child: Text(
                                                "Required",
                                                style: TextStyle(
                                                  color: Colors.red,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          _pfFieldLabel("Insured Value (\$)",
                                              required: true),
                                          TextField(
                                            controller: item.valueController,
                                            keyboardType: TextInputType
                                                .numberWithOptions(
                                                    decimal: true),
                                            style: _pfInputText,
                                            onChanged: (value) {
                                              setState(() {
                                                item.valueError = false;
                                              });
                                            },
                                            cursorColor: navyClr,
                                            decoration: _pfInputDecoration(
                                              hint: "Enter value",
                                              error: item.valueError,
                                            ),
                                          ),
                                          if (item.valueError)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                  top: 5, left: 2),
                                              child: Text(
                                                "Required",
                                                style: TextStyle(
                                                  color: Colors.red,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Padding(
                                      // color: Colors.blue,
                                      padding: const EdgeInsets.only(top: 34),
                                      child: _pfIconAction(
                                        icon: Icons.delete_outline,
                                        color: redClr,
                                        background: const Color(0xFFFBE9E7),
                                        onTap: () =>
                                            removeHistoricalInsuredValue(index),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          const SizedBox(height: 4),
                          _pfAddLink(
                            "Add Historical Insured Value",
                            onTap: addHistoricalInsuredValue,
                          ),
                  ],
                ),

                const SizedBox(height: 16),

                if (selectedpropertytypedata != null &&
                    selectedpropertytypedata!.propertyType == "Residential")
                  _pfSectionCard(
                    title: 'Residential Unit',
                    subtitle: 'Enter Residential Units',
                    trailing: selectedpropertytypedata?.isMultiunit == true
                        ? _pfAddLink(
                            "Add Another Unit",
                            // borderRadius: BorderRadius.circular(3),
                            // boxShadow: [
                            //   BoxShadow(
                            //     color: Colors.grey,
                            //     offset: Offset(0.0, 1.0), //(x,y)
                            //     blurRadius: 6.0,
                            //   ),
                            // ],
                            // fontWeight: FontWeight.bold,
                            onTap: () {
                              // if (selectedProperty != null) {
                              //   addPropertyGroup();
                              // }
                              addPropertyGroup();
                            },
                          )
                        : null,
                    children: [
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
                                          padding: EdgeInsets.only(
                                              top: index == 0 ? 0 : 12),
                                          child: _pfUnitCard(
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
                                              Row(
                                                children: [
                                                  if (selectedIsMultiUnit)
                                                    Expanded(
                                                      child: Text(
                                                        'Residential ${index + 1}',
                                                        style: const TextStyle(
                                                          fontSize: 16,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: navyClr,
                                                        ),
                                                      ),
                                                    )
                                                  else
                                                    const Spacer(),
                                                  Visibility(
                                                    visible:
                                                        !(selectedpropertytype ==
                                                                'Residential' &&
                                                            selectedIsMultiUnit ==
                                                                false &&
                                                            index == 0),
                                                    child: _pfIconAction(
                                                      icon:
                                                          Icons.delete_outline,
                                                      color: redClr,
                                                      background: const Color(
                                                          0xFFFBE9E7),
                                                      onTap: () =>
                                                          removePropertyGroup(
                                                              index),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              if (selectedIsMultiUnit)
                                                const SizedBox(height: 16),
                                              ...group,
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ],
                              ),
                    ],
                  ),
                if (selectedpropertytypedata != null &&
                    selectedpropertytypedata!.propertyType == "Commercial")
                  _pfSectionCard(
                    title: 'Commercial Unit',
                    subtitle: 'Enter Commercial Units',
                    trailing: selectedpropertytypedata?.isMultiunit == true
                        ? _pfAddLink(
                            "Add Another Unit",
                            // borderRadius: BorderRadius.circular(3),
                            // boxShadow: [
                            //   BoxShadow(
                            //     color: Colors.grey,
                            //     offset: Offset(0.0, 1.0), //(x,y)
                            //     blurRadius: 6.0,
                            //   ),
                            // ],
                            onTap: () {
                              addPropertyGroup();
                            },
                          )
                        : null,
                    children: [
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
                                          padding: EdgeInsets.only(
                                              top: index == 0 ? 0 : 12),
                                          child: _pfUnitCard(
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
                                              Row(
                                                children: [
                                                  if (selectedIsMultiUnit)
                                                    Expanded(
                                                      child: Text(
                                                        'Commercial ${index + 1}',
                                                        style: const TextStyle(
                                                          fontSize: 16,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: navyClr,
                                                        ),
                                                      ),
                                                    )
                                                  else
                                                    const Spacer(),
                                                  Visibility(
                                                    visible:
                                                        !(selectedpropertytype ==
                                                                'Commercial' &&
                                                            selectedIsMultiUnit ==
                                                                false &&
                                                            index == 0),
                                                    child: _pfIconAction(
                                                      icon:
                                                          Icons.delete_outline,
                                                      color: redClr,
                                                      background: const Color(
                                                          0xFFFBE9E7),
                                                      onTap: () =>
                                                          removePropertyGroup(
                                                              index),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              if (selectedIsMultiUnit)
                                                const SizedBox(height: 16),
                                              ...group,
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ],
                              ),
                    ],
                  ),
                if (iserror2)
                  const Text(
                    "required",
                    style: TextStyle(color: Colors.redAccent),
                  ),
                const SizedBox(height: 20),

                Row(
                  children: [
                    // SizedBox(width: MediaQuery.of(context).size.width * 0.01),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          // displayPropertyData();
                          Navigator.pop(context);
                        },
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white,
                          side: const BorderSide(color: outlineClr),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          "Cancel",
                          style: TextStyle(
                            color: mutedClr,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: ElevatedButton(
                      onPressed: () async {
                        if (_formKey.currentState!.validate()) {
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
                            /* List<Map<String, String>> processorIds = ownerDetails!.processorList!.map((processor) {
                          return {
                            'processor_id': processor.processorId ?? "",
                          };
                        }).toList();*/
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
                              // Straight from the owner screen: the Add form has
                              // no controllers of its own for these four.
                              alternateEmail:
                                  ownerDetails.rentalOwnerAlternateEmail,
                              homeNumber: ownerDetails.rentalOwnerHomeNumber,
                              businessNumber:
                                  ownerDetails.rentalOwnerBusinessNumber,
                              streetAddress: ownerDetails.streetAddress,
                              city: updatedOwner.city,
                              state: updatedOwner.state,
                              country: updatedOwner.country,
                              postalCode: updatedOwner.postalCode,
                              //processorid: processorIds!,
                            );

                            // SharedPreferences prefs =
                            //     await SharedPreferences.getInstance();
                            // String? adminId = prefs.getString("adminId");
                            if (adminId != null) {
                              //  try {
                              // Format placed_in_service date to yyyy-MM-dd
                              String? formattedPlacedInService;
                              if (datePlacedInService.text.isNotEmpty) {
                                try {
                                  // Parse the displayed date back to DateTime
                                  DateTime? parsedDate;
                                  List<String> dateFormats = [
                                    'yyyy-MM-dd',
                                    'yyyy-M-d',
                                    'yyyy-MMM-dd',
                                    'dd-MM-yyyy',
                                    'd-M-yyyy',
                                    'M/d/yyyy',
                                    'MM/dd/yyyy',
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
                                  // Remove commas from the value
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
                                      : null,
                                  propertyAmenities: List<String>.from(
                                      propertyAmenities.value)
                              );

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
                                  // Optional; empty -> null so the key is
                                  // omitted, like web (description || undefined).
                                  final String commercialDescription =
                                      controllers.length > 3
                                          ? controllers[3].text.trim()
                                          : '';
                                  units[i].description =
                                      commercialDescription.isEmpty
                                          ? null
                                          : commercialDescription;
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
                                  units[i].rentPrice = controllers[5].text.trim();
                                  units[i].halfBaths = controllers[6].text.trim();
                                  units[i].availabilityDate =
                                      _toApiDate(controllers[7].text);
                                  units[i].parkingType =
                                      controllers[8].text.trim();
                                  units[i].leaseTerm =
                                      controllers[9].text.trim();
                                  units[i].securityDeposit =
                                      controllers[10].text.trim();
                                  units[i].securityDepositType =
                                      controllers[11].text.trim();
                                  units[i].securityDepositMax =
                                      controllers[12].text.trim();
                                  units[i].securityDepositRefundable =
                                      controllers[13].text.trim();
                                  units[i].petPolicy =
                                      controllers[14].text.trim();
                                  units[i].isFurnished =
                                      controllers[15].text == 'true';
                                  units[i].smokingAllowed =
                                      controllers[16].text == 'true';
                                  units[i].description =
                                      controllers[17].text.trim();
                                  units[i].Image = propertyGroupImagenames[i];
                                  units[i].amenities = List<String>.from(
                                      propertyGroupAmenities[i].value);
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
                                  // print(controllers.length);
                                  units[i].sqft = controllers[0].text.trim();
                                  units[i].bath = controllers[1].text.trim();
                                  units[i].bed = controllers[2].text.trim();
                                  units[i].rentPrice = controllers[3].text.trim();
                                  units[i].halfBaths = controllers[4].text.trim();
                                  units[i].availabilityDate =
                                      _toApiDate(controllers[5].text);
                                  units[i].parkingType =
                                      controllers[6].text.trim();
                                  units[i].leaseTerm =
                                      controllers[7].text.trim();
                                  units[i].securityDeposit =
                                      controllers[8].text.trim();
                                  units[i].securityDepositType =
                                      controllers[9].text.trim();
                                  units[i].securityDepositMax =
                                      controllers[10].text.trim();
                                  units[i].securityDepositRefundable =
                                      controllers[11].text.trim();
                                  units[i].petPolicy =
                                      controllers[12].text.trim();
                                  units[i].isFurnished =
                                      controllers[13].text == 'true';
                                  units[i].smokingAllowed =
                                      controllers[14].text == 'true';
                                  units[i].description =
                                      controllers[15].text.trim();
                                  units[i].Image = propertyGroupImagenames[i];
                                  units[i].amenities = List<String>.from(
                                      propertyGroupAmenities[i].value);
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
                                  // Optional; empty -> null so the key is
                                  // omitted, like web (description || undefined).
                                  final String commercialDescription =
                                      controllers.length > 1
                                          ? controllers[1].text.trim()
                                          : '';
                                  units[i].description =
                                      commercialDescription.isEmpty
                                          ? null
                                          : commercialDescription;
                                  units[i].Image = propertyGroupImagenames[i];
                                }

                                units.removeWhere((unit) => unit.sqft!.isEmpty);
                              }
                              //  print("unit ${}")
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
                            }
                          }
                        } else {
                          // print('Form is invalid');
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: navyClr,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: loading
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: SpinKitFadingCircle(
                                color: Colors.white,
                                size: 22.0,
                              ),
                            )
                          : const Text(
                              "Create Property",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
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
        "id": "CRM $id",
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

/// Dashed rounded border for the unit photo upload box (look only; no
/// package needed). Same as the Edit Property screens.
class _PfDashedBorderPainter extends CustomPainter {
  const _PfDashedBorderPainter();

  static const Color _color = Color(0xFFCED4DA);
  static const double _stroke = 1.2;
  static const double _radius = 12;
  static const double _dash = 6;
  static const double _gap = 4;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _color
      ..strokeWidth = _stroke
      ..style = PaintingStyle.stroke;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(_radius),
    ).deflate(_stroke / 2);
    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      double d = 0;
      while (d < metric.length) {
        final double end =
            d + _dash < metric.length ? d + _dash : metric.length;
        canvas.drawPath(metric.extractPath(d, end), paint);
        d = end + _gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

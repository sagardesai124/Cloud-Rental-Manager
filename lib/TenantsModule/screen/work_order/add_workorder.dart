import 'package:three_zero_two_property/services/app_log.dart';
import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:flutter_svg/svg.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../widgets/VideoPlayerWidget.dart';
import '../../widgets/appbar.dart';
import 'package:three_zero_two_property/TenantsModule/repository/workorder.dart';
import 'package:three_zero_two_property/TenantsModule/widgets/drawer_tiles.dart';

import '../../../constant/constant.dart';
import '../../../screens/Maintenance/Vendor/add_vendor.dart';
import '../../../widgets/titleBar.dart';
import 'package:http/http.dart' as http;
import 'package:three_zero_two_property/services/api_helpers.dart';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:three_zero_two_property/services/api_helpers.dart';
import '../../../Model/All_categories_model.dart';
import '../../../repository/fetch_allcategories.dart';

import '../../widgets/custom_drawer.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: ImageUploadPage(),
    );
  }
}

class ImageUploadPage extends StatefulWidget {
  @override
  _ImageUploadPageState createState() => _ImageUploadPageState();
}

class _ImageUploadPageState extends State<ImageUploadPage> {
  bool isLoading = false;
  List<File> selectedImages = [];
  List<String?> uploaded_images = [];

  Future<String?> uploadImage(File imageFile) async {
    final String uploadUrl = '$image_upload_url/api/images/upload';
    var request = http.MultipartRequest('POST', Uri.parse(uploadUrl));
    request.files
        .add(await http.MultipartFile.fromPath('files', imageFile.path));

    var response = await apiSend(request);
    var responseData = await http.Response.fromStream(response);
    var responseBody = json.decode(responseData.body);
    if (responseBody['status'] == 'ok') {
      List file = responseBody['files'];
      return file.first["filename"];
    } else {
      throw Exception('Failed to upload file: ${responseBody['message']}');
    }
  }

  Future<void> selectImages() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
    );

    if (result != null) {
      setState(() {
        selectedImages = result.paths.map((path) => File(path!)).toList();
      });
    }
  }

  Future<void> uploadSelectedImages() async {
    setState(() {
      isLoading = true;
    });

    try {
      for (File image in selectedImages) {
        await uploadImage(image);
      }
      setState(() {
        selectedImages = [];
      });
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Images uploaded successfully')));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to upload images')));
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Upload Images'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (selectedImages.isNotEmpty)
              Wrap(
                children: selectedImages.map((image) {
                  return Container(
                    margin: EdgeInsets.all(8.0),
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8.0),
                      image: DecorationImage(
                        image: FileImage(image),
                        fit: BoxFit.cover,
                      ),
                    ),
                  );
                }).toList(),
              ),
            Container(
              height: 50,
              width: 150,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: blueColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                onPressed: isLoading
                    ? null
                    : () async {
                  await selectImages();
                },
                child: Text(
                  'Select Images',
                  style: TextStyle(color: Color(0xFFf7f8f9)),
                ),
              ),
            ),
            SizedBox(height: 20),
            Container(
              height: 50,
              width: 150,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: blueColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                onPressed: isLoading
                    ? null
                    : () async {
                  await uploadSelectedImages();
                },
                child: isLoading
                    ? Center(
                  child: SpinKitFadingCircle(
                    color: Colors.white,
                    size: 25.0,
                  ),
                )
                    : Text(
                  'Upload here',
                  style: TextStyle(color: Color(0xFFf7f8f9)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class Add_Workorder extends StatefulWidget {
  @override
  State<Add_Workorder> createState() => _Add_WorkorderState();
}

class _Add_WorkorderState extends State<Add_Workorder> {
  final TextEditingController subject = TextEditingController();

  final TextEditingController other = TextEditingController();

  final TextEditingController perform = TextEditingController();

  GlobalKey<FormState> _formkey = GlobalKey<FormState>();
  final TextEditingController _dateController = TextEditingController();

  @override
  void dispose() {
    // `subject` and `perform` are handed to CustomTextField, whose State
    // disposes whatever controller it is given (CustomTextFieldState in
    // screens/Maintenance/Vendor/add_vendor.dart). Releasing them here as
    // well threw "used after being disposed" when this screen closed.
    // `other` goes to a plain TextFormField, so it stays ours to release.
    other.dispose();
    _dateController.dispose();
    super.dispose();
  }
  bool form_valid = false;
  List<File> selectedImages = [];
  List<String?> uploaded_images = [];
  bool _isLoading = true;
  bool _Loading = false;
  bool _isUploadingImages = false;
  Map<String, String> properties = {}; // Mapping of rental_id to rental_address
  Map<String, String> units = {}; // Mapping of unit_id to rental_unit

  String? _selectedPropertyId;
  String? _selectedProperty;
  String? _selectedUnitId;
  String? _selectedUnit;
  String? _selectedRentaId;
  Future<void> selectImages() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.media,
      allowMultiple: true,
    );

    if (result != null) {
      setState(() {
        selectedImages = result.paths.map((path) => File(path!)).toList();
      });
    }
    uploadSelectedImages();
  }

  Future<void> uploadSelectedImages() async {
    if (selectedImages.isEmpty) return;
    setState(() => _isUploadingImages = true);
    try {
      for (File image in selectedImages) {
        var image_name = await uploadImage(image);
        uploaded_images.add(image_name);
      }
      setState(() {
        selectedImages = [];
      });
      //   ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Images uploaded successfully')));
    } catch (e) {
      // ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to upload images')));
    } finally {
      if (mounted) setState(() => _isUploadingImages = false);
    }
  }

  Future<String?> uploadImage(File imageFile) async {
    final String uploadUrl = '$image_upload_url/api/images/upload';
    var request = http.MultipartRequest('POST', Uri.parse(uploadUrl));
    // Every other authenticated call in this file sends these headers; this
    // upload never did. The server has since started requiring them here
    // (confirmed via a live 401 "session expired" — the token/id were never
    // actually being sent, not actually expired).
    final prefs = await SharedPreferences.getInstance();
    final _token = prefs.getString('token');
    final _tenantId = prefs.getString('tenant_id');
    request.headers.addAll({
      "authorization": "CRM $_token",
      "id": "CRM $_tenantId",
    });
    request.files
        .add(await http.MultipartFile.fromPath('files', imageFile.path));

    var response = await apiSend(request);
    var responseData = await http.Response.fromStream(response);
    var responseBody = json.decode(responseData.body);
    if (responseBody['status'] == 'ok') {
      // A success status with no file entries would otherwise crash on
      // .first (or on the null list itself). This loop uploads multiple
      // images in sequence, so an unguarded crash here would also abort
      // every remaining image in the batch.
      final List files = responseBody['files'] ?? [];
      if (files.isEmpty) {
        throw Exception('Upload succeeded but no file was returned');
      }
      return files.first["filename"];
    } else {
      throw Exception('Failed to upload file: ${responseBody['message']}');
    }
  }

  Future<void> _loadProperties() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString("tenant_id");
    String? admin_id = prefs.getString("adminId");
    String? token = prefs.getString('token');
    setState(() {
      _isLoading = true;
    });

    try {
      final response =
      await apiGet(Uri.parse('${Api_url}/api/tenant/tenant_property/$id'),
          //api/tenant/tenant_property
          headers: {
            "authorization": "CRM $token",
            "id": "CRM $id",
          });
      if (response.statusCode == 200) {
        List jsonResponse = json.decode(response.body)['data'];
        Map<String, String> addresses = {};
        // jsonResponse.forEach((data) {
        //   addresses[data['rental_id'].toString()] =
        //       data['rental_adress'].toString();
        // });
        // jsonResponse.forEach((data) {
        //   addresses[data['rental_id'].toString()] =
        //   '${data['rental_adress']} (${data['status']})';
        // });
        jsonResponse.forEach((data) {
          // Combine rental_id and address to create a unique key
          String key =
              '${data['rental_id']} - ${data['rental_adress']} - ${data['status']}';
          addresses[key] =
          '${data['rental_adress']} - ${data['status']}'; // Value remains the rental_id
        });

        setState(() {
          properties = addresses;
          _isLoading = false;
        });
      } else {
        //  throw Exception('Failed to load data');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text('Failed to fetch properties: ${friendlyErrorMessage(e)}')),
      // );
    }
  }

  void _showVideoDialog(String videoFile) {
    showDialog(
      context: context,
      builder: (context) {
        return Container(child: VideoPlayerDialog(videoUrl: videoFile));
      },
    );
  }

  Future<void> _loadUnits(String rentalId) async {
    setState(() {
      _isLoading = true;
    });
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString("tenant_id");
    String? admin_id = prefs.getString("adminId");
    String? token = prefs.getString('token');
    try {
      final response = await apiGet(
          Uri.parse(
              '$Api_url/api/unit/rental_unit_dropdown/$rentalId?tenant_id=$id'),
          headers: {
            "authorization": "CRM $token",
            "id": "CRM $id",
          });

      if (response.statusCode == 200) {
        List jsonResponse = json.decode(response.body)['data'];
        Map<String, String> unitAddresses = {};
        jsonResponse.forEach((data) {
          unitAddresses[data['unit_id'].toString()] =
              data['rental_unit'].toString();
        });

        setState(() {
          units = unitAddresses;
          _isLoading = false;
        });
      } else {
        //throw Exception('Failed to load units');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text('Failed to fetch units: ${friendlyErrorMessage(e)}')),
      // );
    }
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _loadProperties();
    _loadDropdownCategories();
  }

  Future<void> _loadDropdownCategories() async {
    setState(() {
      _isLoadingCategories = true;
    });
    try {
      final cats = await FetchAllcategories().fetchAllCategories();
      setState(() {
        _dropdownCategories = cats;
        _isLoadingCategories = false;
      });
    } catch (e) {
      logError('Error fetching categories in TenantsModule: ' + e.toString());
      setState(() {
        _isLoadingCategories = false;
      });
    }
  }

  List<allcategories_model> _dropdownCategories = [];
  allcategories_model? _selectedDropdownCategory;
  bool _isLoadingCategories = false;
  String? _selectedEntry;
  final List<String> _entry = [
    'Yes',
    'No',
  ];
  List<Map<String, dynamic>> rows = [];
  bool _showTextField = false;
  String renderId = '';
  String unitId = '';
  GlobalKey<ScaffoldState> key = GlobalKey<ScaffoldState>();
  String? _propertyErrorMessage;
  @override
  Widget build(BuildContext context) {
    double screenHeight = MediaQuery.of(context).size.height;
    double screenWidth = MediaQuery.of(context).size.height;
    return Scaffold(
      key: key,
      appBar: widget_302.App_Bar(
          context: context,
          onDrawerIconPressed: () {
            // print("calling appbar");
            key.currentState!.openDrawer();
            // Scaffold.of(context).openDrawer();
          }),
      backgroundColor: Colors.white,
      drawer: CustomDrawer(
        currentpage: 'Work Orders',
      ),
      body: Form(
        key: _formkey,
        child: Container(
          color: Colors.white,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  height: 25,
                ),
                titleBar(
                  width: MediaQuery.of(context).size.width * .91,
                  title: 'New Work Order',
                ),
                SizedBox(
                  height: 10,
                ),
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Container(
                    width: double.infinity,
                    // height: !form_valid ? 860 : 830,
                    decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10.0),
                        border: Border.all(
                          color: const Color(0xFFCED4DA),
                        )),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Subject *',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: blueColor)),
                          SizedBox(
                            height: 4,
                          ),
                          CustomTextField(
                            keyboardType: TextInputType.text,
                            hintText: 'Add subject',
                            controller: subject,
                            showElevation: false,
                            borderColor: const Color(0xFFCED4DA),
                            borderWidth: 1.5,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'please enter the subject';
                              }
                              return null;
                            },
                          ),
                          SizedBox(
                            height: 10,
                          ),
                          Text('Property *',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: blueColor)),

                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              DropdownButtonHideUnderline(
                                child: DropdownButtonFormField2<String>(
                                  decoration:
                                  InputDecoration(border: InputBorder.none),
                                  isExpanded: true,
                                  hint: const Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'Select here',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w400,
                                            color: Color(0xFFb0b6c3),
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  items: properties.keys.map((rentalId) {
                                    return DropdownMenuItem<String>(
                                      value: rentalId,
                                      child: Text(
                                        '${properties[rentalId]!}',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w400,
                                          color: Colors.black87,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    );
                                  }).toList(),
                                  value: _selectedPropertyId,
                                  onChanged: (value) {
                                    setState(() {
                                      _propertyErrorMessage = null;
                                      _selectedUnitId = null;
                                      _selectedPropertyId = value;
                                      _selectedProperty = properties[
                                      value]; // Store selected rental_adress
                                      //  _selectedProperty = properties[value]; // Store selected rental_adress
                                      String? selectedKey = value;
                                      List<String> splitValue =
                                      selectedKey!.split(' - ');

                                      _selectedRentaId = splitValue[0];
                                      String status = splitValue[2];
                                      // print('rentalid ${rentalId}');
                                      renderId = value.toString();

                                      _loadUnits(
                                          _selectedRentaId!); // Fetch units for the selected propert
                                      if (status.contains('Expired')) {
                                        _propertyErrorMessage =
                                        'Your lease for this property has expired. The work order will appear only on the admin/staff dashboard.';
                                      }
                                    });
                                  },
                                  buttonStyleData: ButtonStyleData(
                                    height: 50,
                                    width: 160,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 12),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(6),
                                      color: Colors.white,
                                      border: Border.all(color: Color(0xFFb0b6c3)),

                                    ),
                                    elevation: 0,
                                  ),
                                  iconStyleData: const IconStyleData(
                                    icon: Icon(
                                      Icons.arrow_drop_down,
                                    ),
                                    iconSize: 24,
                                    iconEnabledColor: Color(0xFFb0b6c3),
                                    iconDisabledColor: Colors.grey,
                                  ),
                                  dropdownStyleData: DropdownStyleData(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(6),
                                      color: Colors.white,
                                    ),
                                    scrollbarTheme: ScrollbarThemeData(
                                      radius: const Radius.circular(6),
                                      thickness: MaterialStateProperty.all(6),
                                      thumbVisibility:
                                      MaterialStateProperty.all(true),
                                    ),
                                  ),
                                  menuItemStyleData: const MenuItemStyleData(
                                    height: 40,
                                    padding:
                                    EdgeInsets.only(left: 14, right: 14),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please select an option';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              units.isNotEmpty
                                  ? Text('Unit',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: blueColor))
                                  : Container(),
                              const SizedBox(height: 0),
                              units.isNotEmpty
                                  ? DropdownButtonHideUnderline(
                                child: DropdownButtonFormField2<String>(
                                  decoration: InputDecoration(
                                      border: InputBorder.none),
                                  isExpanded: true,
                                  hint: const Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'Select here',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w400,
                                            color: Color(0xFFb0b6c3),
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  items: units.keys.map((unitId) {
                                    return DropdownMenuItem<String>(
                                      value: unitId,
                                      child: Text(
                                        units[unitId]!,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w400,
                                          color: Colors.black87,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    );
                                  }).toList(),
                                  value: _selectedUnitId,
                                  onChanged: (value) {
                                    setState(() {
                                      unitId = value.toString();
                                      _selectedUnitId = value;
                                      _selectedUnit = units[
                                      value]; // Store selected rental_unit

                                    });
                                  },
                                  buttonStyleData: ButtonStyleData(
                                    height: 50,
                                    width: 160,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 12),
                                    decoration: BoxDecoration(
                                      borderRadius:
                                      BorderRadius.circular(6),
                                      color: Colors.white,
                                      border: Border.all(
                                          color: Color(0xFFb0b6c3)),
                                      boxShadow: [
                                        BoxShadow(
                                            color: Colors.black12,
                                            blurRadius: 2,
                                            offset: Offset(0, 2)),
                                      ],
                                    ),
                                    elevation: 0,
                                  ),
                                  iconStyleData: const IconStyleData(
                                    icon: Icon(Icons.arrow_drop_down),
                                    iconSize: 24,
                                    iconEnabledColor: Color(0xFFb0b6c3),
                                    iconDisabledColor: Colors.grey,
                                  ),
                                  dropdownStyleData: DropdownStyleData(
                                    decoration: BoxDecoration(
                                      borderRadius:
                                      BorderRadius.circular(6),
                                      color: Colors.white,
                                    ),
                                    scrollbarTheme: ScrollbarThemeData(
                                      radius: const Radius.circular(6),
                                      thickness:
                                      MaterialStateProperty.all(6),
                                      thumbVisibility:
                                      MaterialStateProperty.all(true),
                                    ),
                                  ),
                                  menuItemStyleData:
                                  const MenuItemStyleData(
                                    height: 40,
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 12),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please select an option';
                                    }
                                    return null;
                                  },
                                ),
                              )
                                  : Container(),
                            ],
                          ),
                          SizedBox(
                            height: 4,
                          ),
                          Text('Category',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: blueColor)),
                          SizedBox(
                            height: 10,
                          ),
                          FormField<String>(
                            validator: (value) {
                              if (_selectedDropdownCategory == null) {
                                return 'Please select a category';
                              }
                              return null;
                            },
                            builder: (FormFieldState<String> state) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  DropdownButtonHideUnderline(
                                    child: DropdownButton2<allcategories_model>(
                                      isExpanded: true,
                                      hint: Text(_isLoadingCategories
                                          ? 'Loading categories...'
                                          : 'Select here',style: TextStyle(fontSize: 14, color: Color(0xFFb0b6c3)),),
                                      value: _dropdownCategories.contains(
                                          _selectedDropdownCategory)
                                          ? _selectedDropdownCategory
                                          : null,
                                      items: _dropdownCategories.map((cat) {
                                        return DropdownMenuItem<
                                            allcategories_model>(
                                          value: cat,
                                          child: Text(cat.name ?? ''),
                                        );
                                      }).toList(),
                                      onChanged: _isLoadingCategories
                                          ? null // disables dropdown while loading
                                          : (allcategories_model? newValue) {
                                        setState(() {
                                          _selectedDropdownCategory =
                                              newValue;
                                          _showTextField =
                                              newValue?.name == 'Other';
                                          state.didChange(newValue?.name);
                                        });
                                        state.reset();
                                        // Notify FormField of value change
                                      },
                                      buttonStyleData: ButtonStyleData(
                                        height: 50,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 0, vertical: 1),
                                        decoration: BoxDecoration(
                                          borderRadius:
                                          BorderRadius.circular(6),
                                          color: Colors.white,
                                          border: Border.all(
                                              color: Color(0xFFb0b6c3)),

                                        ),
                                        elevation: 0,
                                      ),
                                      iconStyleData: const IconStyleData(
                                        icon: Icon(Icons.arrow_drop_down),
                                        iconSize: 24,
                                        iconEnabledColor: Color(0xFFb0b6c3),
                                        iconDisabledColor: Colors.grey,
                                      ),
                                      dropdownStyleData: DropdownStyleData(
                                        decoration: BoxDecoration(
                                          borderRadius:
                                          BorderRadius.circular(6),
                                          color: Colors.white,
                                        ),
                                        scrollbarTheme: ScrollbarThemeData(
                                          radius: const Radius.circular(6),
                                          thickness:
                                          MaterialStateProperty.all(6),
                                          thumbVisibility:
                                          MaterialStateProperty.all(true),
                                        ),
                                      ),
                                      menuItemStyleData:
                                      const MenuItemStyleData(
                                        height: 50,
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 14, vertical: 12),
                                      ),
                                    ),
                                  ),
                                  if (state.hasError)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                          left: 0, top: 4),
                                      child: Text(
                                        state.errorText!,
                                        style: const TextStyle(
                                          color: Colors.red,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                          _showTextField
                              ? Padding(
                            padding: const EdgeInsets.only(
                                top: 10, bottom: 10),
                            child: buildTextField('Other Category',
                                'Enter Other Category', other),
                          )
                              : Container(),
                          SizedBox(
                            height: 10,
                          ),
                          Text('Entry Allowed ',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: blueColor)),
                          SizedBox(
                            height: 10,
                          ),
                          DropdownButtonHideUnderline(
                            child: DropdownButton2<String>(
                              isExpanded: true,
                              hint: Text('Select here',style: TextStyle(fontSize: 14, color: Color(0xFFb0b6c3)),),
                              value: _selectedEntry,
                              items: _entry.map((method) {
                                return DropdownMenuItem<String>(
                                  value: method,
                                  child: Text(method),
                                );
                              }).toList(),
                              onChanged: (String? newValue) {
                                setState(() {
                                  _selectedEntry = newValue;
                                  //_selectedPaymentMethod = addRow();
                                  // if(_selectedCategory == 'Other')
                                  // addRow();
                                });
                              },
                              buttonStyleData: ButtonStyleData(
                                height: 50,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 0, vertical: 1),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(6),
                                  color: Colors.white,
                                  border: Border.all(color: Color(0xFFb0b6c3)),
                                  // boxShadow: [
                                  //   BoxShadow(
                                  //       color: Colors.black12,
                                  //       blurRadius: 2,
                                  //       offset: Offset(0, 2)),
                                  // ],
                                ),
                                elevation: 0,
                              ),
                              iconStyleData: const IconStyleData(
                                icon: Icon(
                                  Icons.arrow_drop_down,
                                ),
                                iconSize: 24,
                                iconEnabledColor: Color(0xFFb0b6c3),
                                iconDisabledColor: Colors.grey,
                              ),
                              dropdownStyleData: DropdownStyleData(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(6),
                                  color: Colors.white,
                                ),
                                scrollbarTheme: ScrollbarThemeData(
                                  radius: const Radius.circular(6),
                                  thickness: MaterialStateProperty.all(6),
                                  thumbVisibility:
                                  MaterialStateProperty.all(true),
                                ),
                              ),
                              menuItemStyleData: const MenuItemStyleData(
                                height: 40,
                                padding: EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 12),
                              ),
                            ),
                          ),
                          SizedBox(
                            height: 10,
                          ),
                          Text('Work To Be Performed',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: blueColor)),
                          SizedBox(
                            height: 10,
                          ),
                          CustomTextField(
                            keyboardType: TextInputType.text,
                            hintText: 'Enter here',
                            showElevation: false,
                            borderColor: const Color(0xFFCED4DA),
                            borderWidth: 1.5,
                            controller: perform,
                            optional: true,
                          ),
                          // Web parity (TAddWork.js): Photos sit after Work To
                          // Be Performed, as the last section before the
                          // buttons — same as the Edit screen.
                          SizedBox(
                            height: 10,
                          ),
                          _buildImageUploadSection(),
                          SizedBox(
                            height: 10,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(
                      top: 16, right: 16, left: 16, bottom: 5),
                  child: Row(
                    children: [
                      Container(
                        height: 50,
                        width: 150,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: blueColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                          ),
                          onPressed: _submitForm,
                          child: isloading
                              ? Center(
                            child: SpinKitFadingCircle(
                              color: Colors.white,
                              size: 55.0,
                            ),
                          )
                              : Text(
                            'Add Work Order',
                            style: TextStyle(color: Color(0xFFf7f8f9),fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 8,
                      ),
                      Container(
                          height: 50,
                          width: 120,
                          decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8.0)),
                          child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Color(0xFFffffff),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                      BorderRadius.circular(8.0))),
                              onPressed: () {
                                Navigator.pop(context);
                              },
                              child: Text(
                                'Cancel',
                                style: TextStyle(color: Color(0xFF748097),fontWeight: FontWeight.bold),
                              )))
                    ],
                  ),
                ),
                if (_propertyErrorMessage !=
                    null) // Display error message if present
                  Padding(
                    padding:
                    const EdgeInsets.only(top: 8.0, left: 16, right: 16),
                    child: Text(
                      _propertyErrorMessage!,
                      textAlign: TextAlign.justify,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.red,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                SizedBox(
                  height: 30,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool isVideo(String url) {
    return url.toLowerCase().endsWith(".mp4");
  }

  /// Image upload section: Maintenance-style (upload icon, file size/types text)
  Widget _buildImageUploadSection() {
    const double thumbSize = 80;
    const int maxImages = 10;
    final totalImages = uploaded_images.where((e) => e != null && e.isNotEmpty).length;
    final canAdd = totalImages < maxImages;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Photos (Maximum of 10)',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: blueColor)),
        const SizedBox(height: 10),
        if (totalImages == 0)
          GestureDetector(
            onTap: canAdd ? selectImages : null,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Image.asset(
                    'assets/icons/Upload.png',
                    height: 50,
                    width: 50,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Upload your Photo here',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Maximum File Size is 20MB',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey),
                  ),
                  const Text(
                    'Supported File Types are .png, .jpeg, .pdf, .csv',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey),
                  ),

                ],
              ),
            ),
          ),
        if (totalImages == 0) const SizedBox(height: 10),
        if (totalImages > 0)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (canAdd)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      GestureDetector(
                        onTap: selectImages,
                        child: Container(
                          height: 28,
                          width: 28,
                          decoration: BoxDecoration(
                            color: blueColor,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(Icons.add, color: Colors.white, size: 18),
                        ),
                      ),
                    ],
                  ),
                if (canAdd) const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: uploaded_images
                      .where((e) => e != null && e.isNotEmpty)
                      .toList()
                      .asMap()
                      .entries
                      .map((entry) {
                    final imageUrl = entry.value!;
                    final isMp4 = isVideo(imageUrl);
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [

                        const SizedBox(height: 4),
                        GestureDetector(
                          onTap: () =>
                              setState(() => uploaded_images.remove(imageUrl)),
                          child: Icon(Icons.close, color: Colors.grey[700], size: 22),
                        ),
                        Container(
                          width: thumbSize,
                          height: thumbSize,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: isMp4
                                ? GestureDetector(
                              onTap: () => _showVideoDialog('$image_url$imageUrl'),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  VideoItem(url: '$image_url$imageUrl'),
                                  const Icon(Icons.play_circle_fill,
                                      color: Colors.white, size: 40),
                                ],
                              ),
                            )
                                : Image.network(
                              '$image_url$imageUrl',
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                              const Icon(Icons.error, size: 32),
                            ),
                          ),
                        ),

                      ],
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        if (_isUploadingImages)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: LinearProgressIndicator(),
          ),
      ],
    );
  }

  Widget buildTextField(
      String label, String hintText, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label,
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
        SizedBox(height: 8.0),
        Material(
          elevation: 3,
          borderRadius: BorderRadius.circular(5),
          child: Container(
            padding: EdgeInsets.only(left: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(5),
            ),
            child: TextFormField(
              controller: controller,
              focusNode: FocusNode(),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: hintText,
              ),
            ),
          ),
        ),
      ],
    );
  }

  bool isLoading = false;
  bool isloading = false;
  bool formValid = true;

  void _submitForm() async {
    // Reentrancy lock: the button stays tappable while the request
    // runs, and a retry after a slow/failed response created REAL
    // duplicate work orders (the server saves before it responds).
    if (isloading) return;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? firstName = prefs.getString("first_name");
    String? lastName = prefs.getString("last_name");
    if (_formkey.currentState!.validate()) {
      setState(() {
        isloading = true;
      });
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? id = prefs.getString("tenant_id");
      String? admin_id = prefs.getString("adminId");
      String? token = prefs.getString('token');
      String? rentalId = _selectedPropertyId;
      String? unitId = _selectedUnitId;

      try {
        final workOrder = await WorkOrderRepository().addWorkOrder(
          adminId: admin_id,
          workOrder_images: uploaded_images,
          workSubject: subject.text.trim(),
          workCategory: _selectedDropdownCategory?.name,
          workPerformed: perform.text.trim(),
          status: 'New',
          rentalAddress: _selectedRentaId ?? "",
          rentalUnit: units[_selectedUnitId] ?? "",
          tenant: "${firstName} ${lastName}(Tenant)",
          rentalid: _selectedRentaId,
          unitid: unitId,
          entry: _selectedEntry == 'Yes',
          notificationTime:
          DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
        );

        // No success toast here on purpose. addWorkOrder() in
        // TenantsModule/repository/workorder.dart already raises the server's
        // confirmation message, so showing this one as well put TWO toasts on
        // screen at once when saving. The Admin, Staff and Vendor add screens
        // all let the repository own that message, so Tenant now matches them.
        // The failure toast in the catch below stays: the repository throws
        // without toasting on failure, so this screen is its only source.
        Navigator.pop(context, true);
        // Handle success: Maybe navigate to another screen or reset the form
      } catch (e) {
        Fluttertoast.showToast(
            msg: friendlyErrorMessage(e,
                fallbackMessage: 'Failed to add work order. Please try again.'),
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            timeInSecForIosWeb: 1,
            backgroundColor: Colors.red,
            textColor: Colors.white,
            fontSize: 16.0);

        // Handle error: Log the error, show a dialog, etc.
        logError(e);
      } finally {
        setState(() {
          isloading = false;
        });
      }
    } else {
      setState(() {
        formValid = false;
      });
    }
  }
}
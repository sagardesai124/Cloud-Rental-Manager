import 'dart:convert';
import 'dart:developer';

import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:three_zero_two_property/widgets/no_internet_view.dart';
import 'package:three_zero_two_property/provider/network_retry_state.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../Model/manage_template_model.dart';
import '../../constant/constant.dart';
import 'package:http/http.dart' as http;
import 'package:three_zero_two_property/services/api_helpers.dart';
class manage_templates extends StatefulWidget {
  const manage_templates({super.key});

  @override
  State<manage_templates> createState() => _manage_templatesState();
}

class _manage_templatesState extends State<manage_templates>
    with NetworkRetryState {

  /// `id` header = the logged-in user's own id (web parity: the axios
  /// interceptor sends it for every request). The server only honours adminId
  /// with an admin token, so Staff — who reach this shared screen too — send
  /// staff_id. Keyed off the stored role, never a leftover staff_id. The
  /// company id stays in the URL/body.
  String? _ownIdHeader(SharedPreferences prefs) {
    final staffId = prefs.getString('staff_id');
    return (prefs.getString('role') == 'Staffmember' &&
            staffId != null &&
            staffId.isNotEmpty)
        ? staffId
        : prefs.getString('adminId');
  }
  List<Templates> dummyTemplateList = [
    Templates(
      type: "Reset password",
      templates: [
        Template(
          sId: "6780ef6e7dd8556a7db403c0",
          templateId: "1736503150202",
          adminId: "1730954076891",
          name: "Invitation",
          mailType: "Invitation",
          isActive: false,
        ),
        Template(
          sId: "67cabb54b7a739fbd4654e48",
          templateId: "1741339476981",
          adminId: "1730954076891",
          name: "Test Invitation",
          mailType: "Invitation",
          isActive: false,
        ),
      ],
      isEnabled: false,
    ),
    Templates(
      type: "Invitation",
      isEnabled: false,
      templates: [
        Template(
          sId: "6780ef6e7dd8556a7db403c0",
          templateId: "1736503150202",
          adminId: "1730954076891",
          name: "Invitation",
          mailType: "Invitation",
          isActive: false,
        ),
        Template(
          sId: "67cabb54b7a739fbd4654e48",
          templateId: "1741339476981",
          adminId: "1730954076891",
          name: "Test Invitation",
          mailType: "Invitation",
          isActive: false,
        ),
      ],
    ),
    Templates(
      type: "Lease creation",
      templates: [
        Template(
          sId: "6780ef6e7dd8556a7db403c0",
          templateId: "1736503150202",
          adminId: "1730954076891",
          name: "Invitation",
          mailType: "Invitation",
          isActive: false,
        ),
        Template(
          sId: "67cabb54b7a739fbd4654e48",
          templateId: "1741339476981",
          adminId: "1730954076891",
          name: "Test Invitation",
          mailType: "Invitation",
          isActive: false,
        ),
      ],
      isEnabled: true,
    ),
    Templates(
      type: "Applicant application",
      templates: [

      ],
      isEnabled: true,
    ),
  ];

  /// Required by [NetworkRetryState]: re-issue this view's own load.
  /// The one load initState makes; the dummy template list it also seeds is
  /// local state, not something a reload should rebuild.
  @override
  Future<void> reloadData() async {
    if (!mounted) return;
    await fetchTemplates();
  }

  @override
  initState(){
    super.initState();
    fetchTemplates();
    for (var element in dummyTemplateList) {


      final activeTemplate = element.templates?.firstWhere(
            (item) => item.isActive == true,
        orElse: () => Template(name: null),
      );
      if (activeTemplate?.name != null) {
        selectedTemplates[element.type!] =
        "${activeTemplate!.templateId}|${activeTemplate.name}";
      }
      selectedTemplates[element.type!] = activeTemplate?.name;
    }

  }
  Future<void> fetchTemplates() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');
    String? id = prefs.getString('adminId');
   // try {
      final response = await apiGet(Uri.parse("$Api_url/api/templates/settings/$id"), headers: {
      "authorization" : "CRM $token",
      "id":"CRM ${_ownIdHeader(prefs)}",
      },);
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body)["templates"];

        List<Templates> fetchedTemplates = data.map((e) => Templates.fromJson(e)).toList();

        setState(() {
          dummyTemplateList = fetchedTemplates;

          // Initialize selectedTemplates with active template
          for (var element in dummyTemplateList) {
            final activeTemplate = element.templates?.firstWhere(
                  (item) => item.isActive == true,
              orElse: () => Template(name: null),
            );
            if (activeTemplate?.name != null) {
              selectedTemplates[element.type!] =
              "${activeTemplate!.templateId}|${activeTemplate.name}";
            }else{
              selectedTemplates[element.type!] = null;
            }
            
            // Store original values for change tracking
            if (element.type != null) {
              _originalIsEnabled[element.type!] = element.isEnabled ?? false;
              _originalSelectedTemplates[element.type!] = selectedTemplates[element.type!];
            }
          }
        });
      } else {
        // Handle non-200 errors
      }

  }

  Map<String, String?> selectedTemplates = {};
  // Original values for change tracking
  Map<String, bool> _originalIsEnabled = {};
  Map<String, String?> _originalSelectedTemplates = {};
  
  // Check if any changes were made
  bool _hasTemplateChanges() {
    // Check if any switch state changed
    for (var element in dummyTemplateList) {
      if (element.type != null) {
        final originalEnabled = _originalIsEnabled[element.type!] ?? false;
        final currentEnabled = element.isEnabled ?? false;
        if (originalEnabled != currentEnabled) {
          return true;
        }
      }
    }
    
    // Check if any dropdown selection changed
    for (var entry in selectedTemplates.entries) {
      final originalValue = _originalSelectedTemplates[entry.key];
      final currentValue = entry.value;
      if (originalValue != currentValue) {
        return true;
      }
    }
    
    return false;
  }
  
  @override
  Widget build(BuildContext context) {
    // Lives inside another screen, so the compact offline state is what
    // fits here rather than taking over the whole page.
    if (isOffline) {
      return NoInternetView(compact: true, onRetry: retryNow);
    }
    return Container(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 10),
          Row(
            children: [
              Text(
                "Manage Templates",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: blueColor,
                  fontSize: MediaQuery.of(context).size.width < 500 ? 18 : 25,
                ),
              ),
              Spacer(),
            ],
          ),
          SizedBox(height: 20),
          Column(
            children: dummyTemplateList.map((element) {
              final templates = element.templates ?? [];
              Template? selectedTemplate = element.templates!.firstWhere((item)=>item.isActive ==true, orElse: () => Template(name: ''),);
              return Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10.0),
                    child: Text("${element.type}",style: TextStyle(fontWeight: FontWeight.bold),),
                  ),
                  Row(

                    children: [
                      Switch(value: element.isEnabled!,
                          activeColor: blueColor,
                          onChanged: (value){
                        setState(() {
                          element.isEnabled = value;
                        });
                      }),

                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 8.0, right: 10.0),
                          child: templates.isEmpty
                              ? DropdownButtonHideUnderline(
                            child: DropdownButton2<String>(
                              isExpanded: true,
                              hint: const Text("Select template"),
                              items: [
                                DropdownMenuItem<String>(
                                  enabled: true,
                                  value: 'not_found',
                                  child: Text("Template not found"),
                                )
                              ],
                              onChanged:  element.isEnabled! ? (value){} : null, // disables dropdown interaction
                              buttonStyleData: ButtonStyleData(
                                height: 46,
                                padding: const EdgeInsets.symmetric(horizontal: 3),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(6),
                                  color: Colors.white,
                                ),
                                elevation: 2,
                              ),
                              iconStyleData: const IconStyleData(
                                icon: Icon(Icons.arrow_drop_down),
                                iconSize: 24,
                                iconEnabledColor: Color(0xFFb0b6c3),
                                iconDisabledColor: Colors.grey,
                              ),
                              dropdownStyleData: DropdownStyleData(
                                maxHeight: 150,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(6),
                                  color: Colors.white,
                                ),
                              ),
                              menuItemStyleData: const MenuItemStyleData(
                                height: 50,
                                padding: EdgeInsets.symmetric(horizontal: 14),
                              ),
                            ),
                          )
                              : DropdownButtonHideUnderline(
                                child:DropdownButton2<String>(
                                  isExpanded: true,
                                  value: selectedTemplates[element.type],
                                  hint: const Text("Select template"),
                                  items: templates.map<DropdownMenuItem<String>>((template) {
                                    final combinedKey = "${template.templateId}|${template.name}";
                                    return DropdownMenuItem<String>(
                                      value: combinedKey,
                                      child: Text(template.name ?? ""),
                                    );
                                  }).toList(),
                                  onChanged: (newVal) {
                                    setState(() {
                                      selectedTemplates[element.type!] = newVal;
                                    });
                                  },
                                  buttonStyleData: ButtonStyleData(
                                    height: 46,
                                    padding: EdgeInsets.symmetric(horizontal: 3),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(6),
                                      color: Colors.white,
                                    ),
                                    elevation: 2,
                                  ),
                                  iconStyleData: const IconStyleData(
                                    icon: Icon(Icons.arrow_drop_down),
                                    iconSize: 24,
                                    iconEnabledColor: Color(0xFFb0b6c3),
                                    iconDisabledColor: Colors.grey,
                                  ),
                                  dropdownStyleData: DropdownStyleData(
                                    maxHeight: 300,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(6),
                                      color: Colors.white,
                                    ),
                                    scrollbarTheme: ScrollbarThemeData(
                                      radius: const Radius.circular(6),
                                      thickness: MaterialStateProperty.all(6),
                                      thumbVisibility: MaterialStateProperty.all(true),
                                    ),
                                  ),
                                  menuItemStyleData: const MenuItemStyleData(
                                    height: 50,
                                    padding: EdgeInsets.only(left: 14, right: 14),
                                  ),
                                )

                          ),
                        ),
                      ),

                    ],
                  ),
                  SizedBox(height: 10,)
                ],
              );
            }).toList(),
          ),
          SizedBox(height: 10),
          GestureDetector(
            onTap: _hasTemplateChanges()
                ? () async {
                    final jsonData = dummyTemplateList.map((e) => e.toJson()).toList();
                    log(jsonEncode(jsonData));
                    await updateSelectedTemplates();
                  }
                : null,
            child: Opacity(
              opacity: _hasTemplateChanges() ? 1.0 : 0.5,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(5.0),
                child: Container(
                  height:
                  MediaQuery.of(context).size.width <
                      500
                      ? 35
                      : 50,
                  width:
                  MediaQuery.of(context).size.width <
                      500
                      ? 100
                      : 150,
                  decoration: BoxDecoration(
                    borderRadius:
                    BorderRadius.circular(5.0),
                    color: blueColor,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey,
                        offset: Offset(0.0, 1.0), //(x,y)
                        blurRadius: 6.0,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      "Save",
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: MediaQuery.of(context)
                              .size
                              .width <
                              500
                              ? 16
                              : 20),
                    ),
                  ),
                ),
              ),
            ),
          ),

        ],
      ),
    );
  }
  Future<void> updateSelectedTemplates() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');

    for (var entry in selectedTemplates.entries) {
      final templateType = entry.key;
      final selectedValue = entry.value;

      // Skip if no value selected
      if (selectedValue == null) continue;

      // Find the corresponding Template object from dummyTemplateList
      final templateObj = dummyTemplateList
          .firstWhere((t) => t.type == templateType)
          .templates
          ?.firstWhere((template) => '${template.templateId}|${template.name}' == selectedValue, orElse: () => Template());

      final templateId = templateObj?.templateId;

      if (templateId != null && templateId.isNotEmpty) {
        final url = Uri.parse('$Api_url/api/templates/settings/$templateId');

        final response = await apiPut(
          url,
          headers: {
            'authorization': 'CRM $token',
            'id': 'CRM ${_ownIdHeader(prefs)}',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'is_active': true}),
        );
        if (response.statusCode == 200) {
          await updateSwitchBasedPreferences();
        } else {
        }
      }
    }
  }

  Future<void> updateSwitchBasedPreferences() async {
    // Check if there are any changes before proceeding
    if (!_hasTemplateChanges()) {
      return; // No changes made, don't proceed with update
    }
    
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');
    String? adminId = prefs.getString('adminId');

    // Constructing enabledArray for the API
    Map<String, bool> enabledArray = {};

    for (var item in dummyTemplateList) {
      if (item.type != null) {
        enabledArray[item.type!] = item.isEnabled ?? false;
      }
    }

    final url = Uri.parse('$Api_url/api/mail_preferences');

    final response = await apiPut(
      url,
      headers: {
        'authorization': 'CRM $token',
        'id': 'CRM ${_ownIdHeader(prefs)}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'admin_id': adminId,
        'enabledArray': enabledArray,
      }),
    );

    if (response.statusCode == 200) {
      // Update original values after successful save
      setState(() {
        for (var element in dummyTemplateList) {
          if (element.type != null) {
            _originalIsEnabled[element.type!] = element.isEnabled ?? false;
            _originalSelectedTemplates[element.type!] = selectedTemplates[element.type!];
          }
        }
      });
      Fluttertoast.showToast(msg: "Changes saved");
    } else {
    }
  }

}

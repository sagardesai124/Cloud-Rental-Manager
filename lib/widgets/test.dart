import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:three_zero_two_property/services/api_helpers.dart';
import 'dart:convert';


import '../constant/constant.dart';



class LoginProvider with ChangeNotifier {
  String _email = '';
  bool _isEmailSubmitted = false;
  bool _hasMultipleCompanies = false;
  List<String> _companies = [];
  String _selectedCompany = '';
  String _password = '';

  String get email => _email;
  bool get isEmailSubmitted => _isEmailSubmitted;
  bool get hasMultipleCompanies => _hasMultipleCompanies;
  List<String> get companies => _companies;
  String get selectedCompany => _selectedCompany;
  String get password => _password;

  void setEmail(String email) {
    if (_email != email) {
      _email = email;
      _isEmailSubmitted = false;
      _hasMultipleCompanies = false;
      _companies = [];
      _selectedCompany = '';
      _password = '';
      notifyListeners();
    }
  }

  void setPassword(String password) {
    _password = password;
    notifyListeners();
  }

  Future<void> submitEmail() async {
    // Make API call to check email
    final response = await apiPost(
      Uri.parse('http://192.168.1.22:4000/api/admin/check_role'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': _email}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      List<dynamic> roles = data['data'];
      if (roles.isEmpty) {
        Fluttertoast.showToast(msg: "Email does not exist");
      } else {
        if (roles.length > 1) {
          _hasMultipleCompanies = true;
          _companies = roles

              .map<String>((role) => '${role['company_name']} (${role['role']})')
              .toList();
           _isEmailSubmitted = true;
        } else {
          _hasMultipleCompanies = false;
           _isEmailSubmitted = true;
        }
      }
    } else {
      Fluttertoast.showToast(msg: "Email is not exist");
    }

   // _isEmailSubmitted = true;
    notifyListeners();
  }

  void selectCompany(String company) {
    _selectedCompany = company;
    notifyListeners();
  }

  void login() {
    // Implement login logic here
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
  String capitalizeFirstLetter(String input) {
    if (input.isEmpty) return input;
    return input[0].toUpperCase() + input.substring(1);
  }

}
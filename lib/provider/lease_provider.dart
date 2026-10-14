import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:three_zero_two_property/constant/constant.dart';
import 'package:three_zero_two_property/model/rental_properties.dart';

import '../Model/tenants.dart';
import '../model/ApplicantModel.dart';
import '../model/LeaseLedgerModel.dart';
import '../model/cosigner.dart';
import '../repository/lease.dart';
import '../screens/Leasing/RentalRoll/newAddLease.dart';

class SelectedTenantsProvider extends ChangeNotifier {
  List<Tenant> _selectedTenants = [];
  List<TextEditingController> _rentShareControllers = [];
  String? _validationMessage;
  List<Tenant> get selectedTenants => _selectedTenants;
  List<TextEditingController> get rentShareControllers => _rentShareControllers;
  String? get validationMessage => _validationMessage;
  // void addTenant(Tenant tenant) {
  //   print("Add Tenant is calling ");
  //   if (_selectedTenants.isEmpty) {
  //     // Set rent share to 100 for the first tenant
  //     _rentShareControllers.add(TextEditingController(text: '100'));
  //   } else {
  //     _rentShareControllers.add(TextEditingController());
  //   }
  //   for(var i=0;i< _selectedTenants.length;i++){
  //     print("Tenants ${_selectedTenants[i].tenantFirstName} ${_selectedTenants[i].tenantLastName} ${_selectedTenants[i].tenantId}");
  //   }
  //   // Check if the tenant is already in the selected tenants
  //   if (_selectedTenants.any((existingTenant) => existingTenant.tenantLastName == tenant.tenantLastName)) {
  //     print("Tenant ${tenant.tenantLastName} is already added.");
  //     return; // Exit the method if the tenant is already added
  //   }
  //
  //
  //
  //   print("add before length ${tenant.tenantLastName}");
  //   _selectedTenants.add(tenant);
  //   print("add after length ${_selectedTenants.length}");
  //   notifyListeners();
  // }

  /// Adds [tenant] unless the same person is already on the lease; returns
  /// whether it was added.
  bool addTenant(Tenant tenant) {
//    Check if the tenant is already in the selected tenants
    if (isAdded(tenant)) {
      return false; // Exit the method if the tenant is already added
    }



    // Add a new controller for the tenant
    if (_selectedTenants.isEmpty || _selectedTenants.length == 0) {
      // Set rent share to 100 for the first tenant
      _rentShareControllers.add(TextEditingController(text: '100'));
    } else {
      _rentShareControllers.add(TextEditingController()); // Subsequent tenants get 0
    }

    _selectedTenants.add(tenant);
    notifyListeners();
    return true;
  }

  /// Whether the same person as [tenant] is already on the lease.
  bool isAdded(Tenant tenant) =>
      _selectedTenants.any((existing) => _sameTenant(existing, tenant));

  // Saved tenants match by tenant id and applicants by applicant id. A tenant
  // typed in on the form has neither yet, so when either side is such a
  // tenant they match by email (the server refuses two tenants with the same
  // email on one lease), whichever was added first. Two different new
  // tenants, or a new tenant next to an existing one, can both be added.
  bool _sameTenant(Tenant existing, Tenant tenant) {
    String norm(String? v) => (v ?? '').trim();
    if (norm(tenant.tenantId).isNotEmpty &&
        existing.tenantId == tenant.tenantId) {
      return true;
    }
    if (norm(tenant.applicantId).isNotEmpty &&
        existing.applicantId == tenant.applicantId) {
      return true;
    }
    bool typedIn(Tenant t) =>
        norm(t.tenantId).isEmpty && norm(t.applicantId).isEmpty;
    if (!typedIn(existing) && !typedIn(tenant)) return false;
    final email = norm(tenant.tenantEmail).toLowerCase();
    return email.isNotEmpty &&
        norm(existing.tenantEmail).toLowerCase() == email;
  }

  void AddEditTenant(){
    for(var i=0;i< _selectedTenants.length;i++){
    }
  }

  void setTenants(List<Tenant> tenants) {
    _selectedTenants = tenants;
    _rentShareControllers = List.generate(
        tenants.length, (index) => TextEditingController()); // Generate controllers for each tenant
    notifyListeners();
  }

  void removeTenant(Tenant tenant) {
    int index = _selectedTenants.indexOf(tenant);
    if (index == -1) {
      index = _selectedTenants.indexWhere((t) => _sameTenant(t, tenant));
    }
    if (index != -1) {
      _selectedTenants.removeAt(index);
      _rentShareControllers[index].dispose(); // Dispose the controller to avoid memory leaks
      _rentShareControllers.removeAt(index);
      notifyListeners();
    }
  }

  void clearonlyTenant(){
    _selectedTenants.clear();
  }
  void clearTenant() {
    _selectedTenants.clear();
    _rentShareControllers.forEach((controller) => controller.dispose()); // Dispose all controllers
    _rentShareControllers.clear();
    notifyListeners();
  }
  // bool validateRentShares() {
  //   double totalRentShare = 0;
  //
  //   for (var controller in _rentShareControllers) {
  //     double rentShare = double.tryParse(controller.text) ?? 0;
  //     totalRentShare += rentShare;
  //   }
  //
  //   if (totalRentShare > 100) {
  //     _validationMessage = "Total rent share cannot exceed 100%";
  //     notifyListeners();
  //     return false;
  //   }
  //
  //   _validationMessage = null; // Reset validation message if valid
  //   notifyListeners();
  //   return true;
  // }

  void setValidationMessage(String message) {
    _validationMessage = message;
    notifyListeners();
  }


  void clearValidationMessage() {
    _validationMessage = null;
    notifyListeners(); // Update listeners to clear the error in the UI
  }

  bool validateRentShares() {
    double totalRentShare = 0;
    bool allFieldsEmpty = true;

    for (var controller in _rentShareControllers) {
      double rentShare = double.tryParse(controller.text) ?? 0;
      totalRentShare += rentShare;

      if (rentShare > 0) {
        allFieldsEmpty = false;
      }
    }

   //  if (totalRentShare > 100) {
   //    _validationMessage = "Total rent share cannot exceed 100%";
   //    notifyListeners();
   //    return false;
   //  }
   // else if (totalRentShare < 100) {
   //    _validationMessage = allFieldsEmpty
   //        ? "Tenants must enter rent share values."
   //        : "Total rent share must equal 100%";
   //    notifyListeners();
   //    return false;
   //  }

   _validationMessage = null;
    notifyListeners();
    return true;
  }



}




class SelectedCosignersProvider extends ChangeNotifier {
  List<Cosigner> _cosigners = [];

  List<Cosigner> get cosigners => _cosigners;

  void addCosigner(Cosigner cosigner) {
    _cosigners.add(cosigner);
    notifyListeners();
  }

  void removeConsigner(Cosigner cosigner) {
    _cosigners.remove(cosigner);
    notifyListeners();
  }

  void updateCosigner(Cosigner updatedCosigner, int index) {
    _cosigners[index] = updatedCosigner;
    notifyListeners();
    // for (int i = 0; i < _cosigners.length; i++) {
    //
    //   if (_cosigners[i].c_id == updatedCosigner.c_id) {
    //     print("update");
    //     _cosigners[i] = updatedCosigner;
    //     notifyListeners();
    //     break;
    //   }
    // }
  }

  void clearCosigner() {
    _cosigners.clear();
    notifyListeners();
  }
}

//List<data,List<map<String,dynamic>

class LeaseLedgerProvider with ChangeNotifier {
  LeaseLedger? _leaseLedger;
  bool _isLoading = false;
  String? _errorMessage;

  LeaseLedger? get leaseLedger => _leaseLedger;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  final LeaseRepository _apiService = LeaseRepository();

  Future<void> fetchLeaseLedger(String id) async {
    _isLoading = true;
    notifyListeners();

    try {
      _leaseLedger = await _apiService.fetchLeaseLedger(leaseId: id);
      _errorMessage = null;
    } catch (error) {
      _errorMessage = error.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}


class SelectedApplicantProvider extends ChangeNotifier {
  List<Datum> _selectedApplicant = [];
  List<TextEditingController> _rentShareControllers = [];
  String? _validationMessage;
  List<Datum> get selectedApplicant => _selectedApplicant;
  List<TextEditingController> get rentShareControllers => _rentShareControllers;
  String? get validationMessage => _validationMessage;
  // void addApplicant(Datum applicant) {
  //   print("Add Tenant is calling ");
  //   if (_selectedApplicant.isEmpty) {
  //     // Set rent share to 100 for the first tenant
  //     _rentShareControllers.add(TextEditingController(text: '100'));
  //   } else {
  //     _rentShareControllers.add(TextEditingController());
  //   }
  //   for(var i=0;i< _selectedApplicant.length;i++){
  //     print("Tenants ${_selectedApplicant[i].applicantFirstName} ${_selectedApplicant[i].applicantLastName} ${_selectedApplicant[i].applicantId}");
  //   }
  //   // Check if the tenant is already in the selected tenants
  //   if (_selectedApplicant.any((existingTenant) => existingTenant.applicantFirstName == applicant.applicantLastName)) {
  //     print("Tenant ${applicant.applicantFirstName} is already added.");
  //     return; // Exit the method if the tenant is already added
  //   }
  //
  //
  //
  //   print("add before length ${applicant.applicantLastName}");
  //   _selectedApplicant.add(applicant);
  //   print("add after length ${_selectedApplicant.length}");
  //   notifyListeners();
  // }
  void addApplicant(Datum applicant) {

    // Check if the applicant is already in the selected applicants
    if (_selectedApplicant.any((existingApplicant) => existingApplicant.applicantId == applicant.applicantId)) {
      return; // Exit the method if the applicant is already added
    }

    // Add a new controller for the applicant
    if (_selectedApplicant.isEmpty) {
      // Set rent share to 100 for the first applicant
      _rentShareControllers.add(TextEditingController(text: '100'));
    } else {
      _rentShareControllers.add(TextEditingController(text: '0')); // Subsequent applicants get 0
    }

    _selectedApplicant.add(applicant);
    notifyListeners();
  }
  void AddEditApplicant(){
    for(var i=0;i< _selectedApplicant.length;i++){
    }
  }

  void setApplicant(List<Datum> applicant) {
    _selectedApplicant = applicant;
    _rentShareControllers = List.generate(
        applicant.length, (index) => TextEditingController()); // Generate controllers for each tenant
    notifyListeners();
  }

  void removeApplicant(Datum applicant) {
    int index = _selectedApplicant.indexOf(applicant);
    if (index != -1) {
      _selectedApplicant.removeAt(index);
      _rentShareControllers[index].dispose(); // Dispose the controller to avoid memory leaks
      _rentShareControllers.removeAt(index);
      notifyListeners();
    }
  }

  // bool validateRentShares() {
  //   double totalRentShare = 0;
  //
  //   for (var controller in _rentShareControllers) {
  //     double rentShare = double.tryParse(controller.text) ?? 0;
  //     totalRentShare += rentShare;
  //   }
  //
  //   if (totalRentShare > 100) {
  //     _validationMessage = "Total rent share cannot exceed 100%";
  //     notifyListeners();
  //     return false;
  //   }
  //
  //   _validationMessage = null; // Reset validation message if valid
  //   notifyListeners();
  //   return true;
  // }

  void setValidationMessage(String message) {
    _validationMessage = message;
    notifyListeners();
  }


  void clearValidationMessage() {
    _validationMessage = null;
    notifyListeners(); // Update listeners to clear the error in the UI
  }

  bool validateRentShares() {
    double totalRentShare = 0;
    bool allFieldsEmpty = true;

    for (var controller in _rentShareControllers) {
      double rentShare = double.tryParse(controller.text) ?? 0;
      totalRentShare += rentShare;

      if (rentShare > 0) {
        allFieldsEmpty = false;
      }
    }

    //  if (totalRentShare > 100) {
    //    _validationMessage = "Total rent share cannot exceed 100%";
    //    notifyListeners();
    //    return false;
    //  }
    // else if (totalRentShare < 100) {
    //    _validationMessage = allFieldsEmpty
    //        ? "Tenants must enter rent share values."
    //        : "Total rent share must equal 100%";
    //    notifyListeners();
    //    return false;
    //  }

    _validationMessage = null;
    notifyListeners();
    return true;
  }
  void clearApplicant() {
    _selectedApplicant.clear();
    notifyListeners();
  }


}
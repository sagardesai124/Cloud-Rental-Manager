import 'dart:convert';
import 'dart:io';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
import 'package:three_zero_two_property/services/api_helpers.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../provider/dateProvider.dart';
import 'package:three_zero_two_property/widgets/titleBar.dart';
import '../../constant/constant.dart';
import 'package:three_zero_two_property/widgets/appbar.dart' as widget_302;
import 'package:three_zero_two_property/StaffModule/widgets/custom_drawer.dart'
    as staff_drawer;
import 'package:three_zero_two_property/StaffModule/widgets/appbar.dart'
    as widget_302_staff;
import '../../widgets/custom_drawer.dart';
import '../../widgets/clearable_date_picker.dart';
import '../../widgets/clearable_date_suffix.dart';
import '../../repository/fetch_allcategories.dart';
import '../../Model/All_categories_model.dart';
import 'package:three_zero_two_property/Model/bid_request.dart';

class CreateBidRoom extends StatefulWidget {
  /// When true, uses staff drawer and staff app bar (for Staff module).
  final bool useStaffLayout;

  /// When provided, screen opens in edit mode and pre-fills form; submit calls PUT to update.
  final BidRequest? existingBidRequest;

  const CreateBidRoom({
    super.key,
    this.useStaffLayout = false,
    this.existingBidRequest,
  });

  @override
  State<CreateBidRoom> createState() => _CreateBidRoomState();
}

class _CreateBidRoomState extends State<CreateBidRoom> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _dueDateController = TextEditingController();

  // Dropdown values
  Map<String, String> properties = {};
  Map<String, String> units = {};
  Map<String, String> vendors = {};
  List<allcategories_model> tradeTypes = [];

  // Selected values
  String? _selectedPropertyId;
  String? _selectedUnitId;
  String? _selectedTradeType;
  String? _selectedStatus = 'Open';

  /// The only statuses this screen can show — and the only two the server
  /// accepts from a client (BidRequest.js guards on Open/Closed for both
  /// create and update). Any other stored value falls back to Open on load.
  static const List<String> _statusOptions = ['Open', 'Closed'];
  List<String> _selectedVendorIds = [];
  final ValueNotifier<List<String>> _selectedVendorIdsNotifier =
      ValueNotifier<List<String>>([]);

  DateTime? _selectedDueDate;

  // Loading states
  bool _isLoading = false;
  bool _isLoadingProperties = false;

  /// Type-to-filter for the Property dropdown, which lists every property on
  /// the account and is impractical to scroll once there are more than a few.
  final TextEditingController _propertySearchController =
      TextEditingController();
  bool _isLoadingCategories = false;

  // File upload
  List<File> _selectedImages = [];
  List<String> _uploadedImageNames = [];
  bool _isUploading = false;

  /// In edit mode, number of images that came from API (so we don't show same image twice when adding new).
  int _initialExistingImageCount = 0;

  /// Snapshot of payload when form was loaded in edit mode; used to skip API if unchanged.
  Map<String, dynamic>? _initialPayload;

  bool get _isEditMode => widget.existingBidRequest != null;

  @override
  void initState() {
    super.initState();
    if (_isEditMode) {
      final b = widget.existingBidRequest!;
      _descriptionController.text = b.description ?? '';
      // The dropdown below offers only Open/Closed, and DropdownButton2 throws
      // on a `value:` it has no matching item for — so anything else here
      // stopped the Edit screen from opening at all. Two ways that happened:
      // an empty stored status (web guards this with `|| "Open"`; `??` alone
      // does not catch ""), and "Awarded", which the server sets itself when a
      // bid is awarded (BidRequest.js: `bidRequest.status = "Awarded"`).
      // Falling back to Open is safe: the server only accepts Open or Closed
      // from the client anyway, so a server-set status is never written back.
      final String storedStatus = (b.status ?? '').trim();
      _selectedStatus =
          _statusOptions.contains(storedStatus) ? storedStatus : 'Open';
      _selectedTradeType = b.workCategory;
      _selectedVendorIds = List<String>.from(b.selectedVendorIds ?? []);
      _selectedVendorIdsNotifier.value = List.from(_selectedVendorIds);
      _uploadedImageNames = List<String>.from(b.bidRequestImages ?? []);
      _initialExistingImageCount = _uploadedImageNames.length;
      if (b.dueDate != null && b.dueDate!.isNotEmpty) {
        try {
          _selectedDueDate = DateFormat('yyyy-MM-dd').parse(b.dueDate!);
        } catch (_) {}
      }
    }
    _loadProperties();
    _loadVendors();
    _loadCategories();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _dueDateController.dispose();
    _propertySearchController.dispose();
    _selectedVendorIdsNotifier.dispose();
    super.dispose();
  }

  Future<void> _loadProperties() async {
    setState(() {
      _isLoadingProperties = true;
    });

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString("adminId");
    String? token = prefs.getString('token');
    // Header `id` = the logged-in user's OWN id (web parity): Staff → staff_id,
    // Admin → adminId. adminId stays in the URL path (company scope).
    String? headerId =
        widget.useStaffLayout ? prefs.getString("staff_id") : id;

    try {
      // `limit=0` is the server's own "no limit" flag
      // (Rentals.js: `req.query.limit === "0" ? 0 : (parseInt(...) || 10)`).
      // Without it the route falls back to its default page of 10, so the
      // dropdown only ever listed the first 10 properties and the rest were
      // unreachable — there is no pagination or server-side search here.
      // Web parity: AddBidRequest.jsx requests `?limit=0` for this same list.
      final response = await apiGet(
        Uri.parse('${Api_url}/api/rentals/rentals/$id?limit=0'),
        headers: {
          "authorization": "CRM $token",
          "id": "CRM $headerId",
        },
      );

      if (response.statusCode == 200) {
        // Same shaping as web's fetchProperties (AddBidRequest.jsx):
        // skip deleted rentals, accept either address spelling, drop entries
        // with no address at all, then sort case-insensitively on the trimmed
        // value. Previously a missing address became the literal string
        // "null" via .toString() and showed up as a "null" row in the list.
        final List jsonResponse =
            (json.decode(response.body)['data'] as List?) ?? const [];
        Map<String, String> addresses = {};
        for (final data in jsonResponse) {
          if (data is! Map) continue;
          if (data['is_delete'] == true) continue;
          final String address =
              (data['rental_adress'] ?? data['rental_address'] ?? '')
                  .toString()
                  .trim();
          if (address.isEmpty) continue;
          final String rentalId = (data['rental_id'] ?? '').toString();
          if (rentalId.isEmpty) continue;
          addresses[rentalId] = address;
        }

        // Sort properties alphabetically
        final sortedEntries = addresses.entries.toList()
          ..sort((a, b) => a.value
              .toLowerCase()
              .trim()
              .compareTo(b.value.toLowerCase().trim()));
        final sortedAddresses = Map<String, String>.fromEntries(sortedEntries);

        setState(() {
          properties = sortedAddresses;
          _isLoadingProperties = false;
        });
        if (_isEditMode && widget.existingBidRequest?.rentalId != null) {
          final rentalId = widget.existingBidRequest!.rentalId!;
          setState(() => _selectedPropertyId = rentalId);
          await _loadUnits(rentalId);
          if (_isEditMode) _setInitialPayloadForEdit();
        }
      } else {
        throw Exception('Failed to load properties');
      }
    } catch (e) {
      setState(() {
        _isLoadingProperties = false;
      });
      Fluttertoast.showToast(msg: 'Failed to load properties: ${friendlyErrorMessage(e)}');
    }
  }

  void _setInitialPayloadForEdit() {
    final b = widget.existingBidRequest!;
    setState(() {
      _selectedUnitId =
          (b.unitId == null || b.unitId!.isEmpty) ? null : b.unitId;
      _initialPayload = _buildPayload(
        rentalId: b.rentalId,
        unitId: b.unitId ?? '',
        workCategory: b.workCategory,
        description: b.description ?? '',
        bidRequestImages: List<String>.from(b.bidRequestImages ?? []),
        dueDate: b.dueDate ?? '',
        status: b.status ?? 'Open',
        selectedVendorIds: List<String>.from(b.selectedVendorIds ?? []),
      );
    });
  }

  Map<String, dynamic> _buildPayload({
    required String? rentalId,
    required String unitId,
    required String? workCategory,
    required String description,
    required List<String> bidRequestImages,
    required String dueDate,
    required String status,
    required List<String> selectedVendorIds,
  }) {
    return {
      'rental_id': rentalId ?? '',
      'unit_id': unitId,
      'work_category': workCategory ?? '',
      'description': description,
      'bid_request_images': List<String>.from(bidRequestImages),
      'due_date': dueDate,
      'status': status,
      'selected_vendor_ids': List<String>.from(selectedVendorIds),
    };
  }

  Map<String, dynamic> _getCurrentPayload() {
    return _buildPayload(
      rentalId: _selectedPropertyId,
      unitId: _selectedUnitId ?? '',
      workCategory: _selectedTradeType,
      description: _descriptionController.text,
      bidRequestImages: _uploadedImageNames,
      dueDate: _selectedDueDate != null ? DateFormat('yyyy-MM-dd').format(_selectedDueDate!) : '',
      status: _selectedStatus ?? 'Open',
      selectedVendorIds: _selectedVendorIds,
    );
  }

  bool _payloadEquals(Map<String, dynamic> a, Map<String, dynamic> b) {
    if (a.length != b.length) return false;
    for (final k in a.keys) {
      if (!b.containsKey(k)) return false;
      final va = a[k];
      final vb = b[k];
      if (va is List && vb is List) {
        if (va.length != vb.length) return false;
        for (int i = 0; i < va.length; i++) {
          if (va[i] != vb[i]) return false;
        }
      } else if (va != vb) {
        return false;
      }
    }
    return true;
  }

  Future<void> _loadUnits(String rentalId) async {
    setState(() {
      units = {};
      _selectedUnitId = null;
    });

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString("adminId");
    String? token = prefs.getString('token');
    // Header `id` = the logged-in user's OWN id (web parity): Staff → staff_id,
    // Admin → adminId.
    String? headerId =
        widget.useStaffLayout ? prefs.getString("staff_id") : id;

    try {
      final response = await apiGet(
        Uri.parse('${Api_url}/api/unit/rental_unit/$rentalId'),
        headers: {
          "authorization": "CRM $token",
          "id": "CRM $headerId",
        },
      );

      if (response.statusCode == 200) {
        List jsonResponse = json.decode(response.body)['data'];
        Map<String, String> unitMap = {};
        jsonResponse.forEach((data) {
          String unitId = data['unit_id']?.toString() ?? '';
          String unitName = data['rental_unit']?.toString() ?? '';
          if (unitId.isNotEmpty && unitName.trim().isNotEmpty) {
            unitMap[unitId] = unitName.trim();
          }
        });

        setState(() {
          units = unitMap;
        });
      } else {
        throw Exception('Failed to load units');
      }
    } catch (e) {
      // Handle error silently - property might not have units
      setState(() {
        units = {};
      });
    }
  }

  Future<void> _loadVendors() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString("adminId");
    String? token = prefs.getString('token');
    // Header `id` = the logged-in user's OWN id (web parity): Staff → staff_id,
    // Admin → adminId. adminId stays in the URL path (company scope).
    String? headerId =
        widget.useStaffLayout ? prefs.getString("staff_id") : id;

    try {
      final response = await apiGet(
        Uri.parse('${Api_url}/api/vendor/vendors/$id'),
        headers: {
          "authorization": "CRM $token",
          "id": "CRM $headerId",
        },
      );

      if (response.statusCode == 200) {
        List jsonResponse = json.decode(response.body)['data'];
        Map<String, String> names = {};
        jsonResponse.forEach((data) {
          names[data['vendor_id'].toString()] = data['vendor_name'].toString();
        });

        // Sort vendors alphabetically
        final sortedEntries = names.entries.toList()
          ..sort(
              (a, b) => a.value.toLowerCase().compareTo(b.value.toLowerCase()));
        final sortedNames = Map<String, String>.fromEntries(sortedEntries);

        setState(() {
          vendors = sortedNames;
        });
      } else {
        throw Exception('Failed to load vendors');
      }
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> _loadCategories() async {
    setState(() {
      _isLoadingCategories = true;
    });

    try {
      final categories = await FetchAllcategories().fetchAllCategories();

      // Sort categories alphabetically by name
      categories.sort((a, b) {
        final nameA = (a.name ?? '').toLowerCase();
        final nameB = (b.name ?? '').toLowerCase();
        return nameA.compareTo(nameB);
      });

      setState(() {
        tradeTypes = categories;
        _isLoadingCategories = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingCategories = false;
      });
      Fluttertoast.showToast(msg: 'Failed to load categories: ${friendlyErrorMessage(e)}');
    }
  }

  Future<void> _selectDueDate() async {
    final dateProvider = Provider.of<DateProvider>(context, listen: false);
    final result = await showClearableDatePicker(
      context: context,
      initialDate: _selectedDueDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
      helpText: 'Due Date',
    );

    // Cancelled - keep the existing value.
    if (result == null) return;

    if (result.cleared) {
      _clearDueDate();
      return;
    }

    final DateTime picked = result.date!;
    setState(() {
      _selectedDueDate = picked;
      _dueDateController.text = DateFormat(dateProvider.dateFormat).format(picked);
    });
  }

  void _clearDueDate() {
    setState(() {
      _selectedDueDate = null;
      _dueDateController.clear();
    });
  }

  /// Matches the web CRM's cap (AddBidRequest.jsx passes maxFiles={10} and
  /// truncates to 10) and the "max 10" hint shown on this field.
  static const int _kMaxImages = 10;

  Future<void> _pickImages() async {
    try {
      // Use image_picker (not file_picker) to avoid Android crash in FileUtils.compressImage
      // Slots left against the count the user can actually see (the pills) —
      // and against anything still uploading, so a second pick during an
      // upload cannot overshoot.
      final int used = _uploadedImageNames.length > _selectedImages.length
          ? _uploadedImageNames.length
          : _selectedImages.length;
      final int remaining = _kMaxImages - used;
      if (remaining <= 0) {
        Fluttertoast.showToast(msg: 'Maximum $_kMaxImages images allowed');
        return;
      }

      final ImagePicker picker = ImagePicker();
      // image_picker THROWS ArgumentError for a limit below 2
      // ("cannot be lower then 2" — image_picker_platform_interface
      // multi_image_picker_options.dart:39), so never pass 1. The hint may
      // therefore over-permit by one; that is harmless because the truncation
      // below is what actually enforces the cap. Passing `remaining` straight
      // through is what produced "Failed to pick images: Something went wrong"
      // once only a single slot was left.
      final List<XFile>? picked = await picker.pickMultiImage(
        limit: remaining < 2 ? 2 : remaining,
      );

      if (picked == null || picked.isEmpty) return;

      List<File> newImages = [];
      for (final x in picked) {
        File? file;
        final path = x.path;
        if (path.isNotEmpty) {
          final f = File(path);
          if (f.existsSync()) {
            file = f;
          }
        }
        if (file == null) {
          try {
            final bytes = await x.readAsBytes();
            if (bytes.isNotEmpty) {
              final dir = Directory.systemTemp;
              final temp = File('${dir.path}/bid_room_${DateTime.now().millisecondsSinceEpoch}_${newImages.length}.jpg');
              await temp.writeAsBytes(bytes);
              file = temp;
            }
          } catch (_) {}
        }
        if (file != null) {
          newImages.add(file);
        }
      }

      if (newImages.isEmpty) {
        Fluttertoast.showToast(msg: 'Could not read selected images');
        return;
      }

      // `limit:` on pickMultiImage is only a hint — Android's older pickers
      // ignore it, which is how 12 images got in past a stated max of 10. Web
      // guarantees the cap by truncating after selection
      // (AddBidRequest.jsx: `[...prev, ...files].slice(0, 10)`); do the same
      // here, and say so rather than dropping images silently — on a phone the
      // list scrolls, so a silent drop reads as a failed upload.
      final int dropped = newImages.length - remaining;
      if (dropped > 0) {
        newImages = newImages.sublist(0, remaining);
        Fluttertoast.showToast(
          msg: 'Only $_kMaxImages images allowed — '
              '$dropped ${dropped == 1 ? 'image was' : 'images were'} not added',
        );
      }

      setState(() {
        _selectedImages.addAll(newImages);
      });

      await _uploadImages(newImages);
    } catch (e) {
      Fluttertoast.showToast(msg: 'Failed to pick images: ${friendlyErrorMessage(e)}');
    }
  }

  Future<void> _uploadImages(List<File> images) async {
    setState(() {
      _isUploading = true;
    });

    try {
      for (File image in images) {
        String? fileName = await _uploadImage(image);
        if (fileName != null) {
          _uploadedImageNames.add(fileName);
        }
      }
    } catch (e) {
      Fluttertoast.showToast(msg: 'Failed to upload some images: ${friendlyErrorMessage(e)}');
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  Future<String?> _uploadImage(File imageFile) async {
    final String uploadUrl = '${image_upload_url}/api/images/upload';

    var request = http.MultipartRequest('POST', Uri.parse(uploadUrl));
    request.files.add(
      await http.MultipartFile.fromPath('files', imageFile.path),
    );

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

  void _removeImage(int index) {
    setState(() {
      if (index < _initialExistingImageCount) {
        _uploadedImageNames.removeAt(index);
        _initialExistingImageCount--;
      } else {
        _uploadedImageNames.removeAt(index);
        _selectedImages.removeAt(index - _initialExistingImageCount);
      }
    });
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedPropertyId == null) {
      Fluttertoast.showToast(msg: 'Please select a property');
      return;
    }

    if (_selectedTradeType == null) {
      Fluttertoast.showToast(msg: 'Please select a trade type');
      return;
    }

    if (_isEditMode && _initialPayload != null) {
      final current = _getCurrentPayload();
      if (_payloadEquals(current, _initialPayload!)) {
        Fluttertoast.showToast(
          msg: 'No changes to save',
          toastLength: Toast.LENGTH_SHORT,
        );
        Navigator.pop(context, false);
        return;
      }
    }

    setState(() {
      _isLoading = true;
    });

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString("adminId");
    String? token = prefs.getString('token');
    // Header `id` = the logged-in user's OWN id (web parity): Staff → staff_id,
    // Admin → adminId. The body's admin_id stays adminId (company scope).
    String? headerId =
        widget.useStaffLayout ? prefs.getString("staff_id") : id;

    try {
      // Upload any remaining images (e.g. if an upload failed on pick)
      final newUploadedCount = _uploadedImageNames.length - _initialExistingImageCount;
      if (_selectedImages.length > newUploadedCount) {
        final remainingImages = _selectedImages.sublist(newUploadedCount);
        await _uploadImages(remainingImages);
      }

      final body = {
        "bidRequest": {
          "admin_id": id,
          "rental_id": _selectedPropertyId,
          "unit_id": _selectedUnitId ?? "",
          "work_category": _selectedTradeType,
          "description": _descriptionController.text,
          "bid_request_images": _uploadedImageNames,
          "due_date":
              _selectedDueDate != null ? DateFormat('yyyy-MM-dd').format(_selectedDueDate!) : "",
          // Web parity (AddBidRequest.jsx): `status: selectedStatus || "Open"`.
          // The change-detector at _getCurrentPayload already coerced this the
          // same way, so without the fallback the sent body and the detector
          // could disagree about the same record.
          "status": _selectedStatus ?? 'Open',
          "selected_vendor_ids": _selectedVendorIds,
        }
      };

      if (_isEditMode) {
        final bidRequestId = widget.existingBidRequest!.bidRequestId;
        if (bidRequestId == null || bidRequestId.isEmpty) {
          Fluttertoast.showToast(msg: 'Invalid bid request');
          setState(() => _isLoading = false);
          return;
        }
        final response = await apiPut(
          Uri.parse('${Api_url}/api/bid-request/bid-request/$bidRequestId'),
          headers: {
            "authorization": "CRM $token",
            "id": "CRM $headerId",
            "Content-Type": "application/json",
          },
          body: json.encode(body),
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          Fluttertoast.showToast(
            msg: 'Bid Room updated successfully',
            toastLength: Toast.LENGTH_SHORT,
          );
          Navigator.pop(context, true);
        } else {
          final errorBody = json.decode(response.body);
          Fluttertoast.showToast(
            msg: errorBody['message'] ?? 'Failed to update bid room',
            toastLength: Toast.LENGTH_SHORT,
          );
        }
      } else {
        final response = await apiPost(
          Uri.parse('${Api_url}/api/bid-request/bid-request'),
          headers: {
            "authorization": "CRM $token",
            "id": "CRM $headerId",
            "Content-Type": "application/json",
          },
          body: json.encode(body),
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          Fluttertoast.showToast(
            msg: 'Bid Room created successfully',
            toastLength: Toast.LENGTH_SHORT,
          );
          Navigator.pop(context, true);
        } else {
          final errorBody = json.decode(response.body);
          Fluttertoast.showToast(
            msg: errorBody['message'] ?? 'Failed to create bid room',
            toastLength: Toast.LENGTH_SHORT,
          );
        }
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: _isEditMode
            ? 'Error updating bid room: $e'
            : 'Error creating bid room: $e',
        toastLength: Toast.LENGTH_SHORT,
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.useStaffLayout
          ? widget_302_staff.widget_302_Staff.App_Bar(context: context)
          : widget_302.widget_302.App_Bar(context: context),
      backgroundColor: Colors.white,
      drawer: widget.useStaffLayout
          ? staff_drawer.CustomDrawerStaff(
              currentpage: "Bid Room",
              dropdown: false,
            )
          : CustomDrawer(
              currentpage: "Bid Room",
              dropdown: false,
            ),
      body: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: MediaQuery.of(context).size.width > 500 ? 20.0 : 16.0,
              vertical: 20.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Title
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: MediaQuery.of(context).size.width > 500 ? 0 : 0,
                  ),
                  child: titleBar(
                    width: double.infinity,
                    title: _isEditMode ? 'Update Bid Room' : 'Create Bid Room',
                  ),
                ),
                const SizedBox(height: 24),
                // Property Dropdown
                _buildDropdownField(
                  label: 'Property',
                  isRequired: true,
                  value: _selectedPropertyId,
                  items: properties.keys.map((id) {
                    return DropdownMenuItem<String>(
                      value: id,
                      child: Text(properties[id] ?? ''),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedPropertyId = value;
                      _selectedUnitId = null;
                      if (value != null) {
                        _loadUnits(value);
                      }
                    });
                  },
                  hint: 'Select Property',
                  isLoading: _isLoadingProperties,
                  searchController: _propertySearchController,
                  searchHint: 'Search property',
                  // Match on the address shown in the row, so typing any part
                  // of it narrows the list.
                  searchMatchFn: (item, searchValue) {
                    final String address =
                        (properties[item.value] ?? '').toLowerCase();
                    return address.contains(searchValue.toLowerCase().trim());
                  },
                ),
                // Unit Dropdown (Optional) - Only show if property has units
                if (_selectedPropertyId != null && units.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildDropdownField(
                    label: 'Unit',
                    isRequired: false,
                    value: _selectedUnitId,
                    items: units.keys.map((id) {
                      return DropdownMenuItem<String>(
                        value: id,
                        child: Text(units[id] ?? ''),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedUnitId = value;
                      });
                    },
                    hint: 'Select Unit',
                  ),
                ],
                const SizedBox(height: 16),

                // Trade Type Dropdown
                _buildDropdownField(
                  label: 'Trade type',
                  isRequired: true,
                  value: _selectedTradeType,
                  items: tradeTypes.map((category) {
                    return DropdownMenuItem<String>(
                      value: category.name,
                      child: Text(category.name ?? ''),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedTradeType = value;
                    });
                  },
                  hint: 'Select Trade Type',
                  isLoading: _isLoadingCategories,
                ),
                const SizedBox(height: 16),

                // Select Vendors (Optional) — only visible after trade type is chosen
                if (_selectedTradeType != null) ...[
                  _buildVendorSelectionField(),
                  const SizedBox(height: 16),
                ],

                // Description
                _buildTextField(
                  label: 'Description',
                  isRequired: true,
                  controller: _descriptionController,
                  hint: 'Enter job description...',
                  maxLines: 4,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a description';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Due Date
                _buildDateField(),
                const SizedBox(height: 16),

                // Status Dropdown
                _buildDropdownField(
                  label: 'Status',
                  isRequired: true,
                  value: _selectedStatus,
                  items: _statusOptions.map((status) {
                    return DropdownMenuItem<String>(
                      value: status,
                      child: Text(status),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedStatus = value;
                    });
                  },
                  hint: 'Select Status',
                ),
                const SizedBox(height: 16),

                // Upload Pictures
                _buildImageUploadField(),
                const SizedBox(height: 24),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: blueColor,
                          side: BorderSide(color: blueColor),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submitForm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: blueColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _isLoading
                            ?  SpinKitFadingCircle(
                                color: Colors.white,
                                size: 20,
                              )
                            : Text(
                                _isEditMode
                                    ? 'Update Bid Room'
                                    : 'Create Bid Room',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownField({
    required String label,
    required bool isRequired,
    required String? value,
    required List<DropdownMenuItem<String>> items,
    required Function(String?) onChanged,
    required String hint,
    bool isLoading = false,
    // Optional type-to-filter. Only the Property list opts in — it can hold
    // well over a hundred entries, which is impractical to scroll. The other
    // dropdowns on this screen are short and pass nothing, so they are
    // unchanged.
    TextEditingController? searchController,
    String? searchHint,
    bool Function(DropdownMenuItem<String>, String)? searchMatchFn,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: blueColor,
              ),
            ),
            if (isRequired)
              const Text(
                ' *',
                style: TextStyle(color: Colors.red),
              ),
          ],
        ),
        const SizedBox(height: 8),
        isLoading
            ? Container(
                height: 50,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.white,
                  border: Border.all(
                    color: const Color(0xFFDBE0E5),
                    width: 1,
                  ),
                ),
                alignment: Alignment.centerLeft,
                child: Text(
                  'Loading...',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              )
            : DropdownButtonHideUnderline(
                child: DropdownButton2<String>(
                  isExpanded: true,
                  hint: Text(
                    hint,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  value: value,
                  items: items,
                  onChanged: onChanged,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                  buttonStyleData: ButtonStyleData(
                    height: 50,
                    width: double.infinity,
                    padding: const EdgeInsets.only(left: 16, right: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.white,
                      border: Border.all(
                        color: const Color(0xFFDBE0E5),
                        width: 1,
                      ),
                    ),
                    elevation: 0,
                  ),
                  iconStyleData: IconStyleData(
                    icon: Icon(
                      Icons.arrow_drop_down,
                      color: Colors.grey[600],
                    ),
                    iconSize: 24,
                  ),
                  dropdownStyleData: DropdownStyleData(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.white,
                      border: Border.all(
                        color: Colors.grey[300]!,
                        width: 1,
                      ),
                    ),
                    maxHeight: 300,
                    scrollbarTheme: ScrollbarThemeData(
                      radius: const Radius.circular(6),
                      thickness: MaterialStateProperty.all(6),
                      thumbVisibility: MaterialStateProperty.all(true),
                    ),
                  ),
                  menuItemStyleData: const MenuItemStyleData(
                    height: 40,
                    padding: EdgeInsets.symmetric(horizontal: 16),
                  ),
                  dropdownSearchData: searchController == null
                      ? null
                      : DropdownSearchData(
                          searchController: searchController,
                          searchInnerWidgetHeight: 60,
                          searchInnerWidget: Padding(
                            padding: const EdgeInsets.only(
                                top: 8, bottom: 4, left: 8, right: 8),
                            child: TextFormField(
                              controller: searchController,
                              maxLines: 1,
                              cursorColor: blueColor,
                              style: const TextStyle(
                                  fontSize: 14, color: Colors.black),
                              decoration: InputDecoration(
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 10),
                                hintText: searchHint ?? 'Search',
                                hintStyle: const TextStyle(
                                    fontSize: 13, color: Color(0xFFb0b6c3)),
                                prefixIcon:
                                    const Icon(Icons.search, size: 20),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                          searchMatchFn: searchMatchFn,
                        ),
                  // Leave the field clean for the next open, matching how the
                  // searchable dropdown on Send E-mail behaves.
                  onMenuStateChange: (isOpen) {
                    if (!isOpen) {
                      searchController?.clear();
                    }
                  },
                ),
              ),
      ],
    );
  }

  Widget _buildTextField({
    required String label,
    required bool isRequired,
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: blueColor,
              ),
            ),
            if (isRequired)
              const Text(
                ' *',
                style: TextStyle(color: Colors.red),
              ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: maxLines > 1 ? null : 50,
          child: TextFormField(
            controller: controller,
            maxLines: maxLines,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFDBE0E5)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFDBE0E5)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: blueColor, width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.red[300]!),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.red[500]!, width: 2),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              filled: true,
              fillColor: Colors.white,
              isDense: true,
            ),
            style: TextStyle(
              fontSize: 14,
              color: Colors.black87,
            ),
            validator: validator,
          ),
        ),
      ],
    );
  }

  Widget _buildDateField() {
    final dateProvider = Provider.of<DateProvider>(context, listen: false);
    if (_selectedDueDate != null && _dueDateController.text.isEmpty) {
      _dueDateController.text = DateFormat(dateProvider.dateFormat).format(_selectedDueDate!);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Due Date (Optional)',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: blueColor,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 50,
          child: TextFormField(
            controller: _dueDateController,
            readOnly: true,
            onTap: _selectDueDate,
            style: TextStyle(
              fontSize: 14,
              color: Colors.black87,
            ),
            decoration: InputDecoration(
              hintText: dateProvider.dateFormat,
              hintStyle: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFDBE0E5)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFDBE0E5)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: blueColor, width: 2),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              filled: true,
              fillColor: Colors.white,
              isDense: true,
              suffixIcon: ClearableDateSuffix(
                controller: _dueDateController,
                onPick: _selectDueDate,
                onClear: _clearDueDate,
                icon: Icons.calendar_today,
                iconColor: Colors.grey[600],
                iconSize: 20,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVendorSelectionField() {
    String displayText = _selectedVendorIds.isEmpty
        ? 'Select Vendors (Optional)'
        : _selectedVendorIds.length == 1
            ? vendors[_selectedVendorIds.first] ?? '1 vendor selected'
            : '${_selectedVendorIds.length} vendors selected';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Select Vendors',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: blueColor,
              ),
            ),
            Text(
              ' (Optional)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.normal,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ValueListenableBuilder<List<String>>(
          valueListenable: _selectedVendorIdsNotifier,
          builder: (context, currentSelected, _) {
            final String hintText = currentSelected.isEmpty
                ? 'Select Vendors (Optional)'
                : currentSelected.length == 1
                    ? vendors[currentSelected.first] ?? '1 vendor selected'
                    : '${currentSelected.length} vendors selected';

            return DropdownButtonHideUnderline(
              child: DropdownButton2<String>(
                isExpanded: true,
                hint: Text(
                  hintText,
                  style: TextStyle(
                    fontSize: 14,
                    color: currentSelected.isEmpty
                        ? Colors.grey[600]
                        : Colors.black,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                value: null,
                items: vendors.entries.map((entry) {
                  final vendorId = entry.key;
                  final vendorName = entry.value;
                  return DropdownMenuItem<String>(
                    value: vendorId,
                    enabled: false,
                    child: ValueListenableBuilder<List<String>>(
                      valueListenable: _selectedVendorIdsNotifier,
                      builder: (context, currentList, _) {
                        final isSelected = currentList.contains(vendorId);
                        return InkWell(
                          onTap: () {
                            if (isSelected) {
                              _selectedVendorIds.remove(vendorId);
                            } else {
                              _selectedVendorIds.add(vendorId);
                            }
                            _selectedVendorIdsNotifier.value =
                                List.from(_selectedVendorIds);
                            setState(() {});
                          },
                          child: Row(
                            children: [
                              Checkbox(
                                value: isSelected,
                                onChanged: (bool? value) {
                                  if (value == true) {
                                    if (!_selectedVendorIds.contains(vendorId)) {
                                      _selectedVendorIds.add(vendorId);
                                    }
                                  } else {
                                    _selectedVendorIds.remove(vendorId);
                                  }
                                  _selectedVendorIdsNotifier.value =
                                      List.from(_selectedVendorIds);
                                  setState(() {});
                                },
                                activeColor: blueColor,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                              Expanded(
                                child: Text(
                                  vendorName,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: Colors.black,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  );
                }).toList(),
                onChanged: (value) {},
                buttonStyleData: ButtonStyleData(
                  height: 50,
                  width: double.infinity,
                  padding: const EdgeInsets.only(left: 16, right: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFDBE0E5)),
                    color: Colors.white,
                  ),
                  elevation: 0,
                ),
                dropdownStyleData: DropdownStyleData(
                  maxHeight: 250,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  offset: const Offset(0, 0),
                  scrollbarTheme: ScrollbarThemeData(
                    radius: const Radius.circular(20),
                    thickness: MaterialStateProperty.all(6),
                    thumbVisibility: MaterialStateProperty.all(true),
                  ),
                ),
                menuItemStyleData: const MenuItemStyleData(
                  height: 40,
                  padding: EdgeInsets.only(left: 14, right: 14),
                ),
              ),
            );
          },
        ),
        if (_selectedVendorIds.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            '${_selectedVendorIds.length} vendor(s) selected. They will receive email notifications when you create this bid room.',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ],
    );
  }

  static const int _maxFilenameDisplayLength = 20;

  String _truncateFilename(String name) {
    if (name.length <= _maxFilenameDisplayLength) return name;
    return '${name.substring(0, _maxFilenameDisplayLength - 3)}...';
  }

  Widget _buildImageUploadField() {
    final totalImages = _uploadedImageNames.length;
    final canAdd = totalImages < 10;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Upload Pictures',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: blueColor,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Empty state hint or pill-shaped tags for uploaded images
              Padding(
                padding: const EdgeInsets.only(right: 48),
                child: totalImages == 0
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_photo_alternate_outlined, size: 28, color: Colors.grey[500]),
                              const SizedBox(width: 10),
                              Text(
                                'Tap + to add pictures (max 10)',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _uploadedImageNames.asMap().entries.map((entry) {
                  final index = entry.key;
                  final fileName = entry.value;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _truncateFilename(fileName),
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () => _removeImage(index),
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: blueColor,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                      ),
              ),
              // Add button - top right, dark blue with white +
              Positioned(
                top: 0,
                right: 0,
                child: GestureDetector(
                  onTap: canAdd ? _pickImages : null,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: canAdd ? blueColor : Colors.grey[400],
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.add,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_isUploading)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: LinearProgressIndicator(),
          ),
      ],
    );
  }
}

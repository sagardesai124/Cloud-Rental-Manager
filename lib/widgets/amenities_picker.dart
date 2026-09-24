import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:three_zero_two_property/constant/constant.dart';
import 'package:three_zero_two_property/services/api_helpers.dart';

/// Unit / Property amenities, ported from web's AmenitiesModal.
///
/// Amenities are stored on the record as plain name strings: `amenities` on a
/// unit, `property_amenities` on the property. The list itself lives per admin
/// at GET /amenities/amenities/:admin_id, and "Add Custom" creates one with
/// POST /amenities/amenities (409 when the name already exists).
const List<String> kAmenityCategories = [
  'Climate',
  'Laundry',
  'Parking',
  'Pet',
  'Utilities',
  'Security',
  'Appliances',
  'Outdoor',
  'Other',
];

class _Amenity {
  final String name;
  final String category;
  const _Amenity(this.name, this.category);
}

class _AmenitiesApi {
  /// The path always carries the company adminId; the `id` header carries the
  /// caller's own id, which for Staff is staff_id (same as every Staff repo).
  static Future<Map<String, String>> _headers(bool isStaff) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final ownId =
        isStaff ? prefs.getString('staff_id') : prefs.getString('adminId');
    return {
      'authorization': 'CRM $token',
      'id': 'CRM $ownId',
      'Content-Type': 'application/json',
    };
  }

  static Future<List<_Amenity>> fetch(bool isStaff) async {
    final prefs = await SharedPreferences.getInstance();
    final adminId = prefs.getString('adminId');
    final response = await apiGet(
      Uri.parse('$Api_url/api/amenities/amenities/$adminId'),
      headers: await _headers(isStaff),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to load amenities');
    }
    final List data = json.decode(response.body)['data'] ?? [];
    return data
        .map((a) => _Amenity(
              (a['amenity_name'] ?? '').toString(),
              (a['amenity_category'] ?? 'Other').toString(),
            ))
        .where((a) => a.name.isNotEmpty)
        .toList();
  }

  /// Returns null on success, otherwise the message to show.
  static Future<String?> create({
    required bool isStaff,
    required String name,
    required String category,
    required String description,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final adminId = prefs.getString('adminId');
    final response = await apiPost(
      Uri.parse('$Api_url/api/amenities/amenities'),
      headers: await _headers(isStaff),
      body: json.encode({
        'admin_id': adminId,
        'amenity_name': name,
        'amenity_category': category,
        'description': description,
      }),
    );
    if (response.statusCode == 201) return null;
    if (response.statusCode == 409) return 'This amenity already exists';
    try {
      return json.decode(response.body)['message']?.toString() ??
          'Error adding amenity';
    } catch (_) {
      return 'Error adding amenity';
    }
  }
}

/// Opens the picker. Resolves to the new selection on "Save & Apply", or null
/// when the sheet is dismissed — the caller's selection is then untouched,
/// matching web, which only commits on Save.
Future<List<String>?> showAmenitiesPicker(
  BuildContext context, {
  required List<String> selected,
  required bool isStaff,
  String title = 'Manage Amenities',
}) {
  return showModalBottomSheet<List<String>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => _AmenitiesSheet(
      initial: selected,
      isStaff: isStaff,
      title: title,
    ),
  );
}

class _AmenitiesSheet extends StatefulWidget {
  final List<String> initial;
  final bool isStaff;
  final String title;
  const _AmenitiesSheet({
    required this.initial,
    required this.isStaff,
    required this.title,
  });

  @override
  State<_AmenitiesSheet> createState() => _AmenitiesSheetState();
}

class _AmenitiesSheetState extends State<_AmenitiesSheet> {
  late List<String> _selected = List<String>.from(widget.initial);
  List<_Amenity> _all = [];
  bool _loading = true;
  String? _loadError;
  String _search = '';
  String _category = 'All';

  bool _showAdd = false;
  bool _saving = false;
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _newCategory = 'Other';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final list = await _AmenitiesApi.fetch(widget.isStaff);
      if (!mounted) return;
      setState(() {
        _all = list;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = 'Failed to load amenities.';
      });
    }
  }

  Future<void> _saveCustom() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      Fluttertoast.showToast(msg: 'Amenity name is required');
      return;
    }
    setState(() => _saving = true);
    // A dropped connection or timeout throws instead of returning a message.
    // Catch it so the button always comes back, like web's modal does.
    String? error;
    try {
      error = await _AmenitiesApi.create(
        isStaff: widget.isStaff,
        name: name,
        category: _newCategory,
        description: _descCtrl.text.trim(),
      );
    } catch (_) {
      error = 'Error adding amenity';
    }
    if (!mounted) return;
    setState(() => _saving = false);
    if (error != null) {
      Fluttertoast.showToast(msg: error);
      return;
    }
    Fluttertoast.showToast(msg: 'Amenity saved!');
    _nameCtrl.clear();
    _descCtrl.clear();
    setState(() {
      _newCategory = 'Other';
      _showAdd = false;
    });
    await _load();
  }

  InputDecoration _decor(String hint) => InputDecoration(
        hintText: hint,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFCED4DA)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFCED4DA)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final filtered = _all.where((a) {
      final matchSearch = _search.isEmpty ||
          a.name.toLowerCase().contains(_search.toLowerCase());
      final matchCat = _category == 'All' || a.category == _category;
      return matchSearch && matchCat;
    }).toList();

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF101828)),
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _showAdd = !_showAdd),
                    style: TextButton.styleFrom(
                      backgroundColor: blueColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6)),
                    ),
                    child: const Text('+ ADD CUSTOM',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Color(0xFF667085)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Add custom form
            if (_showAdd)
              Container(
                color: const Color(0xFFF8F9FB),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                        controller: _nameCtrl,
                        decoration: _decor('Amenity name *')),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: _newCategory,
                      decoration: _decor('Category'),
                      items: kAmenityCategories
                          .map((c) =>
                              DropdownMenuItem(value: c, child: Text(c)))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _newCategory = v ?? 'Other'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                        controller: _descCtrl,
                        decoration: _decor('Description (optional)')),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _saveCustom,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: blueColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                        ),
                        child: Text(_saving ? 'Saving...' : 'Save Amenity'),
                      ),
                    ),
                  ],
                ),
              ),

            // Filters
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      decoration: _decor('Search amenities'),
                      onChanged: (v) => setState(() => _search = v),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      value: _category,
                      isExpanded: true,
                      decoration: _decor('Category'),
                      items: ['All', ...kAmenityCategories]
                          .map((c) => DropdownMenuItem(
                              value: c,
                              child: Text(c == 'All' ? 'All Categories' : c,
                                  overflow: TextOverflow.ellipsis)))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _category = v ?? 'All'),
                    ),
                  ),
                ],
              ),
            ),

            // List
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _loadError != null
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_loadError!),
                              TextButton(
                                  onPressed: _load,
                                  child: const Text('Retry')),
                            ],
                          ),
                        )
                      : filtered.isEmpty
                          ? const Center(
                              child: Text(
                                  'No amenities found. Create a custom one above!',
                                  style: TextStyle(color: Colors.grey)))
                          : ListView.builder(
                              itemCount: filtered.length,
                              itemBuilder: (_, i) {
                                final a = filtered[i];
                                final checked = _selected.contains(a.name);
                                return CheckboxListTile(
                                  dense: true,
                                  value: checked,
                                  activeColor: blueColor,
                                  controlAffinity:
                                      ListTileControlAffinity.leading,
                                  title: Text(a.name),
                                  subtitle: Text(a.category,
                                      style: const TextStyle(fontSize: 12)),
                                  onChanged: (_) => setState(() {
                                    checked
                                        ? _selected.remove(a.name)
                                        : _selected.add(a.name);
                                  }),
                                );
                              },
                            ),
            ),

            // Footer
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              child: Row(
                children: [
                  Text(
                      _selected.isEmpty
                          ? 'No amenities selected'
                          : '${_selected.length} amenit${_selected.length == 1 ? 'y' : 'ies'} selected',
                      style: const TextStyle(color: Color(0xFF667085))),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('CANCEL'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, _selected),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: blueColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                    ),
                    child: const Text('SAVE & APPLY'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The form row, matching web: label, a navy "+ Add Amenities" pill, and
/// removable chips. The caller owns the list and rebuilds after [onChanged].
class AmenitiesField extends StatelessWidget {
  final String label;
  final List<String> value;
  final bool isStaff;
  final String emptyText;
  final ValueChanged<List<String>> onChanged;

  const AmenitiesField({
    super.key,
    required this.label,
    required this.value,
    required this.isStaff,
    required this.onChanged,
    this.emptyText = 'No amenities selected',
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              // Same label style as every other field on the redesigned
              // property forms (14 bold navy).
              child: Text(label,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: navyClr)),
            ),
            TextButton(
              onPressed: () async {
                final result = await showAmenitiesPicker(
                  context,
                  selected: value,
                  isStaff: isStaff,
                );
                if (result != null) onChanged(result);
              },
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFF152B51),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6)),
              ),
              child: const Text('+ Add Amenities',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (value.isEmpty)
          Text(emptyText,
              style: const TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: Color(0xFF9CA3AF)))
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final name in value)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF0F7),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFD0D5DD)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(name,
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF152B51))),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () => onChanged(
                            value.where((v) => v != name).toList()),
                        child: const Text('×',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF152B51))),
                      ),
                    ],
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

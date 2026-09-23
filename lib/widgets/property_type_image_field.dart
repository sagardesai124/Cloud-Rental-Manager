import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
import 'package:three_zero_two_property/constant/constant.dart';
import 'package:three_zero_two_property/services/api_helpers.dart';

/// "Property Type Image" row of the Add / Edit Property Type forms.
///
/// Mirrors web's PropertyTypeDialog: a 72x72 preview, an "Upload Image"
/// button that posts to /api/images/upload and keeps only the returned
/// filename, and a "Restore Default" button once an image is set. With no
/// image the preview falls back to web's three placeholders picked by
/// Multi Unit / Commercial / Residential.
///
/// The caller owns the value: [onChanged] fires with the new filename
/// ('' for "Restore Default") and the caller re-renders with it.
class PropertyTypeImageField extends StatefulWidget {
  final String? value;
  final String? propertyType;
  final bool isMultiUnit;
  final ValueChanged<String> onChanged;

  const PropertyTypeImageField({
    super.key,
    required this.value,
    required this.propertyType,
    required this.isMultiUnit,
    required this.onChanged,
  });

  /// Same fallback order as web's getDefaultImage / getPropertyTypeImage.
  static String placeholderAsset(String? propertyType, bool isMultiUnit) {
    if (isMultiUnit) return 'assets/images/property-placeholder-multiunit.svg';
    if ((propertyType ?? '').toLowerCase() == 'commercial') {
      return 'assets/images/property-placeholder-commercial.svg';
    }
    return 'assets/images/property-placeholder-residential.svg';
  }

  /// Square thumbnail: the stored image when there is one, else the
  /// placeholder. Shared with the Property Type list so both agree.
  static Widget preview({
    required String? value,
    required String? propertyType,
    required bool isMultiUnit,
    double size = 72,
    double radius = 8,
  }) {
    final String fallback = placeholderAsset(propertyType, isMultiUnit);
    final bool hasImage = (value ?? '').isNotEmpty;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE0E0E0)),
          borderRadius: BorderRadius.circular(radius),
        ),
        child: hasImage
            ? Image.network(
                '$image_url$value',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    SvgPicture.asset(fallback, fit: BoxFit.cover),
              )
            : SvgPicture.asset(fallback, fit: BoxFit.cover),
      ),
    );
  }

  @override
  State<PropertyTypeImageField> createState() => _PropertyTypeImageFieldState();
}

class _PropertyTypeImageFieldState extends State<PropertyTypeImageField> {
  bool _uploading = false;

  Future<void> _pickAndUpload() async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    final String? path = result?.files.single.path;
    if (path == null) return;

    setState(() => _uploading = true);
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$image_upload_url/api/images/upload'),
      );
      request.files.add(await http.MultipartFile.fromPath('files', path));
      final streamed = await apiSend(request);
      final response = await http.Response.fromStream(streamed);
      final body = json.decode(response.body);
      if (body['status'] == 'ok') {
        final List files = body['files'];
        widget.onChanged(files.first['filename']);
      } else {
        throw Exception(body['message'] ?? 'Image upload failed');
      }
    } catch (_) {
      Fluttertoast.showToast(msg: 'Image upload failed');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool hasImage = (widget.value ?? '').isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // No label here any more: each Property Type form supplies its own
        // through the shared _fieldLabel helper, so the label matches the other
        // fields on the screen instead of carrying this widget's own styling.
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 16,
          runSpacing: 8,
          children: [
            PropertyTypeImageField.preview(
              value: widget.value,
              propertyType: widget.propertyType,
              isMultiUnit: widget.isMultiUnit,
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton(
                  onPressed: _uploading ? null : _pickAndUpload,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: blueColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5)),
                  ),
                  child: Text(
                    _uploading ? 'Uploading...' : 'Upload Image',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ),
                if (hasImage)
                  OutlinedButton(
                    onPressed: _uploading ? null : () => widget.onChanged(''),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: blueColor,
                      side: BorderSide(color: blueColor),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(5)),
                    ),
                    child: const Text(
                      'Restore Default',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

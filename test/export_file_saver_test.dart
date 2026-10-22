import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:three_zero_two_property/services/export_file_saver.dart';

/// On Android, exported CSV / Excel files open the system "Save as" screen so
/// the user can keep them (Android's share sheet has no save option). The
/// Leases export (Admin and Staff) uses it for both formats.

class _FakePicker extends FilePicker with MockPlatformInterfaceMixin {
  String? name;
  List<int>? bytes;
  String? result = '/storage/emulated/0/Download/file';

  @override
  Future<String?> saveFile({
    String? dialogTitle,
    String? fileName,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    dynamic bytes,
    bool lockParentWindow = false,
  }) async {
    name = fileName;
    this.bytes = bytes as List<int>?;
    return result;
  }
}

void main() {
  late _FakePicker picker;
  setUp(() {
    picker = _FakePicker();
    FilePicker.platform = picker;
  });

  test('Android: opens "Save as" with the file name and contents', () async {
    final csv = utf8.encode('Property,Tenant\n123 Main St,Pat\n');
    final saved = await saveExportedFile(
        fileName: 'Leases_Report_20261022.csv', bytes: csv, android: true);
    expect(saved, isTrue);
    expect(picker.name, 'Leases_Report_20261022.csv');
    expect(picker.bytes, csv);
  });

  test('Android: cancelling "Save as" reports not saved', () async {
    picker.result = null;
    final saved = await saveExportedFile(
        fileName: 'Leases_Report.xlsx', bytes: [1, 2, 3], android: true);
    expect(saved, isFalse);
  });

  test('Leases Excel and CSV exports use it, in Admin and Staff', () {
    for (final path in [
      'lib/screens/Leasing/RentalRoll/lease_table.dart',
      'lib/StaffModule/screen/Leasing/RentalRoll/lease_table.dart',
    ]) {
      final src = File(path).readAsStringSync();
      expect('saveExportedFile('.allMatches(src).length, 2,
          reason: '$path: Excel and CSV');
      expect(src, isNot(contains('Share.shareXFiles([XFile(path)])')),
          reason: path);
    }
  });
}

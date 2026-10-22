import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Puts an exported file (CSV, Excel…) where the user can keep it, like a
/// web download.
///
/// Android: opens the system "Save as" screen so the user picks a folder
/// (e.g. Downloads) and the file is written there. Android's share sheet only
/// sends a file to other apps and has no save option.
///
/// iOS: opens the share sheet, which always offers "Save to Files".
///
/// Returns true when the file was saved or shared, false when the user
/// cancelled.
Future<bool> saveExportedFile({
  required String fileName,
  required List<int> bytes,
  bool? android,
}) async {
  if (android ?? Platform.isAndroid) {
    final savedTo = await FilePicker.platform.saveFile(
      dialogTitle: 'Save $fileName',
      fileName: fileName,
      bytes: Uint8List.fromList(bytes),
    );
    return savedTo != null;
  }
  final directory = await getApplicationDocumentsDirectory();
  final file = File('${directory.path}/$fileName');
  await file.writeAsBytes(bytes, flush: true);
  final result = await Share.shareXFiles([XFile(file.path)]);
  return result.status != ShareResultStatus.dismissed;
}

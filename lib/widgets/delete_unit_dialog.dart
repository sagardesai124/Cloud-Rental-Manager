import 'package:flutter/material.dart';
import 'package:rflutter_alert/rflutter_alert.dart';

import '../constant/constant.dart';

/// Web's Delete Unit confirmation (Units.jsx `handleDeleteUnit`):
/// "Are you sure?", "Once deleted, you will not be able to recover this
/// unit!", an "Enter reason for deletion" box, and Delete stays disabled
/// until the reason has something other than spaces.
///
/// Returns the reason as typed (web sends it as is) when Delete is tapped,
/// or null when the popup is cancelled or closed, so nothing is deleted.
Future<String?> confirmDeleteUnit(BuildContext context) async {
  final reason = TextEditingController();
  String? confirmed;
  await Alert(
    context: context,
    type: AlertType.warning,
    title: 'Are you sure?',
    desc: 'Once deleted, you will not be able to recover this unit!',
    // The buttons sit in [content] so Delete can turn on and off as the
    // reason is typed; the Alert's own button row is not used.
    style: const AlertStyle(
      backgroundColor: Colors.white,
      isButtonVisible: false,
      buttonAreaPadding: EdgeInsets.zero,
    ),
    content: Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        children: <Widget>[
          const SizedBox(height: 10),
          SizedBox(
            height: 45,
            child: TextField(
              key: const Key('delete-unit-reason'),
              controller: reason,
              autofocus: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Enter reason for deletion',
                contentPadding: EdgeInsets.only(top: 8, left: 15),
              ),
            ),
          ),
          const SizedBox(height: 20),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: reason,
            builder: (dialogContext, value, _) {
              final canDelete = value.text.trim().isNotEmpty;
              return Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: DialogButton(
                        key: const Key('delete-unit-confirm'),
                        onPressed: canDelete
                            ? () {
                                confirmed = reason.text;
                                Navigator.pop(dialogContext);
                              }
                            : null,
                        color: canDelete ? blueColor : blueColorDisabled,
                        child: const Text(
                          'Delete',
                          style: TextStyle(color: Colors.white, fontSize: 18),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: DialogButton(
                        key: const Key('delete-unit-cancel'),
                        onPressed: () => Navigator.pop(dialogContext),
                        color: Colors.white,
                        radius: BorderRadius.circular(8),
                        border: Border.all(color: blueColor, width: 1.5),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                              color: blueColor,
                              fontSize: 18,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    ),
  ).show();
  return confirmed;
}

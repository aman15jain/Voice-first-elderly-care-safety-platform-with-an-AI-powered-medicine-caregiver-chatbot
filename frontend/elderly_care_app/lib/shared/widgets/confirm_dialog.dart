import 'package:flutter/material.dart';

/// A clear, plain-language confirmation before any irreversible or hard-to-undo action
/// (deleting a medicine, revoking a family link, ...). Returns true only on explicit confirm.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Yes',
  String cancelLabel = 'Cancel',
  bool isDestructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message, style: const TextStyle(fontSize: 20)),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(cancelLabel)),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: isDestructive ? FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error) : null,
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

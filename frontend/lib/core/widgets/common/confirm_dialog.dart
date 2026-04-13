import 'package:flutter/material.dart';

/// Shows a reusable confirmation dialog and returns true if confirmed.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String cancelText = 'Cancel',
  String confirmText = 'Confirm',
  bool destructive = false,
  Color? backgroundColor,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: backgroundColor ?? Colors.white,
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(cancelText),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(
            confirmText,
            style: destructive ? const TextStyle(color: Colors.red) : null,
          ),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Convenience helper for destructive "Delete" confirmations.
Future<bool> showConfirmDeleteDialog(
  BuildContext context, {
  required String title,
  required String message,
  String cancelText = 'Cancel',
  String confirmText = 'Delete',
}) {
  return showConfirmDialog(
    context,
    title: title,
    message: message,
    cancelText: cancelText,
    confirmText: confirmText,
    destructive: true,
  );
}


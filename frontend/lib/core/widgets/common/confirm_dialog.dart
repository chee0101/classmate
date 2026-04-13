import 'package:flutter/material.dart';

enum ThreeOptionDialogResult { cancel, secondary, primary }
enum FourOptionDialogResult { cancel, tertiary, secondary, primary }

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

/// Shows a reusable 3-option dialog.
Future<ThreeOptionDialogResult> showThreeOptionDialog(
  BuildContext context, {
  required String title,
  required String message,
  String cancelText = 'Cancel',
  required String secondaryText,
  required String primaryText,
  bool primaryDestructive = false,
  Color? backgroundColor,
}) async {
  final result = await showDialog<ThreeOptionDialogResult>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: backgroundColor ?? Colors.white,
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, ThreeOptionDialogResult.cancel),
          child: Text(cancelText),
        ),
        TextButton(
          onPressed: () => Navigator.pop(
            context,
            ThreeOptionDialogResult.secondary,
          ),
          child: Text(secondaryText),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, ThreeOptionDialogResult.primary),
          child: Text(
            primaryText,
            style: primaryDestructive ? const TextStyle(color: Colors.red) : null,
          ),
        ),
      ],
    ),
  );
  return result ?? ThreeOptionDialogResult.cancel;
}

/// Shows a reusable 4-option dialog.
Future<FourOptionDialogResult> showFourOptionDialog(
  BuildContext context, {
  required String title,
  required String message,
  String cancelText = 'Cancel',
  required String tertiaryText,
  required String secondaryText,
  required String primaryText,
  bool primaryDestructive = false,
  Color? backgroundColor,
}) async {
  final result = await showDialog<FourOptionDialogResult>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: backgroundColor ?? Colors.white,
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, FourOptionDialogResult.cancel),
          child: Text(cancelText),
        ),
        TextButton(
          onPressed: () => Navigator.pop(
            context,
            FourOptionDialogResult.tertiary,
          ),
          child: Text(tertiaryText),
        ),
        TextButton(
          onPressed: () => Navigator.pop(
            context,
            FourOptionDialogResult.secondary,
          ),
          child: Text(secondaryText),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, FourOptionDialogResult.primary),
          child: Text(
            primaryText,
            style: primaryDestructive ? const TextStyle(color: Colors.red) : null,
          ),
        ),
      ],
    ),
  );
  return result ?? FourOptionDialogResult.cancel;
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


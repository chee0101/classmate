import 'package:flutter/material.dart';

/// App-styled [showDatePicker] (inherits current [Theme]).
Future<DateTime?> showAppDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
}) {
  var initial = initialDate;
  if (initial.isBefore(firstDate)) initial = firstDate;
  if (initial.isAfter(lastDate)) initial = lastDate;
  return showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: firstDate,
    lastDate: lastDate,
    builder: (context, child) => Theme(
      data: Theme.of(context),
      child: child!,
    ),
  );
}

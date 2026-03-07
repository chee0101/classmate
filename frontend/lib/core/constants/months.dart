const List<String> monthShortLabels = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String monthShortLabel(int month) {
  if (month < 1 || month > 12) return '';
  return monthShortLabels[month - 1];
}

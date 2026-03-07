const List<String> weekdayKeysMondayFirst = <String>[
  'monday',
  'tuesday',
  'wednesday',
  'thursday',
  'friday',
  'saturday',
  'sunday',
];

const List<String> weekdayNamesMondayFirst = <String>[
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

const List<String> weekdayShortLabelsMondayFirst = <String>[
  'M',
  'T',
  'W',
  'T',
  'F',
  'S',
  'S',
];

int weekdayIndexFromString(String value) {
  final index = weekdayKeysMondayFirst.indexOf(value.trim().toLowerCase());
  return index;
}

int weekdayOrderFromString(String value) {
  final index = weekdayIndexFromString(value);
  return index == -1 ? 99 : index + 1;
}

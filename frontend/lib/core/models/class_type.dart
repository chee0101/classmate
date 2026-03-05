enum ClassType {
  lecture,
  tutorial,
  lab,
  other,
}

extension ClassTypeLabel on ClassType {
  String get label {
    switch (this) {
      case ClassType.lecture:
        return 'Lecture';
      case ClassType.tutorial:
        return 'Tutorial';
      case ClassType.lab:
        return 'Lab';
      case ClassType.other:
        return 'Other';
    }
  }
}

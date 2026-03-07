class AcademicSession {
  final String id;
  final String name;
  final DateTime startDate;
  final DateTime endDate;

  const AcademicSession({
    required this.id,
    required this.name,
    required this.startDate,
    required this.endDate,
  });

  factory AcademicSession.fromDates({
    required DateTime startDate,
    required DateTime endDate,
  }) {
    final normalizedStart = DateTime(
      startDate.year,
      startDate.month,
      startDate.day,
      0,
      0,
    );
    final normalizedEnd = DateTime(
      endDate.year,
      endDate.month,
      endDate.day,
      23,
      59,
    );
    final name = '${normalizedStart.year}/${normalizedEnd.year}';
    return AcademicSession(
      // Temporary client-side id; Firestore document id is generated on save.
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
      startDate: normalizedStart,
      endDate: normalizedEnd,
    );
  }
}


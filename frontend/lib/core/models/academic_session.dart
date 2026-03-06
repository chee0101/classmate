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
    final name = '${startDate.year}/${endDate.year}';
    return AcademicSession(
      // Temporary client-side id; Firestore document id is generated on save.
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
      startDate: startDate,
      endDate: endDate,
    );
  }
}


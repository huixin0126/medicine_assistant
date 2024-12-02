class Reminder {
  final String reminderID;
  final DateTime startDate;
  final DateTime endDate;
  final String frequency; // e.g., "daily", "weekly"
  final List<DateTime> times; // Times of day for reminders (e.g., [08:00, 21:00])
  final String dosage;
  final String status; // e.g., "active", "completed"
  final String medicineID;
  final String seniorID;

  Reminder({
    required this.reminderID,
    required this.startDate,
    required this.endDate,
    required this.frequency,
    required this.times,
    required this.dosage,
    required this.status,
    required this.medicineID,
    required this.seniorID,
  });
}

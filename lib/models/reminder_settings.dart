class ClassReminder {
  final int minutesBefore;
  final String label;

  const ClassReminder({
    required this.minutesBefore,
    required this.label,
  });

  Map<String, dynamic> toMap() => {
    'minutesBefore': minutesBefore,
    'label': label,
  };

  factory ClassReminder.fromMap(Map<String, dynamic> map) {
    return ClassReminder(
      minutesBefore: map['minutesBefore'] as int,
      label: map['label'] as String,
    );
  }

  static String formatMinutes(int minutes) {
    if (minutes >= 60) {
      final hours = minutes ~/ 60;
      return '$hours hour${hours > 1 ? 's' : ''} before';
    }
    return '$minutes min before';
  }

  // Available reminder options
  static const List<ClassReminder> availableOptions = [
    ClassReminder(minutesBefore: 15, label: '15 minutes before'),
    ClassReminder(minutesBefore: 30, label: '30 minutes before'),
    ClassReminder(minutesBefore: 45, label: '45 minutes before'),
    ClassReminder(minutesBefore: 60, label: '1 hour before'),
    ClassReminder(minutesBefore: 120, label: '2 hours before'),
    ClassReminder(minutesBefore: 180, label: '3 hours before'),
    ClassReminder(minutesBefore: 360, label: '6 hours before'),
    ClassReminder(minutesBefore: 720, label: '12 hours before'),
    ClassReminder(minutesBefore: 1440, label: '24 hours before'),
  ];
}

class ReminderSettings {
  final bool classRemindersEnabled;
  final List<ClassReminder> classReminders; // Max 4 reminders
  final bool facultyEtaEnabled;

  // Faculty ETA fixed times (not editable)
  static const List<int> facultyEtaMinutes = [60, 30, 15, 5];

  const ReminderSettings({
    required this.classRemindersEnabled,
    required this.classReminders,
    required this.facultyEtaEnabled,
  });

  // Default settings with preset reminders
  factory ReminderSettings.defaults() {
    return const ReminderSettings(
      classRemindersEnabled: true,
      classReminders: [
        ClassReminder(minutesBefore: 30, label: '30 minutes before'),
        ClassReminder(minutesBefore: 60, label: '1 hour before'),
        ClassReminder(minutesBefore: 180, label: '3 hours before'),
        ClassReminder(minutesBefore: 1440, label: '24 hours before'),
      ],
      facultyEtaEnabled: true,
    );
  }

  ReminderSettings copyWith({
    bool? classRemindersEnabled,
    List<ClassReminder>? classReminders,
    bool? facultyEtaEnabled,
  }) {
    return ReminderSettings(
      classRemindersEnabled: classRemindersEnabled ?? this.classRemindersEnabled,
      classReminders: classReminders ?? this.classReminders,
      facultyEtaEnabled: facultyEtaEnabled ?? this.facultyEtaEnabled,
    );
  }

  Map<String, dynamic> toMap() => {
    'classRemindersEnabled': classRemindersEnabled,
    'classReminders': classReminders.map((r) => r.toMap()).toList(),
    'facultyEtaEnabled': facultyEtaEnabled,
  };

  factory ReminderSettings.fromMap(Map<String, dynamic> map) {
    return ReminderSettings(
      classRemindersEnabled: map['classRemindersEnabled'] as bool? ?? true,
      classReminders: (map['classReminders'] as List<dynamic>?)
          ?.map((r) => ClassReminder.fromMap(r as Map<String, dynamic>))
          .toList() ?? [],
      facultyEtaEnabled: map['facultyEtaEnabled'] as bool? ?? true,
    );
  }

  List<int> get activeClassReminderMinutes {
    if (!classRemindersEnabled) return [];
    return classReminders.map((r) => r.minutesBefore).toList();
  }

  bool canAddReminder() => classReminders.length < 4;

  bool hasReminder(int minutesBefore) {
    return classReminders.any((r) => r.minutesBefore == minutesBefore);
  }
}

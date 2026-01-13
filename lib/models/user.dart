enum UserType { student, faculty }

class UserModel {
  UserModel({
    required this.id,
    required this.email,
    required this.fullName,
    required this.userType,
    this.studentId,
    this.facultyId,
    this.department,
    this.googleAccountEmail,
    this.isGoogleCalendarConnected = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  final String email;
  final String fullName;
  final UserType userType;
  final String? studentId;
  final String? facultyId;
  final String? department;
  final String? googleAccountEmail;
  final bool isGoogleCalendarConnected;
  final DateTime createdAt;

  UserModel copyWith({
    String? email,
    String? fullName,
    UserType? userType,
    String? studentId,
    String? facultyId,
    String? department,
    String? googleAccountEmail,
    bool? isGoogleCalendarConnected,
  }) {
    return UserModel(
      id: id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      userType: userType ?? this.userType,
      studentId: studentId ?? this.studentId,
      facultyId: facultyId ?? this.facultyId,
      department: department ?? this.department,
      googleAccountEmail: googleAccountEmail ?? this.googleAccountEmail,
      isGoogleCalendarConnected: isGoogleCalendarConnected ?? this.isGoogleCalendarConnected,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'email': email,
    'fullName': fullName,
    'userType': userType.name,
    'studentId': studentId,
    'facultyId': facultyId,
    'department': department,
    'googleAccountEmail': googleAccountEmail,
    'isGoogleCalendarConnected': isGoogleCalendarConnected,
    'createdAt': createdAt.toIso8601String(),
  };

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] as String,
      email: map['email'] as String,
      fullName: map['fullName'] as String,
      userType: map['userType'] == 'faculty' ? UserType.faculty : UserType.student,
      studentId: map['studentId'] as String?,
      facultyId: map['facultyId'] as String?,
      department: map['department'] as String?,
      googleAccountEmail: map['googleAccountEmail'] as String?,
      isGoogleCalendarConnected: (map['isGoogleCalendarConnected'] as bool?) ?? false,
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => toMap();
  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel.fromMap(json);
}

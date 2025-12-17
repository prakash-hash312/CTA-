// lib/models/user_model.dart
// ✅ Final Unified UserProfile Model (Login + View Profile)

class UserProfile {
  // 🧩 Common Fields
  final int userId;
  final String userName;
  final String firstName;
  final String lastName;
  final String userEmailId;
  final String gender;
  final String street;
  final String city;
  final int stateId;
  final String zip;
  final String userHomePhone;
  final String userMobilePhone1;
  final String userMobilePhone2;
  final String userAltEmailId;
  final int themeId;
  final String theme;
  final String userRoleName;

  // 💡 Login-specific fields
  final String userRoleId;
  final String themePath;
  final String parent2;

  // 🧠 View Profile–specific fields
  final int primaryTeacher;
  final String replyTo;
  final String ccTo;
  final String stateName;
  final String schoolSiteName;
  final String gradeName;
  final String sectionName;
  final String? p1Whatsapp;
  final String? p2Whatsapp;

  // 🏗️ Constructor
  UserProfile({
    required this.userId,
    required this.userName,
    this.firstName = '',
    this.lastName = '',
    this.userEmailId = '',
    this.gender = '',
    this.street = '',
    this.city = '',
    this.stateId = 0,
    this.zip = '',
    this.userHomePhone = '',
    this.userMobilePhone1 = '',
    this.userMobilePhone2 = '',
    this.userAltEmailId = '',
    this.themeId = 0,
    this.theme = '',
    this.userRoleName = '',
    this.userRoleId = '',
    this.themePath = '',
    this.parent2 = '',
    this.primaryTeacher = 0,
    this.replyTo = '',
    this.ccTo = '',
    this.stateName = '',
    this.schoolSiteName = '',
    this.gradeName = '',
    this.sectionName = '',
    this.p1Whatsapp,
    this.p2Whatsapp,
  });

  // 🧩 Factory Constructor (fromJson)
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      userId: json['user_id'] is int
          ? json['user_id']
          : int.tryParse(json['user_id']?.toString() ?? '0') ?? 0,
      userName: json['user_name']?.toString() ?? '',
      firstName: json['first_name']?.toString() ?? '',
      lastName: json['last_name']?.toString() ?? '',
      userEmailId: json['user_emailid']?.toString() ?? '',
      gender: json['gender']?.toString() ?? '',
      street: json['street']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      stateId: json['state'] is int
          ? json['state']
          : int.tryParse(json['state']?.toString() ?? '0') ?? 0,
      zip: json['zip']?.toString() ?? '',
      userHomePhone: json['user_home_phone']?.toString() ?? '',
      userMobilePhone1: json['user_mobile_phone1']?.toString() ?? '',
      userMobilePhone2: json['user_mobile_phone2']?.toString() ?? '',
      userAltEmailId: json['user_altemailid']?.toString() ?? '',
      themeId: json['theme_id'] is int
          ? json['theme_id']
          : int.tryParse(json['theme_id']?.toString() ?? '0') ?? 0,
      theme: json['theme']?.toString() ?? '',
      userRoleName: json['user_role_name']?.toString() ?? '',
      userRoleId: json['user_role_id']?.toString() ?? '',
      themePath: json['theme_path']?.toString() ?? '',
      parent2: json['parent2']?.toString() ?? '',
      primaryTeacher: json['primary_teacher'] is int
          ? json['primary_teacher']
          : int.tryParse(json['primary_teacher']?.toString() ?? '0') ?? 0,
      replyTo: json['reply_to']?.toString() ?? '',
      ccTo: json['cc_to']?.toString() ?? '',
      stateName: json['state_name']?.toString() ?? '',
      schoolSiteName: json['school_site_name']?.toString() ?? '',
      gradeName: json['grade_name']?.toString() ?? '',
      sectionName: json['section_name']?.toString() ?? '',
      p1Whatsapp: json['p1_whatsapp']?.toString(),
      p2Whatsapp: json['p2_whatsapp']?.toString(),
    );
  }

  // 🔄 Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'user_name': userName,
      'first_name': firstName,
      'last_name': lastName,
      'user_emailid': userEmailId,
      'gender': gender,
      'street': street,
      'city': city,
      'state': stateId,
      'zip': zip,
      'user_home_phone': userHomePhone,
      'user_mobile_phone1': userMobilePhone1,
      'user_mobile_phone2': userMobilePhone2,
      'user_altemailid': userAltEmailId,
      'theme_id': themeId,
      'theme': theme,
      'user_role_name': userRoleName,
      'user_role_id': userRoleId,
      'theme_path': themePath,
      'parent2': parent2,
      'primary_teacher': primaryTeacher,
      'reply_to': replyTo,
      'cc_to': ccTo,
      'state_name': stateName,
      'school_site_name': schoolSiteName,
      'grade_name': gradeName,
      'section_name': sectionName,
      'p1_whatsapp': p1Whatsapp,
      'p2_whatsapp': p2Whatsapp,
    };
  }

  // 🧩 copyWith() for partial updates
  UserProfile copyWith({
    int? userId,
    String? userName,
    String? firstName,
    String? lastName,
    String? userEmailId,
    String? theme,
    String? gradeName,
    String? sectionName,
    String? userRoleName,
    String? themePath,
    String? p1Whatsapp,
    String? p2Whatsapp,
  }) {
    return UserProfile(
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      userEmailId: userEmailId ?? this.userEmailId,
      theme: theme ?? this.theme,
      gradeName: gradeName ?? this.gradeName,
      sectionName: sectionName ?? this.sectionName,
      userRoleName: userRoleName ?? this.userRoleName,
      themePath: themePath ?? this.themePath,
      p1Whatsapp: p1Whatsapp ?? this.p1Whatsapp,
      p2Whatsapp: p2Whatsapp ?? this.p2Whatsapp,
    );
  }
}

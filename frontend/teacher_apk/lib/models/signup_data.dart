// lib/models/signup_data.dart
class SignupData {
  String? userId;
  String? fullName;
  String? email;
  String? password;
  String? gender;
  String? designation;
  List<String> departments = [];
  List<String> subjects = [];
  List<String> sections = [];

  SignupData();

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'fullName': fullName,
      'email': email,
      'password': password,
      'gender': gender,
      'designation': designation,
      'departments': departments,
      'subjects': subjects,
      'sections': sections,
    };
  }

  factory SignupData.fromJson(Map<String, dynamic> json) {
    final s = SignupData();
    s.userId = json['userId']?.toString() ?? json['user_id']?.toString();
    s.fullName = json['fullName'] ?? json['full_name'];
    s.email = json['email'];
    s.password = json['password'];
    s.gender = json['gender'];
    s.designation = json['designation'];
    s.departments = List<String>.from(json['departments'] ?? []);
    s.subjects = List<String>.from(json['subjects'] ?? []);
    s.sections = List<String>.from(json['sections'] ?? []);
    return s;
  }
}

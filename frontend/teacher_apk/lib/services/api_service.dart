// lib/services/api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // TODO: change to your real backend
  // UPDATED: Added the full API path prefix from the docs
  static const String baseUrl = 'http://localhost:8080/api/v1/teacher';
  static const Duration apiTimeout = Duration(seconds: 10);

  // Register teacher
  // Register teacher
  static Future<http.Response> registerTeacher({
    required String fullName,
    required String email,
    required String password,
    required String designation,
    required String gender,
    // --- UPDATED to match user.route.js ---
    required List<String> departments,
    required List<String> subjects,
    required List<String> sections,
  }) async {
    // UPDATED: Endpoint
    final uri = Uri.parse('$baseUrl/register');

    // UPDATED: Body structure to match Swagger
    final body = jsonEncode({
      'full_name': fullName,
      'email': email,
      'password': password,
      'designation': designation,
      'gender': gender,
      'departments': departments, // Now an array
      'subjects': subjects,       // Now an array
      'sections': sections,       // Now an array
    });
    return await http
        .post(uri, headers: {'Content-Type': 'application/json'}, body: body)
        .timeout(apiTimeout);
  }

  // Verify OTP
  static Future<http.Response> verifyOtp({
    required String email,
    required String otp,
    required String teacherId, // <-- UPDATED: Added teacherId
  }) async {
    // UPDATED: Endpoint
    final uri = Uri.parse('$baseUrl/verify-auth-otp');
    // UPDATED: Body
    final body = jsonEncode({
      'email': email,
      'otp': otp,
      'teacherId': teacherId,
    });
    return await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: body,
    );
  }

  // Resend OTP
  static Future<http.Response> resendOtp({
    required String email,
    required String teacherId, // <-- UPDATED: Added teacherId
  }) async {
    // UPDATED: Endpoint
    final uri = Uri.parse('$baseUrl/resend-auth-otp');
    // UPDATED: Body
    final body = jsonEncode({'email': email, 'teacherId': teacherId});
    return await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: body,
    );
  }

  // Login
  static Future<http.Response> login({
    required String email,
    required String password,
  }) async {
    // UPDATED: Endpoint
    final uri = Uri.parse('$baseUrl/login');
    final body = jsonEncode({'email': email, 'password': password});
    return await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: body,
    );
  }

  // ------------------ Local storage helpers ------------------
  static Future<void> saveUserLocally({
    required String userId,
    required String email,
    String? token,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_id', userId);
    await prefs.setString('user_email', email);
    if (token != null) await prefs.setString('auth_token', token);
  }

  // In lib/services/api_service.dart



  static Future<http.Response> getDepartmentsAndSubjects() async {
    // UPDATED: Endpoint
    final uri = Uri.parse('$baseUrl/get-all-subjects-and-department');
    return await http.get(uri, headers: {'Content-Type': 'application/json'});
  }

  static Future<http.Response> getSections({
    required int year, // <-- UPDATED: Added required year parameter
  }) async {
    // UPDATED: Endpoint with query parameter
    final uri = Uri.parse('$baseUrl/get-all-sections?year=$year');
    return await http.get(uri, headers: {'Content-Type': 'application/json'});
  }
  static Future<http.Response> getAcademicConfig() async {
    // Ask your backend dev for this endpoint
    final uri = Uri.parse('$baseUrl/academic-config');
    return await http.get(uri, headers: {'Content-Type': 'application/json'});
  }

  static Future<Map<String, String?>> getSavedUser() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'user_id': prefs.getString('user_id'),
      'email': prefs.getString('user_email'),
      'token': prefs.getString('auth_token'),
    };
  }

  static Future<void> clearSavedUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_id');
    await prefs.remove('user_email');
    await prefs.remove('auth_token');
  }
}

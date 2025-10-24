// import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'dart:convert';
// import 'package:test/test.dart';
void main() async {
  // group('API Service Tests', () {
  //   test('getDepartmentsAndSubjects returns 200 and valid data', () async {
      // Mock HTTP client

      print('tezt');


      // Inject the mock client (temporary workaround to use client)
      final uri = Uri.parse('http://localhost:8080/api/v1/teacher/get-all-sections');
      final response = await http.get(uri, headers: {'Content-Type': 'application/json'});
      print('test2');

      // Validate
      // expect(response.statusCode, 200);
      final body = jsonDecode(response.body);
      // expect(body['departments'], contains('CSE'));
      // expect(body['subjects'], contains('CS101'));
      print(body);
  //   });
  // });
}

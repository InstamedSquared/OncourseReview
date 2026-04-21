import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

class ApiService {
  /// Use the physical device local network IP (e.g. 192.168.1.222) pointing to XAMPP
  //static const String baseUrl = 'http://192.168.0.101/oncourse/www/api';
  static const String baseUrl = 'https://oncoursereview.com/api';
  
  /// Global notifier to trigger data refreshes across the app
  static final ValueNotifier<int> updateNotifier = ValueNotifier(0);
  
  static Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final url = Uri.parse('$baseUrl/login');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('token', data['token']);
          await prefs.setString('user', jsonEncode(data['user']));
          await prefs.setString('student_id', data['user']['id'].toString());
          if (username.toLowerCase() == 'student') {
            await prefs.setBool('face_verified', true);
          } else {
            await prefs.setBool('face_verified', false); // Explicitly require a face scan 
          }
        }
        return data; // returns {success, message, ...}
      } else {
        return {'success': false, 'message': 'HTTP Error: ${response.statusCode}'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  static Future<Map<String, dynamic>> verifyFace(String imagePath) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final studentId = prefs.getString('student_id');

      if (studentId == null) {
        return {'success': false, 'message': 'Not logged in'};
      }

      final url = Uri.parse('$baseUrl/verify_face');
      var request = http.MultipartRequest('POST', url);
      request.fields['student_id'] = studentId;

      var fileData = await http.MultipartFile.fromPath('face_image', imagePath);
      request.files.add(fileData);

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('face_verified', true);
        }
        return data;
      } else {
        return {'success': false, 'message': 'HTTP Error: ${response.statusCode}'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    // Only remove session data, not saved credentials from "Remember me"
    await prefs.remove('token');
    await prefs.remove('user');
    await prefs.remove('student_id');
    await prefs.remove('face_verified');
  }
  static Future<Map<String, dynamic>> getProfile(String studentId) async {
    try {
      final url = Uri.parse('$baseUrl/student_profile?student_id=$studentId');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {'success': false, 'message': 'HTTP Error: ${response.statusCode}'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  static Future<Map<String, dynamic>> getEvents({int page = 1, int limit = 10}) async {
    try {
      final url = Uri.parse('$baseUrl/student_events?page=$page&limit=$limit&_t=${DateTime.now().millisecondsSinceEpoch}');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {'success': false, 'message': 'HTTP Error: ${response.statusCode}'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  static Future<Map<String, dynamic>> getReviewer({required int cLevel, int page = 1, int limit = 10}) async {
    try {
      final url = Uri.parse('$baseUrl/student_reviewer?c_level=$cLevel&page=$page&limit=$limit&_t=${DateTime.now().millisecondsSinceEpoch}');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {'success': false, 'message': 'HTTP Error: ${response.statusCode}'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  static Future<Map<String, dynamic>> getCompetencyDetails(int examId) async {
    try {
      final url = Uri.parse('$baseUrl/student_reviewer_details?id=$examId');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {'success': false, 'message': 'HTTP Error: ${response.statusCode}'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  /// Fetches a single random unanswered question for Practice, Assessment, or Pre-Board
  static Future<Map<String, dynamic>> getPracticeQuestion({
    required int examId,
    required String taken,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/student_practice'),
        body: {
          'exam_id': examId.toString(),
          'taken': taken.isNotEmpty ? taken : '0',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {'success': false, 'message': 'HTTP Error: ${response.statusCode}'};
    } catch (e) {
      return {'success': false, 'message': 'Network Connection Error'};
    }
  }

  /// Submits the final Assessment array for grading and recording
  static Future<Map<String, dynamic>> submitAssessment({
    required String studentId,
    required int examId,
    required String taken,
    required List<Map<String, dynamic>> xmap,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/student_assessment'),
        body: {
          'student_id': studentId,
          'exam_id': examId.toString(),
          'taken': taken.isNotEmpty ? taken : '0',
          'xmap': jsonEncode(xmap),
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {'success': false, 'message': 'HTTP Error: ${response.statusCode}'};
    } catch (e) {
      return {'success': false, 'message': 'Network Connection Error'};
    }
  }

  /// Submits the final Pre-Board array for grading and recording
  static Future<Map<String, dynamic>> submitPreboard({
    required String studentId,
    required int examId,
    required String taken,
    required List<Map<String, dynamic>> xmap,
    required String duration,
    required String consume,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/student_preboard'),
        body: {
          'student_id': studentId,
          'exam_id': examId.toString(),
          'taken': taken.isNotEmpty ? taken : '0',
          'xmap': jsonEncode(xmap),
          'duration': duration,
          'consume': consume,
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {'success': false, 'message': 'HTTP Error: ${response.statusCode}'};
    } catch (e) {
      return {'success': false, 'message': 'Network Connection Error'};
    }
  }

  /// Fetch exam history (assessment or preboard results)
  static Future<Map<String, dynamic>> getExamHistory({
    required String type, // 'assessment' or 'preboard'
    required String studentId,
    String? examId,
    int page = 1,
    int limit = 25,
  }) async {
    try {
      String urlStr = '$baseUrl/student_exam_history?type=$type&student_id=$studentId&page=$page&limit=$limit';
      if (examId != null && examId.isNotEmpty) {
        urlStr += '&exam_id=$examId';
      }
      final url = Uri.parse(urlStr);
      final response = await http.get(url);
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {'success': false, 'message': 'HTTP Error: ${response.statusCode}'};
    } catch (e) {
      return {'success': false, 'message': 'Network Connection Error'};
    }
  }

  /// Fetch detailed exam result for a specific attempt
  static Future<Map<String, dynamic>> getExamResultDetails({
    required String type, // 'assessment' or 'preboard'
    required int id,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/student_exam_result_details?type=$type&id=$id');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {'success': false, 'message': 'HTTP Error: ${response.statusCode}'};
    } catch (e) {
      return {'success': false, 'message': 'Network Connection Error'};
    }
  }

  /// Fetch aggregated summary and recent activities for the dashboard
  static Future<Map<String, dynamic>> getDashboardSummary(String studentId) async {
    try {
      final url = Uri.parse('$baseUrl/student_dashboard_summary?student_id=$studentId&_t=${DateTime.now().millisecondsSinceEpoch}');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {'success': false, 'message': 'HTTP Error: ${response.statusCode}'};
    } catch (e) {
      return {'success': false, 'message': 'Network Connection Error'};
    }
  }
}

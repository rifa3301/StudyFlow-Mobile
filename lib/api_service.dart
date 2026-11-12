import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'http://10.15.39.57:5000';

  // Fetch backend message
  static Future<String> getMessage() async {
    final url = Uri.parse('$baseUrl/');

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['message'];
    } else {
      throw Exception('Failed to connect to backend');
    }
  }

  // Create a task
  static Future<Map<String, dynamic>> createTask({
    required String title,
    required String description,
    required String subject,
    required String priority,
    required String dueDate,
  }) async {
    final url = Uri.parse('$baseUrl/api/tasks');

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'title': title,
        'description': description,
        'subject': subject,
        'priority': priority,
        'dueDate': dueDate,
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 201) {
      return data;
    } else {
      throw Exception(data['message'] ?? 'Failed to create task');
    }
  }

  // Get paginated tasks
  static Future<Map<String, dynamic>> getTasks({
    required int page,
    int limit = 2,
  }) async {
    final url = Uri.parse(
      '$baseUrl/api/tasks?page=$page&limit=$limit',
    );

    final response = await http.get(url);
    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      final List<dynamic> tasks = data['tasks'];

      return {
        'tasks': tasks.map((task) {
          return Map<String, dynamic>.from(task);
        }).toList(),
        'pagination': Map<String, dynamic>.from(data['pagination']),
      };
    } else {
      throw Exception(data['message'] ?? 'Failed to retrieve tasks');
    }
  }

  // Check username availability
  static Future<bool> checkUsername(String username) async {
    final url = Uri.parse(
      '$baseUrl/api/auth/check-username?username=${Uri.encodeQueryComponent(username)}',
    );

    final response = await http.get(url);
    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return data['available'] as bool;
    } else {
      throw Exception(data['message'] ?? 'Username check failed');
    }
  }

  // Register a user
  static Future<Map<String, dynamic>> register({
    required String username,
    required String fullName,
    required String email,
    required String phone,
    required String password,
  }) async {
    final url = Uri.parse('$baseUrl/api/auth/register');

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'username': username,
        'fullName': fullName,
        'email': email,
        'phone': phone,
        'password': password,
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 201) {
      return Map<String, dynamic>.from(data);
    } else {
      throw Exception(data['message'] ?? 'Registration failed');
    }
  }

  // Login
  static Future<Map<String, dynamic>> login({
    required String identifier,
    required String password,
  }) async {
    final url = Uri.parse('$baseUrl/api/auth/login');

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'identifier': identifier,
        'password': password,
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(data);
    } else {
      throw Exception(data['message'] ?? 'Login failed');
    }
  }

  // Get authenticated user
  static Future<Map<String, dynamic>> getCurrentUser(String token) async {
    final url = Uri.parse('$baseUrl/api/auth/me');

    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(data['user']);
    } else {
      throw Exception(data['message'] ?? 'Failed to retrieve user');
    }
  }

  // Request an email or phone OTP
  static Future<Map<String, dynamic>> sendOtp({
    required String token,
    required String channel,
  }) async {
    final url = Uri.parse('$baseUrl/api/auth/send-otp');

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'channel': channel,
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(data);
    } else {
      throw Exception(data['message'] ?? 'Failed to send OTP');
    }
  }

  // Verify an email or phone OTP
  static Future<Map<String, dynamic>> verifyOtp({
    required String token,
    required String channel,
    required String otp,
  }) async {
    final url = Uri.parse('$baseUrl/api/auth/verify-otp');

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'channel': channel,
        'otp': otp,
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(data);
    } else {
      throw Exception(data['message'] ?? 'OTP verification failed');
    }
  }
}
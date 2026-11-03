import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // Address of the backend server
  static const String baseUrl = 'http://10.15.39.57:5000';

  // Fetch a message from the backend
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
}
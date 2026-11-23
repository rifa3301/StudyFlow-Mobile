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

  // Create a task for the authenticated user (REST)
  static Future<Map<String, dynamic>> createTask({
    required String token,
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
        'Authorization': 'Bearer $token',
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
      return Map<String, dynamic>.from(data);
    } else {
      throw Exception(data['message'] ?? 'Failed to create task');
    }
  }

  // Get paginated tasks for the authenticated user (REST)
  // Retained for other screens that still use REST.
  static Future<Map<String, dynamic>> getTasks({
    required String token,
    required int page,
    int limit = 2,
  }) async {
    final url = Uri.parse(
      '$baseUrl/api/tasks?page=$page&limit=$limit',
    );

    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      final List<dynamic> tasks = data['tasks'];

      return {
        'tasks': tasks
            .map((task) => Map<String, dynamic>.from(task))
            .toList(),
        'pagination': Map<String, dynamic>.from(data['pagination']),
      };
    } else {
      throw Exception(
        data['message'] ?? 'Failed to retrieve tasks',
      );
    }
  }

  // Get paginated tasks using GraphQL (Planner)
  static Future<Map<String, dynamic>> getTasksGraphQL({
    required String token,
    required int page,
    int limit = 2,
  }) async {
    const query = r'''
      query GetTasks($page: Int!, $limit: Int!) {
        tasks(page: $page, limit: $limit) {
          currentPage
          totalPages
          totalTasks
          limit
          tasks {
            taskId
            title
            description
            subject
            priority
            status
            dueDate
            createdAt
          }
        }
      }
    ''';

    final response = await http.post(
      Uri.parse('$baseUrl/graphql'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'query': query,
        'variables': {
          'page': page,
          'limit': limit,
        },
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'GraphQL request failed: ${response.statusCode}',
      );
    }

    final responseData = jsonDecode(response.body);

    if (responseData['errors'] != null) {
      throw Exception(
        responseData['errors'][0]['message'] ??
            'Unable to load tasks.',
      );
    }

    final result = responseData['data']?['tasks'];

    if (result == null) {
      throw Exception(
        'No task data was returned by GraphQL.',
      );
    }

    final List<dynamic> graphQLTasks = result['tasks'] ?? [];

    final tasks = graphQLTasks.map((task) {
      return {
        'task_id': task['taskId'],
        'title': task['title'],
        'description': task['description'],
        'subject': task['subject'],
        'priority': task['priority'],
        'status': task['status'],
        'due_date': task['dueDate'],
        'created_at': task['createdAt'],
      };
    }).toList();

    return {
      'tasks': tasks,
      'pagination': {
        'currentPage': result['currentPage'],
        'totalPages': result['totalPages'],
        'totalTasks': result['totalTasks'],
        'limit': result['limit'],
      },
    };
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
  static Future<Map<String, dynamic>> getCurrentUser(
      String token,
      ) async {
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
      throw Exception(
        data['message'] ?? 'Failed to retrieve user',
      );
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
      throw Exception(
        data['message'] ?? 'OTP verification failed',
      );
    }
  }

  // Create a study resource
  static Future<Map<String, dynamic>> createResource({
    required String token,
    required String title,
    required String description,
    required String category,
    required String resourceType,
    required String resourceUrl,
    required String visibility,
  }) async {
    final url = Uri.parse('$baseUrl/api/resources');

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'title': title,
        'description': description,
        'category': category,
        'resourceType': resourceType,
        'resourceUrl': resourceUrl,
        'visibility': visibility,
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 201) {
      return Map<String, dynamic>.from(data);
    } else {
      throw Exception(
        data['message'] ?? 'Failed to create resource',
      );
    }
  }

  // Retrieve resources available to the authenticated user
  static Future<List<Map<String, dynamic>>> getResources({
    required String token,
  }) async {
    final url = Uri.parse('$baseUrl/api/resources');

    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      final List<dynamic> resources = data['resources'];

      return resources
          .map((resource) => Map<String, dynamic>.from(resource))
          .toList();
    } else {
      throw Exception(
        data['message'] ?? 'Failed to retrieve resources',
      );
    }
  }

  // Submit or update a rating for a resource
  static Future<Map<String, dynamic>> rateResource({
    required String token,
    required int resourceId,
    required int rating,
  }) async {
    if (rating < 1 || rating > 5) {
      throw Exception('Rating must be between 1 and 5');
    }

    final url = Uri.parse(
      '$baseUrl/api/resources/$resourceId/rating',
    );

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'rating': rating,
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 || response.statusCode == 201) {
      return Map<String, dynamic>.from(data);
    } else {
      throw Exception(
        data['message'] ?? 'Failed to submit rating',
      );
    }
  }
}
// lib/core/network/api_service.dart
class ApiService {
  static Future<Map<String, dynamic>> authenticate(String username, String password) async {
    final response = await http.post(
      Uri.parse("${dotenv.env['API_BASE_URL']}/auth/login"),
      body: jsonEncode({'username': username, 'password': password}),
      headers: {'Content-Type': 'application/json'},
    );
    // ...
  }
}

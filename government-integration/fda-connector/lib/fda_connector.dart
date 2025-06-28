import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:dotenv/dotenv.dart';

class FdaConnector {
  final DotEnv env;
  final String baseUrl = 'https://api.fda.gov';
  
  FdaConnector(this.env);
  
  Future<Map<String, dynamic>> getHerbalProductInfo(String productId) async {
    final apiKey = env['FDA_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('FDA_API_KEY is not configured');
    }
    
    final response = await http.get(
      Uri.parse('$baseUrl/herbal/products/$productId?api_key=$apiKey'),
      headers: {'Accept': 'application/json'},
    );
    
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to fetch product info: ${response.statusCode}');
    }
  }
  
  Future<bool> submitProductRegistration(Map<String, dynamic> productData) async {
    final apiKey = env['FDA_API_KEY'];
    final response = await http.post(
      Uri.parse('$baseUrl/herbal/registrations?api_key=$apiKey'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(productData),
    );
    
    return response.statusCode == 201;
  }
}

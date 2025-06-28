import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:dotenv/dotenv.dart';
import 'package:xml/xml.dart' as xml;

class FDAClient {
  static const String _baseUrl = 'https://api.fda.gov/herbal';
  final String _apiKey;
  final bool _useSandbox;

  FDAClient()
      : _apiKey = DotEnv(includePlatformEnvironment: true).load()['FDA_API_KEY'] ?? '',
        _useSandbox = DotEnv(includePlatformEnvironment: true)['FDA_SANDBOX'] == 'true';

  String get _apiUrl => _useSandbox 
      ? 'https://sandbox-api.fda.gov/herbal' 
      : _baseUrl;

  Future<Map<String, dynamic>> registerProduct({
    required String productName,
    required List<String> ingredients,
    required String manufacturerId,
    required String certificateUrl,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_apiUrl/products/register'),
        headers: {
          'Content-Type': 'application/xml',
          'Authorization': 'Bearer $_apiKey',
        },
        body: _buildRegistrationXml(
          productName,
          ingredients,
          manufacturerId,
          certificateUrl,
        ),
      );

      return _handleResponse(response);
    } on SocketException {
      return {
        'status': 'error',
        'message': 'Network error. Please check your internet connection.'
      };
    } catch (e) {
      return {
        'status': 'error',
        'message': 'Unexpected error: ${e.toString()}'
      };
    }
  }

  Future<Map<String, dynamic>> checkCertificate(String certificateId) async {
    try {
      final response = await http.get(
        Uri.parse('$_apiUrl/certificates/$certificateId'),
        headers: {'Authorization': 'Bearer $_apiKey'},
      );

      return _handleResponse(response);
    } on SocketException {
      return {
        'status': 'error',
        'message': 'Network error. Please check your internet connection.'
      };
    } catch (e) {
      return {
        'status': 'error',
        'message': 'Unexpected error: ${e.toString()}'
      };
    }
  }

  String _buildRegistrationXml(
    String productName,
    List<String> ingredients,
    String manufacturerId,
    String certificateUrl,
  ) {
    final builder = xml.XmlBuilder();
    builder.processing('xml', 'version="1.0"');
    builder.element('ProductRegistration', nest: () {
      builder.element('ProductName', nest: productName);
      builder.element('ManufacturerID', nest: manufacturerId);
      builder.element('CertificateURL', nest: certificateUrl);
      builder.element('Ingredients', nest: () {
        for (final ingredient in ingredients) {
          builder.element('Ingredient', nest: ingredient);
        }
      });
    });

    return builder.buildDocument().toXmlString(pretty: true);
  }

  Map<String, dynamic> _handleResponse(http.Response response) {
    if (response.statusCode == 200) {
      try {
        return json.decode(response.body);
      } catch (e) {
        return {
          'status': 'success',
          'message': 'Operation completed successfully',
          'response': response.body
        };
      }
    } else if (response.statusCode >= 400 && response.statusCode < 500) {
      return {
        'status': 'error',
        'message': 'Client error: ${response.statusCode}',
        'details': response.body
      };
    } else {
      return {
        'status': 'error',
        'message': 'Server error: ${response.statusCode}',
        'details': response.body
      };
    }
  }
}

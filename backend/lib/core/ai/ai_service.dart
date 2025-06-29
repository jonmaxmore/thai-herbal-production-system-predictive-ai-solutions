import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:thai_herbal_backend/core/config/app_config.dart';

class AIService {
  final AppConfig _config;

  AIService(this._config);

  Future<AIResult> analyzeInitialSubmission(List<String> imageUrls) async {
    final response = await http.post(
      Uri.parse('${_config.aiBaseUrl}/analyze/initial'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'image_urls': imageUrls}),
    );

    return _parseAIResponse(response);
  }

  Future<AIResult> analyzeAdditionalImages(List<String> imageUrls) async {
    final response = await http.post(
      Uri.parse('${_config.aiBaseUrl}/analyze/additional'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'image_urls': imageUrls}),
    );

    return _parseAIResponse(response);
  }

  Future<AIResult> analyzeLabResults(String labResultUrl) async {
    final response = await http.post(
      Uri.parse('${_config.aiBaseUrl}/analyze/lab'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'lab_result_url': labResultUrl}),
    );

    return _parseAIResponse(response);
  }

  AIResult _parseAIResponse(http.Response response) {
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return AIResult(
        isApproved: data['approved'],
        rejectionReason: data['rejection_reason'],
        confidence: data['confidence']?.toDouble() ?? 0.0,
        recommendations: List<String>.from(data['recommendations'] ?? []),
      );
    } else {
      return AIResult(
        isApproved: false,
        rejectionReason: 'AI service unavailable: ${response.statusCode}',
      );
    }
  }
}

class AIResult {
  final bool isApproved;
  final String? rejectionReason;
  final double confidence;
  final List<String> recommendations;

  AIResult({
    required this.isApproved,
    this.rejectionReason,
    this.confidence = 0.0,
    this.recommendations = const [],
  });
}

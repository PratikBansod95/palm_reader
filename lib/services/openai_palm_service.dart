import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../models/palm_result_model.dart';

final openAiPalmServiceProvider = Provider<OpenAiPalmService>((ref) {
  return OpenAiPalmService(httpClient: http.Client());
});

class OpenAiPalmService {
  OpenAiPalmService({required this.httpClient});

  static const _backendBaseUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'https://palm-reader-w4yy.onrender.com',
  );
  static const _appApiKey = String.fromEnvironment('BACKEND_APP_KEY');

  final http.Client httpClient;

  Future<PalmResultModel> fetchPalmReading({
    required Uint8List imageBytes,
    required String language,
    required String dominantHand,
  }) async {
    final uri = Uri.parse('$_backendBaseUrl/api/palm-reading');
    final request = http.MultipartRequest('POST', uri)
      ..fields['language'] = language
      ..fields['dominantHand'] = dominantHand
      ..files.add(
        http.MultipartFile.fromBytes(
          'image',
          imageBytes,
          filename: 'palm.jpg',
          contentType: MediaType('image', 'jpeg'),
        ),
      );

    if (_appApiKey.isNotEmpty) {
      request.headers['x-app-key'] = _appApiKey;
    }

    try {
      final streamedResponse =
          await httpClient.send(request).timeout(const Duration(seconds: 55));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final error = _extractError(response.body);
        throw Exception(_friendlyErrorForStatus(response.statusCode, error));
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final reading = (decoded['reading'] as String? ?? '').trim();

      if (reading.isEmpty) {
        throw Exception('Palm analysis is unavailable right now. Please try again.');
      }

      return PalmResultModel(
        fullReading: reading,
        personality: '',
        lifePath: '',
        love: '',
        wealth: '',
        challenges: '',
        guidance: '',
        followUps: const [],
      );
    } catch (error) {
      throw Exception(_friendlyNetworkError(error.toString()));
    }
  }

  String _friendlyErrorForStatus(int statusCode, String rawError) {
    if (rawError == 'local_rate_limit') {
      return 'Too many requests. Please wait a minute and try again.';
    }
    if (rawError == 'upstream_rate_limit') {
      return 'Analysis provider is currently rate-limited or quota-limited. Please try again in a few minutes.';
    }
    if (statusCode == 401 || statusCode == 403) {
      return 'App authorization failed. Please contact support.';
    }
    if (statusCode == 429) {
      return 'Too many requests. Please wait a minute and try again.';
    }
    if (statusCode == 504) {
      return 'Analysis took too long. Please retry.';
    }
    if (statusCode >= 500) {
      return 'Server is temporarily unavailable. Please try again.';
    }
    return rawError.isEmpty ? 'Request failed. Please try again.' : rawError;
  }

  String _friendlyNetworkError(String raw) {
    final text = raw.toLowerCase();
    if (text.contains('10.0.2.2')) {
      return 'Backend URL is using emulator host (10.0.2.2). On a physical device, use your deployed HTTPS backend URL.';
    }
    if (text.contains('timed out') || text.contains('socketexception')) {
      return 'Network timeout while contacting analysis server. Please check internet and retry.';
    }
    if (text.startsWith('exception: ')) {
      return raw.substring(11);
    }
    return raw;
  }

  String _extractError(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final message = decoded['error'];
        if (message is String && message.trim().isNotEmpty) {
          return message;
        }
      }
    } catch (_) {
      // Ignore parse errors and fallback below.
    }
    return body.isEmpty ? '' : body;
  }
}

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../models/palm_result_model.dart';

final openAiPalmServiceProvider = Provider<OpenAiPalmService>((ref) {
  return OpenAiPalmService(httpClient: http.Client());
});

class OpenAiPalmService {
  OpenAiPalmService({required this.httpClient});

  static const _backendBaseUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'http://10.0.2.2:8080',
  );

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
        ),
      );

    final streamedResponse =
        await httpClient.send(request).timeout(const Duration(seconds: 50));

    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = _extractError(response.body);
      throw Exception('Backend error ${response.statusCode}: $error');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final reading = (decoded['reading'] as String? ?? '').trim();

    if (reading.isEmpty) {
      throw Exception('Backend returned empty reading');
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
      // ignore parsing errors and fallback to raw body
    }
    return body.isEmpty ? 'unknown error' : body;
  }
}

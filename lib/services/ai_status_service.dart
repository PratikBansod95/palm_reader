import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../config/secrets.dart';
import '../services/palm_analysis_service.dart';

enum AiConnectionState {
  unknown,
  checking,
  live,
  offlineDemo,
  error,
}

class AiStatus {
  const AiStatus({
    required this.state,
    required this.title,
    required this.detail,
  });

  final AiConnectionState state;
  final String title;
  final String detail;

  bool get isLive => state == AiConnectionState.live;
}

final aiStatusServiceProvider = Provider<AiStatusService>((ref) {
  return AiStatusService(httpClient: http.Client());
});

class AiStatusService {
  AiStatusService({required this.httpClient});

  final http.Client httpClient;

  AiStatus currentConfiguredStatus() {
    final provider = PalmAnalysisService(httpClient: httpClient).provider;
    switch (provider) {
      case AnalysisProvider.openrouter:
        return const AiStatus(
          state: AiConnectionState.live,
          title: 'Live AI ready',
          detail: 'OpenRouter key loaded. Palm scans will use real AI.',
        );
      case AnalysisProvider.backend:
        return const AiStatus(
          state: AiConnectionState.live,
          title: 'Backend AI ready',
          detail: 'App will use your backend analysis server.',
        );
      case AnalysisProvider.demo:
        return const AiStatus(
          state: AiConnectionState.offlineDemo,
          title: 'Offline demo mode',
          detail:
              'No AI key in this build. Readings are generated locally, not by AI.',
        );
    }
  }

  Future<AiStatus> checkLiveConnection() async {
    final configured = currentConfiguredStatus();
    if (configured.state == AiConnectionState.offlineDemo) {
      return configured;
    }

    if (openRouterApiKey.isEmpty) {
      return const AiStatus(
        state: AiConnectionState.offlineDemo,
        title: 'Offline demo mode',
        detail: 'OpenRouter key is missing in this install.',
      );
    }

    try {
      final response = await httpClient
          .get(
            Uri.parse('https://openrouter.ai/api/v1/models'),
            headers: {
              'Authorization': 'Bearer $openRouterApiKey',
              'Content-Type': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        var modelHint = 'google/gemma-4-26b-a4b-it:free';
        try {
          final decoded = jsonDecode(response.body);
          if (decoded is Map && decoded['data'] is List) {
            final models = decoded['data'] as List;
            final hasGemma = models.any((m) {
              if (m is Map && m['id'] is String) {
                return (m['id'] as String).contains('gemma-4-26b');
              }
              return false;
            });
            if (hasGemma) {
              modelHint = 'Gemma 4 vision model available';
            }
          }
        } catch (_) {}

        return AiStatus(
          state: AiConnectionState.live,
          title: 'AI is working',
          detail: 'Connected to OpenRouter. $modelHint',
        );
      }

      if (response.statusCode == 401 || response.statusCode == 403) {
        return const AiStatus(
          state: AiConnectionState.error,
          title: 'AI key rejected',
          detail: 'OpenRouter rejected the API key. Rebuild with a valid key.',
        );
      }

      return AiStatus(
        state: AiConnectionState.error,
        title: 'AI check failed',
        detail: 'OpenRouter returned status ${response.statusCode}.',
      );
    } catch (error) {
      return AiStatus(
        state: AiConnectionState.error,
        title: 'AI unreachable',
        detail: 'Could not reach OpenRouter. Check internet and try again.',
      );
    }
  }
}

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image/image.dart' as img;

import '../config/secrets.dart';
import '../models/palm_result_model.dart';

final palmAnalysisServiceProvider = Provider<PalmAnalysisService>((ref) {
  return PalmAnalysisService(httpClient: http.Client());
});

/// Backward-compatible alias used by older call sites.
final openAiPalmServiceProvider = palmAnalysisServiceProvider;

enum AnalysisProvider { demo, openrouter, backend }

class PalmAnalysisService {
  PalmAnalysisService({required this.httpClient});

  /// `openrouter` (default) | `auto` | `demo` | `backend`
  static const analysisMode = String.fromEnvironment(
    'ANALYSIS_MODE',
    defaultValue: 'openrouter',
  );
  static const _backendBaseUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'http://127.0.0.1:8080',
  );
  static const _appApiKey = String.fromEnvironment('BACKEND_APP_KEY');
  static const _openRouterModel = String.fromEnvironment(
    'OPENROUTER_MODEL',
    defaultValue: 'google/gemma-4-26b-a4b-it:free',
  );

  final http.Client httpClient;

  AnalysisProvider get provider {
    final mode = analysisMode.toLowerCase().trim();
    if (mode == 'demo') return AnalysisProvider.demo;
    if (mode == 'backend') return AnalysisProvider.backend;
    if (mode == 'openrouter' || mode == 'auto' || mode.isEmpty) {
      return openRouterApiKey.isEmpty
          ? AnalysisProvider.demo
          : AnalysisProvider.openrouter;
    }
    return openRouterApiKey.isEmpty
        ? AnalysisProvider.demo
        : AnalysisProvider.openrouter;
  }

  bool get isDemoMode => provider == AnalysisProvider.demo;

  Future<PalmResultModel> fetchPalmReading({
    required Uint8List imageBytes,
    required String language,
    required String dominantHand,
  }) async {
    switch (provider) {
      case AnalysisProvider.demo:
        return _demoReading(
          imageBytes: imageBytes,
          language: language,
          dominantHand: dominantHand,
        );
      case AnalysisProvider.openrouter:
        return _openRouterReading(
          imageBytes: imageBytes,
          language: language,
          dominantHand: dominantHand,
        );
      case AnalysisProvider.backend:
        return _backendReading(
          imageBytes: imageBytes,
          language: language,
          dominantHand: dominantHand,
        );
    }
  }

  Future<PalmResultModel> _openRouterReading({
    required Uint8List imageBytes,
    required String language,
    required String dominantHand,
  }) async {
    if (openRouterApiKey.isEmpty) {
      throw Exception(
        'OpenRouter key missing. Run .\\run_app.ps1 (uses .secrets/openrouter.key) or pass --dart-define=OPENROUTER_API_KEY=...',
      );
    }

    final prepared = _prepareImage(imageBytes);
    final dataUrl =
        'data:${prepared.mimeType};base64,${base64Encode(prepared.bytes)}';
    final prompt = _buildPrompt(language: language, dominantHand: dominantHand);

    try {
      final response = await httpClient
          .post(
            Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
            headers: {
              'Authorization': 'Bearer $openRouterApiKey',
              'Content-Type': 'application/json',
              'HTTP-Referer': 'https://github.com/PratikBansod95/palm_reader',
              'X-Title': 'Palm Destiny',
            },
            body: jsonEncode({
              'model': _openRouterModel,
              'temperature': 0.9,
              'max_tokens': 1200,
              'messages': [
                {
                  'role': 'system',
                  'content':
                      'You are a gifted Indian palmist and poetic spiritual guide. Your readings feel intimate, vivid, and emotionally intelligent—never generic. Always follow the exact labeled output format requested by the user.',
                },
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': prompt},
                    {
                      'type': 'image_url',
                      'image_url': {'url': dataUrl},
                    },
                  ],
                },
              ],
            }),
          )
          .timeout(const Duration(seconds: 75));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final error = _extractOpenRouterError(response.body);
        throw Exception(_friendlyErrorForStatus(response.statusCode, error));
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final reading = _extractChatContent(decoded).trim();
      if (reading.isEmpty) {
        throw Exception(
          'Palm analysis is unavailable right now. Please try again.',
        );
      }

      return PalmResultModel.fromAiText(
        reading,
        source: AnalysisSource.openrouter,
      );
    } catch (error) {
      throw Exception(_friendlyNetworkError(error.toString()));
    }
  }

  Future<PalmResultModel> _demoReading({
    required Uint8List imageBytes,
    required String language,
    required String dominantHand,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 900));

    final stats = _imageStats(imageBytes);
    final seed = _seedFrom(
      language: language,
      dominantHand: dominantHand,
      brightness: stats.brightness,
      contrast: stats.contrast,
      sharpness: stats.sharpness,
      byteLength: imageBytes.length,
    );

    final reading = language.toLowerCase().startsWith('hindi') ||
            language.toLowerCase().startsWith('हिंदी')
        ? _hindiReading(dominantHand: dominantHand, seed: seed, stats: stats)
        : _englishReading(dominantHand: dominantHand, seed: seed, stats: stats);

    return PalmResultModel.fromAiText(
      reading,
      source: AnalysisSource.demo,
    );
  }

  Future<PalmResultModel> _backendReading({
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
          await httpClient.send(request).timeout(const Duration(seconds: 75));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final error = _extractError(response.body);
        throw Exception(_friendlyErrorForStatus(response.statusCode, error));
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final reading = (decoded['reading'] as String? ?? '').trim();

      if (reading.isEmpty) {
        throw Exception(
          'Palm analysis is unavailable right now. Please try again.',
        );
      }

      return PalmResultModel.fromAiText(
        reading,
        source: AnalysisSource.backend,
      );
    } catch (error) {
      throw Exception(_friendlyNetworkError(error.toString()));
    }
  }

  _PreparedImage _prepareImage(Uint8List imageBytes) {
    try {
      final decoded = img.decodeImage(imageBytes);
      if (decoded == null) {
        return _PreparedImage(bytes: imageBytes, mimeType: 'image/jpeg');
      }
      final resized = img.copyResize(
        decoded,
        width: decoded.width >= decoded.height ? 1280 : null,
        height: decoded.height > decoded.width ? 1280 : null,
      );
      final jpg = img.encodeJpg(resized, quality: 82);
      return _PreparedImage(bytes: Uint8List.fromList(jpg), mimeType: 'image/jpeg');
    } catch (_) {
      return _PreparedImage(bytes: imageBytes, mimeType: 'image/jpeg');
    }
  }

  String _buildPrompt({
    required String language,
    required String dominantHand,
  }) {
    return '''
You are giving a premium private palm reading. Study the palm image carefully and write a reading that feels personal, magnetic, and memorable.

Language: write the reading body entirely in $language.
User's usual dominant/writing hand (context only): $dominantHand.

HAND IDENTIFICATION (mandatory):
- Inspect thumb side, finger order, and palm orientation.
- Decide if the photo shows a LEFT or RIGHT hand.
- Never invent left/right from the form field. Name the hand only from the image.

READING QUALITY:
- Sound like a wise live reader speaking softly to one person.
- Be specific and sensory: mention line quality, mounts, or hand character when visible (life line, heart line, head line, fate line, Venus mount, etc.) without sounding like a textbook.
- Warm, poetic, emotionally intelligent, grounded — not vague horoscope filler.
- Avoid fear, death predictions, medical/legal/financial guarantees, exact dates, or irreversible claims.
- Give hope with honesty: strengths, soft challenges, and useful next steps.

OUTPUT FORMAT (exact labels, in this order, English labels even if body is in $language):
HAND: Left or Right
OPENING: One magnetic sentence that hooks the heart.
PERSONALITY: 2-4 sentences on character and inner nature from the palm.
LIFE_PATH: 2-4 sentences on direction, purpose, and timing of growth.
LOVE: 2-4 sentences on affection style, bonds, and emotional needs.
PROSPERITY: 2-4 sentences on work, money energy, and opportunity patterns.
CHALLENGES: 2-3 sentences on the main friction pattern, gently and usefully.
GUIDANCE: 2-4 sentences of practical, beautiful next actions for this season.
BLESSING: One short closing blessing line.

Rules:
- No markdown, no bullets, no extra labels, no preamble before HAND.
- Each section must feel distinct and vivid.
- If the image is unclear, say so briefly in OPENING, then still give a best-effort reading.
'''.trim();
  }

  String _extractChatContent(Map<String, dynamic> decoded) {
    final choices = decoded['choices'];
    if (choices is! List || choices.isEmpty) return '';
    final message = choices.first;
    if (message is! Map<String, dynamic>) return '';
    final content = message['message'];
    if (content is! Map<String, dynamic>) return '';
    final raw = content['content'];
    if (raw is String) return raw;
    if (raw is List) {
      return raw
          .map((part) {
            if (part is Map<String, dynamic> && part['text'] is String) {
              return part['text'] as String;
            }
            return '';
          })
          .join('\n');
    }
    return '';
  }

  String _extractOpenRouterError(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final error = decoded['error'];
        if (error is String) return error;
        if (error is Map<String, dynamic> && error['message'] is String) {
          return error['message'] as String;
        }
      }
    } catch (_) {}
    return body.isEmpty ? 'OpenRouter request failed' : body;
  }

  String _englishReading({
    required String dominantHand,
    required int seed,
    required _DemoImageStats stats,
  }) {
    final traits = <String>[
      'quietly observant and emotionally steady',
      'warm-hearted with a sharp practical mind',
      'intuitive, reflective, and carefully ambitious',
      'resilient under pressure with a soft private side',
      'curious, adaptable, and loyal once trust is earned',
    ];
    final love = <String>[
      'You give affection through consistency more than grand gestures',
      'You need emotional safety before you fully open',
      'You attract people who feel calm around your presence',
      'Partnership grows when honesty is paired with patience',
      'Your heart softens for those who respect your inner pace',
    ];
    final money = <String>[
      'Steady progress suits you better than sudden leaps',
      'Your earning path strengthens when skill and patience meet',
      'Practical planning protects the opportunities you create',
      'Value compounds when you finish what you start',
      'Resources grow through focus, not scattered effort',
    ];
    final challenge = <String>[
      'Overthinking can delay decisions you already understand',
      'You sometimes carry too much alone before asking for support',
      'Perfectionism may mute the courage of imperfect beginnings',
      'Holding on to old caution can slow fresh chapters',
      'You may undervalue how much clarity you already hold',
    ];
    final guidance = <String>[
      'Choose one meaningful commitment this week and protect it from distraction',
      'Speak one honest need out loud instead of waiting to be understood',
      'Create a quiet daily ritual that resets your nervous system',
      'Act on the smallest next step rather than waiting for certainty',
      'Offer kindness to yourself with the same care you give others',
    ];

    final lightNote = stats.brightness < 0.35
        ? 'Even in softer light, the lines still suggest a mind that works best with depth rather than noise.'
        : stats.brightness > 0.75
            ? 'The brightness in this capture mirrors a season where clarity is becoming easier to claim.'
            : 'The balance of light across the palm hints at a life seeking equilibrium between drive and rest.';

    final contrastNote = stats.contrast > 0.12
        ? 'Defined ridges point to strong inner preferences—you know what feels right even when you hesitate to say it.'
        : 'Softer line contrast suggests a flexible temperament that can adapt without losing your core.';

    final hand = dominantHand.toLowerCase() == 'left' ? 'Left' : 'Right';
    final t = traits[seed % traits.length];
    final l = love[(seed ~/ 3) % love.length];
    final m = money[(seed ~/ 5) % money.length];
    final c = challenge[(seed ~/ 7) % challenge.length];
    final g = guidance[(seed ~/ 11) % guidance.length];

    return '''
HAND: $hand
OPENING: Your palm carries a quiet radiance—the kind that reveals itself only to those who look with patience.
PERSONALITY: You come across as someone $t. $contrastNote
LIFE_PATH: $lightNote Your path favors depth over noise, and progress that lasts longer than applause.
LOVE: $l Bonds deepen when you feel emotionally safe and respected for your pace.
PROSPERITY: $m Craftsmanship and steady focus unlock more for you than scattered ambition.
CHALLENGES: $c The friction softens when you trust the clarity you already hold.
GUIDANCE: $g Let one sincere choice this week become proof that you are ready.
BLESSING: May your hands remember their wisdom every time you choose yourself with gentleness.
'''
        .trim();
  }

  String _hindiReading({
    required String dominantHand,
    required int seed,
    required _DemoImageStats stats,
  }) {
    final traits = <String>[
      'शांत, समझदार और भावुक रूप से संतुलित',
      'नर्म दिल वाले, पर व्यावहारिक सोच रखने वाले',
      'अंतर्ज्ञानी, विचारशील और सावधानी से महत्वाकांक्षी',
      'दबाव में मजबूत, भीतर से संवेदनशील',
      'जिज्ञासु, अनुकूलनशील और विश्वास पर अटूट',
    ];
    final love = <String>[
      'आप प्रेम को बड़े प्रदर्शन से अधिक निरंतरता से देते हैं',
      'पूरी तरह खुलने से पहले आपको भावनात्मक सुरक्षा चाहिए',
      'आप उन लोगों को आकर्षित करते हैं जो आपकी उपस्थिति में शांत महसूस करते हैं',
      'ईमानदारी और धैर्य साथ हों तो रिश्ते गहराते हैं',
      'आपका हृदय उनके लिए नरम होता है जो आपकी गति का सम्मान करें',
    ];
    final money = <String>[
      'अचानक छलांग से अधिक स्थिर प्रगति आपको सूट करती है',
      'कौशल और धैर्य मिलें तो कमाई का मार्ग मजबूत होता है',
      'व्यावहारिक योजना आपके बनाए अवसरों की रक्षा करती है',
      'जो शुरू करें उसे पूरा करने से मूल्य बढ़ता है',
      'फोकस से संसाधन बढ़ते हैं, बिखरे प्रयास से नहीं',
    ];
    final challenge = <String>[
      'अधिक सोचना उन निर्णयों को रोक सकता है जिन्हें आप पहले से समझते हैं',
      'सहायता माँगने से पहले आप बहुत कुछ अकेले उठा लेते हैं',
      'पूर्णता की चाह अधूरे शुरूआतों का साहस दबा सकती है',
      'पुरानी सावधानियाँ नई शुरुआत को धीमा कर सकती हैं',
      'आप कभी-कभी अपनी स्पष्टता का सही मूल्यांकन नहीं करते',
    ];
    final guidance = <String>[
      'इस सप्ताह एक अर्थपूर्ण वचन चुनें और उसे ध्यान भटकने से बचाएँ',
      'समझे जाने का इंतज़ार करने के बजाय एक ज़रूरत ईमानदारी से बोलें',
      'एक शांत दैनिक अभ्यास बनाएँ जो मन को स्थिर करे',
      'पूर्ण निश्चितता का इंतज़ार न करें—अगला छोटा कदम उठाएँ',
      'दूसरों को देते करुणा अपने प्रति भी रखें',
    ];

    final hand = dominantHand.toLowerCase() == 'left' ? 'Left' : 'Right';
    final t = traits[seed % traits.length];
    final l = love[(seed ~/ 3) % love.length];
    final m = money[(seed ~/ 5) % money.length];
    final c = challenge[(seed ~/ 7) % challenge.length];
    final g = guidance[(seed ~/ 11) % guidance.length];
    final light = stats.brightness < 0.35
        ? 'हल्की रोशनी में भी रेखाएँ गहराई वाली सोच का संकेत देती हैं।'
        : 'हथेली पर प्रकाश का संतुलन जीवन में संतुलन की खोज दर्शाता है।';

    return '''
HAND: $hand
OPENING: आपकी हथेली में एक शांत चमक है—जो धैर्य से देखने वाले को ही अपना सच दिखाती है।
PERSONALITY: आप $t व्यक्ति हैं। आपकी प्रकृति में स्थिर बुद्धिमत्ता और कोमल शक्ति दोनों बसते हैं।
LIFE_PATH: $light आपका मार्ग शोर से अधिक गहराई और टिकाऊ प्रगति की ओर है।
LOVE: $l प्रेम आपके लिए प्रदर्शन नहीं, सुरक्षित और सम्मानित साथ है।
PROSPERITY: $m आपके लिए सफलता बिखरे प्रयासों से नहीं, पूरे किए गए कामों से खिलती है।
CHALLENGES: $c यह चुनौती तब हल होती है जब आप अपनी पहले से मौजूद स्पष्टता पर विश्वास करते हैं।
GUIDANCE: $g इस सप्ताह एक सच्चा चुनाव आपकी तैयारी का प्रमाण बने।
BLESSING: आपकी हथेलियाँ आपको हर बार याद दिलाएँ कि कोमलता भी एक शक्ति है।
'''
        .trim();
  }

  _DemoImageStats _imageStats(Uint8List imageBytes) {
    try {
      final decoded = img.decodeImage(imageBytes);
      if (decoded == null) {
        return const _DemoImageStats(
          brightness: 0.5,
          contrast: 0.1,
          sharpness: 5,
        );
      }
      final width = decoded.width;
      final height = decoded.height;
      final step = (width < height ? width : height) ~/ 200;
      final sampleStep = step < 1 ? 1 : step;
      var count = 0;
      var sum = 0.0;
      var sumSq = 0.0;
      var edgeSum = 0.0;
      var edgeCount = 0;

      for (var y = 0; y < height; y += sampleStep) {
        for (var x = 0; x < width; x += sampleStep) {
          final p = decoded.getPixel(x, y);
          final l =
              (0.299 * p.r.toDouble()) +
              (0.587 * p.g.toDouble()) +
              (0.114 * p.b.toDouble());
          sum += l;
          sumSq += l * l;
          count++;
          if (x >= sampleStep) {
            final lp = decoded.getPixel(x - sampleStep, y);
            final left =
                (0.299 * lp.r.toDouble()) +
                (0.587 * lp.g.toDouble()) +
                (0.114 * lp.b.toDouble());
            edgeSum += (l - left).abs();
            edgeCount++;
          }
        }
      }
      if (count == 0) {
        return const _DemoImageStats(
          brightness: 0.5,
          contrast: 0.1,
          sharpness: 5,
        );
      }
      final mean = sum / count;
      final variance = max(0.0, (sumSq / count) - (mean * mean));
      final stdDev = sqrt(variance);
      return _DemoImageStats(
        brightness: mean / 255.0,
        contrast: stdDev / 255.0,
        sharpness: edgeCount == 0 ? 5 : edgeSum / edgeCount,
      );
    } catch (_) {
      return const _DemoImageStats(
        brightness: 0.5,
        contrast: 0.1,
        sharpness: 5,
      );
    }
  }

  int _seedFrom({
    required String language,
    required String dominantHand,
    required double brightness,
    required double contrast,
    required double sharpness,
    required int byteLength,
  }) {
    final raw =
        '${language.toLowerCase()}|$dominantHand|${(brightness * 100).round()}|${(contrast * 1000).round()}|${sharpness.round()}|$byteLength';
    var hash = 0;
    for (final code in raw.codeUnits) {
      hash = (hash * 31 + code) & 0x7fffffff;
    }
    return hash;
  }

  String _friendlyErrorForStatus(int statusCode, String rawError) {
    if (rawError == 'local_rate_limit') {
      return 'Too many requests. Please wait a minute and try again.';
    }
    if (rawError == 'upstream_rate_limit') {
      return 'Analysis provider is currently rate-limited or quota-limited. Please try again in a few minutes.';
    }
    if (statusCode == 401 || statusCode == 403) {
      return 'API authorization failed. Check your OpenRouter key.';
    }
    if (statusCode == 429) {
      return 'Too many requests. Please wait a minute and try again.';
    }
    if (statusCode == 504) {
      return 'Analysis took too long. Please retry.';
    }
    if (statusCode >= 500) {
      return 'Analysis service is temporarily unavailable. Please try again.';
    }
    return rawError.isEmpty ? 'Request failed. Please try again.' : rawError;
  }

  String _friendlyNetworkError(String raw) {
    final text = raw.toLowerCase();
    if (text.contains('timed out') || text.contains('socketexception')) {
      return 'Network timeout while contacting analysis provider. Please check internet and retry.';
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
    } catch (_) {}
    return body.isEmpty ? '' : body;
  }
}

class _PreparedImage {
  const _PreparedImage({required this.bytes, required this.mimeType});

  final Uint8List bytes;
  final String mimeType;
}

class _DemoImageStats {
  const _DemoImageStats({
    required this.brightness,
    required this.contrast,
    required this.sharpness,
  });

  final double brightness;
  final double contrast;
  final double sharpness;
}

typedef OpenAiPalmService = PalmAnalysisService;

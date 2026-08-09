import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image/image.dart' as img;

import '../models/palm_result_model.dart';

final palmAnalysisServiceProvider = Provider<PalmAnalysisService>((ref) {
  return PalmAnalysisService(httpClient: http.Client());
});

/// Backward-compatible alias used by older call sites.
final openAiPalmServiceProvider = palmAnalysisServiceProvider;

class PalmAnalysisService {
  PalmAnalysisService({required this.httpClient});

  static const analysisMode = String.fromEnvironment(
    'ANALYSIS_MODE',
    defaultValue: 'demo',
  );
  static const _backendBaseUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'https://palm-reader-w4yy.onrender.com',
  );
  static const _appApiKey = String.fromEnvironment('BACKEND_APP_KEY');

  final http.Client httpClient;

  bool get isDemoMode => analysisMode.toLowerCase() != 'backend';

  Future<PalmResultModel> fetchPalmReading({
    required Uint8List imageBytes,
    required String language,
    required String dominantHand,
  }) async {
    if (isDemoMode) {
      return _demoReading(
        imageBytes: imageBytes,
        language: language,
        dominantHand: dominantHand,
      );
    }
    return _backendReading(
      imageBytes: imageBytes,
      language: language,
      dominantHand: dominantHand,
    );
  }

  Future<PalmResultModel> _demoReading({
    required Uint8List imageBytes,
    required String language,
    required String dominantHand,
  }) async {
    // Brief pause so the scanning animation has presence.
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
          await httpClient.send(request).timeout(const Duration(seconds: 55));
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

    final hand = dominantHand.toLowerCase() == 'left' ? 'left' : 'right';
    final t = traits[seed % traits.length];
    final l = _lowerFirst(love[(seed ~/ 3) % love.length]);
    final m = _lowerFirst(money[(seed ~/ 5) % money.length]);
    final c = _lowerFirst(challenge[(seed ~/ 7) % challenge.length]);
    final g = guidance[(seed ~/ 11) % guidance.length];

    return '''
Looking at your $hand palm, the overall impression is of someone $t. There is a grounded intelligence here—less flashy, more enduring—and it shows in the way your life line and heart currents seem to support each other rather than compete.

$lightNote $contrastNote In relationships, $l. Love for you is less about spectacle and more about being met with steadiness.

Around work and resources, $m. Ambition is present, but it prefers craftsmanship over chaos. The challenge pattern that rises most clearly is this: $c.

As guidance for the season ahead: $g. Palmistry here is a mirror for reflection, not a verdict. Use these impressions as permission to move with more self-trust, one deliberate choice at a time.
'''
        .trim();
  }

  String _lowerFirst(String value) {
    if (value.isEmpty) return value;
    return '${value[0].toLowerCase()}${value.substring(1)}';
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

    final hand = dominantHand.toLowerCase() == 'left' ? 'बाएँ' : 'दाएँ';
    final t = traits[seed % traits.length];
    final l = love[(seed ~/ 3) % love.length];
    final m = money[(seed ~/ 5) % money.length];
    final c = challenge[(seed ~/ 7) % challenge.length];
    final g = guidance[(seed ~/ 11) % guidance.length];
    final light = stats.brightness < 0.35
        ? 'हल्की रोशनी में भी रेखाएँ गहराई वाली सोच का संकेत देती हैं।'
        : 'हथेली पर प्रकाश का संतुलन जीवन में संतुलन की खोज दर्शाता है।';

    return '''
आपकी $hand हथेली को देखते हुए पहली छाप यह बनती है कि आप $t व्यक्ति हैं। यहाँ एक स्थिर बुद्धिमत्ता दिखती है—चमकदार शोर से अधिक टिकाऊ समझ—जहाँ जीवन रेखा और हृदय की धाराएँ एक-दूसरे का समर्थन करती हुई लगती हैं।

$light रिश्तों में, $l। आपके लिए प्रेम प्रदर्शन से अधिक स्थिर साथ का नाम है।

काम और संसाधनों के बारे में, $m। महत्वाकांक्षा है, पर वह अव्यवस्था से अधिक कुशलता पसंद करती है। सबसे स्पष्ट चुनौती यह है: $c।

आने वाले समय के लिए मार्गदर्शन: $g। यह वाचन आत्म-चिंतन के लिए एक दर्पण है, अंतिम फैसला नहीं। इन संकेतों को आत्मविश्वास के साथ एक सोच-समझे कदम आगे बढ़ाने की अनुमति समझें।
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

/// Legacy name kept for imports that still reference OpenAiPalmService.
typedef OpenAiPalmService = PalmAnalysisService;

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
    final photoId = _imageFingerprint(prepared.bytes);
    final dataUrl =
        'data:${prepared.mimeType};base64,${base64Encode(prepared.bytes)}';
    final prompt = _buildPrompt(
      language: language,
      dominantHand: dominantHand,
      photoId: photoId,
    );
    final requestSeed = Random().nextInt(1 << 30);

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
              'temperature': 1.0,
              'top_p': 0.95,
              'max_tokens': 1200,
              'seed': requestSeed,
              'messages': [
                {
                  'role': 'system',
                  'content':
                      'You are a gifted Indian palmist and poetic spiritual guide. Your readings feel intimate, vivid, and emotionally intelligent—never generic. You ALWAYS look at the attached palm photo first. Anchor every claim to a visible feature in THIS photo. Never invent a reading when no clear hand is in the image. Never reuse the same opening, metaphors, or section wording across different photos. Always follow the exact labeled output format requested by the user.',
                },
                {
                  'role': 'user',
                  // Image first so the vision model actually attends to the palm.
                  'content': [
                    {
                      'type': 'image_url',
                      'image_url': {'url': dataUrl},
                    },
                    {'type': 'text', 'text': prompt},
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
    final photoId = _imageFingerprint(imageBytes);
    final seed = _seedFrom(
      language: language,
      dominantHand: dominantHand,
      brightness: stats.brightness,
      contrast: stats.contrast,
      sharpness: stats.sharpness,
      byteLength: imageBytes.length,
      photoId: photoId,
    );

    final reading = language.toLowerCase().startsWith('hindi') ||
            language.toLowerCase().startsWith('हिंदी')
        ? _hindiReading(
            dominantHand: dominantHand,
            seed: seed,
            stats: stats,
          )
        : _englishReading(
            dominantHand: dominantHand,
            seed: seed,
            stats: stats,
          );

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
    required String photoId,
  }) {
    return '''
You are giving a premium private palm reading. Study the palm image carefully and write a reading that feels personal, magnetic, and memorable — the kind of reading someone screenshots and sends to a friend saying "this is scary accurate."

Language: write the reading body entirely in $language.
User's usual dominant/writing hand (context only, not to be used to determine which hand appears in the photo): $dominantHand.
Photo id for this request (unique to this image): $photoId.
This reading must be unique to photo id $photoId. Do not reuse openings, metaphors, or section wording from any other reading.

IMAGE CHECK (mandatory, first step):
- If the image does not clearly show a human palm/hand, do not fabricate a reading. Output only:
  HAND: Unclear
  OPENING: One honest sentence explaining the photo doesn't show a clear hand, and inviting a retake.
  (stop after OPENING in this case)

HAND IDENTIFICATION (mandatory, when a hand is visible):
- Inspect thumb side, finger order, and palm orientation.
- Decide if the photo shows a LEFT or RIGHT hand.
- Never infer left/right from the form field. Name the hand only from the image.

HOW TO MAKE THIS FEEL REAL (mandatory technique):
- Look at THIS photo before writing. OPENING must name one concrete visible detail unique to this image (a specific line curve/break/branch, mount fullness, finger proportion, crease pattern, or texture).
- Anchor every claim to something visible: a specific line, its depth, length, branch, break, curve, or a mount's fullness, a finger's length relative to another, the hand's texture or temperature-look. Never make a claim you can't tie to a visible feature.
- Vary sentence length on purpose. Let some lines be short and land hard. Don't write four same-length sentences in a row.
- Use one concrete, unexpected image per section instead of abstract mood words. Not "you are creative" — instead, point to what that creativity actually looks like in their life (an unfinished project, a room rearranged at midnight, a habit of starting three things at once).
- Plant one detail in PERSONALITY or LIFE_PATH and pay it off later in GUIDANCE or BLESSING, so the reading feels like it's about one specific person, not a template.
- Write like you're noticing something in real time ("there—see how the line curves back toward the thumb"), not reciting a memorized meaning.

BANNED PATTERNS (these are the tells of a fake/generic reading — never use them):
- Generic openers: "Your hand tells a story," "The universe has written," "I see great things ahead," "Your palm carries a quiet radiance"
- Stock phrases: "old soul," "everything happens for a reason," "trust the journey," "your path is unique," "special gift," "destined for greatness"
- Vague hedge-everything statements that could apply to anyone
- Listing traits without tying them to a visible feature
- Ending every section on the same upbeat note — let CHALLENGES actually feel like a challenge before GUIDANCE resolves it
- Copy-paste sameness: if this reading could fit a different palm photo equally well, rewrite until it couldn't

READING QUALITY:
- Sound like a wise live reader speaking softly to one person, noticing details as they go.
- Warm, poetic, emotionally intelligent, grounded — never vague horoscope filler.
- Avoid fear, death predictions, medical/legal/financial guarantees, exact dates.
- Comment only on palmistry-relevant features (lines, mounts, shape, texture, finger proportions). Never remark on skin tone, scars, jewelry, or other personal appearance details.
- If the hand appears to belong to a minor, keep LOVE focused on friendship/family connection — never romantic or sexual framing.
- Give hope with honesty: real strengths, one honest soft challenge, and a genuinely useful next step — not just comfort.
- Target roughly 220-320 words total across all sections.

OUTPUT FORMAT (exact labels, in this order, each label on its own line, one blank line between sections):
HAND: Left or Right
OPENING: One magnetic sentence that hooks the heart — must include one concrete visible detail from THIS photo.
PERSONALITY: 2-4 sentences, anchored to a specific visible feature.
LIFE_PATH: 2-4 sentences, anchored to a specific visible feature.
LOVE: 2-4 sentences, anchored to a specific visible feature.
PROSPERITY: 2-4 sentences, anchored to a specific visible feature.
CHALLENGES: 2-3 sentences — name a real, specific soft challenge, don't soften it into nothing.
GUIDANCE: 2-4 sentences — resolve or pay off something planted earlier.
BLESSING: One short closing blessing line, specific to this person, not generic.

Rules:
- No markdown, no bullets, no extra labels, no preamble before HAND.
- Each section must feel distinct and vivid — no recycled phrasing, no recycled sentence structure across sections.
- If the image is unclear but a hand is visible, say so briefly in OPENING, then still give a best-effort reading.
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
    final openings = <String>[
      'Look—the life line here runs deep and close to the thumb, like someone who protects their energy before they spend it.',
      'That head line forks just past the center; your mind keeps two plans open even when your mouth says one.',
      'The heart line sits high and clear—you feel first, explain later, and hate being rushed into either.',
      'Your fate line is quieter than the others; progress for you is built in private, not announced.',
      'See the fullness under the base of the thumb—warmth is your default, and solitude is how you recharge it.',
    ];
    final blessings = <String>[
      'May the next quiet decision you make finally match the strength already written in that life line.',
      'May the unfinished thing on your desk become the one you finish without apology.',
      'May someone finally meet your pace instead of asking you to hurry your heart.',
      'May tonight\'s small honest choice compound into the chapter you keep imagining.',
      'May your hands stop carrying what was never yours to hold alone.',
    ];
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
    final o = openings[(seed ~/ 13) % openings.length];
    final b = blessings[(seed ~/ 17) % blessings.length];

    return '''
HAND: $hand
OPENING: $o
PERSONALITY: You come across as someone $t. $contrastNote
LIFE_PATH: $lightNote Your path favors depth over noise, and progress that lasts longer than applause.
LOVE: $l Bonds deepen when you feel emotionally safe and respected for your pace.
PROSPERITY: $m Craftsmanship and steady focus unlock more for you than scattered ambition.
CHALLENGES: $c The friction softens when you trust the clarity you already hold.
GUIDANCE: $g Let one sincere choice this week become proof that you are ready.
BLESSING: $b
'''
        .trim();
  }

  String _hindiReading({
    required String dominantHand,
    required int seed,
    required _DemoImageStats stats,
  }) {
    final openings = <String>[
      'देखिए—जीवन रेखा यहाँ गहरी और अँगूठे के पास चलती है; आप ऊर्जा खर्च करने से पहले उसे बचाते हैं।',
      'मस्तिष्क रेखा बीच के बाद दो भागों में बँटती दिखती है; आपके मन में अक्सर दो योजनाएँ साथ चलती हैं।',
      'हृदय रेखा ऊँची और साफ़ है—आप पहले महसूस करते हैं, बाद में समझाते हैं।',
      'भाग्य रेखा बाकी रेखाओं से शांत है; आपकी प्रगति निजी मेहनत से बनती है, शोर से नहीं।',
      'अँगूठे के नीचे का भाग भरा हुआ है—आपका स्वभाव गर्म है, और अकेला समय आपको वापस भरता है।',
    ];
    final blessings = <String>[
      'अगला शांत निर्णय उसी शक्ति से मेल खाए जो आपकी जीवन रेखा में पहले से है।',
      'मेज़ पर अधूरा काम आज बिना माफ़ी के पूरा हो।',
      'कोई आपकी गति का सम्मान करे, जल्दबाज़ी न माँगे।',
      'आज की एक छोटी ईमानदार पसंद वह अध्याय बने जिसकी आप कल्पना करते हैं।',
      'आपके हाथ वह बोझ छोड़ दें जो कभी आपका नहीं था।',
    ];
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
    final o = openings[(seed ~/ 13) % openings.length];
    final b = blessings[(seed ~/ 17) % blessings.length];
    final light = stats.brightness < 0.35
        ? 'हल्की रोशनी में भी रेखाएँ गहराई वाली सोच का संकेत देती हैं।'
        : 'हथेली पर प्रकाश का संतुलन जीवन में संतुलन की खोज दर्शाता है।';

    return '''
HAND: $hand
OPENING: $o
PERSONALITY: आप $t व्यक्ति हैं। आपकी प्रकृति में स्थिर बुद्धिमत्ता और कोमल शक्ति दोनों बसते हैं।
LIFE_PATH: $light आपका मार्ग शोर से अधिक गहराई और टिकाऊ प्रगति की ओर है।
LOVE: $l प्रेम आपके लिए प्रदर्शन नहीं, सुरक्षित और सम्मानित साथ है।
PROSPERITY: $m आपके लिए सफलता बिखरे प्रयासों से नहीं, पूरे किए गए कामों से खिलती है।
CHALLENGES: $c यह चुनौती तब हल होती है जब आप अपनी पहले से मौजूद स्पष्टता पर विश्वास करते हैं।
GUIDANCE: $g इस सप्ताह एक सच्चा चुनाव आपकी तैयारी का प्रमाण बने।
BLESSING: $b
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
    required String photoId,
  }) {
    final raw =
        '${language.toLowerCase()}|$dominantHand|${(brightness * 100).round()}|${(contrast * 1000).round()}|${sharpness.round()}|$byteLength|$photoId';
    var hash = 0;
    for (final code in raw.codeUnits) {
      hash = (hash * 31 + code) & 0x7fffffff;
    }
    return hash;
  }

  /// Content fingerprint so different palms get different demo/AI prompts.
  String _imageFingerprint(Uint8List bytes) {
    var hash = 2166136261;
    final step = bytes.length < 2048 ? 1 : bytes.length ~/ 2048;
    for (var i = 0; i < bytes.length; i += step) {
      hash ^= bytes[i];
      hash = (hash * 16777619) & 0xffffffff;
    }
    hash ^= bytes.length;
    return hash.toRadixString(16).padLeft(8, '0');
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

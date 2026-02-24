import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/palm_result_model.dart';

final mockApiServiceProvider = Provider<MockApiService>((ref) {
  return MockApiService();
});

class MockApiService {
  Future<PalmResultModel> fetchPalmReading() async {
    await Future<void>.delayed(const Duration(milliseconds: 850));

    final json = <String, dynamic>{
      'personality':
          'You project calm strength. Your palm suggests intuitive leadership, empathy, and a quiet magnetism that makes people trust your direction.',
      'lifePath':
          'Your path leans toward meaningful reinvention. Each major chapter asks you to outgrow comfort, then rewards you with deeper purpose and influence.',
      'love':
          'Your emotional lines show loyal depth. You thrive in honest partnerships where emotional intelligence and shared growth matter more than surface intensity.',
      'wealth':
          'Your financial energy points to steady expansion through disciplined choices, strategic timing, and building long-term value instead of short bursts.',
      'challenges':
          'You sometimes carry more than you need. The pattern here suggests learning to set boundaries sooner so your energy stays aligned with what truly matters.',
      'guidance':
          'For this phase, choose one bold priority and protect it daily. As your focus sharpens, hidden opportunities appear with unusual synchronicity.',
      'followUps': [
        'Would you like deeper insight into your love life?',
        'Do you want a compatibility reading?',
      ],
    };

    return PalmResultModel.fromMap(json);
  }
}


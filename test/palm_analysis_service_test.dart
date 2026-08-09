import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:palm_reader/services/palm_analysis_service.dart';

void main() {
  test('demo mode returns narrative reading', () async {
    final service = PalmAnalysisService(httpClient: http.Client());
    expect(service.isDemoMode, isTrue);

    final image = img.Image(width: 640, height: 640);
    img.fill(image, color: img.ColorRgb8(180, 120, 90));
    for (var y = 200; y < 440; y++) {
      for (var x = 180; x < 460; x++) {
        image.setPixelRgb(x, y, 210, 150, 110);
      }
    }
    final bytes = Uint8List.fromList(img.encodeJpg(image));

    final result = await service.fetchPalmReading(
      imageBytes: bytes,
      language: 'English',
      dominantHand: 'Right',
    );

    expect(result.fullReading.trim().isNotEmpty, isTrue);
    expect(result.fullReading.toLowerCase(), contains('palm'));
  });
}

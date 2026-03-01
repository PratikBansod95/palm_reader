import 'dart:typed_data';

class OnboardingSelection {
  const OnboardingSelection({
    required this.language,
    required this.dominantHand,
  });

  final String language;
  final String dominantHand;
}

class ScanRequest {
  const ScanRequest({
    required this.imageBytes,
    required this.language,
    required this.dominantHand,
  });

  final Uint8List imageBytes;
  final String language;
  final String dominantHand;
}

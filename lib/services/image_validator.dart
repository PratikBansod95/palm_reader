import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/animation_timings.dart';

final imageValidatorProvider = Provider<ImageValidator>((ref) {
  return ImageValidator();
});

class ImageValidator {
  final _random = Random();

  Future<bool> validatePalmImage() async {
    await Future<void>.delayed(AnimationTimings.imageValidationDelay);
    return _random.nextInt(10) < 8;
  }
}


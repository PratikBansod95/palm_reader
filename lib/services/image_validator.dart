import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;

import '../core/constants/animation_timings.dart';

final imageValidatorProvider = Provider<ImageValidator>((ref) {
  return ImageValidator();
});

class ImageValidationResult {
  const ImageValidationResult({
    required this.isValid,
    required this.message,
    required this.width,
    required this.height,
    required this.brightness,
    required this.contrast,
    required this.sharpness,
  });

  final bool isValid;
  final String message;
  final int width;
  final int height;
  final double brightness;
  final double contrast;
  final double sharpness;
}

class ImageValidator {
  static const int _minWidth = 720;
  static const int _minHeight = 720;
  static const double _minBrightness = 0.14;
  static const double _maxBrightness = 0.93;
  static const double _minContrast = 0.055;
  static const double _hardMinSharpness = 4.8;
  static const double _softMinSharpness = 5.5;

  Future<ImageValidationResult> validatePalmImage(Uint8List imageBytes) async {
    await Future<void>.delayed(AnimationTimings.imageValidationDelay);

    try {
      final decoded = img.decodeImage(imageBytes);
      if (decoded == null) {
        return const ImageValidationResult(
          isValid: false,
          message: 'Could not process this image. Please retake the photo.',
          width: 0,
          height: 0,
          brightness: 0,
          contrast: 0,
          sharpness: 0,
        );
      }

      final width = decoded.width;
      final height = decoded.height;
      final stats = _computeQualityStats(decoded);

      final tooSmall = width < _minWidth || height < _minHeight;
      final tooDark = stats.brightness < _minBrightness;
      final tooBright = stats.brightness > _maxBrightness;
      final lowContrast = stats.contrast < _minContrast;
      final blurry = stats.sharpness < _hardMinSharpness ||
          (stats.sharpness < _softMinSharpness && stats.contrast < 0.09);

      if (!tooSmall && !tooDark && !tooBright && !lowContrast && !blurry) {
        return ImageValidationResult(
          isValid: true,
          message: 'Image quality looks good.',
          width: width,
          height: height,
          brightness: stats.brightness,
          contrast: stats.contrast,
          sharpness: stats.sharpness,
        );
      }

      final message = _buildFailureMessage(
        tooSmall: tooSmall,
        tooDark: tooDark,
        tooBright: tooBright,
        lowContrast: lowContrast,
        blurry: blurry,
      );

      return ImageValidationResult(
        isValid: false,
        message: message,
        width: width,
        height: height,
        brightness: stats.brightness,
        contrast: stats.contrast,
        sharpness: stats.sharpness,
      );
    } catch (_) {
      return const ImageValidationResult(
        isValid: false,
        message: 'Could not process this image. Please retake the photo.',
        width: 0,
        height: 0,
        brightness: 0,
        contrast: 0,
        sharpness: 0,
      );
    }
  }

  _QualityStats _computeQualityStats(img.Image image) {
    final width = image.width;
    final height = image.height;
    final int sampleStep = max(1, min(width, height) ~/ 260);

    var count = 0;
    var sum = 0.0;
    var sumSq = 0.0;
    var edgeSum = 0.0;
    var edgeCount = 0;

    for (var y = 0; y < height; y += sampleStep) {
      for (var x = 0; x < width; x += sampleStep) {
        final p = image.getPixel(x, y);
        final r = p.r.toDouble();
        final g = p.g.toDouble();
        final b = p.b.toDouble();
        final l = (0.299 * r) + (0.587 * g) + (0.114 * b);

        sum += l;
        sumSq += l * l;
        count++;

        if (x >= sampleStep) {
          final lp = image.getPixel(x - sampleStep, y);
          final lr = lp.r.toDouble();
          final lg = lp.g.toDouble();
          final lb = lp.b.toDouble();
          final left = (0.299 * lr) + (0.587 * lg) + (0.114 * lb);
          edgeSum += (l - left).abs();
          edgeCount++;
        }

        if (y >= sampleStep) {
          final upPixel = image.getPixel(x, y - sampleStep);
          final ur = upPixel.r.toDouble();
          final ug = upPixel.g.toDouble();
          final ub = upPixel.b.toDouble();
          final upLuma = (0.299 * ur) + (0.587 * ug) + (0.114 * ub);
          edgeSum += (l - upLuma).abs();
          edgeCount++;
        }
      }
    }

    if (count == 0 || edgeCount == 0) {
      return const _QualityStats(
        brightness: 0,
        contrast: 0,
        sharpness: 0,
      );
    }

    final mean = sum / count;
    final variance = max(0, (sumSq / count) - (mean * mean));
    final stdDev = sqrt(variance);

    return _QualityStats(
      brightness: mean / 255.0,
      contrast: stdDev / 255.0,
      sharpness: edgeSum / edgeCount,
    );
  }

  String _buildFailureMessage({
    required bool tooSmall,
    required bool tooDark,
    required bool tooBright,
    required bool lowContrast,
    required bool blurry,
  }) {
    if (tooSmall) {
      return 'Image resolution is too low. Move closer and retake the photo.';
    }
    if (blurry) {
      return 'Image looks blurry. Hold steady and keep the palm in focus.';
    }
    if (tooDark) {
      return 'Image is too dark. Use brighter, even lighting.';
    }
    if (tooBright) {
      return 'Image is overexposed. Reduce glare and avoid harsh light.';
    }
    if (lowContrast) {
      return 'Palm lines are not clear enough. Use better lighting and a plain background.';
    }
    return 'Palm image is not clear enough. Please retake with full palm visibility.';
  }
}

class _QualityStats {
  const _QualityStats({
    required this.brightness,
    required this.contrast,
    required this.sharpness,
  });

  final double brightness;
  final double contrast;
  final double sharpness;
}

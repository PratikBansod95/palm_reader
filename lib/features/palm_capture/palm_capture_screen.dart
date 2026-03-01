import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/theme/colors.dart';
import '../../models/reading_context_model.dart';
import '../../services/image_validator.dart';
import '../../widgets/animated_background.dart';

const List<double> _kDesaturateMatrix = <double>[
  0.2126, 0.7152, 0.0722, 0, 0,
  0.2126, 0.7152, 0.0722, 0, 0,
  0.2126, 0.7152, 0.0722, 0, 0,
  0, 0, 0, 1, 0,
];

class PalmCaptureScreen extends ConsumerStatefulWidget {
  const PalmCaptureScreen({
    required this.selection,
    super.key,
  });

  final OnboardingSelection selection;

  @override
  ConsumerState<PalmCaptureScreen> createState() => _PalmCaptureScreenState();
}

class _PalmCaptureScreenState extends ConsumerState<PalmCaptureScreen>
    with SingleTickerProviderStateMixin {
  bool _loading = false;
  final ImagePicker _picker = ImagePicker();

  late final AnimationController _pulseController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _capture() async {
    HapticFeedback.mediumImpact();

    final permission = await Permission.camera.request();
    if (!mounted) {
      return;
    }

    if (!permission.isGranted) {
      await _showCameraPermissionDialog(
        permanentlyDenied: permission.isPermanentlyDenied,
      );
      return;
    }

    final image = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 92,
      maxWidth: 1800,
      maxHeight: 1800,
      preferredCameraDevice: CameraDevice.rear,
    );

    if (!mounted || image == null) {
      return;
    }

    final Uint8List capturedBytes = await image.readAsBytes();

    setState(() => _loading = true);
    final validation = await ref
        .read(imageValidatorProvider)
        .validatePalmImage(capturedBytes);
    debugPrint(
      'PalmValidation valid=${validation.isValid} '
      'size=${validation.width}x${validation.height} '
      'brightness=${validation.brightness.toStringAsFixed(3)} '
      'contrast=${validation.contrast.toStringAsFixed(3)} '
      'sharpness=${validation.sharpness.toStringAsFixed(3)} '
      'message="${validation.message}"',
    );
    if (!mounted) {
      return;
    }
    setState(() => _loading = false);

    if (validation.isValid) {
      context.go(
        '/scanning',
        extra: ScanRequest(
          imageBytes: capturedBytes,
          language: widget.selection.language,
          dominantHand: widget.selection.dominantHand,
        ),
      );
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Capture Not Clear'),
        content: Text(
          validation.message,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Future<void> _showCameraPermissionDialog({
    required bool permanentlyDenied,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Camera Permission Needed'),
        content: Text(
          permanentlyDenied
              ? 'Camera access is blocked. Please enable camera permission from app settings.'
              : 'Please allow camera permission to capture your palm image.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          if (permanentlyDenied)
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await openAppSettings();
              },
              child: const Text('Open Settings'),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: AnimatedBackground(
        child: Stack(
          children: [
            const Positioned.fill(child: _SkyOverlay()),
            SafeArea(
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Click a clear picture of your dominant hand',
                          style: textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Keep your palm fully visible and well-lit before capture.',
                          style: textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 22),
                        Expanded(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: AppColors.cardBase,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: AppColors.cardStroke),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.gold.withOpacity(0.08),
                                  blurRadius: 24,
                                ),
                              ],
                            ),
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(24),
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        ShaderMask(
                                          blendMode: BlendMode.dstIn,
                                          shaderCallback: (bounds) {
                                            return RadialGradient(
                                              center: const Alignment(0, 0.08),
                                              radius: 1.05,
                                              colors: const [
                                                Colors.white,
                                                Colors.white,
                                                Colors.transparent,
                                              ],
                                              stops: const [0.0, 0.56, 1.0],
                                            ).createShader(bounds);
                                          },
                                          child: ColorFiltered(
                                            colorFilter:
                                                const ColorFilter.matrix(_kDesaturateMatrix),
                                            child: ColorFiltered(
                                              colorFilter: ColorFilter.mode(
                                                AppColors.softGold.withValues(alpha: 0.30),
                                                BlendMode.modulate,
                                              ),
                                              child: ImageFiltered(
                                                imageFilter: ImageFilter.blur(
                                                  sigmaX: 2.8,
                                                  sigmaY: 2.8,
                                                ),
                                                child: Opacity(
                                                  opacity: 0.2,
                                                  child: Transform.scale(
                                                    scale: 1.12,
                                                    child: Image.asset(
                                                      'assets/images/hand_overlay.png',
                                                      fit: BoxFit.cover,
                                                      alignment: const Alignment(0.02, 0.18),
                                                      errorBuilder: (context, error, stackTrace) =>
                                                          const SizedBox.shrink(),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        DecoratedBox(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                              colors: [
                                                AppColors.midnight.withValues(alpha: 0.3),
                                                AppColors.deepIndigo.withValues(alpha: 0.12),
                                                AppColors.midnight.withValues(alpha: 0.36),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Center(
                          child: GestureDetector(
                            onTap: _loading ? null : _capture,
                            child: AnimatedBuilder(
                              animation: _pulseController,
                              builder: (context, child) {
                                final pulse = 6 + (_pulseController.value * 14);
                                return Container(
                                  width: 94,
                                  height: 94,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.gold.withOpacity(0.24),
                                        blurRadius: pulse,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: child,
                                );
                              },
                              child: DecoratedBox(
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.gold,
                                ),
                                child: const Icon(
                                  Icons.camera_alt_rounded,
                                  color: AppColors.midnight,
                                  size: 34,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                  if (_loading)
                    const ColoredBox(
                      color: Color(0x99000000),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SkyOverlay extends StatefulWidget {
  const _SkyOverlay();

  @override
  State<_SkyOverlay> createState() => _SkyOverlayState();
}

class _SkyOverlayState extends State<_SkyOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 8),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _SkyPainter(progress: _controller.value),
        );
      },
    );
  }
}

class _SkyPainter extends CustomPainter {
  _SkyPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final starPaint = Paint()..style = PaintingStyle.fill;

    for (var i = 0; i < 320; i++) {
      final baseX = (i * 53.0) % size.width;
      final baseY = (i * 97.0) % size.height;
      final twinkle = (sin((progress * 2 * pi) + (i * 0.37)) + 1) * 0.5;
      final alpha = 0.08 + (twinkle * 0.38);
      final radius = (i % 9 == 0) ? 1.7 : (0.4 + ((i % 4) * 0.32));

      starPaint.color = AppColors.softGold.withValues(alpha: alpha);
      canvas.drawCircle(Offset(baseX, baseY), radius, starPaint);

      if (i % 24 == 0) {
        _drawSparkle(canvas, Offset(baseX, baseY), 5 + (twinkle * 5));
      }
    }

    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1
      ..color = AppColors.softGold.withValues(
        alpha: 0.2 + (0.1 * sin(progress * 2 * pi)),
      );

    final nodes = <Offset>[
      Offset(size.width * 0.14, size.height * 0.2),
      Offset(size.width * 0.24, size.height * 0.17),
      Offset(size.width * 0.32, size.height * 0.23),
      Offset(size.width * 0.72, size.height * 0.12),
      Offset(size.width * 0.82, size.height * 0.16),
      Offset(size.width * 0.9, size.height * 0.22),
      Offset(size.width * 0.16, size.height * 0.78),
      Offset(size.width * 0.24, size.height * 0.84),
      Offset(size.width * 0.33, size.height * 0.8),
      Offset(size.width * 0.71, size.height * 0.74),
      Offset(size.width * 0.85, size.height * 0.79),
      Offset(size.width * 0.9, size.height * 0.86),
      Offset(size.width * 0.43, size.height * 0.19),
      Offset(size.width * 0.5, size.height * 0.14),
      Offset(size.width * 0.58, size.height * 0.2),
      Offset(size.width * 0.45, size.height * 0.82),
      Offset(size.width * 0.53, size.height * 0.87),
      Offset(size.width * 0.61, size.height * 0.81),
    ];

    final links = <List<int>>[
      [0, 1],
      [1, 2],
      [3, 4],
      [4, 5],
      [6, 7],
      [7, 8],
      [9, 10],
      [10, 11],
      [12, 13],
      [13, 14],
      [15, 16],
      [16, 17],
      [2, 12],
      [8, 15],
    ];

    for (final link in links) {
      canvas.drawLine(nodes[link[0]], nodes[link[1]], linePaint);
    }

    final nodePaint = Paint()
      ..style = PaintingStyle.fill
      ..color = AppColors.softGold.withValues(alpha: 0.52);
    for (final n in nodes) {
      canvas.drawCircle(n, 1.6, nodePaint);
    }
  }

  void _drawSparkle(Canvas canvas, Offset c, double length) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1
      ..color = AppColors.softGold.withValues(alpha: 0.5);

    canvas.drawLine(Offset(c.dx - length, c.dy), Offset(c.dx + length, c.dy), p);
    canvas.drawLine(Offset(c.dx, c.dy - length), Offset(c.dx, c.dy + length), p);
  }

  @override
  bool shouldRepaint(covariant _SkyPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}


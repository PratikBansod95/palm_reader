import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:palm_reader/core/theme/app_theme.dart';
import 'package:palm_reader/features/onboarding/language_hand_screen.dart';
import 'package:palm_reader/features/palm_analysis/result_screen.dart';
import 'package:palm_reader/features/palm_capture/palm_capture_screen.dart';
import 'package:palm_reader/features/palm_capture/scanning_screen.dart';
import 'package:palm_reader/features/subscription/subscription_screen.dart';
import 'package:palm_reader/models/palm_result_model.dart';

class PalmDestinyApp extends StatelessWidget {
  const PalmDestinyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const LanguageHandScreen(),
        ),
        GoRoute(
          path: '/capture',
          builder: (context, state) => const PalmCaptureScreen(),
        ),
        GoRoute(
          path: '/scanning',
          builder: (context, state) => const ScanningScreen(),
        ),
        GoRoute(
          path: '/results',
          pageBuilder: (context, state) {
            final extra = state.extra;
            if (extra is! PalmResultModel) {
              return const NoTransitionPage(child: LanguageHandScreen());
            }
            return CustomTransitionPage<void>(
              child: ResultScreen(result: extra),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                final slide = Tween<Offset>(
                  begin: const Offset(0, 0.08),
                  end: Offset.zero,
                ).chain(CurveTween(curve: Curves.easeOutCubic));

                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: animation.drive(slide),
                    child: child,
                  ),
                );
              },
            );
          },
        ),
        GoRoute(
          path: '/subscription',
          builder: (context, state) => const SubscriptionScreen(),
        ),
      ],
    );

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Palm Destiny',
      theme: AppTheme.dark,
      routerConfig: router,
    );
  }
}


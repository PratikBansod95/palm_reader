import 'package:flutter/material.dart';

class AnimationTimings {
  static const sectionStagger = Duration(milliseconds: 200);
  static const scanStep = Duration(milliseconds: 1100);
  static const imageValidationDelay = Duration(milliseconds: 600);
  static const scanTotal = Duration(seconds: 6);
  static const scanMinDwell = Duration(milliseconds: 1500);

  static const revealCurve = Curves.easeOutCubic;
  static const premiumCurve = Curves.easeInOutCubicEmphasized;
}


import 'package:flutter/material.dart';

class AnimationTimings {
  static const sectionStagger = Duration(milliseconds: 200);
  static const scanStep = Duration(seconds: 1);
  static const imageValidationDelay = Duration(seconds: 1);
  static const scanTotal = Duration(seconds: 6);

  static const revealCurve = Curves.easeOutCubic;
  static const premiumCurve = Curves.easeInOutCubicEmphasized;
}


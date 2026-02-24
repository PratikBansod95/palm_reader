import 'package:flutter/material.dart';

class AppAnimations {
  static const Duration verySlow = Duration(seconds: 16);
  static const Duration slow = Duration(milliseconds: 1400);
  static const Duration medium = Duration(milliseconds: 750);
  static const Duration fast = Duration(milliseconds: 300);

  static const Curve reveal = Curves.easeOutCubic;
  static const Curve smooth = Curves.easeInOutCubicEmphasized;
}


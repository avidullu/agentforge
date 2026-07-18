import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Chooses a readable text/icon color for an arbitrary solid background,
/// guaranteed to meet WCAG 2.1 AA contrast (≥4.5:1 for normal text).
///
/// Uses WCAG relative luminance and contrast ratio (not Flutter's simple
/// brightness estimator), so mid-brightness agent avatar colors (yellow, cyan,
/// medium green) get a properly contrasting foreground instead of white text
/// at 2.17:1.
///
/// For any solid sRGB background, at least one of pure black or pure white
/// will always meet the 4.5:1 threshold.
Color foregroundFor(Color background) {
  final bgLuminance = _relativeLuminance(background);

  // Contrast with white: (1.0 + 0.05) / (bgLuminance + 0.05)
  final whiteContrast = 1.05 / (bgLuminance + 0.05);

  // If white meets WCAG AA, prefer it (lighter foreground = more readable on
  // dark). Otherwise fall back to black.
  if (whiteContrast >= 4.5) return Colors.white;

  // Contrast with black: (bgLuminance + 0.05) / (0.0 + 0.05)
  final blackContrast = (bgLuminance + 0.05) / 0.05;

  // Black is guaranteed to pass when white fails; double-check for safety.
  if (blackContrast >= 4.5) return Colors.black;

  // Should be unreachable for any solid sRGB color, but if somehow both fail,
  // pick the higher-contrast option.
  return whiteContrast >= blackContrast ? Colors.white : Colors.black;
}

/// WCAG 2.1 relative luminance of an sRGB [color].
///
/// Linearizes each channel per the sRGB transfer function, then applies the
/// ITU-R BT.709 luminance coefficients.
double _relativeLuminance(Color color) {
  double linearizeChannel(int channel) {
    final c = channel / 255.0;
    return c <= 0.04045
        ? c / 12.92
        : math.pow((c + 0.055) / 1.055, 2.4) as double;
  }

  final r = linearizeChannel((color.r * 255).round());
  final g = linearizeChannel((color.g * 255).round());
  final b = linearizeChannel((color.b * 255).round());

  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

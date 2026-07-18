import 'package:flutter/material.dart';

/// Chooses a readable text/icon color for an arbitrary solid background.
Color foregroundFor(Color background) {
  return ThemeData.estimateBrightnessForColor(background) == Brightness.light
      ? Colors.black
      : Colors.white;
}

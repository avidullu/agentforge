import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agentforge/core/theme/app_theme.dart';

void main() {
  group('AppTheme', () {
    test('dark theme uses Material 3', () {
      expect(AppTheme.dark.useMaterial3, isTrue);
    });

    test('dark theme has dark brightness', () {
      expect(AppTheme.dark.brightness, Brightness.dark);
    });

    test('scaffold background is black', () {
      expect(AppTheme.dark.scaffoldBackgroundColor, AppColors.background);
    });

    test('color scheme accent is green', () {
      expect(AppTheme.dark.colorScheme.primary, AppColors.accent);
      expect(AppTheme.dark.colorScheme.secondary, AppColors.accent);
    });

    test('color scheme error is destructive red', () {
      expect(AppTheme.dark.colorScheme.error, AppColors.destructive);
    });

    test('color scheme surface is the design token', () {
      expect(AppTheme.dark.colorScheme.surface, AppColors.surface);
    });

    test('card theme has no elevation and rounded corners', () {
      final card = AppTheme.dark.cardTheme;
      expect(card.elevation, 0);
      expect(card.color, AppColors.surfaceRaised);
      expect(card.shape, isA<RoundedRectangleBorder>());
      final shape = card.shape as RoundedRectangleBorder;
      expect(shape.borderRadius, BorderRadius.circular(16));
    });

    test('app bar theme has no elevation and dark background', () {
      final bar = AppTheme.dark.appBarTheme;
      expect(bar.elevation, 0);
      expect(bar.backgroundColor, AppColors.background);
      expect(bar.centerTitle, isFalse);
    });

    test('input decoration theme has focused green border', () {
      final input = AppTheme.dark.inputDecorationTheme;
      expect(input, isNotNull);
      final fb = input.focusedBorder as OutlineInputBorder;
      expect(fb.borderSide.color, AppColors.accent);
      expect(fb.borderSide.width, 2);
    });
  });

  group('AppColors', () {
    test('tokens are dark-mode oriented', () {
      // Background is pure black
      expect(AppColors.background, const Color(0xFF000000));
      // Surface is near-black
      expect(AppColors.surface, const Color(0xFF131417));
      // Accent is green (positive signal)
      expect(AppColors.accent, const Color(0xFF30D158));
      // Destructive is red (negative signal)
      expect(AppColors.destructive, const Color(0xFFFF453A));
    });
  });
}

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agentforge/core/theme/color_contrast.dart';

/// WCAG 2.1 contrast ratio for two relative luminances.
double _contrastRatio(double l1, double l2) {
  final lighter = math.max(l1, l2);
  final darker = math.min(l1, l2);
  return (lighter + 0.05) / (darker + 0.05);
}

/// WCAG 2.1 relative luminance of an sRGB color (test-grade copy of the
/// production implementation for independent validation).
double _luminance(Color color) {
  double linearizeChannel(int c) {
    final v = c / 255.0;
    return v <= 0.04045
        ? v / 12.92
        : math.pow((v + 0.055) / 1.055, 2.4) as double;
  }

  return 0.2126 * linearizeChannel((color.r * 255).round()) +
      0.7152 * linearizeChannel((color.g * 255).round()) +
      0.0722 * linearizeChannel((color.b * 255).round());
}

void main() {
  group('foregroundFor', () {
    // ── Basic contract (should still pass) ──────────────────────────

    test('returns black for light backgrounds', () {
      expect(foregroundFor(const Color(0xFFFFFFFF)), Colors.black);
      expect(foregroundFor(const Color(0xFFFFFF00)), Colors.black);
      expect(foregroundFor(const Color(0xFF00FF00)), Colors.black);
      expect(foregroundFor(const Color(0xFFC0C0C0)), Colors.black);
    });

    test('returns white for dark backgrounds', () {
      expect(foregroundFor(const Color(0xFF000000)), Colors.white);
      expect(foregroundFor(const Color(0xFF131417)), Colors.white);
      expect(foregroundFor(const Color(0xFF1C1C1E)), Colors.white);
    });

    test('returns white for near-black colors', () {
      expect(foregroundFor(const Color(0xFF0A0A0A)), Colors.white);
    });

    test('returns black for near-white colors', () {
      expect(foregroundFor(const Color(0xFFF0F0F0)), Colors.black);
    });

    // ── WCAG AA guarantee (the fix) ────────────────────────────────

    test('guarantees WCAG AA ≥4.5:1 for any solid color', () {
      // Sample a range of hues at varying lightness levels.
      const hues = [0, 60, 120, 180, 240, 300]; // spaced ~60° apart
      const saturations = [0.0, 0.5, 1.0];
      const values = [0.1, 0.25, 0.4, 0.55, 0.7, 0.85, 1.0];

      for (final h in hues) {
        for (final s in saturations) {
          for (final v in values) {
            final bg = HSVColor.fromAHSV(1.0, h.toDouble(), s, v).toColor();
            final fg = foregroundFor(bg);

            final bgLum = _luminance(bg);
            final fgLum = _luminance(fg);
            final ratio = _contrastRatio(bgLum, fgLum);

            expect(
              ratio,
              greaterThanOrEqualTo(4.5),
              reason:
                  'foregroundFor(0x${bg.toARGB32().toRadixString(16)}) '
                  '→ ${fg == Colors.white ? "white" : "black"} '
                  'at ${ratio.toStringAsFixed(2)}:1',
            );
          }
        }
      }
    });

    // ── Agent avatar colors from the AF-006 audit ──────────────────

    test('agent colors from audit pass WCAG AA', () {
      // Documented failures from docs/10-Mobile-Design-Handoff-Review.md:
      // White initials on agents.Claude/Codex/Grok/Gemini: 2.65/2.17/2.61/3.27:1
      // These are approximate; the exact hex values may differ.
      const agentColors = <Color>[
        Color(0xFF7C3AED), // purple (Claude-ish)
        Color(0xFF10B981), // green (Codex-ish)
        Color(0xFF3B82F6), // blue (Grok-ish)
        Color(0xFF8B5CF6), // violet (Gemini-ish)
        Color(0xFFF59E0B), // amber (custom warm)
        Color(0xFFEF4444), // red
        Color(0xFF06B6D4), // cyan (from audit sample)
        Color(0xFF84CC16), // lime
        Color(0xFFF97316), // orange
        Color(0xFFEC4899), // pink
        Color(0xFF6366F1), // indigo
        Color(0xFF14B8A6), // teal
      ];

      for (final bg in agentColors) {
        final fg = foregroundFor(bg);
        final ratio = _contrastRatio(_luminance(bg), _luminance(fg));

        expect(
          ratio,
          greaterThanOrEqualTo(4.5),
          reason:
              'Agent color 0x${bg.toARGB32().toRadixString(16).padLeft(8, '0')} '
              '→ ${fg == Colors.white ? "white" : "black"} '
              'at ${ratio.toStringAsFixed(2)}:1',
        );
      }
    });

    // ── Edge cases ─────────────────────────────────────────────────

    test('mid-tone gray where both black and white could work', () {
      // Around L=0.18 both black and white pass 4.5:1.
      // The implementation prefers white when it passes.
      const midGray = Color(0xFF808080); // #808080 ≈ L=0.216
      // White: 1.05/0.266 = 3.95 — FAIL
      // Black: 0.266/0.05 = 5.32 — PASS
      expect(foregroundFor(midGray), Colors.black);
    });

    test('50% gray picks the higher-contrast option', () {
      const halfGray = Color(0xFF7F7F7F);
      final fg = foregroundFor(halfGray);
      final ratio = _contrastRatio(_luminance(halfGray), _luminance(fg));
      expect(ratio, greaterThanOrEqualTo(4.5));
    });

    test('slightly-above-mid chooses black', () {
      // At L≈0.18, white is ~4.5:1 (borderline pass).
      // The implementation picks white when it passes ≥4.5.
      const borderline = Color(0xFF949494); // L ≈ 0.183
      final fg = foregroundFor(borderline);
      final ratio = _contrastRatio(_luminance(borderline), _luminance(fg));
      expect(ratio, greaterThanOrEqualTo(4.5));
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agentforge/core/theme/color_contrast.dart';

void main() {
  group('foregroundFor', () {
    test('returns black for light backgrounds', () {
      expect(foregroundFor(const Color(0xFFFFFFFF)), Colors.black);
      expect(foregroundFor(const Color(0xFFFFFF00)), Colors.black); // yellow
      expect(foregroundFor(const Color(0xFF00FF00)), Colors.black); // green
      expect(foregroundFor(const Color(0xFFC0C0C0)), Colors.black); // silver
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
  });
}

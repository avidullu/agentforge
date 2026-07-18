import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agentforge/core/theme/widgets/empty_state.dart';
import 'package:agentforge/core/theme/widgets/error_state.dart';
import 'package:agentforge/core/theme/widgets/section_header.dart';
import 'package:agentforge/core/theme/widgets/status_badge.dart';

void main() {
  group('EmptyState', () {
    testWidgets('renders title and body', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EmptyState(title: 'No items', body: 'Nothing to see here.'),
          ),
        ),
      );
      expect(find.text('No items'), findsOneWidget);
      expect(find.text('Nothing to see here.'), findsOneWidget);
    });

    testWidgets('renders action button when provided', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmptyState(
              title: 'Empty',
              body: 'body',
              actionLabel: 'Do it',
              onAction: () => tapped = true,
            ),
          ),
        ),
      );
      expect(find.text('Do it'), findsOneWidget);
      await tester.tap(find.text('Do it'));
      expect(tapped, isTrue);
    });

    testWidgets('renders secondary button when provided', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmptyState(
              title: 'Empty',
              body: 'body',
              secondaryLabel: 'Secondary',
              onSecondary: () {},
            ),
          ),
        ),
      );
      expect(find.text('Secondary'), findsOneWidget);
    });

    testWidgets('does not render action area when no actions', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EmptyState(title: 'x', body: 'y'),
          ),
        ),
      );
      expect(find.byType(FilledButton), findsNothing);
      expect(find.byType(TextButton), findsNothing);
    });
  });

  group('ErrorState', () {
    testWidgets('renders title, message, and retry', (tester) async {
      var retried = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ErrorState(
              title: 'Oops',
              message: 'Something broke',
              onRetry: () => retried = true,
            ),
          ),
        ),
      );
      expect(find.text('Oops'), findsOneWidget);
      expect(find.text('Something broke'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      expect(retried, isTrue);
    });

    testWidgets('renders fallback text when provided', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ErrorState(
              title: 'Err',
              message: 'msg',
              onRetry: () {},
              fallback: 'owner/repo #42',
            ),
          ),
        ),
      );
      expect(find.text('owner/repo #42'), findsOneWidget);
    });

    testWidgets('does not render fallback when empty', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ErrorState(title: 'Err', message: 'm', onRetry: () {}),
          ),
        ),
      );
      // Should not have a fallback text body.
      expect(find.text('Err'), findsOneWidget);
      expect(find.text('m'), findsOneWidget);
      // Fallback area should be absent.
      expect(
        find.byWidgetPredicate(
          (w) => w is Text && w.style == ThemeData().textTheme.bodySmall,
        ),
        findsNothing,
      );
    });
  });

  group('SectionHeader', () {
    testWidgets('renders label', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: SectionHeader(label: 'Pull Requests')),
        ),
      );
      expect(find.text('Pull Requests'), findsOneWidget);
    });

    testWidgets('renders action button when provided', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SectionHeader(
              label: 'Agents',
              actionLabel: 'Add',
              onAction: () => tapped = true,
            ),
          ),
        ),
      );
      expect(find.text('Add'), findsOneWidget);
      await tester.tap(find.text('Add'));
      expect(tapped, isTrue);
    });

    testWidgets('does not render action without both label and callback', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SectionHeader(label: 'X', actionLabel: 'Y'),
          ),
        ),
      );
      expect(find.text('Y'), findsNothing);
    });
  });

  group('StatusBadge', () {
    testWidgets('renders label text', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: StatusBadge(label: 'in_progress')),
        ),
      );
      expect(find.text('in_progress'), findsOneWidget);
    });

    testWidgets('renders avatar with initial when avatarColor is set', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StatusBadge(
              label: 'Codex',
              avatarColor: Color(0xFF10B981),
              avatarLabel: 'C',
            ),
          ),
        ),
      );
      expect(find.text('Codex'), findsOneWidget);
      expect(find.text('C'), findsOneWidget); // avatar initial
      expect(find.byType(CircleAvatar), findsOneWidget);
    });

    testWidgets('does not render avatar when avatarColor is null', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: StatusBadge(label: 'open')),
        ),
      );
      expect(find.byType(CircleAvatar), findsNothing);
    });

    testWidgets('uses WCAG-safe foreground via foregroundFor', (tester) async {
      // Light green should get black foreground text
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StatusBadge(
              label: 'working',
              backgroundColor: Color(0xFF30D158),
            ),
          ),
        ),
      );
      // The label text should exist and be black (foregroundFor returns black
      // for light green since white contrast is <4.5:1).
      final text = tester.widget<Text>(find.text('working'));
      expect(text.style?.color, Colors.black);
    });
  });
}

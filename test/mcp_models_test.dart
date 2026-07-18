import 'package:flutter_test/flutter_test.dart';

import 'package:agentforge/core/mcp/mcp_models.dart';

void main() {
  group('AgentContext', () {
    test('hasContent is false for empty context', () {
      const ctx = AgentContext(agentId: 'a1', agentName: 'Test');
      expect(ctx.hasContent, isFalse);
    });

    test('hasContent is true when plan is present', () {
      const ctx = AgentContext(
        agentId: 'a1',
        agentName: 'Test',
        plan: 'Do the thing',
      );
      expect(ctx.hasContent, isTrue);
    });

    test('hasContent is true when rationaleSummary is present', () {
      const ctx = AgentContext(
        agentId: 'a1',
        agentName: 'Test',
        rationaleSummary: 'Refactored the module',
      );
      expect(ctx.hasContent, isTrue);
    });

    test('hasContent is true when recentActions is non-empty', () {
      const ctx = AgentContext(
        agentId: 'a1',
        agentName: 'Test',
        recentActions: ['edit', 'test'],
      );
      expect(ctx.hasContent, isTrue);
    });

    group('fromJson', () {
      test('parses full payload with recent_actions', () {
        final ctx = AgentContext.fromJson(
          {
            'plan': 'Fix bug',
            'rationale_summary': 'Root cause identified',
            'recent_actions': ['edit src/lib.dart', 'test unit'],
            'status': 'in_progress',
            'updated_at': '2026-07-18T12:00:00Z',
          },
          agentId: 'a1',
          agentName: 'Codex',
          sourceEndpoint: 'http://127.0.0.1:8765',
        );
        expect(ctx.plan, 'Fix bug');
        expect(ctx.rationaleSummary, 'Root cause identified');
        expect(ctx.recentActions, ['edit src/lib.dart', 'test unit']);
        expect(ctx.status, 'in_progress');
        expect(ctx.updatedAt, DateTime.utc(2026, 7, 18, 12));
        expect(ctx.agentId, 'a1');
        expect(ctx.agentName, 'Codex');
        expect(ctx.sourceEndpoint, 'http://127.0.0.1:8765');
        expect(ctx.error, isNull);
        expect(ctx.hasContent, isTrue);
      });

      test('parses camelCase recentActions key', () {
        final ctx = AgentContext.fromJson(
          {
            'plan': '',
            'recentActions': ['do x'],
          },
          agentId: 'a2',
          agentName: 'Claude',
        );
        expect(ctx.recentActions, ['do x']);
        expect(ctx.hasContent, isTrue);
      });

      test('parses legacy actions key', () {
        final ctx = AgentContext.fromJson(
          {
            'actions': ['step 1'],
          },
          agentId: 'a3',
          agentName: 'Gemini',
        );
        expect(ctx.recentActions, ['step 1']);
      });

      test('parses actions as maps with summary key', () {
        final ctx = AgentContext.fromJson(
          {
            'recent_actions': [
              {'summary': 'Edited file'},
              {'text': 'Ran tests'},
            ],
          },
          agentId: 'a4',
          agentName: 'Agent',
        );
        expect(ctx.recentActions, ['Edited file', 'Ran tests']);
      });

      test('handles legacy reasoning field as rationale summary', () {
        final ctx = AgentContext.fromJson(
          {'reasoning': 'Old chain-of-thought'},
          agentId: 'a5',
          agentName: 'Legacy',
        );
        expect(ctx.rationaleSummary, 'Old chain-of-thought');
      });

      test('rationale_summary takes precedence over reasoning', () {
        final ctx = AgentContext.fromJson(
          {
            'rationale_summary': 'New authored summary',
            'reasoning': 'Old chain-of-thought',
          },
          agentId: 'a6',
          agentName: 'Modern',
        );
        expect(ctx.rationaleSummary, 'New authored summary');
      });

      test('handles missing updated_at gracefully', () {
        final ctx = AgentContext.fromJson(
          {},
          agentId: 'a7',
          agentName: 'NoDate',
        );
        expect(ctx.updatedAt, isNull);
      });

      test('handles camelCase updatedAt', () {
        final ctx = AgentContext.fromJson(
          {'updatedAt': '2026-01-01T00:00:00Z'},
          agentId: 'a8',
          agentName: 'Camel',
        );
        expect(ctx.updatedAt, DateTime.utc(2026));
      });

      test('handles non-String actions gracefully', () {
        final ctx = AgentContext.fromJson(
          {
            'recent_actions': [42, true],
          },
          agentId: 'a9',
          agentName: 'Mixed',
        );
        expect(ctx.recentActions, isEmpty);
      });
    });

    group('AgentContext.unavailable', () {
      test('creates error context with no content', () {
        final ctx = AgentContext.unavailable(
          agentId: 'a1',
          agentName: 'Down',
          error: 'Connection refused',
          sourceEndpoint: 'https://agent.example',
        );
        expect(ctx.hasContent, isFalse);
        expect(ctx.error, 'Connection refused');
        expect(ctx.sourceEndpoint, 'https://agent.example');
        expect(ctx.plan, isEmpty);
      });
    });
  });

  group('FeedbackResult', () {
    test('ok is the primary success indicator', () {
      const success = FeedbackResult(ok: true, deliveryId: 'd-1');
      expect(success.ok, isTrue);
      expect(success.deliveryId, 'd-1');

      const failure = FeedbackResult(ok: false, message: 'timeout');
      expect(failure.ok, isFalse);
      expect(failure.message, 'timeout');
    });

    test('defaults are sensible', () {
      const r = FeedbackResult(ok: false);
      expect(r.message, isEmpty);
      expect(r.clientMessageId, '');
      expect(r.deliveryId, '');
    });
  });
}

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agentforge/core/forgejo/forgejo_client.dart';
import 'package:agentforge/core/forgejo/forgejo_providers.dart';
import 'package:agentforge/core/forgejo/models.dart';
import 'package:agentforge/core/settings/app_settings.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.handler);

  final ResponseBody Function(RequestOptions) handler;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return handler(options);
  }
}

void main() {
  test(
    'request changes requires a review comment before any request',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await expectLater(
        container
            .read(prActionsProvider)
            .submitReview(
              const PrKey('o', 'r', 3),
              event: ReviewEvent.requestChanges,
              expectedHeadSha: 'head',
            ),
        throwsA(
          isA<ForgejoException>().having(
            (error) => error.message,
            'message',
            contains('requires a review comment'),
          ),
        ),
      );
    },
  );

  test('formal review stops when the PR head changed', () async {
    var requests = 0;
    final dio = Dio(BaseOptions(baseUrl: AppSettings.defaultBaseUrl));
    dio.httpClientAdapter = _Adapter((options) {
      requests += 1;
      expect(options.method, 'GET');
      return ResponseBody.fromString(
        '''
        {
          "number": 3,
          "title": "Changed head",
          "state": "open",
          "body": "",
          "head": {"sha": "new-head"},
          "user": {"login": "avi"}
        }
        ''',
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    });
    final client = ForgejoClient(
      settings: const AppSettings(
        baseUrl: AppSettings.defaultBaseUrl,
        token: 'test',
      ),
      dio: dio,
    );
    final container = ProviderContainer(
      overrides: [forgejoClientProvider.overrideWith((ref) async => client)],
    );
    addTearDown(container.dispose);

    await expectLater(
      container
          .read(prActionsProvider)
          .submitReview(
            const PrKey('o', 'r', 3),
            event: ReviewEvent.approve,
            expectedHeadSha: 'old-head',
          ),
      throwsA(
        isA<ForgejoException>().having(
          (e) => e.message,
          'message',
          contains('head changed'),
        ),
      ),
    );
    expect(requests, 1);
  });
}

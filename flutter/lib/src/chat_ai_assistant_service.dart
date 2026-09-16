import 'dart:convert';

import 'package:dio/dio.dart';

/// Talks to the AI backend.
///
/// Expects `ai-sdk-sample` from this repository, running on localhost:3000 —
/// see this sample's README.
class ChatAIAssistantService {
  factory ChatAIAssistantService() => _instance;

  static final _instance = ChatAIAssistantService._();

  ChatAIAssistantService._() : _client = Dio() {
    _client
      ..options.baseUrl = 'http://localhost:3000'
      ..options.headers = {
        'Content-Type': 'application/json',
      }
      ..interceptors.addAll([LogInterceptor()]);
  }

  final Dio _client;

  Future<Response<T>> startAIAgent<T>(
    String channelId, {
    String? platform,
  }) async {
    final result = await _client.post<T>(
      '/start-ai-agent',
      data: jsonEncode({
        'channel_id': channelId,
        if (platform != null) 'platform': platform,
      }),
    );

    return result;
  }

  Future<Response<T>> stopAIAgent<T>(String channelId) async {
    final result = await _client.post<T>(
      '/stop-ai-agent',
      data: jsonEncode({'channel_id': channelId}),
    );

    return result;
  }

  /// Tells the backend which client-side tools this app can run.
  ///
  /// [tools] comes straight from `AIToolRegistry.registrationPayloads()`. The
  /// backend forwards them to the agent SDK's `registerClientTools`, which
  /// *persists* them for the channel and re-applies them whenever its agent
  /// restarts — so this is not something the app has to keep alive.
  ///
  /// The envelope (`channel_id` + `tools`) and the camelCase keys inside each
  /// payload are this backend's; `stream_chat_flutter_ai` ships no HTTP client
  /// and takes no view on either. See `/register-tools` in
  /// `ai-sdk-sample/src/index.ts`.
  Future<void> registerTools(
    String channelId,
    List<Map<String, Object?>> tools,
  ) async {
    if (tools.isEmpty) return;

    await _client.post<void>(
      '/register-tools',
      data: jsonEncode({'channel_id': channelId, 'tools': tools}),
    );
  }

  /// Asks the backend to boil [text] down to a short title.
  ///
  /// Used to name a conversation after its first message, the way the iOS
  /// sample does.
  Future<String?> summarize(
    String text, {
    String? platform,
    String? model,
  }) async {
    final result = await _client.post<Map<String, Object?>>(
      '/summarize',
      data: jsonEncode({
        'text': text,
        if (platform != null) 'platform': platform,
        if (model != null) 'model': model,
      }),
    );

    return result.data?['summary'] as String?;
  }
}

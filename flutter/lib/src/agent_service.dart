import 'package:dio/dio.dart';

/// Talks to the AI backend: `ai-sdk-sample` from this repository.
class AgentService {
  /// On an Android device or emulator, `localhost` is the device itself —
  /// forward the port with `adb reverse tcp:3000 tcp:3000` (see the README).
  static const baseUrl = 'http://localhost:3000';

  final _dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      // Dio waits forever by default, and the first message of a new chat
      // waits on `/start-ai-agent`. That endpoint makes several Stream API
      // calls of its own, hence the roomier receive timeout.
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );

  /// Starts the AI agent in [channelId], which then answers every new message.
  Future<void> startAgent(String channelId, {String? platform}) async {
    await _dio.post<void>('/start-ai-agent', data: {
      'channel_id': channelId,
      if (platform != null) 'platform': platform,
    });
  }

  /// Tells the backend which client-side tools this app can run.
  ///
  /// [tools] comes straight from `AIToolRegistry.registrationPayloads()`. The
  /// backend keeps them for the channel and re-applies them whenever its agent
  /// restarts.
  Future<void> registerTools(String channelId, List<Map<String, Object?>> tools) async {
    if (tools.isEmpty) return;
    await _dio.post<void>('/register-tools', data: {'channel_id': channelId, 'tools': tools});
  }

  /// Asks the backend to boil [text] down to a short conversation title.
  Future<String?> summarize(String text, {String? platform}) async {
    final response = await _dio.post<Map<String, Object?>>('/summarize', data: {
      'text': text,
      if (platform != null) 'platform': platform,
    });
    return response.data?['summary'] as String?;
  }
}

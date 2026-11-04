import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';

/// Talks to the AI backend: `ai-sdk-sample` from this repository.
class AgentService {
  /// Where the backend runs. The Android emulator reaches your machine at
  /// 10.0.2.2, because `localhost` there is the emulator itself.
  ///
  /// On a physical device, run `adb reverse tcp:3000 tcp:3000` and pass
  /// `--dart-define=AGENT_BASE_URL=http://localhost:3000`.
  static final baseUrl = switch (const String.fromEnvironment('AGENT_BASE_URL')) {
    '' when !kIsWeb && defaultTargetPlatform == TargetPlatform.android => 'http://10.0.2.2:3000',
    '' => 'http://localhost:3000',
    final url => url,
  };

  /// [dio] is for tests; the default one talks to [baseUrl].
  AgentService({Dio? dio}) : _dio = dio ?? Dio(_options);

  static final _options = BaseOptions(
    baseUrl: baseUrl,
    // Dio waits forever by default, and the first message of a new chat
    // waits on `/start-ai-agent`. That endpoint makes several Stream API
    // calls of its own, hence the roomier receive timeout.
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 30),
  );

  final Dio _dio;

  /// Starts the AI agent in [channelId], which then answers every new message.
  Future<void> startAgent(String channelId, {String? platform}) async {
    await _dio.post<void>(
      '/start-ai-agent',
      data: {
        'channel_id': channelId,
        if (platform != null) 'platform': platform,
      },
    );
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

  /// Sends the user's answer to an approval. See the README's Agent steps.
  Future<void> answerToolCall({
    required String channelId,
    required AIToolCallPart call,
    required AIToolApprovalDecision decision,
    required AIClientIdentity identity,
  }) async {
    await _dio.post<void>(
      '/tool-approval',
      data: {
        'channel_id': channelId,
        'tool_call_id': call.id,
        'user_id': identity.userId,
        'client_id': ?identity.clientId,
        'decision': decision.value,
      },
    );
  }

  /// Sends what a client tool returned. See the README's Agent steps.
  Future<void> sendToolResult({
    required String channelId,
    required AIToolCallPart call,
    required AIClientToolResult result,
    required String clientId,
  }) async {
    await _dio.post<void>(
      '/tool-results',
      data: {
        'channel_id': channelId,
        ...result.toJson(toolCallId: call.id, clientId: clientId),
      },
    );
  }

  /// Asks the backend to boil [text] down to a short conversation title.
  Future<String?> summarize(String text, {String? platform}) async {
    final response = await _dio.post<Map<String, Object?>>(
      '/summarize',
      data: {
        'text': text,
        if (platform != null) 'platform': platform,
      },
    );
    return response.data?['summary'] as String?;
  }
}

/// Turns a failed [AgentService] call into one line for a snackbar.
///
/// "Backend unreachable" and "backend said no" need different fixes, so they
/// read differently. The response body of the latter goes to the console.
String describeBackendError(Object error) {
  if (error is! DioException) return 'Unexpected error: $error';
  switch (error.type) {
    case DioExceptionType.connectionError:
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
      return 'Backend unreachable. Is ai-sdk-sample running at ${AgentService.baseUrl}?';
    case DioExceptionType.receiveTimeout:
      return 'The backend took too long to respond.';
    case DioExceptionType.badResponse:
      final response = error.response;
      debugPrint('Backend responded ${response?.statusCode}: ${response?.data}');
      return 'The backend returned an error (HTTP ${response?.statusCode}).';
    default:
      return 'Request failed: ${error.message ?? error.type.name}';
  }
}

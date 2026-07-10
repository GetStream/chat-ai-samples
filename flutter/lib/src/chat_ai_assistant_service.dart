import 'dart:convert';

import 'package:dio/dio.dart';

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
}

import 'dart:convert';

import 'package:dio/dio.dart';

class ChatAIAssistantService {
  factory ChatAIAssistantService() => _instance;

  static final _instance = ChatAIAssistantService._();

  ChatAIAssistantService._() : _client = Dio() {
    _client
      ..options.baseUrl = 'https://stream-nodejs-ai-e5d85ed5ce6f.herokuapp.com'
      ..options.headers = {
        'Content-Type': 'application/json',
      }
      ..interceptors.addAll([LogInterceptor()]);
  }

  final Dio _client;

  Future<Response<T>> startAIAgent<T>(String channelId) async {
    final result = await _client.post<T>(
      '/start-ai-agent',
      data: jsonEncode({'channel_id': channelId}),
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

import 'package:flutter/material.dart';
import 'package:stream_chat_ai_assistant_flutter_example/src/chat_ai_assistant_channel_list_page.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';

Future<void> main() async {
  final client = StreamChatClient('zcgvnykxsfm8');

  final user = await client.connectUser(
    User(id: 'anakin_skywalker'),
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjoiYW5ha2luX3NreXdhbGtlciJ9.ZwCV1qPrSAsie7-0n61JQrSEDbp6fcMgVh4V2CB0kM8',
  );

  debugPrint('User connected: ${user.id}');

  runApp(MyApp(client: client));
}

class MyApp extends StatelessWidget {
  const MyApp({
    super.key,
    required this.client,
  });

  final StreamChatClient client;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Stream Chat AI Assistant',
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      themeMode: ThemeMode.light,
      home: const ChatAiAssistantChannelListPage(),
      builder: (_, child) => StreamChat(client: client, child: child),
    );
  }
}

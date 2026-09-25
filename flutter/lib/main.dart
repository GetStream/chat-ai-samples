import 'package:flutter/material.dart';
import 'package:stream_chat_ai_assistant_flutter_example/src/home_page.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Use the same Stream app as the backend. The token must be signed with
  // that app's secret.
  final client = StreamChatClient('zcgvnykxsfm8');
  await client.connectUser(
    User(id: 'anakin_skywalker'),
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjoiYW5ha2luX3NreXdhbGtlciJ9.ZwCV1qPrSAsie7-0n61JQrSEDbp6fcMgVh4V2CB0kM8',
  );

  runApp(MyApp(client: client));
}

class MyApp extends StatefulWidget {
  const MyApp({super.key, required this.client});

  final StreamChatClient client;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // The assistant can change this through the `setThemeMode` client tool.
  // Ask it to switch to dark mode.
  var _themeMode = ThemeMode.light;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Stream Chat AI Assistant',
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      themeMode: _themeMode,
      builder: (context, child) => StreamChat(client: widget.client, child: child),
      home: HomePage(
        client: widget.client,
        onThemeModeChanged: (mode) => setState(() => _themeMode = mode),
      ),
    );
  }
}

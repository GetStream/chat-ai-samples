import 'package:flutter/material.dart';
import 'package:stream_chat_ai_assistant_flutter_example/src/chat_ai_assistant_channel_page.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';

class ChatAiAssistantChannelListPage extends StatefulWidget {
  const ChatAiAssistantChannelListPage({super.key});

  @override
  State<ChatAiAssistantChannelListPage> createState() =>
      _ChatAiAssistantChannelListPageState();
}

class _ChatAiAssistantChannelListPageState
    extends State<ChatAiAssistantChannelListPage> {
  // Create a channel list controller to fetch the channels.
  late final _controller = StreamChannelListController(
    client: StreamChat.of(context).client,
    filter: Filter.in_(
      'members',
      [StreamChat.of(context).currentUser!.id],
    ),
    presence: true,
    limit: 30,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Assistant Channels'),
      ),
      body: StreamChannelListView(
        controller: _controller,
        onChannelTap: (channel) {
          // Navigate to the chat page when a channel is tapped on.
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) {
                return ChatAIAssistantChannelPage(
                  channel: channel,
                );
              },
            ),
          );
        },
      ),
    );
  }
}

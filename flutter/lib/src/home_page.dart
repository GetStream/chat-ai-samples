import 'dart:async';

import 'package:flutter/material.dart';
import 'package:stream_chat_ai_assistant_flutter_example/src/agent_service.dart';
import 'package:stream_chat_ai_assistant_flutter_example/src/client_tools.dart';
import 'package:stream_chat_ai_assistant_flutter_example/src/connection_banner.dart';
import 'package:stream_chat_ai_assistant_flutter_example/src/conversation_view.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';

/// Prompts offered on the "new chat" screen, sent as-is when tapped.
const _landingSuggestions = [
  'Create a painting in Renaissance-style',
  'Create a workout plan for resistance training',
  'Find the decade that a photo is from',
  'Help me study vocabulary for an exam',
  'Tell me the best stocks to invest',
  'Top 5 restaurants in New York',
];

/// Modes offered in the composer's "+" sheet, next to the photo picker.
const _chatOptions = [
  ChatOption(
    id: 'image',
    text: 'Create image',
    description: 'Visualize anything',
    icon: Icons.palette_outlined,
  ),
  ChatOption(
    id: 'research',
    text: 'Deep research',
    description: 'Get a detailed report',
    icon: Icons.travel_explore,
  ),
  ChatOption(
    id: 'search',
    text: 'Web search',
    description: 'Find real-time news and info',
    icon: Icons.public,
  ),
  ChatOption(
    id: 'study',
    text: 'Study and learn',
    description: 'Learn a new concept',
    icon: Icons.menu_book_outlined,
  ),
  ChatOption(
    id: 'agent',
    text: 'Agent mode',
    description: 'Get work done for you',
    icon: Icons.smart_toy_outlined,
  ),
  ChatOption(
    id: 'files',
    text: 'Add files',
    description: 'Analyze or summarize',
    icon: Icons.folder_zip_outlined,
  ),
];

/// Using OpenAI because that's the key the local backend's `.env` sets up.
const _aiPlatform = 'openai';

/// The app's only screen.
///
/// A persistent composer sits at the bottom. Above it is either the "new chat"
/// view or the active conversation. Past conversations are in a drawer, opened
/// by swiping from the left edge.
class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.client, required this.onThemeModeChanged});

  final StreamChatClient client;

  /// Called when the assistant asks the app to switch themes.
  final ValueChanged<ThemeMode> onThemeModeChanged;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _agentService = AgentService();
  final _composerController = ChatComposerController(chatOptions: _chatOptions);
  Channel? _activeChannel;

  /// The client-side tools this app offers the AI agent, the same in every
  /// conversation.
  late final _toolRegistry = AIToolRegistry()
    ..register(GreetUserTool(onGreet: _showGreeting))
    ..register(SetThemeModeTool(onChange: widget.onThemeModeChanged));

  /// Listens on the client, so it keeps working across conversations.
  late final ClientToolListener _toolListener;

  late final _channelListController = StreamChannelListController(
    client: widget.client,
    filter: Filter.in_('members', [widget.client.state.currentUser!.id]),
    limit: 30,
  );

  @override
  void initState() {
    super.initState();
    _toolListener = ClientToolListener(client: widget.client, registry: _toolRegistry);
  }

  @override
  void dispose() {
    _toolListener.dispose();
    _channelListController.dispose();
    _composerController.dispose();
    super.dispose();
  }

  void _showGreeting() {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Greetings!'),
        content: const Text('👋 Hello there! The assistant asked me to greet you.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Starts the AI agent for [channel] and registers the client tools with it.
  Future<void> _ensureAgentStarted(Channel channel) async {
    final channelId = channel.id;
    if (channelId == null) return;

    try {
      await _agentService.startAgent(channelId, platform: _aiPlatform);
      // Registering again for a channel the backend already knows is harmless,
      // and keeps it in sync with the tools this build has.
      await _agentService.registerTools(channelId, _toolRegistry.registrationPayloads());
    } catch (e) {
      debugPrint('Failed to start the AI agent: $e');
      // Without this, the app looks fine but the assistant never replies.
      _showError(
        "Couldn't start the assistant. Is ai-sdk-sample running at ${AgentService.baseUrl}?",
      );
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  /// Names a new conversation after its first message.
  Future<void> _setChannelTitle(Channel channel, String firstMessage) async {
    var title = firstMessage.length > 40 ? '${firstMessage.substring(0, 40)}…' : firstMessage;
    try {
      final summary = await _agentService.summarize(firstMessage, platform: _aiPlatform);
      if (summary != null && summary.trim().isNotEmpty) title = summary.trim();
    } catch (e) {
      debugPrint('Failed to summarize the title, using the message: $e');
    }

    try {
      await channel.updatePartial(set: {'name': title});
    } catch (e) {
      debugPrint('Failed to set the channel title: $e');
    }
  }

  Future<void> _sendMessage(
    String text, {
    ChatOption? option,
    List<XFile> attachments = const [],
  }) async {
    if (text.trim().isEmpty && attachments.isEmpty) return;

    var channel = _activeChannel;
    final isNewChannel = channel == null;
    if (channel == null) {
      channel = widget.client.channel(
        'messaging',
        id: const Uuid().v4(),
        extraData: {
          'members': [widget.client.state.currentUser!.id],
        },
      );
      await channel.watch();
      if (!mounted) return;
      setState(() => _activeChannel = channel);
      // Wait for the agent before sending: it only answers messages that
      // arrive after it has started.
      await _ensureAgentStarted(channel);
    }

    // `sendMessage` uploads the attachments itself.
    final messageAttachments = await Future.wait(
      attachments.map((file) => file.toAttachment(type: AttachmentType.image)),
    );
    await channel.sendMessage(
      Message(
        text: option == null ? text : '${option.text}: $text',
        attachments: messageAttachments,
      ),
    );

    if (isNewChannel) {
      unawaited(_setChannelTitle(channel, text.trim().isNotEmpty ? text : 'Photo'));
    }
  }

  Future<void> _stopResponse() async {
    try {
      await _activeChannel?.stopAIResponse();
    } catch (e) {
      debugPrint('Failed to stop the AI response: $e');
      _showError("Couldn't stop the reply.");
    }
  }

  void _openChannel(Channel? channel) {
    Navigator.of(context).pop(); // close the drawer
    setState(() => _activeChannel = channel);
    // The next conversation view reports its own state once it's listening.
    _composerController.isGenerating = false;
    if (channel == null) {
      _composerController.clear();
    } else {
      unawaited(_ensureAgentStarted(channel));
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeChannel = _activeChannel;

    return Scaffold(
      drawer: _ConversationDrawer(
        controller: _channelListController,
        onChannelSelected: _openChannel,
      ),
      // The composer is in the body rather than `bottomNavigationBar`, because
      // only the body moves up when the keyboard opens.
      body: SafeArea(
        child: Column(
          children: [
            const ConnectionBanner(),
            Expanded(
              child: activeChannel == null
                  ? _LandingView(onSuggestionTap: _sendMessage)
                  : ConversationView(
                      key: ValueKey(activeChannel.cid),
                      channel: activeChannel,
                      onGeneratingChanged: (isGenerating) =>
                          _composerController.isGenerating = isGenerating,
                    ),
            ),
            ChatComposer(
              controller: _composerController,
              enableSpeechToText: true,
              onSendPressed: (text, option, attachments) =>
                  _sendMessage(text, option: option, attachments: attachments),
              onStopPressed: _stopResponse,
            ),
          ],
        ),
      ),
    );
  }
}

/// The conversation history: a "New chat" button and the user's channels.
class _ConversationDrawer extends StatelessWidget {
  const _ConversationDrawer({required this.controller, required this.onChannelSelected});

  final StreamChannelListController controller;

  /// Called with the chosen channel, or `null` for a new chat.
  final ValueChanged<Channel?> onChannelSelected;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            ListTile(
              leading: const Icon(Icons.add_comment_outlined),
              title: const Text('New chat'),
              onTap: () => onChannelSelected(null),
            ),
            const Divider(height: 1),
            Expanded(
              child: StreamChannelListView(
                controller: controller,
                itemBuilder: (context, items, index, defaultWidget) {
                  final channel = items[index];
                  return ListTile(
                    title: Text(channel.name ?? channel.id ?? ''),
                    onTap: () => onChannelSelected(channel),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The "new chat" screen: suggestion chips just above the composer.
class _LandingView extends StatelessWidget {
  const _LandingView({required this.onSuggestionTap});

  final ValueChanged<String> onSuggestionTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Spacer(),
        AISuggestionsView(
          suggestions: _landingSuggestions,
          itemMaxWidth: 190,
          onSuggestionSelected: onSuggestionTap,
        ),
      ],
    );
  }
}

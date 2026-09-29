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

  /// Set while a new conversation is being created, so a second tap on send
  /// or a suggestion can't create a second channel.
  bool _isStartingChannel = false;

  /// One start per channel, shared by everything that needs the agent: the
  /// send path waits on the same future the drawer started. Failed starts are
  /// removed, so the next send tries again.
  final _agentStarts = <String, Future<bool>>{};

  /// Channels whose agent is still starting, for the progress hint.
  final _startingAgents = <String>{};

  /// The client-side tools this app offers the AI agent, the same in every
  /// conversation.
  late final _toolRegistry = AIToolRegistry(onToolError: _onToolError)
    ..register(GreetUserTool(onGreet: _showGreeting))
    ..register(SetThemeModeTool(onChange: widget.onThemeModeChanged));

  /// Listens on the client, so it keeps working across conversations.
  late final ClientToolListener _toolListener;

  late final _channelListController = StreamChannelListController(
    client: widget.client,
    filter: Filter.in_('members', [_currentUserId]),
    limit: 30,
  );

  /// `main` only builds this page after `connectUser` succeeded.
  String get _currentUserId {
    final user = widget.client.state.currentUser;
    assert(user != null, 'HomePage needs a connected user');
    return user?.id ?? '';
  }

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
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK')),
        ],
      ),
    );
  }

  void _onToolError(AIToolInvocation invocation, Object error, StackTrace stack) {
    _showError('The assistant\'s "${invocation.tool.name}" action failed.');
  }

  /// Starts the AI agent for [channel] and registers the client tools with it.
  ///
  /// Returns whether the agent is running. Concurrent callers share one start.
  Future<bool> _ensureAgentStarted(Channel channel) {
    final channelId = channel.id;
    if (channelId == null) return Future.value(false);

    return _agentStarts.putIfAbsent(channelId, () async {
      if (mounted) setState(() => _startingAgents.add(channelId));
      final started = await _startAgent(channelId);
      if (!started) unawaited(_agentStarts.remove(channelId));
      if (mounted) setState(() => _startingAgents.remove(channelId));
      return started;
    });
  }

  Future<bool> _startAgent(String channelId) async {
    try {
      await _agentService.startAgent(channelId, platform: _aiPlatform);
    } catch (e) {
      debugPrint('Failed to start the AI agent: $e');
      // Without this, the app looks fine but the assistant never replies.
      _showError("Couldn't start the assistant. ${describeBackendError(e)}");
      return false;
    }

    try {
      // Registering again for a channel the backend already knows is harmless,
      // and keeps it in sync with the tools this build has.
      await _agentService.registerTools(channelId, _toolRegistry.registrationPayloads());
    } catch (e) {
      debugPrint('Failed to register client tools: $e');
      _showError(
        "The assistant is running, but can't use app actions like switching the theme. "
        '${describeBackendError(e)}',
      );
    }
    return true;
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

  /// Puts an unsent message back in the composer, which empties itself as soon
  /// as send is pressed. Skipped if the user has already typed something new.
  void _restoreComposer(String text, ChatOption? option, List<XFile> attachments) {
    if (!mounted || _composerController.hasContent) return;
    _composerController.textEditingController.text = text;
    _composerController.addAttachments(attachments);
    if (option != null) _composerController.selectChatOption(option);
  }

  Future<void> _sendMessage(
    String text, {
    ChatOption? option,
    List<XFile> attachments = const [],
  }) async {
    if (text.trim().isEmpty && attachments.isEmpty) return;
    if (_isStartingChannel) {
      _restoreComposer(text, option, attachments);
      return;
    }

    var channel = _activeChannel;
    if (channel == null) {
      _isStartingChannel = true;
      try {
        channel = widget.client.channel(
          'messaging',
          id: const Uuid().v4(),
          extraData: {
            'members': [_currentUserId],
          },
        );
        await channel.watch();
      } catch (e) {
        debugPrint('Failed to create the conversation: $e');
        _showError("Couldn't start a new conversation. Check your connection and try again.");
        _restoreComposer(text, option, attachments);
        return;
      } finally {
        _isStartingChannel = false;
      }
      if (!mounted) return;
      setState(() => _activeChannel = channel);
    }

    // Wait for the agent before sending: it only answers messages that
    // arrive after it has started. If it can't start, keep the message in the
    // composer rather than send it to a channel nobody will answer in.
    if (!await _ensureAgentStarted(channel)) {
      _restoreComposer(text, option, attachments);
      return;
    }

    final isNewChannel = channel.state?.messages.isEmpty ?? true;
    try {
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
    } catch (e) {
      debugPrint('Failed to send the message: $e');
      _showError("Couldn't send your message. Please try again.");
      _restoreComposer(text, option, attachments);
      return;
    }

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
            if (_startingAgents.contains(activeChannel?.id)) const _StartingAssistantHint(),
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

/// A thin progress bar and a label above the composer while the agent starts.
class _StartingAssistantHint extends StatelessWidget {
  const _StartingAssistantHint();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const LinearProgressIndicator(minHeight: 2),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Text('Starting assistant…', style: Theme.of(context).textTheme.bodySmall),
        ),
      ],
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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';

import 'agent_service.dart';
import 'agent_starter.dart';
import 'agent_steps.dart';
import 'client_tools.dart';
import 'connection_banner.dart';
import 'conversation_view.dart';
import 'draft_channel.dart';
import 'home_layout.dart';

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
/// by swiping from the left edge, or a side panel on wide screens.
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

  /// The new conversation being opened, if any. A second send while it is in
  /// flight waits on it, so it neither creates a second channel nor gets lost.
  Future<Channel?>? _channelCreation;

  /// The next new conversation, created while its first message is typed.
  late final _draftChannel = DraftChannel(create: _createChannel);

  /// Channels whose first message already claimed the title, so two messages
  /// sent before the title exists only title the conversation once.
  final _titleClaims = <String>{};

  late final _agentStarter = AgentStarter(
    agentService: _agentService,
    toolPayloads: _toolRegistry.registrationPayloads,
    onError: _showError,
    platform: _aiPlatform,
  );

  /// The client-side tools this app offers the AI agent, the same in every
  /// conversation.
  late final _clientTools = <AIClientTool>[
    GreetUserTool(onGreet: _showGreeting),
    SetThemeModeTool(onChange: widget.onThemeModeChanged),
    const LocalTimeTool(),
  ];

  /// Runs the tools invoked by `custom_client_tool_invocation` events.
  late final _toolRegistry = AIToolRegistry(onToolError: _onToolError);

  /// The user and install that tool calls in agent steps are matched against.
  late final _identity = AIClientIdentity(userId: _currentUserId, clientId: clientId);

  /// Listens on the client, so it keeps working across conversations.
  late final ClientToolListener _toolListener;

  /// What answers each conversation's tool calls.
  late final _agentSteps = AgentStepsByChannel(
    (channel) => ConversationAgentSteps(
      channelId: channel.id!,
      identity: _identity,
      tools: _clientTools,
      agentService: _agentService,
      onError: _showError,
    ),
  );

  late final _channelListController = StreamChannelListController(
    client: widget.client,
    // Leaves out drafts: channels prepared for a chat that was never sent in.
    filter: Filter.and([
      Filter.in_('members', [_currentUserId]),
      Filter.exists('last_message_at'),
    ]),
    eventHandler: _SentChannelsEventHandler(),
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
    _clientTools.forEach(_toolRegistry.register);
    _toolListener = ClientToolListener(client: widget.client, registry: _toolRegistry);
    _agentStarter.addListener(_onAgentStartsChanged);
    _composerController.textEditingController.addListener(_onComposerTextChanged);
  }

  @override
  void dispose() {
    _composerController.textEditingController.removeListener(_onComposerTextChanged);
    _draftChannel.dispose();
    _agentStarter.dispose();
    _toolListener.dispose();
    _channelListController.dispose();
    _composerController.dispose();
    _agentSteps.dispose();
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

  /// Rebuilds for the "Starting assistant…" hint.
  void _onAgentStartsChanged() {
    if (mounted) setState(() {});
  }

  /// Prepares a new chat's channel and agent while its first message is typed.
  void _onComposerTextChanged() {
    if (_activeChannel != null) return;
    _draftChannel.onTextChanged(_composerController.textEditingController.text);
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

  /// Creates a channel for a new conversation and starts its agent, without
  /// waiting for the agent.
  Future<Channel> _createChannel() async {
    final channel = widget.client.channel(
      'messaging',
      id: const Uuid().v4(),
      extraData: {
        'members': [_currentUserId],
      },
    );
    await channel.watch();
    // Nobody can be watching a channel that didn't exist a moment ago. The
    // send path reports a failure, and tries again.
    unawaited(_agentStarter.ensureStarted(channel, checkPresence: false, reportErrors: false));
    return channel;
  }

  /// Goes back to the new-chat screen when a new conversation's first message
  /// couldn't go out, rather than leave an empty conversation open.
  void _leaveIfEmpty(Channel channel) {
    if (!mounted || _activeChannel != channel) return;
    if (channel.state?.messages.isNotEmpty ?? false) return;
    _draftChannel.restore(channel);
    setState(() => _activeChannel = null);
  }

  /// Opens a new conversation, the draft if there is one, or returns null
  /// after showing an error. Concurrent senders share one call through
  /// [_channelCreation].
  Future<Channel?> _openNewChannel() async {
    try {
      final channel = await _draftChannel.take();
      if (!mounted) return null;
      setState(() => _activeChannel = channel);
      return channel;
    } catch (e) {
      debugPrint('Failed to create the conversation: $e');
      _showError("Couldn't start a new conversation. Check your connection and try again.");
      return null;
    } finally {
      _channelCreation = null;
    }
  }

  Future<void> _sendMessage(
    String text, {
    ChatOption? option,
    List<XFile> attachments = const [],
  }) async {
    if (text.trim().isEmpty && attachments.isEmpty) return;

    var channel = _activeChannel;
    if (channel == null) {
      channel = await (_channelCreation ??= _openNewChannel());
      if (channel == null) {
        _restoreComposer(text, option, attachments);
        return;
      }
    }

    // Wait for the agent before sending: it only answers messages that
    // arrive after it has started. If it can't start, keep the message in the
    // composer rather than send it to a channel nobody will answer in.
    if (!await _agentStarter.ensureStarted(channel)) {
      _leaveIfEmpty(channel);
      _restoreComposer(text, option, attachments);
      return;
    }

    final cid = channel.cid!;
    final titleIt = (channel.state?.messages.isEmpty ?? true) && _titleClaims.add(cid);
    try {
      // `sendMessage` uploads the attachments itself.
      final messageAttachments = await Future.wait(
        attachments.map((file) => file.toAttachment(type: AttachmentType.image)),
      );
      await channel.sendMessage(
        Message(
          text: option == null ? text : '${option.text}: $text',
          attachments: messageAttachments,
          // Tells the agent which install to send client tool calls to.
          extraData: {'client_id': clientId},
        ),
      );
    } catch (e) {
      debugPrint('Failed to send the message: $e');
      _showError("Couldn't send your message. Please try again.");
      if (titleIt) _titleClaims.remove(cid);
      _leaveIfEmpty(channel);
      _restoreComposer(text, option, attachments);
      return;
    }

    if (titleIt) {
      unawaited(_setChannelTitle(channel, text.trim().isNotEmpty ? text : 'Photo'));
    }
  }

  Future<void> _stopResponse() async {
    // Don't wait for the rest of the reply to type out: the user asked to stop.
    _composerController.isGenerating = false;
    try {
      await _activeChannel?.stopAIResponse();
    } catch (e) {
      debugPrint('Failed to stop the AI response: $e');
      // Still replying, so stop can be pressed again.
      _composerController.isGenerating = true;
      _showError("Couldn't stop the reply.");
    }
  }

  void _openChannel(Channel? channel) {
    setState(() => _activeChannel = channel);
    // The next conversation view reports its own state once it's listening.
    _composerController.isGenerating = false;
    if (channel == null) {
      _composerController.clear();
    } else {
      unawaited(_agentStarter.ensureStarted(channel));
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeChannel = _activeChannel;

    return HomeLayout(
      history: _ConversationHistory(
        controller: _channelListController,
        activeChannel: activeChannel,
        onChannelSelected: _openChannel,
      ),
      body: Column(
        children: [
          const ConnectionBanner(),
          Expanded(
            child: activeChannel == null
                ? _LandingView(onSuggestionTap: _sendMessage)
                : ConversationView(
                    key: ValueKey(activeChannel.cid),
                    channel: activeChannel,
                    agentSteps: _agentSteps.of(activeChannel),
                    onGeneratingChanged: (isGenerating) => _composerController.isGenerating = isGenerating,
                  ),
          ),
          if (_agentStarter.isStarting(activeChannel?.id)) const _StartingAssistantHint(),
          ChatComposer(
            controller: _composerController,
            enableSpeechToText: true,
            onSendPressed: (text, option, attachments) => _sendMessage(text, option: option, attachments: attachments),
            onStopPressed: _stopResponse,
          ),
        ],
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
class _ConversationHistory extends StatelessWidget {
  const _ConversationHistory({required this.controller, required this.activeChannel, required this.onChannelSelected});

  final StreamChannelListController controller;

  /// Highlighted in the side panel.
  final Channel? activeChannel;

  /// Called with the chosen channel, or `null` for a new chat.
  final ValueChanged<Channel?> onChannelSelected;

  void _select(BuildContext context, Channel? channel) {
    // Does nothing in the side panel, which has no drawer.
    Scaffold.maybeOf(context)?.closeDrawer();
    onChannelSelected(channel);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.add_comment_outlined),
          title: const Text('New chat'),
          onTap: () => _select(context, null),
        ),
        const Divider(height: 1),
        Expanded(
          child: StreamChannelListView(
            controller: controller,
            itemBuilder: (context, items, index, defaultWidget) {
              final channel = items[index];
              return ListTile(
                title: Text(channel.name ?? channel.id ?? ''),
                selected: channel.cid == activeChannel?.cid,
                onTap: () => _select(context, channel),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Keeps drafts out of the history, as its query's filter does: the default
/// adds every channel the user is added to, including a fresh draft.
class _SentChannelsEventHandler extends StreamChannelListEventHandler {
  @override
  void onNotificationAddedToChannel(Event event, StreamChannelListController controller) {
    if (event.channel?.lastMessageAt == null) return;
    super.onNotificationAddedToChannel(event, controller);
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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:stream_chat_ai_assistant_flutter_example/src/chat_ai_assistant_channel_page.dart';
import 'package:stream_chat_ai_assistant_flutter_example/src/chat_ai_assistant_service.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart'
    hide
        StreamingMessageView,
        AITypingIndicatorView,
        TypewriterState,
        TypewriterController,
        StreamTypewriterBuilder;
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';

/// Prompts shown on the landing (no active channel) screen, sent verbatim on
/// tap. Mirrors the iOS sample's hardcoded `predefinedOptions`
/// (`ContentView.swift`), which is a static list there too — not a dynamic
/// feature (confirmed by `stream-chat-swift-ai`'s `SuggestionsView`, which
/// just renders whatever string array it's given, in order, no
/// filtering/randomization).
const _landingSuggestions = [
  'Create a painting in Renaissance-style',
  'Create a workout plan for resistance training',
  'Find the decade that a photo is from',
  'Help me study vocabulary for an exam',
  'Tell me the best stocks to invest',
  'Top 5 restaurants in New York',
];

/// Modes offered from the composer's leading "+" sheet, mirroring
/// `stream-chat-swift-ai`'s `ComposerPickerView` chat-options section
/// (`ComposerView.swift`). Distinct from [_landingSuggestions] above — this
/// list is reachable via the "+" button at any time, not just on the landing
/// screen.
const _chatOptions = [
  ChatOption(id: 'summarize', text: 'Summarize', icon: Icons.summarize_outlined),
  ChatOption(id: 'web_search', text: 'Web search', icon: Icons.public),
  ChatOption(id: 'deep_research', text: 'Deep research', icon: Icons.travel_explore),
  ChatOption(id: 'write_email', text: 'Write an email', icon: Icons.email_outlined),
];

/// The app's single entry-point screen.
///
/// A persistent composer sits at the bottom; the content area switches
/// between a "new chat" landing view (no active channel) and the active
/// conversation. Channel history lives in a drawer reached by edge-swipe —
/// there is deliberately no app bar, mirroring the iOS sample's
/// `ContentView.mainConversation()` + `SidebarView`/`ConversationListView`,
/// which has no navigation title/toolbar in its chat screens either.
class ChatAIAssistantHomePage extends StatefulWidget {
  const ChatAIAssistantHomePage({super.key});

  @override
  State<ChatAIAssistantHomePage> createState() =>
      _ChatAIAssistantHomePageState();
}

class _ChatAIAssistantHomePageState extends State<ChatAIAssistantHomePage> {
  Channel? _activeChannel;

  late final _channelListController = StreamChannelListController(
    client: StreamChat.of(context).client,
    filter: Filter.in_(
      'members',
      [StreamChat.of(context).currentUser!.id],
    ),
    presence: true,
    limit: 30,
  );

  // Chat options are surfaced through the composer's leading "+" sheet
  // (`_showChatOptionsSheet`) rather than as an always-visible chip row —
  // matches iOS's `ComposerPickerView`, which only shows them inside the
  // sheet opened by the "+" button.
  final _composerController = AiComposerController();

  @override
  void dispose() {
    _channelListController.dispose();
    _composerController.dispose();
    super.dispose();
  }

  Future<void> _ensureAgentStarted(Channel channel) async {
    final channelId = channel.id;
    if (channelId == null) return;

    try {
      // Using OpenAI since that's the key set up in the local backend's
      // .env; swap or make configurable if the deployed backend needs a
      // different platform.
      await ChatAIAssistantService().startAIAgent(channelId, platform: 'openai');
    } catch (e) {
      debugPrint('Failed to start AI agent: $e');
    }
  }

  Future<void> _maybeSetLocalTitle(Channel channel, String firstMessage) async {
    // Best-effort local title. Unlike the iOS sample, which calls a
    // `/summarize` backend endpoint to AI-generate a title, this stays
    // entirely client-side — no backend changes for this sample.
    final title = firstMessage.length > 40 ? '${firstMessage.substring(0, 40)}…' : firstMessage;
    try {
      await channel.updatePartial(set: {'name': title});
    } catch (e) {
      debugPrint('Failed to set local channel title: $e');
    }
  }

  Future<void> _sendMessage(String text, {ChatOption? option}) async {
    if (text.trim().isEmpty) return;

    final message = switch (option) {
      final option? => '${option.text}: $text',
      null => text,
    };

    var channel = _activeChannel;
    final isNewChannel = channel == null;
    if (channel == null) {
      final client = StreamChat.of(context).client;
      final currentUserId = StreamChat.of(context).currentUser!.id;
      channel = client.channel(
        'messaging',
        id: const Uuid().v4(),
        extraData: {
          'members': [currentUserId],
        },
      );
      await channel.watch();
      if (!mounted) return;
      setState(() => _activeChannel = channel);
      unawaited(_ensureAgentStarted(channel));
    }

    await channel.sendMessage(Message(text: message));

    if (isNewChannel) {
      unawaited(_maybeSetLocalTitle(channel, text));
    }
  }

  void _selectChannel(Channel channel) {
    Navigator.of(context).pop(); // close the drawer
    setState(() => _activeChannel = channel);
    unawaited(_ensureAgentStarted(channel));
  }

  void _startNewConversation() {
    Navigator.of(context).pop(); // close the drawer
    setState(() => _activeChannel = null);
    _composerController.clear();
  }

  Future<void> _showChatOptionsSheet(BuildContext context) async {
    final selected = await showModalBottomSheet<ChatOption>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final option in _chatOptions)
              ListTile(
                leading: Icon(option.icon),
                title: Text(option.text),
                onTap: () => Navigator.of(context).pop(option),
              ),
          ],
        ),
      ),
    );

    if (selected != null) _composerController.selectChatOption(selected);
  }

  @override
  Widget build(BuildContext context) {
    final activeChannel = _activeChannel;

    return Scaffold(
      // No AppBar — matches the iOS sample, which sets no navigation title or
      // toolbar in its chat screens. The drawer below is reached purely via
      // Flutter's default edge-swipe gesture.
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.add_comment_outlined),
                title: const Text('New chat'),
                onTap: _startNewConversation,
              ),
              const Divider(height: 1),
              Expanded(
                child: StreamChannelListView(
                  controller: _channelListController,
                  // A plain-text row — mirrors iOS's minimal "Conversations"
                  // list (`ConversationListView`), which shows just channel
                  // names with no avatars/previews/timestamps/unread badges.
                  itemBuilder: (context, items, index, defaultWidget) {
                    final channel = items[index];
                    return ListTile(
                      title: Text(channel.name ?? channel.id ?? ''),
                      onTap: () => _selectChannel(channel),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: activeChannel == null
            ? _LandingView(onSuggestionTap: _sendMessage)
            : ChatAIAssistantConversationView(
                key: ValueKey(activeChannel.cid),
                channel: activeChannel,
              ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(8),
        child: StreamAIComposer(
          controller: _composerController,
          enableSpeechToText: true,
          onSendPressed: (text, option) => _sendMessage(text, option: option),
          onStopPressed: () => _activeChannel?.stopAIResponse(),
          factory: _AIComposerFactory(
            onOptionsPressed: () => _showChatOptionsSheet(context),
          ),
        ),
      ),
    );
  }
}

/// The "new chat" landing screen: a horizontally-scrollable row of prompt
/// suggestions above the (always-docked) composer. Tapping one sends it
/// immediately — mirrors the iOS sample's `SuggestionsView`.
class _LandingView extends StatelessWidget {
  const _LandingView({required this.onSuggestionTap});

  final ValueChanged<String> onSuggestionTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        const Spacer(),
        // `IntrinsicHeight` + a plain `Row` (rather than a fixed-height
        // `ListView`) lets each chip size to its own 2-line text instead of
        // being hard-clipped to an arbitrary box height.
        IntrinsicHeight(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final suggestion in _landingSuggestions) ...[
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 160),
                    child: Material(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => onSuggestionTap(suggestion),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            suggestion,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.left,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Supplies the composer's leading "+" (opens the chat-options sheet).
///
/// Mirrors iOS's `AddAttachmentsButton` in `ComposerView.swift`, minus real
/// photo/camera attachment upload — `stream_chat_flutter_ai`'s
/// `AiComposerController` has no attachment state today, so that part is a
/// follow-up (either a package enhancement or a sample-only bypass), not part
/// of this pass. The voice/send toggle is handled by the composer itself via
/// `enableSpeechToText: true`, not this factory.
class _AIComposerFactory extends StreamAIComposerFactory {
  const _AIComposerFactory({required this.onOptionsPressed});

  final VoidCallback onOptionsPressed;

  @override
  Widget buildLeading(BuildContext context, AiComposerController controller) {
    return IconButton(
      icon: const Icon(Icons.add_circle_outline),
      onPressed: onOptionsPressed,
    );
  }
}

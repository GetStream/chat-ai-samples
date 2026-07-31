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

/// Modes offered in the composer's attachment sheet (opened via the "+"
/// button — see `ComposerAttachmentSheet`), alongside the photo picker.
/// Mirrors `createChatOptions()` in the iOS sample's `ContentView.swift`,
/// which populates `ComposerViewModel.chatOptions` with this same six-option
/// set (title/description/icon) — that file also marks the array
/// `// TODO: extract this.`, i.e. even upstream treats the concrete content
/// as sample-only, not finalized.
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
    filter: Filter.in_('members', [StreamChat.of(context).currentUser!.id]),
    presence: true,
    limit: 30,
  );

  final _composerController = ChatComposerController(chatOptions: _chatOptions);

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
      await ChatAIAssistantService().startAIAgent(
        channelId,
        platform: 'openai',
      );
    } catch (e) {
      debugPrint('Failed to start AI agent: $e');
    }
  }

  Future<void> _maybeSetLocalTitle(Channel channel, String firstMessage) async {
    // Best-effort local title. Unlike the iOS sample, which calls a
    // `/summarize` backend endpoint to AI-generate a title, this stays
    // entirely client-side — no backend changes for this sample.
    final title = firstMessage.length > 40
        ? '${firstMessage.substring(0, 40)}…'
        : firstMessage;
    try {
      await channel.updatePartial(set: {'name': title});
    } catch (e) {
      debugPrint('Failed to set local channel title: $e');
    }
  }

  Future<void> _sendMessage(
    String text, {
    ChatOption? option,
    List<XFile> attachments = const [],
  }) async {
    if (text.trim().isEmpty && attachments.isEmpty) return;

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
      // Must be awaited, not fire-and-forget: the backend's AI agent only
      // registers a live `message.new` listener in `agent.init()` — it never
      // replays channel history. `_ensureAgentStarted` needs ~3 sequential
      // Stream API round-trips (upsertUser, addMembers, channel.watch())
      // before that listener exists, while `channel.sendMessage` below is a
      // single round-trip — so firing it without awaiting almost always won
      // the race and left the agent listening one message too late.
      await _ensureAgentStarted(channel);
    }

    // `channel.sendMessage` uploads any not-yet-uploaded attachment (via
    // `sendImage`/`sendFile`) before posting, so `toAttachment` only needs to
    // wrap the picked file — no manual upload call needed.
    final messageAttachments = await Future.wait(
      attachments.map((file) => file.toAttachment(type: AttachmentType.image)),
    );

    await channel.sendMessage(
      Message(text: message, attachments: messageAttachments),
    );

    if (isNewChannel) {
      unawaited(
        _maybeSetLocalTitle(channel, text.trim().isNotEmpty ? text : 'Photo'),
      );
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
        // No `minimum` padding here — `ChatComposer` now supplies its own
        // 8px margin internally; adding one here too would double it up.
        child: ChatComposer(
          controller: _composerController,
          enableSpeechToText: true,
          onSendPressed: (text, option, attachments) =>
              _sendMessage(text, option: option, attachments: attachments),
          onStopPressed: () => _activeChannel?.stopAIResponse(),
        ),
      ),
    );
  }
}

/// The "new chat" landing screen: an `AISuggestionsView` row docked
/// above the (always-docked) composer. Tapping a chip sends it immediately —
/// mirrors the iOS sample's `VStack { Spacer(); SuggestionsView(...) }`.
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

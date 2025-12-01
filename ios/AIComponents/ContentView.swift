//
//  ContentView.swift
//  AIComponents
//
//  Created by Martin Mitrevski on 24.10.25.
//

import Combine
import MCP
import SwiftUI
import StreamChat
import StreamChatAI
import StreamChatSwiftUI

struct ContentView: View {
    
    @Injected(\.chatClient) var chatClient
    
    @State var channelController: ChatChannelController?
    
    @State var showMessageList = false
    @State private var isSplitOpen = false
    @State private var composerHeight: CGFloat = 0
    @State private var isTextFieldFocused = true
    @ObservedObject private var clientToolActionHandler = ClientToolActionHandler.shared
    @StateObject var viewModel: ComposerViewModel
    @State var clientToolRegistry: ClientToolRegistry
    @StateObject var typingIndicatorHandler: TypingIndicatorHandler
    @State private var draftChannelId: ChannelId?
    
    //TODO: extract this.
    let predefinedOptions = ["Create a painting in Renaissance-style", "Create a workout plan for resistance training", "Find the decade that a photo is from", "Help me study vocabulary for an exam", "Tell me the best stocks to invest"]
    
    init() {
        _viewModel = StateObject(wrappedValue: .init())
        let clientToolRegistry = ClientToolRegistry()
        self.clientToolRegistry = clientToolRegistry
        _typingIndicatorHandler = StateObject(wrappedValue: TypingIndicatorHandler(
                actionHandler: ClientToolActionHandler.shared,
                clientToolRegistry: clientToolRegistry
            )
        )

        clientToolRegistry.register(tool: GreetClientTool())
    }
        
    var body: some View {
        NavigationStack {
            SidebarView(
                isOpen: $isSplitOpen,
                excludedBottomHeight: composerHeight,
                menu: {
                    ConversationListView(
                        onChannelSelected: handleChannelSelection,
                        onNewChat: handleNewChatRequest
                    )
                },
                content: {
                    mainConversation()
                }
            )
        }
        .alert(item: $clientToolActionHandler.presentedAlert) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text("OK"))
            )
        }
        .onAppear {
            AIComponentsViewFactory.shared.typingIndicatorHandler = _typingIndicatorHandler.wrappedValue
            viewModel.chatOptions = createChatOptions()
        }
    }
    
    private func mainConversation() -> some View {
        VStack(spacing: 0) {
            ZStack(alignment: .leading) {
                Color.clear
                    .allowsHitTesting(false)
                
                if showMessageList, let channelController {
                    ConversationView(
                        channelController: channelController
                    )
                    .id(channelController.cid)
                } else {
                    VStack {
                        Spacer()
                        SuggestionsView(suggestions: predefinedOptions) { messageData in
                            sendMessage(messageData)
                        }
                    }
                    .onChange(of: viewModel.text) { oldValue, newValue in
                        // already create the channel for faster reply.
                        if viewModel.text.count > 5 {
                            setupChannel()
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            
            ComposerView(
                viewModel: viewModel,
                isGenerating: typingIndicatorHandler.generatingMessageId != nil,
                onMessageSend: { messageData in
                    sendMessage(messageData)
                },
                onStopGenerating: {
                    stopGenerating()
                }
            )
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(key: ComposerHeightPreferenceKey.self, value: proxy.size.height)
                }
            )
            .onPreferenceChange(ComposerHeightPreferenceKey.self) { newHeight in
                composerHeight = newHeight
            }
            .onChange(of: isSplitOpen) { oldValue, newValue in
                isTextFieldFocused = !isSplitOpen
            }
        }
    }
    
    private func stopGenerating() {
        if let cid = channelController?.cid {
            channelController?
                .eventsController()
                .sendEvent(
                    AIIndicatorStopEvent(cid: cid)
                )
        }
        typingIndicatorHandler.generatingMessageId = nil
    }
    
    private func setActiveChannelController(_ controller: ChatChannelController?) {
        channelController = controller
        typingIndicatorHandler.channelId = controller?.cid
    }
    
    private func sendMessage(_ messageData: MessageData) {
        let attachments = messageData.attachments.compactMap { url in
            try? AnyAttachmentPayload(localFileURL: url, attachmentType: .image)
        }
        setupChannel {
            channelController?.createNewMessage(text: messageData.text, attachments: attachments)
            showMessageList = true
            if channelController?.cid == draftChannelId {
                draftChannelId = nil
            }
            
            if channelController?.channel?.name == nil {
                Task {
                    let summary = try await AgentService.shared.summarize(text: messageData.text, platform: "openai") //TODO: fix this
                    channelController?.updateChannel(name: summary, imageURL: nil, team: nil)
                }
            }
        }
        viewModel.cleanUpData()
    }
    
    private func setupChannel(completion: (() -> ())? = nil) {
        if channelController == nil {
            let id = UUID().uuidString
            let channelId = ChannelId(type: .messaging, id: id)
            let controller = try? chatClient.channelController(
                createChannelWithId: channelId
            )
            setActiveChannelController(controller)
            setupAgent(for: controller, completion: completion)
        } else {
            completion?()
        }
    }

    private func handleChannelSelection(_ channel: ChatChannel) {
        let controller = chatClient.channelController(for: channel.cid)
        setActiveChannelController(controller)
        showMessageList = true
        setupAgent(for: channelController)
        withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
            isSplitOpen = false
        }
    }

    private func handleNewChatRequest() {
        if let existingDraftId = draftChannelId {
            let draftController = chatClient.channelController(for: existingDraftId)
            if draftController.channel?.latestMessages.isEmpty ?? true {
                setActiveChannelController(draftController)
                showMessageList = true
                viewModel.cleanUpData()
                withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                    isSplitOpen = false
                }
                return
            } else {
                self.draftChannelId = nil
            }
        }

        setActiveChannelController(nil)
        viewModel.cleanUpData()
        showMessageList = true
        setupChannel()
        if let newCid = channelController?.cid {
            draftChannelId = newCid
        }
        withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
            isSplitOpen = false
        }
    }

    private func setupAgent(
        for channelController: ChatChannelController?,
        completion: (() -> ())? = nil
    ) {
        channelController?.synchronize { _ in
            Task { @MainActor in
                guard let id = channelController?.cid?.id else {
                    completion?()
                    return
                }

                do {
                    try await AgentService.shared.setupAgent(channelId: id)
                    let tools = clientToolRegistry.registrationPayloads()
                    if !tools.isEmpty {
                        try await AgentService.shared.registerTools(channelId: id, tools: tools)
                    }
                } catch {
                    print("Failed to setup AI agent or register tools:", error.localizedDescription)
                }

                completion?()
            }
        }
    }
    
    func createChatOptions() -> [ChatOption] {
        var options = [
            ChatOption(
                id: "image",
                title: "Create image",
                description: "Visualize anything",
                icon: "paintpalette",
                shortTitle: "Image"
            ),
            ChatOption(
                id: "research",
                title: "Deep research",
                description: "Get a detailed report",
                icon: "binoculars.circle",
                shortTitle: "Research"
            ),
            ChatOption(
                id: "search",
                title: "Web search",
                description: "Find real-time news and info",
                icon: "network",
                shortTitle: "Search"
            ),
            ChatOption(
                id: "study",
                title: "Study and learn",
                description: "Learn a new concept",
                icon: "book",
                shortTitle: "Study"
            ),
            ChatOption(
                id: "agent",
                title: "Agent mode",
                description: "Get work done for you",
                icon: "dot.circle.and.cursorarrow",
                shortTitle: "Agent"
            ),
            ChatOption(
                id: "files",
                title: "Add files",
                description: "Analyze or summarize",
                icon: "zipper.page",
                shortTitle: "Files"
            )
        ]
        for index in options.indices {
            options[index].action = { [weak viewModel = self.viewModel] in
                viewModel?.selectedChatOption = options[index]
                viewModel?.sheetShown = false
            }
        }
        return options
    }
}

struct ConversationView: View {
    let channelController: ChatChannelController
    @StateObject private var viewModel: ChatChannelViewModel

    init(channelController: ChatChannelController) {
        self.channelController = channelController
        _viewModel = StateObject(wrappedValue: ChatChannelViewModel(channelController: channelController))
    }

    var body: some View {
        if let channel = viewModel.channel {
            MessageListView(
                factory: AIComponentsViewFactory.shared,
                channel: channel,
                viewModel: viewModel,
                onLongPress: { _ in }
            )
        } else {
            ProgressView()
        }
    }
}

private struct ComposerHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct CustomMessageListContainerModifier: ViewModifier {
    
    @ObservedObject var typingIndicatorHandler: TypingIndicatorHandler
    
    func body(content: Content) -> some View {
        content.overlay {
            AIAgentOverlayView(typingIndicatorHandler: typingIndicatorHandler)
        }
    }
}

struct AIAgentOverlayView: View {
    
    @ObservedObject var typingIndicatorHandler: TypingIndicatorHandler
    
    var body: some View {
        VStack {
            Spacer()
            if typingIndicatorHandler.typingIndicatorShown {
                HStack {
                    AITypingIndicatorView(text: typingIndicatorHandler.state)
                    Spacer()
                }
                .padding()
                .frame(height: 60)
                .background(Color(UIColor.secondarySystemBackground))
            }
        }
    }
}

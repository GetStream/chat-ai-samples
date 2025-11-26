//
//  ContentView.swift
//  AIComponents
//
//  Created by Martin Mitrevski on 24.10.25.
//

import Combine
import Foundation
import StreamChat
import StreamChatAI
import StreamChatSwiftUI

class TypingIndicatorHandler: ObservableObject, EventsControllerDelegate, ChatChannelWatcherListControllerDelegate {
    
    @Injected(\.chatClient) var chatClient: ChatClient
    
    private var eventsController: EventsController!
    private let clientToolActionHandler: ClientToolActionHandling
    
    @Published var state: String = ""
    
    private let aiBotId = "ai-bot"
    
    @Published var aiBotPresent = false
    
    @Published var generatingMessageId: String?
    
    var channelId: ChannelId? {
        didSet {
            if let channelId = channelId {
                watcherListController = chatClient.watcherListController(query: .init(cid: channelId))
                watcherListController?.delegate = self
                watcherListController?.synchronize { [weak self] _ in
                    guard let self else { return }
                    self.aiBotPresent = self.isAiBotPresent
                }
            }
        }
    }
    
    @Published var typingIndicatorShown = false
    
    var isAiBotPresent: Bool {
        let aiAgent = watcherListController?
            .watchers
            .first(where: { $0.id.contains(self.aiBotId) })
        return aiAgent?.isOnline == true
    }
    
    var watcherListController: ChatChannelWatcherListController?
    let clientToolRegistry: ClientToolRegistry
        
    init(actionHandler: ClientToolActionHandling, clientToolRegistry: ClientToolRegistry) {
        self.clientToolActionHandler = actionHandler
        self.clientToolRegistry = clientToolRegistry
        eventsController = chatClient.eventsController()
        eventsController.delegate = self
    }
    
    func eventsController(_ controller: EventsController, didReceiveEvent event: any Event) {
        if
            let unknownEvent = event as? UnknownChannelEvent,
            let payload = unknownEvent.payload(ofType: ClientToolInvocationEventPayload.self)
        {
            Task { @MainActor [clientToolActionHandler] in
                let invocation = ClientToolInvocation(
                    payload: payload,
                    channelId: AnyHashable(unknownEvent.cid)
                )
                let actions = clientToolRegistry.handleInvocation(invocation)
                guard !actions.isEmpty else { return }
                clientToolActionHandler.handle(actions)
            }
            return
        }

        if event is AIIndicatorClearEvent {
            typingIndicatorShown = false
            generatingMessageId = nil
            return
        }
        
        guard let typingEvent = event as? AIIndicatorUpdateEvent else {
            return
        }
        
        state = typingEvent.title
        if typingEvent.state == .generating {
            generatingMessageId = typingEvent.messageId
        } else {
            generatingMessageId = nil
        }
        typingIndicatorShown = !typingEvent.title.isEmpty
    }
    
    func channelWatcherListController(
        _ controller: ChatChannelWatcherListController,
        didChangeWatchers changes: [ListChange<ChatUser>]
    ) {
        self.aiBotPresent = isAiBotPresent
    }
}

extension AIIndicatorUpdateEvent {
    var title: String {
        switch state {
        case .thinking:
            return "Thinking"
        case .checkingExternalSources:
            return "Checking external sources"
        default:
            return ""
        }
    }
}

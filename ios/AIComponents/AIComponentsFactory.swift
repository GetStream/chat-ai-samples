//
//  AIComponentsFactory.swift
//  AIComponents
//
//  Created by Martin Mitrevski on 21.11.25.
//

import SwiftUI
import StreamChat
import StreamChatAI
import StreamChatSwiftUI

class AIComponentsViewFactory: ViewFactory {
    
    @Injected(\.chatClient) var chatClient: ChatClient
    
    private let actionHandler = ClientToolActionHandler.shared
    var typingIndicatorHandler: TypingIndicatorHandler!
    
    private init() {}
    
    static let shared = AIComponentsViewFactory()
        
    public func makeMessageListBackground(
        colors: ColorPalette,
        isInThread: Bool
    ) -> some View {
        Color.clear
    }
    
    func makeMessageReadIndicatorView(channel: ChatChannel, message: ChatMessage) -> some View {
        EmptyView()
    }
    
    @ViewBuilder
    func makeCustomAttachmentViewType(
        for message: ChatMessage,
        isFirst: Bool,
        availableWidth: CGFloat,
        scrolledId: Binding<String?>
    ) -> some View {
        if let a2ui = message.extraData["a2ui"]?.dictionaryValue,
           let surfaceId = a2ui["surfaceId"]?.stringValue ?? a2ui["surface_id"]?.stringValue {
            GenUIView(host: "http://localhost:3000", surfaceId: surfaceId)
        } else {
            let isGenerating = message.extraData["generating"]?.boolValue == true
            StreamingMessageView(
                content: message.text,
                isGenerating: isGenerating
            )
            .padding()
        }
    }
    
    func makeMessageListContainerModifier() -> some ViewModifier {
        CustomMessageListContainerModifier(typingIndicatorHandler: typingIndicatorHandler)
    }
    
    func makeEmptyMessagesView(
        for channel: ChatChannel,
        colors: ColorPalette
    ) -> some View {
        AIAgentOverlayView(typingIndicatorHandler: typingIndicatorHandler)
    }
}

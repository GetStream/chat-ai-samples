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
    var styles = AIComponentsStyles()

    private init() {}

    static let shared = AIComponentsViewFactory()

    public func makeMessageListBackground(
        options: MessageListBackgroundOptions
    ) -> some View {
        Color.clear
    }

    func makeMessageReadIndicatorView(
        options: MessageReadIndicatorViewOptions
    ) -> some View {
        EmptyView()
    }

    @ViewBuilder
    func makeCustomAttachmentViewType(
        options: CustomAttachmentViewTypeOptions
    ) -> some View {
        let message = options.message
        let isGenerating = message.extraData["generating"]?.boolValue == true
        StreamingMessageView(
            content: message.text,
            isGenerating: isGenerating
        )
        .padding()
    }

    func makeEmptyMessagesView(
        options: EmptyMessagesViewOptions
    ) -> some View {
        AIAgentOverlayView(typingIndicatorHandler: typingIndicatorHandler)
    }
}

final class AIComponentsStyles: Styles {
    var composerPlacement: ComposerPlacement = .docked
    var typingIndicatorHandler: TypingIndicatorHandler?

    func makeMessageListContainerModifier(
        options: MessageListContainerModifierOptions
    ) -> some ViewModifier {
        CustomMessageListContainerModifier(typingIndicatorHandler: typingIndicatorHandler)
    }

    func makeComposerInputViewModifier(options: ComposerInputModifierOptions) -> some ViewModifier {
        RegularInputViewModifier()
    }

    func makeComposerButtonViewModifier(options: ComposerButtonModifierOptions) -> some ViewModifier {
        RegularButtonViewModifier()
    }

    func makeSuggestionsContainerModifier(options: SuggestionsContainerModifierOptions) -> some ViewModifier {
        SuggestionsRegularContainerModifier()
    }
}

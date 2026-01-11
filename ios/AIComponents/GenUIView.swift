//
//  GenUIView.swift
//  AIComponents
//
//  Created by Martin Mitrevski on 9.1.26.
//

import SwiftUI
import GenUI
import StreamChat

struct GenUIView: View {
    @StateObject private var renderer: A2uiSurfaceRenderer
    
    init(payload: A2uiPayload, message: ChatMessage, chatClient: ChatClient) {
        _renderer = StateObject(
            wrappedValue: A2uiSurfaceRenderer(
                payload: payload,
                message: message,
                chatClient: chatClient
            )
        )
    }
    
    var body: some View {
        GenUiSurface(host: renderer.processor, surfaceId: renderer.surfaceId)
            .padding(16)
            .onDisappear {
                renderer.dispose()
            }
    }
}

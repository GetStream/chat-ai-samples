//
//  GenUIView.swift
//  AIComponents
//
//  Created by Martin Mitrevski on 9.1.26.
//

import SwiftUI
import GenUI

struct GenUIView: View {
    let host: String
    let surfaceId: String
    
    private let conversation: GenUiConversation
    
    init(host: String, surfaceId: String) {
        self.host = host
        self.surfaceId = surfaceId
        
        // Create host setup similar to GenUISample
        let baseUrl = URL(string: host) ?? URL(string: "http://localhost:10002")!
        let generator = A2uiContentGenerator(serverUrl: baseUrl)
        let catalog = CoreCatalogItems.asCatalog()
        let processor = A2uiMessageProcessor(catalogs: [catalog])
        self.conversation = GenUiConversation(
            contentGenerator: generator,
            a2uiMessageProcessor: processor,
            handleSubmitEvents: false
        )
    }
    
    var body: some View {
        GenUiSurface(host: conversation.host, surfaceId: surfaceId)
            .padding(16)
            .onDisappear {
                conversation.dispose()
            }
    }
}

//
//  ClientToolActionHandler.swift
//  AIComponents
//
//  Created by Martin Mitrevski on 5.11.25.
//

import Combine
import Foundation
import StreamChatAI

final class ClientToolActionHandler: ObservableObject, ClientToolActionHandling {
    static let shared = ClientToolActionHandler()

    @Published var presentedAlert: ClientToolAlert?

    private init() {}

    func handle(_ actions: [ClientToolAction]) {
        actions.forEach { action in
            action()
        }
    }

    func presentAlert(_ alert: ClientToolAlert) {
        presentedAlert = alert
    }
}

struct ClientToolAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

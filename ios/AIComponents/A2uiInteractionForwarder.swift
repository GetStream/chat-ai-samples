//
//  A2uiInteractionForwarder.swift
//  AIComponents
//
//  Created by OpenAI Assistant on 17.1.26.
//

import Combine
import Foundation
import GenUI
import StreamChat

@MainActor
final class A2uiSurfaceRenderer: ObservableObject {
    let surfaceId: String
    let processor: A2uiMessageProcessor

    private var cancellables: Set<AnyCancellable> = []
    private let interactionForwarder: A2uiInteractionForwarder?

    init(payload: A2uiPayload, message: ChatMessage, chatClient: ChatClient) {
        self.surfaceId = payload.surfaceId

        let catalog = CoreCatalogItems.asCatalog()
        let processor = A2uiMessageProcessor(catalogs: [catalog])
        payload.messages.forEach { processor.handleMessage($0) }
        self.processor = processor

        self.interactionForwarder = A2uiInteractionForwarder(
            chatClient: chatClient,
            channelId: message.cid,
            sourceMessageId: message.id,
            surfaceId: payload.surfaceId
        )

        processor.onSubmit
            .receive(on: DispatchQueue.main)
            .sink { [weak interactionForwarder] interaction in
                interactionForwarder?.forwardInteraction(interaction)
            }
            .store(in: &cancellables)
    }

    func dispose() {
        processor.dispose()
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
    }
}

@MainActor
private final class A2uiInteractionForwarder {
    private weak var chatClient: ChatClient?
    private let channelId: ChannelId?
    private let sourceMessageId: MessageId?
    private let surfaceId: String

    init(chatClient: ChatClient, channelId: ChannelId?, sourceMessageId: MessageId?, surfaceId: String) {
        self.chatClient = chatClient
        self.channelId = channelId
        self.sourceMessageId = sourceMessageId
        self.surfaceId = surfaceId
    }

    func forwardInteraction(_ interaction: UserUiInteractionMessage) {
        guard let channelId, let chatClient else {
            print("Unable to forward A2UI interaction: missing channel or chat client.")
            return
        }

        let controller = chatClient.channelController(for: channelId)
        let metadata = A2uiActionMetadata(from: interaction.text)
        let messageText = metadata.query ?? metadata.description

        var extraData: [String: RawJSON] = [
            "a2ui_interaction": .string(interaction.text),
            "a2ui_surface_id": .string(surfaceId),
            "a2ui_display_text": .string(metadata.description)
        ]

        if let actionName = metadata.actionName {
            extraData["a2ui_action_name"] = .string(actionName)
        }

        if let label = metadata.label, !label.isEmpty {
            extraData["a2ui_action_label"] = .string(label)
        }

        if let query = metadata.query {
            extraData["a2ui_query_text"] = .string(query)
        }

        if let rawContext = metadata.rawContext {
            extraData["a2ui_action_context"] = rawContext
        }

        if let sourceMessageId {
            extraData["a2ui_source_message_id"] = .string(sourceMessageId)
        }

        controller.createNewMessage(
            text: messageText,
            extraData: extraData
        )
    }
}

private struct A2uiActionMetadata {
    let description: String
    let actionName: String?
    let label: String?
    let query: String?
    let rawContext: RawJSON?

    init(from jsonString: String) {
        guard
            let data = jsonString.data(using: .utf8),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let userAction = json["userAction"] as? [String: Any]
        else {
            self.description = "Submitted action"
            self.actionName = nil
            self.label = nil
            self.query = nil
            self.rawContext = nil
            return
        }

        let context = userAction["context"] as? [String: Any] ?? [:]
        self.actionName = userAction["name"] as? String
        self.label = (context["label"] as? String) ??
            (context["title"] as? String) ??
            (context["text"] as? String)
        self.query = Self.buildQuery(for: actionName, context: context)
        self.rawContext = RawJSON.make(from: context)

        if let label = label, !label.isEmpty {
            self.description = label
        } else if let actionName = actionName, !actionName.isEmpty {
            self.description = actionName
                .replacingOccurrences(of: "_", with: " ")
                .capitalized
        } else {
            self.description = "Submitted action"
        }
    }

    private static func buildQuery(for actionName: String?, context: [String: Any]) -> String? {
        guard let actionName else { return nil }

        let valueFor: (String) -> String? = { key in
            guard let rawValue = context[key] else { return nil }
            if let string = rawValue as? String {
                return string
            }
            if let number = rawValue as? NSNumber {
                return number.stringValue
            }
            if let bool = rawValue as? Bool {
                return bool ? "true" : "false"
            }
            if JSONSerialization.isValidJSONObject(rawValue),
               let data = try? JSONSerialization.data(withJSONObject: rawValue, options: []),
               let string = String(data: data, encoding: .utf8) {
                return string
            }
            return nil
        }

        switch actionName {
        case "book_restaurant":
            let restaurant = valueFor("restaurantName") ?? "Unknown Restaurant"
            let address = valueFor("address")
            let imageUrl = valueFor("imageUrl")

            var parts = ["USER_WANTS_TO_BOOK: \(restaurant)"]
            if let address {
                parts.append("Address: \(address)")
            }
            if let imageUrl {
                parts.append("ImageURL: \(imageUrl)")
            }
            return parts.joined(separator: ", ")
        case "submit_booking":
            let restaurant = valueFor("restaurantName") ?? "Unknown Restaurant"
            let partySize = valueFor("partySize") ?? "Unknown Size"
            let reservationTime = valueFor("reservationTime") ?? "Unknown Time"
            let dietary = valueFor("dietary") ?? "None"
            let imageUrl = valueFor("imageUrl")

            var query = "User submitted a booking for \(restaurant) for \(partySize) people at \(reservationTime) with dietary requirements: \(dietary)"
            if let imageUrl {
                query += ". Image URL: \(imageUrl)"
            }
            return query
        default:
            if JSONSerialization.isValidJSONObject(context),
               let data = try? JSONSerialization.data(withJSONObject: context, options: []),
               let string = String(data: data, encoding: .utf8) {
                return "User submitted an event: \(actionName) with data: \(string)"
            }
            return "User submitted an event: \(actionName)"
        }
    }
}

private extension RawJSON {
    static func make(from value: Any) -> RawJSON? {
        switch value {
        case let raw as RawJSON:
            return raw
        case let string as String:
            return .string(string)
        case let bool as Bool:
            return .bool(bool)
        case let number as NSNumber:
            return .number(number.doubleValue)
        case is NSNull:
            return .nil
        case let dictionary as [String: Any]:
            var result: [String: RawJSON] = [:]
            for (key, child) in dictionary {
                result[key] = RawJSON.make(from: child)
            }
            return .dictionary(result)
        case let array as [Any]:
            return .array(array.compactMap { RawJSON.make(from: $0) })
        default:
            return nil
        }
    }
}

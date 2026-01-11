//
//  A2uiPayload.swift
//  AIComponents
//
//  Created by OpenAI Assistant on 17.1.26.
//

import Foundation
import GenUI
import StreamChat

struct A2uiPayload {
    let surfaceId: String
    let messages: [A2uiMessage]

    init?(rawJSON: RawJSON?) {
        guard
            let rawJSON,
            case let .dictionary(dictionary) = rawJSON
        else {
            return nil
        }

        guard let surfaceId = dictionary["surfaceId"]?.stringValue ?? dictionary["surface_id"]?.stringValue else {
            return nil
        }

        guard let rawMessages = dictionary["messages"]?.arrayValue else {
            return nil
        }

        let parsedMessages: [A2uiMessage] = rawMessages.compactMap { rawMessage in
            guard let json = rawMessage.jsonMap else {
                return nil
            }
            return try? A2uiMessageFactory.fromJson(json)
        }

        guard !parsedMessages.isEmpty else {
            return nil
        }

        self.surfaceId = surfaceId
        self.messages = parsedMessages
    }
}

private extension RawJSON {
    var jsonMap: JsonMap? {
        guard case let .dictionary(dictionary) = self else {
            return nil
        }

        return dictionary.reduce(into: JsonMap()) { partialResult, element in
            partialResult[element.key] = element.value.jsonCompatibleValue
        }
    }

    var jsonCompatibleValue: Any {
        switch self {
        case let .number(value):
            return value
        case let .string(value):
            return value
        case let .bool(value):
            return value
        case let .array(values):
            return values.map(\.jsonCompatibleValue)
        case let .dictionary(dictionary):
            return dictionary.reduce(into: JsonMap()) { partialResult, element in
                partialResult[element.key] = element.value.jsonCompatibleValue
            }
        case .nil:
            return NSNull()
        }
    }
}

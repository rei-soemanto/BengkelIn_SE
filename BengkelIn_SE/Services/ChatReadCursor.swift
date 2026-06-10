//
//  ChatReadCursor.swift
//  BengkelIn
//
//  Created by Bryan Fernando Dinata on 29/05/26.
//

import Foundation

struct ChatReadCursor {
    let serviceRequestId: String

    private var key: String { "chat_last_read_\(serviceRequestId)" }

    var lastReadAt: Date {
        let stamp = UserDefaults.standard.double(forKey: key)
        return stamp > 0 ? Date(timeIntervalSince1970: stamp) : .distantPast
    }

    func markRead(at date: Date = Date()) {
        UserDefaults.standard.set(date.timeIntervalSince1970, forKey: key)
    }

    func unreadCount(in incoming: [ChatMessage]) -> Int {
        let cursor = lastReadAt
        return incoming.filter { Self.date(of: $0) > cursor }.count
    }

    static func date(of message: ChatMessage) -> Date {
        guard let str = message.createdAt else { return .distantPast }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: str) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: str) ?? .distantPast
    }
}

//
//  ChatPresence.swift
//  BengkelIn
//
//  Created by Bryan Fernando Dinata on 29/05/26.
//

import Foundation

@MainActor
final class ChatPresence {
    static let shared = ChatPresence()
    private init() {}

    var activeServiceRequestId: String?
}

//
//  Created by Michael Schwarz on 17.09.20.
//

import Foundation
import OperationLog


/// Operations to modify characters in a string
struct CharacterOperation: LogOperation {

    enum Kind: String, Codable {
        case append
        case removeLast
    }

    // MARK: - Properties

    let kind: Kind
    let character: Character

    // MARK: - LogOperation

    var description: String? {
        switch self.kind {
        case .append:
            return "Append character: \(character)"
        case .removeLast:
            return "removeLast character: \(character)"
        }
    }

    func apply(to snapshot: StringSnapshot) -> StringSnapshot {
        switch self.kind {
        case .append:
            return snapshot.appending(character: self.character)
        case .removeLast:
            return snapshot.removingLast(character: self.character)
        }
    }

    func serialize() throws -> Data {
        return try JSONEncoder().encode(self)
    }

    func reverted() -> Self {
        switch self.kind {
        case .append:
            return .init(kind: .removeLast, character: self.character)
        case .removeLast:
            return .init(kind: .append, character: self.character)
        }
    }
}

// MARK: - Codable

extension CharacterOperation: Codable {

    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let string = try container.decode(String.self)
        guard string.count == 1 else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Not a character: \(string)")
        }

        let kind = try container.decode(Kind.self)
        let character = string[string.startIndex]
        self.init(kind: kind, character: character)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(String(self.character))
        try container.encode(self.kind)
    }
}

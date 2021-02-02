//
//  Created by Michael Schwarz on 17.09.20.
//

import Foundation
import OperationLog


/// Snapshot which represents a string
struct StringSnapshot: SnapshotProtocol {

    // MARK: - Properties

    private(set) var string: String

    init(string: String) {
        self.string = string
    }

    // MARK: - StringSnapshot

    func applying(_ operation: CharacterOperation) -> (snapshot: StringSnapshot, outcome: Outcome<CharacterOperation>) {
        switch operation.kind {
        case .append:
            let undoOperation = CharacterOperation(kind: .removeLast, character: operation.character)
            let newSnapshot = self.appending(character: operation.character)
            return (newSnapshot, .fullApplied(undoOperation: undoOperation))
        case .removeLast:
            guard let lastCharacter = self.string.last else {
                return (self, .skipped(reason: "Snapshot is empty"))
            }

            let undoOperation = CharacterOperation(kind: .append, character: lastCharacter)
            let newSnapshot = self.removingLast(character: operation.character)
            return (newSnapshot, .fullApplied(undoOperation: undoOperation))
        }
    }

    func appending(character: Character) -> StringSnapshot {
        return StringSnapshot(string: self.string.appending("\(character)"))
    }

    func removingLast(character: Character) -> StringSnapshot {
        var newString = self.string
        let last = newString.removeLast()
        guard last == character else {
            fatalError("Character should match \(last) <> \(character)")
        }

        return StringSnapshot(string: newString)
    }

    // MARK: - Snapshot

    func serialize() throws -> Data {
        return try JSONEncoder().encode(self)
    }

    static func deserialize(fromData data: Data) throws -> StringSnapshot {
        return try JSONDecoder().decode(self, from: data)
    }
}

// MARK: - Codable

extension StringSnapshot: Codable { }

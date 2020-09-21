//
//  Created by Michael Schwarz on 17.09.20.
//

import Foundation
import OperationLog


/// Snapshot which represents a string
struct StringSnapshot: Snapshot {

    // MARK: - Properties

    private(set) var string: String

    // MARK: - StringSnapshot

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

//
//  Created by Michael Schwarz on 17.09.20.
//

import Foundation
import OperationLog


struct CharacterOperation: LogOperation {

    enum Kind {
        case add
        case remove
    }

    let kind: Kind
    let character: Character

    var description: String? {
        switch self.kind {
        case .add:
            return "Add character: \(character)"
        case .remove:
            return "Remove character: \(character)"
        }
    }

    func apply(to snapshot: StringSnapshot) -> StringSnapshot {
        switch self.kind {
        case .add:
            return snapshot.appending(character: self.character)
        case .remove:
            return snapshot.removingLast(character: self.character)
        }
    }

    func serialize() -> Data {
        return Data()
    }

    func reverted() -> Self {
        switch self.kind {
        case .add:
            return .init(kind: .remove, character: self.character)
        case .remove:
            return .init(kind: .add, character: self.character)
        }
    }
}

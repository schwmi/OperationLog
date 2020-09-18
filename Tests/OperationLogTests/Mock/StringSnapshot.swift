//
//  Created by Michael Schwarz on 17.09.20.
//

import Foundation
import OperationLog



struct StringSnapshot: Snapshot {

    var string: String

    func serialize() -> Data {
        return Data()
    }

    func appending(character: Character) -> StringSnapshot {
        return StringSnapshot(string: self.string.appending("\(character)"))
    }

    func removingLast(character: Character) -> StringSnapshot {
        var newString = self.string
        let last = newString.removeLast()
        guard last == character else {
            fatalError("Character should match")
        }

        return StringSnapshot(string: newString)
    }
}

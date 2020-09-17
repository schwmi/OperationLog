//
//  Created by Michael Schwarz on 17.09.20.
//

import Foundation
import OperationLog


struct AddCharacterOperation: OperationProtocol {

    var description: String?

    func apply(to snapshot: StringSnapshot) -> StringSnapshot {
        fatalError()
    }

    func serialize() -> Data {
        return Data()
    }

    func reverted() -> Self {
        return AddCharacterOperation(description: "Bla")
    }
}

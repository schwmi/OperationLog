//
//  Created by Michael Schwarz on 17.09.20.
//

import Foundation
import OperationLog



struct StringSnapshot: Snapshot {

    func serialize() -> Data {
        return Data()
    }
}

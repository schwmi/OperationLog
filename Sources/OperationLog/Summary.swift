import Foundation


public extension OperationLog {

    /// Summarizes information about all operations applied to a log
    /// Can be used to retrieve aggregated information like total operation count
    /// or the number of actors which contributed to a log and also apply outcome for each operation (e.g. applied/skipped)
    struct Summary {

        public struct AppliedOperation {

            /// Informs how an operation was applied to a snapshot
            public enum ApplyType {
                /// The operation was fully applied
                case full
                /// Only parts of the operation could be applied to the snapshot
                case partial(reason: String)
                /// The operation had to be skipped (e.g. because a merged operation, which was executed before, made the operation obsolete)
                case skipped(reason: String)

                public var isSkipped: Bool {
                    switch self {
                    case .skipped:
                        return true
                    case .partial, .full:
                        return false
                    }
                }
            }

            /// ID of the operation
            public let id: UUID
            /// Index, apply order
            public let index: Int
            /// ActorID which applied the operation
            public let actor: ActorID
            /// Information how the operation was applied
            public let applyType: ApplyType
        }

        /// All actorIDs which applied operations in a given log
        public var actors: Set<ActorID>
        /// The latest clock of the Log => clock of the current snapshot
        public var latestClock: VectorClock<ActorID>
        /// Number of operations in the log
        public var operationCount: Int
        /// Sorted array (apply order) of operation infos
        public var operationInfos: [AppliedOperation]
        
        mutating func apply(_ operation: LoggedOperation, outcome: Outcome<Operation>) {
            self.actors.insert(operation.actor)
            self.latestClock = operation.clock
            self.operationCount += 1
            let applyType: AppliedOperation.ApplyType = {
                switch outcome {
                case .fullApplied:
                    return .full
                case .partialApplied(_, let reason):
                    return .partial(reason: reason)
                case .skipped(let reason):
                    return .skipped(reason: reason)
                }
            }()
            self.operationInfos.append(.init(id: operation.id,
                                             index: self.operationCount,
                                             actor: operation.actor,
                                             applyType: applyType))
        }
    }
}

// MARK: - Codable

extension OperationLog.Summary: Codable { }

extension OperationLog.Summary.AppliedOperation: Codable { }

extension OperationLog.Summary.AppliedOperation.ApplyType: Codable {

    enum CodingKeys: CodingKey {
        case fullApplied, partialApplied, skipped
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let key = container.allKeys.first

        switch key {
        case .fullApplied:
            self = .full
        case .partialApplied:
            let reason = try container.decode(String.self, forKey: .partialApplied)
            self = .partial(reason: reason)
        case .skipped:
            let reason = try container.decode(String.self, forKey: .skipped)
            self = .skipped(reason: reason)
        default:
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: container.codingPath,
                                                                    debugDescription: "Unable to decode OperationLog.Summary.AppliedOperation.ApplyType"))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .full:
            try container.encodeNil(forKey: .fullApplied)
        case .partial(let reason):
            try container.encode(reason, forKey: .partialApplied)
        case .skipped(let reason):
            try container.encode(reason, forKey: .skipped)
        }

    }
}



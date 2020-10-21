import Foundation
import VectorClock


public extension OperationLog {

    /// Summarizes information about an operation log
    struct Summary {

        public struct AppliedOperation {

            public enum ApplyType {
                case fullApplied
                case partialApplied(reason: String)
                case skipped(reason: String)
            }

            let id: UUID
            let index: Int
            let actor: ActorID
            let applyType: ApplyType
        }
        
        public var actors: Set<ActorID>
        public var latestClock: VectorClock<ActorID>
        public var operationCount: Int
        public var operationIDs: [AppliedOperation]
        
        mutating func apply(_ operation: OperationContainer, outcome: Outcome<Operation>) {
            self.actors.insert(operation.actor)
            self.latestClock = operation.clock
            self.operationCount += 1
            let applyType: AppliedOperation.ApplyType = {
                switch outcome {
                case .fullApplied:
                    return .fullApplied
                case .partialApplied(_, let reason):
                    return .partialApplied(reason: reason)
                case .skipped(let reason):
                    return .skipped(reason: reason)
                }
            }()
            self.operationIDs.append(.init(id: operation.id,
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
            self = .fullApplied
        case .partialApplied:
            let reason = try container.decode(String.self, forKey: .partialApplied)
            self = .partialApplied(reason: reason)
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
        case .fullApplied:
            try container.encodeNil(forKey: .fullApplied)
        case .partialApplied(let reason):
            try container.encode(reason, forKey: .partialApplied)
        case .skipped(let reason):
            try container.encode(reason, forKey: .skipped)
        }

    }
}



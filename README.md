# OperationLog

… is a CRDT which holds a vector clock sorted array of operations, and a provides snapshots as representation of applied/reduced operations. It supports methods for merging two logs and for appending new operations. Furthermore, containerized operations from one log can be inserted in bunch into another related log. By doing so - given the common order which is guaranteed by the vector clock - state can be synced between multiple OperationLog instances.

## Usage

For using the log you have to implement the `LogOperation` and `Snapshot` protocol. `Snapshot` is the type into which `LogOperation`s are reduced into. e.g. if the snapshot representation is a string, the suitable operation could contain types for adding and removing characters. Both protocol implementations should be structs. 

### Create a new log
```
let stringSnapshot = StringSnapshot("") // StringSnapshot is a implementation of the `Snapshot` protocol
let log = OperationLog(actorID: "A", initialSnapshot: stringSnapshot)
```

### Append operations
```
[…]
let addCharacterOperation = CharacterOperation(kind: .append, character: "A") // CharacterOperation implements `LogOperation` protocol
log.append(addCharacterOperation)
```

### Merging Logs
```
[…]
logA.merge(logB) // merges logB's content into logA
```

### Serialize / Deserialize a log
```
[…]
let logData = try log.serialize()
let deserializedLog = try OperationLog(actorID: "A", data: logData)
```

# OperationLog

… is a CRDT which holds a vector clock sorted array of operations, and a provides snapshots as representation of applied/reduced operations. It supports methods for merging two logs and for appending new operations. Furthermore, containerized operations from one log can be inserted in bunch into another related log. By doing so - given the common order which is guaranteed by the vector clock - state can be synced between multiple OperationLog instances.

## Usage

### Create a new log

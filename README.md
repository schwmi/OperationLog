# OperationLog

… is a CRDT which holds a vector clock sorted array of operations, and a provides snapshots as representation of applied/reduced operations. It supports methods for merging two logs and for appending new operations. Furthermore, operations appended onto another related log, can be retrieved and later inserted into the current log. By doing so, and given the common order which is guaranteed by the vector clock, state can be synced between multiple OperationLog instances.

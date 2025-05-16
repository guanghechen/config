local circular = std.CircularQueue.new({ capacity = 3 })
circular:enqueue("A")
circular:enqueue("B")
circular:enqueue("C")

std.debug.log("1", circular:at(1))
std.debug.log("2", circular:at(2))
std.debug.log("3", circular:at(3))

circular:enqueue("D")
std.debug.log("4", circular:at(1))
std.debug.log("5", circular:at(2))
std.debug.log("6", circular:at(3))

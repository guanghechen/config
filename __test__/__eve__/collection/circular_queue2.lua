local CircularQueue = require("eve.collection.circular_queue")

local circular = CircularQueue.new({ capacity = 3 })
circular:enqueue("A")
circular:enqueue("B")
circular:enqueue("C")

eve.std.debug.log(circular:at(1))
eve.std.debug.log(circular:at(2))
eve.std.debug.log(circular:at(3))

circular:enqueue("D")
eve.std.debug.log(circular:at(1))
eve.std.debug.log(circular:at(2))
eve.std.debug.log(circular:at(3))

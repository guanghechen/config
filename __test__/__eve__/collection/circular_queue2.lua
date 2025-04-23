local circular = eve.std.CircularQueue.new({ capacity = 3 })
circular:enqueue("A")
circular:enqueue("B")
circular:enqueue("C")

eve.debug.log("1", circular:at(1))
eve.debug.log("2", circular:at(2))
eve.debug.log("3", circular:at(3))

circular:enqueue("D")
eve.debug.log("4", circular:at(1))
eve.debug.log("5", circular:at(2))
eve.debug.log("6", circular:at(3))

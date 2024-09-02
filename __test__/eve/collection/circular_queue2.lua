local circular = eve.c.CircularQueue.new({ capacity = 3 })
circular:enqueue("A")
circular:enqueue("B")
circular:enqueue("C")

eve.debug.log(circular:at(1))
eve.debug.log(circular:at(2))
eve.debug.log(circular:at(3))

circular:enqueue("D")
eve.debug.log(circular:at(1))
eve.debug.log(circular:at(2))
eve.debug.log(circular:at(3))

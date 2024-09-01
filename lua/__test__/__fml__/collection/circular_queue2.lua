local circular = fc.c.CircularQueue.new({ capacity = 3 })
circular:enqueue("A")
circular:enqueue("B")
circular:enqueue("C")

fml.debug.log(circular:at(1))
fml.debug.log(circular:at(2))
fml.debug.log(circular:at(3))

circular:enqueue("D")
fml.debug.log(circular:at(1))
fml.debug.log(circular:at(2))
fml.debug.log(circular:at(3))

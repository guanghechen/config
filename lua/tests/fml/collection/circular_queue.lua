local function circular_queue()
  local circular = fml.collection.CircularQueue.new({ capacity = 3 })
  circular:enqueue("A")
  circular:enqueue("B")
  circular:enqueue("C")

  fml.debug.log({
    size = circular:size(),
    at1 = circular:at(1),
    at2 = circular:at(2),
    at3 = circular:at(3),
    at4 = circular:at(4),
    elements = circular:collect(),
  })

  circular:enqueue("D")
  fml.debug.log({
    size = circular:size(),
    at1 = circular:at(1),
    at2 = circular:at(2),
    at3 = circular:at(3),
    at4 = circular:at(4),
    elements = circular:collect(),
  })

  circular:dequeue_back()
  fml.debug.log({
    size = circular:size(),
    at1 = circular:at(1),
    at2 = circular:at(2),
    at3 = circular:at(3),
    at4 = circular:at(4),
    elements = circular:collect(),
  })

  circular:enqueue("E")
  circular:enqueue("F")
  fml.debug.log({
    size = circular:size(),
    at1 = circular:at(1),
    at2 = circular:at(2),
    at3 = circular:at(3),
    at4 = circular:at(4),
    elements = circular:collect(),
  })

  local result0 = {}
  for element in circular:iterator() do
    table.insert(result0, element)
  end
  fml.debug.log({ result0 = result0 })

  local result1 = {}
  for element in circular:iterator_reverse() do
    table.insert(result1, element)
  end
  fml.debug.log({ result1 = result1 })

  while circular:size() > 1 do
    circular:dequeue_back()
  end
  fml.debug.log({
    size = circular:size(),
    at1 = circular:at(1),
    at2 = circular:at(2),
    at3 = circular:at(3),
    at4 = circular:at(4),
    elements = circular:collect(),
  })

  circular:enqueue("G")
  circular:enqueue("H")
  circular:rearrange(fml.fn.truthy)
  fml.debug.log({
    size = circular:size(),
    at1 = circular:at(1),
    at2 = circular:at(2),
    at3 = circular:at(3),
    at4 = circular:at(4),
    elements = circular:collect(),
  })

  circular:enqueue("I")
  circular:enqueue("J")
  circular:rearrange(function(element)
    return element ~= "I"
  end)
  fml.debug.log({
    size = circular:size(),
    at1 = circular:at(1),
    at2 = circular:at(2),
    at3 = circular:at(3),
    at4 = circular:at(4),
    elements = circular:collect(),
  })

  circular:enqueue("K")
  circular:enqueue("L")
  fml.debug.log({
    size = circular:size(),
    at1 = circular:at(1),
    at2 = circular:at(2),
    at3 = circular:at(3),
    at4 = circular:at(4),
    elements = circular:collect(),
  })

  circular:rearrange(function(element)
    return element ~= "L"
  end)
  fml.debug.log({
    size = circular:size(),
    at1 = circular:at(1),
    at2 = circular:at(2),
    at3 = circular:at(3),
    at4 = circular:at(4),
    elements = circular:collect(),
  })
end

circular_queue()

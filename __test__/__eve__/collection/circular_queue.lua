local function circular_queue()
  local circular = std.CircularQueue.new({ capacity = 3 })
  circular:enqueue("A")
  circular:enqueue("B")
  circular:enqueue("C")

  std.debug.log("1", {
    size = circular:size(),
    at1 = circular:at(1),
    at2 = circular:at(2),
    at3 = circular:at(3),
    at4 = circular:at(4),
    elements = circular:collect(),
  })

  circular:enqueue("D")
  std.debug.log("2", {
    size = circular:size(),
    at1 = circular:at(1),
    at2 = circular:at(2),
    at3 = circular:at(3),
    at4 = circular:at(4),
    elements = circular:collect(),
  })

  circular:dequeue_back()
  std.debug.log("3", {
    size = circular:size(),
    at1 = circular:at(1),
    at2 = circular:at(2),
    at3 = circular:at(3),
    at4 = circular:at(4),
    elements = circular:collect(),
  })

  circular:enqueue("E")
  circular:enqueue("F")
  std.debug.log("4", {
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
  std.debug.log("5", { result0 = result0 })

  local result1 = {}
  for element in circular:iterator_reverse() do
    table.insert(result1, element)
  end
  std.debug.log("6", { result1 = result1 })

  while circular:size() > 1 do
    circular:dequeue_back()
  end
  std.debug.log("7", {
    size = circular:size(),
    at1 = circular:at(1),
    at2 = circular:at(2),
    at3 = circular:at(3),
    at4 = circular:at(4),
    elements = circular:collect(),
  })

  circular:enqueue("G")
  circular:enqueue("H")
  circular:rearrange(function()
    return true
  end)
  std.debug.log("8", {
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
  std.debug.log("9", {
    size = circular:size(),
    at1 = circular:at(1),
    at2 = circular:at(2),
    at3 = circular:at(3),
    at4 = circular:at(4),
    elements = circular:collect(),
  })

  circular:enqueue("K")
  circular:enqueue("L")
  std.debug.log("10", {
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
  std.debug.log("11", {
    size = circular:size(),
    at1 = circular:at(1),
    at2 = circular:at(2),
    at3 = circular:at(3),
    at4 = circular:at(4),
    elements = circular:collect(),
  })
end

circular_queue()

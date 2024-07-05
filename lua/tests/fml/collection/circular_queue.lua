local function circular_queue()
  local circular = fml.collection.CircularQueue.new({ capacity = 3 })
  circular:enqueue("A")
  circular:enqueue("B")
  circular:enqueue("C")

  print("size:" .. vim.inspect(circular:size()))
  print("1:" .. vim.inspect(circular:at(1)))
  print("2:" .. vim.inspect(circular:at(2)))
  print("3:" .. vim.inspect(circular:at(3)))
  print("elements:" .. vim.inspect(circular:collect()))

  circular:enqueue("D")
  print("size:" .. vim.inspect(circular:size()))
  print("1:" .. vim.inspect(circular:at(1)))
  print("2:" .. vim.inspect(circular:at(2)))
  print("3:" .. vim.inspect(circular:at(3)))
  print("elements:" .. vim.inspect(circular:collect()))

  circular:dequeue_back()
  print("size:" .. vim.inspect(circular:size()))
  print("1:" .. vim.inspect(circular:at(1)))
  print("2:" .. vim.inspect(circular:at(2)))
  print("3:" .. vim.inspect(circular:at(3)))
  print("elements:" .. vim.inspect(circular:collect()))

  circular:enqueue("E")
  circular:enqueue("F")
  print("size:" .. vim.inspect(circular:size()))
  print("1:" .. vim.inspect(circular:at(1)))
  print("2:" .. vim.inspect(circular:at(2)))
  print("3:" .. vim.inspect(circular:at(3)))
  print("elements:" .. vim.inspect(circular:collect()))

  local result0 = {}
  for element in circular:iterator() do
    table.insert(result0, element)
  end
  print("result0:" .. vim.inspect(result0))

  local result1 = {}
  for element in circular:iterator_reverse() do
    table.insert(result1, element)
  end
  print("result1:" .. vim.inspect(result1))

  while circular:size() > 1 do
    circular:dequeue_back()
  end
  print("elements:" .. vim.inspect(circular:collect()))
end

circular_queue()

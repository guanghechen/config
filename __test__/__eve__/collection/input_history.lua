local history = std.InputHistory.new({ name = "test", capacity = 5 })

-- Push some items
history:push("A")
history:push("B")
history:push("C")
assert(history:size() == 3)
assert(history:collect(), { "A", "B", "C" })

-- Verify they are in order
assert(history:at(1) == "A")
assert(history:at(2) == "B")
assert(history:at(3) == "C")
assert(history:present() == "C")
assert(select(2, history:present()) == 3)
assert(history:collect(), { "A", "B", "C" })

-- Move back to item B
local b, _ = history:backward()
assert(b == "B")
assert(history:size() == 3)
assert(history:collect(), { "A", "B", "C" })

-- Push a new item D - in InputHistory, we add to the end regardless of current position
history:push("D")
assert(history:size() == 4)
assert(history:collect(), { "A", "B", "C", "D" })

-- Verify D was added to the end and is now current
assert(history:at(1) == "A")
assert(history:at(2) == "B")
assert(history:at(3) == "C")
assert(history:at(4) == "D")
assert(history:present() == "D")
assert(select(2, history:present()) == 4)
assert(history:collect(), { "A", "B", "C", "D" })

-- Push duplicate item - should move present pointer, not add a duplicate
history:backward(2) -- Now at B
assert(history:present() == "B")
history:push("C") -- C already exists
assert(history:collect(), { "A", "B", "D", "C" })
assert(history:size() == 4) -- size should still be 4
assert(history:present() == "C") -- now at existing C

-- Navigation
assert(history:bottom() == "A")
local top, size = history:top()
assert(top == "C")
assert(size == 4)
assert(history:collect(), { "A", "B", "D", "C" })

-- Capacity limit
history:push("E")
history:push("F")
assert(history:collect(), { "B", "D", "C", "E", "F" })

-- A is pushed out of queue when capacity is reached
assert(history:size() == 5)
assert(history:at(1) == "B")
assert(history:at(5) == "F")

-- Update top
history:update_top("Updated")
assert(history:top() == "Updated")
assert(history:present() == "Updated")
assert(history:collect(), { "B", "D", "C", "E", "Updated" })

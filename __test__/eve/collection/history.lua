local history = eve.c.AdvanceHistory.new({
  name = "haha",
  capacity = 5,
  validate = function(v)
    return string.sub(v, 1, 1) ~= "_"
  end,
})

history:push("A")
history:push("B")
history:print()

history:backward()
history:print()

history:push("C")
history:print()

history:backward()
history:backward()
history:backward()
history:backward()
history:print()

history:push("_A")
history:push("_B")
history:push("E")
history:push("_D")
history:print()

history:push("A")
history:push("B")
history:push("B")
history:push("B")
history:push("B")
history:push("B")
history:push("B")
history:print()

history:backward(2)
history:print()

history:forward()
history:print()

history:push("A")
history:print()

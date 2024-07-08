local history = fml.collection.History.new({
  name = "haha",
  capacity = 5,
  validate = function(v)
    return string.sub(v, 1, 1) ~= "_"
  end,
})

history:push("A")
history:push("B")
history:print()

history:back()
history:print()

history:push("C")
history:print()

history:back()
history:back()
history:back()
history:back()
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

history:back(2)
history:print()

history:forward()
history:print()

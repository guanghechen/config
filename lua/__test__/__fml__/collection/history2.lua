local history = fml.collection.History.new({
  name = "haha",
  capacity = 5,
  validate = function(v)
    return string.sub(v, 1, 1) ~= "_"
  end,
})

history:push("A")
history:push("B")
history:push("C")
history:print()

history:back()
history:print()

history:back()
history:print()

history:back()
history:print()

history:back()
history:print()

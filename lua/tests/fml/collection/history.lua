local history = fml.collection.History.new({
  name = "haha",
  max_count = 50,
  validate = function(v)
    return string.sub(v, 1, 1) ~= '_'
  end
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

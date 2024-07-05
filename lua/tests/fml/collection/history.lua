local history = fml.collection.History.new({
  name = "haha",
  max_count = 50,
  validate = function()
    return true
  end,
  comparator = function(x, y)
    if x == y then
      return 0
    end
    return x < y and -1 or 1
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

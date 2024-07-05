local history = fml.collection.History.new({ name = "haha", max_count = 50 })

history:push("A")
history:push("B")
history:print()

history:solid_back()
history:print()

history:push("C")
history:print()

history:solid_back()
history:solid_back()
history:solid_back()
history:solid_back()
history:print()

local list = {
  { name = "alice", age = 18 },
  { name = "bob", age = 19 },
  { name = "cat", age = 18 },
  { name = "dog", age = 20 },
  { name = "eat", age = 21 },
  { name = "fat", age = 18 },
}

std.table.stable_sort(list, function(a, b)
  return a.age - b.age
end)

std.debug.log("1", { list = list })

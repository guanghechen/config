local a = {
  name = "alice",
  greet = function()
    print("Hello!")
  end,
}

local b = {}
setmetatable(b, { __index = a })

function b.great()
  print(", world!")
end

print(b.name)
b.great()

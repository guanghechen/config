local a = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 }
fml.debug.log("#a:", #a)

for i = 6, 10 do
  a[i] = nil
end

fml.debug.log("#a:", #a)

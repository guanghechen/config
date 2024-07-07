fml.debug.log("0 or 1 = ", 0 or 1)

local data = {}
fml.debug.log(vim.json.encode(data))

local a = { 12, 11, 10, 9, 8, 7, 6, 4, 3, 2, 1, 5, 0 }
table.sort(a)
fml.debug.log(a)

local fs = require("__test__.support.fs")
local t = require("__test__.support.harness").new()

t:test("write creates directories and keeps bytes; read returns them", function()
  local path = vim.fs.joinpath(t:tempdir(), "a/b/data.bin")
  fs.write(path, "one\r\ntwo\0three")
  t.assert_eq("one\r\ntwo\0three", fs.read(path))
end)

t:test("lines end with a newline as writefile writes them, and no lines leave the file empty", function()
  local root = t:tempdir()
  fs.write(root .. "/lines", { "one", "two" })
  t.assert_eq("one\ntwo\n", fs.read(root .. "/lines"))
  fs.write(root .. "/empty", {})
  t.assert_eq("", fs.read(root .. "/empty"))
end)

t:run()

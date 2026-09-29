---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.specs.ux.filetree.path" ---@type string

local t = require("__test__.support.harness").new("ux.filetree.path")
local env = require("stl.env")
local path = require("ux.filetree.path")

t:test("Unix path operations retain literal backslashes and filename bytes", function()
  t:patch_table(env, "IS_WIN", false)
  local value = "/work\\space/part\\" .. string.char(255) .. ".lua"
  t.assert_eq(value, path.from_os(value))
  t.assert_eq(value, path.to_os(value))
  t.assert_eq("/work\\space", path.dirname(value))
  t.assert_eq("part\\" .. string.char(255) .. ".lua", path.basename(value))
  t.assert_eq(".lua", path.extname(value))
  t.assert_eq(value:sub(2), path.relative("/", value))
  t.assert_eq("/work/space/../a", path.resolve("/work", "space/../a"))
  t.assert_eq("/work/C:part", path.resolve("/work", "C:part"))
  t.assert_eq("/", path.dirname("/"))
  t.assert_eq("/", path.dirname("/file"))
  t.assert_eq("", path.extname(".gitignore"))
end)

t:test("Windows slash paths round trip drive, UNC and verbatim roots", function()
  t:patch_table(env, "IS_WIN", true)
  for _, pair in ipairs({
    { [[C:\work\a.txt]], "C:/work/a.txt", "C:/" },
    { [[\\server\share\work\a.txt]], "//server/share/work/a.txt", "//server/share" },
    { [[\\?\C:\work\a.txt]], "//?/C:/work/a.txt", "//?/C:/" },
    { [[\\?\UNC\server\share\work\a.txt]], "//?/UNC/server/share/work/a.txt", "//?/UNC/server/share" },
  }) do
    local native, logical, root = unpack(pair)
    t.assert_eq(logical, path.from_os(native))
    t.assert_eq(native, path.to_os(logical))
    t.assert_eq("a.txt", path.basename(logical))
    t.assert_eq(root, path.dirname(path.dirname(logical)))
    t.assert_eq(root, path.dirname(root))
    t.assert_eq("work/a.txt", path.relative(root, logical))
    t.assert_eq(logical, path.resolve(root, "work/a.txt"))
  end
  t.assert_eq("C:/outside", path.resolve("C:/work", "/outside"))
  t.assert_eq("//server/share/outside", path.resolve("//server/share/work", "/outside"))
  t.assert_eq("C:/link/../a", path.resolve("C:/", "link/../a"))
  t.assert_eq("D:/work/a", path.relative("C:/work", "D:/work/a"))
  t.assert_false(pcall(path.resolve, "C:/work", "D:relative"))
end)

t:run()

---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.fixtures.dot.win.seed_marks" ---@type string

local dir = assert(arg[1])
vim.o.hidden = true
local names = {
  "first",
  "explicit",
  "batch_a",
  "batch_b",
  "batch_c",
  "preload",
  "native_plus",
  "native_default",
  "insert_open",
  "redirect",
  "replace",
  "replace_explicit",
  "close",
  "wipe",
  "rapid_a",
  "rapid_b",
  "batch_x",
  "batch_y",
  "final",
  "unloaded",
  "short",
  "empty",
  "native_jump",
  "space name_测试",
  "autocmd_close",
  "native_cursor",
  "native_start",
}
for _, name in ipairs(names) do
  local lines = {}
  for row = 1, 100 do
    lines[row] = string.format("local value_%03d = %d -- %s", row, row, name)
  end
  local path = dir .. "/" .. name .. ".lua"
  vim.fn.writefile(lines, path)
  vim.cmd("edit " .. vim.fn.fnameescape(path))
  vim.api.nvim_win_set_cursor(0, { 80, 6 })
end
vim.cmd("enew")
vim.cmd("wshada! " .. vim.fn.fnameescape(dir .. "/marks.shada"))
vim.fn.writefile({ "return 1" }, dir .. "/short.lua")
vim.fn.writefile({}, dir .. "/empty.lua")

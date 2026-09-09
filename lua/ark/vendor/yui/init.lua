---@diagnostic disable-next-line: unused-local
local __module_name__ = "ark.vendor.yui" ---@type string

pcall(require, "ark.vendor.local.autocmd")

dot.setup_context()

require("ark.vendor.yui.option")
require("ark.vendor.yui.keymap")
pcall(require, "ark.vendor.local.option")
pcall(require, "ark.vendor.local.keymap")

era.dressing.setup({ "im" })

vim.schedule(function()
  era.m.splitjoin.dressing()
  era.m.surrounds.setup()
end)

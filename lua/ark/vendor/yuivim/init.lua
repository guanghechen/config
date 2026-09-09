---@diagnostic disable-next-line: unused-local
local __module_name__ = "ark.vendor.yuivim" ---@type string

pcall(require, "ark.vendor.local.autocmd")

dot.setup_context()

require("ark.vendor.yuivim.option")
require("ark.vendor.yuivim.keymap")
pcall(require, "ark.vendor.local.option")
pcall(require, "ark.vendor.local.keymap")

era.dressing.setup({ "im" })

vim.schedule(function()
  era.m.splitjoin.setup()
  era.m.surrounds.setup()
end)

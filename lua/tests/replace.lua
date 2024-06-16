local nvim_tools = require("nvim_tools")
local JSON = require("guanghechen.util.json")

local options = JSON.stringify({
  cwd = ".",
  flag_regex = true,
  flag_case_sensitive = true,
  search_pattern = 'require\\("(guanghechen\\.util\\.(os|clipboard))"\\)',
  replace_pattern = 'import "$1"',
  search_paths = { "lua/" },
  include_patterns = { "*.lua" },
  exclude_patterns = { "" },
})
local result_str = nvim_tools.replace(options)
local result = JSON.parse(result_str)
vim.notify("result" .. vim.inspect(result))

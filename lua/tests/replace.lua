local guanghechen = require("guanghechen")
local ReplacePane = require("playground.replacer.pane")
local pane = ReplacePane.new()

---@type guanghechen.types.IReplaceState
local options = {
  cwd = guanghechen.util.path.cwd(),
  flag_regex = true,
  flag_case_sensitive = true,
  search_pattern = 'require\\("(guanghechen\\.util\\.(os|clipboard))"\\)',
  replace_pattern = 'import "$1"',
  search_paths = { "lua/" },
  include_patterns = { "*.lua" },
  exclude_patterns = { "" },
}

pane:open(0, options)

local function check_replace()
  local nvim_tools = require("nvim_tools")
  local JSON = require("guanghechen.util.json")
  local options_stringified = JSON.stringify(options)
  local result_str = nvim_tools.replace(options_stringified)
  local result = JSON.parse(result_str)
  vim.notify("result" .. vim.inspect(result))
end

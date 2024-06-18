local util_path = require("guanghechen.util.path")
local Replacer = require("kyokuya.replace.replacer")

---@type kyokuya.types.IReplacerState
local options = {
  mode = "replace",
  cwd = util_path.cwd(),
  flag_regex = true,
  flag_case_sensitive = true,
  search_pattern = 'require\\("(guanghechen\\.util\\.(os|clipboard))"\\)',
  replace_pattern = 'import "$1"',
  search_paths = { "lua/" },
  include_patterns = { "*.lua" },
  exclude_patterns = { "" },
}

local replacer = Replacer.new()
replacer:replace({
  winnr = 0,
  state = options,
})

local function check_replace()
  local nvim_tools = require("nvim_tools")
  local JSON = require("guanghechen.util.json")
  local options_stringified = JSON.stringify(options)
  local result_str = nvim_tools.replace(options_stringified)
  local result = JSON.parse(result_str)
  vim.notify("result" .. vim.inspect(result))
end

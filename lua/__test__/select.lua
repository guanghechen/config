local oxi = require("fml.std.oxi")
local Observable = require("fml.collection.observable")

local cwd = fml.path.cwd() ---@type string
---@type string[]
local paths = fml.oxi.find({
  workspace = fml.path.workspace(),
  cwd = fml.path.cwd(),
  flag_case_sensitive = false,
  flag_gitignore = true,
  flag_regex = false,
  search_pattern = "",
  search_paths = "",
  exclude_patterns = "",
})
local items = {} ---@type fml.types.ui.select.IItem[]
for _, path in ipairs(paths) do
  local item = { uuid = path, display = path, lower = path:lower() } ---@type fml.types.ui.select.IItem
  table.insert(items, item)
end
table.sort(items, function(a, b)
  return a.display < b.display
end)

local select = fml.ui.select.Select.new({
  title = "Select file",
  items = items,
  case_sensitive = Observable.from_value(false),
  input = Observable.from_value(""),
  visible = Observable.from_value(false),
  max_height = 25,
  render_line = fml.ui.select.defaults.render_filepath,
  on_confirm = function(item)
    local winnr = fml.api.state.win_history:present() ---@type integer
    if winnr ~= nil then
      local filepath = fml.path.join(cwd, item.display) ---@type string
      vim.schedule(function()
        fml.api.buf.open(winnr, filepath)
      end)
      return true
    end
    return false
  end,
})

select:toggle()

fml.debug.log(oxi.uuid())

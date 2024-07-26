local oxi = require("fml.std.oxi")
local Observable = require("fml.collection.observable")

local cwd = fml.path.cwd() ---@type string
local paths = fml.oxi.collect_file_paths(cwd, {
  ".git/**",
  "rust/*/target/**",
  "rust/*/debug/**",
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
  state = fml.ui.select.State.new({
    title = "Select file",
    uuid = oxi.uuid(),
    items = items,
    input = Observable.from_value(""),
    visible = Observable.from_value(false),
  }),
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

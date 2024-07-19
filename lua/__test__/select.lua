local oxi = require("fml.std.oxi")
local Observable = require("fml.collection.observable")

---@type fml.types.ui.select.IItem[]
local items = {}
local paths = fml.oxi.collect_file_paths(fml.path.cwd(), { ".git/**", "rust/target/**" })
for _, path in ipairs(paths) do
  local item = { display = path } ---@type fml.types.ui.select.IItem
  table.insert(items, item)
end

local select = fml.ui.select.Select.new({
  state = fml.ui.select.State.new({
    title = "Select file",
    uuid = oxi.uuid(),
    items = items,
    input = Observable.from_value(""),
    visible = Observable.from_value(false),
  }),
  render_line = fml.ui.select.util.default_render_filepath,
  on_confirm = function(item, idx)
    fml.debug.log("confirm:", { item = item, idx = idx })
  end,
})

select:toggle()

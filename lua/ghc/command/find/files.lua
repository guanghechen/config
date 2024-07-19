---@class ghc.command.find
local M = require("ghc.command.find.mod")

---@type fml.types.ui.select.ISelect|nil
local _select = nil

---@return fml.types.ui.select.ISelect
local function get_select()
  if _select == nil then
    local uuid = "eba42821-7a63-42b8-91bd-43a8005f2c91" ---@type string

    _select = fml.ui.select.Select.new({
      state = fml.ui.select.State.new({
        title = "Select file",
        uuid = uuid,
        items = {},
        input = fml.collection.Observable.from_value(""),
        visible = fml.collection.Observable.from_value(false),
      }),
      max_height = 25,
      render_line = fml.ui.select.util.default_render_filepath,
      on_confirm = function(item)
        local winnr = fml.api.state.win_history:present() ---@type integer
        if winnr ~= nil then
          local cwd = fml.path.cwd() ---@type string
          local filepath = fml.path.join(cwd, item.display) ---@type string
          vim.schedule(function()
            fml.api.buf.open(winnr, filepath)
          end)
          return true
        end
        return false
      end,
    })
  end

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
  _select.state:update_items(items)

  return _select
end

---@return nil
function M.files()
  local select = get_select() ---@type fml.types.ui.select.ISelect
  select:open()
end

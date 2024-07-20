---@class ghc.command.find
local M = require("ghc.command.find.mod")

local _select = nil ---@type fml.types.ui.select.ISelect|nil
local _uuid = "eba42821-7a63-42b8-91bd-43a8005f2c91" ---@type string
local _filepath = fml.path.locate_session_filepath({ filename = "select-" .. _uuid .. ".json" }) ---@type string

vim.api.nvim_create_autocmd("VimLeavePre", {
  callback = function()
    if _select ~= nil then
      local data = _select.state:dump() ---@type fml.types.ui.select.state.ISerializedData
      fml.fs.write_json(_filepath, data)
    end
  end,
})

---@return fml.types.ui.select.ISelect
local function get_select()
  if _select == nil then
    _select = fml.ui.select.Select.new({
      state = fml.ui.select.State.new({
        title = "Select file",
        uuid = _uuid,
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

    local data = fml.fs.read_json({ filepath = _filepath, silent_on_bad_path = true, silent_on_bad_json = false })
    if data ~= nil then
      _select.state:load(data)
    end
  end

  local cwd = fml.path.cwd() ---@type string
  local paths = fml.oxi.collect_file_paths(cwd, {
    ".cache/**",
    ".git/**",
    ".yarn/**",
    "**/build/**",
    "**/debug/**",
    "**/node_modules/**",
    "**/target/**",
    "**/tmp/**",
    "**/*.pdf",
    "**/*.mkv",
    "**/*.mp4",
    "**/*.zip",
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

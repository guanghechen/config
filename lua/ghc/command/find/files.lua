local constant = require("fml.constant")
local History = require("fml.collection.history")
local statusline = require("ghc.ui.statusline")
local session = require("ghc.context.session")
local util_find_scope = require("ghc.util.find.scope")

---@class ghc.command.find.files.IConfigData
---@field public exclude_patterns       string[]

---@class ghc.command.find.files.IStateData
---@field frecency                      ?fml.types.collection.frecency.ISerializedData|nil
---@field input_history                 ?fml.types.collection.history.ISerializedData|nil

---@class ghc.command.find
local M = require("ghc.command.find.mod")

---@type string
local _filepath = fml.path.locate_session_filepath({ filename = "state.find_files.json" })

---@type fml.types.collection.IFrecency
local _frecency = fml.collection.Frecency.new({
  items = {},
  normalize = function(key)
    return fml.md5.sumhexa(key)
  end,
})

---@type fml.types.collection.IHistory
local _input_history = History.new({
  name = "find_files",
  capacity = 100,
  validate = fml.string.is_non_blank_string,
})

local _state_data = fml.fs.read_json({ filepath = _filepath, silent_on_bad_path = true, silent_on_bad_json = false })
if _state_data ~= nil then
  ---@cast _state_data ghc.command.find.files.IStateData
  _frecency:load(_state_data.frecency)
  _input_history:load(_state_data.input_history)
end
local _select = nil ---@type fml.types.ui.select.ISelect|nil

local state_dirpath = fml.collection.Observable.from_value(vim.fn.expand("%:p:h"))
local state_find_cwd = fml.collection.Observable.from_value(
  util_find_scope.get_cwd(session.find_scope:snapshot(), state_dirpath:snapshot()) ---@type string
)

fml.disposable:add_disposable(fml.collection.Disposable.new({
  on_dispose = function()
    if _select ~= nil then
      local ok, data = pcall(function()
        local frecency = _frecency:dump() ---@type fml.types.collection.frecency.ISerializedData
        local input_history = _input_history:dump() ---@type fml.types.collection.history.ISerializedData
        local stack = input_history.stack ---@type fml.types.T[]
        if #stack > 0 then
          local prefix = constant.EDITING_INPUT_PREFIX ---@type string
          local top = stack[#stack] ---@type string
          if #top > #prefix and string.sub(top, 1, #prefix) == prefix then
            stack[#stack] = string.sub(top, #prefix + 1)
          end
        end
        return { frecency = frecency, input_history = input_history } ---@type ghc.command.find.files.IStateData
      end)
      if ok then
        fml.fs.write_json(_filepath, data, false)
      else
        fml.fs.write_json(_filepath, { error = data }, false)
      end
    end
  end,
}))

---@param scope                         ghc.enums.context.FindScope
---@return nil
local function change_scope(scope)
  local scope_current = session.find_scope:snapshot() ---@type ghc.enums.context.FindScope
  if _select ~= nil and scope_current ~= scope then
    session.find_scope:next(scope)
    local dirpath = state_dirpath:snapshot() ---@type string
    local find_cwd = util_find_scope.get_cwd(scope, dirpath) ---@type string
    state_find_cwd:next(find_cwd)
    M.reload()
  end
end

---@return nil
local function edit_config()
  ---@type ghc.command.find.files.IConfigData
  local data = {
    exclude_patterns = session.find_exclude_pattern:snapshot(),
  }
  local setting = fml.ui.Setting.new({
    position = "center",
    width = 100,
    title = "Edit Configuration (find files)",
    validate = function(raw_data)
      if type(raw_data) ~= "table" then
        return "Invalid find_files configuration, expect an object."
      end
      ---@cast raw_data ghc.command.find.files.IConfigData
      if raw_data.exclude_patterns == nil or not fml.is.array(raw_data.exclude_patterns) then
        return "Invalid data.exclude_patterns, expect an array."
      end
    end,
    on_confirm = function(raw_data)
      ---@cast raw_data ghc.command.replace.state.IData
      local raw = vim.tbl_extend("force", data, raw_data)

      local exclude_patterns = raw.exclude_patterns ---@type string[]
      session.find_exclude_pattern:next(exclude_patterns)
      M.reload()
    end,
  })
  setting:open({
    initial_value = data,
    text_cursor_row = 1,
    text_cursor_col = 1,
  })
end

---@return nil
function M.reload()
  if _select ~= nil then
    local find_cwd = state_find_cwd:snapshot() ---@type string
    local exclude_pattern = session.find_exclude_pattern:snapshot() ---@type string[]
    local paths = fml.oxi.collect_file_paths(find_cwd, exclude_pattern)
    local items = {} ---@type fml.types.ui.select.IItem[]
    for _, path in ipairs(paths) do
      local item = { uuid = path, display = path, lower = path:lower() } ---@type fml.types.ui.select.IItem
      table.insert(items, item)
    end
    table.sort(items, function(a, b)
      return a.display < b.display
    end)
    _select.state:update_items(items)
  end
end

---@return fml.types.ui.select.ISelect
local function get_select()
  if _select == nil then
    local actions = {
      change_scope_workspace = function()
        change_scope("W")
      end,
      change_scope_cwd = function()
        change_scope("C")
      end,
      change_scope_directory = function()
        change_scope("D")
      end,
      change_scope_carousel = function()
        ---@type ghc.enums.context.FindScope
        local scope = session.find_scope:snapshot()
        local scope_next = util_find_scope.get_carousel_next(scope)
        change_scope(scope_next)
      end,
    }

    ---@type fml.types.IKeymap[]
    local input_keymaps = {
      {
        modes = { "i", "n" },
        key = "<c-b>c",
        callback = edit_config,
        desc = "find: edit configuration",
      },
      {
        modes = { "n", "v" },
        key = "<leader>w",
        callback = actions.change_scope_workspace,
        desc = "find: change scope (workspace)",
      },
      {
        modes = { "n", "v" },
        key = "<leader>c",
        callback = actions.change_scope_cwd,
        desc = "find: change scope (cwd)",
      },
      {
        modes = { "n", "v" },
        key = "<leader>d",
        callback = actions.change_scope_directory,
        desc = "find: change scope (directory)",
      },
      {
        modes = { "n", "v" },
        key = "<leader>s",
        callback = actions.change_scope_carousel,
        desc = "find: change scope (carousel)",
      },
    }

    ---@type fml.types.IKeymap[]
    local main_keymaps = vim.tbl_deep_extend("force", {}, input_keymaps)

    _select = fml.ui.select.Select.new({
      state = fml.ui.select.State.new({
        title = "Find files",
        items = {},
        input = session.find_file_pattern,
        input_history = _input_history,
        frecency = _frecency,
        visible = fml.collection.Observable.from_value(false),
      }),
      width = 0.4,
      height = 0.5,
      render_line = fml.ui.select.defaults.render_filepath,
      input_keymaps = input_keymaps,
      main_keymaps = main_keymaps,
      on_close = function()
        statusline.disable(statusline.cnames.find_files)
      end,
      on_confirm = function(item)
        local winnr = fml.api.state.win_history:present() ---@type integer
        if winnr ~= nil then
          local cwd = state_find_cwd:snapshot() ---@type string
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

  local scope = session.find_scope:snapshot() ---@type ghc.enums.context.FindScope
  local find_cwd = util_find_scope.get_cwd(scope, state_dirpath:snapshot()) ---@type string
  state_find_cwd:next(find_cwd)
  M.reload()

  return _select
end

---@return nil
function M.files()
  state_dirpath:next(vim.fn.expand("%:p:h"))
  local select = get_select() ---@type fml.types.ui.select.ISelect
  statusline.enable(statusline.cnames.find_files)
  select:open()
end

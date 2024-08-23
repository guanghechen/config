local ORIDINAL_WIDTH = vim.fn.strwidth(tostring(fml.constant.WIN_BUF_HISTORY_CAPACITY)) ---@type integer
local unique_ = fml.collection.Observable.from_value(false) ---@type fml.types.collection.IObservable

local _select = nil ---@type fml.ui.FileSelect|nil

---@param ordinal                       integer
---@return string
local function gen_uuid_from_ordinal(ordinal)
  return fml.string.pad_start(tostring(ordinal), ORIDINAL_WIDTH, " ")
end

---@param initial_title                 string
---@return fml.ui.FileSelect
local function get_select(initial_title)
  local state_frecency = require("ghc.state.frecency")
  local frecency = state_frecency.load_and_autosave().files ---@type fml.types.collection.IFrecency

  ---@type fml.types.ui.file_select.IProvider
  local provider = {
    fetch_data = function()
      local cwd = fml.path.cwd() ---@type string
      local unique = unique_:snapshot() ---@type boolean
      local winnr = fml.api.state.win_history:present() ---@type integer|nil
      local win = winnr ~= nil and fml.api.state.wins[winnr] or nil ---@type fml.types.api.state.IWinItem|nil
      if win == nil then
        fml.reporter.error({
          from = "fml.api.win",
          subject = "find_history",
          message = "Cannot find window.",
          details = { winnr = winnr, unique = unique },
        })

        ---@type fml.types.ui.file_select.IData
        return { cwd = cwd, items = {} }
      end

      local items = {} ---@type fml.types.ui.file_select.IRawItem[]
      local present_uuid = "0" ---@type string

      if unique then
        local present_filepath = win.filepath_history:present() ---@type string|nil
        local visited = {} ---@type table<string, boolean>
        for absolute_filepath, ordinal in win.filepath_history:iterator_reverse() do
          local filepath = fml.path.relative(cwd, absolute_filepath) ---@type string
          if not visited[filepath] then
            visited[filepath] = true

            local uuid = gen_uuid_from_ordinal(ordinal) ---@type string
            if present_filepath == absolute_filepath then
              present_uuid = uuid
            end

            local item = { uuid = uuid, filepath = filepath } ---@type fml.types.ui.file_select.IRawItem
            table.insert(items, item)
          end
        end
      else
        local present_ordinal = win.filepath_history:present_index() ---@type integer
        if present_ordinal ~= nil then
          present_uuid = gen_uuid_from_ordinal(present_ordinal)
        end

        for absolute_filepath, ordinal in win.filepath_history:iterator_reverse() do
          local filepath = fml.path.relative(cwd, absolute_filepath) ---@type string
          local uuid = gen_uuid_from_ordinal(ordinal) ---@type string
          local item = { uuid = uuid, filepath = filepath } ---@type fml.types.ui.file_select.IRawItem
          table.insert(items, item)
        end
      end

      local width = 0 ---@type integer
      for _, item in ipairs(items) do
        local w = vim.fn.strwidth(item.filepath) ---@type integer
        width = width < w and w or width
      end

      if _select ~= nil then
        _select:change_dimension({ height = #items + 3, width = width + 16 })
      end

      ---@type fml.types.ui.file_select.IData
      return { cwd = cwd, items = items, present_uuid = present_uuid }
    end,
    render_item = function(item, match)
      local text_prefix = item.uuid .. " " ---@type string
      local width_prefix = ORIDINAL_WIDTH + 1 ---@type integer
      local width_icon = string.len(item.data.icon) ---@type integer
      local text = text_prefix .. item.data.icon .. item.data.filepath ---@type string

      ---@type fml.types.ui.IInlineHighlight[]
      local highlights = {
        {
          coll = width_prefix,
          colr = width_prefix + width_icon,
          hlname = item.data.icon_hl,
        },
      }
      for _, piece in ipairs(match.matches) do
        ---@type fml.types.ui.IInlineHighlight
        local highlight = {
          coll = width_prefix + width_icon + piece.l,
          colr = width_prefix + width_icon + piece.r,
          hlname = "f_us_main_match",
        }
        table.insert(highlights, highlight)
      end
      return text, highlights
    end,
  }

  if _select == nil then
    _select = fml.ui.FileSelect.new({
      destroy_on_close = true,
      enable_preview = false,
      frecency = frecency,
      provider = provider,
      title = initial_title,
      on_close = function()
        if _select ~= nil then
          _select:mark_data_dirty()
        end
      end,
      on_confirm = function(item)
        local item_index = tonumber(item.uuid) ---@type integer|nil
        if item_index ~= nil then
          local winnr = fml.api.state.win_history:present() ---@type integer|nil
          local win = winnr ~= nil and fml.api.state.wins[winnr] or nil ---@type fml.types.api.state.IWinItem|nil
          if win ~= nil then
            win.filepath_history:go(item_index)
          end
        end

        if _select ~= nil then
          local cwd = fml.path.cwd() ---@type string
          local filepath = fml.path.join(cwd, item.data.filepath) ---@type string
          return fml.api.buf.open_in_current_valid_win(filepath)
        end
        return false
      end,
    })
  end
  return _select
end

---@class ghc.command.find_win_history
local M = {}

---@return nil
function M.list_history()
  unique_:next(false)
  local title = "window history" ---@type string
  local select = get_select(title) ---@type fml.ui.FileSelect
  select:change_input_title(title)
  select:focus()
end

---@return nil
function M.list_history_unique()
  local title = "window history (unique)" ---@type string
  local select = get_select(title) ---@type fml.ui.FileSelect
  unique_:next(true)
  select:change_input_title(title)
  select:focus()
end

return M

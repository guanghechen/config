local ORIDINAL_WIDTH = vim.fn.strwidth(tostring(eve.constants.WIN_BUF_HISTORY_CAPACITY)) ---@type integer

local _select = nil ---@type fml.ui.FileSelect|nil

---@param ordinal                       integer
---@return string
local function gen_uuid_from_ordinal(ordinal)
  return eve.string.pad_start(tostring(ordinal), ORIDINAL_WIDTH, " ")
end

---@return fml.ui.FileSelect
local function get_select()
  if _select == nil then
    local state_frecency = require("ghc.state.frecency")
    local frecency = state_frecency.load_and_autosave().files ---@type eve.types.collection.IFrecency

    ---@type fml.types.ui.file_select.IProvider
    local provider = {
      fetch_data = function()
        local cwd = eve.path.cwd() ---@type string
        local items = {} ---@type fml.types.ui.file_select.IRawItem[]
        local present_uuid = "0" ---@type string
        local width = 0 ---@type integer
        local winnr = eve.widgets:get_current_winnr() ---@type integer|nil
        local win = winnr ~= nil and fml.api.state.wins[winnr] or nil ---@type fml.types.api.state.IWinItem|nil
        if win == nil then
          eve.reporter.error({
            from = "fml.api.win",
            subject = "find_history",
            message = "Cannot find window.",
            details = { winnr = winnr },
          })

          ---@type fml.types.ui.file_select.IData
          return { cwd = cwd, items = {} }
        else
          local _, present_ordinal = win.filepath_history:present() ---@type string|nil, integer|nil
          if present_ordinal ~= nil then
            present_uuid = gen_uuid_from_ordinal(present_ordinal)
          end

          for absolute_filepath, ordinal in win.filepath_history:iterator_reverse() do
            local filepath = eve.path.relative(cwd, absolute_filepath, true) ---@type string
            local uuid = gen_uuid_from_ordinal(ordinal) ---@type string
            local item = { uuid = uuid, filepath = filepath } ---@type fml.types.ui.file_select.IRawItem
            table.insert(items, item)
          end

          for _, item in ipairs(items) do
            local w = vim.fn.strwidth(item.filepath) ---@type integer
            width = width < w and w or width
          end
        end

        if _select ~= nil then
          width = math.max(width + 16, 60)
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

        ---@type eve.types.ux.IInlineHighlight[]
        local highlights = {
          {
            coll = width_prefix,
            colr = width_prefix + width_icon,
            hlname = item.data.icon_hl,
          },
        }
        for _, piece in ipairs(match.matches) do
          ---@type eve.types.ux.IInlineHighlight
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

    _select = fml.ui.FileSelect.new({
      dimension = { height = 3 },
      dirty_on_invisible = true,
      enable_preview = false,
      extend_preset_keymaps = true,
      frecency = frecency,
      provider = provider,
      title = "Find Window History",
      on_confirm = function(item)
        local item_index = tonumber(item.uuid) ---@type integer|nil
        if item_index ~= nil then
          local winnr = eve.widgets:get_current_winnr() ---@type integer|nil
          local win = winnr ~= nil and fml.api.state.wins[winnr] or nil ---@type fml.types.api.state.IWinItem|nil
          if win ~= nil then
            win.filepath_history:go(item_index)
          end
        end

        if _select ~= nil then
          local cwd = eve.path.cwd() ---@type string
          local filepath = eve.path.join(cwd, item.data.filepath) ---@type string
          local ok = fml.api.buf.open_in_current_valid_win(filepath)
          return ok and "close" or "none"
        end
        return "none"
      end,
    })
  end
  return _select
end

---@class ghc.command.find_win_history
local M = {}

---@return nil
function M.focus()
  local select = get_select() ---@type fml.ui.FileSelect
  select:focus()
end

return M

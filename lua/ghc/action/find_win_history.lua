local ORIDINAL_WIDTH = vim.api.nvim_strwidth(tostring(eve.constants.WIN_BUF_HISTORY_CAPACITY)) ---@type integer

local _select = nil ---@type fml.ux.FileSelect|nil

---@param ordinal                       integer
---@return string
local function gen_uuid_from_ordinal(ordinal)
  return eve.string.pad_start(tostring(ordinal), ORIDINAL_WIDTH, " ")
end

---@return fml.ux.FileSelect
local function get_select()
  if _select == nil then
    local frecency = eve.context.state.frecency.files ---@type t.eve.collection.IFrecency

    ---@type t.fml.ux.file_select.IProvider
    local provider = {
      fetch_data = function()
        local cwd = eve.path.cwd() ---@type string
        local items = {} ---@type t.fml.ux.file_select.IRawItem[]
        local present_uuid = "0" ---@type string
        local width = 0 ---@type integer
        local winnr = eve.locations.get_current_winnr() ---@type integer|nil
        local win = winnr ~= nil and eve.context.state.wins[winnr] or nil ---@type t.eve.context.state.win.IItem|nil
        if win == nil then
          eve.reporter.error({
            from = "ghc.action.find_win_history",
            message = "Cannot find window.",
            details = { winnr = winnr },
          })

          ---@type t.fml.ux.file_select.IData
          return { cwd = cwd, items = {} }
        else
          local _, present_ordinal = win.filepath_history:present() ---@type string|nil, integer|nil
          if present_ordinal ~= nil then
            present_uuid = gen_uuid_from_ordinal(present_ordinal)
          end

          for absolute_filepath, ordinal in win.filepath_history:iterator_reverse() do
            local filepath = eve.path.relative(cwd, absolute_filepath, true) ---@type string
            local uuid = gen_uuid_from_ordinal(ordinal) ---@type string
            local item = { uuid = uuid, filepath = filepath } ---@type t.fml.ux.file_select.IRawItem
            table.insert(items, item)
          end

          for _, item in ipairs(items) do
            local w = vim.api.nvim_strwidth(item.filepath) ---@type integer
            width = width < w and w or width
          end
        end

        if _select ~= nil then
          width = math.max(width + 16, 60)
          _select:change_dimension({ height = #items + 3, width = width + 16 })
        end

        ---@type t.fml.ux.file_select.IData
        return { cwd = cwd, items = items, present_uuid = present_uuid }
      end,
      render_item = function(item, match)
        local text_prefix = item.uuid .. " " ---@type string
        local width_prefix = ORIDINAL_WIDTH + 1 ---@type integer
        local width_icon = string.len(item.data.icon) ---@type integer
        local text = text_prefix .. item.data.icon .. item.data.filepath ---@type string

        ---@type t.eve.IHighlightInline[]
        local highlights = {
          {
            coll = width_prefix,
            colr = width_prefix + width_icon,
            hlname = item.data.icon_hl,
          },
        }
        for _, piece in ipairs(match.matches) do
          ---@type t.eve.IHighlightInline
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

    _select = fml.ux.FileSelect.new({
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
          local winnr = eve.locations.get_current_winnr() ---@type integer|nil
          local win = winnr ~= nil and eve.context.state.wins[winnr] or nil ---@type t.eve.context.state.win.IItem|nil
          if win ~= nil then
            win.filepath_history:go(item_index)
          end
        end

        if _select ~= nil then
          local cwd = eve.path.cwd() ---@type string
          local filepath = eve.path.join(cwd, item.data.filepath) ---@type string
          local ok = fml.api.buf.open_filepath_in_current_valid_win(filepath)
          return ok and "close" or "none"
        end
        return "none"
      end,
    })
  end
  return _select
end

---@class ghc.action.find_win_history
local M = {}

---@return nil
function M.focus()
  local select = get_select() ---@type fml.ux.FileSelect
  select:focus()
end

return M

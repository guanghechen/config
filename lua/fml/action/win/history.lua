local __module_name__ = "fml.action.win" ---@type string

local setting = require("eve.constant.setting")
local editor = require("eve.module.editor")
local state = require("eve.state")

local FileSelect = require("fml.ux.file_select")

local _history_select = nil ---@type fml.ux.FileSelect|nil

---@return fml.ux.FileSelect
local function get_history_select()
  if _history_select == nil then
    local ORDINAL_WIDTH = vim.api.nvim_strwidth(tostring(setting.WIN_BUF_HISTORY_CAPACITY)) ---@type integer
    local frecency = state.frecency.files ---@type eve.collection.IFrecency

    ---@param ordinal                       integer
    ---@return string
    local function gen_uuid_from_ordinal(ordinal)
      return eve.std.string.pad_start(tostring(ordinal), ORDINAL_WIDTH, " ")
    end

    ---@type fml.ux.file_select.IProvider
    local provider = {
      fetch_data = function()
        local cwd = eve.path.cwd() ---@type string
        local items = {} ---@type fml.ux.file_select.IRawItem[]
        local uuid_present = "0" ---@type string
        local width = 0 ---@type integer

        local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
        local winnr_sourcefile = state.tab.get_winnr_sourcefile(tabnr) ---@type integer|nil

        local meta = winnr_sourcefile and state.win.resolve(winnr_sourcefile) or nil ---@type eve.t.state.win.meta.state|nil
        if meta == nil then
          eve.std.reporter.error({
            from = __module_name__,
            message = "Cannot find window.",
            details = { winnr_source = winnr_sourcefile },
          })
          ---@type fml.ux.file_select.IData
          return { cwd = cwd, items = {} }
        else
          local _, present_ordinal = meta.filepath_history:present() ---@type string|nil, integer|nil
          if present_ordinal ~= nil then
            uuid_present = gen_uuid_from_ordinal(present_ordinal)
          end

          for filepath, ordinal in meta.filepath_history:iterator_reverse() do
            local relative_filepath = eve.path.relative(cwd, filepath, true) ---@type string
            local uuid = gen_uuid_from_ordinal(ordinal) ---@type string
            ---@type fml.ux.file_select.IRawItem
            local item = {
              uuid = uuid,
              filepath = filepath,
              filepath_relative = relative_filepath,
            }
            items[#items + 1] = item
          end

          for _, item in ipairs(items) do
            local w = vim.api.nvim_strwidth(item.filepath) ---@type integer
            width = width < w and w or width
          end
        end

        if _history_select ~= nil then
          width = math.max(width + 16, 60)
          _history_select:change_dimension({ height = #items + 3, width = width + 16 })
        end

        ---@type fml.ux.file_select.IData
        return { cwd = cwd, items = items, uuid_present = uuid_present }
      end,
      render_item = function(item, match)
        local text_prefix = item.uuid .. " " ---@type string
        local width_prefix = ORDINAL_WIDTH + 1 ---@type integer
        local width_icon = string.len(item.data.icon) ---@type integer
        local text = text_prefix .. item.data.icon .. item.data.filepath_relative ---@type string

        ---@type eve.t.IHighlightInline[]
        local highlights = {
          {
            coll = width_prefix,
            colr = width_prefix + width_icon,
            hlname = item.data.icon_hl,
          },
        }
        for _, piece in ipairs(match.matches) do
          ---@type eve.t.IHighlightInline
          local highlight = {
            coll = width_prefix + width_icon + piece.l,
            colr = width_prefix + width_icon + piece.r,
            hlname = "f_us_main_match",
          }
          highlights[#highlights + 1] = highlight
        end
        return text, highlights
      end,
    }

    _history_select = FileSelect.new({
      dimension = { height = 3 },
      dirty_on_invisible = true,
      preview_enabled = false,
      extend_preset_keymaps = true,
      frecency = frecency,
      multiple = false,
      provider = provider,
      title = "Find Window History",
      on_confirm = function(widget, items)
        if #items == 1 then
          local item = items[1] ---@type fml.ux.select.IItem
          local item_index = tonumber(item.uuid) ---@type integer|nil
          local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
          local winnr_sourcefile = state.tab.get_winnr_sourcefile(tabnr) ---@type integer|nil

          if item_index ~= nil then
            local meta = winnr_sourcefile and state.win.resolve(winnr_sourcefile) or nil ---@type eve.t.state.win.meta.state|nil
            if meta ~= nil then
              meta.filepath_history:go(item_index)
            end
          end

          if winnr_sourcefile ~= nil then
            widget:close()
            editor.open_filepath(winnr_sourcefile, item.data.filepath)
          end
        end
      end,
    })
  end
  return _history_select
end

---@class fml.action.win
local M = {}

---@return nil
function M.history()
  local select = get_history_select() ---@type fml.ux.FileSelect
  select:show()
end

---@return nil
function M.history_backward()
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer

  local buftype = vim.bo[bufnr].buftype ---@type string
  if buftype == "quickfix" then
    state.qflist.backward()
    return
  end

  local meta = state.win.resolve(winnr) ---@type eve.t.state.win.meta.state|nil
  if meta == nil then
    eve.std.reporter.error({
      from = __module_name__,
      subject = "history_backward",
      message = "Cannot find window.",
      details = { winnr = winnr },
    })
    return
  end

  local last_filepath = meta.filepath_history:backward() ---@type string|nil
  if last_filepath ~= nil then
    editor.open_filepath(winnr, last_filepath)
  end
end

---@return nil
function M.history_forward()
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer

  local buftype = vim.bo[bufnr].buftype ---@type string
  if buftype == "quickfix" then
    state.qflist.forward()
    return
  end

  local meta = state.win.resolve(winnr) ---@type eve.t.state.win.meta.state|nil
  if meta == nil then
    eve.std.reporter.error({
      from = __module_name__,
      subject = "history_forward",
      message = "Cannot find window.",
      details = { winnr = winnr },
    })
    return
  end

  local next_filepath = meta.filepath_history:forward() ---@type string|nil
  if next_filepath ~= nil then
    editor.open_filepath(winnr, next_filepath)
  end
end

return M

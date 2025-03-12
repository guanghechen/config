local fn = require("eve.builtin.fn")
local path = require("eve.builtin.path")
local ft = require("eve.constant.filetype")
local icons = require("eve.constant.icon")
local editor = require("eve.module.editor")
local calc_fileicon = require("eve.module.fileicon").calc_fileicon
local winpicker = require("eve.module.winpicker")
local command = require("eve.command")
local state = require("eve.state")

local Select = require("fml.ux.select")

---@class fml.action.find.buffers.IItemData
---@field public bufnr                  integer
---@field public buftype                string
---@field public filetype               string
---@field public filepath               string
---@field public filename               string
---@field public icon                   string
---@field public icon_hl                string

local _select ---@type fml.ux.ISelect|nil

---@return fml.ux.ISelect
local function get_select()
  if _select == nil then
    local scopes = vim.list_slice(state.select.find_buffer_scopes) ---@type eve.e.FindBufferScope[]

    ---@type eve.t.ux.widget.IRawStatuslineItem[]
    local statusline_items = {
      {
        type = "enum",
        desc = "find(buffer): toggle scope",
        symbol = "",
        state = state.select.find_buffer_scope,
        callback = function()
          local scope = state.select.find_buffer_scope:snapshot() ---@type eve.e.FindBufferScope
          local idx = fn.find_index(scopes, scope) or 1 ---@type integer
          local idx_next = idx == #scopes and 1 or idx + 1 ---@type integer
          local next_scope = scopes[idx_next] ---@type eve.e.FindBufferScope
          state.select.find_buffer_scope:next(next_scope)

          if _select ~= nil then
            _select:mark_data_dirty()
          end
        end,
      },
      {
        type = "flag",
        desc = "find(buffer): toggle selected",
        symbol = icons.symbols.flag_selected,
        state = state.select.find_buffer.flag_selected,
        callback = function()
          local flag = state.select.find_buffer.flag_selected:snapshot() ---@type boolean
          state.select.find_buffer.flag_selected:next(not flag)
        end,
      },
    }

    ---@type eve.t.IKeymap[]
    local main_keymaps = {
      {
        modes = { "i", "n", "v" },
        key = "<C-d>",
        desc = "buffer: close",
        callback = function()
          if _select == nil then
            return
          end

          local item = _select:get_item_selected()
          if item == nil then
            return
          end

          local bufnr = item.data.bufnr ---@type integer
          if not fn.is_buf_valid(bufnr) then
            return
          end

          if not editor.is_buf_sourcefile(bufnr) then
            if fn.is_buf_valid(bufnr) then
              vim.api.nvim_buf_delete(bufnr, { force = true })
            end
            _select:mark_item_deleted(item.uuid)
            return
          end

          local tabnrs = vim.api.nvim_list_tabpages() ---@type integer[]
          for _, tabnr in ipairs(tabnrs) do
            state.tab.on_bufs_close(tabnr, { bufnr })
          end

          local unrefereced_bufnrs = state.tab.get_unrefereced_bufnrs() ---@type integer[]
          if #unrefereced_bufnrs > 0 then
            for _, unreferenced_bufnr in ipairs(unrefereced_bufnrs) do
              vim.api.nvim_buf_delete(unreferenced_bufnr, { force = true })
            end
            _select:mark_item_deleted(item.uuid)
            _select:mark_data_dirty()
          end
        end,
      },
    }

    ---@type fml.ux.select.IProvider
    local provider = {
      fetch_data = function()
        local cwd = path.cwd() ---@type string
        local scope = state.select.find_buffer_scope:snapshot() ---@type eve.e.FindBufferScope
        local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
        local meta_tab = state.tab.resolve(tabnr) ---@type eve.state.tab.meta.state|nil

        ---@param bufnr                     integer
        ---@return boolean
        local function should_show(bufnr)
          if scope == "A" then
            return true
          end

          local filetype = vim.bo[bufnr].filetype ---@type string
          if scope == "T" then
            return filetype == ft.TERM
          end

          if scope == "F" then
            return meta_tab and meta_tab:find_buf(bufnr) ~= nil or false
          end

          if
            filetype == ft.SEARCH_INPUT
            or filetype == ft.SEARCH_MAIN
            or filetype == ft.SEARCH_PREVIEW
            or filetype == ft.WINSEP
          then
            return false
          end
          return true
        end

        local items = {} ---@type fml.ux.select.IItem[]
        local bufnrs = vim.api.nvim_list_bufs() ---@type integer[]
        for _, bufnr in ipairs(bufnrs) do
          if should_show(bufnr) then
            local buftype = vim.bo[bufnr].buftype ---@type string
            local filetype = vim.bo[bufnr].filetype ---@type string
            local filepath = vim.api.nvim_buf_get_name(bufnr) ---@type string
            local relative_filepath = path.relative(cwd, filepath, true) ---@type string
            local filename = path.basename(filepath)
            local icon, icon_hl = calc_fileicon(filename)

            ---@type fml.action.find.buffers.IItemData
            local data = {
              bufnr = bufnr,
              buftype = buftype,
              filetype = filetype,
              filepath = relative_filepath,
              filename = filename,
              icon = icon,
              icon_hl = icon_hl,
            }

            local text = string.format(
              "%-5d %-10s %-15s %s %s",
              bufnr,
              buftype or vim.NIL,
              filetype,
              #filepath > 0 and icon or " ",
              relative_filepath
            )
            local item = { uuid = tostring(bufnr), text = text, data = data }
            items[#items + 1] = item
          end
        end

        table.sort(items, function(a, b)
          return a.data.bufnr < b.data.bufnr
        end)

        ---@type fml.ux.select.IData
        return { items = items }
      end,
      render_item = function(item, match)
        local data = item.data ---@type fml.action.find.buffers.IItemData

        ---@type eve.t.IHighlightInline[]
        local highlights = {
          { coll = 0, colr = 5, hlname = "f_buf_nr" },
          { coll = 6, colr = 16, hlname = "f_buf_buftype" },
          { coll = 17, colr = 32, hlname = "f_buf_filetype" },
          { coll = 33, colr = 35, hlname = data.icon_hl },
          { coll = 35, colr = -1, hlname = "f_buf_filepath" },
        }

        for _, piece in ipairs(match.matches) do
          ---@type eve.t.IHighlightInline[]
          local highlight = { coll = piece.l, colr = piece.r, hlname = "f_us_main_match" }
          table.insert(highlights, highlight)
        end
        return item.text, highlights
      end,
    }

    ---@type fml.ux.ISelect
    _select = Select.new({
      dimension = {
        height = 0.8,
        max_height = 1,
        max_width = 1,
        width = 120,
      },
      dirty_on_invisible = true,
      flag_case_sensitive = state.select.find_buffer.flag_case_sensitive,
      flag_fuzzy = state.select.find_buffer.flag_fuzzy,
      flag_regex = state.select.find_buffer.flag_regex,
      flag_selected = state.select.find_buffer.flag_selected,
      input = state.select.find_buffer.input,
      input_history = state.select.find_buffer.input_history,
      input_keymaps = main_keymaps,
      main_keymaps = main_keymaps,
      multiple = true,
      preview_enabled = false,
      extend_preset_keymaps = true,
      statusline_items = statusline_items,
      provider = provider,
      title = "Find buffers",
      on_confirm = function(widget, items)
        widget:hide()

        if #items > 0 then
          local winnr_source = command.context_winnr() ---@type integer|nil
          local winnr = winpicker.pick_window(winpicker.filters.project, winnr_source, true) ---@type integer|nil
          if winnr ~= nil then
            for _, item in ipairs(items) do
              local data = item.data ---@type fml.action.find.buffers.IItemData
              vim.api.nvim_win_set_buf(winnr, data.bufnr)
            end
          end
        end
      end,
    })
  end
  return _select
end

---@class fml.action.find
local M = {}

---@param context                       eve.command.IContext
---@return nil
---@diagnostic disable-next-line: unused-local
function M.find_bufs(context)
  local select = get_select() ---@type fml.ux.ISelect
  select:show()
end

---@param context                       eve.command.IContext
---@return nil
---@diagnostic disable-next-line: unused-local
function M.find_bufs_file(context)
  state.select.find_buffer_scope:next("F")
  local select = get_select() ---@type fml.ux.ISelect
  select:show()
end

---@param context                       eve.command.IContext
---@return nil
---@diagnostic disable-next-line: unused-local
function M.find_bufs_term(context)
  state.select.find_buffer_scope:next("T")
  local select = get_select() ---@type fml.ux.ISelect
  select:show()
end

return M

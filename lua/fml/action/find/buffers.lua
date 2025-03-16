local Select = require("fml.ux.select")

---@class fml.action.find.buffers.IItemData
---@field public bufnr                  integer
---@field public buftype                string
---@field public filetype               string
---@field public filepath               string
---@field public filename               string
---@field public icon                   string
---@field public icon_hl                string

local scopes = vim.list_slice(eve.state.select.find_buffer_scopes) ---@type eve.e.FindBufferScope[]
local _select = nil ---@type fml.ux.ISelect|nil

---@type eve.t.ux.widget.IRawStatuslineItem[]
local statusline_items = {
  {
    type = "enum",
    desc = "find(buffer): toggle scope",
    symbol = "",
    state = eve.state.select.find_buffer_scope,
    callback = function()
      local scope = eve.state.select.find_buffer_scope:snapshot() ---@type eve.e.FindBufferScope
      local idx = eve.table.find_index(scopes, scope) or 1 ---@type integer
      local idx_next = idx == #scopes and 1 or idx + 1 ---@type integer
      local next_scope = scopes[idx_next] ---@type eve.e.FindBufferScope
      eve.state.select.find_buffer_scope:next(next_scope)

      if _select ~= nil then
        _select:mark_data_dirty()
      end
    end,
  },
  {
    type = "flag",
    desc = "find(buffer): toggle selected",
    symbol = eve.icon.symbols.flag_selected,
    state = eve.state.select.find_buffer.flag_selected,
    callback = function()
      local flag = eve.state.select.find_buffer.flag_selected:snapshot() ---@type boolean
      eve.state.select.find_buffer.flag_selected:next(not flag)
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
      if not eve.editor.is_buf_valid(bufnr) then
        _select:mark_item_deleted(item.uuid)
        return
      end

      if not eve.editor.is_buf_sourcefile(bufnr) then
        vim.api.nvim_buf_delete(bufnr, { force = true })
        return
      end

      local tabnrs = vim.api.nvim_list_tabpages() ---@type integer[]
      for _, tabnr in ipairs(tabnrs) do
        eve.state.tab.on_bufs_close(tabnr, { bufnr })
      end

      local unrefereced_bufnrs = eve.state.tab.get_unrefereced_bufnrs() ---@type integer[]
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
    local cwd = eve.path.cwd() ---@type string
    local scope = eve.state.select.find_buffer_scope:snapshot() ---@type eve.e.FindBufferScope
    local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
    local meta_tab = eve.state.tab.resolve(tabnr) ---@type eve.state.tab.meta.state|nil

    ---@param bufnr                     integer
    ---@return boolean
    local function should_show(bufnr)
      if scope == "A" then
        return true
      end

      local filetype = vim.bo[bufnr].filetype ---@type string
      if scope == "T" then
        return filetype == eve.filetype.TERM
      end

      if scope == "F" then
        return meta_tab and meta_tab:find_buf(bufnr) ~= nil or false
      end

      if
        filetype == eve.filetype.SEARCH_INPUT
        or filetype == eve.filetype.SEARCH_MAIN
        or filetype == eve.filetype.SEARCH_PREVIEW
        or filetype == eve.filetype.WINSEP
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
        local relative_filepath = eve.path.relative(cwd, filepath, true) ---@type string
        local filename = eve.path.basename(filepath)
        local icon, icon_hl = eve.fn.fileicon(filename)

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
local select = Select.new({
  dimension = {
    height = 0.8,
    max_height = 1,
    max_width = 1,
    width = 120,
    width_preview = 0,
  },
  dirty_on_invisible = true,
  flag_case_sensitive = eve.state.select.find_buffer.flag_case_sensitive,
  flag_fuzzy = eve.state.select.find_buffer.flag_fuzzy,
  flag_regex = eve.state.select.find_buffer.flag_regex,
  flag_selected = eve.state.select.find_buffer.flag_selected,
  input = eve.state.select.find_buffer.input,
  input_history = eve.state.select.find_buffer.input_history,
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
      local winnr_sourcefile = eve.state.editor.get_winnr_sourcefile() or eve.editor.pick_sourcefile_win() ---@type integer|nil
      if winnr_sourcefile ~= nil then
        for _, item in ipairs(items) do
          local data = item.data ---@type fml.action.find.buffers.IItemData
          vim.api.nvim_win_set_buf(winnr_sourcefile, data.bufnr)
        end
      end
    end
  end,
})
_select = select

eve.state.observe({ eve.state.select.find_buffer_scope }, function()
  local scope = eve.state.select.find_buffer_scope:snapshot() ---@type eve.e.FindBufferScope
  if scope == "A" then
    select:change_input_title("find buffers")
  elseif scope == "F" then
    select:change_input_title("find buffers (files)")
  elseif scope == "L" then
    select:change_input_title("find buffers (except widgets)")
  elseif scope == "T" then
    select:change_input_title("find buffers (terms)")
  end
end, false)

---@class fml.action.find
local M = {}

---@return nil
function M.find_bufs()
  eve.state.select.find_buffer_scope:next("A")
  select:show()
end

---@return nil
function M.find_bufs_file()
  eve.state.select.find_buffer_scope:next("F")
  select:show()
end

---@return nil
function M.find_bufs_term()
  eve.state.select.find_buffer_scope:next("T")
  select:show()
end

return M

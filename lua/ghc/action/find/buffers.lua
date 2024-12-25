local checks = require("eve.lib.checks")
local constant = require("eve.lib.constant")
local functional = require("eve.lib.functional")
local calc_fileicon = require("eve.lib.nvim").calc_fileicon
local path = require("eve.lib.path")
local state = require("eve.state")

---@class ghc.action.find.buffers.IItemData
---@field public bufnr                  integer
---@field public filetype               string
---@field public filepath               string
---@field public filename               string
---@field public icon                   string
---@field public icon_hl                string

---@type fml.t.ux.ISelect|nil
local select

local scopes = { "A", "P" } ---@type eve.e.FindBufferScope[]

---@type eve.t.ux.widget.IRawStatuslineItem[]
local statusline_items = {
  {
    type = "enum",
    desc = "find(buffer): toggle scope",
    symbol = "",
    state = state.find_buffer.scope,
    callback = function()
      local scope = state.find_buffer.scope:snapshot() ---@type eve.e.FindBufferScope
      local idx = functional.find_index(scopes, scope) or 1 ---@type integer
      local idx_next = idx == #scopes and 1 or idx + 1 ---@type integer
      local next_scope = scopes[idx_next] ---@type eve.e.FindBufferScope
      state.find_buffer.scope:next(next_scope)

      if select ~= nil then
        select:mark_data_dirty()
      end
    end,
  },
}

---@type fml.t.ux.select.IProvider
local provider = {
  fetch_data = function()
    local cwd = path.cwd() ---@type string
    local scope = state.find_buffer.scope:snapshot() ---@type eve.e.FindBufferScope

    ---@param bufnr                     integer
    local function should_show(bufnr)
      local filetype = vim.bo[bufnr].filetype ---@type string
      if
        filetype == constant.FT_SEARCH_INPUT
        or filetype == constant.FT_SEARCH_MAIN
        or filetype == constant.FT_SEARCH_PREVIEW
        or filetype == constant.FT_WINSEP
      then
        return false
      end
      return true
    end

    local items = {} ---@type fml.t.ux.select.IItem[]
    local bufnrs = vim.api.nvim_list_bufs() ---@type integer[]
    for _, bufnr in ipairs(bufnrs) do
      if scope == "A" or should_show(bufnr) then
        local filetype = vim.bo[bufnr].filetype ---@type string
        local filepath = vim.api.nvim_buf_get_name(bufnr) ---@type string
        local relative_filepath = path.relative(cwd, filepath, true) ---@type string
        local filename = path.basename(filepath)
        local icon, icon_hl = calc_fileicon(filename)

        ---@type ghc.action.find.buffers.IItemData
        local data = {
          bufnr = bufnr,
          filetype = filetype,
          filepath = relative_filepath,
          filename = filename,
          icon = icon,
          icon_hl = icon_hl,
        }

        local text =
          string.format("%-5d  %-18s  %s %s", bufnr, filetype, #filepath > 0 and icon or " ", relative_filepath)
        local item = { uuid = tostring(bufnr), text = text, data = data }
        items[#items + 1] = item
      end
    end

    table.sort(items, function(a, b)
      return a.data.bufnr < b.data.bufnr
    end)

    ---@type fml.t.ux.select.IData
    return { items = items }
  end,
  render_item = function(item, match)
    local data = item.data ---@type ghc.action.find.buffers.IItemData

    ---@type eve.t.IHighlightInline[]
    local highlights = {
      { coll = 0, colr = 5, hlname = "f_buf_nr" },
      { coll = 5, colr = 25, hlname = "f_buf_filetype" },
      { coll = 27, colr = 29, hlname = data.icon_hl },
      { coll = 29, colr = -1, hlname = "f_buf_filepath" },
    }

    for _, piece in ipairs(match.matches) do
      ---@type eve.t.IHighlightInline[]
      local highlight = { coll = piece.l, colr = piece.r, hlname = "f_us_main_match" }
      table.insert(highlights, highlight)
    end
    return item.text, highlights
  end,
}

---@type fml.t.ux.ISelect
select = fml.ux.Select.new({
  dimension = {
    height = 0.8,
    max_height = 1,
    max_width = 1,
    width = 120,
  },
  dirty_on_invisible = true,
  flag_case_sensitive = state.find_buffer.flag_case_sensitive,
  flag_fuzzy = state.find_buffer.flag_fuzzy,
  flag_regex = state.find_buffer.flag_regex,
  input = state.find_buffer.keyword,
  input_history = state.input_history.find_buffer,
  preview_enabled = false,
  extend_preset_keymaps = true,
  statusline_items = statusline_items,
  provider = provider,
  title = "Find buffers",
  on_confirm = function(item)
    local data = item.data ---@type ghc.action.find.buffers.IItemData
    local winnr = state.tab.get_current_winnr() ---@type integer | nil
    if winnr ~= nil and winnr > 0 and vim.api.nvim_win_is_valid(winnr) then
      vim.api.nvim_win_set_buf(winnr, data.bufnr)
    else
      local winnrs = vim.api.nvim_tabpage_list_wins(0) ---@type integer[]
      for _, winnr2 in ipairs(winnrs) do
        if not checks.is_win_floating(winnr2) then
          vim.api.nvim_win_set_buf(winnr2, data.bufnr)
          break
        end
      end
    end
    return "hide"
  end,
})

---@class ghc.action.find
local M = {}

---@return nil
function M.find_buffers()
  select:toggle()
end

return M

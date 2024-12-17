local path = require("eve.lib.path")
local checks = require("eve.builtin.checks")
local uuids = eve.commander.uuids ---@type eve.builtin.commander.uuids

---@class ghc.command.find.buffers.IItemData
---@field public bufnr                  integer
---@field public filetype               string
---@field public filepath               string
---@field public filename               string
---@field public icon                   string
---@field public icon_hl                string

local cwd = path.cwd() ---@type string

---@type fml.t.ux.select.IProvider
local provider = {
  fetch_data = function()
    cwd = path.cwd() ---@type string

    local items = {} ---@type fml.t.ux.select.IItem[]
    local bufnrs = vim.api.nvim_list_bufs() ---@type integer[]
    for _, bufnr in ipairs(bufnrs) do
      local filetype = vim.bo[bufnr].filetype ---@type string
      local filepath = vim.api.nvim_buf_get_name(bufnr) ---@type string
      local relative_filepath = path.relative(cwd, filepath, true) ---@type string
      local filename = path.basename(filepath)
      local icon, icon_hl = eve.nvim.calc_fileicon(filename)

      ---@type ghc.command.find.buffers.IItemData
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

    table.sort(items, function(a, b)
      return a.data.bufnr < b.data.bufnr
    end)

    ---@type fml.t.ux.select.IData
    return { items = items }
  end,
  render_item = function(item, match)
    local data = item.data ---@type ghc.command.find.buffers.IItemData

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
local select = fml.ux.Select.new({
  dimension = {
    height = 0.8,
    max_height = 1,
    max_width = 1,
    width = 120,
  },
  dirty_on_invisible = true,
  preview_enabled = false,
  extend_preset_keymaps = true,
  provider = provider,
  title = "Find buffers",
  on_confirm = function(item)
    local data = item.data ---@type ghc.command.find.buffers.IItemData
    local winnr = eve.tab.get_current_winnr() ---@type integer | nil
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

eve.commander.register({
  uuid = uuids.find_buffers,
  desc = "find: buffers",
  action = function()
    select:toggle()
  end,
})

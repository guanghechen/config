local Nvimbar = require("eve.lib.ux.nvimbar")
local Subscriber = require("eve.lib.collection.subscriber")
local status = require("eve.builtin.status")
local state = require("eve.state")
local c = require("ghc.dressing.nvimbar.components")

local winline_map = {} ---@type table<string, eve.lib.ux.INvimbar>

---@param winnr                         integer
---@return boolean
local function should_show_winline(winnr)
  if winnr == 0 or not vim.api.nvim_win_is_valid(winnr) or eve.checks.is_win_floating(winnr) then
    return false
  end

  local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer

  local filepath = vim.api.nvim_buf_get_name(bufnr) ---@type string
  if filepath:sub(1, 9) == "diffview:" then
    return filepath:sub(1, 19) ~= "diffview:///panels/"
  end

  if not eve.checks.is_buf_valid(bufnr) then
    return false
  end

  return true
end

---@param winnr                         integer
---@return string
local function refresh(winnr)
  if not should_show_winline(winnr) then
    return ""
  end

  local winline = winline_map[winnr] ---@type eve.lib.ux.INvimbar
  if winline == nil then
    local devmode = state.state.flight.devmode:snapshot() ---@type boolean

    ---@type eve.lib.ux.INvimbar
    winline = Nvimbar.new({
      name = "winline_" .. winnr,
      component_sep = "",
      component_sep_hlname = "f_sl_bg",
      component_sep_hlname_active = "f_sl_bg",
      preset_context = { winnr = winnr },
      render_delay = 64,
      silent = not devmode,
      get_max_width = function()
        return vim.api.nvim_win_get_width(winnr)
      end,
      is_active = function(context)
        local winnr_cur = eve.locations.get_current_winnr() or 0 ---@type integer
        return winnr_cur == context.winnr
      end,
      trigger_rerender = function()
        local result = winline and winline:snapshot() or "" ---@type string
        if #result > 0 and vim.api.nvim_win_is_valid(winnr) then
          vim.wo[winnr].winbar = result
        end
      end,
      validate = function()
        if winnr > 0 and vim.api.nvim_win_is_valid(winnr) then
          return nil
        else
          return "The window is not valid, winnr=" .. winnr .. "."
        end
      end,
    })
    winline_map[winnr] = winline

    winline
      ---
      :register(c.win_indicator(), "left")
      :register(c.dirpath(), "left")
      :register(c.filename(), "left")
      :register(c.lsp_symbols(), "left")
      ---
      :register(c.debug_render_count(), "center")
  end
  return winline:render()
end

status.winline_dirty_nr:subscribe(
  Subscriber.new({
    on_next = function(winnr)
      refresh(winnr)
    end,
  }),
  true
)

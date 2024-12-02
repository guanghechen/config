local __module_name__ = "ghc.nvimbar.winline" ---@type string

local reporter = require("eve.lib.reporter")
local Nvimbar = require("eve.lib.ux.nvimbar")
local Subscriber = require("eve.lib.collection.subscriber")
local state = require("eve.state")
local c = require("ghc.nvimbar.components")

local winline_map = {} ---@type table<string, eve.lib.ux.INvimbar>

---@class ghc.nvimbar.winline
local M = {}

---@param winnr                         integer
---@return boolean
function M.should_show_winline(winnr)
  if eve.checks.is_win_floating(winnr) then
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
---@param force                         boolean
---@return string
function M.render(winnr, force)
  if not M.should_show_winline(winnr) then
    return ""
  end

  local winline = winline_map[winnr] ---@type eve.lib.ux.INvimbar
  if winline == nil then
    local devmode = state.state.flight.devmode:snapshot() ---@type boolean
    winline = Nvimbar.new({
      name = "winline_" .. winnr,
      component_sep = "",
      component_sep_hlname = "f_wl_bg",
      component_sep_hlname_active = "f_wla_bg",
      preset_context = { winnr = winnr },
      render_delay = 32,
      silent = not devmode,
      get_max_width = function()
        return vim.api.nvim_win_get_width(winnr)
      end,
      is_active = function(context)
        local winnr_cur = eve.locations.get_current_winnr() or 0 ---@type integer
        return winnr_cur == context.winnr
      end,
      trigger_rerender = function()
        vim.schedule(function()
          M.update(winnr, false)
        end)
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
  end
  return winline:render(force)
end

---@param winnr                         integer
---@param force                         boolean
---@return nil
function M.update(winnr, force)
  if vim.api.nvim_win_is_valid(winnr) then
    local result = M.render(winnr, force) ---@type string
    if #result > 0 then
      local ok, err = pcall(function()
        vim.wo[winnr].winbar = result
      end)
      if not ok then
        reporter.error({
          from = __module_name__,
          subject = "update",
          message = "Failed to update winbar.",
          details = { winnr = winnr, result = result, err = err },
        })
      end
    end
  end
end

state.state.status.winline_dirty_nr:subscribe(
  Subscriber.new({
    on_next = function(winnr)
      if winnr > 0 and vim.api.nvim_win_is_valid(winnr) then
        M.update(winnr, true)
      end
    end,
  }),
  true
)

return M

local functional = require("eve.lib.functional")
local Nvimbar = require("eve.lib.ux.nvimbar")
local state = require("eve.state")
local c = require("ghc.nvimbar.components")

local devmode = state.state.flight.devmode:snapshot() ---@type boolean
local statusline_dirty = true ---@type boolean

local statusline ---@type eve.lib.ux.INvimbar

statusline = Nvimbar.new({
  name = "statusline",
  component_sep = "  ",
  component_sep_hlname = "f_sl_bg",
  component_sep_hlname_active = "f_sl_bg",
  render_delay = 64,
  silent = not devmode,
  get_max_width = function()
    return vim.o.columns
  end,
  is_active = functional.falsy,
  trigger_rerender = function()
    statusline_dirty = false
    vim.cmd.redrawstatus()
    vim.schedule(function()
      statusline:cancel_render()
    end)
  end,
  validate = function()
    return nil
  end,
})

statusline
  :register(c.copilot())
  :register(c.diagnostics())
  :register(c.fileformat())
  :register(c.filepath())
  :register(c.filesize())
  :register(c.filestatus())
  :register(c.filetype())
  :register(c.git())
  :register(c.lsp())
  :register(c.mode())
  :register(c.noice())
  :register(c.pos())
  :register(c.readonly())
  :register(c.username())
  :register(c.widget())

statusline
  :place("username", "left")
  :place("mode", "left")
  :place("git", "left")
  :place("filetype", "left")
  :place("filestatus", "left")
  :place("readonly", "left")
  --
  :place("widget", "center")
  --
  :place("pos", "right")
  :place("filesize", "right")
  :place("fileformat", "right")
  :place("lsp", "right")
  :place("copilot", "right")
  :place("noice", "right")
  :place("diagnostics", "right")

---@class ghc.nvimbar.statusline
local M = { cnames = vim.deepcopy(c) }

---@param name                          string
---@return ghc.nvimbar.statusline
function M.disable(name)
  statusline:disable(name)
  return M
end

---@param name                          string
---@return ghc.nvimbar.statusline
function M.enable(name)
  statusline:enable(name)
  return M
end

---@return string
function M.render()
  local result = statusline:render(statusline_dirty) ---@type string
  statusline_dirty = true
  return result
end

return M

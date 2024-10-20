local statusline_dirty = true ---@type boolean

---@type t.fml.ux.INvimbar
local statusline = fml.ux.Nvimbar.new({
  name = "statusline",
  component_sep = "  ",
  component_sep_hlname = "f_sl_bg",
  get_max_width = function()
    return vim.o.columns
  end,
  trigger_rerender = function()
    statusline_dirty = false
    vim.cmd.redrawstatus()
  end,
})

local c = {
  copilot = "copilot",
  diagnostics = "diagnostics",
  fileformat = "fileformat",
  filepath = "filepath",
  filestatus = "filestatus",
  filetype = "filetype",
  git = "git",
  lsp = "lsp",
  mode = "mode",
  noice = "noice",
  pos = "pos",
  readonly = "readonly",
  username = "username",
  widget = "widget",
}
for _, name in pairs(c) do
  statusline:register(name, require("ghc.ux.statusline.component." .. name))
end

statusline
  :place(c.username, "left")
  :place(c.mode, "left")
  :place(c.git, "left")
  :place(c.filetype, "left")
  :place(c.filestatus, "left")
  :place(c.readonly, "left")
  :place(c.widget, "center")
  :place(c.pos, "right")
  :place(c.fileformat, "right")
  :place(c.lsp, "right")
  :place(c.copilot, "right")
  :place(c.noice, "right")
  :place(c.diagnostics, "right")

---@class ghc.ux.statusline
local M = { cnames = vim.deepcopy(c) }

---@param name                          string
---@return ghc.ux.statusline
function M.disable(name)
  statusline:disable(name)
  return M
end

---@param name                          string
---@return ghc.ux.statusline
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

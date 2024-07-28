---@type fml.types.ui.INvimbar
local statusline = fml.ui.Nvimbar.new({
  name = "statusline",
  component_sep = "  ",
  component_sep_hlname = "f_sl_bg",
  get_max_width = function()
    return vim.o.columns
  end,
  trigger_rerender = function()
    vim.schedule(function()
      vim.cmd("redrawstatus")
    end)
  end,
})

local c = {
  copilot = "copilot",
  cwd = "cwd",
  diagnostics = "diagnostics",
  fileformat = "fileformat",
  filepath = "filepath",
  filestatus = "filestatus",
  filetype = "filetype",
  find_files = "find_files",
  git = "git",
  lsp = "lsp",
  mode = "mode",
  noice = "noice",
  pos = "pos",
  readonly = "readonly",
  search = "search",
  username = "username",
}
for _, name in pairs(c) do
  statusline:register(name, require("ghc.ui.statusline.component." .. name))
end
statusline
  ---
  :disable(c.find_files)
  :disable(c.search)

statusline
  :place(c.username, "left")
  :place(c.mode, "left")
  :place(c.git, "left")
  :place(c.filetype, "left")
  :place(c.filestatus, "left")
  :place(c.readonly, "left")
  :place(c.search, "center")
  :place(c.find_files, "center")
  :place(c.cwd, "right")
  :place(c.lsp, "right")
  :place(c.copilot, "right")
  :place(c.fileformat, "right")
  :place(c.pos, "right")
  :place(c.noice, "right")
  :place(c.diagnostics, "right")

---@class ghc.ui.statusline
local M = { cnames = vim.deepcopy(c) }

---@param name                          string
---@return ghc.ui.statusline
function M.disable(name)
  statusline:disable(name)
  return M
end

---@param name                          string
---@return ghc.ui.statusline
function M.enable(name)
  statusline:enable(name)
  return M
end

---@return string
function M.render()
  return statusline:render()
end

return M

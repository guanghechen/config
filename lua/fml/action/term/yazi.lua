local path = require("eve.std.path")
local editor = require("eve.module.editor")
local state = require("eve.state")

local toggle_term = require("fml.action.term.toggle").toggle

---@param name                          string
---@param cwd                           string
---@param filepath                      string
---@return nil
local function open_yazi(name, cwd, filepath)
  local tempname = path.locate_cache_filepath("yazi-chooser-files.txt") ---@type string
  local terminal ---@type fml.ux.ITerminal|nil

  local dirpath = path.dirname(filepath) ---@type string
  local cmd = string.format('yazi "%s" --chooser-file="%s"', dirpath, tempname) ---@type string
  terminal = toggle_term({
    name = name,
    cmd = cmd,
    cwd = cwd,
    permanent = false,
    on_exit = function()
      pcall(function()
        if terminal == nil then
          return
        end

        terminal:close()

        local filepaths = vim.fn.filereadable(tempname) == 1 and vim.fn.readfile(tempname) or {} ---@type string[]
        local N = #filepaths ---@type integer
        local k = 1 ---@type integer
        for i = 1, N, 1 do
          local p = filepaths[i] ---@type string
          if vim.fn.filereadable(p) == 1 then
            filepaths[k] = p
            k = k + 1
          end
        end
        for i = k, N, 1 do
          filepaths[i] = nil
        end

        if #filepaths > 0 then
          editor.open_filepaths(nil, filepaths)
        end
      end)
    end,
  })
end

---@class fml.action.term.yazi
local M = {}

---@return nil
function M.yazi_cwd()
  local cwd = path.cwd() ---@type string
  open_yazi("yazi_cwd", cwd, cwd)
end

---@return nil
function M.yazi_reveal()
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local bufnr_sourcefile = state.tab.get_bufnr_sourcefile(tabnr) ---@type integer|nil

  local cwd = path.cwd() ---@type string
  if bufnr_sourcefile == nil then
    open_yazi("yazi_cwd", cwd, cwd)
  else
    local filepath = vim.api.nvim_buf_get_name(bufnr_sourcefile) ---@type string
    open_yazi("yazi_cwd", cwd, filepath)
  end
end

---@return nil
function M.yazi_workspace()
  local workspace = path.workspace() ---@type string
  open_yazi("yazi_workspace", workspace, workspace)
end

return M

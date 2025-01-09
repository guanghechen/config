local path = require("eve.builtin.path")
local editor = require("eve.module.editor")

local toggle_term = require("fml.action.term.toggle").toggle

---@param name                          string
---@param cwd                           string
---@param filepath                      string
---@param context                       eve.command.IContext
---@return nil
local function open_yazi(name, cwd, filepath, context)
  local tempname = vim.fn.tempname() ---@type string
  local terminal ---@type fml.ux.ITerminal|nil

  ---@type string
  local command =
    string.format('yazi %s --chooser-file="%s"', vim.fn.shellescape(filepath), vim.fn.shellescape(tempname))
  terminal = toggle_term({
    name = name,
    command = command,
    cwd = cwd,
    permanent = false,
    selected_text = "",
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
          editor.open_filepaths(context.winnr, filepaths)
        end
      end)

      vim.fn.delete(tempname)
    end,
  })
end

---@class fml.action.term.yazi
local M = {}

---@param context                       eve.command.IContext
---@return nil
function M.yazi_cwd(context)
  local cwd = path.cwd() ---@type string
  open_yazi("yazi_cwd", cwd, cwd, context)
end

---@param context                       eve.command.IContext
---@return nil
function M.yazi_reveal(context)
  local cwd = path.cwd() ---@type string
  local filepath = vim.api.nvim_buf_get_name(context.bufnr) ---@type string
  open_yazi("yazi_cwd", cwd, filepath, context)
end

---@param context                       eve.command.IContext
---@return nil
function M.yazi_workspace(context)
  local workspace = path.workspace() ---@type string
  open_yazi("yazi_workspace", workspace, workspace, context)
end

return M

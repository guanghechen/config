local __module_name__ = "eve.ux.nvimbar.component.python" ---@type string

local btn = eve.nvim.btn
local txt = eve.nvim.txt

local fn_select_python_venv = eve.G.register_anonymous_fn(function()
  vim.cmd(eve.command.definitions.lsp.select_python_venv.uuid)
end)

local python_venv = "" ---@type string|nil
local python_version = "" ---@type string|nil
eve.fn.observe({ eve.state.lsp.python_venv_path }, function()
  local python_venv_path = eve.state.lsp.python_venv_path:snapshot() ---@type string
  python_venv = python_venv_path ~= nil and eve.path.basename(python_venv_path) or nil ---@type string|nil

  local python_path = eve.state.lsp.get_python_bin_path() ---@type string|nil
  if python_path ~= nil then
    local cmd = vim.fn.shellescape(python_path) .. " --version"
    local ok, output = pcall(vim.fn.system, cmd)
    if ok then
      python_version = output:match("(%d+%.%d+%.%d+)")
    else
      python_version = nil
      eve.reporter.error({
        from = __module_name__,
        message = "Failed to run python version command.",
        details = { error = output, cmd = cmd, python_path = python_path },
      })
    end
  end
end, false)

---@class eve.ux.nvimbar.component.python
local M = {}

---@param position                      eve.ux.nvimbar.PositionEnum
---@return eve.ux.nvimbar.IRawComponent
function M.env(position)
  local hln_text = position .. "_python_env_text" ---@type string

  ---@type eve.ux.nvimbar.IRawComponent
  local component = {
    name = "python:env",
    atomic = true,
    tight = true,
    condition = function(context)
      return context.filetype == "python" or (python_venv ~= nil and python_version ~= nil)
    end,
    render = function()
      local text ---@type string
      if #python_version > 0 then
        text = python_version .. " (" .. (python_venv or "unknown") .. ")  " ---@type string
      else
        text = "(" .. (python_venv or "unknown") .. ")  " ---@type string
      end

      local hl_text = btn(txt(text, hln_text), fn_select_python_venv) ---@type string
      return text, hl_text, true
    end,
  }
  return component
end

return M

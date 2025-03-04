local __module_name__ = "fml.dressing.venv" ---@type string

local reporter = require("eve.builtin.reporter")

---@class fml.dressing.venv.hook
local M = {}

---@param name                          string
---@param callback                      fun(client: table): nil
---@return nil
function M.execute_for_client(name, callback)
  local client = vim.lsp.get_clients({ name = name })[1]
  if not client then
    reporter.warn({
      from = __module_name__,
      subject = "execute_for_client",
      message = "No client named: " .. name .. " found",
    })
  else
    callback(client)
  end
end

---@param venv_path                     string
---@param venv_python                   string
---@return nil
---@diagnostic disable-next-line: unused-local
function M.basedpyright_hook(venv_path, venv_python)
  M.execute_for_client("basedpyright", function(client)
    if client.settings then
      client.settings = vim.tbl_deep_extend("force", client.settings, { python = { pythonPath = venv_python } })
    else
      client.config.settings =
        vim.tbl_deep_extend("force", client.config.settings, { python = { pythonPath = venv_python } })
    end
    client.notify("workspace/didChangeConfiguration", { settings = nil })
  end)
end

---@param venv_path                     string
---@param venv_python                   string
---@return nil
---@diagnostic disable-next-line: unused-local
function M.pyright_hook(venv_path, venv_python)
  M.execute_for_client("pyright", function(client)
    if client.settings then
      client.settings = vim.tbl_deep_extend("force", client.settings, { python = { pythonPath = venv_python } })
    else
      client.config.settings =
        vim.tbl_deep_extend("force", client.config.settings, { python = { pythonPath = venv_python } })
    end
    client.notify("workspace/didChangeConfiguration", { settings = nil })
  end)
end

---@param venv_path                     string
---@param venv_python                   string
---@return nil
---@diagnostic disable-next-line: unused-local
function M.pylance_hook(venv_path, venv_python)
  M.execute_for_client("pylance", function(client)
    if client.settings then
      client.settings = vim.tbl_deep_extend("force", client.settings, { python = { pythonPath = venv_python } })
    else
      client.config.settings =
        vim.tbl_deep_extend("force", client.config.settings, { python = { pythonPath = venv_python } })
    end
    client.notify("workspace/didChangeConfiguration", { settings = nil })
  end)
end

---@param venv_path                     string
---@param venv_python                   string
---@return nil
---@diagnostic disable-next-line: unused-local
function M.pylsp_hook(venv_path, venv_python)
  M.execute_for_client("pylsp", function(client)
    local settings = vim.tbl_deep_extend("force", (client.settings or client.config.settings), {
      pylsp = {
        plugins = {
          jedi = {
            environment = venv_python,
          },
        },
      },
    })
    client.notify("workspace/didChangeConfiguration", { settings = settings })
  end)
end

return M

---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.support.cmp.embedded" ---@type string

local UI = require("__test__.support.ui")

local M = {}

---Starts a child Neovim with the completion runtime over `lines`, the cursor on the last line. The child closes, and
---must have reported no error, when `t` cleans up.
---@param t                             __test__.support.Harness
---@param lines                         string[]
---@return __test__.support.UI
function M.editor(t, lines)
  local ui = UI.new()
  t:defer(function()
    ui:close()
  end)
  ui:start({})
  ui:lua(
    [[
    local lines = ...
    require('__test__.support.cmp.runtime').setup()
    vim.api.nvim_set_option_value('filetype', 'lua', { buf = 0 })
    vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
    vim.api.nvim_win_set_cursor(0, { #lines, 0 })
    require('era.keystroke.cmp').setup()
  ]],
    lines
  )
  t:defer(function()
    t.assert_eq("", ui:lua([[return vim.v.errmsg]]), "no editor errors")
  end)
  return ui
end

---Installs a fake LSP client in the child. `complete` and `resolve` are Lua chunks returning the completion handler
---`fun(params, callback)` and the resolve handler `fun(item): item, delay_ms?`; requests and executed commands are
---recorded in `_G.cmp_requests` and `_G.cmp_commands`.
---@param ui                            __test__.support.UI
---@param complete                      string
---@param resolve                       ?string
---@return nil
function M.lsp_client(ui, complete, resolve)
  ui:lua(
    [[
    local complete_code, resolve_code = ...
    local completion = assert(loadstring(complete_code))()
    local resolve = resolve_code and assert(loadstring(resolve_code))() or function(item) return item end
    _G.cmp_requests = {}
    _G.cmp_commands = {}
    local client = {
      id = 9001, name = 'completion-fixture', offset_encoding = 'utf-16',
      server_capabilities = { completionProvider = { resolveProvider = true, triggerCharacters = { '.' } } },
      cancel_request = function() end,
      exec_cmd = function(_, command) cmp_commands[#cmp_commands + 1] = command end,
    }
    function client:request(method, params, callback, bufnr)
      cmp_requests[#cmp_requests + 1] = { method = method, params = params, bufnr = bufnr }
      local id = #cmp_requests
      if method == 'textDocument/completion' then
        completion(params, callback)
      elseif method == 'completionItem/resolve' then
        local result, delay = resolve(params)
        vim.defer_fn(function() callback(nil, result) end, delay or 0)
      end
      return true, id
    end
    vim.lsp.get_clients = function(filter)
      return filter and filter.method == 'textDocument/completion' and { client } or {}
    end
    vim.lsp.get_client_by_id = function(id) return id == client.id and client or nil end
  ]],
    complete,
    resolve
  )
end

---Waits until the Lua chunk `code` returns a truthy value in the child.
---@param ui                            __test__.support.UI
---@param code                          string
---@param message                       string
---@return nil
function M.wait(ui, code, message)
  ui:wait_until(function()
    return ui:lua(code)
  end, 3000, message)
end

return M

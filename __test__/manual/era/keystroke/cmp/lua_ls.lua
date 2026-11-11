-- Run from the repository root: nvim -l __test__/manual/era/keystroke/cmp/lua_ls.lua [server]
-- Requires an existing lua-language-server: the argument, else Mason's. The cases share one child Neovim that runs this
-- checkout's completion against the real server and run in order: completion and acceptance, documentation, function
-- snippets, signature help and the buffer-word fallback.
---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.manual.era.keystroke.cmp.lua_ls" ---@type string

local root = assert(vim.uv.cwd())
package.path = root .. "/?.lua;" .. root .. "/?/init.lua;" .. package.path
local UI = require("__test__.support.ui")
local t = require("__test__.support.harness").new()
local executable = arg[1] or vim.fn.stdpath("data") .. "/mason/bin/lua-language-server"
assert(vim.fn.executable(executable) == 1, "Use an existing lua-language-server executable")
local directory = t:tempdir()
local path = directory .. "/sample.lua"
vim.fn.writefile({ "local obj = { alpha = 1, alpine = 2 }", "obj." }, path)
local ui = UI.open(t, { width = 120, height = 40 })
t:defer(function()
  pcall(ui.lua, ui, [[vim.lsp.stop_client(cmp_smoke_client, true)]])
end)
local started = false ---@type boolean

---Waits until the Lua chunk `code` returns a truthy value in the child; on timeout, prints the editor state first.
---@param code                          string
---@param message                       string
---@return nil
local function wait(code, message)
  if not pcall(ui.wait_lua, ui, code, 15000) then
    print(
      vim.json.encode(
        ui:lua(
          [[return { mode = vim.api.nvim_get_mode().mode, line = vim.api.nvim_get_current_line(), error = vim.v.errmsg, responses = cmp_smoke_responses }]]
        )
      )
    )
    error(message)
  end
end

---Registers a case that continues the session the first case starts.
---@param name                          string
---@param callback                      fun(): nil
---@return nil
local function scenario(name, callback)
  t:test(name, function()
    assert(started, "the real server did not start")
    callback()
  end)
end

t:test("the real server starts with completion support", function()
  ui:lua(
    [[
    local root, directory, path, executable = ...
    require('__test__.support.cmp.runtime').setup()
    vim.api.nvim_buf_set_name(0, path)
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'local obj = { alpha = 1, alpine = 2 }', 'obj.' })
    vim.api.nvim_set_option_value('filetype', 'lua', { buf = 0 })
    vim.api.nvim_win_set_cursor(0, { 2, 3 })
    require('era.keystroke.cmp').setup()
    era.m.lsp = { event = require('era.m.lsp.event') }
    local config = assert(loadfile(root .. '/lsp/lua_ls.lua'))()
    _G.cmp_smoke_client = vim.lsp.start({
      name = 'lua_ls', cmd = { executable, '--logpath=' .. directory .. '/log' },
      cmd_cwd = directory, root_dir = directory,
      capabilities = config.capabilities,
      settings = config.settings,
    })
    _G.cmp_smoke_menu = function(needle)
      if not require('era.keystroke.cmp').is_menu_visible() then return false end
      for _, item in ipairs(vim.fn.complete_info({ 'items' }).items) do
        if (item.abbr .. ' ' .. item.menu):find(needle, 1, true) then return true end
      end
      return false
    end
    _G.cmp_smoke_window = function(filetype, needle)
      for _, winnr in ipairs(vim.api.nvim_list_wins()) do
        local bufnr = vim.api.nvim_win_get_buf(winnr)
        if vim.api.nvim_get_option_value('filetype', { buf = bufnr }) == filetype then
          for _, line in ipairs(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)) do
            if line:find(needle, 1, true) then return true end
          end
        end
      end
      return false
    end
  ]],
    root,
    directory,
    path,
    executable
  )
  wait(
    [[local c = vim.lsp.get_client_by_id(cmp_smoke_client); return c and c.initialized and c:supports_method('textDocument/completion', 0)]],
    "completion capability"
  )
  ui:lua([[
    _G.cmp_smoke_responses = {}
    local client = vim.lsp.get_client_by_id(cmp_smoke_client)
    local request = client.request
    client.request = function(self, method, params, callback, bufnr)
      if method ~= 'textDocument/completion' then return request(self, method, params, callback, bufnr) end
      return request(self, method, params, function(err, result, ...)
        local items = type(result) == 'table' and (result.items or result) or {}
        cmp_smoke_responses[#cmp_smoke_responses + 1] = { error = err, sample = items[1], count = #items, position = params.position }
        callback(err, result, ...)
      end, bufnr)
    end
  ]])
  started = true
end)

scenario("completion shows the server's candidates and accepts one", function()
  ui:rpc("nvim_input", "A")
  wait([[return vim.api.nvim_get_mode().mode:sub(1, 1) == 'i']], "insert mode")
  -- LuaLS can return null while its first document is still being indexed. A manual retry
  -- must query it again even if the editor already has local buffer candidates.
  local ready = false
  for _ = 1, 20 do
    ui:lua([[require('era.keystroke.cmp').show()]])
    ready = pcall(ui.wait_lua, ui, [[return cmp_smoke_menu('[lsp]')]], 500)
    if ready then
      break
    end
  end
  assert(ready, "real LSP candidates after indexing")
  ui:lua([[require('era.keystroke.cmp').accept(1)]])
  wait([[return vim.api.nvim_get_current_line() == 'obj.alpha']], "real LSP acceptance")
end)

scenario("documentation holds one full signature without a repeated header or rule", function()
  ui:rpc("nvim_input", "<Esc>")
  wait([[return vim.api.nvim_get_mode().mode == 'n']], "normal mode")
  ui:lua([[
    local lines = {
      '---@param a number First operand.', '---@param b number', '---@return number',
      'local function add(a, b) return a + b end', '',
    }
    vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
    vim.api.nvim_win_set_cursor(0, { #lines, 0 })
  ]])
  ui:rpc("nvim_input", "iadd")
  wait([[return cmp_smoke_menu('add(')]], "real function completion")
  wait(
    [[
    local info = vim.fn.complete_info({ 'selected' })
    if info.preview_bufnr == nil or not vim.api.nvim_buf_is_valid(info.preview_bufnr) then return false end
    local lines = vim.api.nvim_buf_get_lines(info.preview_bufnr, 0, -1, false)
    local text = table.concat(lines, '\n')
    return text:find('function add(a: number, b: number)', 1, true) ~= nil
      and text:find('First operand.', 1, true) ~= nil
      and not vim.list_contains(lines, 'function')
      and not vim.list_contains(lines, '---')
  ]],
    "real documentation contains one full signature and no repeated header or rule"
  )
end)

scenario("an accepted function snippet reaches its second parameter and final tabstop", function()
  ui:rpc("nvim_input", "<C-y>")
  wait(
    [[return vim.api.nvim_get_current_line() == 'add(a, b)' and vim.snippet.active() and vim.api.nvim_get_mode().mode == 's']],
    "real function snippet acceptance"
  )
  ui:rpc("nvim_input", "<Tab>")
  wait(
    [[return vim.api.nvim_get_mode().mode == 's' and vim.api.nvim_win_get_cursor(0)[2] == 7]],
    "real function second parameter"
  )
  ui:rpc("nvim_input", "<Tab>")
  wait(
    [[return not vim.snippet.active() and vim.api.nvim_get_mode().mode == 'i' and vim.api.nvim_win_get_cursor(0)[2] == #'add(a, b)']],
    "real function final tabstop"
  )
end)

scenario("signature help opens on a call", function()
  ui:rpc("nvim_input", "<Esc>")
  wait([[return vim.api.nvim_get_mode().mode == 'n']], "normal mode")
  ui:lua([[
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'local function add(a, b) return a + b end', '' })
    vim.api.nvim_win_set_cursor(0, { 2, 0 })
  ]])
  ui:rpc("nvim_input", "iadd(")
  wait([[return cmp_smoke_window('cmp-signature', 'add')]], "real signature help")
end)

scenario("automatic and manual completion keep the buffer-word fallback", function()
  ui:rpc("nvim_input", "<Esc>")
  wait([[return vim.api.nvim_get_mode().mode == 'n']], "normal mode")
  ui:lua([[
    local bufnr = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { 'qzxOtherWord' })
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { '-- qzxCurrentWord', 'local value = ' })
    vim.api.nvim_win_set_cursor(0, { 2, 0 })
    cmp_smoke_responses = {}
  ]])
  ui:rpc("nvim_input", "Aqzx")
  -- The preceding semantic checks ensure LuaLS has finished its initial indexing.
  -- Wait for its response so an early local fallback cannot hide a later Text result.
  wait([[return #cmp_smoke_responses > 0]], "real word completion response")
  wait([[return cmp_smoke_menu('qzxOtherWord')]], "cross-buffer word fallback")
  ui:lua([[require('era.keystroke.cmp').show()]])
  wait([[return #cmp_smoke_responses > 1]], "manual word completion response")
  wait([[return cmp_smoke_menu('qzxOtherWord')]], "manual cross-buffer word fallback")
  t.assert_eq("", ui:lua([[return vim.v.errmsg]]), "no editor errors")
end)

t:run()

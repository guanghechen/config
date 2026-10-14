-- Run from the repository root: nvim -l __test__/fixtures/era/keystroke/cmp/emmet.lua [server]
---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.fixtures.era.keystroke.cmp.emmet" ---@type string

local root = assert(vim.uv.cwd())
local executable = arg[1] or vim.fn.stdpath("data") .. "/mason/bin/emmet-language-server"
assert(vim.fn.executable(executable) == 1, "Use an existing emmet-language-server executable")
vim.opt.runtimepath:prepend(root)
package.path = root .. "/?.lua;" .. root .. "/?/init.lua;" .. package.path
local Rpc = require("__test__.support.rpc")
local t = require("__test__.support.harness").new(__module_name__)

---@param prefix                        string
---@return table
local function editor(prefix)
  local directory = vim.fn.tempname()
  vim.fn.mkdir(directory, "p")
  t:defer(function()
    vim.fn.delete(directory, "rf")
  end)
  local rpc = Rpc.new(root)
  t:defer(function()
    rpc:close()
  end)
  rpc:request("nvim_ui_attach", { 120, 40, { ext_linegrid = true, ext_multigrid = true, rgb = true } })
  rpc:lua(
    [[
    local root, directory, executable, prefix = ...
    vim.opt.runtimepath:prepend(root)
    vim.opt.runtimepath:append(root .. '/__test__/fixtures/era/keystroke/cmp/friendly-snippets')
    package.path = root .. '/?.lua;' .. root .. '/?/init.lua;' .. package.path
    require('__test__.fixtures.era.keystroke.cmp.runtime').setup()
    local stdpath = vim.fn.stdpath
    vim.fn.stdpath = function(kind) return kind == 'config' and directory or stdpath(kind) end
    local bufnr = vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_set_name(bufnr, directory .. '/sample.html')
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { prefix })
    vim.api.nvim_set_option_value('filetype', 'html', { buf = bufnr })
    vim.api.nvim_set_option_value('swapfile', false, { buf = bufnr })
    vim.api.nvim_set_option_value('expandtab', true, { buf = bufnr })
    vim.api.nvim_set_option_value('shiftwidth', 2, { buf = bufnr })
    vim.api.nvim_set_option_value('tabstop', 2, { buf = bufnr })
    local Session = require('era.keystroke.cmp.session')
    local new = Session.new
    Session.new = function(props)
      cmp_emmet_session = new(props)
      return cmp_emmet_session
    end
    require('era.keystroke.cmp').setup()
    era.m.lsp = { event = require('era.m.lsp.event') }
    local config = assert(loadfile(root .. '/lsp/emmet_language_server.lua'))()
    cmp_emmet_client = vim.lsp.start({
      name = 'emmet_language_server', cmd = { executable, '--stdio' },
      cmd_cwd = directory, root_dir = directory,
      capabilities = config.capabilities, settings = config.settings,
    })
  ]],
    root,
    directory,
    executable,
    prefix
  )
  t:defer(function()
    rpc:lua([[vim.lsp.stop_client(cmp_emmet_client, true)]])
  end)
  assert(
    Rpc.wait(10000, function()
      return rpc:lua(
        [[local client = vim.lsp.get_client_by_id(cmp_emmet_client); return client and client.initialized]]
      )
    end, 10),
    "real Emmet initialized"
  )
  return rpc
end

for _, case in ipairs({
  {
    name = "complete abbreviation outranks local snippets",
    prefix = "",
    input = "div>ul>li",
    expected = { "<div>", "  <ul>", "    <li></li>", "  </ul>", "</div>" },
  },
  {
    name = "partial abbreviation retains its complete input",
    prefix = "",
    input = "div>ul>l",
    expected = { "<div>", "  <ul>", "    <l></l>", "  </ul>", "</div>" },
  },
  {
    name = "Unicode before the abbreviation preserves the edit boundary",
    prefix = "中文 ",
    input = "div>ul>li",
    expected = { "中文 <div>", "  <ul>", "    <li></li>", "  </ul>", "</div>" },
  },
  {
    name = "suffix alternative remains available for explicit acceptance",
    prefix = "",
    input = "div>ul>li",
    alternative = "link",
    expected = { "<div>", "  <ul>", '    <link rel="stylesheet" href="">', "  </ul>", "</div>" },
  },
}) do
  t:test(case.name, function()
    local rpc = editor(case.prefix)
    rpc:request("nvim_input", { "A" .. case.input })
    assert(
      Rpc.wait(10000, function()
        return rpc:lua(
          [[
        local abbreviation = ...
        for _, item in ipairs(cmp_emmet_session and cmp_emmet_session.items or {}) do
          if item.source == 'lsp' and item.raw.label == abbreviation then return true end
        end
        return false
      ]],
          case.input
        )
      end, 10),
      "real Emmet candidate"
    )
    t.assert_true(
      rpc:lua([[
      for _, item in ipairs(cmp_emmet_session.items) do
        if item.source == 'snippets' and item.raw.label == 'li' then return true end
      end
      return false
    ]]),
      "local suffix snippet participates in ranking"
    )
    if case.alternative ~= nil then
      rpc:lua(
        [[
        local label = ...
        for index, item in ipairs(cmp_emmet_session.items) do
          if item.source == 'lsp' and item.raw.label == label then
            assert(require('era.keystroke.cmp').accept(index))
            return
          end
        end
        error('LSP alternative missing: ' .. label)
      ]],
        case.alternative
      )
    else
      rpc:request("nvim_input", { "<CR>" })
    end
    assert(
      Rpc.wait(3000, function()
        return vim.deep_equal(case.expected, rpc:request("nvim_buf_get_lines", { 0, 0, -1, false }))
      end, 10),
      "acceptance preserves the full abbreviation and prefix"
    )
    t.assert_eq("", rpc:lua([[return vim.v.errmsg]]), "no editor errors")
  end)
end

t:run()

local bootstrap = require("__test__.support.bootstrap")
local harness = require("__test__.support.harness")
local t = harness.new()

bootstrap.with_global(t, "stl", { env = { IS_WIN = false } })
bootstrap.with_global(t, "era", {
  m = {
    lsp = {
      fn = require("era.m.lsp.fn"),
      event = { get_capabilities = vim.lsp.protocol.make_client_capabilities },
    },
  },
})

local servers = {
  cssls = "vscode-css-language-server",
  eslint = "vscode-eslint-language-server",
  html = "vscode-html-language-server",
  jsonls = "vscode-json-language-server",
  tailwindcss = "tailwindcss-language-server",
  yamlls = "yaml-language-server",
}

---@return string
local function project()
  local root = t:tempdir()
  vim.fn.mkdir(root .. "/node_modules/.bin", "p")
  return assert(vim.uv.fs_realpath(root))
end

t:test("server commands select each workspace executable independently of editor cwd", function()
  local roots = { project(), project() }
  local previous_cwd = assert(vim.uv.cwd())
  t:defer(function()
    vim.api.nvim_set_current_dir(previous_cwd)
  end)
  vim.api.nvim_set_current_dir(roots[1])

  local commands = {}
  local dispatchers = {}
  local client = {}
  t:patch_table(vim.lsp.rpc, "start", function(args, handlers, options)
    commands[#commands + 1] = { args = args, handlers = handlers, cwd = options.cwd }
    return client
  end)

  for server, executable in pairs(servers) do
    local config = dofile(previous_cwd .. "/lsp/" .. server .. ".lua")
    for _, root in ipairs(roots) do
      local binpath = root .. "/node_modules/.bin/" .. executable
      vim.fn.writefile({ "#!/bin/sh" }, binpath)
      assert(vim.uv.fs_chmod(binpath, 493))
      t.assert_eq(client, config.cmd(dispatchers, { root_dir = root }), server .. " client")
      local command = commands[#commands]
      t.assert_eq(binpath, command.args[1], server .. " executable")
      t.assert_eq("--stdio", command.args[2], server .. " transport")
      t.assert_eq(2, #command.args, server .. " arguments")
      t.assert_eq(dispatchers, command.handlers, server .. " dispatchers")
      t.assert_eq(root, command.cwd, server .. " working directory")
    end
  end
end)

t:test("server commands keep ancestor lookup and PATH fallback for unavailable local executables", function()
  local root = project()
  local nested = root .. "/packages/app"
  vim.fn.mkdir(nested .. "/node_modules/.bin", "p")
  local command
  t:patch_table(vim.lsp.rpc, "start", function(args, _, options)
    command = { args = args, cwd = options.cwd }
    return {}
  end)

  for server, executable in pairs(servers) do
    local config = dofile("lsp/" .. server .. ".lua")
    local binpath = root .. "/node_modules/.bin/" .. executable
    vim.fn.writefile({ "#!/bin/sh" }, binpath)
    assert(vim.uv.fs_chmod(binpath, 493))
    local unavailable = nested .. "/node_modules/.bin/" .. executable
    vim.fn.writefile({ "" }, unavailable)
    assert(vim.uv.fs_chmod(unavailable, 420))

    config.cmd({}, { root_dir = nested })
    t.assert_eq(binpath, command.args[1], server .. " ancestor binary")
    t.assert_eq(nested, command.cwd, server .. " nested workspace")

    assert(vim.uv.fs_chmod(binpath, 420))
    config.cmd({}, { root_dir = nested })
    t.assert_eq(executable, command.args[1], server .. " PATH fallback")

    config.cmd({}, {})
    t.assert_eq(executable, command.args[1], server .. " no workspace")
    t.assert_nil(command.cwd, server .. " no workspace cwd")
  end
end)

t:run()

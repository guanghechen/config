-- https://github.com/neovim/nvim-lspconfig/blob/784531c83cdab93ed7a2ec10f0111ca564b1c18a/lsp/rust_analyzer.lua
-- https://github.com/neovim/nvim-lspconfig/blob/master/doc/configs.md#rust_analyzer

local __module_name__ = "lsp.rust_analyzer" ---@type string

local function reload_workspace(bufnr)
  local clients = vim.lsp.get_clients({ bufnr = bufnr, name = "rust_analyzer" })
  for _, client in ipairs(clients) do
    std.reporter.info({
      from = __module_name__,
      subject = "reload_workspace",
      message = "Reloading Cargo workspace",
    })
    ---@diagnostic disable-next-line:param-type-mismatch
    client:request("rust-analyzer/reloadWorkspace", nil, function(err)
      if err then
        error(tostring(err))
      end
      std.reporter.info({
        from = __module_name__,
        subject = "reload_workspace",
        message = "Cargo workspace reloaded",
      })
    end, 0)
  end
end

---@param fname                         string
---@return string|nil
local function is_library(fname)
  local user_home = std.env.HOME_USER
  local cargo_home = os.getenv("CARGO_HOME") or std.path.join(user_home, ".cargo")

  local registry = std.path.join(cargo_home, "registry/src")
  local git_registry = std.path.join(cargo_home, "git/checkouts")
  local rustup_home = os.getenv("RUSTUP_HOME") or std.path.join(user_home, ".rustup")
  local toolchains = std.path.join(rustup_home, "toolchains")

  local normalized_fname = std.path.normalize(fname, false)
  for _, item in ipairs({ toolchains, registry, git_registry }) do
    if std.path.is_descendant(item, normalized_fname) then
      local clients = vim.lsp.get_clients({ name = "rust_analyzer" })
      return #clients > 0 and clients[#clients].config.root_dir or nil
    end
  end
end

---@param bufnr                         integer
---@param on_dir                        fun(rootdir: string|nil)
local function root_dir(bufnr, on_dir)
  local fname = vim.api.nvim_buf_get_name(bufnr)
  local reused_dir = is_library(fname)
  if reused_dir then
    on_dir(reused_dir)
    return
  end

  local cargo_crate_dir = vim.fs.root(fname, { "Cargo.toml" })
  local cargo_workspace_root

  if cargo_crate_dir == nil then
    on_dir(
      vim.fs.root(fname, { "rust-project.json" })
        or vim.fs.dirname(vim.fs.find(".git", { path = fname, upward = true })[1])
    )
    return
  end

  local cmd = {
    "cargo",
    "metadata",
    "--no-deps",
    "--format-version",
    "1",
    "--manifest-path",
    cargo_crate_dir .. "/Cargo.toml",
  }

  vim.system(cmd, { text = true }, function(output)
    vim.schedule(function()
      if output.code == 0 then
        if output.stdout then
          local result = vim.json.decode(output.stdout)
          local workspace_root = result["workspace_root"] ---@type unknown
          if workspace_root ~= "" and type(workspace_root) == "string" then
            cargo_workspace_root = std.path.normalize(workspace_root, false)
          end
        end

        on_dir(cargo_workspace_root or cargo_crate_dir)
      else
        std.reporter.error({
          from = __module_name__,
          subject = "root_dir",
          message = "Failed to run cargo metadata.",
          details = {
            cmd = table.concat(cmd, " "),
            code = output.code,
            stderr = output.stderr,
          },
        })
      end
    end)
  end)
end

---@param params                        lsp.InitializeParams
---@param config                        table
---@return nil
local function before_init(params, config)
  eve.lsp.before_init(params, config)

  -- See https://github.com/rust-lang/rust-analyzer/blob/eb5da56d839ae0a9e9f50774fa3eb78eb0964550/docs/dev/lsp-extensions.md?plain=1#L26
  if config.settings and config.settings["rust-analyzer"] then
    params.initializationOptions = config.settings["rust-analyzer"]
  end

  ---@param command table{ title: string, command: string, arguments: any[] }
  vim.lsp.commands["rust-analyzer.runSingle"] = function(command)
    local r = command.arguments[1]
    local cmd = { "cargo", unpack(r.args.cargoArgs) }
    if r.args.executableArgs and #r.args.executableArgs > 0 then
      vim.list_extend(cmd, { "--", unpack(r.args.executableArgs) })
    end

    local proc = vim.system(cmd, { cwd = r.args.cwd })

    local result = proc:wait()

    if result.code == 0 then
      std.reporter.info({
        from = __module_name__,
        subject = "runSingle",
        message = vim.trim(result.stdout or "Command completed."),
      })
    else
      std.reporter.error({
        from = __module_name__,
        subject = "runSingle",
        message = "Command failed.",
        details = {
          cmd = table.concat(cmd, " "),
          code = result.code,
          stderr = result.stderr,
        },
      })
    end
  end

  local caps = params.capabilities
  local experimental = type(caps.experimental) == "table" and caps.experimental or {} ---@cast experimental table
  experimental.serverStatusNotification = true
  caps.experimental = experimental
end

---@param client                        vim.lsp.Client
---@param bufnr                         integer
local function on_attach(client, bufnr)
  eve.lsp.on_attach(client, bufnr)

  vim.api.nvim_buf_create_user_command(bufnr, "LspCargoReload", function()
    reload_workspace(bufnr)
  end, { desc = "Reload current cargo workspace" })
end

---@param client                        vim.lsp.Client
---@param bufnr                         integer
local function on_detach(client, bufnr)
  eve.lsp.on_detach(client, bufnr)
end

---@param client                        vim.lsp.Client
---@param config                        any
local function on_init(client, config)
  eve.lsp.on_init(client, config)
end

local capabilities = eve.lsp.get_capabilities()
local experimental = type(capabilities.experimental) == "table" and capabilities.experimental or {} ---@cast experimental table
experimental.serverStatusNotification = true
experimental.commands = vim.list_extend({
  "rust-analyzer.showReferences",
  "rust-analyzer.runSingle",
  "rust-analyzer.debugSingle",
}, experimental.commands or {})
capabilities.experimental = experimental

---@type vim.lsp.Config
return {
  capabilities = capabilities,
  cmd = { "rust-analyzer" },
  filetypes = { "rust" },
  settings = {
    ["rust-analyzer"] = {
      check = {
        command = "clippy",
      },
      completion = {
        limit = 69,
        privateEditable = {
          enable = true,
        },
      },
      diagnostics = {
        enable = false,
      },
      imports = {
        merge = {
          blob = false,
        },
      },
      lens = {
        debug = { enable = true },
        enable = true,
        implementations = { enable = true },
        references = {
          adt = { enable = true },
          enumVariant = { enable = true },
          method = { enable = true },
          trait = { enable = true },
        },
        run = { enable = true },
        updateTest = { enable = true },
      },
      procMacro = {
        enable = true,
      },
    },
  },
  root_dir = root_dir,
  before_init = before_init,
  on_attach = on_attach,
  on_detach = on_detach,
  on_init = on_init,
}

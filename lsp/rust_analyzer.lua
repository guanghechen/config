-- https://github.com/neovim/nvim-lspconfig/blob/0112e1f77983141e1453bd37d124302f1c876c46/lsp/rust_analyzer.lua
-- https://github.com/neovim/nvim-lspconfig/blob/master/doc/configs.md#rust_analyzer

local function reload_workspace(bufnr)
  local clients = vim.lsp.get_clients({ bufnr = bufnr, name = "rust_analyzer" })
  for _, client in ipairs(clients) do
    vim.notify("Reloading Cargo Workspace")
    client:request("rust-analyzer/reloadWorkspace", nil, function(err)
      if err then
        error(tostring(err))
      end
      vim.notify("Cargo workspace reloaded")
    end, 0)
  end
end

local function is_library(fname)
  local user_home = vim.fs.normalize(vim.env.HOME)
  local cargo_home = os.getenv("CARGO_HOME") or user_home .. "/.cargo"
  local registry = cargo_home .. "/registry/src"
  local git_registry = cargo_home .. "/git/checkouts"

  local rustup_home = os.getenv("RUSTUP_HOME") or user_home .. "/.rustup"
  local toolchains = rustup_home .. "/toolchains"

  for _, item in ipairs({ toolchains, registry, git_registry }) do
    if vim.fs.relpath(item, fname) then
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
    if output.code == 0 then
      if output.stdout then
        local result = vim.json.decode(output.stdout)
        if result["workspace_root"] then
          cargo_workspace_root = vim.fs.normalize(result["workspace_root"])
        end
      end

      on_dir(cargo_workspace_root or cargo_crate_dir)
    else
      vim.schedule(function()
        vim.notify(("[rust_analyzer] cmd failed with code %d: %s\n%s"):format(output.code, cmd, output.stderr))
      end)
    end
  end)
end

---@param params                        lsp.InitializeParams
---@param config                        table
local function before_init(params, config)
  eve.lsp.before_init(params, config)

  -- See https://github.com/rust-lang/rust-analyzer/blob/eb5da56d839ae0a9e9f50774fa3eb78eb0964550/docs/dev/lsp-extensions.md?plain=1#L26
  if config.settings and config.settings["rust-analyzer"] then
    params.initializationOptions = config.settings["rust-analyzer"]
  end

  local capabilities = params.capabilities
  capabilities.experimental = capabilities.experimental or {}
  capabilities.experimental.serverStatusNotification = true
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

return {
  capabilities = eve.lsp.get_capabilities(),
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

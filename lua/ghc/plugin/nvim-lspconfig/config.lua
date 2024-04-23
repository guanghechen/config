local config = function (_, opts)
  dofile(vim.g.base46_cache .. "lsp")
  require("nvchad.lsp")

  local icons = {
    diagnostics = require("ghc.core.icons").get("diagnostics"),
  }

  local utils = {
    on_attach = require("ghc.core.util.lsp").on_attach,
    keymap_on_attach = function(client, buffer)
      require("ghc.plugin.nvim-lspconfig.keymap").on_attach(client, buffer)
    end,
  }

  -- setup keymaps
  utils.on_attach(utils.keymap_on_attach)

  local register_capability = vim.lsp.handlers["client/registerCapability"]

  vim.lsp.handlers["client/registerCapability"] = function(err, res, ctx)
    local ret = register_capability(err, res, ctx)
    local client = vim.lsp.get_client_by_id(ctx.client_id)
    local buffer = vim.api.nvim_get_current_buf()
    utils.keymap_on_attach(client, buffer)
    return ret
  end

  -- diagnostics signs
  if vim.fn.has("nvim-0.10.0") == 0 then
    for severity, icon in pairs(opts.diagnostics.signs.text) do
      local name = vim.diagnostic.severity[severity]:lower():gsub("^%l", string.upper)
      name = "DiagnosticSign" .. name
      vim.fn.sign_define(name, { text = icon, texthl = name, numhl = "" })
    end
  end

  -- inlay hints
  if opts.inlay_hints.enabled then
    utils.on_attach(function(client, buffer)
      if client.supports_method("textDocument/inlayHint") then
        require("ghc.core.util.toggle").inlay_hints(buffer, true)
      end
    end)
  end

  -- code lens
  if opts.codelens.enabled and vim.lsp.codelens then
    utils.on_attach(function(client, buffer)
      if client.supports_method("textDocument/codeLens") then
        vim.lsp.codelens.refresh()
        --- autocmd BufEnter,CursorHold,InsertLeave <buffer> lua vim.lsp.codelens.refresh()
        vim.api.nvim_create_autocmd({ "BufEnter", "CursorHold", "InsertLeave" }, {
          buffer = buffer,
          callback = vim.lsp.codelens.refresh,
        })
      end
    end)
  end

  if type(opts.diagnostics.virtual_text) == "table" and opts.diagnostics.virtual_text.prefix == "icons" then
    opts.diagnostics.virtual_text.prefix = vim.fn.has("nvim-0.10.0") == 0 and "●"
      or function(diagnostic)
        for d, icon in pairs(icons.diagnostics) do
          if diagnostic.severity == vim.diagnostic.severity[d:upper()] then
            return icon
          end
        end
      end
  end

  vim.diagnostic.config(vim.deepcopy(opts.diagnostics))

  local servers = opts.servers
  local has_cmp, cmp_nvim_lsp = pcall(require, "cmp_nvim_lsp")
  local capabilities = vim.tbl_deep_extend(
    "force",
    {},
    vim.lsp.protocol.make_client_capabilities(),
    has_cmp and cmp_nvim_lsp.default_capabilities() or {},
    opts.capabilities or {}
  )

  local function setup(server)
    local server_opts = vim.tbl_deep_extend("force", {
      capabilities = vim.deepcopy(capabilities),
      on_init = function(client, _) 
        if client.supports_method "textDocument/semanticTokens" then
          client.server_capabilities.semanticTokensProvider = nil
        end
      end
    }, servers[server] or {})

    if opts.setup[server] then
      if opts.setup[server](server, server_opts) then
        return
      end
    elseif opts.setup["*"] then
      if opts.setup["*"](server, server_opts) then
        return
      end
    end
    require("lspconfig")[server].setup(server_opts)
  end

  -- get all the servers that are available through mason-lspconfig
  local have_mason, mlsp = pcall(require, "mason-lspconfig")
  local all_mslp_servers = {}
  if have_mason then
    all_mslp_servers = vim.tbl_keys(require("mason-lspconfig.mappings.server").lspconfig_to_package)
  end

  local ensure_installed = {} ---@type string[]
  for server, server_opts in pairs(servers) do
    if server_opts then
      server_opts = server_opts == true and {} or server_opts
      -- run manual setup if mason=false or if this is a server that cannot be installed with mason-lspconfig
      if server_opts.mason == false or not vim.tbl_contains(all_mslp_servers, server) then
        setup(server)
      elseif server_opts.enabled ~= false then
        ensure_installed[#ensure_installed + 1] = server
      end
    end
  end

  if have_mason then
    mlsp.setup({ ensure_installed = ensure_installed, handlers = { setup } })
  end
end

return config


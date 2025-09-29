-- https://github.com/neovim/nvim-lspconfig/blob/336b388c272555d2ae94627a50df4c2f89a5e257/lsp/copilot.lua
-- https://github.com/neovim/nvim-lspconfig/blob/master/doc/configs.md#copilot

local __module_name__ = "lsp.copilot" ---@type string

---@param bufnr                         integer,
---@param client                        vim.lsp.Client
---@return nil
local function sign_in(bufnr, client)
  client:request(
    ---@diagnostic disable-next-line: param-type-mismatch
    "signIn",
    vim.empty_dict(),
    function(err, result)
      if err then
        vim.notify(err.message, vim.log.levels.ERROR)
        return
      end
      if result.command then
        local code = result.userCode
        local command = result.command
        vim.fn.setreg("+", code)
        vim.fn.setreg("*", code)
        local continue = vim.fn.confirm(
          "Copied your one-time code to clipboard.\n" .. "Open the browser to complete the sign-in process?",
          "&Yes\n&No"
        )
        if continue == 1 then
          client:exec_cmd(command, { bufnr = bufnr }, function(cmd_err, cmd_result)
            if cmd_err then
              vim.notify(err.message, vim.log.levels.ERROR)
              return
            end
            if cmd_result.status == "OK" then
              vim.notify("Signed in as " .. cmd_result.user .. ".")
            end
          end)
        end
      end

      if result.status == "PromptUserDeviceFlow" then
        vim.notify("Enter your one-time code " .. result.userCode .. " in " .. result.verificationUri)
      elseif result.status == "AlreadySignedIn" then
        vim.notify("Already signed in as " .. result.user .. ".")
      end
    end
  )
end

---@param client                        vim.lsp.Client
---@return nil
local function sign_out(_, client)
  client:request(
    ---@diagnostic disable-next-line: param-type-mismatch
    "signOut",
    vim.empty_dict(),
    function(err, result)
      if err then
        vim.notify(err.message, vim.log.levels.ERROR)
        return
      end
      if result.status == "NotSignedIn" then
        vim.notify("Not signed in.")
      end
    end
  )
end

---@param bufnr                         integer
---@param on_dir                        fun(rootdir: string|nil)
local function root_dir(bufnr, on_dir)
  local workspace = std.path.workspace() ---@type string
  local filepath = vim.api.nvim_buf_get_name(bufnr) ---@type string
  if #filepath > #workspace and filepath:sub(1, #workspace) == workspace then
    on_dir(workspace)
    return
  end
end

---@param params                        lsp.InitializeParams
---@param config                        table
local function before_init(params, config)
  eve.lsp.before_init(params, config)
end

---@param client                        vim.lsp.Client
---@param bufnr                         integer
local function on_attach(client, bufnr)
  eve.lsp.on_attach(client, bufnr)

  ---@type std.t.IKeymap[]
  local keymaps = {
    {
      modes = { "i", "n" },
      key = "<c-k>",
      callback = function()
        vim.lsp.inline_completion.select({ count = -1 })
      end,
      desc = "Prev Copilot Suggestion",
    },
    {
      modes = { "i", "n" },
      key = "<c-j>",
      callback = function()
        vim.lsp.inline_completion.select({ count = 1 })
      end,
      desc = "Next Copilot Suggestion",
    },
  }
  eve.nvim.bindkeys(keymaps, { bufnr = bufnr })

  vim.api.nvim_buf_create_user_command(bufnr, "LspCopilotSignIn", function()
    sign_in(bufnr, client)
  end, { desc = "Sign in Copilot with GitHub" })
  vim.api.nvim_buf_create_user_command(bufnr, "LspCopilotSignOut", function()
    sign_out(bufnr, client)
  end, { desc = "Sign out Copilot with GitHub" })
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
  cmd = { "copilot-language-server", "--stdio" },
  init_options = {
    editorInfo = {
      name = "Neovim",
      version = tostring(vim.version()),
    },
    editorPluginInfo = {
      name = "Neovim",
      version = tostring(vim.version()),
    },
  },
  settings = {
    telemetry = {
      telemetryLevel = "off",
    },
  },
  filetypes = {
    "c",
    "cpp",
    "go",
    "javascript",
    "javascriptreact",
    "json",
    "lua",
    "python",
    "rust",
    "typescript",
    "typescriptreact",
    "markdown",
  },
  handlers = {
    -- Status handler for authentication monitoring (LazyVim pattern)
    didChangeStatus = function(err, res, ctx)
      if err then
        return
      end

      local client_id = ctx.client_id
      if res.status == "Error" then
        eve.status.copilots[client_id] = "error"
        std.reporter.warn({
          from = __module_name__,
          subject = "copilot_auth_error",
          message = "Please use `:Copilot auth` or `:LspCopilotSignIn` to sign in to Copilot",
        })
      elseif res.kind ~= "Normal" then
        eve.status.copilots[client_id] = "error"
      elseif res.busy then
        eve.status.copilots[client_id] = "pending"
      else
        eve.status.copilots[client_id] = "ok"
      end
    end,
  },
  root_dir = root_dir,
  before_init = before_init,
  on_attach = on_attach,
  on_detach = on_detach,
  on_init = on_init,
}

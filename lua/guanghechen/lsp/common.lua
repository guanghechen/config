local env = require("eve.lib.env")
local fs = require("eve.lib.fs")
local lsp = require("eve.lib.lsp")
local bindkeys = require("eve.lib.nvim").bindkeys
local path = require("eve.lib.path")
local command = require("eve.lib.command")

local actions = {
  rename = function()
    vim.lsp.buf.rename()
    vim.schedule(function()
      vim.cmd("stopinsert")
    end)
  end,

  show_code_action = function()
    vim.lsp.buf.code_action()
    vim.schedule(function()
      vim.cmd("stopinsert")
    end)
  end,

  show_code_action_source = function()
    vim.lsp.buf.code_action({
      context = {
        only = { "source" },
        diagnostics = {},
      },
    })
    vim.schedule(function()
      vim.cmd("stopinsert")
    end)
  end,
}

---@class guanghechen.lsp.common
local M = {}

local register_capability = vim.lsp.handlers["client/registerCapability"]
M.handlers = {
  ["textDocument/hover"] = vim.lsp.with(vim.lsp.handlers.hover, {
    border = "rounded",
    focusable = true,
    silent = true,
  }),
  ["textDocument/signatureHelp"] = vim.lsp.with(vim.lsp.handlers.signature_help, {
    border = "rounded",
    focusable = true,
    silent = true,
  }),
  ["client/registerCapability"] = function(err, res, ctx)
    ---@diagnostic disable-next-line: no-unknown
    local ret = register_capability(err, res, ctx)
    local client = vim.lsp.get_client_by_id(ctx.client_id)
    if client then
      for bufnr in pairs(client.attached_buffers) do
        vim.api.nvim_exec_autocmds("User", {
          pattern = "LspDynamicCapability",
          data = { client_id = client.id, buffer = bufnr },
        })
      end
    end
    return ret
  end,
}

local has_cmp, cmp_nvim_lsp = pcall(require, "cmp_nvim_lsp")
M.capabilities = vim.tbl_deep_extend(
  "force",
  {},
  vim.lsp.protocol.make_client_capabilities(),
  has_cmp and cmp_nvim_lsp.default_capabilities() or {},
  {}
)
M.capabilities.textDocument.completion.completionItem = {
  documentationFormat = { "markdown", "plaintext" },
  snippetSupport = true,
  preselectSupport = true,
  insertReplaceSupport = true,
  labelDetailsSupport = true,
  deprecatedSupport = true,
  commitCharactersSupport = true,
  tagSupport = { valueSet = { 1 } },
  resolveSupport = {
    properties = {
      "documentation",
      "detail",
      "additionalTextEdits",
    },
  },
}

---@param dirpath                       string
---@param config_filenames              string[]
---@return string|nil
function M.find_filepath(dirpath, config_filenames)
  for _, filename in ipairs(config_filenames) do
    local filepath = dirpath .. env.PATH_SEP .. filename ---@type string
    if fs.is_file_or_dir(filepath) == "file" then
      return filepath
    end
  end
end

---@param filepath                      string
---@param config_filenames              string[]
---@return string|nil
---@return string|nil
function M.locate_lsp_root(filepath, config_filenames)
  local cwd = path.cwd() ---@type string
  do
    local config_filepath = M.find_filepath(cwd, config_filenames) ---@type string|nil
    if config_filepath ~= nil then
      return cwd, config_filepath
    end
  end

  local workspace = path.workspace() ---@type string
  if cwd ~= workspace then
    local config_filepath = M.find_filepath(workspace, config_filenames) ---@type string|nil
    if config_filepath ~= nil then
      return workspace, config_filepath
    end
  end

  local pieces = path.split(filepath) ---@type string[]
  local k = #pieces - 1 ---@type integer
  while k >= 1 do
    local dirpath = table.concat(pieces, env.PATH_SEP, 1, k) ---@type string
    if dirpath == cwd then
      break
    end

    local config_filepath = M.find_filepath(dirpath, config_filenames) ---@type string|nil
    if config_filepath ~= nil then
      return dirpath, config_filepath
    end
    k = k - 1
  end
end

---@param client                        vim.lsp.Client
---@param bufnr                         integer
---@diagnostic disable-next-line: unused-local
function M.on_attach(client, bufnr)
  local has_support_codeLens = lsp.has_support_method(bufnr, "codeLens") ---@type boolean
  local has_support_codeAction = lsp.has_support_method(bufnr, "codeAction") ---@type boolean
  local has_support_rename = lsp.has_support_method(bufnr, "rename") ---@type boolean

  ---@type eve.t.IKeymap[]
  local keymaps = {
    {
      modes = { "n" },
      key = "K",
      callback = function()
        vim.lsp.buf.hover()
      end,
      desc = "lsp: hover",
    },
    {
      modes = { "n" },
      key = "gD",
      callback = function()
        vim.lsp.buf.declaration()
      end,
      desc = "lsp: goto declaration",
    },
    {
      modes = { "n" },
      key = "gK",
      callback = function()
        vim.lsp.buf.signature_help()
      end,
      desc = "lsp: show signature help",
    },
    {
      modes = { "n" },
      key = "gd",
      callback = function()
        command.execute(command.definitions.lsp.goto_definitions.uuid)
      end,
      desc = "lsp: goto definition",
    },
    {
      modes = { "n" },
      key = "gi",
      callback = function()
        command.execute(command.definitions.lsp.goto_implementations.uuid)
      end,
      desc = "lsp: goto implementation",
    },
    {
      modes = { "n" },
      key = "gr",
      callback = function()
        command.execute(command.definitions.lsp.goto_references.uuid)
      end,
      desc = "lsp: show references",
    },
    {
      modes = { "n" },
      key = "gt",
      callback = function()
        command.execute(command.definitions.lsp.goto_type_definitions.uuid)
      end,
      desc = "lsp: goto type definition",
    },
    {
      modes = { "n", "v" },
      key = "<M-cr>",
      callback = actions.show_code_action,
      desc = "lsp: code action",
      active = has_support_codeAction,
    },
    {
      modes = { "n", "v" },
      key = "<leader>cc",
      callback = function()
        vim.lsp.codelens.run()
      end,
      desc = "lsp: codelens",
      active = has_support_codeLens,
    },
    {
      modes = { "n", "v" },
      key = "<leader>cC",
      callback = function()
        vim.lsp.codelens.refresh()
      end,
      desc = "lsp: refresh & display codelens",
      active = has_support_codeLens,
    },
    {
      modes = { "n" },
      key = "<leader>ca",
      callback = actions.show_code_action_source,
      desc = "lsp: source action",
      active = has_support_codeAction,
    },
    {
      modes = { "n" },
      key = "<leader>cr",
      callback = actions.rename,
      desc = "lsp: rename",
      active = has_support_rename,
    },
  }
  bindkeys(keymaps, { bufnr = bufnr })
end

function M.on_init(client, _)
  if client.supports_method("textDocument/semanticTokens") then
    client.server_capabilities.semanticTokensProvider = nil
  end
end

---@param from                          string
---@param to                            string
---@param rename                        ?fun(): nil
---@return nil
---@see https://github.com/folke/snacks.nvim/blob/140204fde53531dd5dc5bd222975a9ff350747ad/lua/snacks/rename.lua#L51
function M.on_rename(from, to, rename)
  local changes = { files = { {
    oldUri = vim.uri_from_fname(from),
    newUri = vim.uri_from_fname(to),
  } } }

  local clients = vim.lsp.get_clients()
  for _, client in ipairs(clients) do
    if client.supports_method("workspace/willRenameFiles") then
      local resp = client.request_sync("workspace/willRenameFiles", changes, 1000, 0)
      if resp and resp.result ~= nil then
        vim.lsp.util.apply_workspace_edit(resp.result, client.offset_encoding)
      end
    end
  end

  if rename then
    rename()
  end

  for _, client in ipairs(clients) do
    if client.supports_method("workspace/didRenameFiles") then
      client.notify("workspace/didRenameFiles", changes)
    end
  end
end

return M

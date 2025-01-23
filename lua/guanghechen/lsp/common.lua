local __module_name__ = "guanghechen.lsp.common" ---@type string

local env = require("eve.builtin.env")
local fs = require("eve.builtin.fs")
local fn = require("eve.builtin.fn")
local path = require("eve.builtin.path")
local reporter = require("eve.builtin.reporter")
local lsp = require("eve.module.lsp")

local command = require("eve.command")

---@class guanghechen.lsp.common
local M = {}

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
}

M.get_capabilities = function()
  local has_cmp, cmp_nvim_lsp = pcall(require, "cmp_nvim_lsp")
  local capabilities = vim.tbl_deep_extend(
    "force",
    {},
    vim.lsp.protocol.make_client_capabilities(),
    has_cmp and cmp_nvim_lsp.default_capabilities() or {},
    {
      workspace = {
        fileOperations = {
          didRename = true,
          willRename = true,
        },
      },
    }
  )
  capabilities.textDocument.completion.completionItem = {
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
  return capabilities
end

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

---@param pkg                           string
---@param pkg_path                      string
---@param silent                        ?boolean
---@return string|nil
function M.locate_mason_pkg_path(pkg, pkg_path, silent)
  pcall(require, "mason") -- make sure Mason is loaded. Will fail when generating docs
  local root = vim.env.MASON or (env.HOME_NVIM_DATA .. env.PATH_SEP .. "mason")
  local filepath = root .. "/packages/" .. pkg .. "/" .. pkg_path

  if not vim.uv.fs_stat(filepath) and not require("lazy.core.config").headless() then
    if not silent then
      reporter.warn({
        from = __module_name__,
        subject = "locate_mason_pkg_path",
        message = string.format(
          "Mason package path not found for **%s**:\n- `%s`\nYou may need to force update the package.",
          pkg,
          pkg_path
        ),
      })
    end
    return nil
  end

  return filepath
end

---@param client                        vim.lsp.Client
---@param bufnr                         integer
---@diagnostic disable-next-line: unused-local
function M.on_attach(client, bufnr)
  local has_support_codeLens = lsp.has_support_method(bufnr, "codeLens") ---@type boolean
  local has_support_codeAction = lsp.has_support_method(bufnr, "codeAction") ---@type boolean
  local has_support_rename = lsp.has_support_method(bufnr, "rename") ---@type boolean

  if client then
    lsp.check_methods(client, bufnr)
  end

  ---@type eve.t.IKeymap[]
  local keymaps = {
    {
      modes = { "n" },
      key = "K",
      callback = function()
        vim.lsp.buf.hover()

        vim.defer_fn(function()
          vim.lsp.buf.hover()
        end, 100)
      end,
      desc = "lsp: hover",
    },
    {
      modes = { "n" },
      key = "gD",
      callback = function()
        vim.lsp.buf.declaration()

        vim.defer_fn(function()
          vim.lsp.buf.declaration()
        end, 100)
      end,
      desc = "lsp: goto declaration",
    },
    {
      modes = { "n" },
      key = "gK",
      callback = function()
        vim.lsp.buf.signature_help()

        vim.defer_fn(function()
          vim.lsp.buf.signature_help()
        end, 100)
      end,
      desc = "lsp: show signature help",
    },
    {
      modes = { "n" },
      key = "gd",
      callback = function()
        vim.cmd(command.definitions.lsp.goto_definitions.uuid)
      end,
      desc = "lsp: goto definition",
    },
    {
      modes = { "n" },
      key = "gi",
      callback = function()
        vim.cmd(command.definitions.lsp.goto_implementations.uuid)
      end,
      desc = "lsp: goto implementation",
    },
    {
      modes = { "n" },
      key = "gr",
      callback = function()
        vim.cmd(command.definitions.lsp.goto_references.uuid)
      end,
      desc = "lsp: show references",
    },
    {
      modes = { "n" },
      key = "gt",
      callback = function()
        vim.cmd(command.definitions.lsp.goto_type_definitions.uuid)
      end,
      desc = "lsp: goto type definition",
    },
    {
      modes = { "n", "v" },
      key = "<C-a><cr>",
      aliases = { "<D-cr>", "<M-cr>" },
      callback = function()
        vim.cmd(command.definitions.lsp.show_code_action.uuid)
      end,
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
      callback = function()
        vim.cmd(command.definitions.lsp.show_code_action_source.uuid)
      end,
      desc = "lsp: source action",
      active = has_support_codeAction,
    },
    {
      modes = { "n" },
      key = "<leader><cr>",
      callback = function()
        vim.cmd(command.definitions.lsp.rename.uuid)
      end,
      desc = "lsp: rename",
      active = has_support_rename,
    },
  }
  fn.bindkeys(keymaps, { bufnr = bufnr })
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

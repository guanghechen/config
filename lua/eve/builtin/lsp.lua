local __module_name__ = "eve.builtin.lsp"

---@class eve.builtin.lsp.ISymbolPos
---@field public line                   integer
---@field public character              integer

---@type table<string, table<vim.lsp.Client, table<number, boolean>>>
local supports_method = {}

---! Check if cursor is within range
---@param cursor                      eve.builtin.lsp.ISymbolPos
---@param range                       { start: eve.builtin.lsp.ISymbolPos, end: eve.builtin.lsp.ISymbolPos }
---@return boolean
local function is_within_range(cursor, range)
  local start = range.start ---@type eve.builtin.lsp.ISymbolPos
  local finish = range["end"] ---@type eve.builtin.lsp.ISymbolPos
  return (cursor.line > start.line or (cursor.line == start.line and cursor.character >= start.character))
    and (cursor.line < finish.line or (cursor.line == finish.line and cursor.character <= finish.character))
end

---@class eve.builtin.lsp
local M = {}

---@param client                        vim.lsp.Client
---@return nil
function M.check_methods(client, bufnr)
  -- don't trigger on invalid buffers
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  -- don't trigger on non-listed buffers
  if not vim.bo[bufnr].buflisted then
    return
  end

  -- don't trigger on nofile buffers
  if vim.bo[bufnr].buftype == "nofile" then
    return
  end

  for method, clients in pairs(supports_method) do
    clients[client] = clients[client] or {}
    if not clients[client][bufnr] then
      if client:supports_method(method, bufnr) then
        clients[client][bufnr] = true
        vim.api.nvim_exec_autocmds("User", {
          pattern = "LspSupportsMethod",
          data = { client_id = client.id, buffer = bufnr, method = method },
        })
      end
    end
  end
end

---! Find the symbol path recursively
---@param cursor                      eve.builtin.lsp.ISymbolPos
---@param symbols                     any[]|nil
---@return any[]|nil
function M.find_symbol_path(cursor, symbols)
  if symbols == nil then
    return
  end

  for _, symbol in ipairs(symbols) do
    if symbol.location then
      local range = symbol.location.range
      if is_within_range(cursor, range) then
        return { symbol }
      end
    elseif symbol.range then
      local range = symbol.range
      if is_within_range(cursor, range) then
        local path = { symbol }
        if symbol.children then
          local child_path = M.find_symbol_path(cursor, symbol.children)
          if child_path then
            for _, child_symbol in ipairs(child_path) do
              path[#path + 1] = child_symbol
            end
          end
        end
        return path
      end
    end
  end
  return nil
end

---@param bufnr                         integer
---@param method                        string
---@return boolean
function M.has_support_method(bufnr, method)
  method = method:find("/") and method or "textDocument/" .. method
  local clients = vim.lsp.get_clients({ bufnr = bufnr })
  for _, client in ipairs(clients) do
    if client:supports_method(method) then
      return true
    end
  end
  return false
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
    if client:supports_method("workspace/willRenameFiles") then
      local resp = client:request_sync("workspace/willRenameFiles", changes, 1000, 0)
      if resp and resp.result ~= nil then
        vim.lsp.util.apply_workspace_edit(resp.result, client.offset_encoding)
      end
    end
  end

  if rename then
    rename()
  end

  for _, client in ipairs(clients) do
    if client:supports_method("workspace/didRenameFiles") then
      client:notify("workspace/didRenameFiles", changes)
    end
  end
end

---@param method                        string
---@param callback                      fun(client: vim.lsp.Client, bufnr: integer): nil
function M.on_supports_method(method, callback)
  supports_method[method] = supports_method[method] or setmetatable({}, { __mode = "k" })

  return vim.api.nvim_create_autocmd("User", {
    pattern = "LspSupportsMethod",
    group = eve.nvim.augroup("on_supports_method:" .. method),
    callback = function(args)
      local bufnr = args.data.buffer ---@type number
      local client = vim.lsp.get_client_by_id(args.data.client_id)
      if client and method == args.data.method then
        return callback(client, bufnr)
      end
    end,
  })
end

---@param files                         { oldUri: string, newUri: string }[]
---@return nil
function M.preload_rename_files(files)
  for _, file_change in ipairs(files) do
    local old_filepath = vim.uri_to_fname(file_change.oldUri)
    if std.path.is_exist_filepath(old_filepath) then
      eve.buf.loadfile(old_filepath)
    end
  end
end

---@param files                         { oldUri: string, newUri: string }[]
---@return nil
function M.replace_renamed_buffers(files)
  for _, file_change in ipairs(files) do
    local old_filepath = vim.uri_to_fname(file_change.oldUri)
    local new_filepath = vim.uri_to_fname(file_change.newUri)

    -- Find buffer with old filepath
    local old_bufnr = vim.fn.bufnr(old_filepath)
    if old_bufnr ~= -1 and vim.api.nvim_buf_is_valid(old_bufnr) then
      -- Check if buffer is currently displayed in any windows
      local windows_with_buffer = {}
      for _, win in ipairs(vim.api.nvim_list_wins()) do
        if vim.api.nvim_win_get_buf(win) == old_bufnr then
          windows_with_buffer[#windows_with_buffer + 1] = win
        end
      end

      -- Create new buffer with new filepath
      local new_bufnr = vim.fn.bufadd(new_filepath)
      if new_bufnr and vim.api.nvim_buf_is_valid(new_bufnr) then
        -- Load the new buffer content
        vim.fn.bufload(new_bufnr)

        -- Copy buffer-local settings from old to new buffer
        local old_bo = vim.bo[old_bufnr]
        local new_bo = vim.bo[new_bufnr]
        new_bo.filetype = old_bo.filetype
        new_bo.buflisted = old_bo.buflisted

        -- Replace old buffer with new buffer in all windows
        for _, win in ipairs(windows_with_buffer) do
          vim.api.nvim_win_set_buf(win, new_bufnr)
        end

        -- Delete the old buffer
        vim.schedule(function()
          if vim.api.nvim_buf_is_valid(old_bufnr) then
            vim.api.nvim_buf_delete(old_bufnr, { force = true })
          end
        end)
      end
    end
  end
end

---@return lsp.ClientCapabilities
M.get_capabilities = function()
  local capabilities = vim.lsp.protocol.make_client_capabilities() ---@type lsp.ClientCapabilities
  return capabilities
end

---@param dirpath                       string
---@param config_filenames              string[]
---@return string|nil
function M.find_filepath(dirpath, config_filenames)
  for _, filename in ipairs(config_filenames) do
    local filepath = dirpath .. std.env.PATH_SEP .. filename ---@type string
    if std.path.is_exist_filepath(filepath) then
      return filepath
    end
  end
end

---@param filepath                      string
---@param config_filenames              string[]
---@return string|nil
---@return string|nil
function M.locate_lsp_root(filepath, config_filenames)
  local cwd = std.path.cwd() ---@type string
  do
    local config_filepath = M.find_filepath(cwd, config_filenames) ---@type string|nil
    if config_filepath ~= nil then
      return cwd, config_filepath
    end
  end

  local workspace = std.path.workspace() ---@type string
  if cwd ~= workspace then
    local config_filepath = M.find_filepath(workspace, config_filenames) ---@type string|nil
    if config_filepath ~= nil then
      return workspace, config_filepath
    end
  end

  local pieces = std.path.split(filepath) ---@type string[]
  local k = #pieces - 1 ---@type integer
  while k >= 1 do
    local dirpath = table.concat(pieces, std.env.PATH_SEP, 1, k) ---@type string
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

---@param bin                           string
---@param silent                        ?boolean
---@return string|nil
---@diagnostic disable-next-line: unused-local
function M.locate_mason_bin_path(bin, silent)
  local root = vim.env.MASON or (std.env.HOME_NVIM_DATA .. std.env.PATH_SEP .. "mason")
  local filepath = std.path.normalize(root .. "/bin/" .. bin)
  return std.path.is_exist_filepath(filepath) and filepath or nil
end

---@param pkg                           string
---@param pkg_path                      string
---@param silent                        ?boolean
---@return string|nil
function M.locate_mason_pkg_path(pkg, pkg_path, silent)
  pcall(require, "mason") -- make sure Mason is loaded. Will fail when generating docs
  local root = vim.env.MASON or (std.env.HOME_NVIM_DATA .. std.env.PATH_SEP .. "mason")
  local filepath = root .. "/packages/" .. pkg .. "/" .. pkg_path

  if not vim.uv.fs_stat(filepath) and not require("lazy.core.config").headless() then
    if not silent then
      std.reporter.warn({
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

----------------------------------------------------------------------------------------------------

---@param params                        lsp.InitializeParams
---@param config                        table
---@diagnostic disable-next-line: unused-local
function M.before_init(params, config)
  local has_blink, blink = pcall(require, "blink.cmp")
  if has_blink then
    params.capabilities = vim.tbl_deep_extend("force", params.capabilities, blink.get_lsp_capabilities({}, false))
  end

  local capabilities = params.capabilities ---@type lsp.ClientCapabilities
  capabilities.textDocument = capabilities.textDocument or {}
  capabilities.textDocument.completion = capabilities.textDocument.completion or {}
  capabilities.textDocument.completion.completionItem = capabilities.textDocument.completion.completionItem or {}
  capabilities.textDocument.completion.completionItem.snippetSupport = true
end

---@param client                        vim.lsp.Client
---@param bufnr                         integer
---@diagnostic disable-next-line: unused-local
function M.on_attach(client, bufnr)
  local has_support_codeLens = M.has_support_method(bufnr, "codeLens") ---@type boolean
  local has_support_codeAction = M.has_support_method(bufnr, "codeAction") ---@type boolean
  local has_support_rename = M.has_support_method(bufnr, "rename") ---@type boolean
  local has_support_documentHighlight = M.has_support_method(bufnr, "documentHighlight") ---@type boolean

  if client then
    M.check_methods(client, bufnr)
  end

  ---@type std.t.IKeymap[]
  local keymaps = {
    {
      modes = { "n" },
      key = "K",
      callback = function()
        vim.lsp.buf.hover({
          focus = true,
          focusable = true,
        })
      end,
      desc = "lsp: hover",
    },
    {
      modes = { "n" },
      key = "gD",
      callback = function()
        vim.cmd("normal! m'")
        vim.lsp.buf.declaration()
      end,
      desc = "lsp: goto declaration",
    },
    {
      modes = { "n" },
      key = "gK",
      callback = function()
        vim.lsp.buf.signature_help({
          focus = true,
          focusable = true,
        })
      end,
      desc = "lsp: show signature help",
    },
    {
      modes = { "n" },
      key = "gd",
      callback = function()
        vim.cmd("normal! m'")
        vim.cmd(eve.command.definitions.lsp.goto_definitions.uuid)
      end,
      desc = "lsp: goto definition",
    },
    {
      modes = { "n" },
      key = "gi",
      callback = function()
        vim.cmd("normal! m'")
        vim.cmd(eve.command.definitions.lsp.goto_implementations.uuid)
      end,
      desc = "lsp: goto implementation",
    },
    {
      modes = { "n" },
      key = "gr",
      callback = function()
        vim.cmd("normal! m'")
        vim.cmd(eve.command.definitions.lsp.goto_references.uuid)
      end,
      desc = "lsp: show references",
    },
    {
      modes = { "n" },
      key = "gt",
      callback = function()
        vim.cmd("normal! m'")
        vim.cmd(eve.command.definitions.lsp.goto_type_definitions.uuid)
      end,
      desc = "lsp: goto type definition",
    },
    {
      disabled = not has_support_codeAction,
      modes = { "n", "v" },
      key = "<C-a><cr>",
      aliases = { "<D-cr>", "<M-cr>" },
      callback = function()
        vim.lsp.buf.code_action()
        vim.schedule(function()
          vim.cmd("stopinsert")
        end)
      end,
      desc = "lsp: code action",
    },
    {
      disabled = not has_support_codeLens,
      modes = { "n", "v" },
      key = "<leader>cc",
      callback = function()
        vim.lsp.codelens.run()
      end,
      desc = "lsp: codelens",
    },
    {
      disabled = not has_support_codeLens,
      modes = { "n", "v" },
      key = "<leader>cC",
      callback = function()
        vim.lsp.codelens.refresh()
      end,
      desc = "lsp: refresh & display codelens",
    },
    {
      disabled = not has_support_codeAction,
      modes = { "n" },
      key = "<leader>ca",
      callback = function()
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
      desc = "lsp: source action",
    },
    {
      disabled = not has_support_rename,
      modes = { "n" },
      key = "<leader>cr",
      callback = function()
        vim.lsp.buf.rename(nil, { bufnr = bufnr })
        vim.schedule(function()
          vim.cmd("stopinsert")
        end)
      end,
      desc = "lsp: rename",
    },
    {
      disabled = not has_support_documentHighlight,
      modes = { "n", "v" },
      key = "[[",
      callback = function()
        require("fml.dressing.illumniate").jump(-vim.v.count1, true)
      end,
      desc = "lsp: goto prev reference",
    },
    {
      disabled = not has_support_documentHighlight,
      modes = { "n", "v" },
      key = "]]",
      callback = function()
        require("fml.dressing.illumniate").jump(vim.v.count1, true)
      end,
      desc = "lsp: goto next reference",
    },
  }
  eve.nvim.bindkeys(keymaps, { bufnr = bufnr })
end

function M.on_init(client, _)
  if client:supports_method("textDocument/semanticTokens") then
    client.server_capabilities.semanticTokensProvider = nil
  end
end

return M

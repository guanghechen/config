-- https://github.com/neovim/nvim-lspconfig/blob/43ed3797b266e1ee8d222e491379ad471c9d3146/lsp/roslyn_ls.lua
-- https://github.com/neovim/nvim-lspconfig/blob/master/doc/configs.md#roslyn_ls

local __module_name__ = "lsp.roslyn_ls" ---@type string

local Methods = vim.lsp.protocol.Methods
local augroup_diagnostics = stl.nvim.fn.augroup(__module_name__ .. ".diagnostics")

---@param client                        vim.lsp.Client
---@param solution_path                 string
---@return nil
local function open_solution(client, solution_path)
  stl.reporter.debug({
    from = __module_name__,
    subject = "initialize",
    message = "Opening solution: " .. solution_path,
  })
  ---@diagnostic disable-next-line: param-type-mismatch
  client:notify("solution/open", {
    solution = vim.uri_from_fname(solution_path),
  })
end

---@param client                        vim.lsp.Client
---@param project_paths                 string[]
---@return nil
local function open_projects(client, project_paths)
  stl.reporter.debug({
    from = __module_name__,
    subject = "initialize",
    message = "Opening projects",
    details = project_paths,
  })
  ---@diagnostic disable-next-line: param-type-mismatch
  client:notify("project/open", {
    projects = vim.tbl_map(vim.uri_from_fname, project_paths),
  })
end

---@param client                        vim.lsp.Client
---@param target_bufnr                  integer|nil
---@return nil
local function refresh_diagnostics(client, target_bufnr)
  local dynamic_capabilities = client.dynamic_capabilities.capabilities.diagnosticProvider or {}
  local identifiers = vim
    .iter(dynamic_capabilities)
    :map(function(capability)
      return capability.registerOptions.identifier
    end)
    :totable()

  local bufnrs = target_bufnr and { target_bufnr } or vim.tbl_keys(client.attached_buffers)
  for _, bufnr in ipairs(bufnrs) do
    if vim.api.nvim_buf_is_loaded(bufnr) then
      for _, identifier in ipairs(identifiers) do
        client:request(Methods.textDocument_diagnostic, {
          identifier = identifier,
          textDocument = vim.lsp.util.make_text_document_params(bufnr),
        }, nil, bufnr)
      end
    end
  end
end

---@return table<string, lsp.Handler>
local function get_handlers()
  return {
    ["workspace/projectInitializationComplete"] = function(_, _, ctx)
      local client = assert(vim.lsp.get_client_by_id(ctx.client_id))
      stl.reporter.info({
        from = __module_name__,
        subject = "initialize",
        message = "Project initialization complete",
      })
      refresh_diagnostics(client)
      return vim.NIL
    end,
    ["razor/provideDynamicFileInfo"] = function()
      stl.reporter.warn({
        from = __module_name__,
        subject = "razor",
        message = "Razor requires roslyn.nvim and is not supported by this configuration.",
      })
      return vim.NIL
    end,
  }
end

---@param client                        vim.lsp.Client
---@param action                        table
---@param bufnr                         integer
---@return nil
local function apply_action(client, action, bufnr)
  if action.edit then
    vim.lsp.util.apply_workspace_edit(action.edit, client.offset_encoding)
  end
  if action.command then
    client:exec_cmd(action.command, { bufnr = bufnr })
  end
end

---@param client                        vim.lsp.Client
---@param command                       table
---@param bufnr                         integer
---@return nil
local function handle_fix_all_action(client, command, bufnr)
  local argument = command.arguments and command.arguments[1]
  if type(argument) ~= "table" then
    stl.reporter.error({
      from = __module_name__,
      subject = "fix all",
      message = "Invalid code action arguments.",
    })
    return
  end

  local scopes = argument.FixAllFlavors
  if type(scopes) ~= "table" or vim.tbl_isempty(scopes) then
    stl.reporter.warn({
      from = __module_name__,
      subject = "fix all",
      message = "No fix-all scopes are available.",
    })
    return
  end

  vim.ui.select(scopes, {
    prompt = "Fix All Scope:",
  }, function(scope)
    if scope == nil then
      return
    end

    ---@diagnostic disable-next-line: param-type-mismatch
    client:request("codeAction/resolveFixAll", {
      title = command.title,
      data = argument,
      scope = scope,
    }, function(err, resolved)
      if err then
        stl.reporter.error({
          from = __module_name__,
          subject = "fix all",
          message = err.message or tostring(err),
        })
        return
      end
      if resolved then
        apply_action(client, resolved, bufnr)
      end
    end, bufnr)
  end)
end

---@param bufnr                         integer
---@param utf16_offset                  integer
---@return [integer, integer]
local function cursor_from_utf16_offset(bufnr, utf16_offset)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local fileformat = vim.api.nvim_get_option_value("fileformat", { buf = bufnr }) ---@type string
  local newline_width = fileformat == "dos" and 2 or 1
  local remaining = utf16_offset

  for row, line in ipairs(lines) do
    local line_width = vim.str_utfindex(line, "utf-16")
    if remaining <= line_width then
      return { row, vim.str_byteindex(line, "utf-16", remaining, false) }
    end
    if row == #lines then
      return { row, #line }
    end

    remaining = remaining - line_width
    if remaining <= newline_width then
      return { row + 1, 0 }
    end
    remaining = remaining - newline_width
  end

  return { 1, 0 }
end

---@param value                         any
---@return boolean
local function is_lsp_position(value)
  return type(value) == "table"
    and type(value.line) == "number"
    and value.line >= 0
    and value.line % 1 == 0
    and type(value.character) == "number"
    and value.character >= 0
    and value.character % 1 == 0
end

---@param client                        vim.lsp.Client
---@param command                       table
---@param bufnr                         integer
---@return nil
local function handle_completion_complex_edit(client, command, bufnr)
  local arguments = command.arguments or {}
  local text_document, edit = arguments[1], arguments[2]
  local is_snippet, new_offset = arguments[3], arguments[4]
  local range = type(edit) == "table" and edit.range or nil

  local valid = type(bufnr) == "number"
    and vim.api.nvim_buf_is_valid(bufnr)
    and vim.api.nvim_buf_is_loaded(bufnr)
    and type(text_document) == "table"
    and type(text_document.uri) == "string"
    and text_document.uri == vim.uri_from_bufnr(bufnr)
    and type(edit) == "table"
    and type(edit.newText) == "string"
    and type(range) == "table"
    and is_lsp_position(range.start)
    and is_lsp_position(range["end"])
    and type(is_snippet) == "boolean"
    and type(new_offset) == "number"
    and new_offset % 1 == 0
  if not valid then
    stl.reporter.warn({
      from = __module_name__,
      subject = "completion",
      message = "Invalid complex edit arguments.",
      details = arguments,
    })
    return
  end
  ---@cast edit lsp.TextEdit
  ---@cast range lsp.Range
  ---@cast is_snippet boolean
  ---@cast new_offset integer

  local winnr = vim.fn.bufwinid(bufnr) ---@type integer
  if (is_snippet or new_offset >= 0) and winnr == -1 then
    stl.reporter.warn({
      from = __module_name__,
      subject = "completion",
      message = "Cannot apply a cursor-aware complex edit to a hidden buffer.",
      details = text_document.uri,
    })
    return
  end

  local ok, err = pcall(function()
    if is_snippet then
      local start_col = vim.lsp.util._get_line_byte_from_position(bufnr, range.start, client.offset_encoding)
      vim.api.nvim_win_call(winnr, function()
        vim.lsp.util.apply_text_edits({ { range = range, newText = "" } }, bufnr, client.offset_encoding)
        vim.api.nvim_win_set_cursor(winnr, { range.start.line + 1, start_col })
        pcall(function()
          vim.cmd("undojoin")
        end)
        vim.snippet.expand(edit.newText)
      end)
      return
    end

    vim.lsp.util.apply_text_edits({ edit }, bufnr, client.offset_encoding)
    if new_offset >= 0 then
      vim.api.nvim_win_set_cursor(winnr, cursor_from_utf16_offset(bufnr, new_offset))
    end
  end)
  if not ok then
    stl.reporter.error({
      from = __module_name__,
      subject = "completion",
      message = tostring(err),
    })
  end
end

---@return table<string, fun(command: table, ctx: lsp.HandlerContext)>
local function get_commands()
  return {
    ["roslyn.client.completionComplexEdit"] = function(command, ctx)
      local client = assert(vim.lsp.get_client_by_id(ctx.client_id))
      handle_completion_complex_edit(client, command, ctx.bufnr)
    end,

    ["roslyn.client.nestedCodeAction"] = function(command, ctx)
      local client = assert(vim.lsp.get_client_by_id(ctx.client_id))
      local argument = command.arguments and command.arguments[1]

      if type(argument) ~= "table" then
        stl.reporter.error({
          from = __module_name__,
          subject = "code action",
          message = "Invalid nested code action arguments.",
        })
        return
      end

      local function handle(action)
        if action == nil then
          return
        end

        if action.data and not action.edit and not action.command then
          client:request("codeAction/resolve", action, function(err, resolved)
            if err then
              stl.reporter.error({
                from = __module_name__,
                subject = "code action",
                message = err.message or tostring(err),
              })
              return
            end
            handle(resolved)
          end, ctx.bufnr)
          return
        end

        local nested = vim.islist(action) and action or action.NestedCodeActions
        if type(nested) ~= "table" or vim.tbl_isempty(nested) then
          apply_action(client, action, ctx.bufnr)
          return
        end

        if #nested == 1 then
          handle(nested[1])
          return
        end

        vim.ui.select(nested, {
          prompt = action.title or "Select code action:",
          format_item = function(item)
            return item.title or (item.command and item.command.title) or "Unnamed action"
          end,
        }, handle)
      end

      handle(argument)
    end,

    ["roslyn.client.fixAllCodeAction"] = function(command, ctx)
      local client = assert(vim.lsp.get_client_by_id(ctx.client_id))
      handle_fix_all_action(client, command, ctx.bufnr)
    end,
  }
end

---@param bufname                      string
---@return boolean
local function is_decompiled(bufname)
  local _, endpos = bufname:find("[/\\]MetadataAsSource[/\\]")
  if endpos == nil then
    return false
  end
  return vim.fn.finddir(bufname:sub(1, endpos), vim.uv.os_tmpdir()) ~= ""
end

---@param bufnr                         integer
---@param on_dir                        fun(rootdir: string|nil)
---@return nil
local function root_dir(bufnr, on_dir)
  local bufname = vim.api.nvim_buf_get_name(bufnr)
  if not is_decompiled(bufname) then
    local rootdir = vim.fs.root(bufnr, function(name)
      return name:match("%.sln[x]?$") ~= nil
    end)
    if rootdir == nil then
      rootdir = vim.fs.root(bufnr, function(name)
        return name:match("%.csproj$") ~= nil
      end)
    end
    if rootdir then
      on_dir(rootdir)
    end
    return
  end

  local previous_bufnr = vim.fn.bufnr("#")
  local client = vim.lsp.get_clients({
    name = "roslyn_ls",
    bufnr = previous_bufnr ~= -1 and previous_bufnr or nil,
  })[1]
  if client then
    on_dir(client.config.root_dir)
  end
end

---@param params                        lsp.InitializeParams
---@param config                        table
---@return nil
local function before_init(params, config)
  era.m.lsp.event.before_init(params, config)
end

---@param client                        vim.lsp.Client
---@param bufnr                         integer
---@return nil
local function on_attach(client, bufnr)
  vim.api.nvim_clear_autocmds({ group = augroup_diagnostics, buffer = bufnr })
  vim.api.nvim_create_autocmd({ "BufEnter", "InsertLeave" }, {
    group = augroup_diagnostics,
    buffer = bufnr,
    callback = function()
      if client.attached_buffers[bufnr] then
        refresh_diagnostics(client, bufnr)
      end
    end,
  })
  vim.api.nvim_create_autocmd("BufWritePost", {
    group = augroup_diagnostics,
    buffer = bufnr,
    callback = function()
      if client.attached_buffers[bufnr] then
        refresh_diagnostics(client)
      end
    end,
  })
  vim.api.nvim_create_autocmd("LspDetach", {
    group = augroup_diagnostics,
    buffer = bufnr,
    callback = function(args)
      local client_id = args.data and args.data.client_id or nil
      if client_id == client.id then
        vim.api.nvim_clear_autocmds({ group = augroup_diagnostics, buffer = bufnr })
      end
    end,
  })

  era.m.lsp.event.on_attach(client, bufnr)
end

---@param client                        vim.lsp.Client
---@param config                        any
---@return nil
local function on_init(client, config)
  era.m.lsp.event.on_init(client, config)

  local rootdir = client.config.root_dir
  if type(rootdir) ~= "string" or rootdir == "" then
    return
  end

  local solution_paths = {} ---@type string[]
  local project_paths = {} ---@type string[]
  for name, entry_type in vim.fs.dir(rootdir) do
    if entry_type == "file" then
      if name:match("%.sln[x]?$") then
        solution_paths[#solution_paths + 1] = vim.fs.joinpath(rootdir, name)
      elseif name:match("%.csproj$") then
        project_paths[#project_paths + 1] = vim.fs.joinpath(rootdir, name)
      end
    end
  end

  table.sort(solution_paths)
  table.sort(project_paths)
  if #solution_paths > 0 then
    -- Native integration has no target picker; keep multi-solution selection deterministic.
    open_solution(client, solution_paths[1])
  elseif #project_paths > 0 then
    open_projects(client, project_paths)
  end
end

local capabilities = era.m.lsp.event.get_capabilities()
capabilities.textDocument.diagnostic = capabilities.textDocument.diagnostic or {}
capabilities.textDocument.diagnostic.dynamicRegistration = true

-- Roslyn emits metadata files below TMPDIR; resolve macOS's symlink so navigation reuses the project client.
local resolved_tmpdir = vim.env.TMPDIR and vim.env.TMPDIR ~= "" and vim.uv.fs_realpath(vim.env.TMPDIR) or nil

---@type vim.lsp.Config
return {
  capabilities = capabilities,
  cmd = { "roslyn-language-server", "--stdio" },
  cmd_env = {
    TMPDIR = resolved_tmpdir,
  },
  commands = get_commands(),
  filetypes = { "cs" },
  handlers = get_handlers(),
  settings = {
    ["csharp|background_analysis"] = {
      dotnet_analyzer_diagnostics_scope = "openFiles",
      dotnet_compiler_diagnostics_scope = "openFiles",
    },
    ["csharp|code_lens"] = {
      dotnet_enable_references_code_lens = false,
      dotnet_enable_tests_code_lens = false,
    },
  },
  root_dir = root_dir,
  before_init = before_init,
  on_attach = on_attach,
  on_init = on_init,
}

local __module_name__ = "eve.builtin.lsp_action" ---@type string

local api = vim.api
local lsp = vim.lsp
local util = vim.lsp.util

---@class eve.builtin.lsp_action.ProviderContext
---@field public bufnr                 integer
---@field public win                   integer
---@field public mode                  string
---@field public lnum                  integer
---@field public cursor                { row: integer, col: integer }
---@field public selection             { start: { line: integer, character: integer }, ["end"]: { line: integer, character: integer } }|nil
---@field public opts                  table
---@field public context               table

---@class eve.builtin.lsp_action.ProviderAction
---@field public title                 string
---@field public kind                  string|nil
---@field public execute               fun(ctx: eve.builtin.lsp_action.ProviderContext): nil
---@field public source                string|nil

---@class eve.builtin.lsp_action.ProviderSpec
---@field public id                    string|nil
---@field public source                string|nil
---@field public handler               fun(ctx: eve.builtin.lsp_action.ProviderContext): eve.builtin.lsp_action.ProviderAction|eve.builtin.lsp_action.ProviderAction[]|nil

---@type eve.builtin.lsp_action.ProviderSpec[]
local providers = {}

---@type fun(opts?: table): nil
local original_code_action = vim.lsp.buf.code_action

local patched = false ---@type boolean

---@param value                         any
---@return boolean
local function is_list(value)
  if vim.islist then
    return vim.islist(value)
  end
  return vim.tbl_islist(value)
end

---@param bufnr                          integer
---@param mode                           string
---@return { start: { line: integer, character: integer }, ["end"]: { line: integer, character: integer } }
local function range_from_selection(bufnr, mode)
  local start_pos = vim.fn.getpos("v")
  local end_pos = vim.fn.getpos(".")

  local start_row = start_pos[2]
  local start_col = start_pos[3]
  local end_row = end_pos[2]
  local end_col = end_pos[3]

  if start_row == end_row and end_col < start_col then
    end_col, start_col = start_col, end_col
  elseif end_row < start_row then
    start_row, end_row = end_row, start_row
    start_col, end_col = end_col, start_col
  end

  if mode == "V" then
    start_col = 1
    local line = api.nvim_buf_get_lines(bufnr, end_row - 1, end_row, true)[1] or ""
    end_col = #line + 1
  elseif mode == "\22" then
    start_col = start_col + 1
  end

  return {
    start = { line = start_row - 1, character = start_col - 1 },
    ["end"] = { line = end_row - 1, character = end_col - 1 },
  }
end

---@param ctx                           eve.builtin.lsp_action.ProviderContext
---@return { action: lsp.CodeAction, spec: eve.builtin.lsp_action.ProviderAction, provider: eve.builtin.lsp_action.ProviderSpec, ctx: eve.builtin.lsp_action.ProviderContext }[]
local function collect_provider_actions(ctx)
  if #providers < 1 then
    return {}
  end

  local actions = {} ---@type { action: lsp.CodeAction, spec: eve.builtin.lsp_action.ProviderAction, provider: eve.builtin.lsp_action.ProviderSpec, ctx: eve.builtin.lsp_action.ProviderContext }[]
  for _, provider in ipairs(providers) do
    local handler = provider.handler ---@type function
    local ok, result = pcall(handler, ctx)
    if not ok then
      std.reporter.error({
        from = __module_name__,
        subject = "collect_provider_actions",
        message = "Failed to execute LSP action provider.",
        details = {
          provider = provider.id,
          error = result,
        },
      })
    elseif result ~= nil then
      local items ---@type eve.builtin.lsp_action.ProviderAction[]
      if is_list(result) then
        items = result
      else
        items = { result }
      end
      for _, item in ipairs(items) do
        if type(item) == "table" and type(item.title) == "string" and type(item.execute) == "function" then
          local action = {
            title = item.title,
            kind = item.kind or "quickfix",
          }
          actions[#actions + 1] = {
            action = action,
            spec = item,
            provider = provider,
            ctx = ctx,
          }
        else
          std.reporter.warn({
            from = __module_name__,
            subject = "collect_provider_actions",
            message = "Ignoring invalid provider action.",
            details = {
              provider = provider.id,
              action = item,
            },
          })
        end
      end
    end
  end

  return actions
end

---@param opts                          table|nil
---@param context                       table
---@param bufnr                         integer
---@param win                           integer
---@param mode                          string
---@param lnum                          integer
---@param cursor                        { row: integer, col: integer }
---@return eve.builtin.lsp_action.ProviderContext
local function make_provider_context(opts, context, bufnr, win, mode, lnum, cursor)
  local selection ---@type { start: { line: integer, character: integer }, ["end"]: { line: integer, character: integer } }|nil
  if opts ~= nil and opts.range ~= nil then
    local start_pos = assert(opts.range.start, "range must have a `start` property")
    local end_pos = assert(opts.range["end"], "range must have an `end` property")
    selection = { start = start_pos, ["end"] = end_pos }
  elseif mode == "v" or mode == "V" or mode == "\22" then
    selection = range_from_selection(bufnr, mode)
  end

  return {
    bufnr = bufnr,
    win = win,
    mode = mode,
    lnum = lnum,
    cursor = cursor,
    selection = selection,
    opts = opts or {},
    context = context,
  }
end

---@param opts                          table|nil
---@return nil
local function custom_code_action(opts)
  opts = opts or {}
  local context = opts.context and vim.deepcopy(opts.context) or {}
  if not context.triggerKind then
    context.triggerKind = lsp.protocol.CodeActionTriggerKind.Invoked
  end

  local bufnr = api.nvim_get_current_buf()
  local win = api.nvim_get_current_win()
  local mode = api.nvim_get_mode().mode
  local cursor_pos = api.nvim_win_get_cursor(win)
  local lnum = cursor_pos[1] - 1

  local provider_ctx = make_provider_context(opts, context, bufnr, win, mode, lnum, {
    row = cursor_pos[1],
    col = cursor_pos[2],
  })
  local provider_actions = collect_provider_actions(provider_ctx)

  local clients = lsp.get_clients({ bufnr = bufnr, method = "textDocument/codeAction" })

  local function build_params(client)
    local params
    if provider_ctx.selection ~= nil then
      params = util.make_given_range_params(provider_ctx.selection.start, provider_ctx.selection["end"], bufnr, client.offset_encoding)
    else
      params = util.make_range_params(win, client.offset_encoding)
    end

    if context.diagnostics then
      params.context = context
    else
      local ns_pull = lsp.diagnostic.get_namespace(client.id, false)
      local ns_push = lsp.diagnostic.get_namespace(client.id, true)
      local diagnostics = {}
      vim.list_extend(diagnostics, vim.diagnostic.get(bufnr, { namespace = ns_pull, lnum = lnum }))
      vim.list_extend(diagnostics, vim.diagnostic.get(bufnr, { namespace = ns_push, lnum = lnum }))
      params.context = vim.tbl_extend("force", context, {
        diagnostics = vim.tbl_map(function(diagnostic)
          return diagnostic.user_data and diagnostic.user_data.lsp or diagnostic
        end, diagnostics),
      })
    end

    return params
  end

  local function apply_action(action, client, ctx)
    if action.edit then
      util.apply_workspace_edit(action.edit, client.offset_encoding)
    end
    local a_cmd = action.command
    if a_cmd then
      local command = type(a_cmd) == "table" and a_cmd or action
      client:exec_cmd(command, ctx)
    end
  end

  local function format_item(item)
    if item.__provider_action ~= nil then
      local action = item.__provider_action
      if action.spec.source or action.provider.source then
        local source = action.spec.source or action.provider.source ---@type string
        return ("%s [%s]"):format(action.action.title, source)
      end
      return action.action.title
    end

    local clients_for_buf = lsp.get_clients({ bufnr = item.ctx.bufnr })
    local title = item.action.title:gsub("\r\n", "\\r\\n"):gsub("\n", "\\n")

    if item.action.disabled then
      title = title .. " (disabled)"
    end

    if #clients_for_buf == 1 then
      return title
    end

    local source = lsp.get_client_by_id(item.ctx.client_id)
    if source == nil then
      return title
    end
    return ("%s [%s]"):format(title, source.name)
  end

  local function on_user_choice(choice)
    if not choice then
      return
    end

    if choice.__provider_action ~= nil then
      local spec = choice.__provider_action.spec ---@type eve.builtin.lsp_action.ProviderAction
      spec.execute(choice.__provider_action.ctx)
      return
    end

    local client = assert(lsp.get_client_by_id(choice.ctx.client_id))
    local action = choice.action

    if type(action.title) == "string" and type(action.command) == "string" then
      apply_action(action, client, choice.ctx)
      return
    end

    if action.disabled then
      vim.notify(action.disabled.reason, vim.log.levels.ERROR)
      return
    end

    if not (action.edit and action.command) and client:supports_method("codeAction/resolve") then
      client:request("codeAction/resolve", action, function(err, resolved_action)
        if err then
          if action.edit or action.command then
            apply_action(action, client, choice.ctx)
          else
            vim.notify(err.code .. ": " .. err.message, vim.log.levels.ERROR)
          end
        else
          apply_action(resolved_action, client, choice.ctx)
        end
      end, bufnr)
    else
      apply_action(action, client, choice.ctx)
    end
  end

  local function finish_with_actions(actions)
    if opts.apply and #actions == 1 then
      local single = actions[1]
      if single.__provider_action ~= nil then
        single.__provider_action.spec.execute(single.__provider_action.ctx)
        return
      end
      on_user_choice(single)
      return
    end

    vim.ui.select(actions, {
      prompt = "Code actions:",
      kind = "codeaction",
      format_item = format_item,
    }, on_user_choice)
  end

  local function process_results(results)
    ---@param action lsp.Command|lsp.CodeAction
    ---@param client_id integer
    local function action_filter(action, client_id)
      if opts and opts.context then
        if opts.context.only then
          if not action.kind then
            return false
          end
          local found = false
          for _, only_kind in ipairs(opts.context.only) do
            if action.kind == only_kind or vim.startswith(action.kind, only_kind .. ".") then
              found = true
              break
            end
          end
          if not found then
            return false
          end
        end
        if action.disabled and opts.context.triggerKind ~= lsp.protocol.CodeActionTriggerKind.Invoked then
          return false
        end
      end
      if opts and opts.filter and not opts.filter(action, client_id) then
        return false
      end
      return true
    end

    ---@type { action: lsp.Command|lsp.CodeAction, ctx: lsp.HandlerContext, __provider_action?: { action: lsp.CodeAction, spec: eve.builtin.lsp_action.ProviderAction, provider: eve.builtin.lsp_action.ProviderSpec, ctx: eve.builtin.lsp_action.ProviderContext } }[]
    local actions = {}
    for _, result in pairs(results) do
      for _, action in pairs(result.result or {}) do
        if action_filter(action, result.context.client_id) then
          table.insert(actions, { action = action, ctx = result.context })
        end
      end
    end

    for _, provider_action in ipairs(provider_actions) do
      if action_filter(provider_action.action, -1) then
        local include = true ---@type boolean
        if opts and opts.filter then
          local ok, filtered = pcall(opts.filter, provider_action.action, -1)
          include = ok and filtered
        end
        if include then
          actions[#actions + 1] = {
            action = provider_action.action,
            ctx = { bufnr = bufnr, client_id = -1 },
            __provider_action = provider_action,
          }
        end
      end
    end

    if #actions == 0 then
      vim.notify("No code actions available", vim.log.levels.INFO)
      return
    end

    finish_with_actions(actions)
  end

  if next(clients) then
    lsp.buf_request_all(bufnr, "textDocument/codeAction", build_params, process_results)
  else
    process_results({})
  end
end

---@class eve.builtin.lsp_action
local M = {}

---@param spec                          eve.builtin.lsp_action.ProviderSpec|fun(ctx: eve.builtin.lsp_action.ProviderContext): eve.builtin.lsp_action.ProviderAction|nil
---@return nil
function M.register(spec)
  if type(spec) == "function" then
    spec = { handler = spec }
  elseif type(spec) ~= "table" then
    error("LSP action provider spec must be a function or table.", 2)
  end

  if type(spec.handler) ~= "function" then
    error("LSP action provider spec must include a handler function.", 2)
  end

  providers[#providers + 1] = spec
end

---@return nil
function M.setup()
  if patched then
    return
  end

  original_code_action = original_code_action or vim.lsp.buf.code_action
  vim.lsp.buf.code_action = custom_code_action
  patched = true
end

---@return nil
function M.teardown()
  if not patched then
    return
  end

  vim.lsp.buf.code_action = original_code_action
  patched = false
end

return M

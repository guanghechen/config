---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.cmp.brackets" ---@type string

local editor = require("era.m.cmp.editor")
local M = {}
local pending = {} ---@type table<integer, fun(): nil>
local REQUEST_TIMEOUT = 400
local callable_kinds = { Function = true, Method = true } ---@type table<string, boolean>
local blocked_filetypes = {
  applescript = true,
  clojure = true,
  cpp = true,
  elixir = true,
  elm = true,
  fennel = true,
  janet = true,
  lisp = true,
  ["objective-c"] = true,
  objc = true,
  objcpp = true,
  nu = true,
  perl = true,
  prolog = true,
  ps1 = true,
  racket = true,
  ruby = true,
  rust = true,
  scheme = true,
  smalltalk = true,
  sql = true,
  vb = true,
} ---@type table<string, boolean>
local kind_blocked_filetypes = { javascriptreact = true, typescriptreact = true, vue = true }
local round_brackets = { "(", ")" } ---@type string[]
local space_brackets = { " ", "" } ---@type string[]
local square_brackets = { "[", "]" } ---@type string[]
local curly_brackets = { "{", "}" } ---@type string[]
local shapes = {
  bash = space_brackets,
  context = square_brackets,
  erlang = space_brackets,
  fish = space_brackets,
  fsharp = space_brackets,
  haskell = space_brackets,
  helm = space_brackets,
  lean = space_brackets,
  make = space_brackets,
  mathematica = square_brackets,
  mma = square_brackets,
  nix = space_brackets,
  ocaml = space_brackets,
  plaintex = curly_brackets,
  powershell = space_brackets,
  sh = space_brackets,
  shell = space_brackets,
  tcl = space_brackets,
  tex = curly_brackets,
  wl = square_brackets,
  wolfram = square_brackets,
  zsh = space_brackets,
} ---@type table<string, string[]>

---@param context                       ?era.m.cmp.IContext
---@param semantic                      boolean
---@return boolean
local function allowed(context, semantic)
  if context == nil then
    return not semantic
  end
  local filetype = context.filetype
  if
    blocked_filetypes[filetype]
    or semantic and filetype == "java"
    or not semantic and kind_blocked_filetypes[filetype]
  then
    return false
  end
  local line = context.line
  if filetype == "python" then
    return line:find("^%s*import%s") == nil and line:find("^%s*from%s") == nil and line:find("^%s*except%s") == nil
  end
  if filetype == "css" or filetype == "scss" or filetype == "less" or filetype == "html" then
    return line:sub(1, context.col):find("[%w_-]*::?[%w-]*$") == nil
  end
  if
    filetype == "javascript"
    or filetype == "javascriptreact"
    or filetype == "typescript"
    or filetype == "typescriptreact"
    or filetype == "svelte"
  then
    return line:find("^%s*import%s") == nil
  end
  return true
end

---@param snippet                       string
---@return integer
local function next_placeholder(snippet)
  local highest = 0
  for number in snippet:gmatch("%${(%d+)") do
    highest = math.max(highest, tonumber(number) or 0)
  end
  for number in snippet:gmatch("%$(%d+)") do
    highest = math.max(highest, tonumber(number) or 0)
  end
  return highest + 1
end

---@param item                          era.m.cmp.ICompletionItem
---@return nil
function M.prepare(item)
  local callable = callable_kinds[vim.lsp.protocol.CompletionItemKind[item.kind]] == true
  if not callable then
    return
  end
  local origin = item._era_cmp_origin
  local context = origin and origin.context or nil
  local brackets = context and shapes[context.filetype] or round_brackets
  brackets = brackets or round_brackets
  local opening, closing = unpack(brackets)
  local text = item.textEdit and item.textEdit.newText or item.insertText or item.label
  if type(text) ~= "string" then
    return
  end
  local trailing = context and context.line:sub(context.col + (origin.suffix_bytes or 0) + 1) or ""
  local existing = opening == " " and trailing:match("^%s") or trailing:match("^%s*" .. vim.pesc(opening))
  local bracket = text:find(opening, 1, true)
  local final_tabstop = item.insertTextFormat == vim.lsp.protocol.InsertTextFormat.Snippet
    and (text:find("$0", 1, true) ~= nil or text:find("${0", 1, true) ~= nil)
  if existing ~= nil then
    item._era_cmp_cursor_offset = vim.fn.strchars(existing, true)
    if bracket ~= nil and opening ~= " " then
      text = text:sub(1, bracket - 1)
    end
  elseif bracket == nil and not final_tabstop then
    if allowed(context, false) then
      if item.insertTextFormat == vim.lsp.protocol.InsertTextFormat.Snippet then
        text = text .. opening .. "$" .. next_placeholder(text) .. closing
      elseif closing == "" then
        text = text .. opening
      else
        text = text:gsub("\\", "\\\\"):gsub("%$", "\\$"):gsub("}", "\\}") .. opening .. "$0" .. closing
        item.insertTextFormat = vim.lsp.protocol.InsertTextFormat.Snippet
      end
    end
  end
  if item.textEdit ~= nil then
    item.textEdit.newText = text
  else
    item.insertText = text
  end
end

---@param bufnr                         integer
---@return nil
function M.cancel(bufnr)
  local cancel = pending[bufnr]
  if cancel ~= nil then
    cancel()
  end
end

---@param item                          era.m.cmp.ICompletionItem
---@param applied                       era.m.cmp.editor.IApplied
---@param completed                     table
---@param on_added                      ?fun(): nil
---@return nil
function M.request(item, applied, completed, on_added)
  local bufnr = applied.bufnr
  M.cancel(bufnr)
  local origin = item._era_cmp_origin
  if
    origin == nil
    or applied.cursor_offset ~= 0
    or applied.text == ""
    or applied.text:find("\n", 1, true)
    or vim.snippet.active()
  then
    return
  end
  local semantic_tokens = package.loaded["vim.lsp.semantic_tokens"]
  if type(semantic_tokens) ~= "table" then
    return
  end
  local highlighter = semantic_tokens.__STHighlighter.active[bufnr]
  if highlighter == nil or highlighter.client_state[origin.client_id] == nil then
    return
  end
  local context = origin.context
  if not allowed(context, true) then
    return
  end
  local brackets = shapes[context.filetype] or round_brackets
  local text = item.textEdit and item.textEdit.newText or item.insertText or item.label
  local trailing = context.line:sub(context.col + (origin.suffix_bytes or 0) + 1)
  if
    text:find(brackets[1], 1, true)
    or trailing:match("^%s*" .. vim.pesc(brackets[1]))
    or item.insertTextFormat == vim.lsp.protocol.InsertTextFormat.Snippet
      and (text:find("$0", 1, true) or text:find("${0", 1, true))
  then
    return
  end
  local winnr = vim.api.nvim_get_current_win()
  local cursor = vim.api.nvim_win_get_cursor(winnr)
  local changedtick = vim.api.nvim_buf_get_changedtick(bufnr)
  local line = vim.api.nvim_get_current_line()
  if cursor[2] < #applied.text or line:sub(cursor[2] - #applied.text + 1, cursor[2]) ~= applied.text then
    return
  end
  local timer = nil ---@type uv.uv_timer_t|nil
  local autocmd = nil ---@type integer|nil
  local queued = false
  ---@return nil
  local function cancel()
    if pending[bufnr] == cancel then
      pending[bufnr] = nil
    end
    if timer ~= nil and not timer:is_closing() then
      timer:stop()
      timer:close()
    end
    if autocmd ~= nil then
      pcall(vim.api.nvim_del_autocmd, autocmd)
      autocmd = nil
    end
  end
  ---@return boolean
  local function current()
    return pending[bufnr] == cancel
      and vim.api.nvim_buf_is_valid(bufnr)
      and vim.api.nvim_get_current_buf() == bufnr
      and vim.api.nvim_get_current_win() == winnr
      and vim.api.nvim_get_mode().mode:match("^i") ~= nil
      and vim.api.nvim_get_option_value("filetype", { buf = bufnr }) == context.filetype
      and not vim.snippet.active()
      and vim.api.nvim_buf_get_changedtick(bufnr) == changedtick
      and vim.deep_equal(vim.api.nvim_win_get_cursor(winnr), cursor)
      and semantic_tokens.__STHighlighter.active[bufnr] == highlighter
  end
  ---@return nil
  local function process()
    queued = false
    if not current() then
      cancel()
      return
    end
    local state = highlighter.client_state[origin.client_id]
    if
      state == nil
      or state.current_result.version ~= changedtick
      or state.current_result.version ~= vim.lsp.util.buf_versions[bufnr]
    then
      return
    end
    local tokens = semantic_tokens.get_at_pos(bufnr, cursor[1] - 1, cursor[2] - 1) or {}
    for _, token in ipairs(tokens) do
      if
        token.client_id == origin.client_id
        and (token.type == "function" or token.type == "method")
        and token.line == cursor[1] - 1
        and token.end_line == token.line
        and token.end_col == cursor[2]
      then
        cancel()
        local ok, err = xpcall(function()
          local extended = editor.extend(applied, brackets[1] .. brackets[2], -vim.fn.strchars(brackets[2], true))
          local recorded, record_error = editor.record(extended, completed)
          if not recorded and record_error ~= nil then
            error(record_error, 0)
          end
          if on_added ~= nil then
            on_added()
          end
        end, debug.traceback)
        if not ok then
          stl.reporter.warn({
            from = __module_name__,
            subject = "apply",
            message = "Failed to add semantic completion brackets.",
            details = err,
          })
        end
        return
      end
    end
  end
  pending[bufnr] = cancel
  process()
  if pending[bufnr] ~= cancel then
    return
  end
  autocmd = vim.api.nvim_create_autocmd("LspTokenUpdate", {
    buffer = bufnr,
    callback = function(args)
      local token = args.data.token
      if
        not queued
        and args.data.client_id == origin.client_id
        and token.line == cursor[1] - 1
        and token.end_col == cursor[2]
        and (token.type == "function" or token.type == "method")
      then
        queued = true
        vim.schedule(process)
      end
    end,
  })
  timer = vim.defer_fn(cancel, REQUEST_TIMEOUT)
  local sent, send_error = xpcall(highlighter.send_request, debug.traceback, highlighter)
  if not sent then
    cancel()
    stl.reporter.warn({
      from = __module_name__,
      subject = "request",
      message = "Failed to refresh semantic tokens for completion.",
      details = send_error,
    })
  end
end

return M

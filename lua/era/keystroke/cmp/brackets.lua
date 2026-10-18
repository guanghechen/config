---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.keystroke.cmp.brackets" ---@type string

local Edit = require("era.keystroke.cmp.edit")
local M = {}
local BLOCKED_KIND = { typescriptreact = true, javascriptreact = true, vue = true }
local BLOCKED_FILETYPES = {
  sql = true,
  ruby = true,
  perl = true,
  lisp = true,
  scheme = true,
  clojure = true,
  prolog = true,
  vb = true,
  elixir = true,
  smalltalk = true,
  applescript = true,
  elm = true,
  rust = true,
  nu = true,
  cpp = true,
  fennel = true,
  janet = true,
  ps1 = true,
  racket = true,
  objc = true,
  objcpp = true,
}
local BRACKETS_BY_FILETYPE = {
  haskell = { " ", "" },
  fsharp = { " ", "" },
  ocaml = { " ", "" },
  erlang = { " ", "" },
  tcl = { " ", "" },
  nix = { " ", "" },
  helm = { " ", "" },
  lean = { " ", "" },
  shell = { " ", "" },
  sh = { " ", "" },
  bash = { " ", "" },
  fish = { " ", "" },
  zsh = { " ", "" },
  powershell = { " ", "" },
  make = { " ", "" },
  wl = { "[", "]" },
  wolfram = { "[", "]" },
  mma = { "[", "]" },
  mathematica = { "[", "]" },
  context = { "[", "]" },
  tex = { "{", "}" },
  plaintex = { "{", "}" },
}
local IMPORT_FILETYPES = {
  javascript = true,
  javascriptreact = true,
  typescript = true,
  typescriptreact = true,
  svelte = true,
}
local SELECTOR_FILETYPES = { css = true, scss = true, less = true, html = true }

---@param filetype                      string
---@return string, string
local function delimiters(filetype)
  local pair = BRACKETS_BY_FILETYPE[filetype]
  if pair ~= nil then
    return pair[1], pair[2]
  end
  return "(", ")"
end

---@param context                       era.keystroke.cmp.IContext
---@return boolean
local function eligible(context)
  local filetype = context.filetype
  if BLOCKED_FILETYPES[filetype] then
    return false
  end
  if filetype == "python" then
    return not context.line:find("^%s*import%s")
      and not context.line:find("^%s*from%s")
      and not context.line:find("^%s*except%s")
  end
  if IMPORT_FILETYPES[filetype] then
    return not context.line:find("^%s*import%s")
  end
  if SELECTOR_FILETYPES[filetype] then
    return not context.line:sub(1, context.col):find("[%w_-]*::?[%w-]*$")
  end
  return true
end

---@param context                       era.keystroke.cmp.IContext
---@param raw                           lsp.CompletionItem
---@param plan                          era.keystroke.cmp.IEditPlan
---@return nil
function M.prepare(context, raw, plan)
  local opening, closing = delimiters(context.filetype)
  local callable = raw.kind == vim.lsp.protocol.CompletionItemKind.Function
    or raw.kind == vim.lsp.protocol.CompletionItemKind.Method
  local right = context.line:sub(plan.main.range["end"].character + 1)
  if right:sub(1, #opening) == opening then
    plan.cursor_offset = callable and not plan.snippet and #opening or 0
    return
  end
  if opening ~= " " and (plan.main.newText:find(opening, 1, true) or plan.main.newText:find("\\", 1, true)) then
    return
  end
  if not eligible(context) then
    return
  end
  if not callable or BLOCKED_KIND[context.filetype] then
    plan.semantic_brackets = context.filetype ~= "java" and raw.kind ~= vim.lsp.protocol.CompletionItemKind.Snippet
    return
  end
  if plan.snippet then
    local last = 0
    for index in plan.main.newText:gmatch("%$%{?(%d+)") do
      last = math.max(last, tonumber(index))
    end
    plan.main.newText = plan.main.newText .. opening .. "$" .. (last + 1) .. closing
  else
    plan.main.newText = plan.main.newText .. opening .. closing
    plan.cursor_offset = -#closing
  end
end

---@param context                       era.keystroke.cmp.IContext
---@param client_id                     integer
---@param callback                      fun(opening: string, closing: string): nil
---@return fun(): nil
function M.watch(context, client_id, callback)
  if context.filetype == "java" or not eligible(context) then
    return function() end
  end
  local client = vim.lsp.get_client_by_id(client_id)
  if client == nil or type(client.server_capabilities.semanticTokensProvider) ~= "table" then
    return function() end
  end
  local opening, closing = delimiters(context.filetype)
  local done = false
  local autocmd
  local timer = assert(vim.uv.new_timer())

  ---@return nil
  local function cancel()
    if done then
      return
    end
    done = true
    timer:stop()
    timer:close()
    if autocmd ~= nil then
      vim.api.nvim_del_autocmd(autocmd)
      autocmd = nil
    end
  end

  ---@return nil
  local function inspect()
    if done then
      return
    end
    if not Edit.is_current(context) then
      cancel()
      return
    end
    for _, token in
      ipairs(vim.lsp.semantic_tokens.get_at_pos(context.bufnr, context.row, math.max(0, context.col - 1)) or {})
    do
      if token.client_id == client_id and (token.type == "function" or token.type == "method") then
        cancel()
        callback(opening, closing)
        return
      end
    end
  end

  autocmd =
    vim.api.nvim_create_autocmd("LspTokenUpdate", { buf = context.bufnr, callback = vim.schedule_wrap(inspect) })
  timer:start(400, 0, vim.schedule_wrap(cancel))
  inspect()
  if not done then
    vim.lsp.semantic_tokens.force_refresh(context.bufnr)
  end
  return cancel
end

return M

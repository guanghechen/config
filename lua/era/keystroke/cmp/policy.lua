---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.keystroke.cmp.policy" ---@type string

local Context = require("era.keystroke.cmp.context")
local Path = require("era.keystroke.cmp.source.path")
local M = {}
M.buffer_parents = { "lsp", "path" }
local code_sources = { "lsp", "path", "snippets", "buffer", "dict" }
local markdown_sources = { "slash", "lsp", "path", "snippets", "buffer", "dict" }
local code_filetypes = {}
for _, filetype in ipairs(stl.filetype.list_code_filetypes()) do
  code_filetypes[filetype] = true
end

---@param context                       era.keystroke.cmp.IContext
---@return boolean
local function trigger_character(context)
  local character = context.line:sub(context.col, context.col)
  if character == "" or character:match("%s") or character:match("%a") then
    return false
  end
  if (context.trigger == "enter" or context.trigger == "accept") and ([["'({[]]):find(character, 1, true) ~= nil then
    return false
  end
  if character == "/" or character == "@" or character == "\\" or character == "." then
    return true
  end
  for _, client in ipairs(vim.lsp.get_clients({ bufnr = context.bufnr, method = "textDocument/completion" })) do
    local provider = client.server_capabilities.completionProvider
    if
      type(provider) == "table"
      and type(provider.triggerCharacters) == "table"
      and vim.list_contains(provider.triggerCharacters, character)
    then
      return true
    end
  end
  return false
end

---@param context                       era.keystroke.cmp.IContext
---@param previous                      ?era.keystroke.cmp.IContext
---@return boolean
local function should_trigger(context, previous)
  if context.trigger == "backspace" then
    return true
  end
  if context.trigger == "typing" then
    return context.keyword ~= "" or context.line:sub(context.col, context.col) == "-" or trigger_character(context)
  end
  if context.trigger == "enter" or context.trigger == "accept" then
    return trigger_character(context)
  end
  return previous ~= nil and Context.within_query(previous, context, trigger_character(context))
end

---@param context                       era.keystroke.cmp.IContext
---@param manual                        boolean
---@param previous                      ?era.keystroke.cmp.IContext
---@return string[]
function M.sources_for(context, manual, previous)
  if not manual and not should_trigger(context, previous) then
    return {}
  end
  local filetype = context.filetype
  local names
  if filetype == "markdown" or filetype == stl.filetype.NOTEPAD then
    names = markdown_sources
  elseif code_filetypes[filetype] then
    names = code_sources
  else
    names = { "path", "buffer" }
  end
  local target = Path.target(context)
  if target ~= nil and target.source == "path_at" then
    names = vim.list_extend({}, names)
    for index, name in ipairs(names) do
      if name == "path" then
        names[index] = "path_at"
      end
    end
  end
  return names
end

return M

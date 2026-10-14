---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.keystroke.cmp.source.snippets" ---@type string

local Item = require("era.keystroke.cmp.item")
local registry ---@type table<string, string[]>|nil
local loaded = {} ---@type table<string, table[]>
local M = {}

---@param path                          string
---@return table|nil
local function read_json(path)
  local file = io.open(path, "r")
  if file == nil then
    return nil
  end
  local content = file:read("*a")
  file:close()
  local ok, value = pcall(vim.json.decode, content)
  if not ok or type(value) ~= "table" then
    stl.reporter.warn({ from = __module_name__, subject = "load snippets", message = "Invalid snippet JSON: " .. path })
    return nil
  end
  return value
end

---@return table<string, string[]>
local function get_registry()
  if registry ~= nil then
    return registry
  end
  era.m.plugin.load("friendly-snippets")
  registry = {}
  local roots = { dot.path.join(vim.fn.stdpath("config"), "snippets") }
  for _, path in ipairs(vim.api.nvim_list_runtime_paths()) do
    if path:match("friendly.snippets$") then
      roots[#roots + 1] = path
    end
  end
  for _, root in ipairs(roots) do
    local package = read_json(dot.path.join(root, "package.json"))
    local entries = package and package.contributes and package.contributes.snippets or nil
    if type(entries) == "table" then
      for _, entry in ipairs(entries) do
        local languages = type(entry.language) == "table" and entry.language or { entry.language }
        for _, language in ipairs(languages) do
          registry[language] = registry[language] or {}
          registry[language][#registry[language] + 1] = dot.path.join(root, entry.path)
        end
      end
    else
      for _, path in ipairs(vim.fn.globpath(root, "**/*.json", false, true)) do
        local filetype = path:match("([^/\\]+)%.json$")
        if filetype ~= nil and filetype ~= "package" then
          registry[filetype] = registry[filetype] or {}
          registry[filetype][#registry[filetype] + 1] = path
        end
      end
    end
  end
  return registry
end

---@param filetype                      string
---@return table[]
local function snippets_for(filetype)
  if loaded[filetype] ~= nil then
    return loaded[filetype]
  end
  local snippets = {}
  for _, path in ipairs(get_registry()[filetype] or {}) do
    for name, value in pairs(read_json(path) or {}) do
      if type(value) == "table" then
        local prefixes = type(value.prefix) == "table" and value.prefix or { value.prefix or name }
        local body = type(value.body) == "table" and table.concat(value.body, "\n") or value.body
        local description = type(value.description) == "table" and table.concat(value.description, "\n")
          or value.description
          or name
        if type(body) == "string" then
          for _, prefix in ipairs(prefixes) do
            if type(prefix) == "string" then
              snippets[#snippets + 1] = { prefix = prefix, body = body, description = description }
            end
          end
        end
      end
    end
  end
  table.sort(snippets, function(a, b)
    return a.prefix < b.prefix or (a.prefix == b.prefix and a.body < b.body)
  end)
  loaded[filetype] = snippets
  return snippets
end

---@param context                       era.keystroke.cmp.IContext
---@param callback                      fun(response: era.keystroke.cmp.IResponse): nil
---@return nil
function M.complete(context, callback)
  local items = {} ---@type era.keystroke.cmp.IItem[]
  local filetypes = { "all", context.filetype }
  for _, filetype in ipairs(filetypes) do
    for _, snippet in ipairs(snippets_for(filetype)) do
      local start_col = context.start_col
      for length = math.min(#snippet.prefix, context.col), 1, -1 do
        if context.line:sub(context.col - length + 1, context.col) == snippet.prefix:sub(1, length) then
          start_col = context.col - length
          break
        end
      end
      items[#items + 1] = Item.new(context, "snippets", {
        label = snippet.prefix,
        kind = vim.lsp.protocol.CompletionItemKind.Snippet,
        insertTextFormat = vim.lsp.protocol.InsertTextFormat.Snippet,
        textEdit = Item.text_edit(context, start_col, snippet.body),
        documentation = { kind = "markdown", value = snippet.description },
      })
    end
  end
  callback({ items = items, incomplete = false })
end

return M

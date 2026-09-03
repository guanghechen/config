---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.cmp.trigger" ---@type string

local snippets = require("era.m.cmp.source.snippets")

local keyword = vim.regex([[\k]])
local blocked = { [" "] = true, ["\n"] = true, ["\t"] = true } ---@type table<string, boolean>

---@class era.m.cmp.trigger
local M = {}

---@param char                          string
---@return boolean
local function is_keyword(char)
  return char == "-" or keyword:match_str(char) ~= nil
end

---@param bufnr                         integer
---@return table<string, boolean>
function M.characters(bufnr)
  local characters = { ["/"] = true, ["@"] = true } ---@type table<string, boolean>
  local filetype = vim.api.nvim_get_option_value("filetype", { buf = bufnr }) ---@type string
  for char in pairs(snippets.trigger_characters(filetype)) do
    characters[char] = true
  end
  for _, client in ipairs(vim.lsp.get_clients({ bufnr = bufnr, method = "textDocument/completion" })) do
    local triggers = vim.tbl_get(client.server_capabilities or {}, "completionProvider", "triggerCharacters") or {}
    for _, char in ipairs(triggers) do
      characters[char] = true
    end
  end
  return characters
end

---@param char                          string
---@param characters                    table<string, boolean>|fun(): table<string, boolean>
---@return "keyword"|"trigger_character"|nil
function M.classify(char, characters)
  if type(char) ~= "string" or char == "" or blocked[char] then
    return nil
  end
  if is_keyword(char) then
    return "keyword"
  end
  local resolved ---@type table<string, boolean>
  if type(characters) == "function" then
    resolved = characters()
  else
    resolved = characters
  end
  if resolved[char] then
    return "trigger_character"
  end
  return nil
end

return M

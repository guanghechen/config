---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.cmp.source.dict" ---@type string

local util = require("era.m.cmp.source.util")

local M = {}

local function expand_indices(results, limit)
  local output = {} ---@type integer[]
  if type(results) ~= "table" then
    return output
  end

  for _, result in ipairs(results) do
    if result.type == "scalar" then
      for _, index in ipairs(result.indexes or {}) do
        output[#output + 1] = math.floor(index + 0.5)
        if #output >= limit then
          return output
        end
      end
    elseif result.type == "segment" then
      local indexes = result.indexes or {}
      for offset = 1, #indexes, 2 do
        local first = indexes[offset]
        local last = indexes[offset + 1]
        if type(first) ~= "number" or type(last) ~= "number" then
          break
        end
        for index = math.floor(first + 0.5), math.floor(last + 0.5) - 1 do
          output[#output + 1] = index
          if #output >= limit then
            return output
          end
        end
      end
    end
  end
  return output
end

local function apply_case(prefix, value)
  if not value:match("^[%l%-%']+$") then
    return value
  end
  if prefix:match("^%u%u") then
    return value:upper()
  end
  if prefix:match("^%u") then
    return value:sub(1, 1):upper() .. value:sub(2)
  end
  return value
end

---@param context                       era.m.cmp.IContext
---@return lsp.CompletionItem[]
function M.complete(context)
  if #context.keyword < 3 then
    return {}
  end

  local ok, results = pcall(yoz.dict.search, {
    keyword = context.keyword,
    language = "en",
    match_mode = "prefix",
    include_compounds = false,
    max_items = 20,
  })
  if not ok then
    stl.reporter.error({
      from = __module_name__,
      subject = "complete",
      message = "Failed to search dictionary completion items.",
      details = results,
    })
    return {}
  end

  local items = {} ---@type lsp.CompletionItem[]
  for _, index in ipairs(expand_indices(results, 20)) do
    local entry = stl.dict.en[index] ---@type { [1]: string, [2]: string }|nil
    if entry ~= nil then
      local word = apply_case(context.keyword, entry[1]) ---@type string
      items[#items + 1] = util.item("dict", 95, {
        label = word,
        kind = vim.lsp.protocol.CompletionItemKind.Text,
        filterText = entry[1],
        sortText = entry[1],
        documentation = { kind = "plaintext", value = entry[2] },
        insertTextFormat = vim.lsp.protocol.InsertTextFormat.PlainText,
        textEdit = {
          newText = word,
          range = util.range(context, context.start_col, context.end_col),
        },
      }, "dict\0" .. word)
    end
  end
  return util.filter(context.keyword, items)
end

return M

---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.keystroke.cmp.source.dict" ---@type string

local Item = require("era.keystroke.cmp.item")
local M = {}

---@param context                       era.keystroke.cmp.IContext
---@param callback                      fun(response: era.keystroke.cmp.IResponse): nil
---@return nil
function M.complete(context, callback)
  local keyword = context.keyword
  if #keyword < 3 or not keyword:match("^[A-Za-z]+$") then
    callback({ items = {}, incomplete = true })
    return
  end
  local results = yoz.dict.search({
    keyword = keyword,
    language = "en",
    match_mode = "prefix",
    include_compounds = false,
    max_items = 20,
  })
  local entries = stl.dict.en
  local items = {} ---@type era.keystroke.cmp.IItem[]

  ---@param index                       integer
  ---@return nil
  local function append(index)
    local entry = entries[index]
    if entry == nil or #items >= 20 then
      return
    end
    local word = entry[1]
    if keyword:match("^%u%u") then
      word = word:upper()
    elseif keyword:match("^%u") then
      word = word:sub(1, 1):upper() .. word:sub(2)
    end
    items[#items + 1] = Item.new(context, "dict", {
      label = word,
      filterText = entry[1],
      kind = vim.lsp.protocol.CompletionItemKind.Text,
      textEdit = Item.text_edit(context, context.start_col, word),
      documentation = { kind = "plaintext", value = entry[2] },
    })
  end

  for _, result in ipairs(results) do
    if result.type == "scalar" then
      for _, index in ipairs(result.indexes) do
        append(index)
      end
    elseif result.type == "segment" then
      for i = 1, #result.indexes, 2 do
        for index = result.indexes[i], result.indexes[i + 1] - 1 do
          append(index)
          if #items >= 20 then
            break
          end
        end
      end
    end
  end
  -- The dictionary caps results, so a longer prefix can expose previously omitted words.
  callback({ items = items, incomplete = true })
end

return M

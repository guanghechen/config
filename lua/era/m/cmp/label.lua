---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.cmp.label" ---@type string

local MAX_CACHE_SIZE = 1000
local MATCH_PRIORITY = 150
local SEMANTIC_PRIORITY = 100

local cache = {} ---@type table<string, era.m.ui_attach.popupmenu.ILabelHighlight[]>
local cache_size = 0

---@class era.m.cmp.label
local M = {}

---@param value                         string
---@return string
function M.display(value)
  return (value:gsub("\r\n?", "\n"):gsub("\n", "↲"))
end

---@param item                          era.m.cmp.ICompletionItem
---@return boolean
function M.is_deprecated(item)
  return item.deprecated == true or vim.list_contains(item.tags or {}, vim.lsp.protocol.CompletionTag.Deprecated)
end

---@param filetype                      string
---@param label                         string
---@return era.m.ui_attach.popupmenu.ILabelHighlight[]
local function collect_semantic(filetype, label)
  local lang = vim.treesitter.language.get_lang(filetype) ---@type string|nil
  if lang == nil then
    return {}
  end

  local parser = vim.treesitter.get_string_parser(label, lang)
  parser:parse(true)

  local highlights = {} ---@type era.m.ui_attach.popupmenu.ILabelHighlight[]
  parser:for_each_tree(function(tree, language_tree)
    if tree == nil then
      return
    end
    local query = vim.treesitter.query.get(language_tree:lang(), "highlights")
    if query == nil then
      return
    end
    for capture, node in query:iter_captures(tree:root(), label) do
      local name = query.captures[capture] ---@type string
      if name ~= "spell" then
        local _, start_col, _, end_col = node:range()
        if end_col > start_col then
          highlights[#highlights + 1] = { start_col, end_col, "@" .. name .. "." .. lang, SEMANTIC_PRIORITY }
        end
      end
    end
  end)
  return highlights
end

---@param filetype                      string
---@param labels                        string[]
---@return table<string, era.m.ui_attach.popupmenu.ILabelHighlight[]>
local function semantics(filetype, labels)
  local values = {} ---@type table<string, era.m.ui_attach.popupmenu.ILabelHighlight[]>
  for _, label in ipairs(labels) do
    local key = filetype .. "\0" .. label ---@type string
    local highlights = cache[key]
    if highlights == nil then
      if cache_size >= MAX_CACHE_SIZE then
        cache = {}
        cache_size = 0
      end
      local ok, value = pcall(collect_semantic, filetype, label)
      highlights = ok and value or {}
      cache[key] = highlights
      cache_size = cache_size + 1
    end
    values[label] = highlights
  end
  return values
end

---@param matched_ranges                integer[][]
---@return era.m.ui_attach.popupmenu.ILabelHighlight[][] label-relative projections
function M.matches(matched_ranges)
  local projected = {} ---@type era.m.ui_attach.popupmenu.ILabelHighlight[][]
  for item_index, ranges in ipairs(matched_ranges) do
    local highlights = {} ---@type era.m.ui_attach.popupmenu.ILabelHighlight[]
    for range_index = 1, #ranges, 2 do
      local start_col = ranges[range_index]
      local end_col = ranges[range_index + 1]
      if end_col ~= nil and end_col > start_col then
        highlights[#highlights + 1] = { start_col, end_col, "PmenuMatch", MATCH_PRIORITY }
      end
    end
    projected[item_index] = highlights
  end
  return projected
end

---@param filetype                      string
---@param items                         era.m.cmp.ICompletionItem[]
---@param matched_ranges                integer[][]
---@param labels                        string[]|nil display labels
---@return era.m.ui_attach.popupmenu.ILabelHighlight[][] label-relative projections
---@return (fun(indices: integer[]): table<integer, era.m.ui_attach.popupmenu.ILabelHighlight[]>)|nil
function M.project(filetype, items, matched_ranges, labels)
  local semantic_labels = {} ---@type table<integer, string>
  local has_semantic = false
  for index, item in ipairs(items) do
    if item._era_cmp_origin ~= nil and not M.is_deprecated(item) then
      semantic_labels[index] = labels and labels[index] or M.display(item.label)
      has_semantic = true
    end
  end
  local projected = M.matches(matched_ranges)
  if not has_semantic then
    return projected, nil
  end
  return projected,
    function(indices)
      local labels = {} ---@type string[]
      for _, index in ipairs(indices) do
        local label = semantic_labels[index]
        if label ~= nil then
          labels[#labels + 1] = label
        end
      end
      local semantic_by_label = semantics(filetype, labels)
      local resolved = {} ---@type table<integer, era.m.ui_attach.popupmenu.ILabelHighlight[]>
      for _, index in ipairs(indices) do
        local label = semantic_labels[index]
        if label ~= nil then
          resolved[index] = semantic_by_label[label] or {}
        end
      end
      return resolved
    end
end

return M

---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.textobject.treesitter" ---@type string

local M = {}

---@param nodes                         TSNode[]
---@param bufnr                         integer
---@param metadata                      table|nil
---@param lang                          string
---@return era.m.textobject.Range
local function node_range(nodes, bufnr, metadata, lang)
  local first, last = nil, nil ---@type integer[]|nil, integer[]|nil
  for _, node in ipairs(nodes) do
    local range = vim.treesitter.get_range(node, bufnr, metadata) ---@type integer[]
    if first == nil or range[3] < first[3] then
      first = range
    end
    if last == nil or range[6] > last[6] then
      last = range
    end
  end
  assert(first ~= nil and last ~= nil)
  local parent = nodes[1]:parent() ---@type TSNode|nil
  while parent ~= nil do
    local _, _, from, _, _, to = parent:range(true)
    if from <= first[3] and last[6] <= to then
      break
    end
    parent = parent:parent()
  end
  local container = parent and (lang .. ":" .. tostring(parent:id())) or nil ---@type string|nil
  return { first[1], first[2], last[4], last[5], container = container }
end

---@param lang_tree                     vim.treesitter.LanguageTree
---@param bufnr                         integer
---@param captures                      table<string, true>
---@param group                         string
---@param rows                          ?integer[] Start row and exclusive end row
---@return era.m.textobject.Range[]
---@return string|nil
local function collect(lang_tree, bufnr, captures, group, rows)
  local lang = lang_tree:lang() ---@type string
  local ok, query = pcall(vim.treesitter.query.get, lang, group)
  if not ok then
    return {}, string.format("Invalid %s query for %s: %s", group, lang, query)
  end
  if query == nil then
    return {}, string.format("No %s query for %s", group, lang)
  end

  local result = {} ---@type era.m.textobject.Range[]
  local seen = {} ---@type table<string, true>
  for _, tree in ipairs(lang_tree:trees()) do
    for _, match, metadata in query:iter_matches(tree:root(), bufnr, rows and rows[1] or 0, rows and rows[2] or -1) do
      for capture_id, nodes in pairs(match) do
        if captures[query.captures[capture_id]] and #nodes > 0 then
          local range = node_range(nodes, bufnr, metadata[capture_id], lang)
          range.capture = query.captures[capture_id]
          local key = table.concat({ range.capture, range[1], range[2], range[3], range[4] }, ":") ---@type string
          if not seen[key] then
            seen[key] = true
            result[#result + 1] = range
          end
        end
      end
    end
  end
  return result, nil
end

---Use the language at the cursor, then its ancestors, then other injected languages.
---@param bufnr                         integer
---@param names                         string[]
---@param group                         string
---@param position                      integer[] Zero-based row and byte column
---@param rows                          ?integer[] Start row and exclusive end row
---@return era.m.textobject.Range[]
---@return string|nil
---@return boolean Whether the selected language was searched in full
function M.ranges(bufnr, names, group, position, rows)
  local ok, parser = pcall(vim.treesitter.get_parser, bufnr, nil, { error = false })
  if not ok or parser == nil then
    local filetype = vim.api.nvim_get_option_value("filetype", { buf = bufnr }) ---@type string
    return {}, string.format("No Tree-sitter parser for %s", filetype == "" and "this buffer" or filetype), true
  end
  parser:parse(true)

  local captures = {} ---@type table<string, true>
  for _, name in ipairs(names) do
    captures[name:gsub("^@", "")] = true
  end
  local active = parser:language_for_range({ position[1], position[2], position[1], position[2] })
  local current = active ---@type vim.treesitter.LanguageTree|nil
  local reason = nil ---@type string|nil
  local searched = {} ---@type table<vim.treesitter.LanguageTree, true>
  while current ~= nil do
    searched[current] = true
    local ranges, err = collect(current, bufnr, captures, group, rows)
    local complete = rows == nil ---@type boolean
    -- A distant match in this language still takes priority over an ancestor language.
    if #ranges == 0 and rows ~= nil then
      ranges, err = collect(current, bufnr, captures, group)
      complete = true
    end
    if #ranges > 0 then
      return ranges, nil, complete
    end
    reason = reason or err
    current = current:parent()
  end

  local ranges = {} ---@type era.m.textobject.Range[]
  ---@param parent                      vim.treesitter.LanguageTree
  ---@return nil
  local function collect_children(parent)
    for _, child in pairs(parent:children()) do
      if not searched[child] then
        local child_ranges = collect(child, bufnr, captures, group)
        vim.list_extend(ranges, child_ranges)
      end
      collect_children(child)
    end
  end
  -- Sibling injections are reachable from the root, including from Markdown prose.
  collect_children(parser)
  return ranges, #ranges == 0 and reason or nil, true
end

return M

---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.keystroke.cmp.snippet" ---@type string

local M = {}
local closing = { ["("] = ")", ["["] = "]", ["{"] = "}", ["<"] = ">", ['"'] = '"', ["'"] = "'" }
local date_formats = {
  CURRENT_YEAR = "%Y",
  CURRENT_YEAR_SHORT = "%y",
  CURRENT_MONTH = "%m",
  CURRENT_MONTH_NAME = "%B",
  CURRENT_MONTH_NAME_SHORT = "%b",
  CURRENT_DATE = "%d",
  CURRENT_DAY_NAME = "%A",
  CURRENT_DAY_NAME_SHORT = "%a",
  CURRENT_HOUR = "%H",
  CURRENT_MINUTE = "%M",
  CURRENT_SECOND = "%S",
}

---@param node                          vim.snippet.Node<any>
---@return string
---@return boolean complete
local function static_text(node)
  local types = vim.lsp._snippet_grammar.NodeType
  if node.type == types.Variable then
    return "", false
  elseif node.type == types.Placeholder then
    return static_text(node.data.value)
  elseif node.type == types.Snippet then
    local parts = {}
    for _, child in ipairs(node.data.children) do
      local text, complete = static_text(child)
      parts[#parts + 1] = text
      if not complete then
        return table.concat(parts), false
      end
    end
    return table.concat(parts), true
  end
  return tostring(node), true
end

---@param body                          string
---@param label                         string
---@return string
function M.preview_word(body, label)
  local ok, parsed = pcall(vim.lsp._snippet_grammar.parse, body)
  local text, complete = "", false
  if ok then
    text, complete = static_text(parsed)
  end
  -- Dynamic prefixes remain labels until selection/acceptance evaluates their variables.
  if not text:find("%S") and not complete then
    text = label
  end
  text = text:match("^[^\r\n]*") or ""
  local indent, content = text:match("^(%s*)(.*)$")
  local first = content:sub(1, 1)
  local last = closing[first]
  local prefix = last ~= nil and content:match("^%b" .. first .. last) or content:match("^[^%s=()%[%]{}<>\"']*")
  return indent .. (prefix or "")
end

---@param name                          string
---@param context                       era.keystroke.cmp.IContext
---@return string|nil
local function variable(name, context)
  if date_formats[name] ~= nil then
    return os.date(date_formats[name]) --[[@as string]]
  elseif name == "CURRENT_SECONDS_UNIX" then
    return tostring(os.time())
  elseif name == "CURRENT_TIMEZONE_OFFSET" then
    local offset = os.date("%z") --[[@as string]]
    return (offset:gsub("^(%p%d%d)(%d%d)$", "%1:%2"))
  elseif name == "RANDOM" then
    return string.format("%06d", math.random(0, 999999))
  elseif name == "RANDOM_HEX" then
    return string.format("%06x", math.random(0, 0xffffff))
  elseif name == "UUID" then
    return yoz.fn.uuid()
  elseif name == "TM_LINE_INDEX" then
    return tostring(context.row)
  elseif name == "TM_LINE_NUMBER" then
    return tostring(context.row + 1)
  elseif name == "TM_CURRENT_LINE" then
    return context.line
  elseif name == "TM_CURRENT_WORD" then
    return context.keyword
  elseif name == "CLIPBOARD" or name == "TM_SELECTED_TEXT" then
    local value = vim.fn.getreg(vim.v.register)
    return name == "TM_SELECTED_TEXT" and value:gsub("\n+$", "") or value
  elseif name == "LINE_COMMENT" or name == "BLOCK_COMMENT_START" or name == "BLOCK_COMMENT_END" then
    local left, right = vim.api.nvim_get_option_value("commentstring", { buf = context.bufnr }):match("^(.-)%%s(.*)$")
    left, right = vim.trim(left or ""), vim.trim(right or "")
    if name == "LINE_COMMENT" then
      return right == "" and left ~= "" and left or "//"
    elseif name == "BLOCK_COMMENT_START" then
      return right ~= "" and left or "/*"
    end
    return right ~= "" and right or "*/"
  end
  local path = vim.api.nvim_buf_get_name(context.bufnr)
  local filename = path:match("[^/\\]+$") or ""
  if name == "TM_FILENAME" then
    return filename
  elseif name == "TM_FILENAME_BASE" then
    return (filename:gsub("%.[^%.]+$", ""))
  elseif name == "TM_DIRECTORY" then
    return path ~= "" and dot.path.dirname(path) or ""
  elseif name == "TM_FILEPATH" then
    return path
  elseif name == "WORKSPACE_FOLDER" or name == "WORKSPACE_NAME" or name == "RELATIVE_FILEPATH" then
    local root = dot.path.cwd()
    for _, client in ipairs(vim.lsp.get_clients({ bufnr = context.bufnr })) do
      for _, folder in ipairs(client.workspace_folders or {}) do
        local directory = vim.uri_to_fname(folder.uri)
        if vim.startswith(path, directory .. "/") then
          root = directory
          break
        end
      end
    end
    if name == "WORKSPACE_FOLDER" then
      return root
    elseif name == "WORKSPACE_NAME" then
      return root:gsub("[/\\]+$", ""):match("[^/\\]+$") or root
    end
    return dot.path.relative(root, path)
  end
  return nil
end

---@param text                          string
---@param first                         integer
---@return integer|nil
local function closing_brace(text, first)
  local depth = 1
  local index = first
  while index <= #text do
    local char = text:sub(index, index)
    if char == "\\" then
      index = index + 2
    else
      if char == "{" then
        depth = depth + 1
      elseif char == "}" then
        depth = depth - 1
        if depth == 0 then
          return index
        end
      end
      index = index + 1
    end
  end
  return nil
end

---@param body                          string
---@param context                       era.keystroke.cmp.IContext
---@return string
function M.expand_variables(body, context)
  local values = {}
  local output = {}
  local index = 1
  while index <= #body do
    local char = body:sub(index, index)
    if char == "\\" then
      output[#output + 1] = body:sub(index, index + 1)
      index = index + 2
    else
      local name, after = body:match("^%$([%a_][%w_]*)()", index)
      local finish = after and after - 1 or nil
      if name == nil then
        name, after = body:match("^%${([%a_][%w_]*)()", index)
        if name ~= nil then
          local delimiter = body:sub(after, after)
          finish = delimiter == "}" and after or (delimiter == ":" and closing_brace(body, after + 1) or nil)
        end
      end
      local value
      if name ~= nil and finish ~= nil then
        if values[name] == nil then
          values[name] = variable(name, context) or false
        end
        value = values[name]
      end
      if type(value) == "string" and value ~= "" then
        output[#output + 1] = value:gsub("\\", "\\\\"):gsub("%$", "\\$"):gsub("}", "\\}")
        index = finish + 1
      else
        output[#output + 1] = char
        index = index + 1
      end
    end
  end
  return table.concat(output)
end

return M

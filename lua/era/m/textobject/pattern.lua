---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.textobject.pattern" ---@type string

local M = {}

local BRACKETS = { ["("] = ")", ["["] = "]", ["{"] = "}", ["<"] = ">" }
local OPENERS = { [")"] = "(", ["]"] = "[", ["}"] = "{", [">"] = "<" }
local QUOTES = { ["'"] = true, ['"'] = true, ["`"] = true }

---@param text                          string
---@param from                          integer
---@param to                            integer
---@return era.m.textobject.ISpan
local function trim(text, from, to)
  while from < to and text:sub(from, from):match("%s") do
    from = from + 1
  end
  while from < to and text:sub(to - 1, to - 1):match("%s") do
    to = to - 1
  end
  return { from = from, to = to }
end

---@param text                          string
---@param pattern                       string
---@param extraction                    string|nil
---@param result                        era.m.textobject.ICandidate[]
---@param disjoint                      ?boolean
---@return nil
local function collect_pattern(text, pattern, extraction, result, disjoint)
  local init = 1 ---@type integer
  while init <= #text do
    if init > 1 and pattern:sub(1, 1) == "^" then
      break
    end
    local from, to = text:find(pattern, init)
    if from == nil or to == nil then
      break
    end
    local outer = { from = from, to = to + 1 } ---@type era.m.textobject.ISpan
    local inner = outer ---@type era.m.textobject.ISpan
    if extraction ~= nil then
      local positions = { text:sub(from, to):match(extraction) } ---@type integer[]
      if #positions == 2 then
        inner = { from = from + positions[1] - 1, to = from + positions[2] - 1 }
      elseif #positions == 4 then
        outer = { from = from + positions[1] - 1, to = from + positions[4] - 1 }
        inner = { from = from + positions[2] - 1, to = from + positions[3] - 1 }
      end
    end
    result[#result + 1] = { span = { from = from, to = to + 1 }, outer = outer, inner = inner }
    init = (disjoint and to or from) + 1
  end
end

---@param text                          string
---@param left                          string
---@param trimmed                       boolean
---@param result                        era.m.textobject.ICandidate[]
---@return nil
local function collect_brackets(text, left, trimmed, result)
  local stack = {} ---@type integer[]
  local opening, closing = left:byte(), BRACKETS[left]:byte()
  for index = 1, #text do
    local char = text:byte(index) ---@type integer
    if char == opening then
      stack[#stack + 1] = index
    elseif char == closing and #stack > 0 then
      local from = stack[#stack] ---@type integer
      stack[#stack] = nil
      local span = { from = from, to = index + 1 } ---@type era.m.textobject.ISpan
      local inner = trimmed and trim(text, from + 1, index) or { from = from + 1, to = index }
      result[#result + 1] = { span = span, outer = span, inner = inner }
    end
  end
end

---@param text                          string
---@param quote                         string
---@param result                        era.m.textobject.ICandidate[]
---@param multiline                     ?boolean
---@return nil
local function collect_quote(text, quote, result, multiline)
  local start = nil ---@type integer|nil
  local index = 1 ---@type integer
  while index <= #text do
    local char = text:sub(index, index) ---@type string
    if char == "\\" then
      index = index + 2
    else
      if char == "\n" and not multiline then
        start = nil
      elseif char == quote then
        if start == nil then
          start = index
        else
          local span = { from = start, to = index + 1 } ---@type era.m.textobject.ISpan
          result[#result + 1] = { span = span, outer = span, inner = { from = start + 1, to = index } }
          start = nil
        end
      end
      index = index + 1
    end
  end
end

---@param text                          string
---@param result                        era.m.textobject.ICandidate[]
---@return nil
local function collect_arguments(text, result)
  local stack = {} ---@type { char: string, from: integer, commas: integer[] }[]
  local quote = nil ---@type string|nil
  local index = 1 ---@type integer
  while index <= #text do
    local char = text:sub(index, index) ---@type string
    if char == "\n" and quote ~= "`" then
      quote = nil
    elseif quote ~= nil then
      if char == "\\" then
        index = index + 1
      elseif char == quote then
        quote = nil
      end
    elseif #stack > 0 and QUOTES[char] then
      -- Quote state belongs to an argument container, not unrelated preceding text.
      quote = char
    elseif char == "(" or char == "[" or char == "{" then
      stack[#stack + 1] = { char = char, from = index, commas = {} }
    elseif #stack > 0 then
      local frame = stack[#stack]
      if char == "," then
        frame.commas[#frame.commas + 1] = index
      elseif char == BRACKETS[frame.char] then
        stack[#stack] = nil
        local separators = { frame.from } ---@type integer[]
        for _, comma in ipairs(frame.commas) do
          separators[#separators + 1] = comma
        end
        separators[#separators + 1] = index
        for arg_index = 1, #separators - 1 do
          local left, right = separators[arg_index], separators[arg_index + 1]
          if right > left + 1 then
            local inner = trim(text, left + 1, right) ---@type era.m.textobject.ISpan
            local first, last = arg_index == 1, arg_index == #separators - 1
            local outer = { from = first and inner.from or left, to = last and inner.to or right + 1 }
            if first and last then
              outer = { from = left + 1, to = right }
            elseif not first then
              outer.to = inner.to
            end
            result[#result + 1] = {
              span = { from = first and left + 1 or left, to = last and right or right + 1 },
              outer = outer,
              inner = inner,
            }
          end
        end
      end
    end
    index = index + 1
  end
end

---@param id                            string
---@return boolean
function M.supports(id)
  return BRACKETS[id] ~= nil
    or OPENERS[id] ~= nil
    or QUOTES[id] == true
    or ("abqtuUdeN?"):find(id, 1, true) ~= nil
    or id:match("^%a$") == nil
end

---@param text                          string
---@param id                            string
---@param prompt                        string[]|nil
---@return era.m.textobject.ICandidate[]
function M.collect(text, id, prompt)
  local result = {} ---@type era.m.textobject.ICandidate[]
  local opener = BRACKETS[id] and id or OPENERS[id] ---@type string|nil
  if opener ~= nil or id == "b" then
    local openers = id == "b" and { "(", "[", "{" } or { opener }
    for _, left in ipairs(openers) do
      collect_brackets(text, left, BRACKETS[id] ~= nil, result)
    end
  elseif QUOTES[id] or id == "q" then
    for _, quote in ipairs(id == "q" and { "'", '"', "`" } or { id }) do
      collect_quote(text, quote, result)
      if quote == "`" then
        collect_quote(text, quote, result, true)
      end
    end
  elseif id == "a" then
    collect_arguments(text, result)
  elseif id == "u" or id == "U" then
    local name = id == "u" and "[%w_%.]" or "[%w_]" ---@type string
    collect_pattern(text, "%f" .. name .. name .. "+%b()", "^.-%(().*()%)$", result)
  elseif id == "t" then
    collect_pattern(text, "<([%p%w]-)%f[^<%w][^<>]->.-</%1>", "^<.->().*()</[^/]->$", result)
  elseif id == "d" then
    collect_pattern(text, "%f[%d]%d+", nil, result)
  elseif id == "N" then
    collect_pattern(text, "%-?%d+%.?%d*", nil, result, true)
  elseif id == "e" then
    for _, pattern in ipairs({
      "%u[%l%d]+%f[^%l%d]",
      "%f[%S][%l%d]+%f[^%l%d]",
      "%f[%P][%l%d]+%f[^%l%d]",
      "^[%l%d]+%f[^%l%d]",
    }) do
      collect_pattern(text, pattern, nil, result)
    end
  elseif id == "?" then
    if prompt ~= nil then
      local pattern = vim.pesc(prompt[1]) .. "().-()" .. vim.pesc(prompt[2]) ---@type string
      collect_pattern(text, pattern, pattern, result)
    end
  elseif id:match("^%a$") == nil then
    local escaped = vim.pesc(id) ---@type string
    local pattern = string.format("%s()()[^%s]-()%s+%%f[^%s]()", escaped, escaped, escaped, escaped)
    collect_pattern(text, pattern, pattern, result)
  end
  return result
end

return M

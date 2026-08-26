---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.surrounds.search" ---@type string

local Buffer = require("era.m.surrounds.buffer")

---@class era.m.surrounds.search
local M = {}

---@param from                          integer
---@param to                            ?integer Inclusive
---@return era.m.surrounds.ISpan
local function new_span(from, to)
  return { from = from, to = to == nil and from or to + 1 }
end

---@param span                          era.m.surrounds.ISpan|nil
---@param target                        era.m.surrounds.ISpan|nil
---@return boolean
local function is_covering(span, target)
  if span == nil or target == nil then
    return false
  end
  if span.from == span.to then
    return span.from == target.from and target.to == span.to
  end
  if target.from == target.to then
    return span.from <= target.from and target.to < span.to
  end
  return span.from <= target.from and target.to <= span.to
end

---@param left                          era.m.surrounds.ISpan|nil
---@param right                         era.m.surrounds.ISpan|nil
---@return boolean
local function is_equal(left, right)
  return left ~= nil and right ~= nil and left.from == right.from and left.to == right.to
end

---@param left                          era.m.surrounds.ISpan|nil
---@param right                         era.m.surrounds.ISpan|nil
---@return boolean
local function is_on_left(left, right)
  return left ~= nil and right ~= nil and left.from <= right.from and left.to <= right.to
end

---@param candidate                     era.m.surrounds.ISpan
---@param current                       era.m.surrounds.ISpan|nil
---@param reference                     era.m.surrounds.ISpan
---@return boolean|nil
local function compare_covering(candidate, current, reference)
  local candidate_covering = is_covering(candidate, reference) ---@type boolean
  local current_covering = is_covering(current, reference) ---@type boolean
  if candidate_covering and current_covering then
    return candidate.to - candidate.from < current.to - current.from
  end
  if candidate_covering then
    return true
  end
  if current_covering then
    return false
  end
end

---@param candidate                     era.m.surrounds.ISpan
---@param current                       era.m.surrounds.ISpan|nil
---@param reference                     era.m.surrounds.ISpan
---@return boolean
local function is_better(candidate, current, reference)
  if is_covering(reference, candidate) or is_equal(candidate, reference) then
    return false
  end

  local covering = compare_covering(candidate, current, reference) ---@type boolean|nil
  if covering ~= nil then
    return covering
  end
  if not is_on_left(reference, candidate) then
    return false
  end
  if current == nil then
    return true
  end
  return math.abs(candidate.from - reference.from) < math.abs(current.from - reference.from)
end

---@param text                          string
---@param pattern                       string
---@param init                          ?integer
---@return integer|nil
---@return integer|nil
local function string_find(text, pattern, init)
  init = init or 1
  if pattern:sub(1, 1) == "^" then
    if init > 1 then
      return nil, nil
    end
    return string.find(text, pattern)
  end

  local special_start, _, previous = string.find(pattern, "(.)%.%-")
  local is_special = special_start ~= nil and previous ~= "%" ---@type boolean
  if not is_special then
    return string.find(text, pattern, init)
  end

  local from, to = string.find(text, pattern, init)
  if from == nil then
    return nil, nil
  end

  local next_from, next_to = from, to ---@type integer|nil, integer|nil
  while next_to == to do
    from, to = next_from, next_to
    next_from, next_to = string.find(text, pattern, next_from + 1)
  end
  return from, to
end

---@param patterns                      table
---@return string[][]
local function cartesian_product(patterns)
  if #patterns == 0 then
    return {}
  end

  local steps = {} ---@type string[][]
  for index, value in ipairs(patterns) do
    steps[index] = vim.islist(value) and value or { value }
  end

  local result = {} ---@type string[][]
  local current = {} ---@type string[]
  local function process(level)
    for _, value in ipairs(steps[level]) do
      current[#current + 1] = value
      if level == #steps then
        result[#result + 1] = vim.list_slice(current)
      else
        process(level + 1)
      end
      current[#current] = nil
    end
  end
  process(1)
  return result
end

---@param text                          string
---@param patterns                      string[]
---@param callback                      fun(span: era.m.surrounds.ISpan): nil
---@return nil
local function iterate_matches(text, patterns, callback)
  local max_level = #patterns ---@type integer
  local visited = {} ---@type table<string, boolean>

  local process
  ---@param level                       integer
  ---@param level_text                  string
  ---@param offset                      integer
  process = function(level, level_text, offset)
    local pattern = patterns[level] ---@type string
    local is_same_balanced = pattern:match("^%%b(.)%1$") ~= nil ---@type boolean
    local init = 1 ---@type integer
    while init <= #level_text do
      local from, to = string_find(level_text, pattern, init)
      if from == nil or to == nil then
        break
      end

      if level == max_level then
        local span = new_span(from + offset, to + offset) ---@type era.m.surrounds.ISpan
        local id = string.format("%d_%d", span.from, span.to) ---@type string
        if not visited[id] then
          visited[id] = true
          callback(span)
        end
      else
        process(level + 1, level_text:sub(from, to), offset + from - 1)
      end
      init = (is_same_balanced and to or from) + 1
    end
  end

  process(1, text, 0)
end

---@param text                          string
---@param pattern                       string
---@return era.m.surrounds.ISpanPair
local function extract_spans(text, pattern)
  local positions = { text:match(pattern) } ---@type any[]
  local valid = #positions == 2 or #positions == 4 ---@type boolean
  for _, position in ipairs(positions) do
    valid = valid and type(position) == "number"
  end
  if not valid then
    error(string.format("(%s) invalid extraction pattern %q for %q", __module_name__, pattern, text), 0)
  end

  if #positions == 2 then
    return {
      left = new_span(1, positions[1] - 1),
      right = new_span(positions[2], #text),
    }
  end
  return {
    left = new_span(positions[1], positions[2] - 1),
    right = new_span(positions[3], positions[4] - 1),
  }
end

---@param neighborhood                  era.m.surrounds.INeighborhood
---@param patterns                      table
---@param reference                     era.m.surrounds.ISpan
---@return { span: era.m.surrounds.ISpan|nil, extract_pattern: string|nil }
local function find_best(neighborhood, patterns, reference)
  local best = nil ---@type era.m.surrounds.ISpan|nil
  local best_patterns = nil ---@type string[]|nil
  for _, nested_patterns in ipairs(cartesian_product(patterns)) do
    iterate_matches(neighborhood.text, nested_patterns, function(span)
      if is_better(span, best, reference) then
        best = span
        best_patterns = nested_patterns
      end
    end)
  end
  return {
    span = best,
    extract_pattern = best_patterns and best_patterns[#best_patterns] or nil,
  }
end

---@param patterns                      table
---@param opts                          era.m.surrounds.ISearchOptions
---@return era.m.surrounds.IRegionPair|nil
function M.find(patterns, opts)
  if opts.n_times == 0 then
    return nil
  end

  local neighborhood = Buffer.get_neighborhood(opts.reference_region, 0) ---@type era.m.surrounds.INeighborhood
  local reference = neighborhood.region_to_span(opts.reference_region) ---@type era.m.surrounds.ISpan

  ---@param current                     era.m.surrounds.ISpan
  ---@return { span: era.m.surrounds.ISpan|nil, extract_pattern: string|nil }
  local function find_next(current)
    local result = find_best(neighborhood, patterns, current)
    if result.span == nil then
      if opts.n_lines == 0 or neighborhood.n_neighbors > 0 then
        return result
      end

      local current_region = neighborhood.span_to_region(current) ---@type era.m.surrounds.IRegion
      neighborhood = Buffer.get_neighborhood(opts.reference_region, opts.n_lines)
      reference = neighborhood.region_to_span(opts.reference_region) ---@type era.m.surrounds.ISpan
      current = neighborhood.region_to_span(current_region) ---@type era.m.surrounds.ISpan
      result = find_best(neighborhood, patterns, current)
    end
    return result
  end

  local result = { span = reference, extract_pattern = nil } ---@type { span: era.m.surrounds.ISpan|nil, extract_pattern: string|nil }
  for _ = 1, opts.n_times do
    result = find_next(result.span)
    if result.span == nil then
      return nil
    end
  end

  ---@param span                        era.m.surrounds.ISpan
  ---@param pattern                     string
  ---@return era.m.surrounds.ISpanPair
  local function extract(span, pattern)
    local local_text = neighborhood.text:sub(span.from, span.to - 1) ---@type string
    local pair = extract_spans(local_text, pattern) ---@type era.m.surrounds.ISpanPair
    local offset = span.from - 1 ---@type integer
    return {
      left = { from = pair.left.from + offset, to = pair.left.to + offset },
      right = { from = pair.right.from + offset, to = pair.right.to + offset },
    }
  end

  local spans = extract(result.span, result.extract_pattern) ---@type era.m.surrounds.ISpanPair
  local outer = { from = spans.left.from, to = spans.right.to } ---@type era.m.surrounds.ISpan
  if is_covering(reference, outer) then
    result = find_next(result.span)
    if result.span == nil then
      return nil
    end
    spans = extract(result.span, result.extract_pattern)
    outer = { from = spans.left.from, to = spans.right.to }
    if is_covering(reference, outer) then
      return nil
    end
  end

  return {
    left = neighborhood.span_to_region(spans.left),
    right = neighborhood.span_to_region(spans.right),
  }
end

return M

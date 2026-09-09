---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.textobject.find" ---@type string

local Filetype = require("stl.filetype")
local Pattern = require("era.m.textobject.pattern")
local Search = require("era.m.textobject.search")
local Source = require("era.m.textobject.source")
local Treesitter = require("era.m.textobject.treesitter")

local M = {}

---@type table<string, boolean>
local DISABLED_BUFTYPES = {
  help = true,
  prompt = true,
  quickfix = true,
  terminal = true,
}

local CAPTURES = {
  f = { a = { "function.outer" }, i = { "function.inner" } },
  c = { a = { "class.outer" }, i = { "class.inner" } },
  o = {
    a = { "block.outer", "conditional.outer", "loop.outer" },
    i = { "block.inner", "conditional.inner", "loop.inner" },
  },
  m = { a = { "comment.outer" }, i = { "comment.inner" } },
  S = { a = { "local.scope" }, i = { "local.scope" } },
}

---@param bufnr                         integer
---@return boolean
function M.is_enabled(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) or not vim.api.nvim_buf_is_loaded(bufnr) then
    return false
  end
  local buftype = vim.api.nvim_get_option_value("buftype", { buf = bufnr }) ---@type string
  if DISABLED_BUFTYPES[buftype] then
    return false
  end
  if buftype ~= "nofile" then
    return true
  end
  -- Source scratch buffers and notepads remain selectable; diff scratch buffers are hunk previews.
  local filetype = vim.api.nvim_get_option_value("filetype", { buf = bufnr }) ---@type string
  return filetype ~= "diff" and Filetype.is_sourcefile(filetype)
end

---@param id                            string
---@return boolean
function M.supports(id)
  return CAPTURES[id] ~= nil or id == "g" or id == "h" or id == "s" or Pattern.supports(id)
end

---@param bufnr                         integer
---@param kind                          era.m.textobject.Kind
---@return era.m.textobject.Range
local function buffer_range(bufnr, kind)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, true) ---@type string[]
  local first, last = 1, #lines
  if kind == "i" then
    while first <= last and lines[first]:match("^%s*$") do
      first = first + 1
    end
    while first <= last and lines[last]:match("^%s*$") do
      last = last - 1
    end
    if first > last then
      return { 0, 0, 0, 0 }
    end
  end
  return { first - 1, 0, last - 1, #lines[last] }
end

---@param ranges                        era.m.textobject.Range[]
---@param source                        era.m.textobject.ISource
---@param envelopes                     era.m.textobject.Range[]|nil
---@return era.m.textobject.ICandidate[]
local function range_candidates(ranges, source, envelopes)
  local result = {} ---@type era.m.textobject.ICandidate[]
  local outer_spans = {} ---@type era.m.textobject.ISpan[]
  for _, outer in ipairs(envelopes or {}) do
    outer_spans[#outer_spans + 1] = Source.span(source, outer)
  end
  local last_row = source.first_row + #source.lines - 1 ---@type integer
  for _, range in ipairs(ranges) do
    local ends_at_boundary = range[3] == last_row + 1 and range[4] == 0 ---@type boolean
    if source.first_row <= range[1] and (range[3] <= last_row or ends_at_boundary) then
      local span = Source.span(source, range)
      if ends_at_boundary and range.vis_mode ~= "V" then
        span.to = span.to - 1
      end
      result[#result + 1] = { span = span, outer = span, inner = span, vis_mode = range.vis_mode }
    end
  end

  if #outer_spans > 0 then
    table.sort(outer_spans, function(left, right)
      return left.from < right.from or (left.from == right.from and left.to > right.to)
    end)
    table.sort(result, function(left, right)
      return left.inner.from < right.inner.from
    end)
    local next_outer = 1 ---@type integer
    local active = {} ---@type era.m.textobject.ISpan[]
    -- Only overlapping envelopes remain active; sibling functions do not require all-pairs scans.
    for _, candidate in ipairs(result) do
      while next_outer <= #outer_spans and outer_spans[next_outer].from <= candidate.inner.from do
        active[#active + 1] = outer_spans[next_outer]
        next_outer = next_outer + 1
      end
      local kept, width = 0, math.huge
      for _, outer in ipairs(active) do
        if outer.to >= candidate.inner.from then
          kept = kept + 1
          active[kept] = outer
          if Search.covers(outer, candidate.inner) and outer.to - outer.from < width then
            candidate.span, width = outer, outer.to - outer.from
          end
        end
      end
      for index = #active, kept + 1, -1 do
        active[index] = nil
      end
    end
  end
  return result
end

---@param kind                          era.m.textobject.Kind
---@param id                            string
---@param opts                          ?era.m.textobject.IOptions
---@return era.m.textobject.Range|nil
---@return string|nil
function M.find(kind, id, opts)
  opts = opts or {}
  local bufnr = vim.api.nvim_get_current_buf() ---@type integer
  if not M.is_enabled(bufnr) then
    return nil, nil
  end
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  local cursor = vim.api.nvim_win_get_cursor(winnr) ---@type integer[]
  local reference = opts.reference or { cursor[1] - 1, cursor[2], cursor[1] - 1, cursor[2] }
  local reference_last = reference[3] > reference[1] and reference[4] == 0 and reference[3] - 1 or reference[3] ---@type integer
  local count = opts.count or 1 ---@type integer
  if count < 1 then
    return nil, nil
  end
  if id == "g" then
    return buffer_range(bufnr, kind), nil
  end
  if id == "s" then
    return era.m.splitline.textobject(kind), nil
  end

  local captures = CAPTURES[id]
  local whole_buffer = id == "f" or id == "c" or id == "S" ---@type boolean
  local first_row = whole_buffer and 0 or math.max(0, reference[1] - 500) ---@type integer
  local last_row = whole_buffer and vim.api.nvim_buf_line_count(bufnr)
    or math.min(vim.api.nvim_buf_line_count(bufnr), reference_last + 501)
  local lines = vim.api.nvim_buf_get_lines(bufnr, first_row, last_row, true) ---@type string[]
  -- Text captures omit the final newline; linewise Git hunk ranges include it.
  if opts.reference ~= nil and opts.vis_mode == "V" and id ~= "h" then
    reference = { reference[1], 0, reference_last, #lines[reference_last - first_row + 1] }
  end
  local source = Source.new(lines, first_row)
  local candidates = {} ---@type era.m.textobject.ICandidate[]
  local reason = nil ---@type string|nil
  local complete = false ---@type boolean
  ---@param rows                        ?integer[]
  ---@return era.m.textobject.ICandidate[]
  ---@return string|nil
  ---@return boolean
  local function query_candidates(rows)
    assert(captures ~= nil)
    local paired = kind == "i" and (id == "f" or id == "c") ---@type boolean
    local requested = vim.list_slice(captures[kind]) ---@type string[]
    if paired then
      vim.list_extend(requested, captures.a)
    end
    local ranges, err, searched_all =
      Treesitter.ranges(bufnr, requested, id == "S" and "locals" or "textobjects", { cursor[1] - 1, cursor[2] }, rows)
    local envelopes = nil ---@type era.m.textobject.Range[]|nil
    if paired then
      local inner = {} ---@type era.m.textobject.Range[]
      envelopes = {}
      for _, range in ipairs(ranges) do
        if vim.list_contains(captures.a, range.capture) then
          envelopes[#envelopes + 1] = range
        else
          inner[#inner + 1] = range
        end
      end
      ranges = inner
    end
    return range_candidates(ranges, source, envelopes), err, searched_all
  end
  if captures ~= nil then
    candidates, reason, complete = query_candidates({ reference[1], reference_last + 1 })
  elseif id == "h" then
    candidates = range_candidates(era.m.git.hunk.textobjects(), source)
  else
    candidates = Pattern.collect(source.text, id, opts.prompt)
  end

  local local_bounds = nil ---@type era.m.textobject.ISpan|nil
  if not whole_buffer then
    local last = reference_last - first_row + 1 ---@type integer
    local_bounds = { from = Source.offset(source, reference[1], 0), to = source.starts[last] + #lines[last] }
  end
  local selected, vis_mode = Search.find(candidates, Source.span(source, reference), kind, count, local_bounds)
  if selected == nil and captures ~= nil and not complete then
    candidates, reason = query_candidates(not whole_buffer and { first_row, last_row } or nil)
    selected, vis_mode = Search.find(candidates, Source.span(source, reference), kind, count, local_bounds)
  end
  if selected == nil then
    return nil, reason
  end
  if kind == "a" and id == "f" then
    vis_mode = opts.vis_mode or "V"
  elseif kind == "a" and id == "c" then
    vis_mode = opts.vis_mode or "\22"
  end
  local range = Source.range(source, selected, vis_mode)
  if kind == "a" and id == "f" and vis_mode == "V" then
    -- Linewise objects may include blank lines, never the indentation of a following statement.
    local last = range[3] + 1 ---@type integer
    while last < #lines and lines[last + 1]:match("^%s*$") do
      last = last + 1
    end
    if last > range[3] + 1 then
      range[3], range[4] = last, 0
    else
      local first = range[1] + 1 ---@type integer
      while first > 1 and lines[first - 1]:match("^%s*$") do
        first = first - 1
      end
      if first < range[1] + 1 then
        range[1], range[2] = first - 1, 0
      end
    end
  end
  return range, nil
end

return M

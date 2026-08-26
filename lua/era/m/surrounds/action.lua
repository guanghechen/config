---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.surrounds.action" ---@type string

local Buffer = require("era.m.surrounds.buffer")
local Definition = require("era.m.surrounds.definition")
local Search = require("era.m.surrounds.search")

local HIGHLIGHT_DURATION = 500 ---@type integer
local N_LINES = 50 ---@type integer

---@class era.m.surrounds.action.ICache
---@field public count                  ?integer
---@field public direction              ?"left"|"right"
---@field public input                  ?era.m.surrounds.IInputDefinition
---@field public output                 ?era.m.surrounds.IOutputDefinition

---@class era.m.surrounds.action
local M = {}

local cache = {} ---@type era.m.surrounds.action.ICache

---@return era.m.surrounds.IInputDefinition|nil
local function get_input()
  if cache.input ~= nil then
    return cache.input
  end
  local id = Definition.read_id() ---@type string|nil
  if id == nil then
    return nil
  end
  cache.input = Definition.resolve_input(id)
  return cache.input
end

---@param use_cache                     boolean
---@return era.m.surrounds.IOutputDefinition|nil
local function get_output(use_cache)
  if not use_cache then
    cache = {}
  elseif cache.output ~= nil then
    return cache.output
  end

  local id = Definition.read_id() ---@type string|nil
  if id == nil then
    return nil
  end
  local output = Definition.resolve_output(id) ---@type era.m.surrounds.IOutputDefinition|nil
  if use_cache then
    cache.output = output
  end
  return output
end

---@param input                         era.m.surrounds.IInputDefinition
---@return era.m.surrounds.IRegionPair|nil
local function find_surrounding(input)
  local cursor = vim.api.nvim_win_get_cursor(0) ---@type integer[]
  return Search.find(input.patterns, {
    n_lines = N_LINES,
    n_times = cache.count or vim.v.count1,
    reference_region = { from = { line = cursor[1], col = cursor[2] + 1 } },
  })
end

---@param input                         era.m.surrounds.IInputDefinition
---@return nil
local function notify_missing(input)
  vim.api.nvim_echo({
    {
      string.format("(surrounds) No %q surrounding found within %d lines", input.id, N_LINES),
      "WarningMsg",
    },
  }, false, {})
end

---@return era.m.surrounds.IRegionPair|nil
local function resolve_surrounding()
  local input = get_input() ---@type era.m.surrounds.IInputDefinition|nil
  if input == nil then
    return nil
  end
  local pair = find_surrounding(input) ---@type era.m.surrounds.IRegionPair|nil
  if pair == nil then
    notify_missing(input)
  end
  return pair
end

---@return boolean
local function is_current_buffer_available()
  return Buffer.is_available(vim.api.nvim_get_current_buf())
end

---@param mode                          string
---@return string|nil
function M.add(mode)
  if not is_current_buffer_available() then
    return "<Esc>"
  end

  local marks = Buffer.get_marks(mode) ---@type era.m.surrounds.IMarks
  local output = get_output(mode ~= "visual") ---@type era.m.surrounds.IOutputDefinition|nil
  if output == nil then
    return "<Esc>"
  end

  if not output.did_count then
    local count = cache.count or vim.v.count1 ---@type integer
    output.left = output.left:rep(count)
    output.right = output.right:rep(count)
    output.did_count = true
  end

  if marks.selection_type == "charwise" then
    Buffer.region_replace({ from = { line = marks.second.line, col = marks.second.col + 1 } }, output.right)
    Buffer.region_replace({ from = marks.first }, output.left)
    Buffer.set_cursor(marks.first.line, marks.first.col + #output.left)
    return nil
  end

  if marks.selection_type == "linewise" then
    local from_line = marks.first.line ---@type integer
    local to_line = marks.second.line ---@type integer
    local indent = Buffer.get_range_indent(from_line, to_line) ---@type string
    Buffer.shift_indent(">", from_line, to_line)
    Buffer.set_cursor_nonblank(from_line)
    Buffer.insert_lines(to_line, { indent .. output.right })
    Buffer.insert_lines(from_line - 1, { indent .. output.left })
    return nil
  end

  local from_col = math.min(marks.first.col, marks.second.col) ---@type integer
  local to_col = math.max(marks.first.col, marks.second.col) ---@type integer
  for line = marks.first.line, marks.second.line do
    Buffer.region_replace({ from = { line = line, col = to_col + 1 } }, output.right)
    Buffer.region_replace({ from = { line = line, col = from_col } }, output.left)
  end
  Buffer.set_cursor(marks.first.line, from_col + #output.left)
end

---@return string|nil
function M.delete()
  if not is_current_buffer_available() then
    return "<Esc>"
  end
  local pair = resolve_surrounding() ---@type era.m.surrounds.IRegionPair|nil
  if pair == nil then
    return "<Esc>"
  end

  Buffer.region_replace(pair.right, {})
  Buffer.region_replace(pair.left, {})
  Buffer.set_cursor(pair.left.from.line, pair.left.from.col)

  local from_line = pair.left.from.line ---@type integer
  local to_line = pair.right.from.line ---@type integer
  local linewise = from_line < to_line and Buffer.is_line_blank(from_line) and Buffer.is_line_blank(to_line) ---@type boolean
  if linewise then
    Buffer.shift_indent("<", from_line, to_line)
    Buffer.set_cursor_nonblank(from_line + 1)
    Buffer.delete_line(to_line)
    Buffer.delete_line(from_line)
  end
end

---@return string|nil
function M.replace()
  if not is_current_buffer_available() then
    return "<Esc>"
  end
  local pair = resolve_surrounding() ---@type era.m.surrounds.IRegionPair|nil
  if pair == nil then
    return "<Esc>"
  end
  local output = get_output(true) ---@type era.m.surrounds.IOutputDefinition|nil
  if output == nil then
    return "<Esc>"
  end

  Buffer.region_replace(pair.right, output.right)
  Buffer.region_replace(pair.left, output.left)
  Buffer.set_cursor(pair.left.from.line, pair.left.from.col + #output.left)
end

---@return nil
function M.find()
  if not is_current_buffer_available() then
    return
  end
  local pair = resolve_surrounding() ---@type era.m.surrounds.IRegionPair|nil
  if pair == nil then
    return
  end
  local positions = Buffer.surrounding_positions(pair) ---@type era.m.surrounds.IPosition[]
  if #positions == 0 then
    return
  end
  vim.cmd("normal! m'")
  Buffer.cycle_cursor(positions, cache.direction or "right")
  vim.cmd("normal! zv")
end

---@return nil
function M.highlight()
  if not is_current_buffer_available() then
    return
  end
  local pair = resolve_surrounding() ---@type era.m.surrounds.IRegionPair|nil
  if pair == nil then
    return
  end

  local bufnr = vim.api.nvim_get_current_buf() ---@type integer
  Buffer.highlight_region(bufnr, pair.left)
  Buffer.highlight_region(bufnr, pair.right)
  vim.defer_fn(function()
    Buffer.clear_region_highlight(bufnr, pair.left)
    Buffer.clear_region_highlight(bufnr, pair.right)
  end, HIGHLIGHT_DURATION)
end

---@param task                          "add"|"delete"|"replace"
---@param ask_for_motion                boolean
---@return fun(): string
function M.make_operator(task, ask_for_motion)
  return function()
    if not is_current_buffer_available() then
      return "<Esc>"
    end
    cache = { count = vim.v.count1 }
    vim.api.nvim_set_option_value("operatorfunc", "v:lua.era.m.surrounds." .. task, { scope = "global" })
    return "<Cmd>redraw<CR>g@" .. (ask_for_motion and "" or " ")
  end
end

---@param task                          "find"|"highlight"
---@param direction                     "left"|"right"|nil
---@return fun(): string
function M.make_action(task, direction)
  return function()
    if not is_current_buffer_available() then
      return "<Esc>"
    end
    cache = { count = vim.v.count1, direction = direction }
    return string.format("<Cmd>lua era.m.surrounds.%s()<CR>", task)
  end
end

return M

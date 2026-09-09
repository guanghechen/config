---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.textobject.action" ---@type string

local Find = require("era.m.textobject.find")
local Swap = require("era.m.textobject.swap")
local Treesitter = require("era.m.textobject.treesitter")

local M = {}
local swap_direction = 1 ---@type integer
local pending_registers = nil ---@type table<string, table>|nil
local selection_id = 0 ---@type integer

---@param message                       string
---@return nil
local function notify(message)
  stl.reporter.warn({ from = __module_name__, subject = "textobject", message = message })
end

---@return nil
local function normal_mode()
  local keys = vim.api.nvim_replace_termcodes("<C-\\><C-n>", true, false, true) ---@type string
  vim.cmd.normal({ args = { keys }, bang = true })
end

---@param bufnr                         integer
---@param range                         era.m.textobject.Range
---@param motion                        ?boolean
---@return integer[] One-based row, zero-based byte column
function M.end_position(bufnr, range, motion)
  local row, col = range[3], range[4]
  if row == range[1] and col == range[2] then
    return { row + 1, col }
  end
  if col == 0 then
    row = row - 1
    local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, true)[1] ---@type string
    if not motion then
      return { row + 1, #line }
    end
    col = #line
  end
  local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, true)[1] ---@type string
  col = math.max(0, col - 1)
  while col > 0 do
    local byte = line:byte(col + 1) ---@type integer|nil
    if byte == nil or byte < 128 or byte >= 192 then
      break
    end
    col = col - 1
  end
  return { row + 1, col }
end

---@return era.m.textobject.Range
function M.visual_range()
  local anchor = vim.fn.getpos("v") ---@type integer[]
  local cursor = vim.api.nvim_win_get_cursor(vim.api.nvim_get_current_win()) ---@type integer[]
  local first, last = { anchor[2] - 1, anchor[3] - 1 }, { cursor[1] - 1, cursor[2] }
  if first[1] > last[1] or (first[1] == last[1] and first[2] > last[2]) then
    first, last = last, first
  end
  local bufnr = vim.api.nvim_get_current_buf() ---@type integer
  local line = vim.api.nvim_buf_get_lines(bufnr, last[1], last[1] + 1, true)[1] ---@type string
  local mode = vim.fn.mode() ---@type string
  if mode == "V" then
    first[2], last = 0, { last[1] + 1, 0 }
  elseif vim.o.selection ~= "exclusive" or (first[1] == last[1] and first[2] == last[2]) then
    local col = math.min(last[2] + 1, #line) ---@type integer
    while col < #line and line:byte(col + 1) >= 128 and line:byte(col + 1) < 192 do
      col = col + 1
    end
    last[2] = col
  end
  return { first[1], first[2], last[1], last[2] }
end

---Runs after the native operator has consumed an empty range's placeholder.
---@param id                            integer
---@return nil
function M.finish_select(id)
  if id ~= selection_id then
    return
  end
  local registers = pending_registers
  pending_registers = nil
  if registers == nil then
    return
  end
  for name, info in pairs(registers) do
    if name ~= '"' then
      vim.fn.setreg(name, info.regcontents or {}, info.regtype or "v")
    end
  end
  local unnamed = registers['"']
  vim.fn.setreg('"', unnamed.regcontents and unnamed or { regcontents = {}, regtype = "v" })
end

---@param kind                          era.m.textobject.Kind
---@param id                            string
---@param opts                          ?era.m.textobject.IOptions
---@return nil
function M.select(kind, id, opts)
  -- A native operator error can discard its queued cleanup; never reuse that snapshot.
  selection_id = selection_id + 1
  local operation_id = selection_id ---@type integer
  pending_registers = nil
  opts = opts or {}
  local register = vim.v.register:lower() ---@type string
  normal_mode()
  if not Find.is_enabled(vim.api.nvim_get_current_buf()) then
    return
  end
  local range, reason = Find.find(kind, id, opts)
  if range == nil then
    notify(reason or ("No " .. kind .. id .. " textobject found"))
    return
  end
  local empty = range[1] == range[3] and range[2] == range[4] ---@type boolean
  if empty and opts.operator_pending and vim.v.operator ~= "c" and vim.v.operator ~= "d" then
    notify("Textobject is empty")
    return
  end

  local winnr = vim.api.nvim_get_current_win() ---@type integer
  local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
  local virtualedit = vim.api.nvim_get_option_value("virtualedit", { win = winnr, scope = "local" }) ---@type string
  local eventignore = vim.o.eventignore ---@type string
  local leftcol = vim.fn.winsaveview().leftcol ---@type integer
  local vis_mode = range.vis_mode or opts.vis_mode or "v" ---@type string
  local ok, err = pcall(function()
    vim.api.nvim_set_option_value("virtualedit", "onemore", { win = winnr, scope = "local" })
    vim.api.nvim_win_set_cursor(winnr, { range[1] + 1, range[2] })
    vim.cmd("normal! zv")
    vim.cmd.normal({ args = { vis_mode }, bang = true })
    local ending = M.end_position(bufnr, range)
    if vim.o.selection == "exclusive" and vis_mode == "v" and not empty then
      ending = { range[3] + 1, range[4] }
    end
    vim.api.nvim_win_set_cursor(winnr, ending)
    vim.cmd("normal! zv")
    vim.fn.winrestview({ leftcol = leftcol })
    if empty and opts.operator_pending then
      -- Visual mode cannot represent an empty edit. The pending c/d consumes this placeholder.
      pending_registers = {
        ['"'] = vim.fn.getreginfo('"'),
        ["-"] = vim.fn.getreginfo("-"),
      }
      if register ~= "_" then
        pending_registers[register] = vim.fn.getreginfo(register)
      end
      -- Clipboard routing may be resolved by the native operator after this command returns.
      for flag in vim.o.clipboard:gmatch("[^,]+") do
        local name = flag == "unnamedplus" and "+" or flag == "unnamed" and "*" or nil
        if name ~= nil then
          pending_registers[name] = vim.fn.getreginfo(name)
        end
      end
      vim.o.eventignore = "all"
      local keys = vim.api.nvim_replace_termcodes("<Esc>i <Esc>v", true, false, true) ---@type string
      vim.cmd.normal({ args = { keys }, bang = true })
    end
  end)
  vim.o.eventignore = eventignore
  vim.api.nvim_set_option_value("virtualedit", virtualedit, { win = winnr, scope = "local" })
  if not ok then
    M.finish_select(operation_id)
    error(err, 0)
  end
  if pending_registers ~= nil then
    -- Queue after the native operator, including when select() is invoked by dot-repeat.
    local keys = vim.api.nvim_replace_termcodes(
      string.format('<Cmd>lua require("era.m.textobject.action").finish_select(%d)<CR>', operation_id),
      true,
      false,
      true
    )
    vim.api.nvim_feedkeys(keys, "in", false)
  end
end

---@param side                          "left"|"right"
---@param id                            string
---@param count                         integer
---@param prompt                        string[]|nil
---@return nil
function M.move_edge(side, id, count, prompt)
  if not Find.is_enabled(vim.api.nvim_get_current_buf()) then
    return
  end
  -- n remains available for numeric edge motions; an/in belong to native selection.
  id = id == "n" and "N" or id
  local range, reason = Find.find("a", id, { prompt = prompt })
  if range == nil then
    notify(reason or ("No a" .. id .. " textobject found"))
    return
  end
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
  local position = side == "left" and { range[1] + 1, range[2] } or M.end_position(bufnr, range, true)
  local cursor = vim.api.nvim_win_get_cursor(winnr)
  if cursor[1] == position[1] and cursor[2] == position[2] then
    count = count + 1
  end
  if count > 1 then
    range = Find.find("a", id, { count = count, prompt = prompt })
    if range == nil then
      return
    end
    position = side == "left" and { range[1] + 1, range[2] } or M.end_position(bufnr, range, true)
  end
  vim.cmd("normal! m'")
  vim.api.nvim_win_set_cursor(winnr, position)
  vim.cmd("normal! zv")
end

---@param captures                      string[]
---@param group                         string
---@param direction                     integer
---@param use_end                       boolean
---@param count                         integer
---@return nil
function M.move(captures, group, direction, use_end, count)
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
  if not Find.is_enabled(bufnr) then
    return
  end
  local cursor = vim.api.nvim_win_get_cursor(winnr)
  for attempt = 1, 2 do
    local rows = attempt == 1 and { math.max(0, cursor[1] - 501), cursor[1] + 500 } or nil ---@type integer[]|nil
    local ranges, reason, complete = Treesitter.ranges(bufnr, captures, group, { cursor[1] - 1, cursor[2] }, rows)
    if reason ~= nil then
      notify(reason)
      return
    end
    local positions = {} ---@type integer[][]
    local seen = {} ---@type table<string, true>
    for _, range in ipairs(ranges) do
      local position = use_end and M.end_position(bufnr, range, true) or { range[1] + 1, range[2] }
      local key = table.concat(position, ":") ---@type string
      local before = position[1] < cursor[1] or (position[1] == cursor[1] and position[2] < cursor[2]) ---@type boolean
      local after = position[1] > cursor[1] or (position[1] == cursor[1] and position[2] > cursor[2]) ---@type boolean
      if not seen[key] and ((direction < 0 and before) or (direction > 0 and after)) then
        seen[key] = true
        positions[#positions + 1] = position
      end
    end
    table.sort(positions, function(left, right)
      return left[1] < right[1] or (left[1] == right[1] and left[2] < right[2])
    end)
    local target = positions[direction > 0 and count or #positions - count + 1]
    -- An enclosing node can end beyond the window, with nearer siblings still outside the query.
    if target ~= nil and (complete or (rows[1] <= target[1] - 1 and target[1] - 1 < rows[2])) then
      -- Read the forced mode before normal! resets it; unforced operators include the target.
      local mode = vim.api.nvim_get_mode().mode ---@type string
      vim.cmd("normal! m'")
      if mode == "no" then
        vim.cmd("normal! v")
      end
      vim.api.nvim_win_set_cursor(winnr, target)
      vim.cmd("normal! zv")
      return
    end
    if complete then
      return
    end
  end
end

---@param direction                     integer
---@return nil
function M.swap_parameter(direction)
  swap_direction = direction
  vim.go.operatorfunc = "v:lua.era.m.textobject.swap_operator"
  vim.api.nvim_feedkeys(tostring(vim.v.count1) .. "g@l", "n", false)
end

---@param _                             string
---@return nil
function M.swap_operator(_)
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
  if not Find.is_enabled(bufnr) then
    return
  end
  if
    not vim.api.nvim_get_option_value("modifiable", { buf = bufnr })
    or vim.api.nvim_get_option_value("readonly", { buf = bufnr })
  then
    notify("Buffer is not writable")
    return
  end
  local cursor = vim.api.nvim_win_get_cursor(winnr)
  local position = { cursor[1] - 1, cursor[2] } ---@type integer[]
  local ranges, reason = Treesitter.ranges(bufnr, { "parameter.inner" }, "textobjects", position)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, true) ---@type string[]
  local edit = Swap.plan(lines, ranges, position, swap_direction, vim.v.count1)
  if edit == nil then
    notify(reason or "No adjacent parameter in the same container")
    return
  end
  local range = edit.range
  vim.api.nvim_buf_set_text(bufnr, range[1], range[2], range[3], range[4], edit.lines)
  vim.api.nvim_win_set_cursor(winnr, edit.cursor)
end

return M

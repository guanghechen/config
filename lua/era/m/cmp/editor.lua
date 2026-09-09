---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.cmp.editor" ---@type string

local nvim = require("stl.nvim.fn")
local namespace = vim.api.nvim_create_namespace(__module_name__)
local REPEAT_FINISH = "<Plug>(era-cmp-repeat-finish)"
local REPEAT_CURSOR = "<Plug>(era-cmp-repeat-cursor)"
local repeat_keys_bound = false
local repeat_generation = 0
local pending_repeat = nil ---@type era.m.cmp.editor.IRepeat|nil
local pending_cursor = nil ---@type era.m.cmp.editor.IRepeat|nil
local cursor_target = nil ---@type integer[]|nil

---@class era.m.cmp.editor.IBase
---@field public bufnr                  integer
---@field public row                    integer
---@field public col                    integer
---@field public line                   string

---@class era.m.cmp.editor.IApplied
---@field public bufnr                  integer
---@field public finish                 lsp.Position
---@field public prefix                 string
---@field public text                   string
---@field public cursor_offset          ?integer

---@class era.m.cmp.editor.IRepeat
---@field public bufnr                  integer
---@field public winnr                  integer
---@field public changedtick            integer
---@field public cursor                 integer[]
---@field public generation             integer
---@field public completed              table
---@field public tail                   string
---@field public cursor_offset          integer
---@field public cursor_mark            ?integer
---@field public body_mark              ?integer
---@field public body                   ?string

---@class era.m.cmp.editor.ITracker
---@field public rebase                 fun(edits: lsp.TextEdit[]): lsp.TextEdit[]|nil
---@field public close                  fun(): nil

---@param state                         era.m.cmp.editor.IRepeat
---@return boolean
local function repeat_is_current(state)
  if
    state.generation ~= repeat_generation
    or vim.fn.mode(1):match("^i") == nil
    or vim.api.nvim_get_current_buf() ~= state.bufnr
    or vim.api.nvim_get_current_win() ~= state.winnr
  then
    return false
  end
  local cursor = vim.api.nvim_win_get_cursor(0)
  local changedtick = vim.api.nvim_buf_get_changedtick(state.bufnr)
  if changedtick == state.changedtick then
    return vim.deep_equal(cursor, state.cursor)
  end
  local anchor = vim.api.nvim_buf_get_extmark_by_id(state.bufnr, namespace, state.cursor_mark, {})
  local range = vim.api.nvim_buf_get_extmark_by_id(state.bufnr, namespace, state.body_mark, { details = true })
  if #anchor ~= 2 or #range ~= 3 or range[3].invalid or cursor[1] ~= anchor[1] + 1 or cursor[2] ~= anchor[2] then
    return false
  end
  local text = vim.api.nvim_buf_get_text(state.bufnr, range[1], range[2], range[3].end_row, range[3].end_col, {})
  if table.concat(text, "\n") ~= state.body then
    return false
  end
  state.cursor = cursor
  state.changedtick = changedtick
  return true
end

---@param state                         ?era.m.cmp.editor.IRepeat
---@return nil
local function release_repeat(state)
  if state == nil then
    return
  end
  if vim.api.nvim_buf_is_valid(state.bufnr) then
    if state.cursor_mark ~= nil then
      pcall(vim.api.nvim_buf_del_extmark, state.bufnr, namespace, state.cursor_mark)
    end
    if state.body_mark ~= nil then
      pcall(vim.api.nvim_buf_del_extmark, state.bufnr, namespace, state.body_mark)
    end
  end
  state.cursor_mark = nil
  state.body_mark = nil
end

---@return nil
local function finish_repeat()
  local state = pending_repeat
  pending_repeat = nil
  if
    state == nil
    or (
      vim.tbl_get(vim.v.completed_item, "user_data", "era_cmp_repeat") ~= state.generation
      and not vim.deep_equal(vim.v.completed_item, state.completed)
    )
  then
    release_repeat(state)
    return
  end
  vim.api.nvim_set_vvar("completed_item", state.completed)
  if not repeat_is_current(state) then
    release_repeat(state)
    return
  end
  if state.tail ~= "" then
    local paste = vim.paste
    vim.paste = function()
      return true
    end
    local ok, result = pcall(vim.api.nvim_paste, state.tail, false, -1)
    vim.paste = paste
    if not ok or not result then
      release_repeat(state)
      stl.reporter.warn({
        from = __module_name__,
        subject = "repeat",
        message = "Failed to record multiline completion repeat.",
        details = result,
      })
      return
    end
  end
  if state.cursor_offset ~= 0 then
    pending_cursor = state
    vim.api.nvim_feedkeys(vim.keycode(REPEAT_CURSOR), "in", false)
  else
    release_repeat(state)
  end
end

---@return string
local function repeat_cursor()
  local state = pending_cursor
  pending_cursor = nil
  if state == nil or not repeat_is_current(state) then
    release_repeat(state)
    return ""
  end
  local line = vim.api.nvim_get_current_line()
  local prefix_chars = vim.fn.strchars(line:sub(1, state.cursor[2]), true)
  cursor_target = { state.cursor[1], vim.fn.byteidx(line, prefix_chars + state.cursor_offset) }
  release_repeat(state)
  local direction = state.cursor_offset > 0 and "<Left>" or "<Right>"
  return "<Cmd>lua require('era.m.cmp.editor').repeat_end()<CR>"
    .. string.rep("<C-g>U" .. direction, math.abs(state.cursor_offset))
end

---@return nil
local function bind_repeat_keys()
  if repeat_keys_bound then
    return
  end
  repeat_keys_bound = true
  local modes = { "i", "n", "s", "x", "c", "t", "o" } ---@type string[]
  ---@type stl.t.IKeymap[]
  local keymaps = {
    { modes = modes, key = REPEAT_FINISH, callback = finish_repeat },
    { modes = modes, key = REPEAT_CURSOR, expr = true, callback = repeat_cursor },
  }
  nvim.bindkeys(keymaps, { noremap = true, silent = true })
end

---@param left                          lsp.Position
---@param right                         lsp.Position
---@return integer
local function compare_position(left, right)
  if left.line ~= right.line then
    return left.line < right.line and -1 or 1
  end
  if left.character == right.character then
    return 0
  end
  return left.character < right.character and -1 or 1
end

---@param position                      lsp.Position
---@param range                         lsp.Range
---@param final_end                     lsp.Position
---@return lsp.Position
local function transform_after(position, range, final_end)
  if position.line == range["end"].line then
    return {
      line = final_end.line,
      character = final_end.character + position.character - range["end"].character,
    }
  end
  return {
    line = position.line + final_end.line - range["end"].line,
    character = position.character,
  }
end

---@param edits                         ?lsp.TextEdit[]
---@param range                         lsp.Range
---@param final_end                     lsp.Position
---@return lsp.TextEdit[]|nil
local function transform_text_edits(edits, range, final_end)
  if edits == nil then
    return nil
  end
  local transformed = {} ---@type lsp.TextEdit[]
  for index, edit in ipairs(edits) do
    local edit_range = edit.range
    local copied = vim.deepcopy(edit) ---@type lsp.TextEdit
    if compare_position(edit_range["end"], range.start) <= 0 then
      transformed[index] = copied
    elseif compare_position(edit_range.start, range["end"]) >= 0 then
      copied.range.start = transform_after(edit_range.start, range, final_end)
      copied.range["end"] = transform_after(edit_range["end"], range, final_end)
      transformed[index] = copied
    else
      error("additional text edit overlaps the primary completion edit", 0)
    end
  end
  return transformed
end

---@param edits                         ?lsp.TextEdit[]
---@param primary                       lsp.Range
---@return nil
local function validate_text_edits(edits, primary)
  if edits == nil then
    return
  end
  local ranges = {} ---@type lsp.Range[]
  for _, edit in ipairs(edits) do
    local range = edit.range
    if compare_position(range.start, range["end"]) > 0 then
      error("invalid additional text edit range", 0)
    end
    if compare_position(range["end"], primary.start) > 0 and compare_position(range.start, primary["end"]) < 0 then
      error("additional text edit overlaps the primary completion edit", 0)
    end
    ranges[#ranges + 1] = range
  end
  table.sort(ranges, function(left, right)
    return compare_position(left.start, right.start) < 0
  end)
  for index = 2, #ranges do
    if compare_position(ranges[index - 1]["end"], ranges[index].start) > 0 then
      error("additional text edits overlap", 0)
    end
  end
end

---@class era.m.cmp.editor
local M = { transform = transform_text_edits, validate = validate_text_edits }

---@param bufnr                         integer
---@param protected                     lsp.Range
---@return era.m.cmp.editor.ITracker
function M.track(bufnr, protected)
  local active = true
  local changes = {} ---@type { range: lsp.Range, finish: lsp.Position }[]
  local guard = vim.deepcopy(protected)
  ---@return nil
  local function close()
    active = false
    changes = {}
  end
  local attached = vim.api.nvim_buf_attach(bufnr, false, {
    on_bytes = function(_, _, _, row, col, _, old_rows, old_col, _, new_rows, new_col)
      if not active then
        return true
      end
      local range = {
        start = { line = row, character = col },
        ["end"] = { line = row + old_rows, character = old_rows == 0 and col + old_col or old_col },
      }
      local finish = { line = row + new_rows, character = new_rows == 0 and col + new_col or new_col }
      if #changes >= 256 then
        close()
        return true
      end
      if compare_position(guard["end"], range.start) <= 0 then
        changes[#changes + 1] = { range = range, finish = finish }
      elseif compare_position(guard.start, range["end"]) >= 0 then
        guard.start = transform_after(guard.start, range, finish)
        guard["end"] = transform_after(guard["end"], range, finish)
        changes[#changes + 1] = { range = range, finish = finish }
      else
        close()
        return true
      end
    end,
    on_reload = close,
    on_detach = close,
  })
  if not attached then
    close()
  end
  ---@param edits                       lsp.TextEdit[]
  ---@return lsp.TextEdit[]|nil
  local function rebase(edits)
    if not active then
      return nil
    end
    local ok, result = pcall(function()
      local rebased = edits
      for _, change in ipairs(changes) do
        rebased = transform_text_edits(rebased, change.range, change.finish)
      end
      return rebased
    end)
    return ok and result or nil
  end
  return { rebase = rebase, close = close }
end

---@return nil
function M.repeat_end()
  local target = cursor_target
  cursor_target = nil
  if target ~= nil then
    vim.api.nvim_win_set_cursor(0, target)
  end
end

---@param base                          era.m.cmp.editor.IBase
---@return nil
function M.restore(base)
  local line = vim.api.nvim_buf_get_lines(base.bufnr, base.row, base.row + 1, false)[1]
  if line ~= base.line then
    vim.api.nvim_buf_set_lines(base.bufnr, base.row, base.row + 1, false, { base.line })
  end
  vim.api.nvim_win_set_cursor(0, { base.row + 1, base.col })
end

---@param bufnr                         integer
---@return nil
function M.undo_point(bufnr)
  local levels = vim.api.nvim_get_option_value("undolevels", { buf = bufnr })
  vim.api.nvim_set_option_value("undolevels", levels, { buf = bufnr })
end

---@param base                          era.m.cmp.editor.IBase
---@param start_col                     integer
---@param end_col                       integer
---@param text                          string
---@param col                           integer
---@return era.m.cmp.editor.IApplied
function M.preview(base, start_col, end_col, text, col)
  if base.line:sub(start_col + 1, end_col) ~= text then
    vim.api.nvim_buf_set_text(base.bufnr, base.row, start_col, base.row, end_col, { text })
  end
  vim.api.nvim_win_set_cursor(0, { base.row + 1, col })
  return {
    bufnr = base.bufnr,
    prefix = base.line:sub(start_col + 1, base.col),
    text = text:sub(1, col - start_col),
    finish = { line = base.row, character = col },
    cursor_offset = 0,
  }
end

---@param applied                       era.m.cmp.editor.IApplied
---@param completed                     table
---@return boolean
---@return any
function M.record(applied, completed)
  if
    not vim.fn.mode(1):match("^i")
    or vim.fn.getcmdwintype() ~= ""
    or applied.prefix:find("[\r\n]")
    or applied.cursor_offset == nil
    or vim.api.nvim_get_current_buf() ~= applied.bufnr
  then
    return false, nil
  end
  bind_repeat_keys()
  repeat_generation = repeat_generation + 1
  release_repeat(pending_repeat)
  release_repeat(pending_cursor)
  pending_repeat = nil
  pending_cursor = nil
  cursor_target = nil
  local first_line = applied.text:match("^[^\n]*")
  local state = {
    bufnr = applied.bufnr,
    winnr = vim.api.nvim_get_current_win(),
    changedtick = vim.api.nvim_buf_get_changedtick(applied.bufnr),
    cursor = vim.api.nvim_win_get_cursor(0),
    generation = repeat_generation,
    completed = completed,
    tail = applied.text:sub(#first_line + 1),
    cursor_offset = applied.cursor_offset,
  } ---@type era.m.cmp.editor.IRepeat
  local shadow_bufnr = nil ---@type integer|nil
  local eventignore = vim.api.nvim_get_option_value("eventignore", { scope = "global" })
  vim.api.nvim_set_option_value("eventignore", "all", { scope = "global" })
  local ok, recorded = xpcall(function()
    local lines = vim.split(applied.text, "\n", { plain = true })
    local last_row = state.cursor[1] - 1
    local line = vim.api.nvim_get_current_line()
    local end_col = vim.fn.byteidx(line, vim.fn.strchars(line:sub(1, state.cursor[2]), true) + state.cursor_offset)
    local first_row = last_row - #lines + 1
    if first_row < 0 or end_col < 0 then
      return false
    end
    local first_text = vim.api.nvim_buf_get_lines(state.bufnr, first_row, first_row + 1, false)[1]
    local start_col = #lines == 1 and end_col - #lines[1] or #first_text - #lines[1]
    if start_col < 0 then
      return false
    end
    state.body = applied.text .. line:sub(end_col + 1, state.cursor[2])
    local body =
      vim.api.nvim_buf_get_text(state.bufnr, first_row, start_col, last_row, math.max(end_col, state.cursor[2]), {})
    if table.concat(body, "\n") ~= state.body then
      return false
    end
    state.body_mark = vim.api.nvim_buf_set_extmark(state.bufnr, namespace, first_row, start_col, {
      end_row = last_row,
      end_col = math.max(end_col, state.cursor[2]),
      right_gravity = true,
      end_right_gravity = false,
      invalidate = true,
      undo_restore = false,
    })
    state.cursor_mark =
      vim.api.nvim_buf_set_extmark(state.bufnr, namespace, last_row, state.cursor[2], { right_gravity = false })
    shadow_bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_call(shadow_bufnr, function()
      vim.api.nvim_set_option_value("completeopt", "", { buf = shadow_bufnr })
      vim.api.nvim_buf_set_lines(shadow_bufnr, 0, -1, false, { "_" .. applied.prefix })
      vim.api.nvim_win_set_cursor(0, { 1, #applied.prefix + 1 })
      vim.fn.complete(1, { { word = "_" .. first_line, user_data = { era_cmp_repeat = state.generation } } })
    end)
    return true
  end, debug.traceback)
  local cleaned, cleanup_error = true, nil
  if shadow_bufnr ~= nil and vim.api.nvim_buf_is_valid(shadow_bufnr) then
    cleaned, cleanup_error = pcall(vim.api.nvim_buf_delete, shadow_bufnr, { force = true })
  end
  vim.api.nvim_set_option_value("eventignore", eventignore, { scope = "global" })
  if not ok or not cleaned then
    release_repeat(state)
    return false, not ok and recorded or cleanup_error
  end
  if not recorded then
    release_repeat(state)
    return false, nil
  end
  pending_repeat = state
  vim.api.nvim_set_vvar("completed_item", completed)
  vim.api.nvim_feedkeys(vim.keycode(REPEAT_FINISH), "in", false)
  return true, nil
end

---@param base                          era.m.cmp.editor.IBase
---@param start                         lsp.Position
---@param suffix_bytes                  integer
---@param text                          string
---@param snippet                       boolean
---@param cursor_offset                 ?integer
---@return era.m.cmp.editor.IApplied
function M.apply(base, start, suffix_bytes, text, snippet, cursor_offset)
  local bufnr = base.bufnr
  local end_col = math.min(base.col + suffix_bytes, #base.line)
  local prefix =
    table.concat(vim.api.nvim_buf_get_text(bufnr, start.line, start.character, base.row, base.col, {}), "\n")
  local tail = vim.api.nvim_buf_set_extmark(bufnr, namespace, base.row, end_col, { right_gravity = true })
  local ok, result = xpcall(function()
    if snippet then
      vim.api.nvim_buf_set_text(bufnr, start.line, start.character, base.row, end_col, {})
      vim.api.nvim_win_set_cursor(0, { start.line + 1, start.character })
      vim.snippet.expand(text)
    else
      vim.api.nvim_buf_set_text(
        bufnr,
        start.line,
        start.character,
        base.row,
        end_col,
        vim.split(text, "\n", { plain = true })
      )
    end
    local position = vim.api.nvim_buf_get_extmark_by_id(bufnr, namespace, tail, {})
    if #position ~= 2 then
      error("completion tail mark was lost", 0)
    end
    if not snippet or cursor_offset ~= nil and cursor_offset ~= 0 and not vim.snippet.active() then
      local target_col = position[2]
      if cursor_offset ~= nil and cursor_offset ~= 0 then
        local line = vim.api.nvim_buf_get_lines(bufnr, position[1], position[1] + 1, false)[1]
        target_col = vim.fn.byteidx(line, vim.fn.strchars(line:sub(1, target_col), true) + cursor_offset)
        if target_col < 0 then
          error("completion cursor is outside the insertion line", 0)
        end
      end
      vim.api.nvim_win_set_cursor(0, { position[1] + 1, target_col })
    end
    local cursor = vim.api.nvim_win_get_cursor(0)
    local cursor_offset = nil
    if cursor[1] == position[1] + 1 and not (snippet and vim.snippet.active()) then
      local line = vim.api.nvim_get_current_line()
      cursor_offset = cursor[2] <= position[2] and vim.fn.strchars(line:sub(cursor[2] + 1, position[2]), true)
        or -vim.fn.strchars(line:sub(position[2] + 1, cursor[2]), true)
    end
    return {
      bufnr = bufnr,
      finish = { line = position[1], character = position[2] },
      prefix = prefix,
      text = table.concat(
        vim.api.nvim_buf_get_text(bufnr, start.line, start.character, position[1], position[2], {}),
        "\n"
      ),
      cursor_offset = cursor_offset,
    }
  end, debug.traceback)
  pcall(vim.api.nvim_buf_del_extmark, bufnr, namespace, tail)
  if not ok then
    error(result, 0)
  end
  return result
end

---@param applied                       era.m.cmp.editor.IApplied
---@param text                          string
---@param cursor_offset                 integer
---@return era.m.cmp.editor.IApplied
function M.extend(applied, text, cursor_offset)
  local cursor = vim.api.nvim_win_get_cursor(0)
  local base = {
    bufnr = applied.bufnr,
    row = cursor[1] - 1,
    col = cursor[2],
    line = vim.api.nvim_get_current_line(),
  }
  vim.api.nvim_cmd({ cmd = "undojoin" }, {})
  local extended = M.apply(base, { line = base.row, character = base.col }, 0, text, false, cursor_offset)
  extended.prefix = applied.text
  extended.text = applied.text .. extended.text
  return extended
end

return M

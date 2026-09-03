---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.cmp.cmdline" ---@type string

local label_highlight = require("era.m.cmp.label")
local list = require("era.m.cmp.list")
local cmdline_surface = require("era.m.ui_attach.cmdline")
local popupmenu = require("era.m.ui_attach.popupmenu")

local M = {}
local OWNER = "era-cmp-cmdline"
local MAX_ITEMS = 200
local PATH_TYPES = {
  dir = true,
  dir_in_path = true,
  file = true,
  file_in_path = true,
  runtime = true,
}
local SOURCE_BADGES = {
  buffer = { "[buf]", "String" },
  command = { "[cmd]", "Keyword" },
  environment = { "[env]", "Constant" },
  help = { "[help]", "Special" },
  mapping = { "[map]", "Operator" },
  option = { "[opt]", "Type" },
  shellcmd = { "[shell]", "Function" },
}
local options = vim.api.nvim_get_all_options_info()
local modifiers = {
  ["."] = "relative to current directory",
  ["S"] = "escape for shell",
  e = "extension",
  gs = "substitute all occurrences",
  h = "directory (head)",
  p = "full path",
  r = "basename (root, no ext)",
  s = "substitute first occurrence",
  t = "filename (tail)",
  ["~"] = "relative to home directory",
}
local CMDLINE_KIND = stl.icon.kind.Property

---@param completion_type               string
---@param path                          boolean
---@return string
---@return string
local function source_badge(completion_type, path)
  if path then
    return "[path]", "Directory"
  end
  if completion_type == "" then
    completion_type = "command"
  elseif completion_type:match("^custom") then
    return "[custom]", "Special"
  end
  local badge = SOURCE_BADGES[completion_type]
  return badge and badge[1] or string.format("[%s]", completion_type), badge and badge[2] or "Type"
end

---@class era.m.cmp.cmdline.ICandidate
---@field public label                  string
---@field public filter_text            string
---@field public insert_text            string
---@field public directory              boolean
---@field public description            string

---@class era.m.cmp.cmdline.ICache
---@field public key                    string
---@field public candidates             era.m.cmp.cmdline.ICandidate[]
---@field public index                  yoz.cmp.IIndex

---@class era.m.cmp.cmdline.ISession
---@field public generation             integer
---@field public line                   string
---@field public pos                    integer 0-indexed byte column
---@field public base_line              string
---@field public base_pos               integer 0-indexed byte column
---@field public replace_start          integer 0-indexed inclusive
---@field public replace_end            integer 0-indexed exclusive
---@field public candidates             era.m.cmp.cmdline.ICandidate[]
---@field public order                  integer[] candidate indices
---@field public rows                   string[][]
---@field public selected               integer 0-indexed ranked row, -1 is base input
---@field public preview_line           string|nil
---@field public preview_pos            integer|nil 1-indexed setcmdline position
---@field public cmdwin                 boolean
---@field public bufnr                  integer|nil
---@field public row                    integer|nil 0-indexed

local cache = nil ---@type era.m.cmp.cmdline.ICache|nil
local session = nil ---@type era.m.cmp.cmdline.ISession|nil
local generation = 0
local expected_line = nil ---@type string|nil
local expected_pos = nil ---@type integer|nil
local refresh_scheduled = false
local dressed = false

local function next_generation()
  generation = generation + 1
  return generation
end

---@return boolean
function M.in_cmdwin()
  return vim.fn.win_gettype() == "command"
end

---@param value                         string
---@return string
local function path_label(value)
  return value:match("([^/\\]+[/\\]?)$") or value
end

---@param value                         string
---@return string
local function sanitize_mapping(value)
  value = value:gsub("\22", "")
  return vim.fn.keytrans(value):gsub("<lt>", "<")
end

---@param value                         string
---@return string
local function escape_path(value)
  value = vim.fn.fnameescape(value)
  value = value:gsub("\\(%$[%w_]+)", "%1")
  value = value:gsub("\\(%${[%w_]+})", "%1")
  return value:gsub("\\(%%:)", "%1")
end

---@param name                          string
---@param pattern                       string
---@param line                          string
---@param pos                           integer 1-indexed
---@return boolean
---@return table|string|nil
local function call_custom(name, pattern, line, pos)
  local expression = name:gsub("^v:lua%.", "")
  if name:match("^v:lua%.") and not expression:find("[^%w_.]") then
    local parts = vim.split(expression, ".", { plain = true })
    local target = _G ---@type any
    for index = 1, #parts - 1 do
      target = type(target) == "table" and target[parts[index]] or nil
      if target == nil then
        break
      end
    end
    local callback = type(target) == "table" and target[parts[#parts]] or nil
    if type(callback) == "function" then
      return pcall(callback, pattern, line, pos)
    end
  end
  return pcall(vim.fn.call, name, { pattern, line, pos })
end

---@param value                         string
---@param completion_type               string
---@param path                          boolean
---@return era.m.cmp.cmdline.ICandidate
local function candidate(value, completion_type, path)
  local label = path and path_label(value) or value
  local insert_text = value
  if path then
    insert_text = escape_path(value)
  elseif completion_type == "mapping" then
    label = sanitize_mapping(value)
    insert_text = label
  elseif completion_type == "environment" then
    label = "$" .. value
    insert_text = label
  end
  label = label_highlight.display(label)
  return {
    label = label,
    filter_text = label,
    insert_text = insert_text,
    directory = value:match("[/\\]$") ~= nil,
    description = "",
  }
end

---@param context                       table
---@return era.m.cmp.cmdline.ICache|nil
local function modifier_cache(context)
  local expression, query = context.pattern:match("^([%%#].*:)([^:]*)$")
  if expression == nil then
    return nil
  end

  local candidates = {} ---@type era.m.cmp.cmdline.ICandidate[]
  local texts = {} ---@type string[]
  for modifier, description in pairs(modifiers) do
    local expanded = vim.fn.expand(expression .. modifier) ---@type string
    if expanded ~= "" then
      candidates[#candidates + 1] = {
        label = modifier,
        filter_text = modifier,
        insert_text = escape_path(expanded),
        directory = false,
        description = description,
      }
      texts[#texts + 1] = modifier
    end
  end
  if #candidates == 0 then
    return nil
  end
  context.query = query
  context.cache_key = table.concat({ "modifier", expression }, "\0")
  return { key = context.cache_key, candidates = candidates, index = yoz.cmp.index(texts, nil, nil, true) }
end

---@param value                         string
---@return integer
local function argument_start(value)
  local start_col = 0
  local quote = nil ---@type string|nil
  local escaped = false
  for index = 1, #value do
    local char = value:sub(index, index)
    if escaped then
      escaped = false
    elseif char == "\\" then
      escaped = true
    elseif quote ~= nil then
      if char == quote then
        quote = nil
        start_col = index
      end
    elseif char == '"' or char == "'" then
      quote = char
      start_col = index
    elseif char:match("%s") then
      start_col = index
    end
  end
  return start_col
end

---@param line                          string
---@param pos                           integer
---@param cmdwin                        boolean
---@return { completion_type: string, pattern: string, replace_start: integer, replace_end: integer, query: string, enumerate: string, cache_key: string, path: boolean, line: string, pos: integer, cmdtype: string }|nil
local function ex_context(line, pos, cmdwin)
  local before = line:sub(1, pos)
  local completion_type = nil ---@type string|nil
  if cmdwin then
    local ok, value = pcall(vim.fn.getcompletiontype, before)
    completion_type = ok and value or nil
  else
    completion_type = vim.fn.getcmdcompltype()
  end
  if type(completion_type) ~= "string" then
    return nil
  end
  local path = PATH_TYPES[completion_type] == true
  local pattern = nil ---@type string|nil
  local replace_start = nil ---@type integer|nil
  if cmdwin then
    replace_start = path and argument_start(before) or yoz.cmp.keyword_range(before, pos, false)
    pattern = before:sub(replace_start + 1)
  else
    pattern = vim.fn.getcmdcomplpat()
    replace_start = pos - #pattern
  end
  if type(pattern) ~= "string" or pos < #pattern then
    return nil
  end

  local enumerate = ""
  local query = pattern
  local stable_prefix = line:sub(1, replace_start)
  if path then
    enumerate = pattern:match("^(.*[/\\])") or ""
    query = pattern:sub(#enumerate + 1)
  elseif completion_type == "" or completion_type:match("^custom") then
    enumerate = line:sub(1, pos)
  end

  return {
    completion_type = completion_type,
    pattern = pattern,
    replace_start = replace_start,
    replace_end = pos,
    query = query,
    enumerate = enumerate,
    cache_key = table.concat({ completion_type, stable_prefix, enumerate, tostring(path) }, "\0"),
    path = path,
    line = line,
    pos = pos,
    cmdtype = cmdwin and vim.fn.getcmdwintype() or vim.fn.getcmdtype(),
  }
end

---@param line                          string
---@param pos                           integer
---@param cmdtype                       string
---@return { completion_type: string, pattern: string, replace_start: integer, replace_end: integer, query: string, enumerate: string, cache_key: string, path: boolean, line: string, pos: integer, cmdtype: string }|nil
local function search_context(line, pos, cmdtype)
  local start_col = yoz.cmp.keyword_range(line, pos, false) ---@type integer
  local query = line:sub(start_col + 1, pos)
  return {
    completion_type = "buffer",
    pattern = query,
    replace_start = start_col,
    replace_end = pos,
    query = query,
    enumerate = "",
    cache_key = table.concat({ "search", vim.api.nvim_get_current_buf(), vim.api.nvim_buf_get_changedtick(0) }, "\0"),
    path = false,
    line = line,
    pos = pos,
    cmdtype = cmdtype,
  }
end

---@param context                      table
---@return era.m.cmp.cmdline.ICache|nil
local function build_cache(context)
  local special = modifier_cache(context)
  if special ~= nil then
    return special
  end
  local raw = nil ---@type string[]|nil
  if context.completion_type == "buffer" and context.cmdtype:match("^[/?]$") then
    raw = yoz.cmp.words(table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n"), 2000)
  elseif context.completion_type:match("^custom") then
    local completion = vim.split(context.completion_type, ",", { plain = true })
    local name = completion[2]
    if type(name) == "string" and name ~= "" and not name:lower():match("^s:") and not name:lower():match("^<sid>") then
      local ok, values = call_custom(name, context.pattern, context.line, context.pos + 1)
      if ok and type(values) == "table" then
        raw = values
      elseif ok and type(values) == "string" then
        raw = vim.split(values, "\n", { plain = true, trimempty = true })
      end
    end
  else
    local completion_type = context.completion_type
    local completion_query = context.enumerate
    if completion_type == "" then
      completion_type = "cmdline"
    end
    local ok, values = pcall(vim.fn.getcompletion, completion_query, completion_type, true)
    if ok and type(values) == "table" then
      raw = values
    end
  end
  if raw == nil then
    return nil
  end

  local candidates = {} ---@type era.m.cmp.cmdline.ICandidate[]
  local texts = {} ---@type string[]
  local seen = {} ---@type table<string, boolean>
  for _, value in ipairs(raw) do
    if type(value) == "string" and value ~= "" then
      local values = { value }
      local option = context.completion_type == "option" and options[value] or nil
      if option ~= nil and option.type == "boolean" then
        values[2] = "no" .. value
      end
      for _, candidate_value in ipairs(values) do
        local item = candidate(candidate_value, context.completion_type, context.path)
        item.description = option and option.shortname or ""
        local key = item.insert_text .. "\0" .. item.label
        if not seen[key] then
          seen[key] = true
          candidates[#candidates + 1] = item
          texts[#texts + 1] = item.filter_text
        end
      end
    end
  end
  return {
    key = context.cache_key,
    candidates = candidates,
    index = yoz.cmp.index(texts, nil, nil, true),
  }
end

---@param value                         era.m.cmp.cmdline.ISession
---@return string|nil
local function ghost_text(value)
  if value.base_pos ~= value.replace_end then
    return nil
  end
  local candidate_index = value.order[1] ---@type integer|nil
  local item = candidate_index and value.candidates[candidate_index] or nil
  if item == nil then
    return nil
  end
  local typed = value.base_line:sub(value.replace_start + 1, value.base_pos) ---@type string
  local insertion = item.insert_text
  if #typed >= #insertion or insertion:sub(1, #typed):lower() ~= typed:lower() then
    return nil
  end
  return insertion:sub(#typed + 1)
end

---@param value                         era.m.cmp.cmdline.ISession
local function present(value)
  if #value.rows == 0 then
    cmdline_surface.set_ghost(nil)
    popupmenu.dismiss(OWNER)
    return
  end
  if value.cmdwin then
    local position = vim.fn.screenpos(0, assert(value.row) + 1, value.replace_start + 1) ---@type table
    popupmenu.present(
      OWNER,
      value.generation,
      value.rows,
      value.selected,
      math.max(0, (position.row or 1) - 1),
      math.max(0, (position.col or value.replace_start + 1) - 1),
      0
    )
  else
    popupmenu.present(OWNER, value.generation, value.rows, value.selected, 0, value.replace_start, -1)
  end
  cmdline_surface.set_ghost(ghost_text(value))
end

---@param value                         era.m.cmp.cmdline.ISession
---@return string
---@return integer 0-indexed
local function current_input(value)
  if value.cmdwin then
    return vim.api.nvim_get_current_line(), vim.api.nvim_win_get_cursor(0)[2]
  end
  return vim.fn.getcmdline(), vim.fn.getcmdpos() - 1
end

---@param value                         era.m.cmp.cmdline.ISession
---@param line                          string
---@param pos                           integer 0-indexed
---@param ghost                         string|nil
---@param preview?                      boolean
local function set_input(value, line, pos, ghost, preview)
  expected_line = line
  expected_pos = pos + 1
  if value.cmdwin then
    vim.api.nvim_set_current_line(line)
    vim.api.nvim_win_set_cursor(0, { assert(value.row) + 1, pos })
  else
    vim.fn.setcmdline(line, pos + 1)
    -- Programmatic cmdline edits do not update the external UI eagerly. A
    -- preview keeps the popup anchor stable and lets the input loop flush both
    -- surfaces after their state has been updated.
    if preview then
      cmdline_surface.sync_preview(line, pos + 1, ghost)
    else
      cmdline_surface.sync(line, pos + 1, ghost)
    end
  end
end

---@param value                         era.m.cmp.cmdline.ISession
---@param selected                      integer
local function apply_preview(value, selected)
  local line = value.base_line
  local pos = value.base_pos
  if selected >= 0 then
    local candidate_index = value.order[selected + 1] ---@type integer|nil
    local item = candidate_index and value.candidates[candidate_index] or nil
    if item == nil then
      return
    end
    line = value.base_line:sub(1, value.replace_start) .. item.insert_text .. value.base_line:sub(value.replace_end + 1)
    pos = value.replace_start + #item.insert_text
  end

  value.selected = selected
  value.preview_line = line
  value.preview_pos = pos + 1
  local ghost = selected < 0 and ghost_text(value) or nil ---@type string|nil
  set_input(value, line, pos, ghost, true)
  popupmenu.select_owned(OWNER, value.generation, selected, false)
end

---@return boolean
function M.visible()
  return session ~= nil and popupmenu.visible(OWNER, session.generation)
end

---@param direction                    -1|1
---@return boolean
function M.move(direction)
  local value = session
  if value == nil or #value.order == 0 then
    return false
  end
  apply_preview(value, list.move(value.selected, #value.order, direction))
  return true
end

---@param direction                    -1|1
---@return boolean
function M.show(direction)
  local value = session
  if value ~= nil then
    local line, pos = current_input(value)
    local base = line == value.base_line and pos == value.base_pos
    local preview = line == value.preview_line and pos + 1 == value.preview_pos
    if not base and not preview then
      M.refresh()
    end
  else
    M.refresh()
  end
  return M.move(direction)
end

---@param index?                        integer 1-indexed ranked row
---@return boolean
function M.accept(index)
  local value = session
  if value == nil or #value.order == 0 then
    return false
  end
  local selected = index and list.resolve(index, #value.order) or value.selected
  if selected == nil then
    return false
  end
  if selected < 0 then
    selected = 0
    apply_preview(value, selected)
  end
  local candidate_index = value.order[selected + 1] ---@type integer|nil
  local item = candidate_index and value.candidates[candidate_index] or nil
  if item == nil then
    return false
  end

  session = nil
  cmdline_surface.set_ghost(nil)
  popupmenu.dismiss(OWNER, value.generation)
  if item.directory then
    expected_line = nil
    expected_pos = nil
    vim.schedule(M.refresh)
  end
  return true
end

---@return boolean
function M.cancel()
  local value = session
  if value == nil then
    return false
  end
  local line = current_input(value)
  if value.preview_line ~= nil and line == value.preview_line then
    set_input(value, value.base_line, value.base_pos, nil)
  end
  session = nil
  cmdline_surface.set_ghost(nil)
  popupmenu.dismiss(OWNER, value.generation)
  return true
end

function M.leave()
  local value = session
  session = nil
  cache = nil
  expected_line = nil
  expected_pos = nil
  cmdline_surface.set_ghost(nil)
  if value ~= nil then
    popupmenu.dismiss(OWNER, value.generation)
  else
    popupmenu.dismiss(OWNER)
  end
end

function M.refresh()
  local cmdwin = M.in_cmdwin()
  if vim.api.nvim_get_mode().mode ~= "c" and not cmdwin then
    return
  end
  local cmdtype = cmdwin and vim.fn.getcmdwintype() or vim.fn.getcmdtype() ---@type string
  if not cmdtype:match("^[:/?@]$") then
    M.leave()
    return
  end

  local line = cmdwin and vim.api.nvim_get_current_line() or vim.fn.getcmdline() ---@type string
  local cursor = cmdwin and vim.api.nvim_win_get_cursor(0) or nil ---@type integer[]|nil
  local pos = cursor and cursor[2] or vim.fn.getcmdpos() - 1 ---@type integer
  if line == expected_line and pos + 1 == expected_pos then
    expected_line = nil
    expected_pos = nil
    return
  end
  expected_line = nil
  expected_pos = nil

  local context = (cmdtype == ":" or cmdtype == "@") and ex_context(line, pos, cmdwin)
    or search_context(line, pos, cmdtype)
  if context == nil then
    M.leave()
    return
  end
  if cache == nil or cache.key ~= context.cache_key then
    cache = build_cache(context)
  end
  if cache == nil or #cache.candidates == 0 then
    M.leave()
    return
  end

  local order = cache.index:rank(context.query, nil, nil, MAX_ITEMS) ---@type integer[]
  if #order == 0 then
    M.leave()
    return
  end
  local rows = {} ---@type string[][]
  local labels = {} ---@type string[]
  local source, source_hlgroup = source_badge(context.completion_type, context.path) ---@type string, string
  for index, candidate_index in ipairs(order) do
    local item = cache.candidates[candidate_index]
    labels[index] = item.label
    rows[index] = { item.label, CMDLINE_KIND, source, "", item.description, "Identifier", nil, source_hlgroup }
  end
  local matched_ranges = yoz.cmp.matched_ranges(context.query, labels) ---@type integer[][]
  local highlights = label_highlight.matches(matched_ranges)
  for index = 1, #rows do
    rows[index][7] = highlights[index]
  end

  local value = {
    generation = next_generation(),
    line = line,
    pos = pos,
    base_line = line,
    base_pos = pos,
    replace_start = context.replace_start,
    replace_end = context.replace_end,
    candidates = cache.candidates,
    order = order,
    rows = rows,
    selected = -1,
    preview_line = nil,
    preview_pos = nil,
    cmdwin = cmdwin,
    bufnr = cmdwin and vim.api.nvim_get_current_buf() or nil,
    row = cursor and cursor[1] - 1 or nil,
  } ---@type era.m.cmp.cmdline.ISession
  session = value
  present(value)
end

local function schedule_auto_refresh()
  local cmdwin = M.in_cmdwin()
  local cmdtype = cmdwin and vim.fn.getcmdwintype() or vim.fn.getcmdtype() ---@type string
  if (cmdtype == ":" or session ~= nil) and not refresh_scheduled then
    refresh_scheduled = true
    vim.schedule(function()
      refresh_scheduled = false
      M.refresh()
    end)
  end
end

function M.dressing()
  if dressed then
    return
  end
  dressed = true
  local augroup = stl.nvim.fn.augroup(__module_name__ .. ".dressing")
  vim.api.nvim_create_autocmd("CmdlineChanged", {
    group = augroup,
    callback = schedule_auto_refresh,
  })
  vim.api.nvim_create_autocmd("CmdlineLeave", {
    group = augroup,
    callback = M.leave,
  })
  vim.api.nvim_create_autocmd({ "TextChangedI", "TextChangedP", "CursorMovedI", "CmdwinEnter" }, {
    group = augroup,
    callback = function()
      if M.in_cmdwin() then
        schedule_auto_refresh()
      end
    end,
  })
  vim.api.nvim_create_autocmd("CmdwinLeave", {
    group = augroup,
    callback = M.leave,
  })
  vim.api.nvim_create_autocmd("InsertLeave", {
    group = augroup,
    callback = function()
      if M.in_cmdwin() then
        M.leave()
      end
    end,
  })
end

return M

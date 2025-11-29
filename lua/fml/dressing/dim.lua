---@see https://github.com/folke/snacks.nvim/blob/fe7cfe9800a182274d0f868a74b7263b8c0c020b/lua/snacks/dim.lua

local __module_name__ = "fml.dressing.dim" ---@type string

---@class fml.dressing.dim.IConfig
---@field public min_size               integer
---@field public max_size               integer
---@field public siblings               boolean
---@field public animate                boolean
---@field public duration               integer
---@field public step                   integer
---@field public easing                 string
local config = {
  min_size = 5,
  max_size = 20,
  siblings = true,
  animate = true,
  duration = 300,
  step = 20,
  easing = "outQuad",
}

---@class fml.dressing.dim.IScope
---@field public buf                    integer
---@field public from                   integer
---@field public to                     integer
---@field public indent                 integer

---@class fml.dressing.dim.IListener
---@field public scopes                 table<integer, fml.dressing.dim.IScope>
---@field public scopes_anim            table<integer, { from: integer, to: integer, buf: integer }>
---@field public dirty                  table<integer, boolean>
---@field public timer                  uv.uv_timer_t|nil

local ns = vim.api.nvim_create_namespace(__module_name__)
local augroup = eve.nvim.augroup(__module_name__)
local enabled = false ---@type boolean
local listener = nil ---@type fml.dressing.dim.IListener|nil

---@param bufnr                         integer
---@return boolean
local function is_buf_enabled(bufnr)
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
    return false
  end
  if vim.bo[bufnr].buftype ~= "" then
    return false
  end
  return true
end

---@param line                          integer
---@return integer|nil, integer
local function get_indent(line)
  local ret = vim.fn.indent(line)
  return ret == -1 and nil or ret, line
end

---@param line                          integer
---@param indent                        integer
---@param up                            boolean|nil
---@return integer
local function expand_indent(line, indent, up)
  local next_fn = up and vim.fn.prevnonblank or vim.fn.nextnonblank
  while line do
    local i, l = get_indent(next_fn(line + (up and -1 or 1)))
    if (i or 0) == 0 or i < indent or l == 0 then
      return line
    end
    line = l
  end
  return line
end

---@param bufnr                         integer
---@param pos                           integer[]
---@return fml.dressing.dim.IScope|nil
local function find_indent_scope(bufnr, pos)
  local indent, line = get_indent(pos[1])
  local prev_i, prev_l = get_indent(vim.fn.prevnonblank(line - 1))
  local next_i, next_l = get_indent(vim.fn.nextnonblank(line + 1))

  if vim.fn.prevnonblank(line) ~= line then
    indent, line = get_indent(prev_i > next_i and prev_l or next_l)
    prev_i, prev_l = get_indent(vim.fn.prevnonblank(line - 1))
    next_i, next_l = get_indent(vim.fn.nextnonblank(line + 1))
  end

  if line == 0 then
    return nil
  end

  if indent == nil then
    return nil
  end

  if prev_i and prev_i <= indent and next_i and next_i > indent then
    line = next_l
    indent = next_i
  elseif next_i and next_i <= indent and prev_i and prev_i > indent then
    line = prev_l
    indent = prev_i
  elseif next_i and next_i > indent and prev_i and prev_i > indent then
    line = next_l
    indent = next_i
  end

  ---@type fml.dressing.dim.IScope
  return {
    buf = bufnr,
    from = expand_indent(line, indent --[[@as integer]], true),
    to = expand_indent(line, indent --[[@as integer]], false),
    indent = indent --[[@as integer]],
  }
end

---@param bufnr                         integer
---@param pos                           integer[]
---@return fml.dressing.dim.IScope|nil
local function find_ts_scope(bufnr, pos)
  local lang = vim.treesitter.language.get_lang(vim.bo[bufnr].filetype)
  local line = vim.fn.nextnonblank(pos[1])
  line = line == 0 and vim.fn.prevnonblank(pos[1]) or line

  local ts_pos = {
    math.max(line - 1, 0),
    (vim.fn.getline(line):find("%S") or 1) - 1,
  }

  local node = vim.treesitter.get_node({
    pos = ts_pos,
    bufnr = bufnr,
    lang = lang,
    ignore_injections = false,
  })
  if not node then
    return nil
  end

  local root = node:tree():root()
  while node and node ~= root do
    local from, _, to = node:range()
    from, to = from + 1, to + 1
    local size = to - from + 1
    if size >= config.min_size then
      ---@type fml.dressing.dim.IScope
      return {
        buf = bufnr,
        from = from,
        to = to,
        indent = math.min(vim.fn.indent(from), vim.fn.indent(to)),
      }
    end
    node = node:parent()
  end

  return nil
end

---@param bufnr                         integer
---@param pos                           integer[]
---@return fml.dressing.dim.IScope|nil
local function find_scope(bufnr, pos)
  local has_parser, parser = pcall(vim.treesitter.get_parser, bufnr, nil, { error = false })
  if has_parser and parser then
    pcall(function()
      parser:parse()
    end)
    local scope = find_ts_scope(bufnr, pos)
    if scope then
      return scope
    end
  end
  return find_indent_scope(bufnr, pos)
end

---@param scope                         fml.dressing.dim.IScope
---@return fml.dressing.dim.IScope
local function expand_scope(scope)
  local min_size = config.min_size
  local max_size = config.max_size

  while scope.to - scope.from + 1 < min_size and scope.indent > 0 do
    local u = expand_indent(scope.from, scope.indent - 1, true)
    local d = expand_indent(scope.to, scope.indent - 1, false)
    if u == scope.from and d == scope.to then
      break
    end
    scope = {
      buf = scope.buf,
      from = u,
      to = d,
      indent = scope.indent - 1,
    }
  end

  if config.siblings and scope.to - scope.from + 1 == 1 then
    local pos = { scope.from, 0 }
    while scope.to - scope.from + 1 < min_size do
      local prev = vim.fn.prevnonblank(scope.from - 1)
      local next = vim.fn.nextnonblank(scope.to + 1)
      local prev_dist = math.abs(pos[1] - prev)
      local next_dist = math.abs(pos[1] - next)
      local prev_s = prev > 0 and find_indent_scope(scope.buf, { prev, 0 })
      local next_s = next > 0 and find_indent_scope(scope.buf, { next, 0 })
      prev_s = prev_s and prev_s.to - prev_s.from + 1 == 1 and prev_s or nil
      next_s = next_s and next_s.to - next_s.from + 1 == 1 and next_s or nil
      local s = prev_dist < next_dist and prev_s or next_s or prev_s
      if s and (s.from < scope.from or s.to > scope.to) then
        scope = {
          buf = scope.buf,
          from = math.min(scope.from, s.from),
          to = math.max(scope.to, s.to),
          indent = scope.indent,
        }
      else
        break
      end
    end
  end

  if scope.to - scope.from + 1 > max_size then
    local center = math.floor((scope.from + scope.to) / 2)
    scope = {
      buf = scope.buf,
      from = center - math.floor(max_size / 2),
      to = center + math.ceil(max_size / 2),
      indent = scope.indent,
    }
  end

  return scope
end

---@param winnr                         integer
---@param bufnr                         integer
---@param top                           integer
---@param bottom                        integer
local function on_win(winnr, bufnr, top, bottom)
  if not listener then
    return
  end

  local scope = listener.scopes[winnr]
  if not scope then
    return
  end

  local anim = listener.scopes_anim[winnr]
  local from = config.animate and anim and anim.from or scope.from
  local to = config.animate and anim and anim.to or scope.to

  for l = top, math.min(from - 1, bottom) do
    vim.api.nvim_buf_set_extmark(bufnr, ns, l - 1, 0, {
      end_row = l,
      end_col = 0,
      hl_group = "f_dim",
      ephemeral = true,
    })
  end

  for l = math.max(to + 1, top), bottom do
    vim.api.nvim_buf_set_extmark(bufnr, ns, l - 1, 0, {
      end_row = l,
      end_col = 0,
      hl_group = "f_dim",
      ephemeral = true,
    })
  end
end

---@param winnr                         integer
local function check_scope(winnr)
  if not listener then
    return
  end

  local bufnr = vim.api.nvim_win_is_valid(winnr) and vim.api.nvim_win_get_buf(winnr)
  if not bufnr or not is_buf_enabled(bufnr) then
    listener.scopes[winnr] = nil
    return
  end

  local pos = vim.api.nvim_win_get_cursor(winnr)
  local scope = find_scope(bufnr, pos)
  if scope then
    scope = expand_scope(scope)
  end

  local prev = listener.scopes[winnr]
  if prev and scope and prev.from == scope.from and prev.to == scope.to and prev.buf == scope.buf then
    return
  end

  listener.scopes[winnr] = scope

  if not config.animate or not scope then
    vim.cmd("redraw!")
    return
  end

  local anim = listener.scopes_anim[winnr]
  if not anim or anim.buf ~= bufnr then
    local info = vim.fn.getwininfo(winnr)[1]
    anim = {
      from = info.topline,
      to = info.botline,
      buf = bufnr,
    }
    listener.scopes_anim[winnr] = anim
  end

  local easing_fn = std.easing[config.easing] or std.easing.outQuad
  local duration = config.duration
  local step = config.step
  local total_steps = math.ceil(duration / step)

  local from_start = anim.from
  local to_start = anim.to
  local elapsed = 0

  if listener.timer and not listener.timer:is_closing() then
    listener.timer:stop()
    listener.timer:close()
  end

  local timer = vim.uv.new_timer()
  if not timer then
    return
  end
  listener.timer = timer

  timer:start(0, step, function()
    vim.schedule(function()
      if not listener or listener.timer ~= timer then
        if not timer:is_closing() then
          timer:stop()
          timer:close()
        end
        return
      end

      elapsed = elapsed + 1
      local progress = math.min(elapsed / total_steps, 1)
      local eased = easing_fn(progress * duration, 0, 1, duration)

      anim.from = math.floor(from_start + (scope.from - from_start) * eased)
      anim.to = math.floor(to_start + (scope.to - to_start) * eased)

      if vim.api.nvim_win_is_valid(winnr) then
        vim.cmd("redraw!")
      end

      if progress >= 1 then
        if not timer:is_closing() then
          timer:stop()
          timer:close()
        end
        if listener and listener.timer == timer then
          listener.timer = nil
        end
      end
    end)
  end)
end

---@param wins                          integer[]|nil
local function update(wins)
  if not listener then
    return
  end

  wins = wins or vim.api.nvim_list_wins()
  for _, winnr in ipairs(wins) do
    listener.dirty[winnr] = true
  end

  vim.defer_fn(function()
    if not listener then
      return
    end
    for winnr in pairs(listener.dirty) do
      if vim.api.nvim_win_is_valid(winnr) then
        check_scope(winnr)
      end
    end
    listener.dirty = {}
  end, 30)
end

local function enable()
  if enabled then
    return
  end
  enabled = true

  ---@type fml.dressing.dim.IListener
  listener = {
    scopes = {},
    scopes_anim = {},
    dirty = {},
    timer = nil,
  }

  vim.api.nvim_set_decoration_provider(ns, {
    on_win = function(_, winnr, bufnr, top, bottom)
      if enabled and is_buf_enabled(bufnr) then
        on_win(winnr, bufnr, top + 1, bottom + 1)
      end
    end,
  })

  vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
    group = augroup,
    callback = function(ev)
      for _, winnr in ipairs(vim.fn.win_findbuf(ev.buf)) do
        update({ winnr })
      end
    end,
  })

  vim.api.nvim_create_autocmd({ "WinClosed", "BufDelete", "BufWipeout" }, {
    group = augroup,
    callback = function()
      if listener then
        for winnr in pairs(listener.scopes) do
          if not vim.api.nvim_win_is_valid(winnr) then
            listener.scopes[winnr] = nil
            listener.scopes_anim[winnr] = nil
          end
        end
      end
    end,
  })

  update()
end

local function disable()
  if not enabled then
    return
  end
  enabled = false

  if listener then
    if listener.timer and not listener.timer:is_closing() then
      listener.timer:stop()
      listener.timer:close()
    end
    listener = nil
  end

  vim.api.nvim_clear_autocmds({ group = augroup })
  vim.cmd("redraw!")
end

std.fn.observe({ eve.context.flight.dressing_dim }, function()
  if eve.context.flight.dressing_dim:snapshot() then
    enable()
  else
    disable()
  end
end)

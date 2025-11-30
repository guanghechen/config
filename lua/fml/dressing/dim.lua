---@see https://github.com/folke/snacks.nvim/blob/fe7cfe9800a182274d0f868a74b7263b8c0c020b/lua/snacks/dim.lua

local __module_name__ = "fml.dressing.dim" ---@type string

---@class fml.dressing.dim.IConfig
---@field public animate                boolean
---@field public duration               integer
---@field public step                   integer
---@field public easing                 string
local config = {
  animate = true,
  duration = 300,
  step = 20,
  easing = "outQuad",
}

---@class fml.dressing.dim.IScope
---@field public buf                    integer
---@field public from                   integer
---@field public to                     integer

---@class fml.dressing.dim.IListener
---@field public scopes                 table<integer, fml.dressing.dim.IScope>
---@field public scopes_anim            table<integer, { from: integer, to: integer, buf: integer }>
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
  return vim.bo[bufnr].buftype == ""
end

---@param winnr                         integer
---@return fml.dressing.dim.IScope|nil
local function get_scope(winnr)
  if not vim.api.nvim_win_is_valid(winnr) then
    return nil
  end

  local bufnr = vim.api.nvim_win_get_buf(winnr)
  if not is_buf_enabled(bufnr) then
    return nil
  end

  local pos = vim.api.nvim_win_get_cursor(winnr)
  local line, col = pos[1], pos[2] + 1
  local scope ---@type table|nil

  -- local MiniIndentscope = require("mini.indentscope")
  if vim.api.nvim_get_current_buf() == bufnr then
    ---@diagnostic disable-next-line: undefined-global
    scope = MiniIndentscope.get_scope(line, col)
  else
    vim.api.nvim_buf_call(bufnr, function()
      ---@diagnostic disable-next-line: undefined-global
      scope = MiniIndentscope.get_scope(line, col)
    end)
  end

  if scope and scope.body then
    return { buf = bufnr, from = scope.body.top, to = scope.body.bottom }
  end
  return nil
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

  local scope = get_scope(winnr)
  if not scope then
    listener.scopes[winnr] = nil
    listener.scopes_anim[winnr] = nil
    return
  end

  local prev = listener.scopes[winnr]
  if prev and prev.from == scope.from and prev.to == scope.to and prev.buf == scope.buf then
    return
  end

  listener.scopes[winnr] = scope

  if not config.animate then
    vim.cmd("redraw!")
    return
  end

  local anim = listener.scopes_anim[winnr]
  if not anim or anim.buf ~= scope.buf then
    local top = vim.fn.line("w0", winnr)
    local bot = vim.fn.line("w$", winnr)
    anim = { from = top, to = bot, buf = scope.buf }
    listener.scopes_anim[winnr] = anim
  end

  local easing_fn = std.easing[config.easing] or std.easing.outQuad
  local total_steps = math.ceil(config.duration / config.step)
  local from_start, to_start = anim.from, anim.to
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

  timer:start(0, config.step, function()
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
      local eased = easing_fn(progress * config.duration, 0, 1, config.duration)

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

---@param winnr                         integer
local function update(winnr)
  if not listener then
    return
  end
  vim.defer_fn(function()
    if listener and vim.api.nvim_win_is_valid(winnr) then
      check_scope(winnr)
    end
  end, 30)
end

local function enable()
  if enabled then
    return
  end
  enabled = true

  listener = { scopes = {}, scopes_anim = {}, timer = nil }

  vim.api.nvim_set_decoration_provider(ns, {
    on_win = function(_, winnr, bufnr, top, bottom)
      if enabled and is_buf_enabled(bufnr) then
        on_win(winnr, bufnr, top + 1, bottom + 1)
      end
    end,
  })

  vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
    group = augroup,
    callback = function()
      update(vim.api.nvim_get_current_win())
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

  update(vim.api.nvim_get_current_win())
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

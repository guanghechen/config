---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.wk.input" ---@type string

local S = era.m.wk

---@class era.m.wk.input
local M = {}

---@type table<string, {bufnr: integer, mode: string, trigger_key: string, tree_key: string}>
M.triggers = {}

---@type uv.uv_timer_t|nil
M.delay_timer = nil

---@type integer Recursion counter for detecting infinite loops
M.recursion = 0

---@type uv.uv_timer_t? Timer to reset recursion counter
M.recursion_timer = nil

---Attach triggers to buffer
---@param bufnr                          integer
function M.attach(bufnr)
  if not S.state.ready then
    return
  end

  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  local buf_trees = S.state.buf_trees[bufnr]
  if not buf_trees then
    return
  end

  for mode, _ in pairs(S.state.get_trigger_modes()) do
    if not S.state.is_suspended(bufnr, mode) then
      local tree = buf_trees[mode]
      if tree then
        for key, node in pairs(tree) do
          if node.is_group or next(node.children) ~= nil then
            M.__bind__(bufnr, mode, M.__resolve_key__(key), key)
          end
        end
      end
    end
  end
end

---Detach triggers from buffer/mode
---@param bufnr                          integer
---@param mode                           string
function M.detach(bufnr, mode)
  local to_remove = {}
  for id, trigger in pairs(M.triggers) do
    if trigger.bufnr == bufnr and trigger.mode == mode then
      to_remove[#to_remove + 1] = id
    end
  end

  for _, id in ipairs(to_remove) do
    local trigger = M.triggers[id]
    if trigger and vim.api.nvim_buf_is_valid(trigger.bufnr) then
      pcall(vim.keymap.del, trigger.mode, trigger.trigger_key, { buffer = trigger.bufnr })
    end
    M.triggers[id] = nil
  end
end

---Stop input and hide view
function M.stop()
  M.__cancel_delay__()
  S.view.close()
  S.state.reset()
end

----------------------------------------------------------------------------------------------------
-- Protected
----------------------------------------------------------------------------------------------------

---Check if a single-char key is safe to use as a trigger.
---For normal mode: g, z, Z, [, ] are safe (they are Vim's built-in prefix keys)
---For operator-pending mode: only [, ] are safe (we don't have motions preset for g/z)
---@param key                            string
---@param mode                           string
---@return boolean
local function is_safe_single_key(key, mode)
  if #key ~= 1 then
    return true
  end

  -- In operator-pending mode, g and z are NOT safe because we don't have
  -- motions preset (like gg, ge, zj, zk) defined. This would break dgg, dgj, etc.
  if mode == "o" then
    -- Only [ and ] are safe in operator-pending mode
    if key == "[" or key == "]" then
      return true
    end
    return false
  end

  -- In other modes (normal, visual), g and z are safe
  if key:match("^[a-z]$") and not key:match("^[gz]$") then
    return false
  end
  -- Only Z is safe for uppercase
  if key:match("^[A-Z]$") and not key:match("^[Z]$") then
    return false
  end
  -- [ and ] are safe (used for prev/next groups)
  if key == "[" or key == "]" then
    return true
  end
  -- Other single chars (symbols, digits) are not safe
  if key:match("^[^a-zA-Z%[%]]$") then
    return false
  end
  return true
end

---Bind trigger keymap
---@param bufnr                          integer
---@param mode                           string
---@param trigger_key                    string
---@param tree_key                       string
function M.__bind__(bufnr, mode, trigger_key, tree_key)
  local id = bufnr .. ":" .. mode .. ":" .. trigger_key
  if M.triggers[id] then
    return
  end

  -- In normal/operator-pending mode, only allow safe single-char keys as triggers
  -- g and z are safe in normal mode (Vim's built-in prefix keys)
  -- but NOT safe in operator-pending mode (we don't have motions preset)
  if (mode == "n" or mode == "o") and not is_safe_single_key(tree_key, mode) then
    return
  end

  local existing = vim.fn.maparg(trigger_key, mode, false, true)
  if type(existing) == "table" and existing.lhs then
    if existing.desc and not existing.desc:find("wk-trigger", 1, true) then
      return
    end
    if existing.rhs or existing.callback then
      return
    end
  end

  vim.keymap.set(mode, trigger_key, function()
    M.__start__(bufnr, mode, tree_key)
  end, {
    buffer = bufnr,
    nowait = true,
    desc = "wk-trigger",
  })

  M.triggers[id] = {
    bufnr = bufnr,
    mode = mode,
    trigger_key = trigger_key,
    tree_key = tree_key,
  }
end

---Cancel delay timer
function M.__cancel_delay__()
  if M.delay_timer then
    M.delay_timer:stop()
    pcall(M.delay_timer.close, M.delay_timer)
    M.delay_timer = nil
  end
end

---Execute keymap or feed keys
---@param node                           ?era.m.wk.INode
---@param keys                           string
function M.__execute__(node, keys)
  local bufnr = S.state.bufnr
  local mode = S.state.mode

  S.state.suspend(bufnr, mode)
  M.stop()

  if node and node.action then
    -- wk spec defined action: call directly
    node.action()
  elseif node and node.rhs then
    -- wk spec defined rhs string: feedkeys
    M.__feed__(node.rhs)
  else
    -- Neovim keymap or unknown: feedkeys with context (count, register)
    M.__feed_with_context__(keys, mode)
  end

  S.state.schedule_resume(bufnr, mode)
end

---Feed keys to Neovim
---@param keys                           string
function M.__feed__(keys)
  local feed = vim.api.nvim_replace_termcodes(keys, true, true, true)
  vim.api.nvim_feedkeys(feed, "mt", false)
end

---Feed keys with count and register context
---@param keys                           string
---@param mode                           string
function M.__feed_with_context__(keys, mode)
  local keystr = keys

  if vim.v.count > 0 and mode ~= "i" and mode ~= "c" then
    keystr = vim.v.count .. keystr
  end

  local default_reg = vim.fn.has("clipboard") == 1 and "+" or '"'
  if vim.v.register ~= default_reg and mode ~= "i" and mode ~= "c" then
    keystr = '"' .. vim.v.register .. keystr
  end

  local feed = vim.api.nvim_replace_termcodes(keystr, true, true, true)
  vim.api.nvim_feedkeys(feed, "mit", false)
end

---Check if timed out based on vim.o.timeoutlen
---@return boolean
function M.__is_timedout__()
  if not vim.o.timeout then
    return false
  end
  local delta = vim.uv.hrtime() / 1e6 - S.state.started_at
  return delta > vim.o.timeoutlen
end

---Input loop
---@param prefix                         string
function M.__loop__(prefix)
  vim.cmd.redraw()

  local ok, char = pcall(vim.fn.getcharstr)

  if not ok then
    M.stop()
    return
  end

  local key = vim.fn.keytrans(char)
  local timedout = M.__is_timedout__()
  local now = vim.uv.hrtime() / 1e6
  S.state.started_at = now

  -- User pressed a key, cancel any pending popup timer and reset show_popup
  M.__cancel_delay__()

  if key == "<Esc>" then
    M.stop()
    return
  end

  if key == "<BS>" then
    local parts = S.util.parse_keys(prefix)
    if #parts <= 1 then
      M.stop()
    else
      table.remove(parts)
      local new_prefix = table.concat(parts)
      S.state.keys = new_prefix
      if S.state.show_popup then
        S.view.render()
      else
        M.__reschedule_popup__()
      end
      M.__loop__(new_prefix)
    end
    return
  end

  local new_prefix = prefix .. key
  S.state.keys = new_prefix

  local node = S.state.get_node(new_prefix)
  if node then
    local has_children = node.is_group or next(node.children) ~= nil
    local has_explicit_action = node.action ~= nil or node.rhs ~= nil
    local is_nowait = node.nowait or (timedout and has_explicit_action)

    -- If nowait is set or timed out with explicit action, execute immediately
    if is_nowait and has_explicit_action then
      M.__execute__(node, new_prefix)
      return
    elseif has_children then
      if S.state.show_popup then
        S.view.render()
      else
        M.__reschedule_popup__()
      end
      M.__loop__(new_prefix)
    else
      M.__execute__(node, new_prefix)
    end
  else
    M.__execute__(nil, new_prefix)
  end
end

---Reschedule popup display (called when user presses a key before popup shows)
function M.__reschedule_popup__()
  local delay = S.state.get_delay()
  if delay > 0 then
    M.__schedule_popup__(delay)
  else
    S.state.show_popup = true
  end
end

---Resolve special keys (e.g., <leader> -> <Space>)
---@param key                            string
---@return string
function M.__resolve_key__(key)
  local termcodes = vim.api.nvim_replace_termcodes(key, true, true, true)
  return vim.fn.keytrans(termcodes)
end

---Schedule popup display with delay
---@param delay                          integer
function M.__schedule_popup__(delay)
  M.__cancel_delay__()

  M.delay_timer = vim.uv.new_timer()
  M.delay_timer:start(
    delay,
    0,
    vim.schedule_wrap(function()
      if S.state.keys ~= "" then
        S.state.show_popup = true
        S.view.render()
        vim.api.nvim__redraw({ flush = true })
      end
    end)
  )
end

---Start which-key flow
---@param bufnr                          integer
---@param mode                           string
---@param key                            string
function M.__start__(bufnr, mode, key)
  -- Don't intercept during macro recording/execution
  if S.util.in_macro() then
    local trigger_key = M.__resolve_key__(key)
    local id = bufnr .. ":" .. mode .. ":" .. trigger_key
    if M.triggers[id] then
      pcall(vim.keymap.del, mode, trigger_key, { buffer = bufnr })
      M.triggers[id] = nil
    end
    M.__feed_with_context__(key, mode)
    return
  end

  -- Recursion protection
  M.recursion = M.recursion + 1
  if not M.recursion_timer then
    M.recursion_timer = vim.uv.new_timer()
  end
  M.recursion_timer:start(500, 0, function()
    M.recursion = 0
  end)
  if M.recursion > 50 then
    M.recursion = 0
    stl.reporter.error({
      from = "era.m.wk.input",
      subject = "Recursion detected",
      message = "Possible infinite loop in keymap configuration",
    })
    return
  end

  S.state.bufnr = bufnr
  S.state.mode = mode
  S.state.keys = key
  S.state.started_at = vim.uv.hrtime() / 1e6

  local delay = S.state.get_delay()
  S.state.show_popup = delay <= 0

  if delay > 0 then
    M.__schedule_popup__(delay)
  end

  if S.state.show_popup then
    S.view.render()
  end

  M.__loop__(key)
end

return M

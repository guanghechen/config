---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.keystroke.pairs.ops" ---@type string

-- Ported from blink.pairs v0.5.0 (`lua/blink/pairs/mappings`; MIT License, Copyright (c) 2025 Liam Dyer; see
-- LICENSE.blink). Each action returns the keys an expression mapping feeds. Balance checks read the buffer's
-- `era.m.pairs` document; the command line has none, so it always pairs.

local Context = require("era.keystroke.pairs.context")
local Rule = require("era.keystroke.pairs.rule")

---@class era.keystroke.pairs.ops
local M = {}

---@param ctx                           era.keystroke.pairs.Context
---@return boolean
local function enabled(ctx)
  if ctx.mode:find("R", 1, true) then
    return false
  end
  if ctx.cmdline then
    local cmdtype = vim.fn.getcmdtype() ---@type string
    if cmdtype == "/" or cmdtype == "?" then
      return false
    end
  end
  return not stl.filetype.is_not_sourcefile(vim.api.nvim_get_option_value("filetype", { buf = ctx.bufnr }))
end

--- Keys that move the cursor `amount` characters, without breaking undo in Insert mode.
---@param ctx                           era.keystroke.pairs.Context
---@param amount                        integer
---@return string
local function shift(ctx, amount)
  local key = (ctx.cmdline and "" or "<C-g>U") .. (amount > 0 and "<Right>" or "<Left>") ---@type string
  return string.rep(key, math.abs(amount))
end

--- `| )` → `(|)`, unless a closing after the cursor is waiting for this opening: `|)` → `(|)`.
---@param ctx                           era.keystroke.pairs.Context
---@param key                           string
---@param rule                          era.keystroke.pairs.Rule
---@param offset                        ?integer Where in the opening the typed key is.
---@return string
local function open_pair(ctx, key, rule, offset)
  if ctx.is_escaped then
    return key
  end
  local doc = ctx.document
  if doc and doc:unmatched_closing_after(rule.opening, rule.closing, ctx.row - 1, ctx.col) ~= nil then
    return key
  end
  return rule.opening:sub(offset or 1) .. rule.closing .. shift(ctx, -#rule.closing)
end

--- `|)` → `)|` and `| )` → ` )|`, unless an opening before the cursor is waiting for this closing.
---@param ctx                           era.keystroke.pairs.Context
---@param rule                          era.keystroke.pairs.Rule
---@return string
local function close_pair(ctx, rule)
  local doc = ctx.document
  if doc and doc:unmatched_opening_before(rule.opening, rule.closing, ctx.row - 1, ctx.col) ~= nil then
    return rule.closing
  end
  if ctx:text_after_cursor(1) == rule.closing:sub(1, 1) then
    return shift(ctx, #rule.closing)
  end
  if ctx:text_after_cursor(2) == " " .. rule.closing then
    return shift(ctx, 2)
  end
  return rule.closing
end

--- `|'` → `'|`, else `|` → `'|'`.
---@param ctx                           era.keystroke.pairs.Context
---@param key                           string
---@param rule                          era.keystroke.pairs.Rule
---@return string
local function open_or_close_pair(ctx, key, rule)
  if ctx.is_escaped then
    return key
  end
  local pair = rule.opening ---@type string
  if ctx:is_after_cursor(pair) then
    return shift(ctx, #pair)
  end
  return pair .. pair .. shift(ctx, -#pair)
end

--- The keys typing `key` feeds: the first rule that applies decides.
---@param key                           string
---@param rules                         era.keystroke.pairs.Rule[]
---@return fun(): string
function M.on_key(key, rules)
  return function()
    local ctx = Context.new()
    if not enabled(ctx) then
      return key
    end
    for _, rule in ipairs(rules) do
      if Rule.is_active(ctx, rule) then
        if rule.opening == rule.closing then
          return open_or_close_pair(ctx, key, rule)
        end
        if #rule.opening == 1 then
          if rule.opening == key then
            return open_pair(ctx, key, rule)
          end
          return close_pair(ctx, rule)
        end
        -- A longer opening: `r#|` + `"` → `r#"|"#`; its last key after the whole opening closes it.
        local prefix = assert(rule.opening:find(key, 1, true), "key outside its rule's opening") - 1 ---@type integer
        if prefix == 0 or ctx:is_before_cursor(rule.opening:sub(1, prefix)) then
          return open_pair(ctx, key, rule, prefix + 1)
        end
        if ctx:is_before_cursor(rule.opening) then
          return close_pair(ctx, rule)
        end
      end
    end
    return key
  end
end

--- The first rule whose opening ends before the cursor and whose closing starts after it, and whether one space
--- separates each from the cursor (only looked for when `spaced`).
---@param ctx                           era.keystroke.pairs.Context
---@param rules                         era.keystroke.pairs.Rule[]
---@param mode                          ?"enter"|"space"
---@param spaced                        boolean
---@return era.keystroke.pairs.Rule|nil
---@return boolean
local function surrounding(ctx, rules, mode, spaced)
  local before, after = ctx:text_before_cursor(), ctx:text_after_cursor() ---@type string, string
  spaced = spaced and before:sub(-1) == " " and after:sub(1, 1) == " "
  for _, rule in ipairs(rules) do
    local opening, closing = rule.opening, rule.closing ---@type string, string
    local around = spaced and opening == before:sub(-#opening - 1, -2) and closing == after:sub(2, #closing + 1)
    local inside = opening == before:sub(-#opening) and closing == after:sub(1, #closing)
    if (around or inside) and Rule.is_active(ctx, rule, mode) then
      return rule, around
    end
  end
  return nil, false
end

--- `(|)` → `|`, and `( | )` → `(|)`.
---@param rules                         era.keystroke.pairs.Rule[]
---@return fun(): string
function M.backspace(rules)
  return function()
    local ctx = Context.new()
    if not enabled(ctx) then
      return "<BS>"
    end
    local rule, spaced = surrounding(ctx, rules, nil, true)
    if not rule then
      return "<BS>"
    end
    if spaced then
      return "<Del><BS>"
    end
    return shift(ctx, #rule.closing) .. string.rep("<BS>", #rule.opening + #rule.closing)
  end
end

--- `(|)` → the closing on its own line below an empty, indented line, after an undo break-point.
---@param rules                         era.keystroke.pairs.Rule[]
---@return fun(): string
function M.enter(rules)
  return function()
    local ctx = Context.new()
    -- `<C-]>` expands an abbreviation, which a mapped key would not.
    if not enabled(ctx) then
      return "<C-g>u<C-]><CR>"
    end
    local rule, spaced = surrounding(ctx, rules, "enter", true)
    if not rule then
      return "<C-g>u<C-]><CR>"
    end
    if spaced then
      return "<C-g>u" .. shift(ctx, 1) .. "<BS><BS><CR><C-o>O"
    end
    return "<C-g>u<CR><C-o>O"
  end
end

--- `(|)` → `( | )`. In Insert mode the first space after a word also starts a new undo step.
---@param rules                         era.keystroke.pairs.Rule[]
---@return fun(): string
function M.space(rules)
  return function()
    local ctx = Context.new()
    local before = ctx:text_before_cursor(1) ---@type string
    local undo = (not ctx.cmdline and before ~= "" and not before:match("%s")) and "<C-g>u" or "" ---@type string
    if not enabled(ctx) or not surrounding(ctx, rules, "space", false) then
      return undo .. "<C-]><Space>"
    end
    return undo .. "<Space><Space>" .. shift(ctx, -1)
  end
end

return M

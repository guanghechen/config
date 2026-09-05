---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.ai.capture" ---@type string

---@class era.m.ai.capture
local M = {}

local BOTTOM_LINES = 10 ---@type integer Capture lines treated as the footer region for state detection.
local SIGNATURE_LEN = 24 ---@type integer Prefix of the payload used to detect whether text is still pending in the box.
local RULE_MIN = 20 ---@type integer Minimum horizontal-rule chars for a line to count as an input-box border.

---@param content                       string
---@param n                             integer
---@return string[]
function M.bottom_lines(content, n)
  local lines = vim.split(content, "\n", { plain = true })
  -- `tmux capture-pane -p` pads the frame with blank rows up to the pane height, and
  -- the TUI footer is not pinned to the bottom of the pane (early in a conversation it
  -- sits well above it). Drop trailing blank lines before taking the last n, or the
  -- footer region (insert / busy markers) falls outside the window and footer_has
  -- silently never matches.
  local last = #lines
  while last > 0 and vim.trim(lines[last]) == "" do
    last = last - 1
  end
  local out = {} ---@type string[]
  for i = math.max(1, last - n + 1), last do
    out[#out + 1] = lines[i]
  end
  return out
end

--- Whether any line of the capture's footer region matches `pattern` (a Lua
--- pattern). Lines are trimmed first, so a `^`-anchored pattern keys off the first
--- non-space glyph; both `insert_pattern` and `busy_pattern` go through here.
---@param content                       string|nil
---@param pattern                       string|nil
---@return boolean
function M.footer_has(content, pattern)
  if not content or not pattern then
    return false
  end
  for _, line in ipairs(M.bottom_lines(content, BOTTOM_LINES)) do
    if vim.trim(line):find(pattern) then
      return true
    end
  end
  return false
end

--- Extract the text currently pending in the input box: the region between the
--- last two horizontal-rule borders, with the prompt marker stripped. Returns nil
--- when the layout cannot be recognized (then submission cannot be judged here).
---@param content                       string|nil
---@return string|nil
function M.extract_input(content)
  if not content then
    return nil
  end

  local lines = vim.split(content, "\n", { plain = true })
  local rules = {} ---@type integer[]
  for i, line in ipairs(lines) do
    local _, dashes = vim.trim(line):gsub("─", "")
    if dashes >= RULE_MIN then
      rules[#rules + 1] = i
    end
  end
  if #rules < 2 then
    return nil
  end

  local top, bottom = rules[#rules - 1], rules[#rules]
  local parts = {} ---@type string[]
  for i = top + 1, bottom - 1 do
    -- Strip exactly one UI prompt marker (❯ or >), never a second one: a leading
    -- ">" can be the user's own content (Markdown quote, shell redirection), and
    -- over-stripping it desyncs extract_input from make_signature, which would
    -- misclassify still-pending text as "submitted" (a false success).
    local t = vim.trim(lines[i]) ---@type string
    local stripped = t:gsub("^❯%s*", "") ---@type string
    if stripped == t then
      stripped = t:gsub("^>%s*", "")
    end
    if stripped ~= "" then
      parts[#parts + 1] = stripped
    end
  end
  return vim.trim(table.concat(parts, "\n"))
end

---@param text                          string
---@return string
function M.make_signature(text)
  local first = vim.split(text or "", "\n", { plain = true })[1] or ""
  return vim.trim(first):sub(1, SIGNATURE_LEN)
end

--- Classify what a capture says about our submission:
---  - "submitted": the agent is processing, or our text has left the input box.
---  - "pending":   our text is still sitting in the input box.
---  - "unknown":   no capture, or the input-box layout could not be parsed.
---@param content                       string|nil
---@param signature                     string
---@param busy_pattern                  string|nil
---@return "submitted"|"pending"|"unknown"
function M.classify(content, signature, busy_pattern)
  if not content then
    return "unknown"
  end
  if M.footer_has(content, busy_pattern) then
    return "submitted"
  end

  local pending = M.extract_input(content)
  if pending == nil then
    return "unknown"
  end
  if signature == "" then
    return pending == "" and "submitted" or "pending"
  end
  return pending:find(signature, 1, true) and "pending" or "submitted"
end

return M

---@class eve.builtin.ai
local M = {}

---@class eve.builtin.ai.ISidekickContext
---@field win                           integer
---@field buf                           integer
---@field cwd                           string
---@field row                           integer
---@field col                           integer
---@field range                         { from: integer[], to: integer[], kind: string }|nil

---@param config                        eve.builtin.ai.IEditInlineConfig
---@return eve.builtin.ai.ISidekickContext
local function build_context(config)
  local bufnr = config.bufnr or vim.api.nvim_get_current_buf()
  local win = vim.fn.bufwinid(bufnr)
  if win == -1 or not vim.api.nvim_win_is_valid(win) then
    win = vim.api.nvim_get_current_win()
  end

  local cursor = { 1, 0 }
  if win ~= -1 and vim.api.nvim_win_is_valid(win) then
    cursor = vim.api.nvim_win_get_cursor(win)
  end

  local range = config.range
  local range_payload
  if range then
    range_payload = {
      from = { range.lnum_start, math.max(range.col_start - 1, 0) },
      to = { range.lnum_end, math.max(range.col_end - 1, 0) },
      kind = "char",
    }
  end

  local cwd = vim.fs.normalize(vim.fn.getcwd((win ~= -1 and win) or nil))

  return {
    win = win,
    buf = bufnr,
    cwd = cwd,
    row = range and range.lnum_start or cursor[1],
    col = range and math.max(range.col_start - 1, 0) or cursor[2],
    range = range_payload,
  }
end

---@param config                        eve.builtin.ai.IEditInlineConfig
---@param template                      string|nil
---@return string|nil rendered, string|nil err
local function render_message(config, template)
  template = template or "/code {this}"
  local prompt = config.prompt
  if type(prompt) ~= "string" or #vim.trim(prompt) == 0 then
    prompt = template
  end

  local context = require("sidekick.cli.context").get()
  context.context = {}
  context.ctx = build_context(config)

  local ok, rendered = pcall(context.render, context, { msg = prompt })
  if not ok then
    return nil, type(rendered) == "string" and rendered or tostring(rendered)
  end

  if type(rendered) ~= "string" or #vim.trim(rendered) == 0 then
    return nil, "Prompt is empty."
  end

  return rendered
end

---@class eve.builtin.ai.ISelectedRange
---@field lnum_start                    integer
---@field lnum_end                      integer
---@field col_start                     integer
---@field col_end                       integer

---@class eve.builtin.ai.IEditInlineConfig
---@field bufnr                         integer
---@field prompt                        string
---@field filepath                      string
---@field range                         eve.builtin.ai.ISelectedRange
---@field content                       string
---@field filetype                      string|nil
---@field location                      string|nil

---@param config                        eve.builtin.ai.IEditInlineConfig
---@param template                      string
---@return boolean ok, string message, boolean should_close
local function send_prompt(config, template)
  template = template or "/code {this}"
  if not eve.context.flight.ai:snapshot() then
    return false, "AI flight is disabled.", false
  end

  local cli = require("sidekick.cli")
  local rendered, render_err = render_message(config, template)
  if not rendered then
    return false, render_err or "Prompt is empty.", false
  end

  local ok_send, err = pcall(cli.send, {
    msg = rendered,
    render = false,
    focus = false,
    submit = true,
  })

  if not ok_send then
    local reason = err or "Failed to send message."
    return false, type(reason) == "string" and reason or vim.inspect(reason), false
  end

  return true, "Request sent to Sidekick.", true
end

---@param config                        eve.builtin.ai.IEditInlineConfig
---@return boolean ok, string message, boolean should_close
function M.edit_inline(config)
  return send_prompt(config, "/code {this}")
end

---@param config                        eve.builtin.ai.IEditInlineConfig
---@return boolean ok, string message, boolean should_close
function M.refine_inline(config)
  return send_prompt(config, "/refine {this}")
end

---@param config                        eve.builtin.ai.IEditInlineConfig
---@return string|nil
function M.resolve_inline_location(config)
  local ctx = build_context(config)
  local location = require("sidekick.cli.location").get(ctx, { kind = "position" })
  if not location then
    return nil
  end

  local function flatten(segment)
    local parts = {}
    for _, piece in ipairs(segment) do
      parts[#parts + 1] = piece[1]
    end
    return table.concat(parts)
  end

  local lines = {}
  for _, segment in ipairs(location) do
    lines[#lines + 1] = flatten(segment)
  end

  return table.concat(lines)
end

---@param config                        eve.builtin.ai.IEditInlineConfig
---@param template                      string|nil
---@return string|nil rendered, string|nil err
function M.render_inline_prompt(config, template)
  return render_message(config, template)
end

return M

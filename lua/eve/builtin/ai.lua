local __module_name__ = "eve.builtin.ai" ---@type string

---@class eve.builtin.ai
local M = {}

local payload_bufnr ---@type integer|nil

---@return integer|nil                    bufnr, string|nil err
local function ensure_payload_buffer()
  if payload_bufnr ~= nil and vim.api.nvim_buf_is_valid(payload_bufnr) then
    return payload_bufnr, nil
  end

  local bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  if bufnr == 0 then
    payload_bufnr = nil
    return nil, "Failed to create scratch buffer."
  end

  payload_bufnr = bufnr

  vim.bo[bufnr].buflisted = true
  vim.bo[bufnr].bufhidden = "hide"
  vim.bo[bufnr].buftype = "nofile"
  vim.bo[bufnr].swapfile = false
  vim.bo[bufnr].filetype = "text"
  vim.bo[bufnr].modifiable = true
  vim.bo[bufnr].readonly = false

  local ok_name, err = pcall(vim.api.nvim_buf_set_name, bufnr, "ai://locations")
  if not ok_name then
    std.reporter.warn({
      from = __module_name__,
      subject = "add_files_to_ai",
      message = "Failed to set AI payload buffer name.",
      details = { error = err },
    })
  end

  return bufnr, nil
end

---@param locations                     std.t.ILocation[]|nil
---@return nil
function M.add_files_to_ai(locations)
  if type(locations) ~= "table" then
    std.reporter.warn({
      from = __module_name__,
      subject = "add_files_to_ai",
      message = "Invalid payload: expected a list of locations.",
      details = { locations = locations },
    })
    return
  end

  local valid_locations = {} ---@type std.t.ILocation[]
  local invalid_indices = {} ---@type integer[]
  for index, location in ipairs(locations) do
    if type(location) == "table" and type(location.filepath) == "string" and #vim.trim(location.filepath) > 0 then
      valid_locations[#valid_locations + 1] = location
    else
      invalid_indices[#invalid_indices + 1] = index
    end
  end

  if vim.tbl_isempty(valid_locations) then
    std.reporter.warn({
      from = __module_name__,
      subject = "add_files_to_ai",
      message = "No valid locations provided.",
      details = vim.tbl_isempty(invalid_indices) and { locations = locations } or { invalid_indices = invalid_indices },
    })
    return
  end

  local lines = {} ---@type string[]
  local failures = {} ---@type { index: integer, error: string, location: std.t.ILocation }[]

  for index, location in ipairs(valid_locations) do
    local text, err = std.uri.file_location(location)
    if text ~= nil then
      lines[#lines + 1] = text
    else
      failures[#failures + 1] = {
        index = index,
        error = err or "Unknown error.",
        location = location,
      }
    end
  end

  if vim.tbl_isempty(lines) then
    std.reporter.warn({
      from = __module_name__,
      subject = "add_files_to_ai",
      message = "No locations could be stringified.",
      details = not vim.tbl_isempty(failures) and { failures = failures } or nil,
    })
    return
  end

  if not vim.tbl_isempty(failures) then
    std.reporter.warn({
      from = __module_name__,
      subject = "add_files_to_ai",
      message = string.format("Skipped %d invalid location%s.", #failures, #failures == 1 and "" or "s"),
      details = { failures = failures },
    })
  end

  local bufnr_payload, buf_err = ensure_payload_buffer()
  if bufnr_payload == nil then
    std.reporter.error({
      from = __module_name__,
      subject = "add_files_to_ai",
      message = "Failed to prepare AI payload buffer.",
      details = { error = buf_err },
    })
    return
  end

  vim.bo[bufnr_payload].modifiable = true
  vim.api.nvim_buf_set_lines(bufnr_payload, 0, -1, false, lines)
  vim.bo[bufnr_payload].modified = false

  local winid = vim.fn.bufwinid(bufnr_payload) ---@type integer
  if winid ~= -1 then
    vim.api.nvim_win_set_buf(winid, bufnr_payload)
  end

  local payload = table.concat(lines, "\n") ---@type string
  local copy_failures = {} ---@type string[]
  for _, register in ipairs({ '"', '+' }) do
    local ok_register, register_err = pcall(vim.fn.setreg, register, payload)
    if not ok_register then
      copy_failures[#copy_failures + 1] = string.format("%s register: %s", register, register_err)
    end
  end

  if #copy_failures > 0 then
    std.reporter.warn({
      from = __module_name__,
      subject = "add_files_to_ai",
      message = "Copy failed: " .. table.concat(copy_failures, "; "),
    })
  else
    std.reporter.info({
      from = __module_name__,
      subject = "add_files_to_ai",
      message = "Locations copied to clipboard.",
    })
  end
end

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
  local location = require("sidekick.cli.context.location").get(ctx, { kind = "position" })
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

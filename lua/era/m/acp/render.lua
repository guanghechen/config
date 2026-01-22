---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.acp.render" ---@type string

---Rendering constants and utilities for ACP UI components.
---@class era.m.acp.render
local M = {}

----------------------------------------------------------------------------------------------------
-- Box Drawing Characters
----------------------------------------------------------------------------------------------------

---@class era.m.acp.render.IBox
---@field public tl                     string  Top-left corner
---@field public tr                     string  Top-right corner
---@field public bl                     string  Bottom-left corner
---@field public br                     string  Bottom-right corner
---@field public h                      string  Horizontal line
---@field public v                      string  Vertical line

---Rounded box characters (more elegant)
---@type era.m.acp.render.IBox
M.box_round = {
  tl = "╭",
  tr = "╮",
  bl = "╰",
  br = "╯",
  h = "─",
  v = "│",
}

---Sharp box characters
---@type era.m.acp.render.IBox
M.box_sharp = {
  tl = "┌",
  tr = "┐",
  bl = "└",
  br = "┘",
  h = "─",
  v = "│",
}

---Double-line box characters
---@type era.m.acp.render.IBox
M.box_double = {
  tl = "╔",
  tr = "╗",
  bl = "╚",
  br = "╝",
  h = "═",
  v = "║",
}

----------------------------------------------------------------------------------------------------
-- Icons
----------------------------------------------------------------------------------------------------

---Role icons
M.icon_user = "󰀄"
M.icon_assistant = "󱚥"
M.icon_system = "󰒓"
M.icon_thinking = "󰠮"

---Status icons
M.icon_pending = "○"
M.icon_running = "◐"
M.icon_success = "●"
M.icon_error = "✗"
M.icon_warning = "⚠"

---Action icons
M.icon_expand = stl.icon.ui.ArrowClosed
M.icon_collapse = stl.icon.ui.ArrowOpen
M.icon_diff = "󰒉"

---Spinner frames (braille pattern)
M.spinner_frames = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }

----------------------------------------------------------------------------------------------------
-- Role Header Rendering
----------------------------------------------------------------------------------------------------

---@class era.m.acp.render.IRoleHeaderOpts
---@field public role                   "user"|"assistant"|"system"
---@field public label                  ?string
---@field public spinner                ?string

---Build role header line with icon badge
---@param opts                          era.m.acp.render.IRoleHeaderOpts
---@return string line
---@return { hl: string, col_start: integer, col_end: integer }[] highlights
function M.build_role_header(opts)
  local icon ---@type string
  local hl_badge ---@type string

  if opts.role == "user" then
    icon = M.icon_user
    hl_badge = "f_acp_role_user_badge"
  elseif opts.role == "assistant" then
    icon = M.icon_assistant
    hl_badge = "f_acp_role_assistant_badge"
  else
    icon = M.icon_system
    hl_badge = "f_acp_role_system_badge"
  end

  local label = opts.label or (opts.role == "user" and "You" or "Assistant")
  local spinner_part = opts.spinner and (" " .. opts.spinner) or ""

  -- Build badge: ▌icon label▐
  local badge_left = "▌"
  local badge_right = "▐"
  local badge_content = icon .. " " .. label
  local badge = badge_left .. badge_content .. badge_right .. spinner_part

  local line = badge

  -- Calculate highlight positions
  local highlights = {} ---@type { hl: string, col_start: integer, col_end: integer }[]
  local badge_start = 0
  local badge_end = badge_start + #badge_left + #badge_content + #badge_right

  highlights[#highlights + 1] = { hl = hl_badge, col_start = badge_start, col_end = badge_end }

  if opts.spinner then
    local spinner_start = badge_end
    local spinner_end = spinner_start + #spinner_part
    highlights[#highlights + 1] = { hl = "f_acp_spinner", col_start = spinner_start, col_end = spinner_end }
  end

  return line, highlights
end

----------------------------------------------------------------------------------------------------
-- Tool Card Rendering
----------------------------------------------------------------------------------------------------

---@class era.m.acp.render.IToolCardOpts
---@field public icon                   string
---@field public name                   string
---@field public args_preview           string[]
---@field public expanded               boolean
---@field public has_diff               boolean
---@field public status                 ?"pending"|"success"|"error"

---Build tool card lines
---@param opts                          era.m.acp.render.IToolCardOpts
---@return string[] lines
---@return table<integer, { hl: string, col_start: integer, col_end: integer }[]> line_highlights
function M.build_tool_card(opts)
  local box = M.box_round
  local indent = ""

  if not opts.expanded then
    -- Collapsed: compact single-line card
    local header = string.format("%s %s", opts.icon, opts.name)
    local args_text = opts.args_preview[1] or ""
    if #args_text > 40 then
      args_text = args_text:sub(1, 40) .. "…"
    end

    local content = header
    if args_text ~= "" then
      content = content .. " " .. box.h .. " " .. args_text
    end

    local display_width = vim.fn.strdisplaywidth(content)
    local padding_len = math.max(2, 60 - display_width)
    local padding = string.rep(box.h, padding_len)

    local line = indent .. box.tl .. box.h .. " " .. content .. " " .. padding .. box.tr

    local highlights = {} ---@type table<integer, { hl: string, col_start: integer, col_end: integer }[]>
    highlights[1] = {
      { hl = "f_acp_tool_border", col_start = 0, col_end = #line },
      { hl = "f_acp_tool_icon", col_start = #indent + #box.tl + #box.h + 1, col_end = #indent + #box.tl + #box.h + 1 + #opts.icon },
      { hl = "f_acp_tool_name", col_start = #indent + #box.tl + #box.h + 1 + #opts.icon + 1, col_end = #indent + #box.tl + #box.h + 1 + #opts.icon + 1 + #opts.name },
    }

    return { line }, highlights
  end

  -- Expanded: full card with borders
  local header_text = string.format("%s %s", opts.icon, opts.name)

  local max_width = vim.fn.strdisplaywidth(header_text)
  for _, line in ipairs(opts.args_preview) do
    max_width = math.max(max_width, vim.fn.strdisplaywidth(line))
  end

  if opts.has_diff then
    max_width = math.max(max_width, vim.fn.strdisplaywidth(M.icon_diff .. " View Diff"))
  end

  max_width = math.max(max_width, 30) -- minimum width

  local function pad(text)
    return text .. string.rep(" ", max_width - vim.fn.strdisplaywidth(text))
  end

  local lines = {} ---@type string[]
  local highlights = {} ---@type table<integer, { hl: string, col_start: integer, col_end: integer }[]>

  -- Top border
  lines[#lines + 1] = indent .. box.tl .. string.rep(box.h, max_width + 2) .. box.tr
  highlights[#lines] = { { hl = "f_acp_tool_border", col_start = 0, col_end = #lines[#lines] } }

  -- Header line
  local header_line = indent .. box.v .. " " .. pad(header_text) .. " " .. box.v
  lines[#lines + 1] = header_line
  local hl_header = {
    { hl = "f_acp_tool_border", col_start = #indent, col_end = #indent + #box.v },
    { hl = "f_acp_tool_header_bg", col_start = #indent + #box.v, col_end = #header_line - #box.v },
    { hl = "f_acp_tool_border", col_start = #header_line - #box.v, col_end = #header_line },
    { hl = "f_acp_tool_icon", col_start = #indent + #box.v + 1, col_end = #indent + #box.v + 1 + #opts.icon },
    { hl = "f_acp_tool_name", col_start = #indent + #box.v + 1 + #opts.icon + 1, col_end = #indent + #box.v + 1 + #opts.icon + 1 + #opts.name },
  }
  highlights[#lines] = hl_header

  -- Separator
  lines[#lines + 1] = indent .. box.v .. string.rep("┄", max_width + 2) .. box.v
  highlights[#lines] = { { hl = "f_acp_tool_border", col_start = 0, col_end = #lines[#lines] } }

  -- Args lines
  for _, arg_line in ipairs(opts.args_preview) do
    local content_line = indent .. box.v .. " " .. pad(arg_line) .. " " .. box.v
    lines[#lines + 1] = content_line
    highlights[#lines] = {
      { hl = "f_acp_tool_border", col_start = #indent, col_end = #indent + #box.v },
      { hl = "f_acp_tool_args", col_start = #indent + #box.v + 1, col_end = #content_line - #box.v - 1 },
      { hl = "f_acp_tool_border", col_start = #content_line - #box.v, col_end = #content_line },
    }
  end

  -- Diff button
  if opts.has_diff then
    local diff_text = M.icon_diff .. " View Diff"
    local diff_line = indent .. box.v .. " " .. pad(diff_text) .. " " .. box.v
    lines[#lines + 1] = diff_line
    highlights[#lines] = {
      { hl = "f_acp_tool_border", col_start = #indent, col_end = #indent + #box.v },
      { hl = "f_acp_diff_button", col_start = #indent + #box.v + 1, col_end = #indent + #box.v + 1 + #diff_text },
      { hl = "f_acp_tool_border", col_start = #diff_line - #box.v, col_end = #diff_line },
    }
  end

  -- Bottom border
  lines[#lines + 1] = indent .. box.bl .. string.rep(box.h, max_width + 2) .. box.br
  highlights[#lines] = { { hl = "f_acp_tool_border", col_start = 0, col_end = #lines[#lines] } }

  return lines, highlights
end

----------------------------------------------------------------------------------------------------
-- Input Border Rendering
----------------------------------------------------------------------------------------------------

---Build decorative input border
---@param width                         integer
---@param title                         string
---@return string line
---@return { hl: string, col_start: integer, col_end: integer }[] highlights
function M.build_input_border(width, title)
  local box = M.box_round

  -- ╭─────── 󰋦 Title ───────╮
  local title_with_padding = " " .. title .. " "
  local title_width = vim.fn.strdisplaywidth(title_with_padding)
  local side_width = math.floor((width - title_width - 2) / 2)
  local left_padding = string.rep(box.h, math.max(2, side_width))
  local right_padding = string.rep(box.h, math.max(2, width - title_width - #left_padding - 2))

  local line = box.tl .. left_padding .. title_with_padding .. right_padding .. box.tr

  local title_start = #box.tl + #left_padding
  local title_end = title_start + #title_with_padding

  local highlights = {
    { hl = "f_acp_input_border", col_start = 0, col_end = title_start },
    { hl = "f_acp_input_title", col_start = title_start, col_end = title_end },
    { hl = "f_acp_input_border", col_start = title_end, col_end = #line },
  }

  return line, highlights
end

----------------------------------------------------------------------------------------------------
-- Section Header Rendering
----------------------------------------------------------------------------------------------------

---Build section header (for sidebar)
---@param title                         string
---@param expanded                      boolean
---@param _width                        integer
---@return string line
---@return { hl: string, col_start: integer, col_end: integer }[] highlights
---@diagnostic disable-next-line: unused-local
function M.build_section_header(title, expanded, _width)
  local icon = expanded and M.icon_collapse or M.icon_expand
  local header = icon .. " " .. title

  local line = header
  local highlights = {
    { hl = "f_acp_section_icon", col_start = 0, col_end = #icon },
    { hl = "f_acp_section_title", col_start = #icon + 1, col_end = #header },
  }

  return line, highlights
end

----------------------------------------------------------------------------------------------------
-- Separator Rendering
----------------------------------------------------------------------------------------------------

---Build a separator line
---@param width                         integer
---@param style                         ?"solid"|"dashed"|"dotted"
---@return string
function M.build_separator(width, style)
  style = style or "solid"
  local char = style == "dashed" and "┄" or (style == "dotted" and "·" or "─")
  return string.rep(char, width)
end

return M

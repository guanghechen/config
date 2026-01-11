---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.minimap.mouse" ---@type string

local util = require("era.m.minimap.util")
local view = require("era.m.minimap.view")

local M = {}

----------------------------------------------------------------------------------------------------
-- Constants
----------------------------------------------------------------------------------------------------

local t = vim.keycode

local LEFTMOUSE = t("<leftmouse>")
local LEFTRELEASE = t("<leftrelease>")

----------------------------------------------------------------------------------------------------
-- Internal functions
----------------------------------------------------------------------------------------------------

---@param winid                       integer
---@param bufnr                       integer
---@param row                         integer 0-based row position in the bar
---@param bar_height                  integer
---@return integer
local function get_topline(winid, bufnr, row, bar_height)
  if row == 0 then
    return 1
  end

  local winheight = util.get_winheight(winid)
  if row + bar_height >= winheight then
    return vim.api.nvim_buf_line_count(bufnr)
  end

  local lookup = util.virtual_topline_lookup(winid)
  return math.max(1, lookup[row + 1] or lookup[#lookup] or 1)
end

---Scrolls the window so that the specified line number is at the top.
---@param winid                       integer
---@param linenr                      integer
local function set_topline(winid, linenr)
  vim.api.nvim_win_call(winid, function()
    local init_line = vim.fn.line(".")
    vim.cmd("keepjumps normal! " .. linenr .. "G")
    local topline = util.visible_line_range(winid)
    local virtual_line = util.virtual_line_count(winid, topline, vim.fn.line("."))
    if virtual_line > 1 then
      vim.cmd("keepjumps normal! " .. (virtual_line - 1) .. t("<c-e>"))
    end
    local _, botline = util.visible_line_range(winid)
    if botline == vim.fn.line("$") then
      vim.cmd("keepjumps normal! Gzb")
    end

    vim.cmd("keepjumps normal! H")
    local effective_top = vim.fn.line(".")
    if init_line < effective_top then
      return
    end

    vim.cmd("keepjumps normal! L")
    local effective_bottom = vim.fn.line(".")
    if init_line > effective_bottom then
      return
    end

    vim.cmd("keepjumps normal! " .. init_line .. "G")
  end)
end

---@return string
local function getchar()
  local ok, char0 = pcall(vim.fn.getchar)
  local char = ok and tostring(char0) or t("<esc>")
  if char == t("<c-c>") then
    char = t("<esc>")
  end
  return char
end

---Get input characters---including mouse clicks and drags---from the input
---stream. Characters are read until the input stream is empty.
---
---The mouse values are 0 when there was no mouse event. The winid is set to
----1 when a mouse event was on the command line. The winid is set to -2 when
---a mouse event was on the tabline.
---@return string characters
---@return era.m.minimap.mouse.IProps[] props
local function read_input_stream()
  local chars = {} ---@type string[]
  local chars_props = {} ---@type era.m.minimap.mouse.IProps[]
  local str_idx = 1

  while true do
    local char = getchar()
    chars[#chars + 1] = char

    local mouse_winid = 0
    local mouse_row = 0
    local mouse_col = 0

    if vim.v.mouse_winid ~= 0 then
      mouse_winid = vim.v.mouse_winid
      local mousepos = vim.fn.getmousepos()
      mouse_row = mousepos.winrow
      mouse_col = mousepos.wincol

      if mousepos.screenrow > vim.go.lines - vim.go.cmdheight then
        mouse_winid = -1
        mouse_row = mousepos.screenrow - vim.go.lines + vim.go.cmdheight
        mouse_col = mousepos.screencol
      end

      local screenpos = vim.fn.win_screenpos(1)
      if
        screenpos[1] == 2
        and screenpos[2] == 1
        and mousepos.screenrow == 1
        and util.is_ordinary_window(mousepos.winid)
      then
        mouse_winid = -2
        mouse_row = mousepos.screenrow
        mouse_col = mousepos.screencol
      end
    end

    chars_props[#chars_props + 1] = {
      char = char,
      str_idx = str_idx,
      winid = mouse_winid,
      row = mouse_row,
      col = mouse_col,
    }

    str_idx = str_idx + char:len()

    if vim.fn.getchar(1) == 0 then
      break
    end
  end

  return table.concat(chars, ""), chars_props
end

---@param count                       integer
---@param char                        string
local function handle_leftrelease(count, char)
  if count == 0 then
    vim.api.nvim_feedkeys(char, "ni", false)
  elseif count == 1 then
    vim.api.nvim_feedkeys(LEFTMOUSE .. char, "ni", false)
  else
    view.refresh()
  end
end

---@param idx                         integer
---@param input_string                string
---@param chars_props                 era.m.minimap.mouse.IProps[]
---@return integer
---@return string
---@return era.m.minimap.mouse.IProps[]
local function update_mouse_props(idx, input_string, chars_props)
  while true do
    idx = idx + 1
    if idx > #chars_props then
      idx = 1
      input_string, chars_props = read_input_stream()
    end
    local mouse_props = assert(chars_props[idx])

    if mouse_props.winid == 0 or vim.tbl_contains({ LEFTMOUSE, LEFTRELEASE }, mouse_props.char) then
      break
    end

    if idx >= #chars_props then
      break
    end

    local next_props = chars_props[idx + 1]

    if next_props and (next_props.winid == 0 or vim.tbl_contains({ LEFTMOUSE, LEFTRELEASE }, next_props.char)) then
      break
    end
  end

  return idx, input_string, chars_props
end

---@param char                        string
---@param mouse_props                 era.m.minimap.mouse.IProps
---@return boolean is_on_bar
---@return boolean is_on_column
local function handle_initial_leftmouse_event(char, mouse_props)
  if mouse_props.winid < 0 then
    vim.api.nvim_feedkeys(char, "ni", false)
    return false, false
  end

  local props = view.get_props(mouse_props.winid)
  if not props then
    vim.api.nvim_feedkeys(char, "ni", false)
    return false, false
  end

  -- Check if click is within minimap column
  if mouse_props.col < props.col or mouse_props.col > props.col + props.width then
    vim.api.nvim_feedkeys(char, "ni", false)
    return false, false
  end

  vim.api.nvim_exec_autocmds("WinScrolled", {})
  vim.cmd.redraw()

  props = view.get_props(mouse_props.winid)
  if not props then
    return false, false
  end

  -- Check if click is on the scrollbar handle (for dragging)
  local is_on_bar = mouse_props.row >= props.row and mouse_props.row < props.row + props.height

  return is_on_bar, true
end

----------------------------------------------------------------------------------------------------
-- Public API
----------------------------------------------------------------------------------------------------

function M.handle_leftmouse()
  vim.api.nvim_feedkeys(LEFTMOUSE, "ni", false)
  if not view.enabled() then
    return
  end

  util.invalidate_virtual_topline_lookup()

  local count = 0
  local winid ---@type integer
  local scrollbar_offset ---@type integer
  local is_dragging = false

  ---@type integer, string, era.m.minimap.mouse.IProps[]
  local idx, input_string, chars_props = 1, "", {}

  while true do
    idx, input_string, chars_props = update_mouse_props(idx, input_string, chars_props)
    local mouse_props = assert(chars_props[idx])
    local str_idx = mouse_props.str_idx
    local char = mouse_props.char
    local mouse_winid = mouse_props.winid

    if char == t("<esc>") then
      vim.api.nvim_feedkeys(input_string:sub(str_idx + #char), "ni", false)
      return
    end

    if char ~= "\x80\xf5X" or count == 0 then
      local input_char = input_string:sub(str_idx)

      if mouse_winid == 0 then
        vim.api.nvim_feedkeys(input_char, "ni", false)
        return
      end

      if char == LEFTRELEASE then
        handle_leftrelease(count, input_char)
        return
      end

      if count == 0 then
        local is_on_bar, is_on_column = handle_initial_leftmouse_event(input_char, mouse_props)
        if not is_on_column then
          return
        end

        winid = mouse_winid
        local props = assert(view.get_props(mouse_winid))

        if is_on_bar then
          -- Click on scrollbar handle: enable dragging
          is_dragging = true
          scrollbar_offset = props.row - mouse_props.row
        else
          -- Click on minimap column but not on bar: jump to position
          local bufnr = vim.api.nvim_win_get_buf(winid)
          local bar_pos = mouse_props.row - 1 ---@type integer 0-based

          -- Check if clicking on a git sign
          local git_handler = require("era.m.minimap.handler.git")
          local hunk_lnum = git_handler.find_hunk_line_at_pos(bufnr, winid, bar_pos)

          if hunk_lnum then
            -- Jump to the hunk line
            vim.api.nvim_win_set_cursor(winid, { hunk_lnum, 0 })
            vim.api.nvim_set_current_win(winid)
          else
            -- Normal scroll: jump to proportional position
            local winheight = util.get_winheight(winid)
            local row0 = math.max(0, math.min(bar_pos, winheight - props.height))
            set_topline(winid, get_topline(winid, bufnr, row0, props.height))
          end

          vim.api.nvim_exec_autocmds("WinScrolled", {})
          vim.cmd.redraw()
          -- Wait for release and return
          while vim.fn.getchar() ~= LEFTRELEASE do
          end
          view.refresh()
          return
        end
      end

      if is_dragging and mouse_winid > 0 then
        local winheight = util.get_winheight(winid)
        local mouse_winrow = assert(vim.fn.getwininfo(mouse_winid)[1]).winrow
        local winrow = assert(vim.fn.getwininfo(winid)[1]).winrow
        local window_offset = mouse_winrow - winrow
        local row = mouse_props.row + window_offset + scrollbar_offset
        local props = view.get_props(winid)
        if not props then
          return
        end
        local row0 = math.max(0, math.min(row, winheight - props.height))
        if props.row ~= row0 then
          local bufnr = vim.api.nvim_win_get_buf(winid)
          set_topline(winid, get_topline(winid, bufnr, row0, props.height))
          vim.api.nvim_exec_autocmds("WinScrolled", {})
          vim.cmd.redraw()
        end
      end
      count = count + 1
    end
  end
end

return M

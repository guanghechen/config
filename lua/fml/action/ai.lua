local __module_name__ = "fml.action.ai" ---@type string

local NSNR_EDIT = vim.api.nvim_create_namespace("ai_edit_selection")

---@param lnum_start                   integer
---@param col_start                    integer
---@param lnum_end                     integer
---@param col_end                      integer
---@param chatbox_width                integer
---@param chatbox_height               integer
---@return integer row, integer col
local function calculate_chatbox_position(lnum_start, col_start, lnum_end, col_end, chatbox_width, chatbox_height)
  local winnr = vim.api.nvim_get_current_win()
  local win_height = vim.api.nvim_win_get_height(winnr)
  local win_width = vim.api.nvim_win_get_width(winnr)

  -- Get current window position info
  local wininfo = vim.fn.getwininfo(winnr)[1]
  local win_row = wininfo.winrow - 1 -- Convert to 0-indexed
  local win_col = wininfo.wincol - 1 -- Convert to 0-indexed

  -- Get cursor position (1-indexed from vim)
  local cursor_pos = vim.api.nvim_win_get_cursor(winnr)
  local cursor_line = cursor_pos[1] -- Absolute line number (1-indexed)
  local cursor_col = cursor_pos[2]

  -- Get window's top line to convert absolute positions to window-relative
  local win_top_line = vim.fn.line("w0") -- First visible line in window (1-indexed)

  -- Convert absolute line numbers to window-relative positions (0-indexed)
  local cursor_row = cursor_line - win_top_line -- Window-relative cursor row
  local selection_start_row = lnum_start - win_top_line -- Window-relative selection start
  local selection_end_row = lnum_end - win_top_line -- Window-relative selection end
  local selection_start_col = col_start - 1 -- Convert to 0-indexed
  local selection_end_col = col_end - 1 -- Convert to 0-indexed

  -- Determine cursor position relative to selection
  local cursor_above_selection = cursor_row < selection_start_row
  local cursor_below_selection = cursor_row > selection_end_row
  local cursor_left_of_selection = cursor_col < selection_start_col
  local cursor_right_of_selection = cursor_col > selection_end_col

  local preferred_row, preferred_col

  -- Start with cursor position as base (in window coordinates)
  preferred_col = cursor_col - math.floor(chatbox_width / 2)
  preferred_row = cursor_row - math.floor(chatbox_height / 2)

  -- Adjust position based on cursor location relative to selection to avoid overlap
  if cursor_above_selection then
    -- Cursor is above selection, place chatbox above cursor
    preferred_row = cursor_row - chatbox_height - 1
  elseif cursor_below_selection then
    -- Cursor is below selection, place chatbox below cursor
    preferred_row = cursor_row + 2
  else
    -- Cursor is within selection vertically, try above first, then below
    local above_row = cursor_row - chatbox_height - 1
    local below_row = cursor_row + 2

    if above_row >= 0 then
      preferred_row = above_row
    elseif below_row + chatbox_height <= win_height then
      preferred_row = below_row
    else
      -- Keep cursor-centered if neither works
      preferred_row = cursor_row - math.floor(chatbox_height / 2)
    end
  end

  -- Adjust horizontal position if cursor is at selection edges
  if cursor_left_of_selection then
    -- Cursor is left of selection, place chatbox to the left
    preferred_col = cursor_col - chatbox_width - 2
  elseif cursor_right_of_selection then
    -- Cursor is right of selection, place chatbox to the right
    preferred_col = cursor_col + 2
  end

  -- Ensure bounds are valid within window
  preferred_row = math.max(0, math.min(preferred_row, win_height - chatbox_height))
  preferred_col = math.max(0, math.min(preferred_col, win_width - chatbox_width))

  -- Convert to screen coordinates by adding window offset
  local screen_row = win_row + preferred_row
  local screen_col = win_col + preferred_col

  return screen_row, screen_col
end

---@protected
---@param template                     string
---@return nil
local function _edit(template)
  local bufnr = vim.api.nvim_get_current_buf() ---@type integer
  if vim.bo[bufnr].buftype ~= "" then
    std.reporter.warn({
      from = __module_name__,
      subject = "edit",
      message = "Cannot edit non-file buffer",
    })
    return
  end

  local filepath = vim.api.nvim_buf_get_name(bufnr) ---@type string
  if filepath == "" then
    std.reporter.warn({
      from = __module_name__,
      subject = "edit",
      message = "Cannot edit unnamed buffer",
    })
    return
  end

  local lnum_start, col_start, lnum_end, col_end = eve.buf.retrieve_visual_range()
  local location = std.uri.file_location(filepath, lnum_start, col_start, lnum_end, col_end)
  local lines = eve.buf.retrieve_visual_range_lines(bufnr, lnum_start, col_start, lnum_end, col_end) ---@type string[]
  local content = table.concat(lines, "\n") ---@type string
  local filetype = vim.bo[bufnr].filetype ---@type string

  local extmarkid = nil ---@type number|nil
  extmarkid = vim.api.nvim_buf_set_extmark(bufnr, NSNR_EDIT, lnum_start - 1, col_start - 1, {
    hl_group = "Visual",
    hl_mode = "combine",
    end_line = lnum_end - 1,
    end_col = col_end - 1,
    priority = vim.hl.priorities.user,
  })

  local chatbox ---@type eve.ux.Chatbox
  local ai_group = oxi.fn.uuid() ---@type string

  local function clear_selection()
    if extmarkid then
      vim.api.nvim_buf_del_extmark(bufnr, NSNR_EDIT, extmarkid)
      extmarkid = nil
    end
  end

  -- Calculate chatbox dimensions
  local chatbox_width = 60
  local chatbox_height = 6

  -- Calculate appropriate position based on selected content
  local chatbox_row, chatbox_col =
    calculate_chatbox_position(lnum_start, col_start, lnum_end, col_end, chatbox_width, chatbox_height)

  local selection_range = {
    lnum_start = lnum_start,
    col_start = col_start,
    lnum_end = lnum_end,
    col_end = col_end,
  }

  local request_base = {
    bufnr = bufnr,
    filepath = filepath,
    filetype = filetype,
    range = selection_range,
    content = content,
  }

  local initial_config = vim.tbl_extend("force", {}, request_base, { prompt = template })
  local default_prompt = eve.ai.render_inline_prompt(initial_config, template) or template
  local default_location = eve.ai.resolve_inline_location(initial_config)
    or string.format(":L%d:C%d-L%d:C%d", lnum_start, col_start, lnum_end, col_end)

  chatbox = eve.ux.Chatbox.new({
    width = chatbox_width,
    height = chatbox_height,
    title = string.format("%s %s", template:find("/refine", 1, true) and "Refine" or "Edit", default_location),
    filetype = "markdown",
    on_close = function()
      -- Clean up visual selection highlight
      clear_selection()
    end,
    on_confirm = function(prompt_lines)
      local prompt_text = table.concat(prompt_lines, "\n")
      local render_fn = template:find("/refine", 1, true) and eve.ai.refine_inline or eve.ai.edit_inline
      local payload = vim.tbl_extend("force", {}, request_base, {
        prompt = prompt_text,
        location = location,
      })
      local ok, message, should_close = render_fn(payload)

      if ok then
        chatbox:set_footer("✓ " .. message)
        std.reporter.log("INFO", {
          from = __module_name__,
          subject = location,
          message = string.format("✓ Sent request to Sidekick\n\nPrompt:\n%s", prompt_text),
          group = ai_group,
        })
        if should_close then
          clear_selection()
          chatbox:close()
          return true
        end
      else
        chatbox:set_footer("✗ " .. message)
        std.reporter.log("ERROR", {
          from = __module_name__,
          subject = location,
          message = string.format("✗ Failed to send request to Sidekick\nReason: %s", message),
          group = ai_group,
        })
      end

      return false
    end,
  })

  chatbox:open({
    initial_prompt = default_prompt,
    row = chatbox_row,
    col = chatbox_col,
    text_cursor_row = -1,
    text_cursor_col = -1,
  })
end

---@class fml.action.ai
local M = {}

---@return nil
function M.ask() end

---@return nil
function M.edit()
  _edit("/code {this}\n\n")
end

---@return nil
function M.refine()
  _edit("/refine {this}\n\n")
end

return M

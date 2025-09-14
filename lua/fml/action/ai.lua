local __module_name__ = "fml.action.ai" ---@type string

---@class fml.action.ai
local M = {}

local TIMEOUT_EDIT = 300 ---@type integer
local NSNR_EDIT = vim.api.nvim_create_namespace("claude_edit_selection")

---@return nil
function M.ask() end

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
  local win_top_line = vim.fn.line('w0') -- First visible line in window (1-indexed)

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

---@return nil
function M.edit()
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

  local extmarkid = nil ---@type number|nil
  extmarkid = vim.api.nvim_buf_set_extmark(bufnr, NSNR_EDIT, lnum_start - 1, col_start - 1, {
    hl_group = "Visual",
    hl_mode = "combine",
    end_line = lnum_end - 1,
    end_col = col_end - 1,
    priority = vim.hl.priorities.user,
  })

  local chatbox ---@type eve.ux.Chatbox
  local process_cur = nil ---@type vim.SystemObj|nil
  local ai_group = oxi.fn.uuid() ---@type string
  local terminated = false ---@type boolean
  local spinner_step = 200 ---@type integer
  local spinner_timer = vim.uv.new_timer() ---@type uv.uv_timer_t|nil
  local output ---@type string

  -- Declare cleanup function that will be used in chatbox on_close
  local function clear_spinner()
    terminated = true
    if spinner_timer then
      spinner_timer:stop()
      spinner_timer:close()
      spinner_timer = nil
    end
  end

  -- Calculate chatbox dimensions
  local chatbox_width = 60
  local chatbox_height = 6

  -- Calculate appropriate position based on selected content
  local chatbox_row, chatbox_col =
    calculate_chatbox_position(lnum_start, col_start, lnum_end, col_end, chatbox_width, chatbox_height)

  chatbox = eve.ux.Chatbox.new({
    width = chatbox_width,
    height = chatbox_height,
    title = string.format("Edit selected block (L%dC%d-L%dC%d)", lnum_start, col_start, lnum_end, col_end),
    filetype = "markdown",
    on_close = function()
      -- Clean up spinner timer
      clear_spinner()

      -- Clean up visual selection highlight
      if extmarkid then
        vim.api.nvim_buf_del_extmark(bufnr, NSNR_EDIT, extmarkid)
        extmarkid = nil
      end

      if process_cur then
        process_cur:kill(9)
        process_cur = nil
      end
    end,
    on_confirm = function(prompt_lines)
      local prompt = table.concat(prompt_lines, "\n")
      if #prompt == 0 then
        return true -- Close if empty
      end

      ---@type eve.builtin.ai.IEditInlineConfig
      local config = {
        prompt = prompt,
        filepath = filepath,
        range = {
          lnum_start = lnum_start,
          col_start = col_start,
          lnum_end = lnum_end,
          col_end = col_end,
        },
        location = location,
        content = table.concat(lines, "\n"),
        tools = { "Edit", "Read", "Write" },
        system_prompt = "Edit the given filepath directly.",
      }

      output = "Starting AI edit...\n" ---@type string

      local function update_notification(level)
        local message = terminated and output or (output .. " " .. std.fn.spinner(spinner_step)) ---@type string
        std.reporter.log(level or "INFO", {
          from = __module_name__,
          subject = location,
          message = message,
          group = ai_group,
        })
      end

      local callbacks = {
        on_start = function()
          chatbox:start_spinner("Processing...")
          -- Start spinner timer
          if spinner_timer then
            spinner_timer:start(0, 200, vim.schedule_wrap(update_notification))
          end
          update_notification()
        end,
        on_stdout = function(err, data)
          if err then
            output = output .. "\n" .. tostring(err)
          end
          if data then
            output = output .. data
          end
          update_notification()
        end,
        on_stderr = function(err, data)
          if err then
            output = output .. "\n" .. tostring(err)
          end
          if data then
            output = output .. data
          end
          update_notification("ERROR")
        end,
        on_success = function(callback_output)
          clear_spinner()
          chatbox:stop_spinner()

          -- Clean up visual selection highlight when process completes
          if extmarkid then
            vim.api.nvim_buf_del_extmark(bufnr, NSNR_EDIT, extmarkid)
            extmarkid = nil
          end

          -- Trigger checktime to reload buffers after AI edit completion
          vim.cmd("checktime")

          local final_message = output ~= "Starting AI edit...\n" and output or callback_output
          if #final_message > 0 then
            chatbox:set_footer("✓ AI completed")
            std.reporter.log("INFO", {
              from = __module_name__,
              subject = location,
              message = string.format("%s\n\n✓ AI edit completed", final_message),
              group = ai_group,
            })
            vim.defer_fn(function()
              chatbox:close()
            end, 1500)
          else
            chatbox:set_footer("⚠ No output returned")
            std.reporter.log("WARN", {
              from = __module_name__,
              subject = location,
              message = "⚠ AI edit completed but no output returned",
              group = ai_group,
            })
            vim.defer_fn(function()
              chatbox:close()
            end, 2000)
          end
        end,
        on_error = function(code, error_msg)
          clear_spinner()
          chatbox:stop_spinner()

          -- Clean up visual selection highlight when process completes
          if extmarkid then
            vim.api.nvim_buf_del_extmark(bufnr, NSNR_EDIT, extmarkid)
            extmarkid = nil
          end

          chatbox:set_footer("✗ Error: " .. error_msg)
          std.reporter.log("ERROR", {
            from = __module_name__,
            subject = location,
            message = string.format("✗ AI edit failed: %s\nExit code: %d", error_msg, code),
            group = ai_group,
          })
        end,
        on_timeout = function()
          clear_spinner()
          chatbox:stop_spinner()
          chatbox:set_footer("⏱ Command timed out")
          std.reporter.log("WARN", {
            from = __module_name__,
            subject = location,
            message = "⏱ AI edit timed out",
            group = ai_group,
          })
        end,
        on_complete = function()
          process_cur = nil
        end,
      }

      process_cur = eve.ai.edit_inline(config, callbacks, TIMEOUT_EDIT)

      if not process_cur then
        clear_spinner()
        chatbox:set_footer("✗ Failed to start AI")
        std.reporter.log("ERROR", {
          from = __module_name__,
          subject = location,
          message = "✗ Failed to start AI edit command",
          group = ai_group,
        })
        vim.defer_fn(function()
          chatbox:close()
        end, 2000)
        return false
      end

      return false
    end,
  })

  chatbox:open({
    initial_lines = {},
    row = chatbox_row,
    col = chatbox_col,
    text_cursor_row = 1,
    text_cursor_col = 0,
  })
end

return M

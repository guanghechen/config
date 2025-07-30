local __module_name__ = "fml.action.ai" ---@type string

---@class fml.action.ai
local M = {}

local GROUP_EDIT = "ghc:claude-edit"
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

  -- Calculate the visual selection center
  local selection_center_row = math.floor((lnum_start + lnum_end) / 2)
  local selection_center_col = math.floor((col_start + col_end) / 2)

  -- Try to place chatbox to the right of the selection
  local preferred_row = selection_center_row - math.floor(chatbox_height / 2)
  local preferred_col = math.max(col_end + 2, selection_center_col + 10)

  -- If chatbox would go off the right edge, try left side
  if preferred_col + chatbox_width > win_width then
    preferred_col = math.max(0, col_start - chatbox_width - 2)
  end

  -- If still doesn't fit or goes off left edge, center horizontally
  if preferred_col < 0 or preferred_col + chatbox_width > win_width then
    preferred_col = math.max(0, math.floor((win_width - chatbox_width) / 2))
  end

  -- Ensure chatbox stays within window bounds vertically
  preferred_row = math.max(0, math.min(preferred_row, win_height - chatbox_height))

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
      group = GROUP_EDIT,
      subject = "edit",
      message = "Cannot edit non-file buffer",
      details = { bufnr = bufnr },
    })
    return
  end

  local filepath = vim.api.nvim_buf_get_name(bufnr) ---@type string
  if filepath == "" then
    std.reporter.warn({
      from = __module_name__,
      group = GROUP_EDIT,
      subject = "edit",
      message = "Cannot edit unnamed buffer",
      details = { bufnr = bufnr, filepath = filepath },
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

      local config = {
        prompt = prompt,
        location = location,
        content = table.concat(lines, "\n"),
        tools = { "Edit", "Read", "Write" },
        system_prompt = "Edit the given filepath directly.",
      }

      local callbacks = {
        on_start = function()
          chatbox:start_spinner("Processing...")
        end,
        on_success = function(output)
          chatbox:stop_spinner()

          -- Clean up visual selection highlight when process completes
          if extmarkid then
            vim.api.nvim_buf_del_extmark(bufnr, NSNR_EDIT, extmarkid)
            extmarkid = nil
          end

          -- Trigger checktime to reload buffers after AI edit completion
          vim.cmd("checktime")

          if #output > 0 then
            chatbox:set_footer("✓ AI completed")
            std.reporter.info({
              from = __module_name__,
              group = GROUP_EDIT,
              subject = "edit (✓ completed)",
              message = output,
            })
            vim.defer_fn(function()
              chatbox:close()
            end, 1500)
          else
            chatbox:set_footer("⚠ No output returned")
            std.reporter.warn({
              from = __module_name__,
              group = GROUP_EDIT,
              subject = "edit (✓ completed)",
            })
            vim.defer_fn(function()
              chatbox:close()
            end, 2000)
          end
        end,
        on_error = function(code, error_msg)
          chatbox:stop_spinner()

          -- Clean up visual selection highlight when process completes
          if extmarkid then
            vim.api.nvim_buf_del_extmark(bufnr, NSNR_EDIT, extmarkid)
            extmarkid = nil
          end

          chatbox:set_footer("✗ Error: " .. error_msg)
          std.reporter.error({
            from = __module_name__,
            group = GROUP_EDIT,
            subject = "edit (✗ failed)",
            details = { code = code, error = error_msg },
          })
        end,
        on_timeout = function()
          chatbox:stop_spinner()
          chatbox:set_footer("⏱ Command timed out")
          std.reporter.warn({
            from = __module_name__,
            group = GROUP_EDIT,
            subject = "edit (⏱ timed out)",
          })
        end,
        on_complete = function()
          process_cur = nil
        end,
      }

      process_cur = eve.ai.edit_inline(config, callbacks, TIMEOUT_EDIT)

      if not process_cur then
        chatbox:set_footer("✗ Failed to start AI")
        std.reporter.error({
          from = __module_name__,
          group = GROUP_EDIT,
          subject = "edit (✗ failed)",
          message = "Failed to start AI command",
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

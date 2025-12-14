local __module_name__ = "fml.action.ai" ---@type string

---@class fml.action.ai
local M = {}

---@return nil
function M.edit()
  local bufnr = vim.api.nvim_get_current_buf() ---@type integer
  if vim.bo[bufnr].buftype ~= "" then
    ark.reporter.warn({
      from = __module_name__,
      subject = "edit",
      message = "Cannot edit non-standard buffer",
    })
    return
  end

  local filepath = vim.api.nvim_buf_get_name(0) ---@type string
  if filepath == "" then
    ark.reporter.warn({
      from = __module_name__,
      subject = "edit",
      message = "Cannot edit unnamed buffer",
    })
    return
  end

  local location ---@type string|nil
  local location_err ---@type string|nil
  local lnum_start, col_start, lnum_end, col_end = dot.buf.retrieve_visual_range()
  local content ---@type string

  if
    lnum_start == nil
    or col_start == nil
    or lnum_end == nil
    or col_end == nil
    or ((lnum_start == lnum_end) and (col_start == col_end))
  then
    location, location_err = dot.uri.file_location({
      filepath = filepath,
    })
    content = location or filepath
  else
    location, location_err = dot.uri.file_location({
      filepath = filepath,
      start_lnum = lnum_start,
      start_col = col_start,
      end_lnum = lnum_end,
      end_col = col_end,
    })
    local lines = dot.buf.retrieve_visual_range_lines(bufnr, lnum_start, col_start, lnum_end, col_end)
    content = table.concat(lines, "\n")
  end

  if location == nil then
    ark.reporter.warn({
      from = __module_name__,
      subject = "edit",
      message = "Failed to format selection location.",
      details = {
        error = location_err,
        filepath = filepath,
        start_lnum = lnum_start,
        start_col = col_start,
        end_lnum = lnum_end,
        end_col = col_end,
      },
    })
    location = string.format("@%s", filepath)
  end

  vim.schedule(function()
    vim.fn.setreg('"', content)
  end)
  dot.command.definitions.notepad.append_content:execute("\n" .. location .. " ")
end

---@return nil
function M.attach_agent()
  dot.ux.widget.ai.action.show_attach_picker()
end

---@return nil
function M.detach_agent()
  dot.ux.widget.ai.action.show_detach_picker()
end

---@return nil
function M.submit_buffer()
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  local text = dot.buf.retrieve_split_block(winnr) ---@type string
  dot.ux.widget.ai.action.send_to_attached(text, true)
end

---@return nil
function M.submit_selection()
  local text = dot.buf.retrieve_selected_text() or ""
  if #text > 0 then
    dot.ux.widget.ai.action.send_to_attached(text, true)
  end
end

---@return nil
function M.send_buffer()
  local bufnr = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local text = table.concat(lines, "\n")
  dot.ux.widget.ai.action.send_to_attached(text, false)
end

---@return nil
function M.send_selection()
  local text = dot.buf.retrieve_selected_text() or ""
  if #text > 0 then
    dot.ux.widget.ai.action.send_to_attached(text, false)
  end
end

---@return nil
function M.send_this()
  local bufnr = vim.api.nvim_get_current_buf() ---@type integer
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local text = table.concat(lines, "\n")
  dot.ux.widget.ai.action.send_to_attached(text, false)
end

---@return nil
function M.send_file()
  local filepath = vim.api.nvim_buf_get_name(0) ---@type string
  if filepath == "" then
    ark.reporter.warn({
      from = __module_name__,
      subject = "send_file",
      message = "Cannot send: buffer has no file path.",
    })
    return
  end

  local location, _ = dot.uri.file_location({ filepath = filepath })
  if location then
    dot.ux.widget.ai.action.send_to_attached(location, false)
  end
end

---@return nil
function M.select_prompt()
  dot.ux.widget.ai.action.show_prompt_picker()
end

return M

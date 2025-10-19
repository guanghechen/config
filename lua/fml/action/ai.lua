local __module_name__ = "fml.action.ai" ---@type string

---@class fml.action.ai
local M = {}

---@return nil
function M.edit()
  local bufnr = vim.api.nvim_get_current_buf() ---@type integer
  if vim.bo[bufnr].buftype ~= "" then
    std.reporter.warn({
      from = __module_name__,
      subject = "edit",
      message = "Cannot edit non-standard buffer",
    })
    return
  end

  local filepath = vim.api.nvim_buf_get_name(0) ---@type string
  if filepath == "" then
    std.reporter.warn({
      from = __module_name__,
      subject = "edit",
      message = "Cannot edit unnamed buffer",
    })
    return
  end

  local location ---@type string|nil
  local location_err ---@type string|nil
  local lnum_start, col_start, lnum_end, col_end = eve.buf.retrieve_visual_range()
  if
    lnum_start == nil
    or col_start == nil
    or lnum_end == nil
    or col_end == nil
    or ((lnum_start == lnum_end) and (col_start == col_end))
  then
    location = string.format("@%s", filepath)
    location_err = nil
  else
    location, location_err = std.uri.file_location({
      filepath = filepath,
      start_lnum = lnum_start,
      start_col = col_start,
      end_lnum = lnum_end,
      end_col = col_end,
    })
  end

  if location == nil then
    std.reporter.warn({
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

  local note = eve.notepad.ensure_named_item("chatbox") ---@type eve.builtin.notepad.INotepadItem
  eve.notepad.append_content(note.uuid, location .. "\n")
  eve.notepad.focus_uuid(note.uuid)

  local widget = require("fml.action.notepad").ensure()
  if widget ~= nil then
    widget:focus()
  end
end

return M

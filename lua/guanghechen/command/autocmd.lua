---@class guanghechen.command.autocmd
local M = {}

local augroups = {
  enable_spell = fml.util.augroup("enable_spell"),
  enable_wrap = fml.util.augroup("enable_wrap"),
  goto_last_loction = fml.util.augroup("goto_last_loction"),
  session_autosave = fml.util.augroup("session_autosave"),
  set_fileformat = fml.util.augroup("set_fileformat"),
  set_filetype = fml.util.augroup("set_filetype"),
  unlist_buffer = fml.util.augroup("unlist_buffer"),
}

-- enable spell in text filetypes
---@param opts {pattern: table}
function M.autocmd_enable_spell(opts)
  local pattern = opts.pattern
  vim.api.nvim_create_autocmd("FileType", {
    group = augroups.enable_spell,
    pattern = pattern,
    callback = function()
      vim.opt_local.spell = true
    end,
  })
end

-- go to last loc when opening a buffer
---@param opts {exclude: string[]}
function M.autocmd_goto_last_location(opts)
  local exclude = opts.exclude
  vim.api.nvim_create_autocmd({ "BufReadPost" }, {
    group = augroups.goto_last_loction,
    callback = function(event)
      local buf = event.buf
      if vim.tbl_contains(exclude, vim.bo[buf].filetype) or vim.b[buf].lazyvim_last_loc then
        return
      end
      vim.b[buf].lazyvim_last_loc = true
      local mark = vim.api.nvim_buf_get_mark(buf, '"')
      local lcount = vim.api.nvim_buf_line_count(buf)
      if mark[1] > 0 and mark[1] <= lcount then
        pcall(vim.api.nvim_win_set_cursor, 0, mark)
      end
    end,
  })
end

---@param opts {pattern:string[], format?: "unix" | "dos"}
function M.autocmd_set_fileformat(opts)
  local pattern = opts.pattern
  local format = opts.format or "unix"
  vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
    group = augroups.set_fileformat,
    pattern = pattern,
    callback = function()
      vim.bo.fileformat = format
    end,
  })
end

return M

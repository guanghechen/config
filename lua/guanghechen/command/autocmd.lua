---@class guanghechen.command.autocmd
local M = {}

local augroups = {
  close_with_q = fml.util.augroup("close_with_q"),
  enable_spell = fml.util.augroup("enable_spell"),
  enable_wrap = fml.util.augroup("enable_wrap"),
  goto_last_loction = fml.util.augroup("goto_last_loction"),
  remember_telescope_prompt = fml.util.augroup("remember_telescope_prompt"),
  session_autosave = fml.util.augroup("session_autosave"),
  set_fileformat = fml.util.augroup("set_fileformat"),
  set_filetype = fml.util.augroup("set_filetype"),
  set_tabstop = fml.util.augroup("set_tabstop"),
  unlist_buffer = fml.util.augroup("unlist_buffer"),
}

-- close some filetypes with <q>
---@param opts {pattern: table}
function M.autocmd_close_with_q(opts)
  local pattern = opts.pattern
  vim.api.nvim_create_autocmd("FileType", {
    group = augroups.close_with_q,
    pattern = pattern,
    callback = function(event)
      vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = event.buf, noremap = true, silent = true })
    end,
  })
end

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

-- enable wrap in text filetypes
---@param opts {pattern: table}
function M.autocmd_enable_wrap(opts)
  local pattern = opts.pattern
  vim.api.nvim_create_autocmd("FileType", {
    group = augroups.enable_wrap,
    pattern = pattern,
    callback = function()
      local winnr = vim.api.nvim_get_current_win() ---@type integer
      if not fml.api.state.is_floating_win(winnr) then
        vim.opt_local.wrap = true
      end
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

---@param prompt_bufnr number
---@param callback fun(prompt:string):nil
function M.autocmd_remember_telescope_prompt(prompt_bufnr, callback)
  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
    buffer = prompt_bufnr,
    group = augroups.remember_telescope_prompt,
    callback = function()
      local action_state = require("telescope.actions.state")
      local picker = action_state.get_current_picker(prompt_bufnr or 0)

      if picker then
        local prompt = picker:_get_prompt()
        if prompt then
          callback(prompt)
        end
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

---@param opts {filetype_map: table<string, string[]>}
function M.autocmd_set_filetype(opts)
  local filetype_map = opts.filetype_map
  for filetype, file_patterns in pairs(filetype_map) do
    vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
      group = augroups.set_filetype,
      pattern = file_patterns,
      callback = function()
        vim.bo.filetype = filetype
      end,
    })
  end
end

---@param opts {pattern: string[], width: number}
function M.autocmd_set_tabstop(opts)
  local pattern = opts.pattern ---@type string[]
  local width = opts.width ---@type number
  vim.api.nvim_create_autocmd("FileType", {
    pattern = pattern,
    group = augroups.set_tabstop,
    callback = function()
      vim.opt.shiftwidth = width
      vim.opt.softtabstop = width -- set the tab width
      vim.opt.tabstop = width -- set the tab width
    end,
  })
end

-- unlist some buffers with specified filetypes for easier close.
---@param opts {pattern: table}
function M.autocmd_unlist_buffer(opts)
  local pattern = opts.pattern
  vim.api.nvim_create_autocmd("FileType", {
    group = augroups.unlist_buffer,
    pattern = pattern,
    callback = function(event)
      vim.bo[event.buf].buflisted = false
    end,
  })
end

return M

---@class guanghechen.core.action.autocmd
local M = {}

-- Check if we need to reload the file when it changed
function M.autocmd_checktime()
  vim.api.nvim_create_autocmd({ "FocusGained", "TermClose", "TermLeave" }, {
    group = fml.fn.augroup("checktime"),
    callback = function()
      if vim.o.buftype ~= "nofile" then
        vim.cmd("checktime")
      end
    end,
  })
end

---@param bufnr number
---@param callback? fun(bufnr:number):nil
function M.autocmd_clear_buftype_extra(bufnr, callback)
  vim.api.nvim_create_autocmd({ "BufLeave", "BufUnload" }, {
    buffer = bufnr,
    group = fml.fn.augroup("clear_buftype_extra"),
    callback = function()
      ghc.context.transient.buftype_extra:next(nil)
      if callback then
        callback(bufnr)
      end
    end,
  })
end

-- close some filetypes with <q>
---@param opts {pattern: table}
function M.autocmd_close_with_q(opts)
  local function close()
    ghc.context.transient.buftype_extra:next(nil)
    vim.cmd("close")
  end

  local pattern = opts.pattern
  vim.api.nvim_create_autocmd("FileType", {
    group = fml.fn.augroup("close_with_q"),
    pattern = pattern,
    callback = function(event)
      vim.bo[event.buf].buflisted = false
      vim.keymap.set("n", "q", close, { buffer = event.buf, noremap = true, silent = true })
    end,
  })
end

-- enable spell in text filetypes
---@param opts {pattern: table}
function M.autocmd_enable_spell(opts)
  local pattern = opts.pattern
  vim.api.nvim_create_autocmd("FileType", {
    group = fml.fn.augroup("enable_spell"),
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
    group = fml.fn.augroup("enable_wrap"),
    pattern = pattern,
    callback = function()
      vim.opt_local.wrap = true
    end,
  })
end

-- go to last loc when opening a buffer
---@param opts {exclude: string[]}
function M.autocmd_goto_last_location(opts)
  local exclude = opts.exclude
  vim.api.nvim_create_autocmd({ "BufReadPost" }, {
    group = fml.fn.augroup("goto_last_loction"),
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

-- Highlight on yank
function M.autocmd_highlight_yank()
  vim.api.nvim_create_autocmd({ "TextYankPost" }, {
    group = fml.fn.augroup("highlight_yank"),
    callback = function()
      vim.highlight.on_yank()
    end,
  })
end

function M.autocmd_lsp_show_progress()
  vim.api.nvim_create_autocmd("LspProgress", {
    group = fml.fn.augroup("lsp_show_progress"),
    callback = function(args)
      if string.find(args.match, "end") then
        vim.cmd("redrawstatus")
      end
      vim.cmd("redrawstatus")
    end,
  })
end

---@param prompt_bufnr number
---@param callback fun(prompt:string):nil
function M.autocmd_remember_telescope_prompt(prompt_bufnr, callback)
  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
    buffer = prompt_bufnr,
    group = fml.fn.augroup("remember_telescope_prompt"),
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

-- resize splits if window got resized
function M.autocmd_resize_splits()
  vim.api.nvim_create_autocmd({ "VimResized" }, {
    group = fml.fn.augroup("resize_splits"),
    callback = function()
      local current_tab = vim.fn.tabpagenr()
      vim.cmd("tabdo wincmd =")
      vim.cmd("tabnext " .. current_tab)
    end,
  })
end

function M.autocmd_session_autosave()
  if vim.fn.argc() < 1 and fml.path.is_git_repo() then
    vim.api.nvim_create_autocmd("VimLeavePre", {
      group = fml.fn.augroup("session_autosave"),
      callback = function()
        ghc.command.session.autosave()
      end,
    })
  end
end

---@param opts {pattern:string[], format?: "unix" | "dos"}
function M.autocmd_set_fileformat(opts)
  local pattern = opts.pattern
  local format = opts.format or "unix"
  vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
    group = fml.fn.augroup("set_fileformat"),
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
      group = fml.fn.augroup("set_filetype"),
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
    group = fml.fn.augroup("set_tabstop"),
    pattern = pattern,
    callback = function()
      vim.opt.shiftwidth = width
      vim.opt.softtabstop = width -- set the tab width
      vim.opt.tabstop = width     -- set the tab width
    end,
  })
end

function M.autocmd_toggle_linenumber()
  local augroup = fml.fn.augroup("toggle_linenumber")

  vim.api.nvim_create_autocmd({ "InsertLeave" }, {
    pattern = "*",
    group = augroup,
    callback = function()
      if vim.o.nu and vim.api.nvim_get_mode().mode == "n" then
        if ghc.context.client.relativenumber:get_snapshot() then
          vim.opt.relativenumber = true
        end
      end
    end,
  })

  vim.api.nvim_create_autocmd({ "InsertEnter" }, {
    pattern = "*",
    group = augroup,
    callback = function()
      if vim.o.nu then
        vim.opt.relativenumber = false
        vim.cmd("redraw")
      end
    end,
  })
end

-- unlist some buffers with specified filetypes for easier close.
---@param opts {pattern: table}
function M.autocmd_unlist_buffer(opts)
  local pattern = opts.pattern
  vim.api.nvim_create_autocmd("FileType", {
    group = fml.fn.augroup("unlist_buffer"),
    pattern = pattern,
    callback = function(event)
      vim.bo[event.buf].buflisted = false
    end,
  })
end

return M

local action_session = require("guanghechen.core.action.session")
local action_window = require("guanghechen.core.action.window")
local context_session = require("guanghechen.core.context.session")

---@class guanghechen.core.action.autocmd
local M = {}

function M.augroup(name)
  return vim.api.nvim_create_augroup("ghc_" .. name, { clear = true })
end

function M.autocmd_startup()
  local group = M.augroup("startup")

  -- Clear jumplist
  -- See https://superuser.com/questions/1642954/how-to-start-vim-with-a-clean-jumplist
  local function auto_clear_jumps()
    vim.schedule(function()
      vim.cmd("clearjumps")
    end)
  end

  -- Auto cd the directory:
  -- 1. the opend file is under a git repo, let's remember the the git repo path as A, and assume the
  --    git repo directory of the shell cwd is B.
  --
  --    a) If A is different from B, then auto cd the A.
  --    b) If A is the same as B, then no action needed.
  -- 2. the opened file is not under a git repo, then auto cd the directory of the opened file.
  local function auto_change_dir()
    if vim.fn.expand("%") ~= "" then
      local cwd = vim.fn.getcwd()
      local p = vim.fn.expand("%:p:h")

      local A = fml.path.locate_git_repo(p)
      local B = fml.path.locate_git_repo(cwd)

      if A == nil then
        vim.cmd("cd " .. p .. "")
      elseif A ~= B then
        vim.cmd("cd " .. A .. "")
      end
    end
  end

  vim.api.nvim_create_autocmd({ "VimEnter" }, {
    group = group,
    callback = function()
      auto_clear_jumps()
      auto_change_dir()
    end,
  })
end

-- Check if we need to reload the file when it changed
function M.autocmd_checktime()
  vim.api.nvim_create_autocmd({ "FocusGained", "TermClose", "TermLeave" }, {
    group = M.augroup("checktime"),
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
    group = M.augroup("clear_buftype_extra"),
    callback = function()
      context_session.buftype_extra:next(nil)
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
    context_session.buftype_extra:next(nil)
    vim.cmd("close")
  end

  local pattern = opts.pattern
  vim.api.nvim_create_autocmd("FileType", {
    group = M.augroup("close_with_q"),
    pattern = pattern,
    callback = function(event)
      vim.bo[event.buf].buflisted = false
      vim.keymap.set("n", "q", close, { buffer = event.buf, noremap = true, silent = true })
    end,
  })
end

-- Auto create dir when saving a file, in case some intermediate directory does not exist
function M.autocmd_create_dirs()
  vim.api.nvim_create_autocmd({ "BufWritePre" }, {
    group = M.augroup("create_dirs"),
    callback = function(event)
      if event.match:match("^%w%w+:[\\/][\\/]") then
        return
      end
      local file = vim.uv.fs_realpath(event.match) or event.match
      vim.fn.mkdir(vim.fn.fnamemodify(file, ":p:h"), "p")
    end,
  })
end

-- enable spell in text filetypes
---@param opts {pattern: table}
function M.autocmd_enable_spell(opts)
  local pattern = opts.pattern
  vim.api.nvim_create_autocmd("FileType", {
    group = M.augroup("enable_spell"),
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
    group = M.augroup("enable_wrap"),
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
    group = M.augroup("goto_last_loction"),
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
    group = M.augroup("highlight_yank"),
    callback = function()
      vim.highlight.on_yank()
    end,
  })
end

function M.autocmd_remember_last_tabnr()
  vim.api.nvim_create_autocmd({ "TabLeave" }, {
    group = M.augroup("remember_last_tabnr"),
    callback = function()
      local tabnr_current = vim.api.nvim_get_current_tabpage()
      vim.g.ghc_last_tabnr = tabnr_current
    end,
  })
end

---@param opts { prompt_bufnr:number, sync_path:boolean, callback?: fun():nil}
function M.autocmd_remember_spectre_prompt(opts)
  local prompt_bufnr = opts.prompt_bufnr ---@type number
  local sync_path = opts.sync_path ---@type boolean
  local callback = opts.callback ---@type (fun():nil)|nil

  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
    buffer = prompt_bufnr,
    group = M.augroup("remember_telescope_prompt"),
    callback = function()
      local state = require("spectre.actions").get_state()
      local replace_pattern = state.query.replace_query ---@type string
      local search_pattern = state.query.search_query ---@type string

      fml.context.replace.search_pattern:next(search_pattern)
      fml.context.replace.replace_pattern:next(replace_pattern)

      if sync_path then
        local query_path = state.query.path ---@type string
        context_session.replace_path:next(query_path)
      end

      if type(callback) == "function" then
        callback()
      end
    end,
  })
end

---@param prompt_bufnr number
---@param callback fun(prompt:string):nil
function M.autocmd_remember_telescope_prompt(prompt_bufnr, callback)
  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
    buffer = prompt_bufnr,
    group = M.augroup("remember_telescope_prompt"),
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
    group = M.augroup("resize_splits"),
    callback = function()
      local current_tab = vim.fn.tabpagenr()
      vim.cmd("tabdo wincmd =")
      vim.cmd("tabnext " .. current_tab)
    end,
  })
end

function M.autocmd_session_autosave()
  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = M.augroup("session_autosave"),
    callback = function()
      action_session.session_autosave()
    end,
  })
end

---@param opts {pattern:string[], format?: "unix" | "dos"}
function M.autocmd_set_fileformat(opts)
  local pattern = opts.pattern
  local format = opts.format or "unix"
  vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
    group = M.augroup("set_fileformat"),
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
      group = M.augroup("set_filetype"),
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
    group = M.augroup("set_tabstop"),
    pattern = pattern,
    callback = function()
      vim.opt.shiftwidth = width
      vim.opt.softtabstop = width -- set the tab width
      vim.opt.tabstop = width -- set the tab width
    end,
  })
end

function M.autocmd_toggle_linenumber()
  local augroup = M.augroup("toggle_linenumber")

  vim.api.nvim_create_autocmd({ "InsertLeave" }, {
    pattern = "*",
    group = augroup,
    callback = function()
      if vim.o.nu and vim.api.nvim_get_mode().mode == "n" then
        if fml.context.shared.relativenumber:get_snapshot() then
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
    group = M.augroup("unlist_buffer"),
    pattern = pattern,
    callback = function(event)
      vim.bo[event.buf].buflisted = false
    end,
  })
end

function M.autocmd_window_update_history()
  action_window.register_autocmd_window_history(M.augroup)
end

return M

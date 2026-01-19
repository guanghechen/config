---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.diffview.pane.sbs" ---@type string

---Side-by-side diff pane for diffview.
---Handles buffer creation, git content loading, and diff display.
---@class era.m.diffview.pane.sbs
local M = {}

----------------------------------------------------------------------------------------------------
-- Constants
----------------------------------------------------------------------------------------------------

local config = require("era.m.diffview.config")

---@type table<string, any>
local BUFOPTS_SBS = config.BUFOPTS_SBS

---@type table<string, any>
local BUFOPTS_PANEL = config.BUFOPTS_PANEL

---@type era.m.diffview.IWinopts
local WINOPTS_SBS = config.WINOPTS_SBS

---@type string[]
local TRACKED_WINOPTS = config.TRACKED_WINOPTS

---@type table<integer, integer>
local fold_cache = {}

---@return integer
local function get_foldlevel()
  if dot.context.diffview.flag_fold_unchanges:snapshot() then
    return WINOPTS_SBS.foldlevel
  end
  return 99
end

---@param winnr                         integer
---@param force                         ?boolean
local function apply_foldlevel(winnr, force)
  if not vim.api.nvim_win_is_valid(winnr) then
    return
  end

  local level = get_foldlevel()
  local cached_level = fold_cache[winnr]
  if not force and cached_level == level then
    return
  end

  local current = vim.api.nvim_get_option_value("foldlevel", { win = winnr, scope = "local" }) ---@type integer
  if current ~= level then
    vim.api.nvim_set_option_value("foldlevel", level, { win = winnr, scope = "local" })
  end

  fold_cache[winnr] = level

  vim.schedule(function()
    if not vim.api.nvim_win_is_valid(winnr) then
      return
    end
    if level <= 0 then
      pcall(function() vim.cmd("silent! normal! zM") end)
      return
    end
    pcall(function() vim.cmd("silent! normal! zR") end)
  end)
end

----------------------------------------------------------------------------------------------------
-- Null buffer management
----------------------------------------------------------------------------------------------------

local null_bufnr = nil ---@type integer|nil

---Get or create the null buffer (for deleted files or binary files)
---@return integer
function M.get_null_buffer()
  if null_bufnr and vim.api.nvim_buf_is_valid(null_bufnr) then
    return null_bufnr
  end

  -- Check if there's already a buffer with this name
  local existing = vim.fn.bufnr("diffview://null")
  if existing ~= -1 and vim.api.nvim_buf_is_valid(existing) then
    null_bufnr = existing
    return null_bufnr
  end

  null_bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(null_bufnr, "diffview://null")

  for opt, val in pairs(BUFOPTS_PANEL) do
    vim.api.nvim_set_option_value(opt, val, { buf = null_bufnr })
  end
  vim.api.nvim_set_option_value("filetype", config.FT.SBS, { buf = null_bufnr })

  return null_bufnr
end

----------------------------------------------------------------------------------------------------
-- Buffer creation and management
----------------------------------------------------------------------------------------------------

---Create or find a side-by-side buffer
---@param name                          string                          unique buffer name
---@return integer                      bufnr
function M.create_sbs_buffer(name)
  local existing = vim.fn.bufnr(name)
  if existing ~= -1 then
    return existing
  end

  local bufnr = vim.api.nvim_create_buf(false, false)
  vim.api.nvim_buf_set_name(bufnr, name)

  for opt, val in pairs(BUFOPTS_SBS) do
    vim.api.nvim_set_option_value(opt, val, { buf = bufnr })
  end
  vim.api.nvim_set_option_value("filetype", config.FT.SBS, { buf = bufnr })

  return bufnr
end

---Find or create a local file buffer
---@param filepath                      string                          absolute path
---@return integer                      bufnr
function M.find_or_create_local_buffer(filepath)
  local bufnr = vim.fn.bufnr(filepath)
  if bufnr ~= -1 then
    vim.api.nvim_set_option_value("buflisted", true, { buf = bufnr })
    return bufnr
  end

  bufnr = vim.fn.bufadd(filepath)
  vim.fn.bufload(bufnr)
  vim.api.nvim_set_option_value("buflisted", true, { buf = bufnr })

  return bufnr
end

----------------------------------------------------------------------------------------------------
-- Git content loading
----------------------------------------------------------------------------------------------------

---Load content from git object into buffer.
---@async
---@param object                        string                          git object (e.g., "HEAD:path" or ":path")
---@param bufnr                         integer                         target buffer
---@param token                         ?stl.c.CancellationToken
---@return boolean ok
function M.load_git_content(object, bufnr, token)
  local future = stl.git.exec.exec({ "show", object }, { cwd = dot.path.workspace() }, token)
  local result = future:await()

  if not result then
    stl.reporter.error({
      from = __module_name__,
      subject = "load_git_content",
      message = "exec returned nil result for object: " .. object,
    })
    return false
  end

  stl.async.scheduler()

  if not vim.api.nvim_buf_is_valid(bufnr) then
    return false
  end

  if result.code ~= 0 then
    vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr })
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {})
    vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr })
    return false
  end

  local lines = result.lines

  -- Remove trailing empty line if present (vim.diff artifact)
  if #lines > 0 and lines[#lines] == "" then
    lines[#lines] = nil
  end

  vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr })
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr })
  vim.api.nvim_set_option_value("modified", false, { buf = bufnr })

  return true
end

----------------------------------------------------------------------------------------------------
-- Window options management
----------------------------------------------------------------------------------------------------

---@type table<integer, table<string, any>>
local winopts_store = {}

---Save window options for later restoration
---@param bufnr                         integer
---@param winnr                         integer
function M.save_winopts(bufnr, winnr)
  if winopts_store[bufnr] then
    return
  end

  if not vim.api.nvim_win_is_valid(winnr) then
    return
  end

  winopts_store[bufnr] = {}
  for _, opt in ipairs(TRACKED_WINOPTS) do
    winopts_store[bufnr][opt] = vim.api.nvim_get_option_value(opt, { win = winnr, scope = "local" })
  end

  -- Clean up store entry when buffer is wiped out to prevent memory leak
  vim.api.nvim_create_autocmd("BufWipeout", {
    buffer = bufnr,
    once = true,
    callback = function()
      winopts_store[bufnr] = nil
    end,
  })
end

---Restore saved window options
---@param bufnr                         integer
function M.restore_winopts(bufnr)
  local saved = winopts_store[bufnr]
  if not saved then
    return
  end

  if not vim.api.nvim_buf_is_valid(bufnr) then
    winopts_store[bufnr] = nil
    return
  end

  -- Find a window displaying this buffer
  local wins = vim.fn.win_findbuf(bufnr)
  local winnr = wins[1]

  if winnr then
    for opt, val in pairs(saved) do
      pcall(function()
        vim.api.nvim_set_option_value(opt, val, { win = winnr, scope = "local" })
      end)
    end
  end

  winopts_store[bufnr] = nil
end

---Clear saved window options for a buffer
---@param bufnr                         integer
function M.clear_winopts(bufnr)
  winopts_store[bufnr] = nil
end

----------------------------------------------------------------------------------------------------
-- winhighlight generation
----------------------------------------------------------------------------------------------------

---Generate winhighlight string for sbs windows
---@param panel_type                    "sbs_left"|"sbs_right"
---@return string
local function gen_winhl(panel_type)
  local parts = {
    "CursorLine:m_dv_cursorline",
    "EndOfBuffer:m_dv_eob",
    "FoldColumn:m_dv_normal",
    "Normal:m_dv_normal",
    "SignColumn:m_dv_normal",
    "WinSeparator:m_dv_winsep",
  }

  if panel_type == "sbs_left" then
    vim.list_extend(parts, {
      "DiffAdd:m_dv_del",
      "DiffChange:m_dv_del",
      "DiffDelete:m_dv_del_dim",
      "DiffText:m_dv_del_inline",
    })
  elseif panel_type == "sbs_right" then
    vim.list_extend(parts, {
      "DiffAdd:m_dv_add",
      "DiffChange:m_dv_add",
      "DiffDelete:m_dv_add_dim",
      "DiffText:m_dv_add_inline",
    })
  end

  return table.concat(parts, ",")
end

---Apply side-by-side window options (non-diff options only, for immediate display)
---@param winnr                         integer
---@param panel_type                    "sbs_left"|"sbs_right"
function M.apply_sbs_winopts(winnr, panel_type)
  if not vim.api.nvim_win_is_valid(winnr) then
    return
  end

  -- Apply non-blocking options immediately
  vim.api.nvim_set_option_value("winhighlight", gen_winhl(panel_type), { win = winnr, scope = "local" })
  vim.api.nvim_set_option_value("foldcolumn", WINOPTS_SBS.foldcolumn, { win = winnr, scope = "local" })
end

---Apply diff-related window options (deferred to avoid blocking UI)
---@param winnr                         integer
function M.apply_sbs_diff_winopts(winnr)
  if not vim.api.nvim_win_is_valid(winnr) then
    return
  end

  ---@diagnostic disable-next-line: spell-check
  vim.api.nvim_set_option_value("cursorbind", WINOPTS_SBS.cursorbind, { win = winnr, scope = "local" })
  vim.api.nvim_set_option_value("scrollbind", WINOPTS_SBS.scrollbind, { win = winnr, scope = "local" })
  vim.api.nvim_set_option_value("foldenable", WINOPTS_SBS.foldenable, { win = winnr, scope = "local" })
  vim.api.nvim_set_option_value("foldmethod", WINOPTS_SBS.foldmethod, { win = winnr, scope = "local" })
  vim.api.nvim_set_option_value("diff", WINOPTS_SBS.diff, { win = winnr, scope = "local" })
  apply_foldlevel(winnr, true)
end

---@param winnr                         integer|nil
function M.apply_fold_unchanged(winnr)
  if not winnr then
    return
  end
  apply_foldlevel(winnr)
end

---@param left_winnr                    integer|nil
---@param right_winnr                   integer|nil
function M.apply_fold_unchanged_pair(left_winnr, right_winnr)
  if left_winnr then
    apply_foldlevel(left_winnr)
  end
  if right_winnr then
    apply_foldlevel(right_winnr)
  end
end

----------------------------------------------------------------------------------------------------
-- Side-by-side view opening
----------------------------------------------------------------------------------------------------

---@class era.m.diffview.pane.sbs.IOpenDiffOpts
---@field public left_winnr             integer
---@field public right_winnr            integer
---@field public entry                  era.m.diffview.IFileEntry
---@field public token                  ?stl.c.CancellationToken

---Open file entry in side-by-side view (for Git Diff staged/unstaged).
---@async
---@param opts                          era.m.diffview.pane.sbs.IOpenDiffOpts
function M.open_diff_entry(opts)
  local left_winnr = opts.left_winnr
  local right_winnr = opts.right_winnr
  local entry = opts.entry
  local token = opts.token

  local status = entry.status
  local filepath = entry.filepath
  local stage_type = entry.stage_type
  local workspace = dot.path.workspace()

  -- Determine what to show on left/right based on stage type and status
  local left_bufnr = nil ---@type integer|nil
  local right_bufnr = nil ---@type integer|nil

  -- Handle different cases
  if status == "D" then
    -- Deleted file: show old content on left, null on right
    if stage_type == "staged" then
      -- Staged delete: HEAD -> (deleted)
      local left_name = era.m.diffview.util.gen_old_bufname(filepath, "HEAD")
      left_bufnr = M.create_sbs_buffer(left_name)
      right_bufnr = M.get_null_buffer()

      M.load_git_content(era.m.diffview.util.head_object(filepath), left_bufnr, token)
      M.__apply_buffers__(left_winnr, right_winnr, left_bufnr, right_bufnr)
    else
      -- Unstaged delete: index -> (deleted)
      local left_name = era.m.diffview.util.gen_old_bufname(filepath, "index")
      left_bufnr = M.create_sbs_buffer(left_name)
      right_bufnr = M.get_null_buffer()

      M.load_git_content(era.m.diffview.util.staged_object(filepath), left_bufnr, token)
      M.__apply_buffers__(left_winnr, right_winnr, left_bufnr, right_bufnr)
    end
  elseif status == "A" or status == "?" then
    -- Added file: show null on left, new content on right
    left_bufnr = M.get_null_buffer()

    if stage_type == "staged" then
      -- Staged add: (new) -> index
      local right_name = era.m.diffview.util.gen_index_bufname(filepath)
      right_bufnr = M.create_sbs_buffer(right_name)

      M.load_git_content(era.m.diffview.util.staged_object(filepath), right_bufnr, token)
      M.__apply_buffers__(left_winnr, right_winnr, left_bufnr, right_bufnr)
    else
      -- Unstaged add: (new) -> working tree
      local absolute_path = dot.path.join(workspace, filepath)
      right_bufnr = M.find_or_create_local_buffer(absolute_path)

      -- Save window options for local buffer
      if vim.api.nvim_win_is_valid(right_winnr) then
        M.save_winopts(right_bufnr, right_winnr)
      end

      M.__apply_buffers__(left_winnr, right_winnr, left_bufnr, right_bufnr)
    end
  else
    -- Modified file: show old on left, new on right
    if stage_type == "staged" then
      -- Staged modify: HEAD -> index
      local left_name = era.m.diffview.util.gen_old_bufname(filepath, "HEAD")
      local right_name = era.m.diffview.util.gen_index_bufname(filepath)
      left_bufnr = M.create_sbs_buffer(left_name)
      right_bufnr = M.create_sbs_buffer(right_name)

      M.load_git_content(era.m.diffview.util.head_object(filepath), left_bufnr, token)
      M.load_git_content(era.m.diffview.util.staged_object(filepath), right_bufnr, token)

      M.__apply_buffers__(left_winnr, right_winnr, left_bufnr, right_bufnr)
    else
      -- Unstaged modify: index -> working tree
      local left_name = era.m.diffview.util.gen_old_bufname(filepath, "index")
      left_bufnr = M.create_sbs_buffer(left_name)

      local absolute_path = dot.path.join(workspace, filepath)
      right_bufnr = M.find_or_create_local_buffer(absolute_path)

      -- Save window options for local buffer
      if vim.api.nvim_win_is_valid(right_winnr) then
        M.save_winopts(right_bufnr, right_winnr)
      end

      M.load_git_content(era.m.diffview.util.staged_object(filepath), left_bufnr, token)
      M.__apply_buffers__(left_winnr, right_winnr, left_bufnr, right_bufnr)
    end
  end
end

---@class era.m.diffview.pane.sbs.IOpenCommitOpts
---@field public left_winnr             integer
---@field public right_winnr            integer
---@field public entry                  era.m.diffview.IFileEntry
---@field public commit                 era.m.diffview.ICommit
---@field public token                  ?stl.c.CancellationToken

---Open commit file entry in side-by-side view (for File History / Git Log).
---@async
---@param opts                          era.m.diffview.pane.sbs.IOpenCommitOpts
function M.open_commit_entry(opts)
  local left_winnr = opts.left_winnr
  local right_winnr = opts.right_winnr
  local entry = opts.entry
  local commit = opts.commit
  local token = opts.token

  local filepath = entry.filepath
  local parent_filepath = commit.parent_filepath or entry.prev_filepath or filepath
  local status = entry.status
  local hash = commit.hash

  -- Get parent hash (first parent)
  local parent_hash = hash .. "^"

  local left_bufnr = nil ---@type integer|nil
  local right_bufnr = nil ---@type integer|nil

  if status == "D" then
    -- Deleted in this commit
    local left_name = era.m.diffview.util.gen_old_bufname(parent_filepath, parent_hash)
    left_bufnr = M.create_sbs_buffer(left_name)
    right_bufnr = M.get_null_buffer()

    M.load_git_content(era.m.diffview.util.commit_object(parent_hash, parent_filepath), left_bufnr, token)
    M.__apply_buffers__(left_winnr, right_winnr, left_bufnr, right_bufnr)
  elseif status == "A" then
    -- Added in this commit
    left_bufnr = M.get_null_buffer()
    local right_name = era.m.diffview.util.gen_old_bufname(filepath, hash)
    right_bufnr = M.create_sbs_buffer(right_name)

    M.load_git_content(era.m.diffview.util.commit_object(hash, filepath), right_bufnr, token)
    M.__apply_buffers__(left_winnr, right_winnr, left_bufnr, right_bufnr)
  else
    -- Modified
    local left_name = era.m.diffview.util.gen_old_bufname(parent_filepath, parent_hash)
    local right_name = era.m.diffview.util.gen_old_bufname(filepath, hash)
    left_bufnr = M.create_sbs_buffer(left_name)
    right_bufnr = M.create_sbs_buffer(right_name)

    M.load_git_content(era.m.diffview.util.commit_object(parent_hash, parent_filepath), left_bufnr, token)
    M.load_git_content(era.m.diffview.util.commit_object(hash, filepath), right_bufnr, token)

    M.__apply_buffers__(left_winnr, right_winnr, left_bufnr, right_bufnr)
  end
end

---Clear side-by-side view (show null buffers on both sides)
---@param left_winnr                    integer
---@param right_winnr                   integer
function M.clear(left_winnr, right_winnr)
  local null_buf = M.get_null_buffer()
  M.__apply_buffers__(left_winnr, right_winnr, null_buf, null_buf)
end

----------------------------------------------------------------------------------------------------

---Apply buffers to side-by-side windows
---@param left_winnr                    integer
---@param right_winnr                   integer
---@param left_bufnr                    integer
---@param right_bufnr                   integer
function M.__apply_buffers__(left_winnr, right_winnr, left_bufnr, right_bufnr)
  -- Step 1: Turn off diff mode before changing buffers to avoid Neovim recalculating diffs
  if vim.api.nvim_win_is_valid(left_winnr) then
    vim.api.nvim_set_option_value("diff", false, { win = left_winnr, scope = "local" })
  end
  if vim.api.nvim_win_is_valid(right_winnr) then
    vim.api.nvim_set_option_value("diff", false, { win = right_winnr, scope = "local" })
  end

  -- Step 2: Set buffers and apply non-blocking options
  if vim.api.nvim_win_is_valid(left_winnr) then
    vim.api.nvim_win_set_buf(left_winnr, left_bufnr)
    M.apply_sbs_winopts(left_winnr, "sbs_left")
  end

  if vim.api.nvim_win_is_valid(right_winnr) then
    vim.api.nvim_win_set_buf(right_winnr, right_bufnr)
    M.apply_sbs_winopts(right_winnr, "sbs_right")
  end

  -- Step 3: Defer expensive operations (diff calculation, filetype detection)
  vim.schedule(function()
    -- Apply diff-related options (triggers diff calculation)
    if vim.api.nvim_win_is_valid(left_winnr) then
      M.apply_sbs_diff_winopts(left_winnr)
    end
    if vim.api.nvim_win_is_valid(right_winnr) then
      M.apply_sbs_diff_winopts(right_winnr)
    end

    -- Detect filetype for syntax highlighting
    if vim.api.nvim_buf_is_valid(left_bufnr) then
      vim.api.nvim_buf_call(left_bufnr, function()
        vim.cmd("filetype detect")
      end)
    end
    if vim.api.nvim_buf_is_valid(right_bufnr) then
      vim.api.nvim_buf_call(right_bufnr, function()
        vim.cmd("filetype detect")
      end)
    end
  end)
end

return M

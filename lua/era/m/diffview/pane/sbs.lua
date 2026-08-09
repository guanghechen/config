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
local util = require("era.m.diffview.util")

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
      pcall(function()
        vim.cmd("silent! normal! zM")
      end)
      return
    end
    pcall(function()
      vim.cmd("silent! normal! zR")
    end)
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
  local existing = stl.nvim.buf.locate_bufnr("diffview://null") ---@type integer|nil
  if existing ~= nil and vim.api.nvim_buf_is_valid(existing) then
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
  local existing = stl.nvim.buf.locate_bufnr(name) ---@type integer|nil
  if existing ~= nil then
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
  local bufnr = stl.nvim.buf.locate_bufnr(filepath) ---@type integer|nil
  if bufnr ~= nil then
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

---@param token                         stl.c.CancellationToken|nil
---@param is_current                    (fun(): boolean)|nil
---@return boolean
local function is_request_current(token, is_current)
  return (not token or not token:is_cancelled()) and (not is_current or is_current())
end

---@param object                        string
---@return string
---@return string
local function get_document_format(object)
  local relpath = object:match("^:%d:(.*)$") or object:match("^[^:]*:(.*)$") ---@type string|nil
  if not relpath or relpath == "" then
    return "utf-8", "\n"
  end

  local filepath = util.workspace_path(relpath) ---@type string
  local local_bufnr = stl.nvim.buf.locate_bufnr(filepath) ---@type integer|nil
  if vim.fn.filereadable(filepath) == 1 then
    local_bufnr = local_bufnr or vim.fn.bufadd(filepath)
    if not vim.api.nvim_buf_is_loaded(local_bufnr) then
      vim.fn.bufload(local_bufnr)
    end
  end
  if not local_bufnr or not vim.api.nvim_buf_is_loaded(local_bufnr) then
    return "utf-8", "\n"
  end

  local encoding = vim.api.nvim_get_option_value("fileencoding", { buf = local_bufnr }) ---@type string
  local fileformat = vim.api.nvim_get_option_value("fileformat", { buf = local_bufnr }) ---@type string
  return era.m.git.staging.normalize_encoding(encoding), era.m.git.staging.eol_from_fileformat(fileformat)
end

---Load content from git object into buffer.
---@async
---@param object                        string                          git object (e.g., "HEAD:path" or ":./path")
---@param bufnr                         integer                         target buffer
---@param token                         ?stl.c.CancellationToken
---@param is_current                    (fun(): boolean)|nil
---@param before_write                  (fun(): nil)|nil
---@param resolved_object_name          string|nil                      object captured by the status snapshot
---@return boolean ok
---@return boolean content_changed
function M.load_git_content(object, bufnr, token, is_current, before_write, resolved_object_name)
  if not is_request_current(token, is_current) then
    return false, false
  end

  -- Keep the index snapshot separate: partial unstage consumes it, while every resolved Git object
  -- may own the content cache identity.
  local index_object_name = nil ---@type string|nil
  local content_object_name = nil ---@type string|nil
  local blob_object = object ---@type string
  local object_missing = false ---@type boolean
  local source_encoding = nil ---@type string|nil
  local source_default_eol = nil ---@type string|nil
  local index_stage_path = object:match("^:%d:(.*)$") ---@type string|nil
  local index_path = not index_stage_path and object:match("^:(.*)$") or nil ---@type string|nil
  if index_path then
    if resolved_object_name then
      index_object_name = resolved_object_name
    else
      local info_result = stl.git.info.get_file_info(dot.path.workspace(), index_path, token):await()
      if not is_request_current(token, is_current) then
        return false, false
      end
      if
        type(info_result) ~= "table"
        or not info_result.ok
        or not info_result.info
        or info_result.info.has_conflicts
        or not info_result.info.object_name
      then
        if not token or not token:is_cancelled() then
          stl.reporter.error({
            from = __module_name__,
            subject = "load_git_content",
            message = (type(info_result) == "table" and info_result.err) or "Unable to inspect index object",
          })
        end
        return false, false
      end
      index_object_name = info_result.info.object_name
    end
    content_object_name = index_object_name
    blob_object = content_object_name
  elseif object:match("^[^:]+:") then
    if resolved_object_name then
      content_object_name = resolved_object_name
      blob_object = content_object_name
    else
      local name_result = stl.git.info.get_object_name(dot.path.workspace(), object, token):await()
      if not is_request_current(token, is_current) then
        return false, false
      end
      if type(name_result) ~= "table" or not name_result.ok or not name_result.object_name then
        if type(name_result) == "table" and name_result.missing then
          object_missing = true
        else
          if not token or not token:is_cancelled() then
            stl.reporter.error({
              from = __module_name__,
              subject = "load_git_content",
              message = (type(name_result) == "table" and name_result.err) or "Unable to resolve Git object",
            })
          end
          return false, false
        end
      else
        content_object_name = name_result.object_name
        blob_object = content_object_name
      end
    end
  end

  if content_object_name then
    stl.async.scheduler()

    if not is_request_current(token, is_current) or not vim.api.nvim_buf_is_valid(bufnr) then
      return false, false
    end

    source_encoding, source_default_eol = get_document_format(object)
    if not is_request_current(token, is_current) or not vim.api.nvim_buf_is_valid(bufnr) then
      return false, false
    end
    if
      vim.b[bufnr].git_content_object_name == content_object_name
      and vim.b[bufnr].git_source_encoding == source_encoding
      and vim.b[bufnr].git_source_default_eol == source_default_eol
    then
      vim.b[bufnr].git_object_name = index_object_name
      return true, false
    end
  end

  local bytes = object_missing and "" or nil ---@type string|nil
  if not object_missing then
    local result = stl.git.info.get_show_blob(dot.path.workspace(), blob_object, token):await()
    if not is_request_current(token, is_current) then
      return false, false
    end

    if type(result) ~= "table" then
      stl.reporter.error({
        from = __module_name__,
        subject = "load_git_content",
        message = "Invalid blob result for object: " .. object,
      })
      return false, false
    end

    bytes = result.bytes
    if not result.ok then
      if result.missing then
        bytes = ""
      else
        if not token or not token:is_cancelled() then
          stl.reporter.error({
            from = __module_name__,
            subject = "load_git_content",
            message = result.err or ("Unable to read object: " .. object),
          })
        end
        return false, false
      end
    end
  end
  if type(bytes) ~= "string" then
    stl.reporter.error({
      from = __module_name__,
      subject = "load_git_content",
      message = "Blob result has no bytes: " .. object,
    })
    return false, false
  end

  stl.async.scheduler()

  if not is_request_current(token, is_current) or not vim.api.nvim_buf_is_valid(bufnr) then
    return false, false
  end

  local encoding, default_eol = get_document_format(object) ---@type string, string
  if not is_request_current(token, is_current) or not vim.api.nvim_buf_is_valid(bufnr) then
    return false, false
  end
  local document, decode_err = era.m.git.staging.from_blob(bytes, encoding, default_eol)
  if not document then
    stl.reporter.error({
      from = __module_name__,
      subject = "load_git_content",
      message = decode_err or ("Unable to decode object: " .. object),
    })
    return false, false
  end

  if before_write then
    before_write()
  end
  if not is_request_current(token, is_current) or not vim.api.nvim_buf_is_valid(bufnr) then
    return false, false
  end

  vim.b[bufnr].git_object_name = nil
  vim.b[bufnr].git_content_object_name = nil
  vim.b[bufnr].git_source_encoding = nil
  vim.b[bufnr].git_source_default_eol = nil

  local write_ok, write_err = pcall(function()
    vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr })
    vim.api.nvim_set_option_value("fileformat", document.eol == "\r\n" and "dos" or "unix", { buf = bufnr })
    vim.api.nvim_set_option_value("fileencoding", document.encoding, { buf = bufnr })
    vim.api.nvim_set_option_value("bomb", document.bomb, { buf = bufnr })
    era.m.git.staging.replace_buffer_text(bufnr, document.text)
    vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr })
    vim.api.nvim_set_option_value("modified", false, { buf = bufnr })
  end)
  if not write_ok then
    if vim.api.nvim_buf_is_valid(bufnr) then
      pcall(vim.api.nvim_set_option_value, "modifiable", false, { buf = bufnr })
    end
    error(write_err, 0)
  end

  vim.b[bufnr].git_object_name = index_object_name
  vim.b[bufnr].git_content_object_name = content_object_name
  vim.b[bufnr].git_source_encoding = content_object_name and encoding or nil
  vim.b[bufnr].git_source_default_eol = content_object_name and default_eol or nil

  return true, true
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
---@field public is_current             (fun(): boolean)|nil
---@field public preserve_view           boolean|nil

---Open file entry in side-by-side view (for Git Diff staged/unstaged).
---@async
---@param opts                          era.m.diffview.pane.sbs.IOpenDiffOpts
function M.open_diff_entry(opts)
  local left_winnr = opts.left_winnr
  local right_winnr = opts.right_winnr
  local entry = opts.entry
  local token = opts.token
  local is_current = opts.is_current

  if not is_request_current(token, is_current) then
    return
  end

  local apply_opts = {
    is_current = is_current,
    preserve_view = opts.preserve_view,
    refresh_diff = entry.stage_type ~= "staged",
  } ---@type era.m.diffview.pane.sbs.IApplyBuffersOpts

  local function capture_views()
    if apply_opts.preserve_view ~= true or apply_opts.left_view or apply_opts.right_view then
      return
    end
    if vim.api.nvim_win_is_valid(left_winnr) then
      apply_opts.left_view = vim.api.nvim_win_call(left_winnr, vim.fn.winsaveview)
    end
    if vim.api.nvim_win_is_valid(right_winnr) then
      apply_opts.right_view = vim.api.nvim_win_call(right_winnr, vim.fn.winsaveview)
    end
  end

  ---@param object                      string
  ---@param bufnr                       integer
  ---@param resolved_object_name        string|nil
  ---@return boolean current
  local function load_content(object, bufnr, resolved_object_name)
    local loaded, content_changed =
      M.load_git_content(object, bufnr, token, is_current, capture_views, resolved_object_name)
    if content_changed then
      apply_opts.refresh_diff = true
    end
    return loaded and is_request_current(token, is_current)
  end

  ---Load an immutable pair concurrently, then publish only after both sides settle successfully.
  ---@param left_object                 string
  ---@param left_bufnr                  integer
  ---@param left_object_name            string|nil
  ---@param right_object                string
  ---@param right_bufnr                 integer
  ---@param right_object_name           string|nil
  ---@return boolean current
  local function load_content_pair(
    left_object,
    left_bufnr,
    left_object_name,
    right_object,
    right_bufnr,
    right_object_name
  )
    ---@param object                    string
    ---@param bufnr                     integer
    ---@param object_name               string|nil
    ---@return stl.c.Future
    local function start_load(object, bufnr, object_name)
      return stl.c.Future.new(function(resolve)
        stl.async.run(function()
          local ok, result = xpcall(function()
            local loaded, content_changed =
              M.load_git_content(object, bufnr, token, is_current, capture_views, object_name)
            return { loaded = loaded, content_changed = content_changed }
          end, debug.traceback)
          if ok then
            resolve(result)
          else
            resolve({ loaded = false, content_changed = false, err = result })
          end
        end)
      end)
    end

    local results = stl.c.Future
      .all({
        start_load(left_object, left_bufnr, left_object_name),
        start_load(right_object, right_bufnr, right_object_name),
      })
      :await()
    local left = results[1] ---@type { loaded: boolean, content_changed: boolean, err: string|nil }
    local right = results[2] ---@type { loaded: boolean, content_changed: boolean, err: string|nil }
    if left.err then
      error(left.err, 0)
    end
    if right.err then
      error(right.err, 0)
    end
    if left.content_changed or right.content_changed then
      apply_opts.refresh_diff = true
    end
    return left.loaded and right.loaded and is_request_current(token, is_current)
  end

  ---@param left_bufnr                  integer
  ---@param right_bufnr                 integer
  local function apply_buffers(left_bufnr, right_bufnr)
    if apply_opts.refresh_diff ~= false then
      capture_views()
    end
    M.__apply_buffers__(left_winnr, right_winnr, left_bufnr, right_bufnr, apply_opts)
  end

  local status = entry.status
  local filepath = entry.filepath
  local stage_type = entry.stage_type

  -- Determine what to show on left/right based on stage type and status
  local left_bufnr = nil ---@type integer|nil
  local right_bufnr = nil ---@type integer|nil

  -- Handle different cases
  if status == "U" then
    -- Conflict preview contract: compare stage 2 (ours) with the editable working tree.
    local left_name = era.m.diffview.util.gen_old_bufname(filepath, "ours")
    left_bufnr = M.create_sbs_buffer(left_name)

    local absolute_path = util.workspace_path(filepath)
    if vim.fn.filereadable(absolute_path) == 1 then
      right_bufnr = M.find_or_create_local_buffer(absolute_path)
      if vim.api.nvim_win_is_valid(right_winnr) then
        M.save_winopts(right_bufnr, right_winnr)
      end
    else
      right_bufnr = M.get_null_buffer()
    end

    if not load_content(era.m.diffview.util.index_stage_object(filepath, 2), left_bufnr) then
      return
    end
    apply_buffers(left_bufnr, right_bufnr)
  elseif status == "D" then
    -- Deleted file: show old content on left, null on right
    if stage_type == "staged" then
      -- Staged delete: HEAD -> (deleted)
      local left_name = era.m.diffview.util.gen_old_bufname(filepath, "HEAD")
      left_bufnr = M.create_sbs_buffer(left_name)
      right_bufnr = M.get_null_buffer()

      if not load_content(era.m.diffview.util.head_object(filepath), left_bufnr, entry.old_object_name) then
        return
      end
      apply_buffers(left_bufnr, right_bufnr)
    else
      -- Unstaged delete: index -> (deleted)
      local left_name = era.m.diffview.util.gen_old_bufname(filepath, "index")
      left_bufnr = M.create_sbs_buffer(left_name)
      right_bufnr = M.get_null_buffer()

      if not load_content(era.m.diffview.util.staged_object(filepath), left_bufnr, entry.old_object_name) then
        return
      end
      apply_buffers(left_bufnr, right_bufnr)
    end
  elseif status == "A" or status == "?" then
    -- Added file: show null on left, new content on right
    left_bufnr = M.get_null_buffer()

    if stage_type == "staged" then
      -- Staged add: (new) -> index
      local right_name = era.m.diffview.util.gen_index_bufname(filepath)
      right_bufnr = M.create_sbs_buffer(right_name)

      if not load_content(era.m.diffview.util.staged_object(filepath), right_bufnr, entry.new_object_name) then
        return
      end
      apply_buffers(left_bufnr, right_bufnr)
    else
      -- Unstaged add: (new) -> working tree
      local absolute_path = util.workspace_path(filepath)
      right_bufnr = M.find_or_create_local_buffer(absolute_path)

      -- Save window options for local buffer
      if vim.api.nvim_win_is_valid(right_winnr) then
        M.save_winopts(right_bufnr, right_winnr)
      end

      apply_buffers(left_bufnr, right_bufnr)
    end
  elseif status == "R" or status == "C" then
    local previous = entry.prev_filepath or filepath
    local left_name = era.m.diffview.util.gen_old_bufname(previous, stage_type == "staged" and "HEAD" or "index")
    left_bufnr = M.create_sbs_buffer(left_name)

    if stage_type == "staged" then
      local right_name = era.m.diffview.util.gen_index_bufname(filepath)
      right_bufnr = M.create_sbs_buffer(right_name)
      if
        not load_content_pair(
          era.m.diffview.util.head_object(previous),
          left_bufnr,
          entry.old_object_name,
          era.m.diffview.util.staged_object(filepath),
          right_bufnr,
          entry.new_object_name
        )
      then
        return
      end
    else
      right_bufnr = M.find_or_create_local_buffer(util.workspace_path(filepath))
      if vim.api.nvim_win_is_valid(right_winnr) then
        M.save_winopts(right_bufnr, right_winnr)
      end
      if not load_content(era.m.diffview.util.staged_object(previous), left_bufnr, entry.old_object_name) then
        return
      end
    end
    apply_buffers(left_bufnr, right_bufnr)
  else
    -- Modified file: show old on left, new on right
    if stage_type == "staged" then
      -- Staged modify: HEAD -> index
      local left_name = era.m.diffview.util.gen_old_bufname(filepath, "HEAD")
      local right_name = era.m.diffview.util.gen_index_bufname(filepath)
      left_bufnr = M.create_sbs_buffer(left_name)
      right_bufnr = M.create_sbs_buffer(right_name)

      if
        not load_content_pair(
          era.m.diffview.util.head_object(filepath),
          left_bufnr,
          entry.old_object_name,
          era.m.diffview.util.staged_object(filepath),
          right_bufnr,
          entry.new_object_name
        )
      then
        return
      end

      apply_buffers(left_bufnr, right_bufnr)
    else
      -- Unstaged modify: index -> working tree
      local left_name = era.m.diffview.util.gen_old_bufname(filepath, "index")
      left_bufnr = M.create_sbs_buffer(left_name)

      local absolute_path = util.workspace_path(filepath)
      right_bufnr = M.find_or_create_local_buffer(absolute_path)

      -- Save window options for local buffer
      if vim.api.nvim_win_is_valid(right_winnr) then
        M.save_winopts(right_bufnr, right_winnr)
      end

      if not load_content(era.m.diffview.util.staged_object(filepath), left_bufnr, entry.old_object_name) then
        return
      end
      apply_buffers(left_bufnr, right_bufnr)
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
---@param is_current                    (fun(): boolean)|nil
function M.clear(left_winnr, right_winnr, is_current)
  local null_buf = M.get_null_buffer()
  M.__apply_buffers__(left_winnr, right_winnr, null_buf, null_buf, { is_current = is_current })
end

----------------------------------------------------------------------------------------------------

---@class era.m.diffview.pane.sbs.IApplyBuffersOpts
---@field public is_current             (fun(): boolean)|nil
---@field public preserve_view           boolean|nil
---@field public left_view              vim.fn.winsaveview.ret|nil
---@field public right_view             vim.fn.winsaveview.ret|nil
---@field public refresh_diff           boolean|nil

---Apply buffers to side-by-side windows
---@param left_winnr                    integer
---@param right_winnr                   integer
---@param left_bufnr                    integer
---@param right_bufnr                   integer
---@param opts                           era.m.diffview.pane.sbs.IApplyBuffersOpts|nil
function M.__apply_buffers__(left_winnr, right_winnr, left_bufnr, right_bufnr, opts)
  local is_current = opts and opts.is_current
  if not is_request_current(nil, is_current) then
    return
  end

  local preserve_view = opts
    and opts.preserve_view == true
    and vim.api.nvim_win_is_valid(left_winnr)
    and vim.api.nvim_win_get_buf(left_winnr) == left_bufnr
    and vim.api.nvim_win_is_valid(right_winnr)
    and vim.api.nvim_win_get_buf(right_winnr) == right_bufnr

  if opts and preserve_view and opts.refresh_diff == false then
    return
  end

  if not preserve_view then
    -- Turn off diff mode before changing buffers to avoid Neovim recalculating diffs.
    if vim.api.nvim_win_is_valid(left_winnr) then
      vim.api.nvim_set_option_value("diff", false, { win = left_winnr, scope = "local" })
    end
    if vim.api.nvim_win_is_valid(right_winnr) then
      vim.api.nvim_set_option_value("diff", false, { win = right_winnr, scope = "local" })
    end

    if vim.api.nvim_win_is_valid(left_winnr) then
      vim.api.nvim_win_set_buf(left_winnr, left_bufnr)
      M.apply_sbs_winopts(left_winnr, "sbs_left")
    end
    if vim.api.nvim_win_is_valid(right_winnr) then
      vim.api.nvim_win_set_buf(right_winnr, right_bufnr)
      M.apply_sbs_winopts(right_winnr, "sbs_right")
    end
  end

  vim.schedule(function()
    if not is_request_current(nil, is_current) then
      return
    end

    if
      not vim.api.nvim_win_is_valid(left_winnr)
      or vim.api.nvim_win_get_buf(left_winnr) ~= left_bufnr
      or not vim.api.nvim_win_is_valid(right_winnr)
      or vim.api.nvim_win_get_buf(right_winnr) ~= right_bufnr
    then
      return
    end

    if preserve_view then
      vim.api.nvim_win_call(left_winnr, function()
        vim.cmd("silent! diffupdate")
      end)
      if opts and opts.left_view then
        vim.api.nvim_win_call(left_winnr, function()
          vim.fn.winrestview(opts.left_view)
        end)
      end
      if opts and opts.right_view then
        vim.api.nvim_win_call(right_winnr, function()
          vim.fn.winrestview(opts.right_view)
        end)
      end
      return
    end

    -- Apply diff-related options (triggers diff calculation)
    M.apply_sbs_diff_winopts(left_winnr)
    M.apply_sbs_diff_winopts(right_winnr)

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

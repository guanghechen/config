local NS_INLINE = "dot_module_git_inline_blame"
local NS_BUFFER = "dot_module_git_buffer_blame"

---@class dot.module.git.blame
local M = {}

---@type table<integer, table<integer, dot.module.git.BlameInfo>>
local cache = {}

---@type table<integer, ark.c.Proc|nil>
local running_procs = {}

---@type table<integer, ark.c.Proc|nil>
local running_buffer_procs = {}

---@param output                     string
---@return table<integer, dot.module.git.BlameInfo>
local function parse_blame_output(output)
  local result = {} ---@type table<integer, dot.module.git.BlameInfo>
  local lines = vim.split(output, "\n", { plain = true })

  local current_sha = nil ---@type string|nil
  local current_info = nil ---@type dot.module.git.BlameInfo|nil
  local commits = {} ---@type table<string, dot.module.git.BlameInfo>

  for _, line in ipairs(lines) do
    if line == "" then
      goto continue
    end

    local sha, orig_lnum, final_lnum, num_lines = line:match("^(%x+)%s+(%d+)%s+(%d+)%s*(%d*)$")
    if sha then
      current_sha = sha
      local existing = commits[sha]
      if existing then
        current_info = vim.tbl_extend("force", {}, existing)
      else
        current_info = {
          sha = sha,
          abbrev_sha = sha:sub(1, 8),
          author = "",
          author_mail = "",
          author_time = 0,
          author_tz = "",
          committer = "",
          committer_mail = "",
          committer_time = 0,
          committer_tz = "",
          summary = "",
          previous = nil,
          previous_filename = nil,
          filename = "",
          orig_lnum = tonumber(orig_lnum) or 0,
          final_lnum = tonumber(final_lnum) or 0,
          num_lines = tonumber(num_lines) or 1,
        }
      end
      current_info.orig_lnum = tonumber(orig_lnum) or 0
      current_info.final_lnum = tonumber(final_lnum) or 0
      current_info.num_lines = tonumber(num_lines) or 1
      goto continue
    end

    if current_info then
      if line:sub(1, 1) == "\t" then
        if current_sha and current_info then
          if not commits[current_sha] then
            commits[current_sha] = current_info
          end
          result[current_info.final_lnum] = current_info
        end
        current_info = nil
        goto continue
      end

      local key, value = line:match("^([%w-]+)%s+(.*)$")
      if key then
        if key == "author" then
          current_info.author = value
        elseif key == "author-mail" then
          current_info.author_mail = value:gsub("^<", ""):gsub(">$", "")
        elseif key == "author-time" then
          current_info.author_time = tonumber(value) or 0
        elseif key == "author-tz" then
          current_info.author_tz = value
        elseif key == "committer" then
          current_info.committer = value
        elseif key == "committer-mail" then
          current_info.committer_mail = value:gsub("^<", ""):gsub(">$", "")
        elseif key == "committer-time" then
          current_info.committer_time = tonumber(value) or 0
        elseif key == "committer-tz" then
          current_info.committer_tz = value
        elseif key == "summary" then
          current_info.summary = value
        elseif key == "previous" then
          local prev_sha, prev_file = value:match("^(%x+)%s+(.*)$")
          if prev_sha then
            current_info.previous = prev_sha
            current_info.previous_filename = prev_file
          end
        elseif key == "filename" then
          current_info.filename = value
        end
      end
    end

    ::continue::
  end

  return result
end

---@param bufnr                      integer
---@param file                       string
---@param cwd                        string
---@param lnum                       integer|nil
---@param callback                   fun(blame: table<integer, dot.module.git.BlameInfo>|nil)
function M.run_blame(bufnr, file, cwd, lnum, callback)
  if running_procs[bufnr] then
    running_procs[bufnr]:kill()
    running_procs[bufnr] = nil
  end

  local args = { "-C", cwd, "blame", "--porcelain" }

  if lnum then
    vim.list_extend(args, { "-L", string.format("%d,%d", lnum, lnum) })
  end

  args[#args + 1] = "--"
  args[#args + 1] = file

  local proc = ark.c.Proc.new({
    cmd = "git",
    args = args,
    timeout = 30000,
    on_exit = function(p, err)
      running_procs[bufnr] = nil
      if err then
        callback(nil)
        return
      end
      local output = p:out()
      local result = parse_blame_output(output)
      callback(result)
    end,
  })

  running_procs[bufnr] = proc
end

---@param bufnr                      integer
---@return table<integer, dot.module.git.BlameInfo>|nil
function M.get_cache(bufnr)
  return cache[bufnr]
end

---@param bufnr                      integer
---@param blame                      table<integer, dot.module.git.BlameInfo>
function M.set_cache(bufnr, blame)
  cache[bufnr] = blame
end

---@param bufnr                      integer
function M.clear_cache(bufnr)
  cache[bufnr] = nil
end

---@param bufnr                      integer
---@param lnum                       integer
---@return dot.module.git.BlameInfo|nil
function M.get_blame_at(bufnr, lnum)
  local buf_cache = cache[bufnr]
  if not buf_cache then
    return nil
  end
  return buf_cache[lnum]
end

---@param info                       dot.module.git.BlameInfo|nil
---@return string
function M.format_blame(info)
  if not info then
    return ""
  end

  if info.sha:match("^0+$") then
    return "Not committed yet"
  end

  local author = info.author
  if author == "Not Committed Yet" then
    return "Not committed yet"
  end

  local time = info.author_time
  local time_str = ""
  if time > 0 then
    local diff = os.time() - time
    if diff < 60 then
      time_str = "just now"
    elseif diff < 3600 then
      time_str = string.format("%d minutes ago", math.floor(diff / 60))
    elseif diff < 86400 then
      time_str = string.format("%d hours ago", math.floor(diff / 3600))
    elseif diff < 604800 then
      time_str = string.format("%d days ago", math.floor(diff / 86400))
    elseif diff < 2592000 then
      time_str = string.format("%d weeks ago", math.floor(diff / 604800))
    elseif diff < 31536000 then
      time_str = string.format("%d months ago", math.floor(diff / 2592000))
    else
      time_str = string.format("%d years ago", math.floor(diff / 31536000))
    end
  end

  local summary = info.summary
  if #summary > 50 then
    summary = summary:sub(1, 47) .. "..."
  end

  return string.format("%s, %s - %s", author, time_str, summary)
end

---@param bufnr                      integer
function M.cancel(bufnr)
  if running_procs[bufnr] then
    running_procs[bufnr]:kill()
    running_procs[bufnr] = nil
  end
end

----------------------------------------------------------------------------------------------------

---@class dot.module.git.blame.IInlineConfig
---@field public delay               integer
---@field public enabled             boolean
---@field public formatter           string
---@field public hl_group            string
---@field public prefix              string
---@field public priority            integer
local inline_config = {
  delay = 2000,
  enabled = true,
  formatter = "<author>, <author_time:%Y-%m-%d %H:%M:%S> - <summary>",
  hl_group = "fg_inline_blame",
  prefix = "    ",
  priority = 200,
}

---@type integer
local inline_ns = vim.api.nvim_create_namespace(NS_INLINE)

---@type table<integer, uv.uv_timer_t>
local inline_timers = {}

---@type table<integer, boolean>
local inline_running = {}

---@param info                       dot.module.git.BlameInfo
---@param fmt                        string
---@return string
local function format_inline_blame(info, fmt)
  local result = fmt
  result = result:gsub("<author>", info.author or "")
  result = result:gsub("<author_mail>", info.author_mail or "")
  result = result:gsub("<committer>", info.committer or "")
  result = result:gsub("<committer_mail>", info.committer_mail or "")
  result = result:gsub("<summary>", info.summary or "")
  result = result:gsub("<sha>", info.sha or "")
  result = result:gsub("<abbrev_sha>", info.abbrev_sha or "")
  result = result:gsub("<author_time:([^>]+)>", function(date_fmt)
    if info.author_time and info.author_time > 0 then
      return os.date(date_fmt, info.author_time) or ""
    end
    return ""
  end)
  result = result:gsub("<committer_time:([^>]+)>", function(date_fmt)
    if info.committer_time and info.committer_time > 0 then
      return os.date(date_fmt, info.committer_time) or ""
    end
    return ""
  end)
  return result
end

---@param bufnr                      integer
local function inline_reset(bufnr)
  if vim.api.nvim_buf_is_valid(bufnr) then
    pcall(vim.api.nvim_buf_del_extmark, bufnr, inline_ns, 1)
  end
end

---@param bufnr                      integer
local function inline_cancel_timer(bufnr)
  local timer = inline_timers[bufnr]
  if timer then
    if not timer:is_closing() then
      timer:stop()
      timer:close()
    end
    inline_timers[bufnr] = nil
  end
end

---@param bufnr                      integer
---@param lnum                       integer
---@param info                       dot.module.git.BlameInfo
local function inline_set_extmark(bufnr, lnum, info)
  local text ---@type string
  if info.sha:match("^0+$") or info.author == "Not Committed Yet" then
    text = inline_config.prefix .. "Not committed yet"
  else
    text = inline_config.prefix .. format_inline_blame(info, inline_config.formatter)
  end

  pcall(vim.api.nvim_buf_set_extmark, bufnr, inline_ns, lnum - 1, 0, {
    id = 1,
    virt_text = { { text, inline_config.hl_group } },
    virt_text_pos = "eol",
    priority = inline_config.priority,
    hl_mode = "combine",
  })
end

---@param bufnr                      integer
local function inline_update(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  if vim.api.nvim_get_mode().mode == "i" then
    return
  end

  local winnr = vim.api.nvim_get_current_win()
  if bufnr ~= vim.api.nvim_win_get_buf(winnr) then
    return
  end

  local lnum = vim.api.nvim_win_get_cursor(winnr)[1]

  local foldclosed = vim.fn.foldclosed(lnum)
  if foldclosed ~= -1 then
    return
  end

  local buf_cache = dot.git.buffer.get_cache(bufnr)
  if not buf_cache then
    return
  end

  if inline_running[bufnr] then
    return
  end
  inline_running[bufnr] = true

  local file = buf_cache.file
  local cwd = buf_cache.repo.toplevel

  M.run_blame(bufnr, file, cwd, lnum, function(blame)
    vim.schedule(function()
      inline_running[bufnr] = nil

      if not vim.api.nvim_buf_is_valid(bufnr) then
        return
      end

      if not vim.api.nvim_win_is_valid(winnr) or bufnr ~= vim.api.nvim_win_get_buf(winnr) then
        return
      end

      local current_lnum = vim.api.nvim_win_get_cursor(winnr)[1]
      if current_lnum ~= lnum then
        return
      end

      if blame and blame[lnum] then
        inline_set_extmark(bufnr, lnum, blame[lnum])
      end
    end)
  end)
end

---@param bufnr                      integer
local function inline_schedule_update(bufnr)
  if not inline_config.enabled then
    return
  end

  inline_reset(bufnr)
  inline_cancel_timer(bufnr)

  local timer = vim.uv.new_timer()
  if not timer then
    return
  end

  inline_timers[bufnr] = timer
  timer:start(inline_config.delay, 0, function()
    inline_cancel_timer(bufnr)
    vim.schedule(function()
      inline_update(bufnr)
    end)
  end)
end

---@type integer
local inline_augroup = vim.api.nvim_create_augroup("DotModuleGitInlineBlame", { clear = true })

local function inline_setup_autocmds()
  vim.api.nvim_clear_autocmds({ group = inline_augroup })

  for bufnr in pairs(inline_timers) do
    inline_cancel_timer(bufnr)
    inline_reset(bufnr)
  end

  if not inline_config.enabled then
    return
  end

  vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
    group = inline_augroup,
    callback = function(args)
      local bufnr = args.buf
      if dot.git.buffer.is_attached(bufnr) then
        inline_schedule_update(bufnr)
      end
    end,
  })

  vim.api.nvim_create_autocmd({ "InsertEnter", "BufLeave" }, {
    group = inline_augroup,
    callback = function(args)
      local bufnr = args.buf
      inline_reset(bufnr)
      inline_cancel_timer(bufnr)
      M.cancel(bufnr)
    end,
  })
end

inline_setup_autocmds()

---@return boolean
function M.inline_is_enabled()
  return inline_config.enabled
end

function M.inline_enable()
  inline_config.enabled = true
  inline_setup_autocmds()
end

function M.inline_disable()
  inline_config.enabled = false
  inline_setup_autocmds()
end

function M.inline_toggle()
  inline_config.enabled = not inline_config.enabled
  inline_setup_autocmds()
end

---@param opts                       dot.module.git.blame.IInlineConfig|nil
function M.inline_configure(opts)
  if opts then
    inline_config = vim.tbl_deep_extend("force", inline_config, opts)
  end
end

---@return integer
function M.inline_get_namespace()
  return inline_ns
end

----------------------------------------------------------------------------------------------------

local buffer_ns = vim.api.nvim_create_namespace(NS_BUFFER)

---@class dot.module.git.blame.IBufferConfig
---@field public formatter           string
---@field public hl_group            string
---@field public priority            integer
local buffer_config = {
  formatter = "<author>, <author_time:%Y-%m-%d %H:%M:%S> - <summary>",
  hl_group = "fg_buffer_blame",
  priority = 100,
}

---@type table<integer, boolean>
local buffer_blame_enabled = {}

---@type table<integer, boolean>
local buffer_blame_loading = {}

---@type table<integer, integer>
local buffer_current_lnum = {}

---@param bufnr                      integer
local function buffer_clear(bufnr)
  if vim.api.nvim_buf_is_valid(bufnr) then
    pcall(vim.api.nvim_buf_clear_namespace, bufnr, buffer_ns, 0, -1)
  end
end

---@param bufnr                      integer
---@param blame                      table<integer, dot.module.git.BlameInfo>
---@param skip_lnum                  integer|nil
local function buffer_render(bufnr, blame, skip_lnum)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  buffer_clear(bufnr)

  local line_count = vim.api.nvim_buf_line_count(bufnr)
  for lnum = 1, line_count do
    if lnum == skip_lnum then
      goto continue
    end

    local info = blame[lnum]
    if info then
      local text ---@type string
      if info.sha:match("^0+$") or info.author == "Not Committed Yet" then
        text = "    Not committed yet"
      else
        text = "    " .. format_inline_blame(info, buffer_config.formatter)
      end

      pcall(vim.api.nvim_buf_set_extmark, bufnr, buffer_ns, lnum - 1, 0, {
        virt_text = { { text, buffer_config.hl_group } },
        virt_text_win_col = 80,
        priority = buffer_config.priority,
        hl_mode = "combine",
      })
    end

    ::continue::
  end
end

---@param bufnr                      integer
local function buffer_update_current_line(bufnr)
  if not buffer_blame_enabled[bufnr] then
    return
  end

  local blame = cache[bufnr]
  if not blame then
    return
  end

  local winnr = vim.fn.bufwinid(bufnr)
  if winnr == -1 then
    return
  end

  local lnum = vim.api.nvim_win_get_cursor(winnr)[1]
  if buffer_current_lnum[bufnr] == lnum then
    return
  end

  buffer_current_lnum[bufnr] = lnum
  buffer_render(bufnr, blame, lnum)
end

---@param bufnr                      integer|nil
function M.buffer_show(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  local buf_cache = dot.git.buffer.get_cache(bufnr)
  if not buf_cache then
    return
  end

  if buffer_blame_loading[bufnr] then
    return
  end

  buffer_blame_enabled[bufnr] = true
  buffer_blame_loading[bufnr] = true

  if running_buffer_procs[bufnr] then
    running_buffer_procs[bufnr]:kill()
    running_buffer_procs[bufnr] = nil
  end

  local file = buf_cache.file
  local cwd = buf_cache.repo.toplevel

  local args = { "-C", cwd, "blame", "--porcelain", "--", file }

  local proc = ark.c.Proc.new({
    cmd = "git",
    args = args,
    timeout = 60000,
    on_exit = function(p, err)
      running_buffer_procs[bufnr] = nil

      vim.schedule(function()
        buffer_blame_loading[bufnr] = nil

        if not vim.api.nvim_buf_is_valid(bufnr) then
          return
        end

        if not buffer_blame_enabled[bufnr] then
          return
        end

        if err then
          return
        end

        local output = p:out()
        local blame = parse_blame_output(output)
        if blame then
          cache[bufnr] = blame
          local winnr = vim.fn.bufwinid(bufnr)
          local lnum = winnr ~= -1 and vim.api.nvim_win_get_cursor(winnr)[1] or nil
          buffer_current_lnum[bufnr] = lnum
          buffer_render(bufnr, blame, lnum)
        end
      end)
    end,
  })

  running_buffer_procs[bufnr] = proc
end

---@param bufnr                      integer|nil
function M.buffer_hide(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  buffer_blame_enabled[bufnr] = nil
  buffer_current_lnum[bufnr] = nil
  buffer_clear(bufnr)
end

---@param bufnr                      integer|nil
function M.buffer_toggle(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if buffer_blame_enabled[bufnr] then
    M.buffer_hide(bufnr)
  else
    M.buffer_show(bufnr)
  end
end

---@param bufnr                      integer|nil
---@return boolean
function M.buffer_is_visible(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  return buffer_blame_enabled[bufnr] == true
end

---@return integer
function M.buffer_get_namespace()
  return buffer_ns
end

---@type ark.timer.IDisposableCallable
local buffer_update_debounced = ark.timer.debounce(function(bufnr)
  buffer_update_current_line(bufnr)
end, 50)

local buffer_augroup = vim.api.nvim_create_augroup("DotModuleGitBufferBlame", { clear = true })

vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
  group = buffer_augroup,
  callback = function(args)
    buffer_update_debounced(args.buf)
  end,
})

return M

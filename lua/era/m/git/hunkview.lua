---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.git.hunkview" ---@type string

---@class era.m.git.hunkview.IProps
---@field public bufnr                 integer

---@class era.m.git.hunkview.IState
---@field protected _disposed          boolean
---@field protected _board_bufnr       integer|nil
---@field protected _board_winnr       integer|nil
---@field protected _ns                integer
---@field protected _bufnr             integer
---@field protected _lnum              integer

---@class era.m.git.Hunkview : era.m.git.hunkview.IState
local M = {}
M.__index = M

---@param props                        era.m.git.hunkview.IProps
---@return era.m.git.Hunkview
function M.new(props)
  local self = setmetatable({}, M)
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  self._disposed = false
  self._board_bufnr = nil
  self._board_winnr = nil
  self._ns = vim.api.nvim_create_namespace("board_git_hunk")
  self._bufnr = props.bufnr
  self._lnum = vim.api.nvim_win_get_cursor(winnr)[1]
  return self
end

---@return nil
function M:dispose()
  if self._disposed then
    return
  end
  self._disposed = true
  self:close()
end

---@return boolean
function M:isdisposed()
  return self._disposed
end

---@return boolean
function M:isvisible()
  return self._board_winnr ~= nil and vim.api.nvim_win_is_valid(self._board_winnr)
end

---@return nil
function M:close()
  local winnr = self._board_winnr ---@type integer|nil
  local bufnr = self._board_bufnr ---@type integer|nil

  self._board_winnr = nil
  self._board_bufnr = nil

  if winnr ~= nil and vim.api.nvim_win_is_valid(winnr) then
    pcall(vim.api.nvim_win_close, winnr, true)
  end

  if bufnr ~= nil and vim.api.nvim_buf_is_valid(bufnr) then
    pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
  end
end

---@return nil
function M:open()
  if self._disposed then
    return
  end

  if self:isvisible() then
    return
  end

  self:close()

  local bufnr = self._bufnr ---@type integer
  local lnum = self._lnum ---@type integer

  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  if not era.m.git.buffer.is_attached(bufnr) then
    era.m.git.buffer.attach(bufnr)
    stl.reporter.info({
      from = __module_name__,
      subject = "Git Hunk",
      message = "Attaching to buffer, try again",
    })
    return
  end

  local hunk = era.m.git.buffer.get_hunk_at(bufnr, lnum) ---@type era.m.git.Hunk|nil
  local is_staged = false ---@type boolean

  if not hunk then
    local staged_hunks = era.m.git.buffer.get_staged_hunks(bufnr)
    if staged_hunks then
      hunk = era.m.git.hunk.find(lnum, staged_hunks)
      if hunk then
        is_staged = true
      end
    end
  end

  if not hunk then
    stl.reporter.info({
      from = __module_name__,
      subject = "Git Hunk",
      message = "No hunk at current line",
    })
    return
  end

  self:__show_popup__(hunk, is_staged)
end

---@return nil
function M:toggle()
  if self:isvisible() then
    self:close()
  else
    self:open()
  end
end

----------------------------------------------------------------------------------------------------

---@protected
---@param width                        integer
---@param height                       integer
---@return integer
---@return integer
function M:__calc_position__(width, height)
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  local cursor_pos = vim.fn.screenpos(winnr, vim.fn.line("."), vim.fn.col("."))
  local cursor_row = cursor_pos.row ---@type integer
  local cursor_col = cursor_pos.col ---@type integer
  local screen_width = vim.o.columns ---@type integer
  local screen_height = vim.o.lines ---@type integer

  local row = 1 ---@type integer
  local col = 0 ---@type integer

  if cursor_row + row + height + 4 > screen_height then
    row = -height - 2
  end

  if cursor_col + col + width + 4 > screen_width then
    col = screen_width - cursor_col - width - 4
  end

  return row, col
end

---@protected
---@param hunk                         era.m.git.Hunk
---@return string[]
---@return stl.t.IHighlight[]
---@return integer
---@return table<integer, { sign: string, hlname: string }>
function M:__render__(hunk)
  local strwidth = vim.api.nvim_strwidth ---@type fun(str: string): integer

  local lines = {} ---@type string[]
  local highlights = {} ---@type stl.t.IHighlight[]
  local signs = {} ---@type table<integer, { sign: string, hlname: string }>

  lines[#lines + 1] = hunk.head
  highlights[#highlights + 1] = {
    lnum = 0,
    coll = 0,
    colr = #hunk.head,
    hlname = "m_bgh_header",
  }
  signs[0] = { sign = "@", hlname = "m_bgh_header" }

  local word_diffs = era.m.git.diff.compute_hunk_word_diff(hunk)
  local word_diff_by_old = {} ---@type table<integer, era.m.git.WordChange[]>
  local word_diff_by_new = {} ---@type table<integer, era.m.git.WordChange[]>

  for _, wd in ipairs(word_diffs) do
    word_diff_by_old[wd.old_lnum] = wd.changes
    word_diff_by_new[wd.new_lnum] = wd.changes
  end

  for i, line in ipairs(hunk.removed.lines) do
    local lnum = #lines
    lines[#lines + 1] = line
    highlights[#highlights + 1] = {
      lnum = lnum,
      coll = 0,
      colr = #line,
      hlname = "DiffDelRight",
    }
    signs[lnum] = { sign = "-", hlname = "Removed" }

    local changes = word_diff_by_old[i]
    if changes then
      for _, change in ipairs(changes) do
        if change.old_end > change.old_start then
          highlights[#highlights + 1] = {
            lnum = lnum,
            coll = change.old_start,
            colr = math.min(change.old_end, #line),
            hlname = "DiffWordLeft",
          }
        end
      end
    end
  end

  for i, line in ipairs(hunk.added.lines) do
    local lnum = #lines
    lines[#lines + 1] = line
    highlights[#highlights + 1] = {
      lnum = lnum,
      coll = 0,
      colr = #line,
      hlname = "DiffAddRight",
    }
    signs[lnum] = { sign = "+", hlname = "Added" }

    local changes = word_diff_by_new[i]
    if changes then
      for _, change in ipairs(changes) do
        if change.new_end > change.new_start then
          highlights[#highlights + 1] = {
            lnum = lnum,
            coll = change.new_start,
            colr = math.min(change.new_end, #line),
            hlname = "DiffWordRight",
          }
        end
      end
    end
  end

  local width = 0 ---@type integer
  for _, line in ipairs(lines) do
    width = math.max(width, strwidth(line))
  end
  local max_width = math.max(40, vim.o.columns - 10) ---@type integer
  width = math.min(width + 2, max_width)

  return lines, highlights, width, signs
end

---@protected
---@param hunk                         era.m.git.Hunk
---@param is_staged                    boolean
---@return nil
function M:__show_popup__(hunk, is_staged)
  if self._disposed then
    return
  end

  local board_bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  self._board_bufnr = board_bufnr

  vim.b[board_bufnr].miniindentscope_disable = true
  vim.b[board_bufnr].miniai_disable = true
  vim.b[board_bufnr].minihipatterns_disable = true
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = board_bufnr })
  vim.api.nvim_set_option_value("buflisted", false, { buf = board_bufnr })
  vim.api.nvim_set_option_value("buftype", "nofile", { buf = board_bufnr })
  vim.api.nvim_set_option_value("filetype", "diff", { buf = board_bufnr })
  vim.api.nvim_set_option_value("swapfile", false, { buf = board_bufnr })
  vim.api.nvim_set_option_value("modifiable", true, { buf = board_bufnr })

  local lines, highlights, width, signs = self:__render__(hunk)
  vim.api.nvim_buf_set_lines(board_bufnr, 0, -1, false, lines)

  vim.api.nvim_set_option_value("modifiable", false, { buf = board_bufnr })
  vim.api.nvim_set_option_value("readonly", true, { buf = board_bufnr })

  for _, hl in ipairs(highlights) do
    vim.hl.range(board_bufnr, self._ns, hl.hlname, { hl.lnum, hl.coll }, { hl.lnum, hl.colr })
  end

  for lnum, sign_info in pairs(signs) do
    vim.api.nvim_buf_set_extmark(board_bufnr, self._ns, lnum, 0, {
      sign_text = sign_info.sign,
      sign_hl_group = sign_info.hlname,
    })
  end

  local height = math.min(#lines, 20) ---@type integer
  local row, col = self:__calc_position__(width, height) ---@type integer, integer

  local winblend = dot.context.theme.get_float_winblend() ---@type integer
  local title_suffix = is_staged and " (staged) " or " "
  local winnr = vim.api.nvim_open_win(board_bufnr, true, {
    relative = "cursor",
    row = row,
    col = col,
    width = width,
    height = height,
    border = "rounded",
    style = "minimal",
    focusable = true,
    title = string.format(" %s Git Hunk%s", stl.icon.git.Diff, title_suffix),
    title_pos = "center",
  })
  self._board_winnr = winnr

  vim.api.nvim_set_option_value("cursorline", true, { win = winnr, scope = "local" })
  vim.api.nvim_set_option_value("number", false, { win = winnr, scope = "local" })
  vim.api.nvim_set_option_value("relativenumber", false, { win = winnr, scope = "local" })
  vim.api.nvim_set_option_value("signcolumn", "yes:1", { win = winnr, scope = "local" })
  vim.api.nvim_set_option_value("spell", false, { win = winnr, scope = "local" })
  vim.api.nvim_set_option_value("winblend", winblend, { win = winnr, scope = "local" })
  vim.api.nvim_set_option_value("winfixbuf", true, { win = winnr, scope = "local" })
  vim.api.nvim_set_option_value("wrap", false, { win = winnr, scope = "local" })
  vim.api.nvim_set_option_value("winhighlight", table.concat({
    "CursorLine:m_ghp_cursor",
    "FloatBorder:ms_b_bg0",
    "FloatTitle:ms_b_bg0",
    "Normal:m_ghp_normal",
    "SignColumn:m_ghp_normal",
  }, ","), { win = winnr, scope = "local" })

  self:__setup_keymaps__(board_bufnr, hunk, is_staged)
end

---@protected
---@param bufnr                        integer
---@param hunk                         era.m.git.Hunk
---@param is_staged                    boolean
---@return nil
function M:__setup_keymaps__(bufnr, hunk, is_staged)
  ---@type stl.t.IKeymap[]
  local keymaps = {
    {
      modes = { "n" },
      key = "q",
      callback = function()
        self:close()
      end,
      desc = "git-hunk: close",
    },
    {
      modes = { "n" },
      key = "<Esc>",
      callback = function()
        self:close()
      end,
      desc = "git-hunk: close",
    },
  }

  if not is_staged then
    keymaps[#keymaps + 1] = {
      modes = { "n" },
      key = "s",
      callback = function()
        self:close()
        -- For topdelete (added.start = 0, vend = 0), use effective position 1
        local effective_start = hunk.added.start == 0 and 1 or hunk.added.start ---@type integer
        local effective_vend = hunk.vend == 0 and 1 or hunk.vend ---@type integer
        local range = { effective_start, effective_vend }
        era.m.git.hunk.stage(range):finally(function(ok, result)
          if ok and result.ok then
            stl.reporter.info({
              from = __module_name__,
              subject = "Git Hunk",
              message = "Hunk staged",
            })
          else
            stl.reporter.error({
              from = __module_name__,
              subject = "Git Hunk",
              message = (result and result.err) or "Failed to stage hunk",
            })
          end
        end)
      end,
      desc = "git-hunk: stage",
    }
    keymaps[#keymaps + 1] = {
      modes = { "n" },
      key = "r",
      callback = function()
        self:close()
        -- For topdelete (added.start = 0, vend = 0), use effective position 1
        local effective_start = hunk.added.start == 0 and 1 or hunk.added.start ---@type integer
        local effective_vend = hunk.vend == 0 and 1 or hunk.vend ---@type integer
        local range = { effective_start, effective_vend }
        local ok, err = era.m.git.hunk.reset(range)
        if ok then
          stl.reporter.info({
            from = __module_name__,
            subject = "Git Hunk",
            message = "Hunk reset",
          })
        else
          stl.reporter.error({
            from = __module_name__,
            subject = "Git Hunk",
            message = err or "Failed to reset hunk",
          })
        end
      end,
      desc = "git-hunk: reset",
    }
  end

  stl.nvim.fn.bindkeys(keymaps, { bufnr = bufnr, noremap = true, silent = true })
end

return M

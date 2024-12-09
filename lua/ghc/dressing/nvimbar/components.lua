local __module_name__ = "ghc.dressing.nvimbar.components" ---@type string

local env = require("eve.lib.env")
local icons = require("eve.lib.icons")
local oxi = require("eve.lib.oxi")
local path = require("eve.lib.path")
local reporter = require("eve.lib.reporter")
local Nvimbar = require("eve.lib.ux.nvimbar")
local G = require("eve.builtin.G")
local commander = require("eve.builtin.commander")
local checks = require("eve.builtin.checks")
local constant = require("eve.builtin.constant")
local status = require("eve.builtin.status")
local util = require("eve.builtin.util")
local widgets = require("eve.builtin.widgets")
local state = require("eve.state")

local btn = Nvimbar.btn
local txt = Nvimbar.txt

---@class ghc.dressing.nvimbar.components
local M = {}

---@param position                      eve.lib.ux.nvimbar.Position
---@return eve.lib.ux.nvimbar.IRawComponent
function M.bufs(position)
  -- local hln_buf = position .. "_buf" ---@type string
  local hln_buf_cur = position .. "_buf_cur" ---@type string
  local hln_buf_indicator = position .. "_buf_indicator" ---@type string
  local hln_buf_mod = position .. "_buf_mod" ---@type string
  local hln_buf_mod_cur = position .. "_buf_mod_cur" ---@type string
  local hln_buf_ommitter = position .. "_buf_ommitter" ---@type string
  local hln_buf_ommitter_sep = position .. "_buf_ommitter_sep" ---@type string
  local hln_buf_sep = position .. "_buf_sep" ---@type string
  local hln_buf_title = position .. "_buf_title" ---@type string
  local hln_buf_title_cur = position .. "_buf_title_cur" ---@type string

  ---@type string
  local fn_active_buf = G.register_anonymous_fn(function(bufnr)
    if type(bufnr) == "number" and vim.api.nvim_buf_is_valid(bufnr) then
      eve.buf.go(bufnr)
    end
  end) or ""

  ---@type string
  local fn_focus_left_buf = G.register_anonymous_fn(function()
    commander.execute(commander.uuids.buf_focus_left)
  end) or ""

  ---@type string
  local fn_focus_right_buf = G.register_anonymous_fn(function()
    commander.execute(commander.uuids.buf_focus_right)
  end) or ""

  ---@param bufnr                         integer
  ---@param is_current                    boolean
  ---@param is_first                      boolean
  ---@return string
  ---@return integer
  local function render_buf(bufnr, is_current, is_first)
    local meta = eve.buf.resolve(bufnr) ---@type eve.t.state.state.buf.IMeta|nil
    if meta == nil then
      return "", 0
    end

    local is_mod = vim.api.nvim_get_option_value("mod", { buf = bufnr }) ---@type boolean
    local is_pinned = meta.pinned ---@type boolean

    local text_indicator_or_sep = is_current and "▎" or (is_first and " " or "▏") ---@type string
    local text_icon = meta.fileicon .. " " ---@type string
    local text_title = meta.filename ---@type string
    local text_mod = is_pinned and (is_mod and "  " or "  ") or (is_mod and "  " or "  ") ---@type string

    local hl_indicator_or_sep = is_current and hln_buf_indicator or hln_buf_sep ---@type string
    local hl_title = is_current and hln_buf_title_cur or hln_buf_title ---@type string
    local hl_mod = is_current and hln_buf_mod_cur or hln_buf_mod ---@type string
    -- local hl_icon = (is_current and hln_buf_cur or hln_buf) .. "_" .. meta.fileicon_hl ---@type string
    local hl_icon = (is_current and hln_buf_cur .. "_" .. meta.fileicon_hl) or hln_buf_title ---@type string

    local hl_text_indicator = txt(text_indicator_or_sep, hl_indicator_or_sep)
    local hl_text_icon = txt(text_icon, hl_icon)
    local hl_text_title = txt(text_title, hl_title)
    local hl_text_mod = is_mod and txt(text_mod, hl_mod) or text_mod

    local width = vim.api.nvim_strwidth(text_indicator_or_sep)
      + vim.api.nvim_strwidth(text_icon)
      + vim.api.nvim_strwidth(text_title)
      + vim.api.nvim_strwidth(text_mod)
    local hl_text = hl_text_indicator .. hl_text_icon .. hl_text_title .. hl_text_mod ---@type string
    return btn(hl_text, fn_active_buf, bufnr), width
  end

  ---@type eve.lib.ux.nvimbar.IRawComponent
  local component = {
    name = "bufs",
    ---@diagnostic disable-next-line: unused-local
    render = function(context, remain_width)
      local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
      local meta = eve.tab.resolve(tabnr) ---@type eve.t.state.state.tab.IMeta|nil
      if meta == nil then
        return "", 0
      end

      local tab_bufnrs = meta.bufnrs ---@type integer[]
      local N = #tab_bufnrs ---@type integer
      if N < 1 then
        return "", 0
      end

      local bufnr_cur = eve.tab.get_current_bufnr() ---@type integer
      local bufid_src = util.find_index(tab_bufnrs, bufnr_cur) ---@type integer|nil
      local bufid_cur = bufid_src or 1
      bufnr_cur = tab_bufnrs[bufid_cur]

      local text, width = render_buf(tab_bufnrs[bufid_cur], bufid_src ~= nil, bufid_cur == 1)
      if remain_width < width then
        return "", 0
      end

      local left_remain_count = bufid_cur - 1 ---@type integer
      local right_remain_count = N - bufid_cur ---@type integer
      local left_omitter_width = bufid_cur == 1 and 0 or 7 ---@type integer
      local right_omitter_width = bufid_cur == N and 0 or 7 ---@type integer

      ---! Render left bufs as many as possible.
      do
        local available_width = remain_width - left_omitter_width - right_omitter_width ---@type integer
        for i = bufid_cur - 1, 1, -1 do
          local t, w = render_buf(tab_bufnrs[i], false, i == 1)
          local width_next = width + w ---@type integer

          if i == 1 then
            if available_width + left_omitter_width >= width_next then
              text = t .. text
              width = width_next
              left_remain_count = 0
              left_omitter_width = 0
            end
            break
          end

          if available_width < width_next then
            break
          end

          text = t .. text
          width = width_next
          left_remain_count = left_remain_count - 1
        end
      end

      ---! Render right bufs as many as possible.
      do
        local available_width = remain_width - left_omitter_width - right_omitter_width ---@type integer
        for i = bufid_cur + 1, N, 1 do
          local t, w = render_buf(tab_bufnrs[i], false, false)
          local width_next = width + w ---@type integer

          if i == N then
            if available_width + right_omitter_width >= width_next then
              text = text .. t
              width = width_next
              right_remain_count = 0
              right_omitter_width = 0
            end
            break
          end

          if available_width < width_next then
            break
          end

          text = text .. t
          width = width_next
          right_remain_count = right_remain_count - 1
        end
      end

      ---! Render left omitter.
      if left_omitter_width > 0 then
        local count = math.min(99, left_remain_count) ---@type integer
        local omitter_text = " " .. icons.ui.Left .. "  " .. tostring(count) .. " " ---@type string
        local omitter_text_hl = txt(omitter_text, hln_buf_ommitter) ---@type string
        text = btn(omitter_text_hl, fn_focus_left_buf) .. text
        width = width + vim.api.nvim_strwidth(omitter_text)
      end

      ---! Render right omitter.
      if right_omitter_width > 0 then
        local count = math.min(99, right_remain_count) ---@type integer
        local omitter_text = "▏" .. tostring(count) .. " " .. icons.ui.Right .. "  " ---@type string
        local omitter_text_hl = txt("▏", hln_buf_ommitter_sep)
          .. txt(tostring(count) .. " " .. icons.ui.Right .. "  ", hln_buf_ommitter) ---@type string
        text = text .. btn(omitter_text_hl, fn_focus_right_buf)
        width = width + vim.api.nvim_strwidth(omitter_text)
      end

      return text, width
    end,
  }
  return component
end

---@param position                      eve.lib.ux.nvimbar.Position
---@return eve.lib.ux.nvimbar.IRawComponent
function M.copilot(position)
  local hln_text = position .. "_text" ---@type string
  local hln_copilot = position .. "_copilot" ---@type string

  ---@type string
  local fn_show_message = G.register_anonymous_fn(function()
    if package.loaded["copilot"] then
      local copilot_status = require("copilot.api").status.data
      reporter.info({
        from = __module_name__,
        subject = "copilot",
        details = { status = copilot_status or "nil" },
      })
    end
  end)

  local status_icon_map = {
    Inactive = icons.cmp.copilot_error,
    InProgress = icons.cmp.copilot,
    Normal = icons.cmp.copilot,
    Warning = icons.cmp.copilot_warn,
  }

  local last_status = nil ---@type string|nil

  ---@type eve.lib.ux.nvimbar.IRawComponent
  local component = {
    name = "copilot",
    condition = function()
      return not not package.loaded["copilot"]
    end,
    will_change = function()
      local copilot_status = require("copilot.api").status.data.status ---@type string|nil
      local changed = copilot_status ~= last_status
      last_status = copilot_status
      return changed
    end,
    render = function()
      local copilot_status = last_status or "Normal" ---@type string
      local icon = status_icon_map[copilot_status] or icons.cmp.copilot ---@type string
      local text = icon .. " " ---@type string
      local width = vim.api.nvim_strwidth(text) ---@type integer
      local hl_text =
        txt(text, (copilot_status == nil or #copilot_status < 1) and hln_text or (hln_copilot .. "_" .. copilot_status))
      hl_text = btn(hl_text, fn_show_message)
      return hl_text, width
    end,
  }
  return component
end

---@param position                      eve.lib.ux.nvimbar.Position
---@return eve.lib.ux.nvimbar.IRawComponent
function M.cwd(position)
  local hln_cwd = position .. "_cwd" ---@type string

  ---@type eve.lib.ux.nvimbar.IRawComponent
  local component = {
    name = "cwd",
    will_change = function(context, prev_context)
      return prev_context == nil or context.cwd ~= prev_context.cwd
    end,
    render = function(context)
      local cwd_name = (context.cwd:match("([^/\\]+)[/\\]*$") or context.cwd)
      local text = " " .. icons.ui.Explorer .. " " .. cwd_name .. " " ---@type string
      local hl_text = txt(text, hln_cwd) ---@type string
      local width = vim.api.nvim_strwidth(text) ---@type integer
      return hl_text, width
    end,
  }
  return component
end

---@param position                      eve.lib.ux.nvimbar.Position
---@return eve.lib.ux.nvimbar.IRawComponent
function M.debug_render_count(position)
  local hln_debug_render_count = position .. "_debug_render_count" ---@type string
  local count = 0 ---@type integer

  ---@type eve.lib.ux.nvimbar.IRawComponent
  local component = {
    name = "debug_render_count",
    condition = function()
      local devmode = state.state.flight.devmode:snapshot() ---@type boolean
      return devmode
    end,
    render = function()
      count = count + 1
      local text = "  " .. util.pad_start(tostring(count % 100000), 5, "0") .. " " ---@type string
      local hl_text = txt(text, hln_debug_render_count) ---@type string
      local width = vim.api.nvim_strwidth(text) ---@type integer
      return hl_text, width
    end,
  }
  return component
end

---@param position                      eve.lib.ux.nvimbar.Position
---@return eve.lib.ux.nvimbar.IRawComponent
function M.devmode(position)
  local hln_devmode = position .. "_devmode" ---@type string

  ---@type eve.lib.ux.nvimbar.IRawComponent
  local component = {
    name = "devmode",
    condition = function()
      local devmode = state.state.flight.devmode:snapshot() ---@type boolean
      return devmode
    end,
    render = function()
      local text = "  devmode " ---@type string
      local hl_text = txt(text, hln_devmode) ---@type string
      local width = vim.api.nvim_strwidth(text) ---@type integer
      return hl_text, width
    end,
  }
  return component
end

---@param position                      eve.lib.ux.nvimbar.Position
---@return eve.lib.ux.nvimbar.IRawComponent
function M.diagnostics(position)
  local hln_diagnostics_error = position .. "_diagnostics_error" ---@type string
  local hln_diagnostics_warn = position .. "_diagnostics_warn" ---@type string
  local hln_diagnostics_hint = position .. "_diagnostics_hint" ---@type string
  local hln_diagnostics_info = position .. "_diagnostics_info" ---@type string

  ---@type eve.lib.ux.nvimbar.IRawComponent
  local component = {
    name = "diagnostics",
    condition = function()
      return not not rawget(vim, "lsp")
    end,
    render = function(context)
      local count_error = #vim.diagnostic.get(context.bufnr, { severity = vim.diagnostic.severity.ERROR })
      local text_count_error = count_error > 0 and icons.diagnostics.Error .. " " .. count_error .. " " or ""

      local count_warn = #vim.diagnostic.get(context.bufnr, { severity = vim.diagnostic.severity.WARN })
      local text_count_warn = count_warn > 0 and icons.diagnostics.Warning .. " " .. count_warn .. " " or ""

      local count_hint = #vim.diagnostic.get(context.bufnr, { severity = vim.diagnostic.severity.HINT })
      local text_count_hint = count_hint > 0 and icons.diagnostics.Hint .. " " .. count_hint .. " " or ""

      local count_info = #vim.diagnostic.get(context.bufnr, { severity = vim.diagnostic.severity.INFO })
      local text_count_info = count_info > 0 and icons.diagnostics.Information .. " " .. count_info .. " " or ""

      local text_hl = txt(text_count_error, hln_diagnostics_error)
        .. txt(text_count_warn, hln_diagnostics_warn)
        .. txt(text_count_hint, hln_diagnostics_hint)
        .. txt(text_count_info, hln_diagnostics_info)
      local width = vim.api.nvim_strwidth(text_count_error)
        + vim.api.nvim_strwidth(text_count_warn)
        + vim.api.nvim_strwidth(text_count_hint)
        + vim.api.nvim_strwidth(text_count_info)

      return text_hl, width
    end,
  }
  return component
end

---@param position                      eve.lib.ux.nvimbar.Position
---@return eve.lib.ux.nvimbar.IRawComponent
function M.diffview(position)
  local hln_sidebar_blank = position .. "_sidebar_blank" ---@type string
  local hln_sidebar_split = position .. "_sidebar_split" ---@type string
  local hln_sidebar_text = position .. "_sidebar_text" ---@type string

  ---@return integer
  local function get_pane_width()
    local winnrs = vim.api.nvim_tabpage_list_wins(0) ---@type integer[]
    for _, winnr in ipairs(winnrs) do
      local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
      if vim.bo[bufnr].filetype == constant.FT_DIFFVIEW_FILES then
        if not checks.is_win_floating(winnr) then
          return vim.api.nvim_win_get_width(winnr) + 1
        end
      end
    end
    return 0
  end

  ---@type eve.lib.ux.nvimbar.IRawComponent
  local component = {
    name = "diffview",
    ---@diagnostic disable-next-line: unused-local
    render = function(context, remain_width)
      local width = math.min(remain_width, get_pane_width()) ---@type integer
      if width <= 20 then
        return "", 0
      end

      local text = icons.git.Git .. " Git Diffview" ---@type string
      local text_width = vim.api.nvim_strwidth(text) ---@type integer
      local text_width_remain = width - text_width ---@type integer
      local left_width = math.floor(text_width_remain / 2)
      local right_width = text_width_remain - left_width - 1
      local left_blank = string.rep(" ", left_width)
      local right_blank = string.rep(" ", right_width)
      local right_split = " " -- "│"

      local hl_text = txt(left_blank, hln_sidebar_blank)
        .. txt(text, hln_sidebar_text)
        .. txt(right_blank, hln_sidebar_blank)
        .. txt(right_split, hln_sidebar_split)
      return hl_text, width
    end,
  }
  return component
end

---@param position                      eve.lib.ux.nvimbar.Position
---@return eve.lib.ux.nvimbar.IRawComponent
function M.dirpath(position)
  local hln_dirpath_text = position .. "_dirpath_text" ---@type string
  local hln_dirpath_sep = position .. "_dirpath_sep" ---@type string
  local sep = " " .. env.PATH_SEP .. " " ---@type string
  local width_sep = vim.api.nvim_strwidth(sep) ---@type integer

  ---@type eve.lib.ux.nvimbar.IRawComponent
  local component = {
    name = "dirpath",
    will_change = function(context, prev_context)
      return prev_context == nil or context.filepath ~= prev_context.filepath
    end,
    render = function(context)
      local winnr = context.winnr ---@type integer
      local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
      local meta = eve.buf.resolve(bufnr) ---@type eve.t.state.state.buf.IMeta|nil
      if meta == nil then
        return "", 0
      end

      local hl_text = "" ---@type string
      local width = 0 ---@type integer
      local N = #meta.relpath - 1 ---@type integer
      for i = 1, N, 1 do
        local piece = meta.relpath[i] ---@type string
        local hl_text_piece = txt(piece, hln_dirpath_text) ---@type string
        local hl_text_sep = txt(sep, hln_dirpath_sep) ---@type string
        hl_text = hl_text .. hl_text_piece .. hl_text_sep
        width = width + vim.api.nvim_strwidth(piece) + width_sep
      end
      return hl_text, width
    end,
  }
  return component
end

---@param position                      eve.lib.ux.nvimbar.Position
---@return eve.lib.ux.nvimbar.IRawComponent
function M.fileformat(position)
  local hln_text = position .. "_text" ---@type string

  local fileformat_text_map = {
    dos = "CRLF",
    mac = "CR",
    unix = "LF",
  }

  ---@type eve.lib.ux.nvimbar.IRawComponent
  local component = {
    name = "fileformat",
    condition = function()
      return vim.o.columns > 100
    end,
    render = function()
      ---@diagnostic disable-next-line: undefined-field
      local text_encoding = vim.opt.fileencoding:get()
      local text_fileformat = fileformat_text_map[vim.bo.fileformat] or "UNKNOWN"
      local icon_tab = icons.ui.Tab .. " "
      local text_tab = vim.api.nvim_get_option_value("shiftwidth", { scope = "local" })
      local text = text_encoding .. " " .. text_fileformat .. " " .. icon_tab .. text_tab
      local hl_text = txt(text, hln_text)
      local width = vim.api.nvim_strwidth(text) ---@type integer
      return hl_text, width
    end,
  }
  return component
end

---@param position                      eve.lib.ux.nvimbar.Position
---@return eve.lib.ux.nvimbar.IRawComponent
function M.filename(position)
  local hln_filename = position .. "_filename" ---@type string
  local hln_filename_text = position .. "_filename_text" ---@type string

  ---@type eve.lib.ux.nvimbar.IRawComponent
  local component = {
    name = "filename",
    will_change = function(context, prev_context)
      return prev_context == nil or context.filename ~= prev_context.filename
    end,
    render = function(context)
      local winnr = context.winnr ---@type integer
      local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
      local meta = eve.buf.resolve(bufnr) ---@type eve.t.state.state.buf.IMeta|nil
      if meta == nil then
        local filepath = vim.api.nvim_buf_get_name(bufnr) ---@type string
        local text = path.basename(filepath) ---@type string
        local width = vim.api.nvim_strwidth(text) ---@type integer
        local hl_text = txt(text, hln_filename_text)
        return hl_text, width
      end

      local text_icon = meta.fileicon .. " " ---@type string
      local text_filename = meta.filename ---@type string
      local hl_text_icon = txt(text_icon, hln_filename .. "_" .. meta.fileicon_hl) ---@type string
      local hl_text_title = txt(text_filename, hln_filename_text) ---@type string

      local hl_text = hl_text_icon .. hl_text_title
      local width = vim.api.nvim_strwidth(text_icon .. text_filename) ---@type integer
      return hl_text, width
    end,
  }
  return component
end

---@param position                      eve.lib.ux.nvimbar.Position
---@return eve.lib.ux.nvimbar.IRawComponent
function M.filepath(position)
  local hln_text = position .. "_text" ---@type string

  ---@param context                       eve.lib.ux.nvimbar.IContext
  ---@return string
  local function get_filepath(context)
    local cwd = context.cwd ---@type string
    local filepath = context.filepath ---@type string
    local relative_to_cwd = path.relative(cwd, filepath, false) ---@type string
    if string.sub(relative_to_cwd, 1, 1) == "." and path.is_absolute(filepath) then
      local workspace = path.workspace() ---@type string
      if cwd ~= workspace then
        local relative_to_workspace = path.relative(workspace, filepath, false)
        if string.sub(relative_to_workspace, 1, 1) == "." then
          relative_to_cwd = path.normalize(filepath)
        end
      end
    end
    return context.fileicon .. " " .. relative_to_cwd
  end

  ---@type eve.lib.ux.nvimbar.IRawComponent
  local component = {
    name = "filepath",
    condition = function(context)
      return #context.filepath > 0 and context.filepath ~= "."
    end,
    will_change = function(context, prev_context)
      return prev_context == nil or context.filepath ~= prev_context.filepath
    end,
    render = function(context)
      local text = get_filepath(context) ---@type string
      local hl_text = txt(text, hln_text)
      local width = vim.api.nvim_strwidth(text)
      return hl_text, width
    end,
  }
  return component
end

---@param position                      eve.lib.ux.nvimbar.Position
---@return eve.lib.ux.nvimbar.IRawComponent
function M.filesize(position)
  local hln_text = position .. "_text" ---@type string

  ---@type eve.lib.ux.nvimbar.IRawComponent
  local component = {
    name = "filesize",
    will_change = function(context, prev_context)
      return prev_context == nil or context.filepath ~= prev_context.filepath or context.mode ~= prev_context.mode
    end,
    render = function(context)
      local text = oxi.get_filesize(context.filepath) or "" ---@type string
      local hl_text = txt(text, hln_text)
      local width = vim.api.nvim_strwidth(text)
      return hl_text, width
    end,
  }
  return component
end

---@param position                      eve.lib.ux.nvimbar.Position
---@return eve.lib.ux.nvimbar.IRawComponent
function M.filestatus(position)
  local hln_text = position .. "_text" ---@type string

  ---@return string
  local function get_filestatus()
    local bufnr = eve.tab.get_current_bufnr() ---@type integer
    if bufnr < 1 or not vim.api.nvim_buf_is_valid(bufnr) then
      return ""
    end

    local buffer_status_line = vim.b[bufnr]
    if buffer_status_line and buffer_status_line.gitsigns_head and not buffer_status_line.gitsigns_git_status then
      local texts = {} ---@type string[]
      local git_status = buffer_status_line.gitsigns_status_dict
      if git_status.added and git_status.added > 0 then
        table.insert(texts, icons.git.Add .. " " .. git_status.added)
      end
      if git_status.changed and git_status.changed > 0 then
        table.insert(texts, icons.git.Mod_alt .. " " .. git_status.changed)
      end
      if git_status.removed and git_status.removed > 0 then
        table.insert(texts, icons.git.Remove .. " " .. git_status.removed)
      end
      return table.concat(texts, " ")
    end
    return ""
  end

  ---@type eve.lib.ux.nvimbar.IRawComponent
  local component = {
    name = "filestatus",
    tight = true,
    will_change = function(context, prev_context)
      return prev_context == nil or context.filepath ~= prev_context.filepath or context.mode ~= prev_context.mode
    end,
    render = function()
      local filestatus = get_filestatus() ---@type string
      if #filestatus < 1 then
        return "", 0
      end

      local text_filestatus = " " .. filestatus ---@type string
      local hl_text = txt(text_filestatus, hln_text) ---@type string
      local width = vim.api.nvim_strwidth(text_filestatus)
      return hl_text, width
    end,
  }
  return component
end

---@param position                      eve.lib.ux.nvimbar.Position
---@return eve.lib.ux.nvimbar.IRawComponent
function M.filetype(position)
  local hln_text = position .. "_text" ---@type string

  ---@type eve.lib.ux.nvimbar.IRawComponent
  local component = {
    name = "filetype",
    will_change = function(context, prev_context)
      return prev_context == nil or context.filetype ~= prev_context.filetype
    end,
    condition = function(context)
      return context.filetype and #context.filetype > 0
    end,
    render = function(context)
      local text = context.fileicon .. " " .. context.filetype ---@type string
      local hl_text = txt(text, hln_text) ---@type string
      local width = vim.api.nvim_strwidth(text)
      return hl_text, width
    end,
  }
  return component
end

---@param position                      eve.lib.ux.nvimbar.Position
---@return eve.lib.ux.nvimbar.IRawComponent
function M.git(position)
  local hln_text = position .. "_text" ---@type string

  ---@type eve.lib.ux.nvimbar.IRawComponent
  local component = {
    name = "git",
    tight = true,
    condition = function(context)
      local buffer_status_line = vim.b[context.bufnr]
      return buffer_status_line and buffer_status_line.gitsigns_status_dict
    end,
    render = function(context)
      local buffer_status_line = vim.b[context.bufnr]
      local git_status = buffer_status_line.gitsigns_status_dict
      local branch_name = git_status.head ---@type string
      local text = " " .. icons.git.Branch .. " " .. branch_name ---@type string
      local hl_text = txt(text, hln_text) ---@type string
      local width = vim.api.nvim_strwidth(text) ---@type integer
      return hl_text, width
    end,
  }
  return component
end

---@param position                      eve.lib.ux.nvimbar.Position
---@return eve.lib.ux.nvimbar.IRawComponent
function M.lsp(position)
  local hln_text = position .. "_text" ---@type string

  ---@return string
  local function get_text()
    local bufnr = eve.tab.get_current_bufnr() ---@type integer
    if bufnr > 0 and not vim.api.nvim_buf_is_valid(bufnr) then
      return ""
    end

    local client_names = {} ---@type string[]
    for _, client in ipairs(vim.lsp.get_clients({ bufnr = bufnr })) do
      if client.attached_buffers[bufnr] and client.name ~= "null-ls" and client.name ~= "copilot" then
        table.insert(client_names, client.name)
      end
    end

    return #client_names > 0 and "  " .. table.concat(client_names, "|") or ""
  end

  ---@type eve.lib.ux.nvimbar.IRawComponent
  local component = {
    name = "lsp",
    condition = function()
      return not not rawget(vim, "lsp")
    end,
    render = function()
      local text = get_text() ---@type string
      local width = vim.api.nvim_strwidth(text) ---@type integer
      local hl_text = txt(text, hln_text) ---@type string
      return hl_text, width
    end,
  }
  return component
end

---@param position                      eve.lib.ux.nvimbar.Position
---@return eve.lib.ux.nvimbar.IRawComponent
function M.lsp_message(position)
  local hln_text = position .. "_text" ---@type string

  ---@type eve.lib.ux.nvimbar.IRawComponent
  local component = {
    name = "lsp_message",
    condition = function()
      return not not rawget(vim, "lsp") and #status.lsp_msg:snapshot() > 0
    end,
    render = function()
      local text = status.lsp_msg:snapshot() ---@type string
      local hl_text = txt(text, hln_text) ---@type string
      local width = vim.api.nvim_strwidth(text) ---@type integer
      return hl_text, width
    end,
  }
  return component
end

---@param position                      eve.lib.ux.nvimbar.Position
---@return eve.lib.ux.nvimbar.IRawComponent
function M.lsp_symbols(position)
  local hln_lsp_icon = position .. "_lsp_icon" ---@type string
  local hln_lsp_sep = position .. "_lsp_sep" ---@type string
  local hln_lsp_text = position .. "_lsp_text" ---@type string

  local sep = "  " ---@type string
  local width_sep = vim.api.nvim_strwidth(sep) ---@type integer

  ---@type string
  local fn_goto_lsp_pos = G.register_anonymous_fn(function(num)
    local args = Nvimbar.decode_btn_args(tostring(num)) ---@type integer[]
    if #args == 3 then
      local winnr = args[1] ---@type integer|nil
      local row = args[2] ---@type integer|nil
      local col = args[3] ---@type integer|nil

      if type(winnr) == "number" and type(row) == "number" and type(col) == "number" then
        if vim.api.nvim_win_is_valid(winnr) then
          vim.api.nvim_win_set_cursor(winnr, { row, col })
        end
      end
    end
  end) or ""

  ---@type eve.lib.ux.nvimbar.IRawComponent
  local component = {
    name = "lsp_symbols",
    ---@diagnostic disable-next-line: unused-local
    render = function(context, remain_width)
      local winnr = context.winnr ---@type integer
      local meta = eve.win.resolve(winnr) ---@type eve.t.state.state.win.IMeta|nil
      if meta == nil then
        return "", 0
      end

      local symbols = meta.lsp_symbols ---@type eve.t.state.state.lsp.ISymbol[]|nil
      if symbols == nil or #symbols < 1 then
        return "", 0
      end

      local hl_text = "" ---@type string
      local width = 0 ---@type integer
      for _, symbol in ipairs(symbols) do
        local title = symbol.name or "" ---@type string
        local icon = (icons.kind[symbol.kind] or "") .. " " ---@type string
        local next_width = width + width_sep + vim.api.nvim_strwidth(icon .. title) ---@type integer
        if next_width > remain_width then
          break
        end

        width = next_width
        local hln_icon = symbol.kind and hln_lsp_icon .. "_" .. symbol.kind or hln_lsp_icon
        local hl_lsp_piece = txt(sep, hln_lsp_sep) .. txt(icon, hln_icon) .. txt(title, hln_lsp_text)
        hl_text = hl_text .. btn(hl_lsp_piece, fn_goto_lsp_pos, { winnr, symbol.row, symbol.col })
      end
      return hl_text, width
    end,
  }
  return component
end

---@param position                      eve.lib.ux.nvimbar.Position
---@return eve.lib.ux.nvimbar.IRawComponent
function M.mode(position)
  local hln_text = position .. "_text" ---@type string

  ---@type eve.lib.ux.nvimbar.IRawComponent
  local component = {
    name = "mode",
    tight = true,
    will_change = function(context, prev_context)
      return prev_context == nil or context.mode ~= prev_context.mode
    end,
    render = function(context)
      local text = "  " .. context.mode_name .. " " ---@type string
      local hl_text = txt(text, hln_text .. "_" .. context.mode) ---@type string
      local width = vim.api.nvim_strwidth(text) ---@type integer
      return hl_text, width
    end,
  }
  return component
end

---@param position                      eve.lib.ux.nvimbar.Position
---@return eve.lib.ux.nvimbar.IRawComponent
function M.neotree(position)
  local hln_sidebar_blank = position .. "_sidebar_blank" ---@type string
  local hln_sidebar_split = position .. "_sidebar_split" ---@type string
  local hln_sidebar_text = position .. "_sidebar_text" ---@type string

  ---@return integer
  local function get_pane_width()
    local winnrs = vim.api.nvim_tabpage_list_wins(0) ---@type integer[]
    for _, winnr in ipairs(winnrs) do
      local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
      if vim.bo[bufnr].filetype == constant.FT_NEOTREE then
        if not checks.is_win_floating(winnr) then
          return vim.api.nvim_win_get_width(winnr) + 1
        end
      end
    end
    return 0
  end

  ---@type eve.lib.ux.nvimbar.IRawComponent
  local component = {
    name = "neotree",
    ---@diagnostic disable-next-line: unused-local
    render = function(context, remain_width)
      local width = math.min(remain_width, get_pane_width()) ---@type integer
      if width <= 20 then
        return "", 0
      end

      local cwd_name = context.cwd:match("([^/\\]+)[/\\]*$") or context.cwd ---@type string
      local text = icons.ui.Explorer .. " " .. cwd_name ---@type string
      local text_width = vim.api.nvim_strwidth(text) ---@type integer
      local text_width_remain = width - text_width ---@type integer
      local left_width = math.floor(text_width_remain / 2)
      local right_width = text_width_remain - left_width - 1
      local left_blank = string.rep(" ", left_width)
      local right_blank = string.rep(" ", right_width)
      local right_split = " " -- "│"

      local hl_text = txt(left_blank, hln_sidebar_blank)
        .. txt(text, hln_sidebar_text)
        .. txt(right_blank, hln_sidebar_blank)
        .. txt(right_split, hln_sidebar_split)
      return hl_text, width
    end,
  }
  return component
end

---@param position                      eve.lib.ux.nvimbar.Position
---@return eve.lib.ux.nvimbar.IRawComponent
function M.noice(position)
  local hln_bg = position .. "_bg" ---@type string
  -- local hln_noice_command = position .. "_noice_command" ---@type string
  local hln_noice_mode = position .. "_noice_mode" ---@type string

  ---@type eve.lib.ux.nvimbar.IRawComponent
  local component = {
    name = "noice",
    condition = function()
      return not not package.loaded["noice"]
    end,
    render = function()
      local noice_status = require("noice").api.status
      local hl_text = "" ---@type string
      local width = 0 ---@type integer

      -- local text_noice_command = noice_status.command.get() ---@type string | nil
      -- if text_noice_command ~= nil and #text_noice_command > 0 then
      --   hl_text = txt(text_noice_command, hln_noice_command)
      --   width = vim.api.nvim_strwidth(text_noice_command)
      -- end

      local text_noice_mode = noice_status.mode.get() or ""
      if text_noice_mode ~= nil and #text_noice_mode > 0 then
        if width > 0 then
          hl_text = hl_text .. txt(" ", hln_bg)
          width = width + 1
        end

        hl_text = hl_text .. txt(text_noice_mode, hln_noice_mode)
        width = width + vim.api.nvim_strwidth(text_noice_mode)
      end
      return hl_text, width
    end,
  }
  return component
end

---@param position                      eve.lib.ux.nvimbar.Position
---@return eve.lib.ux.nvimbar.IRawComponent
function M.pos(position)
  local hln_pos = position .. "_pos" ---@type string
  local hln_pos_top = position .. "_pos_top" ---@type string
  local hln_pos_bot = position .. "_pos_bot" ---@type string
  local hln_text = position .. "_text" ---@type string

  ---@return integer
  ---@return integer
  ---@return string
  ---@return string
  local function calc_row_percentage()
    local total_lines = vim.fn.line("$")
    local cursor = vim.api.nvim_win_get_cursor(0)
    local row = cursor[1] ---@type integer
    local col = cursor[2] + 1 ---@type integer

    if row == 1 then
      return row, col, "top", hln_pos_top
    elseif row == total_lines then
      return row, col, "bot", hln_pos_bot
    else
      local text = util.pad_start(tostring(math.floor(100 * row / total_lines)), 2, " ") .. "%" ---@type string
      return row, col, text, hln_pos
    end
  end

  ---@type eve.lib.ux.nvimbar.IRawComponent
  local component = {
    name = "pos",
    render = function()
      local row, col, percentage, hl_pos = calc_row_percentage() ---@type integer, integer, string
      local text_anchor = ""
        .. util.pad_start(tostring(row), 4, " ")
        .. "·"
        .. util.pad_end(tostring(col), 3, " ")
        .. " " ---@type string
      local text_pos = " " .. percentage .. " " ---@type string
      local hl_text = txt(text_anchor, hln_text) .. txt(text_pos, hl_pos) ---@type string
      local width = vim.api.nvim_strwidth(text_anchor .. text_pos) ---@type integer
      return hl_text, width
    end,
  }
  return component
end

---@param position                      eve.lib.ux.nvimbar.Position
---@return eve.lib.ux.nvimbar.IRawComponent
function M.readonly(position)
  local hln_readonly = position .. "_readonly" ---@type string

  ---@type eve.lib.ux.nvimbar.IRawComponent
  local component = {
    name = "readonly",
    condition = function()
      return vim.bo.readonly
    end,
    render = function()
      local text = icons.ui.Lock .. " [RO]" ---@type string
      local hl_text = txt(text, hln_readonly) ---@type string
      local width = vim.api.nvim_strwidth(text) ---@type integer
      return hl_text, width
    end,
  }
  return component
end

---@param position                      eve.lib.ux.nvimbar.Position
---@return eve.lib.ux.nvimbar.IRawComponent
function M.tabs(position)
  local hln_toggle = position .. "_tab_toggle" ---@type string
  local hln_tab_item = position .. "_tab_item" ---@type string
  local hln_tab_item_cur = position .. "_tab_item_cur" ---@type string

  local dirty = true ---@type boolean
  local folded = false ---@type boolean
  local last_tab_cur = 0 ---@type integer
  local last_tab_count = 0 ---@type integer

  ---@type string
  local fn_active_tab = G.register_anonymous_fn(function(tabid)
    commander.execute(commander.uuids.tab_focus, tostring(tabid))
  end) or ""

  ---@type string
  local fn_toggle_tabs_folded = G.register_anonymous_fn(function()
    folded = not folded
    dirty = true
    status.tabline_dirtier:mark_dirty()
  end) or ""

  ---@type eve.lib.ux.nvimbar.IRawComponent
  local component = {
    name = "tabs",
    will_change = function()
      local tab_cur = vim.fn.tabpagenr() ---@type integer
      local tab_count = vim.fn.tabpagenr("$") ---@type integer
      local changed = last_tab_cur ~= tab_cur or last_tab_count ~= tab_count ---@type boolean
      last_tab_cur = tab_cur
      last_tab_count = tab_count
      dirty = dirty or changed
      return dirty
    end,
    render = function()
      dirty = false

      if last_tab_count <= 1 then
        return "", 0
      end

      if folded then
        local text = " 󰅁 "
        local width = vim.api.nvim_strwidth(text)
        local hl_text = txt(text, hln_toggle)
        hl_text = btn(hl_text, fn_toggle_tabs_folded)
        return hl_text, width
      end

      local text = " 󰅂 " ---@type string
      local width = vim.api.nvim_strwidth(text) ---@type integer
      local hl_text = txt(text, hln_toggle)
      hl_text = btn(hl_text, fn_toggle_tabs_folded)

      local tabnrs = vim.api.nvim_list_tabpages() ---@type integer[]
      for tabid = 1, last_tab_count, 1 do
        local hlname = last_tab_cur == tabid and hln_tab_item_cur or hln_tab_item
        text = " " .. tabid .. " "
        width = width + vim.api.nvim_strwidth(text)
        local hl_text_inner = txt(text, hlname)
        hl_text = hl_text .. btn(hl_text_inner, fn_active_tab, tabnrs[tabid])
      end
      return hl_text, width
    end,
  }
  return component
end

---@param position                      eve.lib.ux.nvimbar.Position
---@return eve.lib.ux.nvimbar.IRawComponent
function M.username(position)
  local hln_username = position .. "_username" ---@type string

  ---@type eve.lib.ux.nvimbar.IRawComponent
  local component = {
    name = "username",
    ---@diagnostic disable-next-line: unused-local
    will_change = function(context, prev_context)
      return prev_context == nil
    end,
    render = function()
      local icon = icons.os.current ---@type string
      local text = " " .. icon .. " " .. env.USERNAME .. " " ---@type string
      local hl_text = txt(text, hln_username) ---@type string
      local width = vim.api.nvim_strwidth(text) ---@type integer
      return hl_text, width
    end,
  }
  return component
end

---@param position                      eve.lib.ux.nvimbar.Position
---@return eve.lib.ux.nvimbar.IRawComponent
function M.widget(position)
  local hln_flag = position .. "_flag" ---@type string
  local hln_flag_enabled = position .. "_flag_enabled" ---@type string
  local hln_scope = position .. "_flag_scope" ---@type string

  ---@type eve.lib.ux.nvimbar.IRawComponent
  local component = {
    name = "widget",
    condition = function()
      local widget = widgets.get_current_widget() ---@type eve.t.ux.IWidget|nil
      return widget ~= nil and widget:status() == "visible"
    end,
    render = function()
      local widget = widgets.get_current_widget() ---@type eve.t.ux.IWidget|nil
      if widget == nil then
        return "", 0
      end

      local items = widget.statusline_items ---@type eve.t.ux.widget.IStatuslineItem[]|nil
      if items == nil or #items < 1 then
        return "", 0
      end

      local hl_text = "" ---@type string
      local width = 0 ---@type integer

      for _, item in ipairs(items) do
        local fn = item.callback_fn ---@type string
        if item.type == "flag" then
          local flag = item.state:snapshot() ---@type boolean
          local text = " " .. item.symbol .. " " ---@type string
          width = width + vim.api.nvim_strwidth(text)
          hl_text = hl_text .. btn(txt(text, flag and hln_flag_enabled or hln_flag), fn)
        elseif item.type == "enum" then
          local flag = item.state:snapshot() ---@type boolean
          local text = " " .. flag .. " " ---@type string
          width = width + vim.api.nvim_strwidth(text)
          hl_text = hl_text .. btn(txt(text, hln_scope), fn)
        end
      end

      return hl_text, width
    end,
  }
  return component
end

return M

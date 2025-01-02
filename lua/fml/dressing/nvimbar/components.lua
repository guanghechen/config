local __module_name__ = "fml.dressing.nvimbar.components" ---@type string

local G = require("eve.builtin.G")
local env = require("eve.builtin.env")
local oxi = require("eve.builtin.oxi")
local path = require("eve.builtin.path")
local reporter = require("eve.builtin.reporter")
local fts = require("eve.constant.filetype")
local icons = require("eve.constant.icon")

local checks = require("eve.lib.checks")
local functional = require("eve.lib.functional")
local calc_fileicon = require("eve.lib.nvim").calc_fileicon
local Nvimbar = require("fml.ux.nvimbar")
local command = require("eve.command")
local state = require("eve.state")

local btn = Nvimbar.btn
local txt = Nvimbar.txt

---@class fml.dressing.nvimbar.components
local M = {}

---@param position                      fml.ux.nvimbar.Position
---@return fml.ux.nvimbar.IRawComponent
function M.bufs(position)
  local hln_buf = position .. "_buf" ---@type string
  local hln_buf_indicator = position .. "_buf_indicator" ---@type string
  local hln_buf_mod = position .. "_buf_mod" ---@type string
  local hln_buf_omitter = position .. "_buf_omitter" ---@type string
  local hln_buf_omitter_sep = position .. "_buf_omitter_sep" ---@type string
  local hln_buf_pinned = position .. "_buf_pinned" ---@type string
  local hln_buf_sep = position .. "_buf_sep" ---@type string
  local hln_buf_text = position .. "_buf_text" ---@type string

  local hln_bufc = position .. "_bufc" ---@type string
  local hln_bufc_mod = position .. "_bufc_mod" ---@type string
  local hln_bufc_pinned = position .. "_bufc_pinned" ---@type string
  local hln_bufc_text = position .. "_bufc_text" ---@type string
  local hln_bufc_error = position .. "_bufc_error" ---@type string
  local hln_bufc_warn = position .. "_bufc_warn" ---@type string
  local hln_bufc_hint = position .. "_bufc_hint" ---@type string
  local hln_bufc_info = position .. "_bufc_info" ---@type string

  ---@type string
  local fn_active_buf = G.register_anonymous_fn(function(bufnr)
    vim.cmd(command.definitions.buf.open.uuid .. " " .. tostring(bufnr))
  end) or ""

  ---@type string
  local fn_focus_left_buf = G.register_anonymous_fn(function()
    vim.cmd(command.definitions.buf.focus_left.uuid)
  end) or ""

  ---@type string
  local fn_focus_right_buf = G.register_anonymous_fn(function()
    vim.cmd(command.definitions.buf.focus_right.uuid)
  end) or ""

  ---@param bufnr                       integer
  ---@return string
  ---@return string
  ---@return string
  local function resolve_buf_info(bufnr)
    local buf_meta = state.buf.resolve(bufnr) ---@type eve.t.state.buf.meta.state|nil
    if buf_meta then
      return buf_meta.filename, buf_meta.fileicon, buf_meta.fileicon_hl
    end

    local filepath = vim.api.nvim_buf_get_name(bufnr) ---@type string
    local filename = path.basename(filepath) ---@type string
    local fileicon, fileicon_hl = calc_fileicon(filename) ---@type string, string
    return filename, fileicon, fileicon_hl
  end

  ---@param buf                           eve.t.state.tab.buf.state
  ---@param is_current                    boolean
  ---@param is_first                      boolean
  ---@return string
  ---@return string
  local function render_buf(buf, is_current, is_first)
    local bufnr = buf.bufnr ---@type integer
    if bufnr < 1 or not vim.api.nvim_buf_is_valid(bufnr) then
      return "", ""
    end

    local is_pinned = buf.pinned ---@type boolean
    local is_mod = vim.bo[bufnr].modified ---@type boolean

    local count_error = #vim.diagnostic.get(bufnr, { severity = vim.diagnostic.severity.ERROR }) ---@type integer
    local count_warn = #vim.diagnostic.get(bufnr, { severity = vim.diagnostic.severity.WARN }) ---@type integer
    local count_hint = #vim.diagnostic.get(bufnr, { severity = vim.diagnostic.severity.HINT }) ---@type integer
    local count_info = #vim.diagnostic.get(bufnr, { severity = vim.diagnostic.severity.INFO }) ---@type integer

    local text_diagnostic = "" ---@type string
    local slots = 0 ---@type integer
    if count_error > 0 then
      text_diagnostic = text_diagnostic .. " " .. icons.diagnostic.Error .. " " .. count_error
      slots = slots + 1
    end
    if count_warn > 0 then
      text_diagnostic = text_diagnostic .. " " .. icons.diagnostic.Warning .. " " .. count_warn
      slots = slots + 1
    end
    if count_hint > 0 and slots < 2 then
      text_diagnostic = text_diagnostic .. " " .. icons.diagnostic.Hint .. " " .. count_hint
      slots = slots + 1
    end
    if count_info > 0 and slots < 2 then
      text_diagnostic = text_diagnostic .. " " .. icons.diagnostic.Information .. " " .. count_info
      slots = slots + 1
    end

    local hl_title = hln_buf_text ---@type string
    if is_current then
      if count_error > 0 then
        hl_title = hln_bufc_error ---@type string
      elseif count_warn > 0 then
        hl_title = hln_bufc_warn ---@type string
      elseif count_hint > 0 then
        hl_title = hln_bufc_hint ---@type string
      elseif count_info > 0 then
        hl_title = hln_bufc_info ---@type string
      else
        hl_title = hln_bufc_text ---@type string
      end
    end

    local filename, fileicon, fileicon_hl = resolve_buf_info(bufnr)
    local text_indicator_or_sep = is_current and "▎" or (is_first and " " or "▏") ---@type string
    local text_icon = fileicon .. " " ---@type string
    local text_title = filename ---@type string
    local text_mod = is_mod and "  " or "  " ---@type string
    local text_pinned = is_mod and "  " or "  " ---@type string
    local text_status = is_pinned and text_pinned or text_mod ---@type string

    local hln_indicator_or_sep = is_current and hln_buf_indicator or hln_buf_sep ---@type string
    local hln_icon = (is_current and hln_bufc or hln_buf) .. "_" .. fileicon_hl ---@type string
    -- local hl_icon = (is_current and hln_bufc .. "_" .. meta.fileicon_hl) or hln_buf_title ---@type string
    local hln_mod = is_current and hln_bufc_mod or hln_buf_mod ---@type string
    local hln_pinned = is_current and hln_bufc_pinned or hln_buf_pinned ---@type string
    local hln_status = is_pinned and hln_pinned or hln_mod ---@type string

    local hl_text_indicator = txt(text_indicator_or_sep, hln_indicator_or_sep)
    local hl_text_icon = txt(text_icon, hln_icon)
    local hl_text_title = txt(text_title, hl_title)
    local hl_text_diagnostic = txt(text_diagnostic, hl_title) ---@type string
    local hl_text_status = txt(text_status, hln_status) ---@type string

    local text = text_indicator_or_sep .. text_icon .. text_title .. text_diagnostic .. text_status ---@type string
    local hl_text = hl_text_indicator .. hl_text_icon .. hl_text_title .. hl_text_diagnostic .. hl_text_status ---@type string
    return text, btn(hl_text, fn_active_buf, bufnr)
  end

  ---@type fml.ux.nvimbar.IRawComponent
  local component = {
    name = "bufs",
    atomic = false,
    ---@diagnostic disable-next-line: unused-local
    render = function(context, remain_width)
      local meta_tab = state.tab.resolve(context.tabnr) ---@type eve.state.tab.meta.state|nil
      if meta_tab == nil or #meta_tab.bufs < 1 then
        return "", "", false
      end

      local bufs = meta_tab.bufs ---@type eve.t.state.tab.buf.state[]
      local N = #bufs ---@type integer

      local winnr_cur = vim.api.nvim_get_current_win() ---@type integer
      local bufnr_cur = winnr_cur > 0 ---@type integer
          and vim.api.nvim_win_is_valid(winnr_cur)
          and vim.api.nvim_win_get_buf(winnr_cur)
        or 0

      local bufc, bufid_cur = meta_tab:find_buf(bufnr_cur)
      bufid_cur = bufid_cur or 1

      local text, hl_text = render_buf(bufs[bufid_cur], bufc ~= nil, bufid_cur == 1)
      remain_width = remain_width - vim.api.nvim_strwidth(text) ---@type integer
      if remain_width < 0 then
        return "", "", false
      end

      local left_remain_count = bufid_cur - 1 ---@type integer
      local right_remain_count = N - bufid_cur ---@type integer
      local left_omitter_width = bufid_cur == 1 and 0 or 7 ---@type integer
      local right_omitter_width = bufid_cur == N and 0 or 7 ---@type integer
      remain_width = remain_width - left_omitter_width - right_omitter_width ---@type integer

      ---! Render left bufs as many as possible.
      do
        for i = bufid_cur - 1, 1, -1 do
          local t, hl_t = render_buf(bufs[i], false, i == 1)
          local w = vim.api.nvim_strwidth(t) ---@type integer

          if i == 1 and remain_width + left_omitter_width >= w then
            text = t .. text
            hl_text = hl_t .. hl_text
            left_remain_count = 0
            remain_width = remain_width + left_omitter_width - w
            break
          end

          if remain_width < w then
            break
          end

          text = t .. text
          hl_text = hl_t .. hl_text
          remain_width = remain_width - w
          left_remain_count = left_remain_count - 1
        end
      end

      ---! Render right bufs as many as possible.
      do
        for i = bufid_cur + 1, N, 1 do
          local t, hl_t = render_buf(bufs[i], false, false)
          local w = vim.api.nvim_strwidth(t) ---@type integer

          if i == N and remain_width + right_omitter_width >= w then
            text = text .. t
            hl_text = hl_text .. hl_t
            right_remain_count = 0
            remain_width = remain_width + right_omitter_width - w
            break
          end

          if remain_width < w then
            break
          end

          text = text .. t
          hl_text = hl_text .. hl_t
          remain_width = remain_width - w
          right_remain_count = right_remain_count - 1
        end
      end

      ---! Render left omitter.
      if left_remain_count > 0 then
        local count = math.min(99, left_remain_count) ---@type integer
        local omitter_text = " " .. icons.ui.Left .. "  " .. tostring(count) .. " " ---@type string
        local omitter_text_hl = txt(omitter_text, hln_buf_omitter) ---@type string
        text = omitter_text .. text
        hl_text = btn(omitter_text_hl, fn_focus_left_buf) .. hl_text
      end

      ---! Render right omitter.
      if right_remain_count > 0 then
        local count = math.min(99, right_remain_count) ---@type integer
        local omitter_text = "▏" .. tostring(count) .. " " .. icons.ui.Right .. "  " ---@type string
        local omitter_text_hl = txt("▏", hln_buf_omitter_sep)
          .. txt(tostring(count) .. " " .. icons.ui.Right .. "  ", hln_buf_omitter) ---@type string
        text = text .. omitter_text
        hl_text = hl_text .. btn(omitter_text_hl, fn_focus_right_buf)
      end

      return text, hl_text, (left_remain_count < 1 and right_remain_count < 1)
    end,
  }
  return component
end

---@param position                      fml.ux.nvimbar.Position
---@return fml.ux.nvimbar.IRawComponent
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
    Inactive = icons.app.CopilotError,
    InProgress = icons.app.Copilot,
    Normal = icons.app.Copilot,
    Warning = icons.app.CopilotWarn,
  }

  local last_status = nil ---@type string|nil

  ---@type fml.ux.nvimbar.IRawComponent
  local component = {
    name = "copilot",
    atomic = true,
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
      local icon = status_icon_map[copilot_status] or icons.app.Copilot ---@type string
      local hln_icon = (copilot_status == nil or #copilot_status < 1) and hln_text
        or (hln_copilot .. "_" .. copilot_status) ---@type string

      local text = icon .. " " ---@type string
      local hl_text = btn(txt(text, hln_icon), fn_show_message)
      return text, hl_text, true
    end,
  }
  return component
end

---@param position                      fml.ux.nvimbar.Position
---@return fml.ux.nvimbar.IRawComponent
function M.cwd(position)
  local hln_cwd = position .. "_cwd" ---@type string

  ---@type fml.ux.nvimbar.IRawComponent
  local component = {
    name = "cwd",
    atomic = true,
    will_change = function(context, prev_context)
      return prev_context == nil or context.cwd ~= prev_context.cwd
    end,
    render = function(context)
      local cwd_name = path.basename(context.cwd) ---@type string

      local text = " " .. icons.ft.FolderRootOpened .. " " .. cwd_name .. " " ---@type string
      local hl_text = txt(text, hln_cwd) ---@type string
      return text, hl_text, true
    end,
  }
  return component
end

---@param position                      fml.ux.nvimbar.Position
---@return fml.ux.nvimbar.IRawComponent
function M.debug_render_count(position)
  local hln_debug_render_count = position .. "_debug_render_count" ---@type string
  local count = 0 ---@type integer

  ---@type fml.ux.nvimbar.IRawComponent
  local component = {
    name = "debug_render_count",
    atomic = true,
    condition = function()
      local devmode = state.flight.devmode:snapshot() ---@type boolean
      return devmode
    end,
    render = function()
      count = count + 1

      local text = "  " .. functional.pad_start(tostring(count % 100000), 5, "0") .. " " ---@type string
      local hl_text = txt(text, hln_debug_render_count) ---@type string
      return text, hl_text, true
    end,
  }
  return component
end

---@param position                      fml.ux.nvimbar.Position
---@return fml.ux.nvimbar.IRawComponent
function M.devmode(position)
  local hln_devmode = position .. "_devmode" ---@type string

  ---@type fml.ux.nvimbar.IRawComponent
  local component = {
    name = "devmode",
    atomic = true,
    condition = function()
      local devmode = state.flight.devmode:snapshot() ---@type boolean
      return devmode
    end,
    render = function()
      local text = "  devmode " ---@type string
      local hl_text = txt(text, hln_devmode) ---@type string
      return text, hl_text, true
    end,
  }
  return component
end

---@param position                      fml.ux.nvimbar.Position
---@return fml.ux.nvimbar.IRawComponent
function M.diagnostics(position)
  local hln_diagnostics_error = position .. "_diagnostics_error" ---@type string
  local hln_diagnostics_warn = position .. "_diagnostics_warn" ---@type string
  local hln_diagnostics_hint = position .. "_diagnostics_hint" ---@type string
  local hln_diagnostics_info = position .. "_diagnostics_info" ---@type string

  ---@type fml.ux.nvimbar.IRawComponent
  local component = {
    name = "diagnostics",
    atomic = true,
    condition = function()
      return not not rawget(vim, "lsp")
    end,
    render = function(context)
      local count_error = #vim.diagnostic.get(context.bufnr, { severity = vim.diagnostic.severity.ERROR })
      local text_count_error = count_error > 0 and icons.diagnostic.Error .. " " .. count_error .. " " or ""

      local count_warn = #vim.diagnostic.get(context.bufnr, { severity = vim.diagnostic.severity.WARN })
      local text_count_warn = count_warn > 0 and icons.diagnostic.Warning .. " " .. count_warn .. " " or ""

      local count_hint = #vim.diagnostic.get(context.bufnr, { severity = vim.diagnostic.severity.HINT })
      local text_count_hint = count_hint > 0 and icons.diagnostic.Hint .. " " .. count_hint .. " " or ""

      local count_info = #vim.diagnostic.get(context.bufnr, { severity = vim.diagnostic.severity.INFO })
      local text_count_info = count_info > 0 and icons.diagnostic.Information .. " " .. count_info .. " " or ""

      local text = text_count_error .. text_count_warn .. text_count_hint .. text_count_info
      local text_hl = txt(text_count_error, hln_diagnostics_error)
        .. txt(text_count_warn, hln_diagnostics_warn)
        .. txt(text_count_hint, hln_diagnostics_hint)
        .. txt(text_count_info, hln_diagnostics_info)
      return text, text_hl, true
    end,
  }
  return component
end

---@param position                      fml.ux.nvimbar.Position
---@return fml.ux.nvimbar.IRawComponent
function M.diffview(position)
  local hln_sidebar_blank = position .. "_sidebar_blank" ---@type string
  local hln_sidebar_split = position .. "_sidebar_split" ---@type string
  local hln_sidebar_text = position .. "_sidebar_text" ---@type string

  ---@return integer
  local function get_pane_width()
    local winnrs = vim.api.nvim_tabpage_list_wins(0) ---@type integer[]
    for _, winnr in ipairs(winnrs) do
      local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
      if vim.bo[bufnr].filetype == fts.DIFFVIEW_FILES then
        if not checks.is_win_floating(winnr) then
          return vim.api.nvim_win_get_width(winnr)
        end
      end
    end
    return 0
  end

  ---@type fml.ux.nvimbar.IRawComponent
  local component = {
    name = "diffview",
    atomic = true,
    ---@diagnostic disable-next-line: unused-local
    render = function(context, remain_width)
      local width = math.min(remain_width, get_pane_width()) ---@type integer
      if width < 1 then
        return "", "", true
      end

      if width < 20 then
        local text = string.rep(" ", width) ---@type string
        local hl_text = txt(text, hln_sidebar_blank)
        return text, hl_text, true
      end

      local title = icons.git.Git .. " Git Diffview" ---@type string
      local title_width = vim.api.nvim_strwidth(title) ---@type integer
      local width_remain = width - title_width ---@type integer
      local left_width = math.floor(width_remain / 2)
      local right_width = width_remain - left_width - 1
      local left_blank = string.rep(" ", left_width)
      local right_blank = string.rep(" ", right_width)
      local right_split = " " -- "│"

      local text = left_blank .. title .. right_blank .. right_split ---@type string
      local hl_text = txt(left_blank, hln_sidebar_blank)
        .. txt(title, hln_sidebar_text)
        .. txt(right_blank, hln_sidebar_blank)
        .. txt(right_split, hln_sidebar_split)
      return text, hl_text, true
    end,
  }
  return component
end

---@param position                      fml.ux.nvimbar.Position
---@return fml.ux.nvimbar.IRawComponent
function M.dirpath(position)
  local hln_text = position .. "_dirpath_text" ---@type string

  -- local icon = icons.ft.Folder .. " " ---@type string
  -- local hln_icon = position .. "_dirpath_icon" ---@type string
  -- local hl_icon = txt(icon, hln_icon) ---@type string

  -- local sep = " " .. env.PATH_SEP .. " " ---@type string
  local sep = icons.fillchars.foldclose .. " " ---@type string
  local hln_sep = position .. "_dirpath_sep" ---@type string
  local hl_text_sep = txt(sep, hln_sep) ---@type string

  ---@type fml.ux.nvimbar.IRawComponent
  local component = {
    name = "dirpath",
    atomic = true,
    condition = function(context)
      local winnr_cur = vim.api.nvim_get_current_win() ---@type integer
      return context.winnr == winnr_cur
    end,
    will_change = function(context, prev_context)
      return prev_context == nil or context.filepath ~= prev_context.filepath
    end,
    render = function(context)
      local winnr = context.winnr ---@type integer
      local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
      local meta = state.buf.resolve(bufnr) ---@type eve.t.state.buf.meta.state|nil
      if meta == nil then
        return "", "", true
      end

      local text = "" ---@type string
      local hl_text = "" ---@type string
      local N = #meta.relpath_pieces - 1 ---@type integer
      for i = 1, N, 1 do
        local piece = meta.relpath_pieces[i] ---@type string
        local hl_text_piece = txt(piece, hln_text) ---@type string

        text = text .. piece .. sep
        hl_text = hl_text .. hl_text_piece .. hl_text_sep
      end
      return text, hl_text, true
    end,
  }
  return component
end

---@param position                      fml.ux.nvimbar.Position
---@return fml.ux.nvimbar.IRawComponent
function M.dirpath_prominent(position)
  local hln_icon = position .. "_dirpath_prominent_icon" ---@type string
  local hln_text = position .. "_dirpath_prominent_text" ---@type string

  local icon = " " .. icons.os.current .. " " ---@type string
  local sep = env.PATH_SEP ---@type string
  local hl_icon = txt(icon, hln_icon) ---@type string

  local width_icon = vim.api.nvim_strwidth(icon) ---@type integer
  local width_sep = vim.api.nvim_strwidth(sep) ---@type integer

  ---@type fml.ux.nvimbar.IRawComponent
  local component = {
    name = "dirpath_prominent",
    atomic = false,
    condition = function(context)
      local winnr_cur = vim.api.nvim_get_current_win() ---@type integer
      return context.winnr == winnr_cur
    end,
    will_change = function(context, prev_context)
      return prev_context == nil or context.filepath ~= prev_context.filepath
    end,
    render = function(context, remain_width)
      local winnr = context.winnr ---@type integer
      local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
      local meta = state.buf.resolve(bufnr) ---@type eve.t.state.buf.meta.state|nil
      if meta == nil then
        return "", "", false
      end

      local cwd_name = path.basename(context.cwd) ---@type string
      local N = #meta.relpath_pieces - 1 ---@type integer
      if N < 1 then
        local text = cwd_name .. " " ---@type string
        local hl_text = hl_icon .. txt(text, hln_text) ---@type string
        text = icon .. text
        return text, hl_text, true
      end

      local is_absolute = meta.relpath_pieces[1] == "" ---@type boolean
      local left_text = is_absolute and "" or cwd_name ---@type string

      local remain_count = is_absolute and N - 1 or N ---@type integer
      remain_width = remain_width - vim.api.nvim_strwidth(left_text) - width_icon - width_sep - N
      if remain_width < 1 then
        local text = cwd_name .. " " ---@type string
        local hl_text = hl_icon .. txt(text, hln_text) ---@type string
        text = icon .. text
        return text, hl_text, false
      end

      local right_text = "" ---@type string
      local _start_index = is_absolute and 2 or 1 ---@type integer
      for i = N, _start_index, -1 do
        local piece = meta.relpath_pieces[i] ---@type string
        local w = vim.api.nvim_strwidth(piece) + width_sep ---@type integer
        if remain_width <= w then
          break
        end

        if i == N then
          right_text = piece .. " "
        else
          right_text = piece .. sep .. right_text
        end

        remain_width = remain_width - w
        remain_count = remain_count - 1
      end

      if remain_count > 0 then
        local omitter = string.rep(".", remain_count)
        right_text = omitter .. sep .. right_text
      end

      local text = left_text .. sep .. right_text ---@type string
      local hl_text = hl_icon .. txt(text, hln_text)
      text = icon .. text
      return text, hl_text, remain_count < 1
    end,
  }
  return component
end

---@param position                      fml.ux.nvimbar.Position
---@return fml.ux.nvimbar.IRawComponent
function M.fileformat(position)
  local hln_text = position .. "_text" ---@type string

  local fileformat_text_map = {
    dos = "CRLF",
    mac = "CR",
    unix = "LF",
  }

  ---@type fml.ux.nvimbar.IRawComponent
  local component = {
    name = "fileformat",
    atomic = true,
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
      return text, hl_text, true
    end,
  }
  return component
end

---@param position                      fml.ux.nvimbar.Position
---@return fml.ux.nvimbar.IRawComponent
function M.filename(position)
  local hln_filename = position .. "_filename" ---@type string
  local hln_filename_text = position .. "_filename_text" ---@type string
  local filename_text_cur = position .. "_filename_text_cur" ---@type string
  local last_winnr = -1 ---@type integer

  ---@type fml.ux.nvimbar.IRawComponent
  local component = {
    name = "filename",
    atomic = true,
    will_change = function(context, prev_context)
      if prev_context == nil or context.filename ~= prev_context.filename then
        return true
      end
      local winnr_cur = vim.api.nvim_get_current_win() ---@type integer
      return winnr_cur ~= last_winnr
    end,
    render = function(context)
      local winnr_cur = vim.api.nvim_get_current_win() ---@type integer
      local is_win_cur = context.winnr == winnr_cur ---@type boolean
      last_winnr = winnr_cur ---@type integer

      local bufnr = vim.api.nvim_win_get_buf(context.winnr) ---@type integer
      local meta_buf = state.buf.resolve(bufnr) ---@type eve.t.state.buf.meta.state|nil
      if meta_buf == nil then
        local text = vim.api.nvim_buf_get_name(bufnr) ---@type string
        local hl_text = txt(text, hln_filename_text) ---@type string
        return text, hl_text, true
      end

      local text_icon = meta_buf.fileicon .. " " ---@type string
      local text_filename = is_win_cur and meta_buf.filename or meta_buf.relpath ---@type string
      local hl_text_icon = txt(text_icon, hln_filename .. "_" .. meta_buf.fileicon_hl) ---@type string
      local hl_text_title = txt(text_filename, is_win_cur and filename_text_cur or hln_filename_text) ---@type string

      local text = text_icon .. text_filename ---@type string
      local hl_text = hl_text_icon .. hl_text_title ---@type string
      return text, hl_text, true
    end,
  }
  return component
end

---@param position                      fml.ux.nvimbar.Position
---@return fml.ux.nvimbar.IRawComponent
function M.filepath(position)
  local hln_text = position .. "_text" ---@type string

  ---@type fml.ux.nvimbar.IRawComponent
  local component = {
    name = "filepath",
    atomic = true,
    condition = function(context)
      return #context.filepath > 0 and context.filepath ~= "."
    end,
    will_change = function(context, prev_context)
      return prev_context == nil or context.filepath ~= prev_context.filepath
    end,
    render = function(context)
      local bufnr = vim.api.nvim_win_get_buf(context.winnr) ---@type integer
      local meta_buf = state.buf.resolve(bufnr) ---@type eve.t.state.buf.meta.state|nil
      local filepath = meta_buf and meta_buf.relpath or context.filepath

      local text = context.fileicon .. " " .. filepath ---@type string
      local hl_text = txt(text, hln_text)
      return text, hl_text, true
    end,
  }
  return component
end

---@param position                      fml.ux.nvimbar.Position
---@return fml.ux.nvimbar.IRawComponent
function M.filesize(position)
  local hln_text = position .. "_text" ---@type string

  ---@type fml.ux.nvimbar.IRawComponent
  local component = {
    name = "filesize",
    atomic = true,
    will_change = function(context, prev_context)
      return prev_context == nil or context.filepath ~= prev_context.filepath or context.mode ~= prev_context.mode
    end,
    render = function(context)
      local text = oxi.get_filesize(context.filepath) or "" ---@type string
      local hl_text = txt(text, hln_text)
      return text, hl_text, true
    end,
  }
  return component
end

---@param position                      fml.ux.nvimbar.Position
---@return fml.ux.nvimbar.IRawComponent
function M.filestatus(position)
  local hln_text = position .. "_text" ---@type string

  ---@param bufnr                       integer
  ---@return string
  local function get_filestatus(bufnr)
    local gitsigns_head = vim.b[bufnr].gitsigns_head
    local gitsigns_git_status = vim.b[bufnr].gitsigns_git_status
    local gitsigns_status_dict = vim.b[bufnr].gitsigns_status_dict

    local text = "" ---@type string
    if gitsigns_head and gitsigns_status_dict and not gitsigns_git_status then
      if gitsigns_status_dict.added and gitsigns_status_dict.added > 0 then
        text = text .. " " .. icons.git.Add .. " " .. gitsigns_status_dict.added ---@type string
      end
      if gitsigns_status_dict.changed and gitsigns_status_dict.changed > 0 then
        text = text .. " " .. icons.git.Mod_alt .. " " .. gitsigns_status_dict.changed ---@type string
      end
      if gitsigns_status_dict.removed and gitsigns_status_dict.removed > 0 then
        text = text .. " " .. icons.git.Remove .. " " .. gitsigns_status_dict.removed ---@type string
      end
    end
    return #text > 0 and text:sub(1) or ""
  end

  ---@type fml.ux.nvimbar.IRawComponent
  local component = {
    name = "filestatus",
    atomic = true,
    render = function(context)
      local text = get_filestatus(context.bufnr) ---@type string
      if #text < 1 then
        return "", "", true
      end

      local hl_text = txt(text, hln_text) ---@type string
      return text, hl_text, true
    end,
  }
  return component
end

---@param position                      fml.ux.nvimbar.Position
---@return fml.ux.nvimbar.IRawComponent
function M.filetype(position)
  local hln_text = position .. "_text" ---@type string

  ---@type fml.ux.nvimbar.IRawComponent
  local component = {
    name = "filetype",
    atomic = true,
    will_change = function(context, prev_context)
      return prev_context == nil or context.filetype ~= prev_context.filetype
    end,
    condition = function(context)
      return context.filetype and #context.filetype > 0
    end,
    render = function(context)
      local text = context.fileicon .. " " .. context.filetype ---@type string
      local hl_text = txt(text, hln_text) ---@type string
      return text, hl_text, true
    end,
  }
  return component
end

---@param position                      fml.ux.nvimbar.Position
---@return fml.ux.nvimbar.IRawComponent
function M.focused_indicator(position)
  local hln_text = position .. "_focused_indicator" ---@type string

  ---@type fml.ux.nvimbar.IRawComponent
  local component = {
    name = "filetype",
    atomic = true,
    will_change = function(context, prev_context)
      return prev_context == nil or context.filetype ~= prev_context.filetype
    end,
    condition = function(context)
      local winnr_cur = vim.api.nvim_get_current_win() ---@type integer
      return context.winnr == winnr_cur
    end,
    render = function(context)
      local text = " " .. context.fileicon .. " " .. context.filetype .. " " ---@type string
      local hl_text = txt(text, hln_text) ---@type string
      return text, hl_text, true
    end,
  }
  return component
end

---@param position                      fml.ux.nvimbar.Position
---@return fml.ux.nvimbar.IRawComponent
function M.git(position)
  local hln_text = position .. "_text" ---@type string

  ---@type fml.ux.nvimbar.IRawComponent
  local component = {
    name = "git",
    atomic = true,
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
      return text, hl_text, true
    end,
  }
  return component
end

---@param position                      fml.ux.nvimbar.Position
---@return fml.ux.nvimbar.IRawComponent
function M.lsp(position)
  local hln_text = position .. "_text" ---@type string

  ---@return string
  local function get_text()
    local bufnr = state.tab.get_current_bufnr() ---@type integer
    if bufnr > 0 and not vim.api.nvim_buf_is_valid(bufnr) then
      return ""
    end

    local has_client = false ---@type boolean
    local client_names = "" ---@type string
    for _, client in ipairs(vim.lsp.get_clients({ bufnr = bufnr })) do
      if client.attached_buffers[bufnr] and client.name ~= "null-ls" and client.name ~= "copilot" then
        if has_client then
          client_names = client_names .. "|" .. client.name
        else
          has_client = true
          client_names = client.name
        end
      end
    end

    if not has_client then
      return ""
    end
    return "  " .. client_names
  end

  ---@type fml.ux.nvimbar.IRawComponent
  local component = {
    name = "lsp",
    atomic = true,
    render = function()
      local text = get_text() ---@type string
      local hl_text = txt(text, hln_text) ---@type string
      return text, hl_text, true
    end,
  }
  return component
end

---@param position                      fml.ux.nvimbar.Position
---@return fml.ux.nvimbar.IRawComponent
function M.lsp_message(position)
  local hln_text = position .. "_text" ---@type string

  ---@type fml.ux.nvimbar.IRawComponent
  local component = {
    name = "lsp_message",
    atomic = true,
    condition = function()
      return not not rawget(vim, "lsp") and #state.status.lsp_msg:snapshot() > 0
    end,
    render = function()
      local text = state.status.lsp_msg:snapshot() ---@type string
      local hl_text = txt(text, hln_text) ---@type string
      return text, hl_text, true
    end,
  }
  return component
end

---@param position                      fml.ux.nvimbar.Position
---@return fml.ux.nvimbar.IRawComponent
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

  ---@type fml.ux.nvimbar.IRawComponent
  local component = {
    name = "lsp_symbols",
    atomic = false,
    ---@diagnostic disable-next-line: unused-local
    render = function(context, remain_width)
      local winnr = context.winnr ---@type integer
      local meta = state.win.resolve(winnr) ---@type eve.t.state.win.meta.state|nil
      if meta == nil then
        return "", "", false
      end

      local symbols = meta.lsp_symbols ---@type eve.t.state.buf.lsp.ISymbol[]|nil
      if symbols == nil or #symbols < 1 then
        return "", "", false
      end

      local text = "" ---@type string
      local hl_text = "" ---@type string

      local has_remain = false ---@type boolean
      for _, symbol in ipairs(symbols) do
        local title = symbol.name or "" ---@type string
        local icon = (icons.kind[symbol.kind] or "") .. " " ---@type string
        local width = width_sep + vim.api.nvim_strwidth(icon .. title) ---@type integer
        if width > remain_width then
          has_remain = true
          break
        end

        remain_width = remain_width - width
        local hln_icon = symbol.kind and hln_lsp_icon .. "_" .. symbol.kind or hln_lsp_icon ---@type string

        local lsp_piece = sep .. icon .. title ---@type string
        local hl_lsp_piece = txt(sep, hln_lsp_sep) .. txt(icon, hln_icon) .. txt(title, hln_lsp_text) ---@type string

        text = text .. lsp_piece
        hl_text = hl_text .. btn(hl_lsp_piece, fn_goto_lsp_pos, { winnr, symbol.row, symbol.col })
      end
      return text, hl_text, not has_remain
    end,
  }
  return component
end

---@param position                      fml.ux.nvimbar.Position
---@return fml.ux.nvimbar.IRawComponent
function M.mode(position)
  local hln_text = position .. "_text" ---@type string

  ---@type fml.ux.nvimbar.IRawComponent
  local component = {
    name = "mode",
    atomic = true,
    tight = true,
    will_change = function(context, prev_context)
      return prev_context == nil or context.mode ~= prev_context.mode
    end,
    render = function(context)
      local text = "  " .. context.mode_name .. " " ---@type string
      local hl_text = txt(text, hln_text .. "_" .. context.mode) ---@type string
      return text, hl_text, true
    end,
  }
  return component
end

---@param position                      fml.ux.nvimbar.Position
---@return fml.ux.nvimbar.IRawComponent
function M.neotree(position)
  local hln_sidebar_blank = position .. "_sidebar_blank" ---@type string
  local hln_sidebar_split = position .. "_sidebar_split" ---@type string
  local hln_sidebar_text = position .. "_sidebar_text" ---@type string

  ---@return integer
  local function get_pane_width()
    local winnrs = vim.api.nvim_tabpage_list_wins(0) ---@type integer[]
    for _, winnr in ipairs(winnrs) do
      local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
      if vim.bo[bufnr].filetype == fts.NEOTREE then
        if not checks.is_win_floating(winnr) then
          return vim.api.nvim_win_get_width(winnr)
        end
      end
    end
    return 0
  end

  ---@type fml.ux.nvimbar.IRawComponent
  local component = {
    name = "neotree",
    atomic = true,
    ---@diagnostic disable-next-line: unused-local
    render = function(context, remain_width)
      local width = math.min(remain_width, get_pane_width()) ---@type integer
      if width < 1 then
        return "", "", true
      end

      if width < 20 then
        local text = string.rep(" ", width) ---@type string
        local hl_text = txt(text, hln_sidebar_blank)
        return text, hl_text, true
      end

      local cwd_name = context.cwd:match("([^/\\]+)[/\\]*$") or context.cwd ---@type string
      local title = icons.ft.FolderRootOpened .. " " .. cwd_name ---@type string
      local title_width = vim.api.nvim_strwidth(title) ---@type integer
      local width_remain = width - title_width ---@type integer
      local left_width = math.floor(width_remain / 2) ---@type integer
      local right_width = width_remain - left_width - 1 ---@type integer
      local left_blank = string.rep(" ", left_width) ---@type string
      local right_blank = string.rep(" ", right_width) ---@type string
      local right_split = " " ---@type string -- "│"

      local text = left_blank .. title .. right_blank .. right_split ---@type string
      local hl_text = txt(left_blank, hln_sidebar_blank)
        .. txt(title, hln_sidebar_text)
        .. txt(right_blank, hln_sidebar_blank)
        .. txt(right_split, hln_sidebar_split)
      return text, hl_text, true
    end,
  }
  return component
end

---@param position                      fml.ux.nvimbar.Position
---@return fml.ux.nvimbar.IRawComponent
function M.noice_command(position)
  local hln_noice_command = position .. "_noice_command" ---@type string

  ---@type fml.ux.nvimbar.IRawComponent
  local component = {
    name = "noice_command",
    atomic = true,
    condition = function()
      return not not package.loaded["noice"]
    end,
    render = function()
      local noice_status = require("noice").api.status
      local text = noice_status.command.get() or "" ---@type string
      if text == nil and #text == 0 then
        return "", "", true
      end

      local hl_text = txt(text, hln_noice_command)
      return text, hl_text, true
    end,
  }
  return component
end

---@param position                      fml.ux.nvimbar.Position
---@return fml.ux.nvimbar.IRawComponent
function M.noice_mode(position)
  local hln_noice_mode = position .. "_noice_mode" ---@type string

  ---@type fml.ux.nvimbar.IRawComponent
  local component = {
    name = "noice_mode",
    atomic = true,
    condition = function()
      return not not package.loaded["noice"]
    end,
    render = function()
      local noice_status = require("noice").api.status
      local text = noice_status.mode.get() or "" ---@type string
      if text == nil or #text == 0 then
        return "", "", true
      end

      local hl_text = txt(text, hln_noice_mode) ---@type string
      return text, hl_text, true
    end,
  }
  return component
end

---@param position                      fml.ux.nvimbar.Position
---@return fml.ux.nvimbar.IRawComponent
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
      local text = functional.pad_start(tostring(math.floor(100 * row / total_lines)), 2, " ") .. "%" ---@type string
      return row, col, text, hln_pos
    end
  end

  ---@type fml.ux.nvimbar.IRawComponent
  local component = {
    name = "pos",
    atomic = true,
    render = function()
      local row, col, percentage, hl_pos = calc_row_percentage() ---@type integer, integer, string
      local text_anchor = ""
        .. functional.pad_start(tostring(row), 4, " ")
        .. "·"
        .. functional.pad_end(tostring(col), 3, " ")
        .. " " ---@type string
      local text_pos = " " .. percentage .. " " ---@type string

      local text = text_anchor .. text_pos ---@type string
      local hl_text = txt(text_anchor, hln_text) .. txt(text_pos, hl_pos) ---@type string
      return text, hl_text, true
    end,
  }
  return component
end

---@param position                      fml.ux.nvimbar.Position
---@return fml.ux.nvimbar.IRawComponent
function M.readonly(position)
  local hln_readonly = position .. "_readonly" ---@type string

  ---@type fml.ux.nvimbar.IRawComponent
  local component = {
    name = "readonly",
    atomic = true,
    condition = function()
      return vim.bo.readonly
    end,
    render = function()
      local text = icons.ui.Lock .. " [RO]" ---@type string
      local hl_text = txt(text, hln_readonly) ---@type string
      return text, hl_text, true
    end,
  }
  return component
end

---@param position                      fml.ux.nvimbar.Position
---@return fml.ux.nvimbar.IRawComponent
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
    vim.cmd(command.definitions.tab.focus.uuid .. " " .. tostring(tabid))
  end) or ""

  ---@type string
  local fn_toggle_tabs_folded = G.register_anonymous_fn(function()
    folded = not folded
    dirty = true
    state.status.dirtier_tabline:mark_dirty()
  end) or ""

  ---@type fml.ux.nvimbar.IRawComponent
  local component = {
    name = "tabs",
    atomic = true,
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
        return "", "", true
      end

      if folded then
        local text = " 󰅁 "
        local hl_text = txt(text, hln_toggle)
        hl_text = btn(hl_text, fn_toggle_tabs_folded)
        return text, hl_text, true
      end

      local text = " 󰅂 " ---@type string
      local hl_text = txt(text, hln_toggle)
      hl_text = btn(hl_text, fn_toggle_tabs_folded)

      local tabnrs = vim.api.nvim_list_tabpages() ---@type integer[]
      for tabid = 1, last_tab_count, 1 do
        local hlname = last_tab_cur == tabid and hln_tab_item_cur or hln_tab_item
        local text_btn = " " .. tabid .. " "
        local hl_text_btn = txt(text_btn, hlname)

        text = text .. text_btn
        hl_text = hl_text .. btn(hl_text_btn, fn_active_tab, tabnrs[tabid])
      end
      return text, hl_text, true
    end,
  }
  return component
end

---@param position                      fml.ux.nvimbar.Position
---@return fml.ux.nvimbar.IRawComponent
function M.username(position)
  local hln_username = position .. "_username" ---@type string

  ---@type fml.ux.nvimbar.IRawComponent
  local component = {
    name = "username",
    atomic = true,
    ---@diagnostic disable-next-line: unused-local
    will_change = function(context, prev_context)
      return prev_context == nil
    end,
    render = function()
      local icon = icons.os.current ---@type string
      local text = " " .. icon .. " " .. env.USERNAME .. " " ---@type string
      local hl_text = txt(text, hln_username) ---@type string
      return text, hl_text, true
    end,
  }
  return component
end

---@param position                      fml.ux.nvimbar.Position
---@return fml.ux.nvimbar.IRawComponent
function M.widget(position)
  local hln_flag = position .. "_flag" ---@type string
  local hln_flag_enabled = position .. "_flag_enabled" ---@type string
  local hln_scope = position .. "_flag_scope" ---@type string

  ---@type fml.ux.nvimbar.IRawComponent
  local component = {
    name = "widget",
    atomic = true,
    condition = function()
      local widget = state.widget.get_current_widget() ---@type eve.t.ux.IWidget|nil
      return widget ~= nil and widget:status() == "visible"
    end,
    render = function()
      local widget = state.widget.get_current_widget() ---@type eve.t.ux.IWidget|nil
      if widget == nil then
        return "", "", true
      end

      local items = widget.statusline_items ---@type eve.t.ux.widget.IStatuslineItem[]|nil
      if items == nil or #items < 1 then
        return "", "", true
      end

      local text = "" ---@type string
      local hl_text = "" ---@type string
      for _, item in ipairs(items) do
        local fn = item.callback_fn ---@type string
        if item.type == "flag" then
          local flag = item.state:snapshot() ---@type boolean
          local text_flag = " " .. item.symbol .. " " ---@type string
          text = text .. text_flag
          hl_text = hl_text .. btn(txt(text_flag, flag and hln_flag_enabled or hln_flag), fn)
        elseif item.type == "enum" then
          local flag = item.state:snapshot() ---@type boolean
          local text_flag = " " .. flag .. " " ---@type string
          text = text .. text_flag
          hl_text = hl_text .. btn(txt(text_flag, hln_scope), fn)
        end
      end
      return text, hl_text, true
    end,
  }
  return component
end

return M

local btn = eve.nvim.btn
local txt = eve.nvim.txt

---@type string
local fn_active_buf = eve.G.register_anonymous_fn(function(bufnr)
  vim.cmd(eve.command.definitions.buf.open.uuid .. " " .. tostring(bufnr))
end) or ""

---@type string
local fn_focus_left_buf = eve.G.register_anonymous_fn(function()
  vim.cmd(eve.command.definitions.buf.focus_left.uuid)
end) or ""

---@type string
local fn_focus_right_buf = eve.G.register_anonymous_fn(function()
  vim.cmd(eve.command.definitions.buf.focus_right.uuid)
end) or ""

---@class eve.ux.nvimbar.component.buf
local M = {}

---@param position                      eve.ux.nvimbar.PositionEnum
---@return eve.ux.nvimbar.IRawComponent
function M.bufs(position)
  local hln_buf = position .. "_buf" ---@type string
  local hln_buf_indicator = position .. "_buf_indicator" ---@type string
  local hln_buf_order = position .. "_buf_order" ---@type string
  local hln_buf_mod = position .. "_buf_mod" ---@type string
  local hln_buf_omitter = position .. "_buf_omitter" ---@type string
  local hln_buf_omitter_sep = position .. "_buf_omitter_sep" ---@type string
  local hln_buf_pinned = position .. "_buf_pinned" ---@type string
  local hln_buf_text = position .. "_buf_text" ---@type string

  local hln_bufc = position .. "_bufc" ---@type string
  local hln_bufc_indicator = position .. "_bufc_indicator" ---@type string
  local hln_bufc_order = position .. "_bufc_order" ---@type string
  local hln_bufc_mod = position .. "_bufc_mod" ---@type string
  local hln_bufc_pinned = position .. "_bufc_pinned" ---@type string
  local hln_bufc_text = position .. "_bufc_text" ---@type string
  local hln_bufc_error = position .. "_bufc_error" ---@type string
  local hln_bufc_warn = position .. "_bufc_warn" ---@type string
  local hln_bufc_hint = position .. "_bufc_hint" ---@type string
  local hln_bufc_info = position .. "_bufc_info" ---@type string

  ---@param buf                         eve.builtin.tab.IBufItem
  ---@param index                       integer
  ---@param total                       integer
  ---@return string
  ---@return string
  local function render_bufc(buf, index, total)
    local bufnr = buf.bufnr ---@type integer
    local meta = eve.buf.resolve(bufnr, false) ---@type eve.builtin.buf.IMeta|nil
    if meta == nil then
      return "", ""
    end

    local is_pinned = buf.pinned ---@type boolean
    local is_mod = vim.bo[bufnr].modified ---@type boolean

    local count_error = #vim.diagnostic.get(bufnr, { severity = vim.diagnostic.severity.ERROR }) ---@type integer
    local count_warn = #vim.diagnostic.get(bufnr, { severity = vim.diagnostic.severity.WARN }) ---@type integer
    local count_hint = #vim.diagnostic.get(bufnr, { severity = vim.diagnostic.severity.HINT }) ---@type integer
    local count_info = #vim.diagnostic.get(bufnr, { severity = vim.diagnostic.severity.INFO }) ---@type integer

    local text_diagnostic = "" ---@type string
    local hl_text_diagnostic = "" ---@type string

    local slots = 0 ---@type integer
    if count_error > 0 then
      local text = " " .. eve.icon.diagnostic.Error .. " " .. count_error ---@type string
      text_diagnostic = text_diagnostic .. text ---@type string
      hl_text_diagnostic = hl_text_diagnostic .. txt(text, hln_bufc_error) ---@type string
      slots = slots + 1
    end
    if count_warn > 0 then
      local text = " " .. eve.icon.diagnostic.Warning .. " " .. count_warn ---@type string
      text_diagnostic = text_diagnostic .. text
      hl_text_diagnostic = hl_text_diagnostic .. txt(text, hln_bufc_warn) ---@type string
      slots = slots + 1
    end
    if count_hint > 0 and slots < 2 then
      local text = " " .. eve.icon.diagnostic.Hint .. " " .. count_hint ---@type string
      text_diagnostic = text_diagnostic .. text ---@type string
      hl_text_diagnostic = hl_text_diagnostic .. txt(text, hln_bufc_hint)
      slots = slots + 1
    end
    if count_info > 0 and slots < 2 then
      local text = " " .. eve.icon.diagnostic.Information .. " " .. count_info ---@type string
      text_diagnostic = text_diagnostic .. text ---@type string
      hl_text_diagnostic = hl_text_diagnostic .. txt(text, hln_bufc_info)
      slots = slots + 1
    end

    local filename = meta.filename ---@type string
    local fileicon = meta.fileicon ---@type string
    local fileicon_hln = meta.fileicon_hln ---@type string
    local text_indicator = "▎" ---@type string
    local text_order = total < 2 and "" or (eve.icon.todigit_subscript(index) .. ".") ---@type string
    local text_icon = fileicon .. " " ---@type string
    local text_title = filename ---@type string
    local text_mod = is_mod and "  " or "  " ---@type string
    local text_pinned = is_mod and "  " or "  " ---@type string
    local text_status = is_pinned and text_pinned or text_mod ---@type string

    local hln_icon = hln_bufc .. "_" .. fileicon_hln ---@type string
    local hln_status = is_pinned and hln_bufc_pinned or hln_bufc_mod ---@type string

    local hl_text_indicator = txt(text_indicator, hln_bufc_indicator)
    local hl_text_order = #text_order > 0 and txt(text_order, hln_bufc_order) or "" ---@type string
    local hl_text_icon = txt(text_icon, hln_icon)
    local hl_text_title = txt(text_title, hln_bufc_text)
    local hl_text_status = txt(text_status, hln_status) ---@type string

    local text = text_indicator .. text_order .. text_icon .. text_title .. text_diagnostic .. text_status
    local hl_text = hl_text_indicator
      .. hl_text_order
      .. hl_text_icon
      .. hl_text_title
      .. hl_text_diagnostic
      .. hl_text_status
    return text, btn(hl_text, fn_active_buf, bufnr)
  end

  ---@param buf                         eve.builtin.tab.IBufItem
  ---@param index                         integer
  ---@param order                         integer
  ---@param marker                        string
  ---@return string
  ---@return string
  local function render_buf(buf, index, order, marker)
    local bufnr = buf.bufnr ---@type integer
    local meta = eve.buf.resolve(bufnr, false) ---@type eve.builtin.buf.IMeta|nil
    if meta == nil then
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
      text_diagnostic = text_diagnostic .. " " .. eve.icon.diagnostic.Error .. " " .. count_error
      slots = slots + 1
    end
    if count_warn > 0 then
      text_diagnostic = text_diagnostic .. " " .. eve.icon.diagnostic.Warning .. " " .. count_warn
      slots = slots + 1
    end
    if count_hint > 0 and slots < 2 then
      text_diagnostic = text_diagnostic .. " " .. eve.icon.diagnostic.Hint .. " " .. count_hint
      slots = slots + 1
    end
    if count_info > 0 and slots < 2 then
      text_diagnostic = text_diagnostic .. " " .. eve.icon.diagnostic.Information .. " " .. count_info
      slots = slots + 1
    end

    local filename = meta.filename ---@type string
    local fileicon = meta.fileicon ---@type string
    local hln_title = hln_buf_text ---@type string

    local text_indicator = index == 1 and " " or "▏" ---@type string
    local text_order = eve.icon.todigit_subscript(order) .. marker ---@type string
    local text_icon = fileicon .. " " ---@type string
    local text_title = filename ---@type string
    local text_mod = is_mod and "  " or "  " ---@type string
    local text_pinned = is_mod and "  " or "  " ---@type string
    local text_status = is_pinned and text_pinned or text_mod ---@type string

    local hln_order = hln_buf_order ---@type string
    local hln_text = hln_buf_text ---@type string
    local hln_icon = hln_buf ---@type string
    local hln_mod = hln_buf_mod ---@type string
    local hln_pinned = hln_buf_pinned ---@type string
    local hln_status = is_pinned and hln_pinned or hln_mod ---@type string

    local hl_text_indicator = txt(text_indicator, hln_buf_indicator)
    local hl_order = #text_order > 0 and txt(text_order, hln_order) or "" ---@type string
    local hl_text_icon = txt(text_icon, hln_icon)
    local hl_text_title = txt(text_title, hln_text)
    local hl_text_diagnostic = txt(text_diagnostic, hln_title) ---@type string
    local hl_text_status = txt(text_status, hln_status) ---@type string

    local text = text_indicator .. text_order .. text_icon .. text_title .. text_diagnostic .. text_status
    local hl_text = hl_text_indicator
      .. hl_order
      .. hl_text_icon
      .. hl_text_title
      .. hl_text_diagnostic
      .. hl_text_status
    return text, btn(hl_text, fn_active_buf, bufnr)
  end

  ---@type eve.ux.nvimbar.IRawComponent
  local component = {
    name = "buf:bufs",
    atomic = false,
    ---@diagnostic disable-next-line: unused-local
    render = function(context, remain_width)
      local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
      local meta_tab = eve.tab.resolve(tabnr, false) ---@type eve.builtin.tab.IMeta|nil
      if meta_tab == nil then
        return "", "", false
      end

      local bufs = meta_tab.bufs ---@type eve.builtin.tab.IBufItem[]
      if #bufs < 1 then
        return "", "", false
      end

      local _, bufid_sourcefile = eve.tab.retrieve_buf_sourcefile(tabnr) ---@type eve.builtin.tab.IBufItem|nil, integer|nil
      local bufid_middle = bufid_sourcefile or 1 ---@type integer
      local relative_orders = bufid_middle == bufid_sourcefile and eve.context.behavior.bufs_relative:snapshot() ---@type boolean
      local N = #bufs ---@type integer

      local text ---@type string
      local hl_text ---@type string
      if bufid_middle == bufid_sourcefile then
        text, hl_text = render_bufc(bufs[bufid_middle], bufid_middle, N)
      else
        text, hl_text = render_buf(bufs[bufid_middle], bufid_middle, bufid_middle, ".")
      end

      remain_width = remain_width - vim.api.nvim_strwidth(text) ---@type integer
      if remain_width < 0 then
        return "", "", false
      end

      local left_remain_count = bufid_middle - 1 ---@type integer
      local right_remain_count = N - bufid_middle ---@type integer
      local left_omitter_width = bufid_middle == 1 and 0 or 7 ---@type integer
      local right_omitter_width = bufid_middle == N and 0 or 7 ---@type integer
      remain_width = remain_width - left_omitter_width - right_omitter_width ---@type integer

      ---@param bufid                   integer
      ---@param order                   integer
      ---@return boolean
      local function render_left(bufid, order)
        local t, hl_t =
          render_buf(bufs[bufid], bufid, relative_orders and order or bufid, relative_orders and "₋" or ".")
        local w = vim.api.nvim_strwidth(t) ---@type integer

        if bufid == 1 and remain_width + left_omitter_width >= w then
          text = t .. text
          hl_text = hl_t .. hl_text
          left_remain_count = 0
          remain_width = remain_width + left_omitter_width - w
          return true
        end

        if remain_width < w then
          return true
        end

        text = t .. text
        hl_text = hl_t .. hl_text
        remain_width = remain_width - w
        left_remain_count = left_remain_count - 1
        return bufid == 1
      end

      ---@param bufid                   integer
      ---@param order                   integer
      ---@return boolean
      local function render_right(bufid, order)
        local t, hl_t =
          render_buf(bufs[bufid], bufid, relative_orders and order or bufid, relative_orders and "₊" or ".")
        local w = vim.api.nvim_strwidth(t) ---@type integer

        if bufid == N and remain_width + right_omitter_width >= w then
          text = text .. t
          hl_text = hl_text .. hl_t
          right_remain_count = 0
          remain_width = remain_width + right_omitter_width - w
          return true
        end

        if remain_width < w then
          return true
        end

        text = text .. t
        hl_text = hl_text .. hl_t
        remain_width = remain_width - w
        right_remain_count = right_remain_count - 1
        return bufid == N
      end

      local max_delta = math.max(left_remain_count, right_remain_count) ---@type integer
      local left_done = false ---@type boolean
      local right_done = false ---@type boolean
      for delta = 1, max_delta, 1 do
        if not left_done then
          local bufid = bufid_middle - delta ---@type integer
          left_done = bufid < 1 or render_left(bufid, delta) ---@type boolean
        end
        if not right_done then
          local bufid = bufid_middle + delta ---@type integer
          right_done = bufid > N or render_right(bufid, delta) ---@type boolean
        end
      end

      ---! Render left omitter.
      if left_remain_count > 0 then
        local count = math.min(99, left_remain_count) ---@type integer
        local omitter_text = " " .. eve.icon.ui.Left .. "  " .. tostring(count) .. " " ---@type string
        local omitter_text_hl = txt(omitter_text, hln_buf_omitter) ---@type string
        text = omitter_text .. text
        hl_text = btn(omitter_text_hl, fn_focus_left_buf) .. hl_text
      end

      ---! Render right omitter.
      if right_remain_count > 0 then
        local count = math.min(99, right_remain_count) ---@type integer
        local omitter_text = "▏" .. tostring(count) .. " " .. eve.icon.ui.Right .. "  " ---@type string
        local omitter_text_hl = txt("▏", hln_buf_omitter_sep)
          .. txt(tostring(count) .. " " .. eve.icon.ui.Right .. "  ", hln_buf_omitter) ---@type string
        text = text .. omitter_text
        hl_text = hl_text .. btn(omitter_text_hl, fn_focus_right_buf)
      end

      return text, hl_text, (left_remain_count < 1 and right_remain_count < 1)
    end,
  }
  return component
end

return M

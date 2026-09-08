---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.nvimbar.component.buf" ---@type string

---@class era.m.nvimbar.component.buf.IBufItem
---@field public bufnr                  integer
---@field public meta                   dot.buf.IMeta

---@class era.m.nvimbar.component.buf.IBufSnapshot
---@field public bufnr                  integer
---@field public filename               string
---@field public fileicon               string
---@field public fileicon_hln           string
---@field public pinned                 boolean
---@field public modified               boolean
---@field public error                  integer
---@field public warn                   integer
---@field public hint                   integer
---@field public info                   integer

local btn = stl.nvim.fn.btn
local txt = stl.nvim.fn.txt

---@type string
local fn_active_buf = dot.G.register_anonymous_fn(function(bufnr)
  dot.command.definitions.buf.open:execute(tostring(bufnr))
end) or ""

---@type string
local fn_focus_left_buf = dot.G.register_anonymous_fn(function()
  dot.command.definitions.buf.focus_left:execute()
end) or ""

---@type string
local fn_focus_right_buf = dot.G.register_anonymous_fn(function()
  dot.command.definitions.buf.focus_right:execute()
end) or ""

---@param x                             era.m.nvimbar.component.buf.IBufItem
---@param y                             era.m.nvimbar.component.buf.IBufItem
---@return boolean
local function cmp_rd_buf(x, y)
  local mx = x.meta ---@type dot.buf.IMeta
  local my = y.meta ---@type dot.buf.IMeta

  if mx.filename ~= my.filename then
    return mx.filename < my.filename
  end

  local dp1 = mx.dirpath_pieces ---@type string[]
  local dp2 = my.dirpath_pieces ---@type string[]
  local D1 = #dp1 ---@type integer
  local D2 = #dp2 ---@type integer
  local D = D1 < D2 and D1 or D2 ---@type integer

  local i1 = D1 ---@type integer
  local i2 = D2 ---@type integer
  for _ = 1, D, 1 do
    local p1 = dp1[i1] ---@type string
    local p2 = dp2[i2] ---@type string
    if p1 ~= p2 then
      return p1 < p2
    end

    i1 = i1 - 1 ---@type integer
    i2 = i2 - 1 ---@type integer
  end
  return D1 < D2
end

---Generate disambiguated filename display for buffers with same filenames
---@param rd_bufs                       era.m.nvimbar.component.buf.IBufItem[]
---@return table<integer, string> -- Map from bufnr to disambiguated filename
local function resolve_disambiguations(rd_bufs)
  local N = #rd_bufs ---@type integer
  if N <= 1 then
    return {}
  end

  table.sort(rd_bufs, cmp_rd_buf)

  local depth = 0 ---@type integer
  local disambiguated = {} ---@type table<integer, string>
  for index = 1, N, 1 do
    local item1 = rd_bufs[index] ---@type era.m.nvimbar.component.buf.IBufItem
    local dp1 = item1.meta.dirpath_pieces ---@type string[]
    local D1 = #dp1 ---@type integer

    if index > 1 then
      local item0 = rd_bufs[index - 1] ---@type era.m.nvimbar.component.buf.IBufItem
      if item1.meta.filename ~= item0.meta.filename then
        depth = 0 ---@type integer
      end
    end

    local next_depth = 0 ---@type integer
    if index < N then
      local item2 = rd_bufs[index + 1] ---@type era.m.nvimbar.component.buf.IBufItem
      if item1.meta.filename == item2.meta.filename then
        local dp2 = item2.meta.dirpath_pieces ---@type string[]
        local D2 = #dp2 ---@type integer
        local D = D1 < D2 and D1 or D2 ---@type integer

        local i1 = D1 ---@type integer
        local i2 = D2 ---@type integer

        next_depth = 1
        while next_depth <= D do
          local p1 = dp1[i1] ---@type string
          local p2 = dp2[i2] ---@type string
          if p1 ~= p2 then
            break
          end

          i1 = i1 - 1 ---@type integer
          i2 = i2 - 1 ---@type integer
          next_depth = next_depth + 1 ---@type integer
        end
      end
    end

    depth = depth < next_depth and next_depth or depth ---@type integer
    if depth > 0 then
      local d = D1 - depth + 1 ---@type integer
      local dirpath = D1 >= 1 and table.concat(dp1, stl.env.PATH_SEP, d < 1 and 1 or d, D1) or "" ---@type string
      disambiguated[item1.bufnr] = dirpath ~= stl.env.PATH_SEP and dirpath .. stl.env.PATH_SEP or dirpath ---@type string
    end
    depth = next_depth
  end

  return disambiguated
end

---@class era.m.nvimbar.component.buf
local M = {}

---@param position                      stl.t.NvimbarPositionEnum
---@return era.m.nvimbar.IRawComponent
function M.bufs(position)
  local hln_buf = position .. "_buf" ---@type string
  local hln_buf_disambiguation = position .. "_buf_disambiguation" ---@type string
  local hln_buf_indicator = position .. "_buf_indicator" ---@type string
  local hln_buf_order = position .. "_buf_order" ---@type string
  local hln_buf_mod = position .. "_buf_mod" ---@type string
  local hln_buf_omitter = position .. "_buf_omitter" ---@type string
  local hln_buf_omitter_sep = position .. "_buf_omitter_sep" ---@type string
  local hln_buf_pinned = position .. "_buf_pinned" ---@type string
  local hln_buf_text = position .. "_buf_text" ---@type string

  local hln_bufc = position .. "_bufc" ---@type string
  local hln_bufc_disambiguation = position .. "_bufc_disambiguation" ---@type string
  local hln_bufc_indicator = position .. "_bufc_indicator" ---@type string
  local hln_bufc_order = position .. "_bufc_order" ---@type string
  local hln_bufc_mod = position .. "_bufc_mod" ---@type string
  local hln_bufc_pinned = position .. "_bufc_pinned" ---@type string
  local hln_bufc_text = position .. "_bufc_text" ---@type string
  local hln_bufc_error = position .. "_bufc_error" ---@type string
  local hln_bufc_warn = position .. "_bufc_warn" ---@type string
  local hln_bufc_hint = position .. "_bufc_hint" ---@type string
  local hln_bufc_info = position .. "_bufc_info" ---@type string

  ---@param buf                         era.m.nvimbar.component.buf.IBufSnapshot|false
  ---@param index                       integer
  ---@param total                       integer
  ---@param disambiguated_paths         table<integer, string>
  ---@return string
  ---@return string
  local function render_bufc(buf, index, total, disambiguated_paths)
    if not buf then
      return "", ""
    end

    local bufnr = buf.bufnr ---@type integer
    local is_pinned = buf.pinned ---@type boolean
    local is_mod = buf.modified ---@type boolean
    local count_error = buf.error ---@type integer
    local count_warn = buf.warn ---@type integer
    local count_hint = buf.hint ---@type integer
    local count_info = buf.info ---@type integer

    local text_diagnostic = "" ---@type string
    local hl_text_diagnostic = "" ---@type string

    local slots = 0 ---@type integer
    if count_error > 0 then
      local text = " " .. stl.icon.diagnostic.Error_alt .. " " .. count_error ---@type string
      text_diagnostic = text_diagnostic .. text ---@type string
      hl_text_diagnostic = hl_text_diagnostic .. txt(text, hln_bufc_error) ---@type string
      slots = slots + 1
    end
    if count_warn > 0 then
      local text = " " .. stl.icon.diagnostic.Warning_alt .. " " .. count_warn ---@type string
      text_diagnostic = text_diagnostic .. text
      hl_text_diagnostic = hl_text_diagnostic .. txt(text, hln_bufc_warn) ---@type string
      slots = slots + 1
    end
    if count_hint > 0 and slots < 2 then
      local text = " " .. stl.icon.diagnostic.Hint_alt .. " " .. count_hint ---@type string
      text_diagnostic = text_diagnostic .. text ---@type string
      hl_text_diagnostic = hl_text_diagnostic .. txt(text, hln_bufc_hint)
      slots = slots + 1
    end
    if count_info > 0 and slots < 2 then
      local text = " " .. stl.icon.diagnostic.Information_alt .. " " .. count_info ---@type string
      text_diagnostic = text_diagnostic .. text ---@type string
      hl_text_diagnostic = hl_text_diagnostic .. txt(text, hln_bufc_info)
      slots = slots + 1
    end

    local filename = buf.filename ---@type string
    local fileicon = buf.fileicon ---@type string
    local fileicon_hln = buf.fileicon_hln ---@type string
    local text_indicator = "▎" ---@type string
    local text_order = total < 2 and "" or (stl.icon.todigit_subscript(index) .. ".") ---@type string
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

    local disambiguation = disambiguated_paths[bufnr] ---@type string|nil
    if disambiguation == nil then
      local text = text_indicator .. text_order .. text_icon .. text_title .. text_diagnostic .. text_status
      local hl_text = hl_text_indicator
        .. hl_text_order
        .. hl_text_icon
        .. hl_text_title
        .. hl_text_diagnostic
        .. hl_text_status
      return text, btn(hl_text, fn_active_buf, bufnr)
    end

    local text_disambiguation = " " .. disambiguation .. " " ---@type string
    local hl_text_disambiguation = txt(text_disambiguation, hln_bufc_disambiguation) ---@type string

    local text = text_indicator
      .. text_order
      .. text_icon
      .. text_title
      .. text_disambiguation
      .. text_diagnostic
      .. text_status
    local hl_text = hl_text_indicator
      .. hl_text_order
      .. hl_text_icon
      .. hl_text_title
      .. hl_text_disambiguation
      .. hl_text_diagnostic
      .. hl_text_status
    return text, btn(hl_text, fn_active_buf, bufnr)
  end

  ---@param buf                         era.m.nvimbar.component.buf.IBufSnapshot|false
  ---@param index                       integer
  ---@param order                       integer
  ---@param marker                      string
  ---@param disambiguated_paths         table<integer, string>
  ---@return string
  ---@return string
  local function render_buf(buf, index, order, marker, disambiguated_paths)
    if not buf then
      return "", ""
    end

    local bufnr = buf.bufnr ---@type integer
    local is_pinned = buf.pinned ---@type boolean
    local is_mod = buf.modified ---@type boolean
    local count_error = buf.error ---@type integer
    local count_warn = buf.warn ---@type integer
    local count_hint = buf.hint ---@type integer
    local count_info = buf.info ---@type integer

    local text_diagnostic = "" ---@type string
    local slots = 0 ---@type integer
    if count_error > 0 then
      text_diagnostic = text_diagnostic .. " " .. stl.icon.diagnostic.Error_alt .. " " .. count_error
      slots = slots + 1
    end
    if count_warn > 0 then
      text_diagnostic = text_diagnostic .. " " .. stl.icon.diagnostic.Warning_alt .. " " .. count_warn
      slots = slots + 1
    end
    if count_hint > 0 and slots < 2 then
      text_diagnostic = text_diagnostic .. " " .. stl.icon.diagnostic.Hint_alt .. " " .. count_hint
      slots = slots + 1
    end
    if count_info > 0 and slots < 2 then
      text_diagnostic = text_diagnostic .. " " .. stl.icon.diagnostic.Information_alt .. " " .. count_info
      slots = slots + 1
    end

    local filename = buf.filename ---@type string
    local fileicon = buf.fileicon ---@type string
    local hln_title = hln_buf_text ---@type string

    local text_indicator = index == 1 and " " or "▏" ---@type string
    local text_order = stl.icon.todigit_subscript(order) .. marker ---@type string
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
    local hl_text_order = #text_order > 0 and txt(text_order, hln_order) or "" ---@type string
    local hl_text_icon = txt(text_icon, hln_icon)
    local hl_text_title = txt(text_title, hln_text)
    local hl_text_diagnostic = txt(text_diagnostic, hln_title) ---@type string
    local hl_text_status = txt(text_status, hln_status) ---@type string

    local disambiguation = disambiguated_paths[bufnr] ---@type string|nil
    if disambiguation == nil then
      local text = text_indicator .. text_order .. text_icon .. text_title .. text_diagnostic .. text_status
      local hl_text = hl_text_indicator
        .. hl_text_order
        .. hl_text_icon
        .. hl_text_title
        .. hl_text_diagnostic
        .. hl_text_status
      return text, btn(hl_text, fn_active_buf, bufnr)
    end

    local text_disambiguation = " " .. disambiguation .. " " ---@type string
    local hl_text_disambiguation = txt(text_disambiguation, hln_buf_disambiguation) ---@type string

    local text = text_indicator
      .. text_order
      .. text_icon
      .. text_title
      .. text_disambiguation
      .. text_diagnostic
      .. text_status
    local hl_text = hl_text_indicator
      .. hl_text_order
      .. hl_text_icon
      .. hl_text_title
      .. hl_text_disambiguation
      .. hl_text_diagnostic
      .. hl_text_status
    return text, btn(hl_text, fn_active_buf, bufnr)
  end

  ---@type era.m.nvimbar.IRawComponent
  local component = {
    name = "buf:bufs",

    ---@diagnostic disable-next-line: unused-local
    refresh = function(context)
      local tabnr = context.tabnr ---@type integer
      local meta_tab = dot.tab.resolve(tabnr, false) ---@type dot.tab.IMeta|nil
      if meta_tab == nil then
        return nil
      end

      local bufs = meta_tab.bufs ---@type dot.tab.IBufItem[]
      dot.tab.refresh_bufs(bufs)

      if #bufs < 1 then
        return nil
      end

      local _, bufid_sourcefile = dot.tab.retrieve_buf_sourcefile(tabnr) ---@type dot.tab.IBufItem|nil, integer|nil
      local bufid_middle = bufid_sourcefile or 1 ---@type integer
      local relative_orders = bufid_middle == bufid_sourcefile and dot.context.behavior.bufs_relative:snapshot() ---@type boolean
      local snapshots = {} ---@type (era.m.nvimbar.component.buf.IBufSnapshot|false)[]
      local rd_bufs = {} ---@type era.m.nvimbar.component.buf.IBufItem[]
      local first_by_filename = {} ---@type table<string, integer|false>
      local diagnostic = package.loaded["era.m.lsp.diagnostic"]
      for bufid, buf in ipairs(bufs) do
        local bufnr = buf.bufnr ---@type integer
        local meta = dot.buf.resolve(bufnr, false) ---@type dot.buf.IMeta|nil
        snapshots[bufid] = false
        if meta then
          local diag_data = diagnostic and diagnostic.get_by_bufnr(bufnr)
          snapshots[bufid] = {
            bufnr = bufnr,
            filename = meta.filename,
            fileicon = meta.fileicon,
            fileicon_hln = meta.fileicon_hln,
            pinned = buf.pinned,
            -- getbufinfo would also collect metadata for unrelated modified buffers.
            modified = vim.fn.getbufvar(bufnr, "&modified") == 1,
            error = diag_data and diag_data.error or 0,
            warn = diag_data and diag_data.warn or 0,
            hint = diag_data and diag_data.hint or 0,
            info = diag_data and diag_data.info or 0,
          }
          -- Only duplicate filenames need directory comparison and sorting.
          local first = first_by_filename[meta.filename] ---@type integer|false|nil
          if first == nil then
            first_by_filename[meta.filename] = bufnr
          else
            if first then
              local first_meta = dot.buf.resolve(first, false) ---@type dot.buf.IMeta|nil
              if first_meta then
                rd_bufs[#rd_bufs + 1] = { bufnr = first, meta = first_meta }
              end
              first_by_filename[meta.filename] = false
            end
            rd_bufs[#rd_bufs + 1] = { bufnr = bufnr, meta = meta }
          end
        end
      end
      return {
        bufs = snapshots,
        middle = bufid_middle,
        sourcefile = bufid_sourcefile,
        relative_orders = relative_orders,
        disambiguated_paths = resolve_disambiguations(rd_bufs),
      }
    end,
    render = function(snapshot, _, remain_width)
      local bufs, bufid_middle = snapshot.bufs, snapshot.middle
      local relative_orders, disambiguated_paths = snapshot.relative_orders, snapshot.disambiguated_paths
      local N = #bufs

      ---@param bufid                   integer
      ---@return string
      ---@return string
      local function render_item(bufid)
        if bufid == snapshot.sourcefile then
          return render_bufc(bufs[bufid], bufid, N, disambiguated_paths)
        else
          local order = relative_orders and math.abs(bufid - bufid_middle) or bufid
          local marker = relative_orders and (bufid < bufid_middle and "₋" or "₊") or "."
          return render_buf(bufs[bufid], bufid, order, marker, disambiguated_paths)
        end
      end

      local text, hl_text = render_item(bufid_middle)
      remain_width = remain_width - vim.api.nvim_strwidth(text) ---@type integer
      if remain_width < 0 then
        return "", ""
      end

      local left_remain_count = bufid_middle - 1 ---@type integer
      local right_remain_count = N - bufid_middle ---@type integer
      local left_omitter_width = bufid_middle == 1 and 0 or 7 ---@type integer
      local right_omitter_width = bufid_middle == N and 0 or 7 ---@type integer
      remain_width = remain_width - left_omitter_width - right_omitter_width ---@type integer

      ---@param bufid                   integer
      ---@return boolean
      local function render_left(bufid)
        local t, hl_t = render_item(bufid)
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
      ---@return boolean
      local function render_right(bufid)
        local t, hl_t = render_item(bufid)
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
          left_done = bufid < 1 or render_left(bufid) ---@type boolean
        end
        if not right_done then
          local bufid = bufid_middle + delta ---@type integer
          right_done = bufid > N or render_right(bufid) ---@type boolean
        end
        if left_done and right_done then
          break
        end
      end

      ---! Render left omitter.
      if left_remain_count > 0 then
        local count = math.min(99, left_remain_count) ---@type integer
        local omitter_text = " " .. stl.icon.ui.Left .. "  " .. tostring(count) .. " " ---@type string
        local omitter_text_hl = txt(omitter_text, hln_buf_omitter) ---@type string
        text = omitter_text .. text
        hl_text = btn(omitter_text_hl, fn_focus_left_buf) .. hl_text
      end

      ---! Render right omitter.
      if right_remain_count > 0 then
        local count = math.min(99, right_remain_count) ---@type integer
        local omitter_text = "▏" .. tostring(count) .. " " .. stl.icon.ui.Right .. "  " ---@type string
        local omitter_text_hl = txt("▏", hln_buf_omitter_sep)
          .. txt(tostring(count) .. " " .. stl.icon.ui.Right .. "  ", hln_buf_omitter) ---@type string
        text = text .. omitter_text
        hl_text = hl_text .. btn(omitter_text_hl, fn_focus_right_buf)
      end

      return text, hl_text
    end,
  }
  return component
end

return M

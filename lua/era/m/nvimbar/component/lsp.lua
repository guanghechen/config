---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.nvimbar.component.lsp" ---@type string

local btn = stl.nvim.fn.btn
local txt = stl.nvim.fn.txt
local decode_btn_args = stl.nvim.fn.decode_btn_args

---@type string
local fn_goto_lsp_pos = dot.G.register_anonymous_fn(function(num)
  local args = decode_btn_args(tostring(num)) ---@type integer[]
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

---@type string
local fn_show_error = dot.G.register_anonymous_fn(function(bufnr)
  local data = era.m.lsp.diagnostic.get_by_bufnr(bufnr) ---@type era.m.lsp.diagnostic.IBufferDiagnostics
  stl.reporter.info({
    from = __module_name__,
    subject = "diagnostics -- error",
    details = { count = data.error },
  })
end)

---@type string
local fn_show_warn = dot.G.register_anonymous_fn(function(bufnr)
  local data = era.m.lsp.diagnostic.get_by_bufnr(bufnr) ---@type era.m.lsp.diagnostic.IBufferDiagnostics
  stl.reporter.info({
    from = __module_name__,
    subject = "diagnostics -- warning",
    details = { count = data.warn },
  })
end)

---@type string
local fn_show_hint = dot.G.register_anonymous_fn(function(bufnr)
  local data = era.m.lsp.diagnostic.get_by_bufnr(bufnr) ---@type era.m.lsp.diagnostic.IBufferDiagnostics
  stl.reporter.info({
    from = __module_name__,
    subject = "diagnostics -- hint",
    details = { count = data.hint },
  })
end)

---@type string
local fn_show_info = dot.G.register_anonymous_fn(function(bufnr)
  local data = era.m.lsp.diagnostic.get_by_bufnr(bufnr) ---@type era.m.lsp.diagnostic.IBufferDiagnostics
  stl.reporter.info({
    from = __module_name__,
    subject = "diagnostics -- info",
    details = { count = data.info },
  })
end)

---@class era.m.nvimbar.component.lsp.ILspIcon
---@field public icon                   string
---@field public hl                     string

---@return                              string[]
---@return                              era.m.nvimbar.component.lsp.ILspIcon[]
---@param position                      stl.t.NvimbarPositionEnum
local function get_lsp_clients(position, bufnr)
  if package.loaded["vim.lsp.client"] == nil then
    return {}, {}
  end
  if not stl.nvim.buf.is_valid(bufnr) then
    return {}, {}
  end

  local hln_fallback = position .. "_lsp_client_text" ---@type string
  local client_names = {} ---@type string[]
  local client_icons = {} ---@type era.m.nvimbar.component.lsp.ILspIcon[]
  for _, client in ipairs(vim.lsp.get_clients({ bufnr = bufnr })) do
    if client.attached_buffers[bufnr] then
      local icon = stl.icon.lsp[client.name] or "" ---@type string
      local hln_icon = position .. "_lsp_icon_" .. client.name ---@type string
      if vim.fn.hlexists(hln_icon) == 0 then
        hln_icon = hln_fallback
      end
      client_names[#client_names + 1] = client.name
      client_icons[#client_icons + 1] = {
        icon = icon,
        hl = hln_icon,
      }
    end
  end

  return client_names, client_icons
end

---@param bufnr                         ?integer
---@return string[]
local function get_lsp_client_names(bufnr)
  local names = {} ---@type string[]
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if package.loaded["vim.lsp.client"] == nil or not stl.nvim.buf.is_valid(bufnr) then
    return names
  end

  for _, client in ipairs(vim.lsp.get_clients({ bufnr = bufnr })) do
    if client.attached_buffers[bufnr] then
      names[#names + 1] = client.name
    end
  end
  return names
end

---@type string
local fn_show_clients = dot.G.register_anonymous_fn(function()
  local client_names = get_lsp_client_names() ---@type string[]
  local message = #client_names > 0 and table.concat(client_names, "\n") or "No active LSP client attached." ---@type string

  stl.reporter.info({
    from = __module_name__,
    subject = "lsp clients",
    message = message,
  })
end) or ""

---@class era.m.nvimbar.component.lsp
local M = {}

---@param position                      stl.t.NvimbarPositionEnum
---@return era.m.nvimbar.IRawComponent
function M.client(position)
  local hln_text = position .. "_lsp_client_text" ---@type string
  local icon_sep = "│" ---@type string
  local lsp_icon = "" ---@type string

  ---@type era.m.nvimbar.IRawComponent
  local component = {
    name = "lsp:client",

    will_change = function(context, _, snapshot)
      return not vim.deep_equal(get_lsp_client_names(context.bufnr), snapshot.client_names)
    end,
    refresh = function(context)
      local client_names, client_icons = get_lsp_clients(position, context.bufnr) ---@type string[], era.m.nvimbar.component.lsp.ILspIcon[]
      if #client_names < 1 then
        return { text = "", hltext = "", client_names = client_names }
      end

      if #client_names == 1 then
        local name = client_names[1] ---@type string
        local text = lsp_icon .. " " .. name ---@type string
        local hl_text = btn(txt(lsp_icon, hln_text) .. txt(" " .. name, hln_text), fn_show_clients) ---@type string
        return { text = text, hltext = hl_text, client_names = client_names }
      end

      local text = lsp_icon .. " (" ---@type string
      local hl_text = txt(lsp_icon, hln_text) .. txt(" (", hln_text) ---@type string

      for index, item in ipairs(client_icons) do
        if index > 1 then
          text = text .. icon_sep
          hl_text = hl_text .. txt(icon_sep, hln_text)
        end
        text = text .. item.icon
        hl_text = hl_text .. txt(item.icon, item.hl)
      end

      text = text .. ")" ---@type string
      hl_text = hl_text .. txt(")", hln_text) ---@type string
      hl_text = btn(hl_text, fn_show_clients) ---@type string
      return { text = text, hltext = hl_text, client_names = client_names }
    end,
  }
  return component
end

---@param position                      stl.t.NvimbarPositionEnum
---@return era.m.nvimbar.IRawComponent
function M.diagnostics(position)
  local hln_diagnostics_error = position .. "_lsp_diagnostics_error" ---@type string
  local hln_diagnostics_warn = position .. "_lsp_diagnostics_warn" ---@type string
  local hln_diagnostics_hint = position .. "_lsp_diagnostics_hint" ---@type string
  local hln_diagnostics_info = position .. "_lsp_diagnostics_info" ---@type string

  ---@type era.m.nvimbar.IRawComponent
  local component = {
    name = "lsp:diagnostics",

    condition = function()
      return package.loaded["era.m.lsp.diagnostic"] ~= nil
    end,
    refresh = function(context)
      local diag_data = era.m.lsp.diagnostic.get_by_bufnr(context.bufnr) ---@type era.m.lsp.diagnostic.IBufferDiagnostics

      local text_hl = "" ---@type string
      local text_count_error = diag_data.error > 0 and stl.icon.diagnostic.Error_alt .. " " .. diag_data.error .. " "
        or ""
      text_hl = text_hl .. btn(txt(text_count_error, hln_diagnostics_error), fn_show_error)

      local text_count_warn = diag_data.warn > 0 and stl.icon.diagnostic.Warning_alt .. " " .. diag_data.warn .. " "
        or ""
      text_hl = text_hl .. btn(txt(text_count_warn, hln_diagnostics_warn), fn_show_warn)

      local text_count_hint = diag_data.hint > 0 and stl.icon.diagnostic.Hint_alt .. " " .. diag_data.hint .. " " or ""
      text_hl = text_hl .. btn(txt(text_count_hint, hln_diagnostics_hint), fn_show_hint)

      local text_count_info = diag_data.info > 0 and stl.icon.diagnostic.Information_alt .. " " .. diag_data.info .. " "
        or ""
      text_hl = text_hl .. btn(txt(text_count_info, hln_diagnostics_info), fn_show_info)

      local text = text_count_error .. text_count_warn .. text_count_hint .. text_count_info
      return { text = text, hltext = text_hl }
    end,
  }
  return component
end

---@param position                      stl.t.NvimbarPositionEnum
---@return era.m.nvimbar.IRawComponent
function M.symbols(position)
  local hln_lsp_icon = position .. "_lsp_symbol_icon" ---@type string
  local hln_lsp_sep = position .. "_lsp_symbol_sep" ---@type string
  local hln_lsp_text = position .. "_lsp_symbol_text" ---@type string

  local sep = " " .. stl.icon.fillchars.foldclose .. " " ---@type string

  ---@type era.m.nvimbar.IRawComponent
  local component = {
    name = "lsp:symbols",

    ---@diagnostic disable-next-line: unused-local
    refresh = function(context)
      local meta = dot.win.resolve(context.winnr, false)
      local winline = meta and meta.winline
      local pieces = {}
      for _, symbol in ipairs(winline and winline.lsp_symbols or {}) do
        local title = symbol.name or ""
        local icon = (stl.icon.kind[symbol.kind] or "") .. " "
        local hln_icon = symbol.kind and hln_lsp_icon .. "_" .. symbol.kind or hln_lsp_icon
        local text = sep .. icon .. title
        local hltext = txt(sep, hln_lsp_sep) .. txt(icon, hln_icon) .. txt(title, hln_lsp_text)
        pieces[#pieces + 1] = {
          text = text,
          hltext = btn(hltext, fn_goto_lsp_pos, { context.winnr, symbol.row, symbol.col }),
          width = vim.api.nvim_strwidth(text),
        }
      end
      return pieces
    end,
    render = function(pieces, _, remain_width)
      local text, hltext = "", ""
      for _, piece in ipairs(pieces) do
        if piece.width > remain_width then
          return text, hltext
        end
        text, hltext = text .. piece.text, hltext .. piece.hltext
        remain_width = remain_width - piece.width
      end
      return text, hltext
    end,
  }
  return component
end

return M

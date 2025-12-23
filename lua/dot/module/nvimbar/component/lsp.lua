local __module_name__ = "dot.module.nvimbar.component.lsp" ---@type string

local btn = ark.nvim.btn
local txt = ark.nvim.txt
local decode_btn_args = ark.nvim.decode_btn_args

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
  local errors = vim.diagnostic.get(bufnr, { severity = vim.diagnostic.severity.ERROR })
  ark.reporter.info({
    from = __module_name__,
    subject = "diagnostics -- error",
    details = errors,
  })
end)

---@type string
local fn_show_warn = dot.G.register_anonymous_fn(function(bufnr)
  local warns = vim.diagnostic.get(bufnr, { severity = vim.diagnostic.severity.WARN })
  ark.reporter.info({
    from = __module_name__,
    subject = "diagnostics -- warning",
    details = warns,
  })
end)

---@type string
local fn_show_hint = dot.G.register_anonymous_fn(function(bufnr)
  local hints = vim.diagnostic.get(bufnr, { severity = vim.diagnostic.severity.HINT })
  ark.reporter.info({
    from = __module_name__,
    subject = "diagnostics -- hint",
    details = hints,
  })
end)

---@type string
local fn_show_info = dot.G.register_anonymous_fn(function(bufnr)
  local infos = vim.diagnostic.get(bufnr, { severity = vim.diagnostic.severity.INFO })
  ark.reporter.info({
    from = __module_name__,
    subject = "diagnostics -- info",
    details = infos,
  })
end)

---@class dot.module.nvimbar.component.lsp.ILspIcon
---@field public icon                   string
---@field public hl                     string

---@return                              string[]
---@return                              dot.module.nvimbar.component.lsp.ILspIcon[]
---@param position                      dot.module.nvimbar.PositionEnum
local function get_lsp_clients(position)
  local bufnr = vim.api.nvim_get_current_buf() ---@type integer
  if not dot.buf.is_valid(bufnr) then
    return {}, {}
  end

  local hln_fallback = position .. "_lsp_client_text" ---@type string
  local client_names = {} ---@type string[]
  local client_icons = {} ---@type dot.module.nvimbar.component.lsp.ILspIcon[]
  for _, client in ipairs(vim.lsp.get_clients({ bufnr = bufnr })) do
    if client.attached_buffers[bufnr] and client.name ~= "null-ls" and client.name ~= "copilot" then
      local icon = ark.icon.lsp[client.name] or "" ---@type string
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

---@return                              string[]
local function get_lsp_client_names()
  local names = {} ---@type string[]
  local bufnr = vim.api.nvim_get_current_buf() ---@type integer
  if not dot.buf.is_valid(bufnr) then
    return names
  end

  for _, client in ipairs(vim.lsp.get_clients({ bufnr = bufnr })) do
    if client.attached_buffers[bufnr] and client.name ~= "null-ls" and client.name ~= "copilot" then
      names[#names + 1] = client.name
    end
  end
  return names
end

---@type string
local fn_show_clients = dot.G.register_anonymous_fn(function()
  local client_names = get_lsp_client_names() ---@type string[]
  local message = #client_names > 0 and table.concat(client_names, "\n") or "No active LSP client attached." ---@type string

  ark.reporter.info({
    from = __module_name__,
    subject = "lsp clients",
    message = message,
  })
end) or ""

---@class dot.module.nvimbar.component.lsp
local M = {}

---@param position                      dot.module.nvimbar.PositionEnum
---@return dot.module.nvimbar.IRawComponent
function M.client(position)
  local hln_text = position .. "_lsp_client_text" ---@type string
  local icon_sep = "│" ---@type string
  local lsp_icon = "" ---@type string

  ---@type dot.module.nvimbar.IRawComponent
  local component = {
    name = "lsp:client",
    atomic = true,
    render = function()
      local client_names, client_icons = get_lsp_clients(position) ---@type string[], dot.module.nvimbar.component.lsp.ILspIcon[]
      if #client_names < 1 then
        return "", "", true
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
      return text, hl_text, true
    end,
  }
  return component
end

---@param position                      dot.module.nvimbar.PositionEnum
---@return dot.module.nvimbar.IRawComponent
function M.diagnostics(position)
  local hln_diagnostics_error = position .. "_lsp_diagnostics_error" ---@type string
  local hln_diagnostics_warn = position .. "_lsp_diagnostics_warn" ---@type string
  local hln_diagnostics_hint = position .. "_lsp_diagnostics_hint" ---@type string
  local hln_diagnostics_info = position .. "_lsp_diagnostics_info" ---@type string

  ---@type dot.module.nvimbar.IRawComponent
  local component = {
    name = "lsp:diagnostics",
    atomic = true,
    condition = function()
      return not not rawget(vim, "lsp")
    end,
    render = function(context)
      local text_hl = "" ---@type string
      local count_error = #vim.diagnostic.get(context.bufnr, { severity = vim.diagnostic.severity.ERROR })
      local text_count_error = count_error > 0 and ark.icon.diagnostic.Error_alt .. " " .. count_error .. " " or ""
      text_hl = text_hl .. btn(txt(text_count_error, hln_diagnostics_error), fn_show_error)

      local count_warn = #vim.diagnostic.get(context.bufnr, { severity = vim.diagnostic.severity.WARN })
      local text_count_warn = count_warn > 0 and ark.icon.diagnostic.Warning_alt .. " " .. count_warn .. " " or ""
      text_hl = text_hl .. btn(txt(text_count_warn, hln_diagnostics_warn), fn_show_warn)

      local count_hint = #vim.diagnostic.get(context.bufnr, { severity = vim.diagnostic.severity.HINT })
      local text_count_hint = count_hint > 0 and ark.icon.diagnostic.Hint_alt .. " " .. count_hint .. " " or ""
      text_hl = text_hl .. btn(txt(text_count_hint, hln_diagnostics_hint), fn_show_hint)

      local count_info = #vim.diagnostic.get(context.bufnr, { severity = vim.diagnostic.severity.INFO })
      local text_count_info = count_info > 0 and ark.icon.diagnostic.Information_alt .. " " .. count_info .. " " or ""
      text_hl = text_hl .. btn(txt(text_count_info, hln_diagnostics_info), fn_show_info)

      local text = text_count_error .. text_count_warn .. text_count_hint .. text_count_info
      return text, text_hl, true
    end,
  }
  return component
end

---@param position                      dot.module.nvimbar.PositionEnum
---@return dot.module.nvimbar.IRawComponent
function M.symbols(position)
  local hln_lsp_icon = position .. "_lsp_symbol_icon" ---@type string
  local hln_lsp_sep = position .. "_lsp_symbol_sep" ---@type string
  local hln_lsp_text = position .. "_lsp_symbol_text" ---@type string

  local sep = " " .. ark.icon.fillchars.foldclose .. " " ---@type string
  local width_sep = vim.api.nvim_strwidth(sep) ---@type integer

  ---@type dot.module.nvimbar.IRawComponent
  local component = {
    name = "lsp:symbols",
    atomic = false,
    ---@diagnostic disable-next-line: unused-local
    render = function(context, remain_width)
      local winnr = context.winnr ---@type integer
      local meta = dot.win.resolve(winnr, false) ---@type dot.win.IMeta|nil
      local winline = meta ~= nil and meta.winline or nil ---@type dot.win.IWinline|nil
      if winline == nil then
        return "", "", false
      end

      local symbols = winline.lsp_symbols ---@type dot.t.ILspSymbol[]|nil
      if symbols == nil or #symbols < 1 then
        return "", "", false
      end

      local text = "" ---@type string
      local hl_text = "" ---@type string

      local has_remain = false ---@type boolean
      for _, symbol in ipairs(symbols) do
        local title = symbol.name or "" ---@type string
        local icon = (ark.icon.kind[symbol.kind] or "") .. " " ---@type string
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

return M

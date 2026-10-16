---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.dressing.winline" ---@type string
local initialized = false ---@type boolean

---@class era.dressing.winline
local M = {}

local txt = stl.nvim.fn.txt
local position = "f_wl" ---@type stl.t.NvimbarPositionEnum

---@param left                          dot.t.ILspSymbol[]|nil
---@param right                         dot.t.ILspSymbol[]|nil
---@return boolean
local function is_same_symbols(left, right)
  if left == nil or right == nil or #left ~= #right then
    return left == right
  end
  for index, symbol in ipairs(left) do
    local other = right[index] ---@type dot.t.ILspSymbol
    if symbol.kind ~= other.kind or symbol.name ~= other.name or symbol.row ~= other.row or symbol.col ~= other.col then
      return false
    end
  end
  return true
end

---@param winnr                         integer
---@param symbols                       dot.t.ILspSymbol[]
---@return nil
local function deliver_symbols(winnr, symbols)
  local meta = dot.win.resolve(winnr, false) ---@type dot.win.IMeta|nil
  local winline = meta ~= nil and meta.winline or nil ---@type dot.win.IWinline|nil
  if winline == nil or winline.nvimbar:isdisposed() or is_same_symbols(winline.lsp_symbols, symbols) then
    return
  end
  winline.lsp_symbols = symbols
  vim.schedule(function()
    if not winline.nvimbar:isdisposed() then
      winline.nvimbar:refresh()
    end
  end)
end

---@param winnr                         integer
---@return era.m.nvimbar.Nvimbar|nil
local function resolve_nvimbar(winnr)
  local meta = dot.win.resolve(winnr, false) ---@type dot.win.IMeta|nil
  local winline = meta ~= nil and meta.winline or nil ---@type dot.win.IWinline|nil
  if winline == nil or winline.nvimbar:isdisposed() then
    local c = era.m.nvimbar.component
    local nvimbar = nil ---@type era.m.nvimbar.Nvimbar|nil
    nvimbar = era.m.nvimbar.Nvimbar.new({
      name = "winline_" .. winnr,
      comp_sep = "",
      comp_sep_hlname = "f_wl_bg",
      comp_sep_hlname_active = "f_wl_bg",
      get_max_width = function()
        if vim.api.nvim_win_is_valid(winnr) then
          local width = vim.api.nvim_win_get_width(winnr) ---@type integer
          return stl.nvim.win.is_float(winnr) and width - 2 or width
        end
        return 0
      end,
      get_preset_context = function()
        return { winnr = winnr }
      end,
      is_active = function()
        return winnr == vim.api.nvim_get_current_win()
      end,
      on_fulfilled = function(result)
        if
          vim.api.nvim_win_is_valid(winnr)
          and vim.api.nvim_get_option_value("winbar", { win = winnr, scope = "local" }) ~= result
        then
          vim.api.nvim_set_option_value("winbar", result, { win = winnr, scope = "local" })
        end
      end,
      validate = function()
        if not vim.api.nvim_win_is_valid(winnr) then
          return "The window is not valid, winnr=" .. winnr .. "."
        end
      end,
    })

    local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
    winline = winline or { bufnr = bufnr, nvimbar = nvimbar } ---@type dot.win.IWinline

    winline.nvimbar = nvimbar
    meta.winline = winline
    winline.fork = function(target_winnr)
      return resolve_nvimbar(target_winnr)
    end

    winline.lsp_symbols = {}
    nvimbar
      ---
      :place({
        position = "left",
        priority = 95,
        component = c.lazy(function()
          return c.dir.path(position)
        end),
      })
      :place({
        position = "left",
        priority = 100,
        component = c.lazy(function()
          return c.file.name(position)
        end),
      })
      :place({
        position = "left",
        priority = 90,
        component = c.lazy(function()
          return c.lsp.symbols(position)
        end),
      })
      ---
      :place({
        position = "center",
        priority = 100,
        component = c.lazy(function()
          return c.devmode.render_count(position)
        end),
      })
      ---
      :place({
        position = "right",
        priority = 120,
        component = c.lazy(function()
          return c.nvim.search_count(position)
        end),
      })
      :place({
        position = "right",
        priority = 110,
        component = c.lazy(function()
          return c.git.hunk_nav(position)
        end),
      })
  end

  if winline ~= nil then
    -- The confirmed tree answers at once; the request issued after this render decides the final path.
    local symbols = era.m.lsp.symbols.path(winnr) ---@type dot.t.ILspSymbol[]|nil
    if symbols ~= nil then
      winline.lsp_symbols = symbols
    end
    era.m.lsp.symbols.request(winnr, deliver_symbols)
    return winline.nvimbar
  end

  return nil
end

---@param winnr                         ?integer
---@return nil
local function render(winnr)
  if winnr == nil or not stl.nvim.win.is_valid(winnr) then
    return
  end

  local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
  local filetype = vim.api.nvim_get_option_value("filetype", { buf = bufnr }) ---@type string
  if stl.filetype.has_external_winline(filetype) then
    dot.win.render_winline(winnr)
    return
  end

  local filepath = vim.api.nvim_buf_get_name(bufnr) ---@type string
  if string.sub(filepath, 1, 11) == "diffview://" then
    local should_show_winline = string.sub(filepath, 1, 19) ~= "diffview:///panels/" ---@type boolean
    if should_show_winline then
      local text = string.sub(filepath, 12) ---@type string
      if string.sub(text, 1, #stl.env.HOME_NVIM_CONFIG) == stl.env.HOME_NVIM_CONFIG then
        text = "<NVIM_HOME>" .. string.sub(text, #stl.env.HOME_NVIM_CONFIG + 1)
      end
      local winbar = "diffview://" .. text
      local _, hunk_nav = era.m.nvimbar.component.git.render_hunk_nav(winnr) ---@type string|nil, string|nil
      local rendered = txt(winbar, "f_wl_text") ---@type string
      if hunk_nav ~= nil then
        rendered = rendered .. "%=" .. hunk_nav
      end
      vim.api.nvim_set_option_value("winbar", rendered, { win = winnr, scope = "local" })
    end
    return
  end
  local buftype = vim.api.nvim_get_option_value("buftype", { buf = bufnr }) ---@type string
  if buftype == "nofile" then
    return
  end

  if buftype == "terminal" then
    return
  end

  if not dot.win.is_sourcefile(winnr) then
    return
  end

  local nvimbar = resolve_nvimbar(winnr) ---@type era.m.nvimbar.Nvimbar|nil
  if nvimbar ~= nil then
    dot.win.render_winline(winnr)
    return
  end

  if stl.filetype.is_sourcefile(filetype) then
    vim.api.nvim_set_option_value("winbar", txt(filepath, "f_wl_text"), { win = winnr, scope = "local" })
    return
  end
end

--- Subscribe once; dirty events render the current and previous windows.
---@return nil
function M.dressing()
  if initialized then
    return
  end
  initialized = true

  dot.state.status.dirty_winline_nr:subscribe(
    stl.c.Subscriber.new({
      on_next = function(winnr, winnr_prev)
        render(winnr)
        if winnr_prev ~= winnr then
          render(winnr_prev)
        end
      end,
    }),
    true
  )
end

return M

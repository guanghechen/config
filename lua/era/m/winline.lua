---@class era.m.winline
local M = {}

local txt = stl.nvim.fn.txt
local position = "f_wl" ---@type stl.e.NvimbarPositionEnum

---@return boolean
local function silent()
  local devmode = dot.context.flight.devmode:snapshot() ---@type boolean
  return not devmode
end

---@param winnr                         integer
---@return era.m.nvimbar.Nvimbar|nil
local function resolve_nvimbar(winnr)
  local meta = dot.win.resolve(winnr, false) ---@type dot.win.IMeta|nil
  local winline = meta ~= nil and meta.winline or nil ---@type dot.win.IWinline|nil
  if winline == nil or winline.nvimbar:isdisposed() then
    local nvimbar = nil ---@type era.m.nvimbar.Nvimbar|nil
    nvimbar = era.m.nvimbar.Nvimbar.new({
      name = "winline_" .. winnr,
      comp_sep = "",
      comp_sep_hlname = "f_wl_bg",
      comp_sep_hlname_active = "f_wl_bg",
      delay = 128,
      silent = silent,
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
        if vim.api.nvim_win_is_valid(winnr) then
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
    winline = winline or { bufnr = bufnr, nvimbar = nvimbar, locate_token = nil } ---@type dot.win.IWinline

    winline.nvimbar = nvimbar
    meta.winline = winline

    winline.lsp_symbols = {}
    nvimbar
      ---
      :place("left", era.m.nvimbar.component.dir.path(position), 95)
      :place("left", era.m.nvimbar.component.file.name(position), 100)
      :place("left", era.m.nvimbar.component.lsp.symbols(position), 90)
      ---
      :place("center", era.m.nvimbar.component.devmode.render_count(position), 100)
    ---
    -- :place("right", era.m.nvimbar.component.dirpath_prominent(position), 100)
  end

  if winline ~= nil then
    if winline.locate_scheduler == nil or winline.locate_scheduler:isdisposed() then
      local locate_scheduler = stl.c.Scheduler.new({
        name = string.format("locate_scheduler:%d", winnr),
        mode = "throttle",
        delay = 128,
        timeout = 10000,
        value = stl.c.Observable.from_value(false),
        silent = silent,
        task = function(_, _, callback)
          local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
          if winline.locate_token ~= nil then
            winline.locate_token:cancel()
            winline.locate_token = nil
          end

          local token = stl.c.CancellationToken.new()
          winline.locate_token = token

          dot.win.locate_symbols(winnr, token):finally(function(resolved, result)
            winline.locate_token = nil

            if not resolved or not result or not result.ok then
              callback(false)
              return
            end

            if not vim.api.nvim_win_is_valid(winnr) or bufnr ~= vim.api.nvim_win_get_buf(winnr) then
              callback(false)
              return
            end

            winline.lsp_symbols = result.symbols
            vim.schedule(function()
              if not winline.nvimbar:isdisposed() then
                winline.nvimbar:render()
              end
            end)
            callback(true, true)
          end)
        end,
      })
      winline.locate_scheduler = locate_scheduler
    end
    winline.locate_scheduler:schedule()
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
      vim.api.nvim_set_option_value("winbar", txt(winbar, "f_wl_text"), { win = winnr, scope = "local" })
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
    nvimbar:render()
    return
  end

  if stl.filetype.is_sourcefile(filetype) then
    vim.api.nvim_set_option_value("winbar", txt(filepath, "f_wl_text"), { win = winnr, scope = "local" })
    return
  end
end

---@return nil
function M.dressing()
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

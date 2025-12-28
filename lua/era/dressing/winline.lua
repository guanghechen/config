local c = require("dot.module.nvimbar").component
local Nvimbar = require("dot.module.nvimbar").Nvimbar

local txt = ark.vim.fn.txt
local position = "f_wl" ---@type ark.e.NvimbarPositionEnum

---@return boolean
local function silent()
  local devmode = dot.context.flight.devmode:snapshot() ---@type boolean
  return not devmode
end

---@param winnr                         integer
---@return dot.module.nvimbar.Nvimbar|nil
local function resolve_nvimbar(winnr)
  local meta = dot.win.resolve(winnr, false) ---@type dot.win.IMeta|nil
  local winline = meta ~= nil and meta.winline or nil ---@type dot.win.IWinline|nil
  if winline == nil or winline.nvimbar:isdisposed() then
    local nvimbar = nil ---@type dot.module.nvimbar.Nvimbar|nil
    nvimbar = Nvimbar.new({
      name = "winline_" .. winnr,
      comp_sep = "",
      comp_sep_hlname = "f_wl_bg",
      comp_sep_hlname_active = "f_wl_bg",
      delay = 128,
      silent = silent,
      get_max_width = function()
        if vim.api.nvim_win_is_valid(winnr) then
          local width = vim.api.nvim_win_get_width(winnr) ---@type integer
          return ark.vim.win.is_float(winnr) and width - 2 or width
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
          vim.wo[winnr].winbar = result
        end
      end,
      validate = function()
        if not vim.api.nvim_win_is_valid(winnr) then
          return "The window is not valid, winnr=" .. winnr .. "."
        end
      end,
    })

    local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
    winline = winline or { bufnr = bufnr, nvimbar = nvimbar, locate_cancel = nil } ---@type dot.win.IWinline

    winline.nvimbar = nvimbar
    meta.winline = winline

    winline.lsp_symbols = {}
    nvimbar
      ---
      :place("left", c.dir.path(position), 95)
      :place("left", c.file.name(position), 100)
      :place("left", c.lsp.symbols(position), 90)
      ---
      :place("center", c.devmode.render_count(position), 100)
    ---
    -- :place("right", c.dirpath_prominent(position), 100)
  end

  if winline ~= nil then
    if winline.locate_scheduler == nil or winline.locate_scheduler:isdisposed() then
      local locate_scheduler = ark.c.Scheduler.new({
        name = string.format("locate_scheduler:%d", winnr),
        mode = "throttle",
        delay = 128,
        timeout = 10000,
        value = ark.c.Observable.from_value(false),
        silent = silent,
        task = function(_, _, callback)
          local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
          if winline.locate_cancel ~= nil then
            pcall(winline.locate_cancel)
            winline.locate_cancel = nil
          end

          winline.locate_cancel = dot.win.locate_symbols(winnr, function(ok, symbols)
            winline.locate_cancel = nil

            if not ok or not vim.api.nvim_win_is_valid(winnr) or bufnr ~= vim.api.nvim_win_get_buf(winnr) then
              callback(false)
              return
            end

            winline.lsp_symbols = symbols
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

---@param winnr                         integer|nil
---@return nil
local function render(winnr)
  if winnr == nil or not ark.vim.win.is_valid(winnr) then
    return
  end

  local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
  local filetype = vim.bo[bufnr].filetype ---@type string
  if ark.filetype.has_external_winline(filetype) then
    return
  end

  local filepath = vim.api.nvim_buf_get_name(bufnr) ---@type string
  if string.sub(filepath, 1, 11) == "diffview://" then
    local should_show_winline = string.sub(filepath, 1, 19) ~= "diffview:///panels/" ---@type boolean
    if should_show_winline then
      local text = string.sub(filepath, 12) ---@type string
      if string.sub(text, 1, #ark.env.HOME_NVIM_CONFIG) == ark.env.HOME_NVIM_CONFIG then
        text = "<NVIM_HOME>" .. string.sub(text, #ark.env.HOME_NVIM_CONFIG + 1)
      end
      local winbar = "diffview://" .. text
      vim.wo[winnr].winbar = txt(winbar, "f_wl_text")
    end
    return
  end
  local buftype = vim.bo[bufnr].buftype ---@type string
  if buftype == "nofile" then
    return
  end

  if buftype == "terminal" then
    return
  end

  if not dot.win.is_sourcefile(winnr) then
    return
  end

  local nvimbar = resolve_nvimbar(winnr) ---@type dot.module.nvimbar.Nvimbar|nil
  if nvimbar ~= nil then
    nvimbar:render()
    return
  end

  if ark.filetype.is_sourcefile(filetype) then
    vim.wo[winnr].winbar = txt(filepath, "f_wl_text")
    return
  end
end

dot.state.status.dirty_winline_nr:subscribe(
  ark.c.Subscriber.new({
    on_next = function(winnr, winnr_prev)
      render(winnr)
      if winnr_prev ~= winnr then
        render(winnr_prev)
      end
    end,
  }),
  true
)

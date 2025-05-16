local c = eve.ux.nvimbar.component

local txt = eve.nvim.txt
local position = "f_wl" ---@type eve.ux.nvimbar.PositionEnum

---@return boolean
local function silent()
  local devmode = eve.context.flight.devmode:snapshot() ---@type boolean
  return not devmode
end

---@param winnr                         integer
---@param source                        "sourcefile"|"neotree"
---@return eve.ux.nvimbar.Nvimbar|nil
local function resolve_nvimbar(winnr, source)
  local meta = eve.win.resolve(winnr, false) ---@type eve.builtin.win.IMeta|nil
  local winline = meta ~= nil and meta.winline or nil ---@type eve.builtin.win.IWinline|nil
  if winline == nil or winline.nvimbar:isdisposed() then
    local nvimbar = nil ---@type eve.ux.nvimbar.Nvimbar|nil
    nvimbar = eve.ux.nvimbar.Nvimbar.new({
      name = "winline_" .. winnr,
      comp_sep = "",
      comp_sep_hlname = "f_wl_bg",
      comp_sep_hlname_active = "f_wl_bg",
      delay = 128,
      silent = silent,
      get_max_width = function()
        if vim.api.nvim_win_is_valid(winnr) then
          return vim.api.nvim_win_get_width(winnr)
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
    winline = winline or { bufnr = bufnr, nvimbar = nvimbar } ---@type eve.builtin.win.IWinline

    winline.nvimbar = nvimbar
    meta.winline = winline

    if source == "sourcefile" then
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
    elseif source == "neotree" then
      local is_floating = eve.win.is_float(winnr) ---@type boolean
      nvimbar:place("center", c.plugin.neotree(position, is_floating and "float" or "left"), 100)
    else
    end
  end

  if source == "sourcefile" and winline ~= nil then
    if winline.locate_scheduler == nil or winline.locate_scheduler:isdisposed() then
      local locate_scheduler = std.Scheduler.new({
        name = string.format("locate_scheduler:%d", winnr),
        mode = "throttle",
        delay = 128,
        timeout = 10000,
        value = std.Observable.from_value(false),
        silent = silent,
        task = function(_, _, callback)
          local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
          eve.win.locate_symbols(winnr, function(ok, symbols)
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
  end

  return winline.nvimbar
end

---@param winnr                         integer|nil
---@return nil
local function render(winnr)
  if winnr == nil or not eve.win.is_valid(winnr) then
    return
  end

  local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
  local filetype = vim.bo[bufnr].filetype ---@type string
  if eve.filetype.has_external_winline(filetype) then
    return
  end

  if filetype == eve.filetype.NEOTREE then
    if vim.o.showtabline == 0 or eve.win.is_float(winnr) then
      local nvimbar = resolve_nvimbar(winnr, "neotree") ---@type eve.ux.nvimbar.Nvimbar|nil
      if nvimbar ~= nil then
        nvimbar:render()
      end
    else
      vim.wo[winnr].winbar = nil
    end
    return
  end

  local filepath = vim.api.nvim_buf_get_name(bufnr) ---@type string
  if filepath:sub(1, 11) == "diffview://" then
    local should_show_winline = filepath:sub(1, 19) ~= "diffview:///panels/" ---@type boolean
    if should_show_winline then
      local text = filepath:sub(12) ---@type string
      if text:sub(1, #std.env.HOME_NVIM_CONFIG) == std.env.HOME_NVIM_CONFIG then
        text = "<NVIM_HOME>" .. text:sub(#std.env.HOME_NVIM_CONFIG + 1)
      end
      local winbar = "diffview://" .. text
      vim.wo[winnr].winbar = txt(winbar, "f_wl_text")
    end
    return
  end
  if filepath:sub(1, 11) == "gitsigns://" then
    local text = filepath:sub(12) ---@type string
    if text:sub(1, #std.env.HOME_NVIM_CONFIG) == std.env.HOME_NVIM_CONFIG then
      text = "<NVIM_HOME>" .. text:sub(#std.env.HOME_NVIM_CONFIG + 1)
    end
    local winbar = "gitsigns://" .. text
    vim.wo[winnr].winbar = txt(winbar, "f_wl_text")
    return
  end

  local buftype = vim.bo[bufnr].buftype ---@type string
  if buftype == "nofile" then
    return
  end

  if not eve.win.is_sourcefile(winnr) then
    return
  end

  local nvimbar = resolve_nvimbar(winnr, "sourcefile") ---@type eve.ux.nvimbar.Nvimbar|nil
  if nvimbar ~= nil then
    nvimbar:render()
    return
  end

  if eve.filetype.is_sourcefile(filetype) then
    vim.wo[winnr].winbar = txt(filepath, "f_wl_text")
    return
  end
end

eve.status.dirty_winline_nr:subscribe(
  std.Subscriber.new({
    on_next = function(winnr, winnr_prev)
      render(winnr)
      if winnr_prev ~= winnr then
        render(winnr_prev)
      end
    end,
  }),
  true
)

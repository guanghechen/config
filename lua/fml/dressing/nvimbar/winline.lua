local c = require("fml.dressing.nvimbar.components")

local txt = eve.nvim.txt
local position = "f_wl" ---@type eve.ux.nvimbar.Position

---@param winnr                         integer
---@param source                        "sourcefile"|"neotree"
---@return eve.ux.INvimbar|nil
local function resolve_winline_scheduler(winnr, source)
  local meta = eve.state.win.resolve(winnr) ---@type eve.state.win.meta.state|nil
  local winline_map = eve.state.win.winline_map ---@type table<integer, eve.ux.INvimbar|nil>

  local winline = winline_map[winnr] ---@type eve.ux.INvimbar|nil
  if winline == nil then
    winline = eve.ux.Nvimbar.new({
      name = "winline_" .. winnr,
      comp_sep = "",
      comp_sep_hlname = position .. "_bg",
      comp_sep_hlname_active = position .. "_bg",
      render_delay = 128,
      silent = function()
        local devmode = eve.state.flight.devmode:snapshot() ---@type boolean
        return not devmode
      end,
      get_max_width = function()
        if vim.api.nvim_win_is_valid(winnr) then
          return vim.api.nvim_win_get_width(winnr)
        end
        return 0
      end,
      get_preset_context = function()
        return { winnr = winnr }
      end,
      is_active = function(context)
        local winnr_cur = vim.api.nvim_get_current_win() ---@type integer
        return winnr_cur > 0 and winnr_cur == context.winnr
      end,
      pre_task = function(callback)
        if winline == nil or winline:is_disposed() then
          return
        end

        if not vim.api.nvim_win_is_valid(winnr) then
          if winline_map[winnr] == winline then
            winline_map[winnr] = nil
          end
          winline:dispose()
          winline = nil
          return
        end

        if source == "sourcefile" then
          -- Quick rerender the winline before the pre_task done to make the ui quick refresh.
          local result = winline:render_immediately()
          vim.wo[winnr].winbar = result

          eve.state.win.locate_symbols(winnr, function(err)
            if err == nil then
              callback()
              return
            end

            if err == false then
              callback()
            else
              callback(err)
            end
          end)
          return
        end

        callback()
      end,
      trigger_rerender = function()
        if winline == nil or winline:is_disposed() then
          return
        end

        if not vim.api.nvim_win_is_valid(winnr) then
          if winline_map[winnr] == winline then
            winline_map[winnr] = nil
          end
          winline:dispose()
          winline = nil
          return
        end

        local result = winline:snapshot() ---@type string
        vim.wo[winnr].winbar = result
      end,
      validate = function()
        if not vim.api.nvim_win_is_valid(winnr) then
          return "The window is not valid, winnr=" .. winnr .. "."
        end
      end,
    })

    if source == "neotree" then
      local is_floating = eve.win.is_floating(winnr) ---@type boolean
      winline:place("center", c.neotree(position, is_floating and "float" or "left"), 100)
    else
      winline
        ---
        :place("left", c.dirpath(position), 95)
        :place("left", c.filename(position), 100)
        :place("left", c.lsp_symbols(position), 90)
        ---
        :place("center", c.debug_render_count(position), 100)
      ---
      -- :place("right", c.dirpath_prominent(position), 100)
    end
    winline_map[winnr] = winline
  end

  if meta ~= nil then
    local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
    if meta.winline_bufnr ~= bufnr then
      meta.winline_bufnr = bufnr
      meta.lsp_symbols = {}
      vim.wo[winnr].winbar = winline:render_immediately()
    end
  end
  return winline
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
    if vim.o.showtabline == 0 or eve.win.is_floating(winnr) then
      local winline = resolve_winline_scheduler(winnr, "neotree") ---@type eve.ux.INvimbar|nil
      if winline ~= nil then
        winline:render()
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
      if text:sub(1, #eve.env.HOME_NVIM_CONFIG) == eve.env.HOME_NVIM_CONFIG then
        text = "<NVIM_HOME>" .. text:sub(#eve.env.HOME_NVIM_CONFIG + 1)
      end
      local winbar = "diffview://" .. text
      vim.wo[winnr].winbar = txt(winbar, "f_wl_text")
    end
    return
  end
  if filepath:sub(1, 11) == "gitsigns://" then
    local text = filepath:sub(12) ---@type string
    if text:sub(1, #eve.env.HOME_NVIM_CONFIG) == eve.env.HOME_NVIM_CONFIG then
      text = "<NVIM_HOME>" .. text:sub(#eve.env.HOME_NVIM_CONFIG + 1)
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

  local winline = resolve_winline_scheduler(winnr, "sourcefile") ---@type eve.ux.INvimbar|nil
  if winline ~= nil then
    winline:render()
    return
  end

  if not eve.filetype.is_not_sourcefile(filetype) then
    vim.wo[winnr].winbar = txt(filepath, "f_wl_text")
    return
  end
end

eve.state.status.dirty_winline_nr:subscribe(
  eve.std.Subscriber.new({
    on_next = function(winnr, winnr_prev)
      render(winnr)
      if winnr_prev ~= winnr then
        render(winnr_prev)
      end
    end,
  }),
  true
)

local states = require("fml.dressing.nvimbar.state")
local c = require("fml.dressing.nvimbar.components")

local txt = eve.nvim.txt
local position = "f_wl" ---@type eve.ux.nvimbar.Position

---@param winnr                         integer
---@param source                        "sourcefile"|"neotree"
---@return eve.ux.INvimbar|nil
local function resolve_nvimbar(winnr, source)
  local winline_map = states.winline_map ---@type table<integer, fml.dressing.nvimbar.state.IWinline>
  local winline = winline_map[winnr] ---@type fml.dressing.nvimbar.state.IWinline|nil
  if winline == nil or winline.nvimbar:is_disposed() then
    local nvimbar = nil ---@type eve.ux.INvimbar|nil
    nvimbar = eve.ux.Nvimbar.new({
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
        if nvimbar == nil or nvimbar:is_disposed() then
          return
        end

        if not vim.api.nvim_win_is_valid(winnr) then
          nvimbar:dispose()
          nvimbar = nil
          return
        end

        if source == "sourcefile" then
          -- Quick rerender the nvimbar before the pre_task done to make the ui quick refresh.
          local result = nvimbar:render_immediately()
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
        if nvimbar == nil or nvimbar:is_disposed() then
          return
        end

        if not vim.api.nvim_win_is_valid(winnr) then
          nvimbar:dispose()
          nvimbar = nil
          return
        end

        local result = nvimbar:snapshot() ---@type string
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
      nvimbar:place("center", c.neotree(position, is_floating and "float" or "left"), 100)
    else
      nvimbar
        ---
        :place("left", c.dirpath(position), 95)
        :place("left", c.filename(position), 100)
        :place("left", c.lsp_symbols(position), 90)
        ---
        :place("center", c.debug_render_count(position), 100)
      ---
      -- :place("right", c.dirpath_prominent(position), 100)
    end

    local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
    if winline == nil then
      ---@type fml.dressing.nvimbar.state.IWinline
      winline = {
        bufnr = bufnr,
        nvimbar = nvimbar,
      }
    else
      winline.bufnr = bufnr
      winline.nvimbar = nvimbar
    end
    winline_map[winnr] = winline
  end

  local nvimbar = winline.nvimbar ---@type eve.ux.INvimbar
  local meta = eve.state.win.resolve(winnr) ---@type eve.state.win.meta.state|nil
  if meta ~= nil then
    local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
    if winline.bufnr ~= bufnr then
      winline.bufnr = bufnr
      meta.lsp_symbols = {}
      vim.wo[winnr].winbar = nvimbar:render_immediately()
    end
  end
  return nvimbar
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
      local nvimbar = resolve_nvimbar(winnr, "neotree") ---@type eve.ux.INvimbar|nil
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

  local nvimbar = resolve_nvimbar(winnr, "sourcefile") ---@type eve.ux.INvimbar|nil
  if nvimbar ~= nil then
    nvimbar:render()
    return
  end

  if eve.filetype.is_sourcefile(filetype) then
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

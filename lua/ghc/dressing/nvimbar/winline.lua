local env = require("eve.lib.env")
local Subscriber = require("eve.lib.collection.subscriber")
local Nvimbar = require("eve.lib.ux.nvimbar")
local status = require("eve.builtin.status")
local state = require("eve.state")
local c = require("ghc.dressing.nvimbar.components")

local devmode = state.state.flight.devmode:snapshot() ---@type boolean
local position = "f_wl" ---@type eve.lib.ux.nvimbar.Position

---@param winnr                         integer
---@return eve.lib.ux.INvimbar|nil
local function resolve_winline_scheduler(winnr)
  local meta = eve.win.resolve(winnr) ---@type eve.t.state.state.win.IMeta|nil
  if meta == nil then
    return
  end

  if meta.winline == nil then
    local winline ---@type eve.lib.ux.INvimbar
    winline = Nvimbar.new({
      name = "winline_" .. winnr,
      component_sep = "",
      component_sep_hlname = position .. "_bg",
      component_sep_hlname_active = position .. "_bg",
      render_delay = 256,
      silent = not devmode,
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
        local winnr_cur = eve.tab.get_current_winnr() or 0 ---@type integer
        return winnr_cur > 0 and winnr_cur == context.winnr
      end,
      pre_task = function(callback)
        if vim.api.nvim_win_is_valid(winnr) then
          eve.win.locate_symbols(winnr, function(err)
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
        end
      end,
      trigger_rerender = function()
        if vim.api.nvim_win_is_valid(winnr) then
          local result = winline:snapshot() ---@type string
          vim.wo[winnr].winbar = result
        end
      end,
      validate = function()
        if not vim.api.nvim_win_is_valid(winnr) then
          return "The window is not valid, winnr=" .. winnr .. "."
        end
      end,
    })

    winline
      ---
      -- :register(c.dirpath(position), "left")
      :register(c.filename(position), "left")
      ---
      :register(c.debug_render_count(position), "center")
      :register(c.lsp_symbols(position), "left")
      ---
      ---
      :register(c.dirpath_prominent(position), "right")
    meta.winline = winline
  end

  local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
  if meta.winline_bufnr ~= bufnr then
    meta.lsp_symbols = {}
    meta.winline_bufnr = bufnr
    vim.wo[winnr].winbar = meta.winline:render_immedately()
  end

  return meta.winline
end

---@param winnr                         integer|nil
---@return nil
local function render(winnr)
  if winnr == nil or winnr < 1 or not vim.api.nvim_win_is_valid(winnr) then
    return
  end

  local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
  local filepath = vim.api.nvim_buf_get_name(bufnr) ---@type string

  if filepath:sub(1, 11) == "diffview://" then
    local should_show_winline = filepath:sub(1, 19) ~= "diffview:///panels/" ---@type boolean
    if should_show_winline then
      local text = filepath:sub(12) ---@type string
      if text:sub(1, #env.HOME_NVIM_CONFIG) == env.HOME_NVIM_CONFIG then
        text = "<NVIM_HOME>" .. text:sub(#env.HOME_NVIM_CONFIG + 1)
      end
      local winbar = "diffview://" .. text
      vim.wo[winnr].winbar = Nvimbar.txt(winbar, "f_wl_text")
    end
    return
  end

  if filepath:sub(1, 11) == "gitsigns://" then
    local text = filepath:sub(12) ---@type string
    if text:sub(1, #env.HOME_NVIM_CONFIG) == env.HOME_NVIM_CONFIG then
      text = "<NVIM_HOME>" .. text:sub(#env.HOME_NVIM_CONFIG + 1)
    end
    local winbar = "gitsigns://" .. text
    vim.wo[winnr].winbar = Nvimbar.txt(winbar, "f_wl_text")
    return
  end

  local winline = resolve_winline_scheduler(winnr) ---@type eve.lib.ux.INvimbar|nil
  if winline ~= nil then
    winline:render()
    return
  end

  local filetype = vim.bo[bufnr].filetype ---@type string
  if eve.filetype.is_plain_file(filetype) then
    vim.wo[winnr].winbar = Nvimbar.txt(filepath, "f_wl_text")
    return
  end
end

status.winline_dirty_nr:subscribe(
  Subscriber.new({
    on_next = function(winnr, winnr_prev)
      render(winnr)
      if winnr_prev ~= winnr then
        render(winnr_prev)
      end
    end,
  }),
  true
)

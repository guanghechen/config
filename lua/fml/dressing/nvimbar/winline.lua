local env = require("eve.builtin.env")
local Subscriber = require("eve.collection.subscriber")
local fts = require("eve.constant.filetype")

local checks = require("eve.lib.checks")
local Nvimbar = require("fml.ux.nvimbar")
local state = require("eve.state")
local c = require("fml.dressing.nvimbar.components")

local position = "f_wl" ---@type fml.ux.nvimbar.Position

---@param winnr                         integer
---@return fml.ux.INvimbar|nil
local function resolve_winline_scheduler(winnr)
  local meta = state.win.resolve(winnr) ---@type eve.t.state.win.meta.state|nil
  if meta == nil then
    return
  end

  if meta.winline == nil then
    local winline ---@type fml.ux.INvimbar
    winline = Nvimbar.new({
      name = "winline_" .. winnr,
      comp_sep = "",
      comp_sep_hlname = position .. "_bg",
      comp_sep_hlname_active = position .. "_bg",
      render_delay = 256,
      silent = function()
        local devmode = state.flight.devmode:snapshot() ---@type boolean
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
        local winnr_cur = state.tab.get_current_winnr() or 0 ---@type integer
        return winnr_cur > 0 and winnr_cur == context.winnr
      end,
      pre_task = function(callback)
        if vim.api.nvim_win_is_valid(winnr) then
          state.win.locate_symbols(winnr, function(err)
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
      :place("left", c.dirpath(position), 95)
      :place("left", c.filename(position), 100)
      :place("left", c.lsp_symbols(position), 90)
      ---
      :place("center", c.debug_render_count(position), 100)
      ---
      :place("right", c.focused_indicator(position), 100)
    -- :place("right", c.dirpath_prominent(position), 100)
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
  if winnr == nil or winnr < 1 or not checks.is_win_valid(winnr) then
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

  local winline = resolve_winline_scheduler(winnr) ---@type fml.ux.INvimbar|nil
  if winline ~= nil then
    winline:render()
    return
  end

  local filetype = vim.bo[bufnr].filetype ---@type string
  if fts.is_plain_file(filetype) then
    vim.wo[winnr].winbar = Nvimbar.txt(filepath, "f_wl_text")
    return
  end
end

state.status.dirty_winline_nr:subscribe(
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

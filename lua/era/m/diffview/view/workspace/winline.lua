---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.diffview.view.workspace.winline" ---@type string

---History pane winline.
---@class era.m.diffview.view.workspace.winline
local M = {}

local POSITION = "f_wl" ---@type stl.t.NvimbarPositionEnum

---@param ctx                            era.m.diffview.view.commits.IContext
---@return era.m.nvimbar.IRawComponent
function M.status_component(ctx)
  local component = {
    name = "diffview:history_status",
    atomic = false,
    render = function(_, remain_width)
      local state = ctx.state
      local title_text = " " .. (ctx.layout.title or "History") .. " " ---@type string
      local count_text = string.format("%s %d", stl.icon.git.Git, state:get_commits_total()) ---@type string
      local page = state:get_commits_page() ---@type integer
      local page_count = state:get_commits_page_count() ---@type integer
      local page_text = string.format("%s %d/%d ", stl.icon.ui.TabPage, page, page_count) ---@type string
      local separator = " │ " ---@type string

      local show_count = vim.api.nvim_strwidth(title_text .. count_text .. separator .. page_text) <= remain_width
      if vim.api.nvim_strwidth(title_text .. page_text) > remain_width then
        title_text = ""
      end

      local text = title_text ---@type string
      local hl_text = stl.nvim.fn.txt(title_text, POSITION .. "_sidebar_pink") ---@type string
      if show_count then
        text = text .. count_text .. separator
        hl_text = hl_text
          .. stl.nvim.fn.txt(count_text, POSITION .. "_sidebar_pink")
          .. stl.nvim.fn.txt(separator, POSITION .. "_sidebar_dim")
      end
      text = text .. page_text
      hl_text = hl_text .. stl.nvim.fn.txt(page_text, POSITION .. "_sidebar_dim")
      return text, hl_text, true
    end,
  } ---@type era.m.nvimbar.IRawComponent
  return component
end

---@param ctx                            era.m.diffview.view.commits.IContext
---@return era.m.nvimbar.Nvimbar|nil
local function resolve_nvimbar(ctx)
  local winnr = ctx.layout.commits_winnr ---@type integer|nil
  if not winnr or not vim.api.nvim_win_is_valid(winnr) then
    return nil
  end

  local meta = dot.win.resolve(winnr, false) ---@type dot.win.IMeta|nil
  if not meta then
    return nil
  end
  local winline = meta.winline ---@type dot.win.IWinline|nil
  if winline and not winline.nvimbar:isdisposed() then
    return winline.nvimbar
  end

  local nvimbar ---@type era.m.nvimbar.Nvimbar
  nvimbar = era.m.nvimbar.Nvimbar.new({
    name = string.format("diffview_history#%d#winbar", ctx.layout.tabnr),
    comp_sep = "",
    comp_sep_hlname = POSITION .. "_bg",
    comp_sep_hlname_active = POSITION .. "_bg",
    delay = 128,
    silent = stl.fn.falsy,
    get_max_width = function()
      return vim.api.nvim_win_is_valid(winnr) and vim.api.nvim_win_get_width(winnr) or 0
    end,
    get_preset_context = function()
      return { winnr = winnr }
    end,
    is_active = function(context)
      return context.winnr == vim.api.nvim_get_current_win()
    end,
    on_fulfilled = function(result)
      if vim.api.nvim_win_is_valid(winnr) and ctx.layout.commits_winnr == winnr then
        vim.api.nvim_set_option_value("winbar", result, { win = winnr, scope = "local" })
      end
    end,
    validate = function()
      if not vim.api.nvim_win_is_valid(winnr) or ctx.layout.commits_winnr ~= winnr then
        return "History window is not valid"
      end
    end,
  })
  nvimbar
    :place("left", M.status_component(ctx), 100)
    :place("right", era.m.nvimbar.component.nvim.search_count(POSITION), 120)

  winline = winline or { bufnr = vim.api.nvim_win_get_buf(winnr), nvimbar = nvimbar }
  winline.bufnr = vim.api.nvim_win_get_buf(winnr)
  winline.nvimbar = nvimbar
  meta.winline = winline
  return nvimbar
end

---@param ctx                            era.m.diffview.view.commits.IContext
function M.render(ctx)
  local nvimbar = resolve_nvimbar(ctx)
  if nvimbar then
    nvimbar:render()
  end
end

---@param ctx                            era.m.diffview.view.commits.IContext
function M.setup(ctx)
  M.render(ctx)
  stl.fn.observe({ ctx.state.commits_page, ctx.state.commits_total }, function()
    M.render(ctx)
  end)
end

return M

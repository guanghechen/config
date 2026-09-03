---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.diffview.view.workspace.winline" ---@type string

---Workspace sidebar winlines.
---@class era.m.diffview.view.workspace.winline
local M = {}

local POSITION = "f_wl" ---@type stl.t.NvimbarPositionEnum

---@param ctx                            era.m.diffview.view.workspace.IContext
---@param stage_type                     stl.m.diffview.StageTypeEnum
---@return era.m.nvimbar.IRawComponent
function M.changes_status_component(ctx, stage_type)
  local component = {
    name = "diffview:" .. stage_type .. "_status",
    atomic = true,
    render = function()
      local count = 0 ---@type integer
      local show_untracked = dot.context.diffview.flag_untracked:snapshot() ---@type boolean
      for _, entry in ipairs(ctx.state:get_entries()) do
        if entry.stage_type == stage_type and (show_untracked or entry.status ~= "?") then
          count = count + 1
        end
      end

      local label = stage_type == "staged" and "Staged" or "Unstaged" ---@type string
      local text = string.format(" %s %s (%d) ", stl.icon.git.Git, label, count) ---@type string
      return text, stl.nvim.fn.txt(text, POSITION .. "_sidebar_pink"), true
    end,
  } ---@type era.m.nvimbar.IRawComponent
  return component
end

---@param ctx                            era.m.diffview.view.commits.IContext
---@return era.m.nvimbar.IRawComponent
function M.history_status_component(ctx)
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

---@param winnr                          integer
---@param name                           string
---@param status_component               era.m.nvimbar.IRawComponent
---@param validate                       fun(): string|nil
---@return era.m.nvimbar.Nvimbar|nil
local function resolve_nvimbar(winnr, name, status_component, validate)
  if not vim.api.nvim_win_is_valid(winnr) then
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
    name = name,
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
      if validate() == nil then
        vim.api.nvim_set_option_value("winbar", result, { win = winnr, scope = "local" })
      end
    end,
    validate = validate,
  })
  nvimbar:place("left", status_component, 100):place("right", era.m.nvimbar.component.nvim.search_count(POSITION), 120)

  winline = winline or { bufnr = vim.api.nvim_win_get_buf(winnr), nvimbar = nvimbar }
  winline.bufnr = vim.api.nvim_win_get_buf(winnr)
  winline.nvimbar = nvimbar
  meta.winline = winline
  local source_bufnr = winline.bufnr ---@type integer
  winline.fork = function(target_winnr)
    return resolve_nvimbar(target_winnr, string.format("%s#fork#%d", name, target_winnr), status_component, function()
      local source_error = validate()
      if source_error ~= nil then
        return source_error
      end
      if not vim.api.nvim_win_is_valid(target_winnr) or vim.api.nvim_win_get_buf(target_winnr) ~= source_bufnr then
        return "Forked Winline window is not valid"
      end
    end)
  end
  return nvimbar
end

---@param ctx                            era.m.diffview.view.workspace.IContext
---@param stage_type                     stl.m.diffview.StageTypeEnum
---@return era.m.nvimbar.Nvimbar|nil
local function resolve_changes_nvimbar(ctx, stage_type)
  local pane = ctx.layout.changes[stage_type]
  local winnr = pane.winnr ---@type integer|nil
  if not winnr then
    return nil
  end
  local label = stage_type == "staged" and "Staged" or "Unstaged" ---@type string
  return resolve_nvimbar(
    winnr,
    string.format("diffview_%s#%d#winbar", stage_type, ctx.layout.tabnr),
    M.changes_status_component(ctx, stage_type),
    function()
      if not vim.api.nvim_win_is_valid(winnr) or pane.winnr ~= winnr then
        return label .. " window is not valid"
      end
    end
  )
end

---@param ctx                            era.m.diffview.view.commits.IContext
---@return era.m.nvimbar.Nvimbar|nil
local function resolve_history_nvimbar(ctx)
  local winnr = ctx.layout.commits_winnr ---@type integer|nil
  if not winnr then
    return nil
  end
  return resolve_nvimbar(
    winnr,
    string.format("diffview_history#%d#winbar", ctx.layout.tabnr),
    M.history_status_component(ctx),
    function()
      if not vim.api.nvim_win_is_valid(winnr) or ctx.layout.commits_winnr ~= winnr then
        return "History window is not valid"
      end
    end
  )
end

---@param ctx                            era.m.diffview.view.workspace.IContext
function M.render_changes(ctx)
  for _, stage_type in ipairs({ "staged", "unstaged" }) do
    local nvimbar = resolve_changes_nvimbar(ctx, stage_type)
    if nvimbar then
      dot.win.render_winline(ctx.layout.changes[stage_type].winnr)
    end
  end
end

---@param ctx                            era.m.diffview.view.commits.IContext
function M.render_history(ctx)
  local nvimbar = resolve_history_nvimbar(ctx)
  if nvimbar then
    dot.win.render_winline(ctx.layout.commits_winnr)
  end
end

---@param ctx                            era.m.diffview.view.workspace.IContext
function M.setup(ctx)
  M.render_changes(ctx)
  local history = assert(ctx.history, "Workspace History context is required")
  M.render_history(history)
  stl.fn.observe({ history.state.commits_page, history.state.commits_total }, function()
    M.render_history(history)
  end)
end

return M

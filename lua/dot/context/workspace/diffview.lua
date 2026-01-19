-- LayoutTypeEnum and PanelViewTypeEnum are defined in lua/__types__/stl/m/diffview.lua

---@class dot.context.diffview.data
---@field public flag_fold_unchanges     boolean
---@field public flag_foldempty           boolean
---@field public flag_panel_viewtype      stl.m.diffview.PanelViewTypeEnum
---@field public flag_commits_layout      stl.m.diffview.CommitsPanelLayoutEnum
---@field public layout_type              stl.m.diffview.LayoutTypeEnum
---@field public panel_width              integer
---@field public commits_layout           integer                           1-5

---@class dot.context.diffview.state
---@field public flag_fold_unchanges     stl.c.Observable
---@field public flag_foldempty           stl.c.Observable
---@field public flag_panel_viewtype      stl.c.Observable
---@field public flag_commits_layout      stl.c.Observable
---@field public layout_type              stl.c.Observable
---@field public panel_width              stl.c.Observable
---@field public commits_layout           stl.c.Observable

---@class dot.context.diffview : dot.context.diffview.state
---@field public defaults                 fun(): dot.context.diffview.data
---@field public dump                     fun(): dot.context.diffview.data
---@field public load                     fun(data: unknown): nil
---@field public normalize                fun(data: unknown): dot.context.diffview.data
local M = {}

---@return dot.context.diffview.data
function M.defaults()
  ---@type dot.context.diffview.data
  return {
    flag_fold_unchanges = true,
    flag_foldempty = true,
    flag_panel_viewtype = "tree",
    flag_commits_layout = "left",
    layout_type = "diff2_hor",
    panel_width = 40,
    commits_layout = 1,
  }
end

---@param data                            any
---@return dot.context.diffview.data
function M.normalize(data)
  local resolved = M.defaults() ---@type dot.context.diffview.data
  if type(data) == "table" then
    if type(data.flag_fold_unchanges) == "boolean" then
      resolved.flag_fold_unchanges = data.flag_fold_unchanges
    end
    if type(data.flag_foldempty) == "boolean" then
      resolved.flag_foldempty = data.flag_foldempty
    end
    if type(data.flag_panel_viewtype) == "string" then
      if data.flag_panel_viewtype == "tree" or data.flag_panel_viewtype == "list" then
        resolved.flag_panel_viewtype = data.flag_panel_viewtype
      end
    end
    if type(data.flag_commits_layout) == "string" then
      if data.flag_commits_layout == "left" or data.flag_commits_layout == "top" then
        resolved.flag_commits_layout = data.flag_commits_layout
      end
    end
    if type(data.layout_type) == "string" then
      local valid_types = {
        diff1 = true,
        diff2_hor = true,
        diff2_ver = true,
        diff3_hor = true,
        diff3_ver = true,
        diff3_mixed = true,
        diff4_mixed = true,
      }
      if valid_types[data.layout_type] then
        resolved.layout_type = data.layout_type
      end
    end
    if type(data.panel_width) == "number" and data.panel_width > 0 then
      resolved.panel_width = math.floor(data.panel_width)
    end
    if type(data.commits_layout) == "number" and data.commits_layout >= 1 and data.commits_layout <= 5 then
      resolved.commits_layout = math.floor(data.commits_layout)
    end
  end

  ---@type dot.context.diffview.data
  return resolved
end

---@return dot.context.diffview.data
function M.dump()
  ---@type dot.context.diffview.data
  return {
    flag_fold_unchanges = M.flag_fold_unchanges:snapshot(),
    flag_foldempty = M.flag_foldempty:snapshot(),
    flag_panel_viewtype = M.flag_panel_viewtype:snapshot(),
    flag_commits_layout = M.flag_commits_layout:snapshot(),
    layout_type = M.layout_type:snapshot(),
    panel_width = M.panel_width:snapshot(),
    commits_layout = M.commits_layout:snapshot(),
  }
end

---@param raw_data                        any
---@return nil
function M.load(raw_data)
  local data = M.normalize(raw_data) ---@type dot.context.diffview.data

  M.flag_fold_unchanges:next(data.flag_fold_unchanges)
  M.flag_foldempty:next(data.flag_foldempty)
  M.flag_panel_viewtype:next(data.flag_panel_viewtype)
  M.flag_commits_layout:next(data.flag_commits_layout)
  M.layout_type:next(data.layout_type)
  M.panel_width:next(data.panel_width)
  M.commits_layout:next(data.commits_layout)
end

----------------------------------------------------------------------------------------------------

local _defaults = M.defaults() ---@type dot.context.diffview.data

---@type stl.c.Observable
M.flag_fold_unchanges = stl.c.Observable.from_value(_defaults.flag_fold_unchanges)

---@type stl.c.Observable
M.flag_foldempty = stl.c.Observable.from_value(_defaults.flag_foldempty)

---@type stl.c.Observable
M.flag_panel_viewtype = stl.c.Observable.from_value(_defaults.flag_panel_viewtype)

---@type stl.c.Observable
M.flag_commits_layout = stl.c.Observable.from_value(_defaults.flag_commits_layout)

---@type stl.c.Observable
M.layout_type = stl.c.Observable.from_value(_defaults.layout_type)

---@type stl.c.Observable
M.panel_width = stl.c.Observable.from_value(_defaults.panel_width)

---@type stl.c.Observable
M.commits_layout = stl.c.Observable.from_value(_defaults.commits_layout)

return M

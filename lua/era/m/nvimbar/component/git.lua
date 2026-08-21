local txt = stl.nvim.fn.txt
local hln_hunk_nav = "m_git_hunk_indicator" ---@type string

---@class era.m.nvimbar.component.git
local M = {}

---@param position                      stl.t.NvimbarPositionEnum
---@return era.m.nvimbar.IRawComponent
function M.branch(position)
  local hln_sep = position .. "_git_branch_sep" ---@type string
  local hln_text = position .. "_git_branch_text" ---@type string

  ---@type era.m.nvimbar.IRawComponent
  local component = {
    name = "git:branch",
    atomic = true,
    tight = true,
    will_change = function(context, prev_context)
      return prev_context == nil or context.git_branch ~= prev_context.git_branch
    end,
    render = function(context)
      if context.git_branch == nil then
        local text = stl.icon.symbols.sep_right ---@type string
        local hl_text = txt(stl.icon.symbols.sep_right, hln_sep) ---@type string
        return text, hl_text, true
      end

      local text = " " .. stl.icon.git.Branch .. " " .. context.git_branch .. stl.icon.symbols.sep_right ---@type string
      local hl_text = txt(" " .. stl.icon.git.Branch .. " " .. context.git_branch, hln_text)
        .. txt(stl.icon.symbols.sep_right, hln_sep)
      return text, hl_text, true
    end,
  }
  return component
end

---@param winnr                         integer
---@return string|nil text
---@return string|nil hl_text
function M.render_hunk_nav(winnr)
  local index, total = era.m.git.hunk_nav.get_nav_indicator(winnr) ---@type integer|nil, integer|nil
  if index == nil or total == nil then
    return nil, nil
  end

  local text = string.format("%s %d/%d", stl.icon.git.Git, index, total) ---@type string
  return text, txt(text, hln_hunk_nav)
end

---@param _position                     stl.t.NvimbarPositionEnum
---@return era.m.nvimbar.IRawComponent
function M.hunk_nav(_position)
  ---@type era.m.nvimbar.IRawComponent
  local component = {
    name = "git:hunk_nav",
    atomic = true,
    condition = function(context)
      local text = M.render_hunk_nav(context.winnr) ---@type string|nil
      return text ~= nil
    end,
    render = function(context)
      local text, hl_text = M.render_hunk_nav(context.winnr) ---@type string|nil, string|nil
      if text == nil or hl_text == nil then
        return "", "", true
      end
      return text, hl_text, true
    end,
  }
  return component
end

return M

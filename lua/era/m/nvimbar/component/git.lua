---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.nvimbar.component.git" ---@type string

local txt = stl.nvim.fn.txt
local hln_hunk_nav = "m_git_hunk_indicator" ---@type string

---@return string|nil
local function get_branch()
  local state = package.loaded["era.m.git.state"]
  local branch = state and state.get_branch() or nil
  return branch ~= "" and branch or nil
end

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

    tight = true,
    will_change = function(_, _, snapshot)
      return get_branch() ~= snapshot.branch
    end,
    refresh = function()
      local branch = get_branch()
      if branch == nil then
        local text = stl.icon.symbols.sep_right ---@type string
        local hl_text = txt(stl.icon.symbols.sep_right, hln_sep) ---@type string
        return { text = text, hltext = hl_text }
      end

      local text = " " .. stl.icon.git.Branch .. " " .. branch .. stl.icon.symbols.sep_right ---@type string
      local hl_text = txt(" " .. stl.icon.git.Branch .. " " .. branch, hln_text)
        .. txt(stl.icon.symbols.sep_right, hln_sep)
      return { text = text, hltext = hl_text, branch = branch }
    end,
  }
  return component
end

---@param winnr                         integer
---@return string|nil text
---@return string|nil hl_text
function M.render_hunk_nav(winnr)
  local nav = package.loaded["era.m.git.hunk_nav"]
  if nav == nil then
    return nil, nil
  end
  local index, total = nav.get_nav_indicator(winnr) ---@type integer|nil, integer|nil
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

    condition = function(context)
      local text = M.render_hunk_nav(context.winnr) ---@type string|nil
      return text ~= nil
    end,
    refresh = function(context)
      local text, hl_text = M.render_hunk_nav(context.winnr) ---@type string|nil, string|nil
      if text == nil or hl_text == nil then
        return { text = "", hltext = "" }
      end
      return { text = text, hltext = hl_text }
    end,
  }
  return component
end

return M

---@return nil
local function mock_miniicons()
  if package.loaded["mini.icons"] then
    return
  end

  local MiniIcons = {}
  _G.MiniIcons = MiniIcons
  package.loaded["mini.icons"] = MiniIcons

  ---@param category                    string
  ---@param name                        string
  ---@param filetype                    ?string
  ---@return string
  ---@return string
  ---@return boolean
  function MiniIcons.get(category, name, filetype)
    return stl.fileicon.get(category, name, filetype)
  end
end

return mock_miniicons

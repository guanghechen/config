---@class fml.dressing.plugin
local M = {}

---@return nil
function M.mock_dressing()
  if package.loaded["dressing"] then
    return
  end

  package.loaded["dressing.nvim"] = {}
end

---@return nil
function M.mock_miniicons()
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
    return std.fileicon.get(category, name, filetype)
  end
end

---@return nil
function M.mock_web_devicons()
  if package.loaded["nvim-web-devicons"] then
    return
  end

  package.loaded["nvim-web-devicons"] = {
    get_icon = function(name, ext, opts)
      local is_file = type(name) == "string"
      local category = is_file and "file" or "extension"
      local icon, hl, is_default = std.fileicon.get(category, is_file and name or ext)
      if is_default and (opts == nil or not opts.default) then
        return nil, nil
      end
      return icon, hl
    end,
  }
end

---@return nil
function M.mock_winpicker()
  if package.loaded["window-picker"] then
    return
  end

  package.loaded["window-picker"] = {
    pick_window = function()
      local winnr_source = vim.api.nvim_get_current_win() ---@type integer
      return eve.win.pick_projectable(winnr_source)
    end,
  }
end

return M

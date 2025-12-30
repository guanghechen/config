---@return nil
local function mock_web_devicons()
  if package.loaded["nvim-web-devicons"] then
    return
  end

  package.loaded["nvim-web-devicons"] = {
    get_icon = function(name, ext, opts)
      local is_file = type(name) == "string"
      local category = is_file and "file" or "extension"
      local icon, hl, is_default = stl.fileicon.get(category, is_file and name or ext)
      if is_default and (opts == nil or not opts.default) then
        return nil, nil
      end
      return icon, hl
    end,
  }
end

return mock_web_devicons

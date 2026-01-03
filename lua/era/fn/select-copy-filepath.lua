local __module_name__ = "era.fn.select_copy_filepath" ---@type string

---@class era.fn.select_copy_filepath.IParams : vim.api.keyset.win_config
---@field public filepath               string
---@field public position               era.m.select.PositionEnum|nil
---@field public on_completed           ?fun(): nil

---@param params                        era.fn.select_copy_filepath.IParams
---@return integer
local function select_copy_filepath(params)
  local filepath = params.filepath ---@type string
  local on_completed = params.on_completed or stl.fn.noop ---@type fun(): nil

  return era.m.select.open({
    title = "Copy filepath",
    position = params.position or "cursor",
    relative = params.relative,
    win = params.win,
    row = params.row,
    col = params.col,
    items = {
      { key = "1", text = "absolute" },
      { key = "2", text = "relative" },
      { key = "3", text = "filename" },
    },
    default_key = "2",
    on_choice = function(item)
      if item ~= nil then
        if item.key == "1" then
          local content = filepath ---@type string

          stl.nvim.fn.copy(content)
          stl.reporter.info({
            from = __module_name__,
            message = "Copied absolute filepath: " .. content,
          })
        elseif item.key == "2" then
          local cwd = dot.path.cwd() ---@type string
          local content = dot.path.relative(cwd, filepath, "/") ---@type string

          stl.nvim.fn.copy(content)
          stl.reporter.info({
            from = __module_name__,
            message = "Copied relative filepath: " .. content,
          })
        elseif item.key == "3" then
          local content = yoz.path.basename(filepath) ---@type string
          stl.nvim.fn.copy(content)
          stl.reporter.info({
            from = __module_name__,
            message = "Copied filename: " .. content,
          })
        end
      end

      on_completed()
    end,
  })
end

return select_copy_filepath

---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.fn.select_copy_filepaths" ---@type string

---@class era.fn.select_copy_filepaths.IParams : vim.api.keyset.win_config
---@field public filepaths                string[]
---@field public position                 era.m.select.PositionEnum|nil
---@field public on_completed             ?fun(): nil

---@param params                        era.fn.select_copy_filepaths.IParams
---@return integer
local function select_copy_filepaths(params)
  local filepaths = params.filepaths ---@type string[]
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
        local contents = {} ---@type string[]
        local cwd = dot.path.cwd() ---@type string

        for _, filepath in ipairs(filepaths) do
          if item.key == "1" then
            contents[#contents + 1] = filepath
          elseif item.key == "2" then
            contents[#contents + 1] = dot.path.relative(cwd, filepath, "/")
          elseif item.key == "3" then
            contents[#contents + 1] = yoz.path.basename(filepath)
          end
        end

        local content = table.concat(contents, "\n") ---@type string
        stl.nvim.fn.copy(content)

        ---@type string
        local item_text = item.key == "1" and "absolute" or item.key == "2" and "relative" or "filename"

        if #filepaths == 1 then
          stl.reporter.info({
            from = __module_name__,
            message = string.format("Copied %s: %s", item_text, content),
          })
        else
          stl.reporter.info({
            from = __module_name__,
            message = string.format("Copied %d %s path(s)", #filepaths, item_text),
          })
        end
      end

      on_completed()
    end,
  })
end

return select_copy_filepaths

local __module_name__ = "dot.fn.select_copy_filepaths" ---@type string

---@class dot.fn.select_copy_filepaths.IParams
---@field public filepaths                string[]
---@field public winopts                  vim.api.keyset.win_config|nil
---@field public on_completed             ?fun(): nil

---@param params                        dot.fn.select_copy_filepaths.IParams
---@return integer
local function select_copy_filepaths(params)
  local filepaths = params.filepaths ---@type string[]
  local winopts = params.winopts or {} ---@type vim.api.keyset.win_config
  local on_completed = params.on_completed or ark.fn.noop ---@type fun(): nil

  local popup = dot.ux.Select.new({
    wincfg = vim.tbl_extend("force", {
      width = 16,
      title = "Copy filepath",
    }, winopts),
    item_present_uuid = "relative",
    items = {
      { uuid = "absolute", text = "absolute" },
      { uuid = "relative", text = "relative" },
      { uuid = "filename", text = "filename" },
    },
    on_select = function(widget, item)
      widget:destroy()

      if item ~= nil then
        local contents = {} ---@type string[]
        local cwd = dot.path.cwd() ---@type string

        for _, filepath in ipairs(filepaths) do
          if item.uuid == "absolute" then
            contents[#contents + 1] = filepath
          elseif item.uuid == "relative" then
            contents[#contents + 1] = dot.path.relative(cwd, filepath, "/")
          elseif item.uuid == "filename" then
            contents[#contents + 1] = yoz.path.basename(filepath)
          end
        end

        local content = table.concat(contents, "\n") ---@type string
        ark.nvim.copy(content)

        if #filepaths == 1 then
          ark.reporter.info({
            from = __module_name__,
            message = string.format("Copied %s: %s", item.uuid, content),
          })
        else
          ark.reporter.info({
            from = __module_name__,
            message = string.format("Copied %d %s path(s)", #filepaths, item.uuid),
          })
        end
      end

      on_completed()
    end,
  })
  return popup:focus()
end

return select_copy_filepaths

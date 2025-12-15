local __module_name__ = "dot.fn.select_copy_filepath" ---@type string

---@class dot.fn.select_copy_filepath.IParams
---@field public filepath               string
---@field public winopts                vim.api.keyset.win_config|nil
---@field public on_completed           ?fun(): nil

---@param params                        dot.fn.select_copy_filepath.IParams
---@return integer
local function select_copy_filepath(params)
  local filepath = params.filepath ---@type string
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
        if item.uuid == "absolute" then
          local content = filepath ---@type string

          ark.nvim.copy(content)
          ark.reporter.info({
            from = __module_name__,
            message = "Copied absolute filepath: " .. content,
          })
        elseif item.uuid == "relative" then
          local cwd = dot.path.cwd() ---@type string
          local content = dot.path.relative(cwd, filepath, "/") ---@type string

          ark.nvim.copy(content)
          ark.reporter.info({
            from = __module_name__,
            message = "Copied relative filepath: " .. content,
          })
        elseif item.uuid == "filename" then
          local content = yoz.path.basename(filepath) ---@type string
          ark.nvim.copy(content)
          ark.reporter.info({
            from = __module_name__,
            message = "Copied filename: " .. content,
          })
        else
          ark.reporter.warn({
            from = __module_name__,
            message = "Unknown item uuid: " .. item.uuid,
          })
        end
      end

      on_completed()
    end,
  })
  return popup:focus()
end

return select_copy_filepath

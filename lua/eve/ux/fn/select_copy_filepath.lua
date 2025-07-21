local __module_name__ = "eve.ux.fn.select_copy_filepath" ---@type string

---@class eve.ux.fn.select_copy_filepath.IParams
---@field public filepath               string
---@field public winopts                vim.api.keyset.win_config|nil
---@field public on_completed           ?fun(): nil

---@param params                        eve.ux.fn.select_copy_filepath.IParams
---@return integer
local function select_copy_filepath(params)
  local filepath = params.filepath ---@type string
  local winopts = params.winopts or {} ---@type vim.api.keyset.win_config
  local on_completed = params.on_completed or std.fn.noop ---@type fun(): nil

  local popup = eve.ux.SelectPopup.new({
    wincfg = vim.tbl_extend("force", {
      width = 16,
      title = "Copy filepath",
    }, winopts),
    item_present_uuid = "relative",
    items = {
          -- stylua: ignore start
          { uuid = "absolute", text = "absolute", },
          { uuid = "relative", text = "relative", },
          { uuid = "filename", text = "filename",          },
      -- stylua: ignore end
    },
    on_select = function(widget, item)
      widget:destroy()

      if item ~= nil then
        if item.uuid == "absolute" then
          local content = filepath ---@type string

          vim.fn.setreg("+", content)
          std.reporter.info({
            from = __module_name__,
            message = "Copied absolute filepath: " .. content,
          })
        elseif item.uuid == "relative" then
          local cwd = std.path.cwd() ---@type string
          local content = std.path.relative(cwd, filepath, true) ---@type string

          vim.fn.setreg("+", content)
          std.reporter.info({
            from = __module_name__,
            message = "Copied relative filepath: " .. content,
          })
        elseif item.uuid == "filename" then
          local content = std.path.basename(filepath) ---@type string
          vim.fn.setreg("+", content)
          std.reporter.info({
            from = __module_name__,
            message = "Copied filename: " .. content,
          })
        else
          std.reporter.warn({
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

local reporter = require("fml.std.reporter")

---@param name                          string
---@param fn                            fun(): nil
---@return nil
local function schedule_fn(name, fn)
  local lock = false
  local dirty = true

  local wrapped ---@type fun(): nil

  wrapped = function()
    vim.schedule(function()
      if lock then
        dirty = true
        return
      end

      local ok, result = pcall(fn)
      if not ok then
        reporter.error({
          from = name,
          subject = "schedule_fn",
          message = "Failed to run the fn.",
          details = { name = name, result = result },
        })
      end

      lock = false
      if dirty then
        dirty = false
        wrapped()
      end
    end)
  end
  return wrapped
end

return schedule_fn

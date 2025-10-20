local __module_name__ = "eve.builtin.ai" ---@type string

---@class eve.builtin.ai
local M = {}

---@param locations                     std.t.ILocation[]
---@return nil
function M.add_files_to_ai(locations)
  if #locations < 1 then
    std.reporter.warn({
      from = __module_name__,
      subject = "add_files_to_ai",
      message = "No valid locations provided.",
    })
    return
  end

  local lines = {} ---@type string[]
  local failures = {} ---@type { index: integer, error: string, location: std.t.ILocation }[]

  for index, location in ipairs(locations) do
    local text, err = std.uri.file_location(location)
    if text ~= nil then
      lines[#lines + 1] = text
    else
      failures[#failures + 1] = {
        index = index,
        error = err or "Unknown error.",
        location = location,
      }
    end
  end

  if #lines < 1 then
    std.reporter.warn({
      from = __module_name__,
      subject = "add_files_to_ai",
      message = "No locations could be stringified.",
    })
    return
  end

  if #failures > 0 then
    std.reporter.warn({
      from = __module_name__,
      subject = "add_files_to_ai",
      message = string.format("Skipped %d invalid location%s.", #failures, #failures == 1 and "" or "s"),
      details = { failures = failures },
    })
  end

  local payload = table.concat(lines, "\n") ---@type string
  local copy_failures = {} ---@type string[]
  local registers = { '"', "+" } ---@type string[]
  for _, register in ipairs(registers) do
    local ok_register, register_err = pcall(vim.fn.setreg, register, payload)
    if not ok_register then
      copy_failures[#copy_failures + 1] = string.format("%s register: %s", register, register_err)
    end
  end

  if #copy_failures > 0 then
    std.reporter.warn({
      from = __module_name__,
      subject = "add_files_to_ai",
      message = "Copy failed: " .. table.concat(copy_failures, "; "),
    })
  else
    std.reporter.info({
      from = __module_name__,
      subject = "add_files_to_ai",
      message = "Locations copied to clipboard.",
    })
  end
end

return M

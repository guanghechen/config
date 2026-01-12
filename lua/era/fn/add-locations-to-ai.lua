---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.fn.add_locations_to_ai" ---@type string

---@param locations                     dot.t.ILocation[]
---@return nil
local function add_locations_to_ai(locations)
  if #locations < 1 then
    stl.reporter.warn({
      from = __module_name__,
      subject = "add_locations_to_ai",
      message = "No valid locations provided.",
    })
    return
  end

  local lines = {} ---@type string[]
  local failures = {} ---@type { index: integer, error: string, location: dot.t.ILocation }[]

  for index, location in ipairs(locations) do
    local text, err = dot.uri.file_location(location)
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
    stl.reporter.warn({
      from = __module_name__,
      subject = "add_locations_to_ai",
      message = "No locations could be stringified.",
    })
    return
  end

  if #failures > 0 then
    stl.reporter.warn({
      from = __module_name__,
      subject = "add_locations_to_ai",
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

  local append_success = false ---@type boolean
  local append_error ---@type string|nil
  local append_payload = payload .. "\n" ---@type string
  if dot ~= nil and dot.command ~= nil and dot.command.definitions ~= nil then
    local notepad_commands = dot.command.definitions.notepad ---@type dot.command.definitions.notepad|nil
    if notepad_commands ~= nil and notepad_commands.append_content ~= nil then
      local ok_append, append_err = pcall(dot.command.execute, notepad_commands.append_content.uuid, append_payload)
      append_success = ok_append
      if not ok_append then
        append_error = append_err
      end
    else
      append_error = "Notepad append content command is unavailable."
    end
  else
    append_error = "Notepad command system is unavailable."
  end

  if append_error ~= nil then
    stl.reporter.warn({
      from = __module_name__,
      subject = "add_locations_to_ai",
      message = "Failed to append payload to notepad.",
      details = { error = append_error },
    })
  end

  if #copy_failures > 0 then
    stl.reporter.warn({
      from = __module_name__,
      subject = "add_locations_to_ai",
      message = "Copy failed: " .. table.concat(copy_failures, "; "),
    })
  else
    local success_message = "Locations copied to clipboard." ---@type string
    if append_success then
      success_message = "Locations copied to clipboard and appended to notepad."
    end
    stl.reporter.info({
      from = __module_name__,
      subject = "add_locations_to_ai",
      message = success_message,
    })
  end
end

return add_locations_to_ai

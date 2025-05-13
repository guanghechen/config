---@class eve.builtin.fn
local M = {}

local spinners = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" } ---@type string[]
-- local spinners = { "", "", "", "󰪞", "󰪟", "󰪠", "󰪢", "󰪣", "󰪤", "󰪥" } ---@type string[]

---@return string
function M.spinner()
  local index = math.floor(vim.uv.hrtime() / (1e6 * 80)) % #spinners + 1 ---@type integer
  return spinners[index]
end

----------------------------------------------------------------------------------------------------

---@param dirname                       string
---@return string
---@return string
function M.diricon(dirname)
  if #dirname == 0 then
    return eve.icon.filetype.Folder, "MiniIconsBlue"
  end

  if dirname:sub(#dirname, #dirname) == "/" then
    return eve.icon.filetype.Folder, "MiniIconsBlue"
  end

  local name = (not dirname or dirname == "") and eve.setting.BUF_UNTITLED or dirname
  local ok, mini_icons = pcall(require, "mini.icons")
  if ok and name ~= eve.setting.BUF_UNTITLED then
    local icon, icon_hl, is_default = mini_icons.get("directory", dirname)
    if not is_default then
      return icon, icon_hl
    end
  end
  return eve.icon.filetype.Folder, "MiniIconsBlue"
end

---@param filename                      string
---@return string
---@return string
function M.fileicon(filename)
  if #filename == 0 then
    return eve.icon.filetype.Unknown, "MiniIconsRed"
  end

  if filename:sub(#filename, #filename) == "/" then
    return eve.icon.filetype.Folder, "MiniIconsBlue"
  end

  local name = (not filename or filename == "") and eve.setting.BUF_UNTITLED or filename
  local ok, mini_icons = pcall(require, "mini.icons")
  if ok and name ~= eve.setting.BUF_UNTITLED then
    local icon, icon_hl, is_default = mini_icons.get("file", filename)
    if not is_default then
      return icon, icon_hl
    end
  end
  return eve.icon.filetype.Unknown, "MiniIconsRed"
end

----------------------------------------------------------------------------------------------------

---@param observables                   eve.std.collection.IObservable[]
---@param callback                      fun(): nil
---@param ignore_initial                ?boolean
---@return nil
function M.observe(observables, callback, ignore_initial)
  for _, observable in ipairs(observables) do
    local subscriber = eve.std.Subscriber.new({
      on_next = function()
        vim.schedule(callback)
      end,
    })
    observable:subscribe(subscriber, ignore_initial)
  end
end

---@param from                          string
---@param subject                       string
---@param message                       string
---@param fn                            fun(...): any
---@param ...                           any
---@return nil
function M.pcall(from, subject, message, fn, ...)
  local ok, error = pcall(fn, ...)
  if not ok then
    eve.reporter.error({
      from = from,
      subject = subject,
      message = message,
      details = {
        error = error,
      },
    })
  end
end

return M

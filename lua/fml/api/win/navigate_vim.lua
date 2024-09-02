---@return nil
local function navigate_window_prev()
  vim.cmd("wincmd p")
end

---@return nil
local function navigate_window_next()
  vim.cmd("wincmd w")
end

---@param direction "h"|"j"|"k"|"l"
local function navigate_window(direction)
  vim.cmd("wincmd " .. direction)
end

---@param direction "p"|"n"|"h"|"j"|"k"|"l"
local function navigate_vim(direction)
  if direction == "p" then
    pcall(navigate_window_prev)
    return
  end

  if direction == "n" then
    pcall(navigate_window_next)
    return
  end

  local ok = pcall(navigate_window, direction)
  if not ok then
    eve.reporter.error({
      from = "fml.api.win",
      subject = "navigate_vim",
      message = "E11: Invalid in command-line window; <CR> executes, CTRL-C quits",
      details = {
        direction = direction,
      },
    })
  end
end

return navigate_vim

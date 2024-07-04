local function navigate_window_prev()
  vim.cmd("wincmd p")
end

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
    -- error, cannot wincmd from the command-line window
    vim.cmd(
      [[ echohl ErrorMsg | echo 'E11: Invalid in command-line window; <CR> executes, CTRL-C quits' | echohl None ]]
    )
  end
end

return navigate_vim

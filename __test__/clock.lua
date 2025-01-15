-- Create a window to display the time and countdown
local function create_clock_window()
  -- Configure window size and style
  local width = 30
  local height = 10
  local buf = vim.api.nvim_create_buf(false, true) -- Create an unmodifiable temporary buffer
  local opts = {
    relative = "editor",
    width = width,
    height = height,
    col = math.floor((vim.o.columns - width) / 2),
    row = math.floor((vim.o.lines - height) / 2),
    style = "minimal",
    border = "rounded",
  }
  local win = vim.api.nvim_open_win(buf, true, opts)
  return buf, win
end

-- Update the time in the window
local function update_clock(buf, remaining)
  local lines = {}
  local time_str = os.date("%H:%M:%S") -- Current time
  table.insert(lines, "Current time: " .. time_str)
  if remaining then
    local minutes = math.floor(remaining / 60)
    local seconds = remaining % 60
    table.insert(lines, string.format("Countdown: %02d:%02d", minutes, seconds))
  else
    table.insert(lines, "Countdown finished!")
  end
  table.insert(lines, "") -- Empty line
  table.insert(lines, "Press q to close the window")
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
end

-- Start the countdown
local function start_clock_and_timer(seconds)
  local buf, win = create_clock_window()
  local remaining = seconds
  local timer = vim.uv.new_timer()

  -- Set the key to close the window
  vim.api.nvim_buf_set_keymap(
    buf,
    "n",
    "q",
    ":lua vim.api.nvim_win_close(" .. win .. ", true)<CR>",
    { noremap = true, silent = true }
  )
  vim.bo[buf].modifiable = false

  -- Update the countdown
  local function tick()
    vim.schedule(function()
      if remaining > 0 then
        update_clock(buf, remaining)
        remaining = remaining - 1
      else
        update_clock(buf, nil)
        if timer then
          timer:stop()
          timer:close()
        end
        vim.cmd("echon '\\<Esc>\\<Esc>\\<Esc>\\a'") -- Ring the bell
        -- Fullscreen effect
        vim.cmd("highlight FullscreenEffect guibg=Red guifg=White")
        vim.cmd("call matchadd('FullscreenEffect', '\\%1l.*')")
        vim.defer_fn(function()
          vim.cmd("call clearmatches()")
        end, 1000)
      end
    end)
  end

  -- Update every second
  if timer then
    timer:start(0, 1000, tick)
  end
end

-- Create Neovim command
vim.api.nvim_create_user_command("TtyClock", function(opts)
  local seconds = tonumber(opts.args)
  if not seconds or seconds <= 0 then
    vim.api.nvim_err_writeln("Please enter a positive integer for seconds!")
    return
  end
  start_clock_and_timer(seconds)
end, { nargs = 1 })

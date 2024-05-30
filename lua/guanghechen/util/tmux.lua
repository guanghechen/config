--- https://github.com/alexghergh/nvim-tmux-navigation/blob/4898c98702954439233fdaf764c39636681e2861/lua/nvim-tmux-navigation/tmux_util.lua#L1

local tmux_directions = { ["p"] = "l", ["h"] = "L", ["j"] = "D", ["k"] = "U", ["l"] = "R", ["n"] = "t:.+" }

-- send the tmux command to the server running on the socket
-- given by the environment variable $TMUX
--
-- the check if tmux is actually running (so the variable $TMUX is
-- not nil) is made before actually calling this function
---@param command string
local function tmux_command(command)
  local tmux_socket = vim.fn.split(vim.env.TMUX, ",")[1]
  return vim.fn.system("tmux -S " .. tmux_socket .. " " .. command)
end

-- check whether the current tmux pane is zoomed
---@return boolean
local function is_tmux_pane_zoomed()
  -- the output of the tmux command is "1\n", so we have to test against that
  return tmux_command("display-message -p '#{window_zoomed_flag}'") == "1\n"
end

---@class ghc.core.util.tmux
local M = {}

-- whether tmux should take control over the navigation
---@param is_same_winnr boolean
---@param disable_nav_when_zoomed boolean
function M.should_tmux_control(is_same_winnr, disable_nav_when_zoomed)
  if is_tmux_pane_zoomed() and disable_nav_when_zoomed then
    return false
  end
  return is_same_winnr
end

-- change the current pane according to direction
---@param direction "p"|"h"|"j"|"k"|"l"|"n"
function M.change_pane(direction)
  tmux_command("select-pane -" .. tmux_directions[direction])
end

---@param tmux_env_name string
---@return string|nil
function M.get_tmux_env_value(tmux_env_name)
  local handle = io.popen("tmux show-environment " .. tmux_env_name .. " 2>&1", "r")
  if handle == nil then
    return nil
  end

  local result = handle:read("*a")
  handle:close()

  if type(result) ~= "string" or result == "" then
    return nil
  end

  -- Extract the value from the result
  local env_value = result:match("^[^=]+=(.-)%s*$")
  return env_value
end

return M

--- https://github.com/alexghergh/nvim-tmux-navigation/blob/4898c98702954439233fdaf764c39636681e2861/lua/nvim-tmux-navigation/tmux_util.lua#L1

local tmux_directions = { ["p"] = "l", ["h"] = "L", ["j"] = "D", ["k"] = "U", ["l"] = "R", ["n"] = "t:.+" }

-- send the tmux command to the server running on the socket
-- given by the environment variable $TMUX
--
-- the check if tmux is actually running (so the variable $TMUX is
-- not nil) is made before actually calling this function
---@param command                       string
local function tmux_command(command)
  local tmux_socket = vim.fn.split(vim.env.TMUX, ",")[1]
  return vim.fn.system("tmux -S " .. tmux_socket .. " " .. command)
end

---@return boolean
local function is_tmux_pane_leftest()
  return tonumber(tmux_command("display-message -p '#{pane_at_left}'")) == 1
end

---@return boolean
local function is_tmux_pane_topest()
  return tonumber(tmux_command("display-message -p '#{pane_at_top}'")) == 1
end

---@return boolean
local function is_tmux_pane_bottomest()
  return tonumber(tmux_command("display-message -p '#{pane_at_bottom}'")) == 1
end

---@return boolean
local function is_tmux_pane_rightest()
  return tonumber(tmux_command("display-message -p '#{pane_at_right}'")) == 1
end

---@class eve.lib.tmux
---@field public is_tmux_pane_corner    fun(direction: "p"|"n"|"h"|"j"|"k"|"l"): boolean
---@field public is_tmux_pane_zoomed    fun(): boolean
---@field public should_tmux_control    fun(disable_nav_when_zoomed: boolean): boolean
---@field public change_pane            fun(direction: "p"|"h"|"j"|"k"|"l"|"n"): nil
---@field public get_tmux_env_value     fun(tmux_env_name: string): string|nil
local M = {}

if vim.env.TMUX ~= nil then
  ---@param direction                   "p"|"n"|"h"|"j"|"k"|"l"
  ---@return boolean
  function M.is_tmux_pane_corner(direction)
    if direction == "h" then
      return is_tmux_pane_leftest()
    end
    if direction == "j" then
      return is_tmux_pane_bottomest()
    end
    if direction == "k" then
      return is_tmux_pane_topest()
    end
    if direction == "l" then
      return is_tmux_pane_rightest()
    end
    return false
  end

  -- check whether the current tmux pane is the only pane of the window or if the pane is zoomed
  ---@return boolean
  function M.is_tmux_pane_zoomed()
    return (
      tonumber(tmux_command("display-message -p '#{window_panes}'")) == 1 ---! Check if the current window has only one pane
      or tonumber(tmux_command("display-message -p '#{window_zoomed_flag}'")) == 1 ---! Check if the current pane is zoomed
    )
  end

  -- whether tmux should take control over the navigation
  ---@param disable_nav_when_zoomed     boolean
  ---@return boolean
  function M.should_tmux_control(disable_nav_when_zoomed)
    if disable_nav_when_zoomed and M.is_tmux_pane_zoomed() then
      return false
    end
    return true
  end

  -- change the current pane according to direction
  ---@param direction                   "p"|"h"|"j"|"k"|"l"|"n"
  ---@return nil
  function M.change_pane(direction)
    tmux_command("select-pane -" .. tmux_directions[direction])
  end

  ---@param tmux_env_name               string
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
else
  ---@param direction                   "p"|"n"|"h"|"j"|"k"|"l"
  ---@return boolean
  ---@diagnostic disable-next-line: unused-local
  function M.is_tmux_pane_corner(direction)
    return true
  end

  ---@return boolean
  function M.is_tmux_pane_zoomed()
    return true
  end

  ---@param disable_nav_when_zoomed     boolean
  ---@return boolean
  ---@diagnostic disable-next-line: unused-local
  function M.should_tmux_control(disable_nav_when_zoomed)
    return false
  end

  ---@param direction                   "p"|"h"|"j"|"k"|"l"|"n"
  ---@return nil
  ---@diagnostic disable-next-line: unused-local
  function M.change_pane(direction)
    return nil
  end

  ---@param tmux_env_name               string
  ---@return string|nil
  ---@diagnostic disable-next-line: unused-local
  function M.get_tmux_env_value(tmux_env_name)
    return nil
  end
end

return M

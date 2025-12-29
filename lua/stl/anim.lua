---@class stl.anim
local M = {}

-- local spinners = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" } ---@type string[]
-- local spinners = { "", "", "", "󰪞", "󰪟", "󰪠", "󰪢", "󰪣", "󰪤", "󰪥" } ---@type string[]
local spinners = {
  "⡀",
  "⠄",
  "⠂",
  "⠁",
  "⠈",
  "⠐",
  "⠠",
  "⢀",
  "⣀",
  "⢄",
  "⢂",
  "⢁",
  "⢈",
  "⢐",
  "⢠",
  "⣠",
  "⢤",
  "⢢",
  "⢡",
  "⢨",
  "⢰",
  "⣰",
  "⢴",
  "⢲",
  "⢱",
  "⢸",
  "⣸",
  "⢼",
  "⢺",
  "⢹",
  "⣹",
  "⢽",
  "⢻",
  "⣻",
  "⢿",
  "⣿",
}

---@param step                          ?integer
---@return string
function M.spinner(step)
  local interval = type(step) == "number" and step or (1e6 * 80) ---@type number
  if interval <= 0 then
    interval = 1e6 * 80
  end
  local index = math.floor(vim.uv.hrtime() / interval) % #spinners + 1 ---@type integer
  return spinners[index]
end

return M

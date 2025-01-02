local __module_name__ = "eve.module.winpicker" ---@type string

local reporter = require("eve.lib.reporter")
local Renderer = require("eve.module.winpicker.renderer")

---@type string[]
local _chars = {
  "F",
  "J",
  "D",
  "K",
  "S",
  "L",
  "A",
  ";",
  "C",
  "M",
  "R",
  "U",
  "E",
  "I",
  "W",
  "O",
  "Q",
  "P",
}

---@return string|nil
local function get_user_input_char()
  local ok, c = pcall(vim.fn.getchar)

  if not ok then
    return
  end

  while type(c) ~= "number" do
    c = vim.fn.getchar()
  end

  return vim.fn.nr2char(c)
end

---@class eve.module.winpicker
local M = {}

---@param filter                        fun(winnr: integer): boolean
---@param winnr_cur                     integer|nil
---@return integer|nil
function M.pick_window(filter, winnr_cur)
  local winnrs = vim.api.nvim_list_wins() ---@type integer[]
  local N = 0 ---@type integer
  for i = 1, #winnrs, 1 do
    local winnr = winnrs[i] ---@type integer
    if winnr ~= winnr_cur and filter(winnr) then
      N = N + 1 ---@type integer
      winnrs[N] = winnr
    end
  end

  if N < 1 then
    reporter.warn({
      from = __module_name__,
      subject = "pick_window",
      message = "No windows left to pick after filtering",
    })
    return nil
  end

  if N == 1 then
    return winnrs[1]
  end

  local renderers = {} ---@type table<integer, eve.module.winpicker.Renderer>
  for i = 1, N, 1 do
    local winnr = winnrs[i] ---@type integer
    local char = _chars[i] ---@type string
    local renderer = Renderer.new({ char = char }) ---@type eve.module.winpicker.Renderer
    renderers[winnr] = renderer
  end

  for winnr, renderer in pairs(renderers) do
    renderer:show(winnr)
  end

  vim.cmd.redraw()
  local winnr_target = nil ---@type integer|nil

  local char = get_user_input_char() ---@type string|nil
  if char ~= nil then
    char = char:lower() ---@type string
    for winnr, renderer in pairs(renderers) do
      if char == renderer.char then
        winnr_target = winnr ---@type integer
        break
      end
    end
  end

  for _, renderer in pairs(renderers) do
    renderer:hide()
  end
  vim.cmd.redraw()

  return winnr_target
end

return M

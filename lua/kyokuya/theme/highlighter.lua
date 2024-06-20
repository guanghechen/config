---@class kyokuya.theme.IHighlighterOptions
---@field public palette kyokuya.theme.palette.IPalette

---@class kyokuya.theme.Highlighter
---@field private highligt_map table<string, kyokuya.theme.INvimHighlightGroup>
---@field private palette kyokuya.theme.palette.IPalette
local M = {}
M.__index = M

---@param opts kyokuya.theme.IHighlighterOptions
---@return kyokuya.theme.Highlighter
function M.new(opts)
  local self = setmetatable({}, M)

  self.palette = opts.palette
  self.highligt_map = {}

  return self
end

---@param opts kyokuya.theme.IHighlighterOptions
---@return kyokuya.theme.Highlighter
function M.new_with_integrations(opts)
  local self = setmetatable({}, M)

  self.palette = opts.palette
  self.highligt_map = {}

  local integrations = require("kyokuya.theme.integration")
  integrations.load_integrations(self)

  return self
end

---@param nsnr integer namespace id
---@return nil
function M:apply(nsnr)
  for hlname, hlgroup in pairs(self.highligt_map) do
    vim.api.nvim_set_hl(nsnr, hlname, hlgroup)
  end
end

---@param hlname string
---@param hlconfig kyokuya.theme.IHighlightGroup
---@return kyokuya.theme.Highlighter
function M:register(hlname, hlconfig)
  local hlgroup = self:resolve(hlconfig) ---@type kyokuya.theme.INvimHighlightGroup
  self.highligt_map[hlname] = hlgroup
  return self
end

---@param hlconfig kyokuya.theme.IHighlightGroup
---@return kyokuya.theme.INvimHighlightGroup
function M:resolve(hlconfig)
  ---@type kyokuya.theme.INvimHighlightGroup
  ---@diagnostic disable-next-line: assign-type-mismatch
  local hlgroup = vim.deepcopy(hlconfig)

  if hlconfig.fg ~= nil then
    hlgroup.fg = self.palette.colors[hlconfig.fg] or hlconfig.fg
  end

  if hlconfig.bg ~= nil then
    hlgroup.bg = self.palette.colors[hlconfig.bg] or hlconfig.bg
  end

  if hlconfig.sp ~= nil then
    hlgroup.sp = self.palette.colors[hlconfig.sp] or hlconfig.sp
  end

  return hlgroup
end

return M

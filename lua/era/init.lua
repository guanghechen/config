---@class era.__mods
local __mods = {
  ai = "era.ai",
  board = "era.board",
  choices = "era.choices",
  clipboard = "era.clipboard",
  colorpicker = "era.colorpicker",
  explorer = "era.explorer",
  git = "era.git",
  illuminate = "era.illuminate",
  im = "era.im",
  image = "era.image",
  input = "era.input",
  lsp = "era.lsp",
  nvimbar = "era.nvimbar",
  picker = "era.picker",
  plugin = "era.plugin",
  searcher = "era.searcher",
  term = "era.term",
  view = "era.view",
  winpicker = "era.winpicker",
}

---@class era
---@field public __mods                 era.__mods
---@field public ai                     era.ai
---@field public board                  era.board
---@field public choices                era.choices
---@field public clipboard              era.clipboard
---@field public colorpicker            era.colorpicker
---@field public explorer               era.explorer
---@field public git                    era.git
---@field public illuminate             era.illuminate
---@field public im                     era.im
---@field public image                  era.image
---@field public input                  era.input
---@field public lsp                    era.lsp
---@field public nvimbar                era.nvimbar
---@field public picker                 era.picker
---@field public plugin                 era.plugin
---@field public searcher               era.searcher
---@field public term                   era.term
---@field public view                   era.view
---@field public winpicker              era.winpicker
local M = setmetatable({
  __mods = __mods,
}, {
  __index = function(t, k)
    local m = __mods[k] ---@type string|nil
    if m == nil then
      return rawget(t, k)
    end
    return require(m)
  end,
})

return M

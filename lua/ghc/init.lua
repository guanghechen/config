---@class ghc.ux
local ux = {
  statusline = require("ghc.ux.statusline"),
  tabline = require("ghc.ux.tabline"),
  winline = require("ghc.ux.winline"),
}

---@class ghc
---@field public ux                     ghc.ux
local ghc = {
  ux = ux,
}

return ghc

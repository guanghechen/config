local icons = require("ghc.core.setting.icons")

return {
  {
    "folke/trouble.nvim",
    cmd = { "TroubleToggle", "Trouble" },
    keys = {},
    opts = require("ghc.plugin.trouble.opts"),
  },
}

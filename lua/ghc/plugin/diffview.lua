local icons = require("ghc.core.setting.icons")

return {
  "sindrets/diffview.nvim",
  cmd = { "DiffviewOpen", "DiffviewFileHistory" },
  opts = {
    icons = { -- Only applies when use_icons is true.
      folder_closed = icons.ui.Folder,
      folder_open = icons.ui.FolderOpen,
    },
    signs = {
      fold_closed = icons.ui.ArrowClosed,
      fold_open = icons.ui.ArrowOpen,
      done = icons.ui.Accepted,
    },
  },
}

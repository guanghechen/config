local kinds = {}
for key, val in pairs(ghc.ui.icons.kind) do
  kinds[key] = val .. " "
end

return {
  "folke/trouble.nvim",
  cmd = { "TroubleToggle", "Trouble" },
  keys = {},
  opts = {
    position = "bottom", -- position of the list can be: bottom, top, left, right
    icons = {
      indent = {
        top = "│ ",
        middle = "├╴",
        last = "└╴",
        fold_open = ghc.ui.icons.ui.ArrowOpen .. " ",
        fold_closed = ghc.ui.icons.ui.ArrowClosed .. " ",
        ws = "  ",
      },
      folder_closed = ghc.ui.icons.ui.Folder .. " ",
      folder_open = ghc.ui.icons.ui.FolderOpen .. " ",
      fold_open = ghc.ui.icons.ui.ArrowOpen .. " ", -- icon used for open folds
      fold_closed = ghc.ui.icons.ui.ArrowClosed .. " ", -- icon used for closed folds
      kinds = kinds,
    },
  },
}

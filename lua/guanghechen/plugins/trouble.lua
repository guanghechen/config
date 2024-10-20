local kinds = {}
for key, val in pairs(eve.icons.kind) do
  kinds[key] = val .. " "
end

return {
  name = "trouble.nvim",
  cmd = { "TroubleToggle", "Trouble" },
  keys = {},
  opts = {
    position = "bottom", -- position of the list can be: bottom, top, left, right
    icons = {
      indent = {
        top = "│ ",
        middle = "├╴",
        last = "└╴",
        fold_open = eve.icons.ui.ArrowOpen .. " ",
        fold_closed = eve.icons.ui.ArrowClosed .. " ",
        ws = "  ",
      },
      folder_closed = eve.icons.ui.Folder .. " ",
      folder_open = eve.icons.ui.FolderOpen .. " ",
      fold_open = eve.icons.ui.ArrowOpen .. " ",     -- icon used for open folds
      fold_closed = eve.icons.ui.ArrowClosed .. " ", -- icon used for closed folds
      kinds = kinds,
    },
  },
}

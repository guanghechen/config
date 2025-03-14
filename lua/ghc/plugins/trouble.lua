local kinds = {}
for key, val in pairs(eve.c.icon.kind) do
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
        fold_open = eve.c.icon.ui.ArrowOpen .. " ",
        fold_closed = eve.c.icon.ui.ArrowClosed .. " ",
        ws = "  ",
      },
      folder_closed = eve.c.icon.filetype.Folder .. " ",
      folder_open = eve.c.icon.filetype.FolderOpen .. " ",
      fold_open = eve.c.icon.ui.ArrowOpen .. " ", -- icon used for open folds
      fold_closed = eve.c.icon.ui.ArrowClosed .. " ", -- icon used for closed folds
      kinds = kinds,
    },
  },
}

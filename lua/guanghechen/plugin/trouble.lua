local kinds = {}
for key, val in pairs(fml.ui.icons.kind) do
  kinds[key] = val .. " "
end

return {
  url = "https://github.com/guanghechen/mirror.git",
  branch = "nvim@trouble.nvim",
  name = "trouble.nvim",
  main = "trouble",
  cmd = { "TroubleToggle", "Trouble" },
  keys = {},
  opts = {
    position = "bottom", -- position of the list can be: bottom, top, left, right
    icons = {
      indent = {
        top = "│ ",
        middle = "├╴",
        last = "└╴",
        fold_open = fml.ui.icons.ui.ArrowOpen .. " ",
        fold_closed = fml.ui.icons.ui.ArrowClosed .. " ",
        ws = "  ",
      },
      folder_closed = fml.ui.icons.ui.Folder .. " ",
      folder_open = fml.ui.icons.ui.FolderOpen .. " ",
      fold_open = fml.ui.icons.ui.ArrowOpen .. " ", -- icon used for open folds
      fold_closed = fml.ui.icons.ui.ArrowClosed .. " ", -- icon used for closed folds
      kinds = kinds,
    },
  },
}

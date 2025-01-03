local icons = require("eve.constant.icon")

local kinds = {}
for key, val in pairs(icons.kind) do
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
        fold_open = icons.ui.ArrowOpen .. " ",
        fold_closed = icons.ui.ArrowClosed .. " ",
        ws = "  ",
      },
      folder_closed = icons.filetype.Folder .. " ",
      folder_open = icons.filetype.FolderOpen .. " ",
      fold_open = icons.ui.ArrowOpen .. " ", -- icon used for open folds
      fold_closed = icons.ui.ArrowClosed .. " ", -- icon used for closed folds
      kinds = kinds,
    },
  },
}

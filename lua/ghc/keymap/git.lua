local path = require("ghc.util.path")

local lazygit = {
  open = function()
    local cmds = {
      "cd " .. '"' .. path.workspace() .. '"',
      "lazygit",
    }

    require("nvchad.term").toggle({
      id = "lazygit",
      pos = "float",
      cmd = table.concat(cmds, " && "),
    })
  end,
}

if path.findGitRepoFromPath(vim.uv.cwd()) ~= nil then
  vim.keymap.set("n", "<leader>gg", lazygit.open, { noremap = true, silent = true, desc = "Lazygit (workspace)" })
end

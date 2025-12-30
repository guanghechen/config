---@see https://github.com/folke/folke/whick-key.nvim/tree/3aab2147e74890957785941f0c1ad87d0a44c15a

return {
  name = "which-key.nvim",
  event = { "VeryLazy" },
  opts_extend = { "spec" },
  opts = {
    preset = "classic",
    triggers = {
      { "<auto>", mode = "nxs" },
    },
    disable = {
      ft = {
        stl.filetype.TERM,
        stl.filetype.WINSEP,
      },
    },
    spec = {
      {
        mode = { "n", "x" },
        { "g", group = "goto", icon = { icon = stl.icon.ui.Location, color = "cyan" } },
        { "gs", group = "surround", icon = { icon = stl.icon.ui.Circle, color = "purple" } },
        { "z", group = "fold", icon = { icon = stl.icon.symbols.flag_fold_empty_path, color = "yellow" } },
        { "]", group = "next", icon = { icon = stl.icon.ui.Right, color = "green" } },
        { "[", group = "prev", icon = { icon = stl.icon.ui.Left, color = "green" } },
        { "<leader>a", group = "ai", icon = { icon = stl.icon.app.Copilot, color = "cyan" } },
        {
          "<leader>b",
          group = "buffer",
          icon = { icon = stl.icon.ui.Buffer, color = "blue" },
          expand = function()
            return require("which-key.extras").expand.buf()
          end,
        },
        { "<leader>c", group = "code", icon = { icon = stl.icon.ui.CodeAction, color = "yellow" } },
        { "<leader>d", group = "debug", icon = { icon = stl.icon.ui.Bug, color = "orange" } },
        { "<leader>e", group = "explorer", icon = { icon = stl.icon.filetype.FileTree, color = "green" } },
        { "<leader>f", group = "find/file", icon = { icon = stl.icon.ui.Search, color = "cyan" } },
        { "<leader>g", group = "git", icon = { icon = stl.icon.git.Git, color = "orange" } },
        { "<leader>gh", group = "git hunk", icon = { icon = stl.icon.git.Diff, color = "yellow" } },
        { "<leader>i", group = "debug/inspect", icon = { icon = stl.icon.ui.Indicator, color = "purple" } },
        { "<leader>q", group = "quit/session", icon = { icon = stl.icon.ui.SignOut, color = "red" } },
        { "<leader>s", group = "search/replace", icon = { icon = stl.icon.symbols.flag_replace, color = "purple" } },
        { "<leader>t", group = "tab/toggle", icon = { icon = stl.icon.ui.Terminal, color = "yellow" } },
        { "<leader>u", group = "ui", icon = { icon = stl.icon.ui.Gear, color = "orange" } },
        {
          "<leader>w",
          group = "window",
          proxy = "<c-w>",
          icon = { icon = stl.icon.ui.Window, color = "blue" },
          expand = function()
            return require("which-key.extras").expand.win()
          end,
        },
        {
          "<leader>x",
          group = "diagnostics/quickfix",
          icon = { icon = stl.icon.diagnostic.Warning_alt, color = "red" },
        },
      },
    },
  },
  config = function(_, opts)
    era.fn.mock_miniicons()
    require("which-key").setup(opts)
  end,
}

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
        eve.filetype.TERM,
        eve.filetype.WINSEP,
      },
    },
    spec = {
      {
        mode = { "n", "x" },
        { "g", group = "goto", icon = { icon = eve.icon.ui.Location, color = "cyan" } },
        { "gs", group = "surround", icon = { icon = eve.icon.ui.Circle, color = "purple" } },
        { "z", group = "fold", icon = { icon = eve.icon.symbols.flag_fold_empty_path, color = "yellow" } },
        { "]", group = "next", icon = { icon = eve.icon.ui.Right, color = "green" } },
        { "[", group = "prev", icon = { icon = eve.icon.ui.Left, color = "green" } },
        { "<leader>a", group = "ai", icon = { icon = eve.icon.app.Copilot, color = "cyan" } },
        {
          "<leader>b",
          group = "buffer",
          icon = { icon = eve.icon.ui.Buffer, color = "blue" },
          expand = function()
            return require("which-key.extras").expand.buf()
          end,
        },
        { "<leader>c", group = "code", icon = { icon = eve.icon.ui.CodeAction, color = "yellow" } },
        { "<leader>d", group = "debug", icon = { icon = eve.icon.ui.Bug, color = "orange" } },
        { "<leader>e", group = "explorer", icon = { icon = eve.icon.filetype.FileTree, color = "green" } },
        { "<leader>f", group = "find/file", icon = { icon = eve.icon.ui.Search, color = "cyan" } },
        { "<leader>g", group = "git", icon = { icon = eve.icon.git.Git, color = "orange" } },
        { "<leader>gh", group = "git hunk", icon = { icon = eve.icon.git.Diff, color = "yellow" } },
        { "<leader>i", group = "debug/inspect", icon = { icon = eve.icon.ui.Indicator, color = "purple" } },
        { "<leader>q", group = "quit/session", icon = { icon = eve.icon.ui.SignOut, color = "red" } },
        { "<leader>s", group = "search/replace", icon = { icon = eve.icon.symbols.flag_replace, color = "purple" } },
        { "<leader>t", group = "tab/toggle", icon = { icon = eve.icon.ui.Terminal, color = "yellow" } },
        { "<leader>u", group = "ui", icon = { icon = eve.icon.ui.Gear, color = "orange" } },
        {
          "<leader>w",
          group = "window",
          proxy = "<c-w>",
          icon = { icon = eve.icon.ui.Window, color = "blue" },
          expand = function()
            return require("which-key.extras").expand.win()
          end,
        },
        {
          "<leader>x",
          group = "diagnostics/quickfix",
          icon = { icon = eve.icon.diagnostic.Warning_alt, color = "red" },
        },
      },
    },
  },
  config = function(_, opts)
    require("fml.dressing.plugin").mock_miniicons()
    require("which-key").setup(opts)
  end,
}

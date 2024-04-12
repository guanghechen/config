return {
  {
    "telescope.nvim",
    dependencies = {},
    keys = {
      { "<leader>fF", LazyVim.telescope("files"), desc = "Find Files (Root Dir)" },
      { "<leader>ff", LazyVim.telescope("files", { cwd = false }), desc = "Find Files (cwd)" },
      { "<leader>fg", "<cmd>Telescope git_files<cr>", desc = "Find Files (git-files)" },
      { "<leader>fR", "<cmd>Telescope oldfiles<cr>", desc = "Recent" },
      { "<leader>fr", LazyVim.telescope("oldfiles", { cwd = vim.uv.cwd() }), desc = "Recent (cwd)" },
      { "<leader>sC", "<cmd>Telescope command_history<cr>", desc = "Command History" },
      { "<leader>sc", "<cmd>Telescope commands<cr>", desc = "Commands" },
      { "<leader>sD", "<cmd>Telescope diagnostics bufnr=0<cr>", desc = "Document Diagnostics" },
      { "<leader>sd", "<cmd>Telescope diagnostics<cr>", desc = "Workspace Diagnostics" },
      { "<leader>sG", LazyVim.telescope("live_grep"), desc = "Grep (Root Dir)" },
      { "<leader>sg", LazyVim.telescope("live_grep", { cwd = false }), desc = "Grep (cwd)" },
      { "<leader>sW", LazyVim.telescope("grep_string", { word_match = "-w" }), desc = "Word (Root Dir)" },
      { "<leader>sw", LazyVim.telescope("grep_string", { cwd = false, word_match = "-w" }), desc = "Word (cwd)" },
      { "<leader>sW", LazyVim.telescope("grep_string"), mode = "v", desc = "Selection (Root Dir)" },
      { "<leader>sw", LazyVim.telescope("grep_string", { cwd = false }), mode = "v", desc = "Selection (cwd)" },
    },
  },
}

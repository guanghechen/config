local function changeColorSchemaForCurrentSession()
  require("telescope.builtin").colorscheme({ enable_preview = true })
end

local function findWordInProject()
  require("telescope").extensions.live_grep_args.live_grep_args()
end

local function showUndoHistory()
  require("telescope").extensions.undo.undo()
end

local function keys()
  return {
    { "<leader>sC", "<cmd>Telescope command_history<cr>", desc = "Command History" },
    { "<leader>sc", "<cmd>Telescope commands<cr>", desc = "Commands" },
    { "<leader>sD", "<cmd>Telescope diagnostics<cr>", desc = "Workspace Diagnostics" },
    { "<leader>sd", "<cmd>Telescope diagnostics bufnr=0<cr>", desc = "Document Diagnostics" },
    { "<leader>sW", LazyVim.telescope("grep_string", { word_match = "-w" }), desc = "Word (Root Dir)" },
    { "<leader>sw", LazyVim.telescope("grep_string", { cwd = false, word_match = "-w" }), desc = "Word (cwd)" },
    { "<leader>sW", LazyVim.telescope("grep_string"), mode = "v", desc = "Selection (Root Dir)" },
    { "<leader>sw", LazyVim.telescope("grep_string", { cwd = false }), mode = "v", desc = "Selection (cwd)" },
    { "<leader>/", LazyVim.telescope("live_grep"), desc = "Grep (Root Dir)" },
    { "<leader>:", "<cmd>Telescope command_history<cr>", desc = "Command History" },
    -- find
    { "<leader>fc", LazyVim.telescope.config_files(), desc = "Find Config File" },
    -- git
    { "<leader>gc", "<cmd>Telescope git_commits<CR>", desc = "Commits" },
    { "<leader>gs", "<cmd>Telescope git_status<CR>", desc = "Status" },
    -- search
    { '<leader>s"', "<cmd>Telescope registers<cr>", desc = "Registers" },
    { "<leader>sa", "<cmd>Telescope autocommands<cr>", desc = "Auto Commands" },
    { "<leader>sb", "<cmd>Telescope current_buffer_fuzzy_find<cr>", desc = "Buffer" },
    { "<leader>sh", "<cmd>Telescope help_tags<cr>", desc = "Help Pages" },
    { "<leader>sH", "<cmd>Telescope highlights<cr>", desc = "Search Highlight Groups" },
    { "<leader>sk", "<cmd>Telescope keymaps<cr>", desc = "Key Maps" },
    { "<leader>sM", "<cmd>Telescope man_pages<cr>", desc = "Man Pages" },
    { "<leader>sm", "<cmd>Telescope marks<cr>", desc = "Jump to Mark" },
    { "<leader>so", "<cmd>Telescope vim_options<cr>", desc = "Options" },
    { "<leader>sR", "<cmd>Telescope resume<cr>", desc = "Resume" },
    { "<leader>uC", LazyVim.telescope("colorscheme", { enable_preview = true }), desc = "Colorscheme with Preview" },
    {
      "<leader>ss",
      function()
        require("telescope.builtin").lsp_document_symbols({
          symbols = require("lazyvim.config").get_kind_filter(),
        })
      end,
      desc = "Goto Symbol",
    },
    {
      "<leader>sS",
      function()
        require("telescope.builtin").lsp_dynamic_workspace_symbols({
          symbols = require("lazyvim.config").get_kind_filter(),
        })
      end,
      desc = "Goto Symbol (Workspace)",
    },
  }
end
return keys

local paths = {
  workspace = function()
    return LazyVim.root()
  end,
  cwd = function()
    return vim.uv.cwd()
  end,
  current = function()
    return vim.fn.expand("%:p:h")
  end,
}

local finder = {
  explorer = {
    workspace = function()
      require("telescope").extensions.file_browser.file_browser({
        cwd = paths.workspace(),
        workspace = "CWD",
        show_untracked = true,
        grouped = true,
        initial_mode = "normal",
        prompt_title = "File explorer",
      })
    end,
    current = function()
      require("telescope").extensions.file_browser.file_browser({
        cwd = paths.current(),
        workspace = "CWD",
        select_buffer = true,
        show_untracked = true,
        grouped = true,
        initial_mode = "normal",
        prompt_title = "File explorer",
      })
    end,
  },
  files = {
    workspace = function()
      require("telescope.builtin").find_files({
        cwd = paths.workspace(),
        workspace = "CWD",
        show_untracked = true,
        prompt_title = "Find files (workspace)",
      })
    end,
    cwd = function()
      require("telescope.builtin").find_files({
        cwd = paths.cwd(),
        workspace = "CWD",
        show_untracked = true,
        prompt_title = "Find files (cwd)",
      })
    end,
    git = function()
      require("telescope.builtin").git_files({
        workspace = "CWD",
        cwd = paths.workspace(),
        prompt_title = "Find files (git)",
      })
    end,
  },
  frecency = {
    workspace = function()
      require("telescope").extensions.frecency.frecency({
        cwd = paths.workspace(),
        workspace = "CWD",
        show_untracked = true,
        prompt_title = "Find recent (workspace)",
      })
    end,
    cwd = function()
      require("telescope").extensions.frecency.frecency({
        cwd = paths.cwd(),
        workspace = "CWD",
        show_untracked = true,
        prompt_title = "Find recent (cwd)",
      })
    end,
    current = function()
      require("telescope").extensions.frecency.frecency({
        cwd = paths.current(),
        workspace = "CWD",
        show_untracked = true,
        prompt_title = "Find recent (current directory)",
      })
    end,
  },
  terminal = {
    workspace = function()
      LazyVim.terminal(nil, {
        cwd = paths.workspace(),
        border = "rounded",
        persistent = true,
      })
    end,
    cwd = function()
      LazyVim.terminal(nil, {
        cwd = paths.cwd(),
        border = "rounded",
        persistent = true,
      })
    end,
    current = function()
      LazyVim.terminal(nil, {
        cwd = paths.current(),
        border = "rounded",
      })
    end,
  },
}

local searcher = {
  live_grep_with_args = {
    workspace = function()
      require("telescope").extensions.live_grep_args.live_grep_args({
        workspace = "CWD",
        cwd = paths.workspace(),
        show_untracked = true,
        prompt_title = "Search grep with args (workspace)",
      })
    end,
    cwd = function()
      require("telescope").extensions.live_grep_args.live_grep_args({
        cwd = paths.cwd(),
        workspace = "CWD",
        show_untracked = true,
        prompt_title = "Search grep with args (cwd)",
      })
    end,
    current = function()
      require("telescope").extensions.live_grep_args.live_grep_args({
        cwd = paths.current(),
        workspace = "CWD",
        show_untracked = true,
        prompt_title = "Search grep with args (current directory)",
      })
    end,
  },
}

local function changeColorSchemaForCurrentSession()
  require("telescope.builtin").colorscheme({ enable_preview = true })
end

local function findWordInProject()
  require("telescope").extensions.live_grep_args.live_grep_args()
end

local function showUndoHistory()
  require("telescope").extensions.undo.undo()
end

-- finders
vim.keymap.set("n", "<leader>fb", "<cmd>Telescope buffers sort_mru=true sort_lastused=true<cr>", { noremap = true, desc = "Switch buffer" })
vim.keymap.set("n", "<leader>fE", finder.explorer.workspace, { noremap = true, desc = "File explorer (from workspace)" })
vim.keymap.set("n", "<leader>fe", finder.explorer.current, { noremap = true, desc = "File explorer (from current file)" })
vim.keymap.set("n", "<leader>fF", finder.files.workspace, { noremap = true, desc = "Find files (workspace)" })
vim.keymap.set("n", "<leader>ff", finder.files.cwd, { noremap = true, desc = "Find files (directory)" })
vim.keymap.set("n", "<leader>fg", finder.files.git, { noremap = true, desc = "Find files (git)" })
vim.keymap.set("n", "<leader><space>", finder.files.workspace, { noremap = true, desc = "Find files (directory)" })
vim.keymap.set("n", "<leader>fr1", finder.frecency.workspace, { noremap = true, desc = "Recent (repo)" })
vim.keymap.set("n", "<leader>fr2", finder.frecency.cwd, { noremap = true, desc = "Recent (cwd)" })
vim.keymap.set("n", "<leader>fr3", finder.frecency.current, { noremap = true, desc = "Recent (directory)" })
vim.keymap.set("n", "<leader>ft1", finder.terminal.workspace, { noremap = true, desc = "Find files (workspace)" })
vim.keymap.set("n", "<leader>ft2", finder.terminal.cwd, { noremap = true, desc = "Find files (cwd)" })
vim.keymap.set("n", "<leader>ft3", finder.terminal.current, { noremap = true, desc = "Open terminal (directory)" })

-- searchers
vim.keymap.set("n", "<leader>sg1", searcher.live_grep_with_args.workspace, { noremap = true, desc = "Grep (workspace)" })
vim.keymap.set("n", "<leader>sg2", searcher.live_grep_with_args.cwd, { noremap = false, desc = "Grep (cwd)" })
vim.keymap.set("n", "<leader>sg3", searcher.live_grep_with_args.current, { noremap = false, desc = "Grep (directory)" })

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

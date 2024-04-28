return {
  {
    "nvim-neo-tree/neo-tree.nvim",
    branch = "v3.x",
    cmd = "Neotree",
    deactivate = function()
      vim.cmd([[Neotree close]])
    end,
    init = function()
      -- Initial open the neo-tree if nvim enter with a directory.
      -- if vim.fn.argc(-1) == 1 then
      --   local stat = vim.uv.fs_stat(vim.fn.argv(0))
      --   if stat and stat.type == "directory" then
      --     require("neo-tree")
      --   end
      -- end
    end,
    keys = {},
    opts = require("ghc.plugin.neo-tree.opts"),
    config = function(_, opts)
      local function on_move(data)
        require("ghc.core.lsp.common").on_rename(data.source, data.destination)
      end

      local events = require("neo-tree.events")
      opts.event_handlers = opts.event_handlers or {}
      vim.list_extend(opts.event_handlers, {
        { event = events.FILE_MOVED, handler = on_move },
        { event = events.FILE_RENAMED, handler = on_move },
      })
      require("neo-tree").setup(opts)
      vim.api.nvim_create_autocmd("TermClose", {
        pattern = "*lazygit",
        callback = function()
          if package.loaded["neo-tree.sources.git_status"] then
            require("neo-tree.sources.git_status").refresh()
          end
        end,
      })
    end,
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-tree/nvim-web-devicons",
      "MunifTanjim/nui.nvim",
    },
  },
  {
    "s1n7ax/nvim-window-picker",
    name = "window-picker",
    event = "VeryLazy",
    version = "2.*",
    config = function()
      require("window-picker").setup({
        hint = "floating-big-letter",
        show_prompt = true,
        filter_rules = {
          autoselect_one = true,
          include_current_win = false,
          bo = {
            filetype = { "neo-tree", "neo-tree-popup", "noice", "notify" },
            buftype = { "terminal", "quickfix" },
          },
        },
      })
    end,
  },
}

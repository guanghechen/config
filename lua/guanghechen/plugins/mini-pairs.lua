local __module_name__ = "guanghechen.plugin.mini-pairs" ---@type string

local reporter = require("eve.builtin.reporter")

-- auto pairs
return {
  name = "mini.pairs",
  event = { "BufReadPost", "BufNewFile", "BufWritePre" },
  opts = {
    modes = { insert = true, command = true, terminal = false },
    skip_next = [=[[%w%%%'%[%"%.%`%$]]=], -- skip autopair when next character is one of these
    skip_ts = { "string" }, -- skip autopair when the cursor is inside these treesitter nodes
    skip_unbalanced = true,
    markdown = true,
    mappings = {
      ["("] = { action = "open", pair = "()", neigh_pattern = "[^\\]." },
      ["["] = { action = "open", pair = "[]", neigh_pattern = "[^\\]." },
      ["{"] = { action = "open", pair = "{}", neigh_pattern = "[^\\]." },
      [")"] = { action = "close", pair = "()", neigh_pattern = "[^\\]." },
      ["]"] = { action = "close", pair = "[]", neigh_pattern = "[^\\]." },
      ["}"] = { action = "close", pair = "{}", neigh_pattern = "[^\\]." },
      ['"'] = { action = "closeopen", pair = '""', neigh_pattern = "[^\\].", register = { cr = false } },
      ["'"] = { action = "closeopen", pair = "''", neigh_pattern = "[^%a\\].", register = { cr = false } },
      ["`"] = { action = "closeopen", pair = "``", neigh_pattern = "[^\\].", register = { cr = false } },
    },
  },
  keys = {
    {
      "<leader>up",
      function()
        vim.g.minipairs_disable = not vim.g.minipairs_disable
        if vim.g.minipairs_disable then
          reporter.warn({
            from = __module_name__,
            subject = "toggle auto pairs",
            message = "Disabled auto pairs",
          })
        else
          reporter.info({
            from = __module_name__,
            subject = "toggle auto pairs",
            message = "Enable auto pairs",
          })
        end
      end,
      desc = "Toggle Auto Pairs",
    },
  },
}

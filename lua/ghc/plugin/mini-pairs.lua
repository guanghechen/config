local guanghechen = require("guanghechen")

-- auto pairs
return {
  "echasnovski/mini.pairs",
  event = "VeryLazy",
  opts = {
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
          reporter.util.reporter.warn({ 
            from = "mini-pairs", 
            subject = "toggle auto pairs", 
            message = "Disabled auto pairs" 
          })
        else
          reporter.util.reporter.info({ 
            from = "mini-pairs", 
            subject = "toggle auto pairs", 
            message = "Enable auto pairs" 
          })
        end
      end,
      desc = "Toggle Auto Pairs",
    },
  },
}

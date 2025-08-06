---! https://github.com/nvim-treesitter/nvim-treesitter-textobjects
return {
  name = "nvim-treesitter-textobjects",
  opts = {
    move = {
      set_jumps = true,
    },
    select = {
      lookahead = true,
      selection_modes = {
        ["@parameter.outer"] = "v",
        ["@function.outer"] = "V",
        ["@class.outer"] = "<c-v>",
      },
      include_surrounding_whitespace = false,
    },
  },
  config = function(_, opts)
    require("nvim-treesitter-textobjects").setup(opts)

    local select = require("nvim-treesitter-textobjects.select")
    local move = require("nvim-treesitter-textobjects.move")

    ---@type std.t.IKeymap[]
    local keymaps = {
      {
        modes = { "x", "o" },
        key = "af",
        callback = function()
          select.select_textobject("@function.outer", "textobjects")
        end,
      },
      {
        modes = { "x", "o" },
        key = "if",
        callback = function()
          select.select_textobject("@function.inner", "textobjects")
        end,
      },
      {
        modes = { "x", "o" },
        key = "ac",
        callback = function()
          select.select_textobject("@class.outer", "textobjects")
        end,
      },
      {
        modes = { "x", "o" },
        key = "ic",
        callback = function()
          select.select_textobject("@class.inner", "textobjects")
        end,
      },
      {
        modes = { "x", "o" },
        key = "as",
        callback = function()
          select.select_textobject("@local.scope", "locals")
        end,
      },
      {
        modes = { "n", "x", "o" },
        key = "]a",
        callback = function()
          move.goto_next_start("@parameter.inner", "textobjects")
        end,
      },
      {
        modes = { "n", "x", "o" },
        key = "]b",
        callback = function()
          move.goto_next_start("@block.outer", "textobjects")
        end,
      },
      {
        modes = { "n", "x", "o" },
        key = "]c",
        callback = function()
          move.goto_next_start("@class.outer", "textobjects")
        end,
      },
      {
        modes = { "n", "x", "o" },
        key = "]f",
        callback = function()
          move.goto_next_start("@function.outer", "textobjects")
        end,
      },
      {
        modes = { "n", "x", "o" },
        key = "]s",
        callback = function()
          move.goto_next_start("@local.scope", "locals")
        end,
      },
      {
        modes = { "n", "x", "o" },
        key = "]z",
        callback = function()
          move.goto_next_start("@fold", "folds")
        end,
      },
      {
        modes = { "n", "x", "o" },
        key = "]A",
        callback = function()
          move.goto_next_end("@parameter.inner", "textobjects")
        end,
      },
      {
        modes = { "n", "x", "o" },
        key = "]C",
        callback = function()
          move.goto_next_end("@class.outer", "textobjects")
        end,
      },
      {
        modes = { "n", "x", "o" },
        key = "]F",
        callback = function()
          move.goto_next_end("@function.outer", "textobjects")
        end,
      },
      {
        modes = { "n", "x", "o" },
        key = "[a",
        callback = function()
          move.goto_previous_start("@parameter.inner", "textobjects")
        end,
      },
      {
        modes = { "n", "x", "o" },
        key = "[b",
        callback = function()
          move.goto_previous_start("@block.outer", "textobjects")
        end,
      },
      {
        modes = { "n", "x", "o" },
        key = "[c",
        callback = function()
          move.goto_previous_start("@class.outer", "textobjects")
        end,
      },
      {
        modes = { "n", "x", "o" },
        key = "[f",
        callback = function()
          move.goto_previous_start("@function.outer", "textobjects")
        end,
      },
      {
        modes = { "n", "x", "o" },
        key = "[s",
        callback = function()
          move.goto_previous_start("@local.scope", "locals")
        end,
      },
      {
        modes = { "n", "x", "o" },
        key = "[z",
        callback = function()
          move.goto_previous_start("@fold", "folds")
        end,
      },
      {
        modes = { "n", "x", "o" },
        key = "[A",
        callback = function()
          move.goto_previous_end("@parameter.inner", "textobjects")
        end,
      },
      {
        modes = { "n", "x", "o" },
        key = "[C",
        callback = function()
          move.goto_previous_end("@class.outer", "textobjects")
        end,
      },
      {
        modes = { "n", "x", "o" },
        key = "[F",
        callback = function()
          move.goto_previous_end("@function.outer", "textobjects")
        end,
      },
    }

    eve.nvim.bindkeys(keymaps, {})
  end,
}

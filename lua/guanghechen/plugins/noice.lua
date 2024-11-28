return {
  name = "noice.nvim",
  lazy = false,
  opts = {
    lsp = {
      progress = {
        enabled = false,
      },
      override = {
        ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
        ["vim.lsp.util.stylize_markdown"] = true,
        ["cmp.entry.get_documentation"] = true,
      },
    },
    routes = {
      {
        view = "notify",
        filter = { event = "msg_showmode" },
      },
      {
        view = "mini",
        filter = {
          event = "msg_show",
          any = {
            { find = "%d+L, %d+B" },
            { find = "; after #%d+" },
            { find = "; before #%d+" },
          },
        },
      },
    },
    presets = {
      bottom_search = true,
      command_palette = true,
      long_message_to_split = true,
      inc_rename = false,
      lsp_doc_border = false,
    },
  },
  -- stylua: ignore
  keys = {
    { "<leader>sn",  "",                                                                            desc = "+noice" },
    { "<leader>snl", function() require("noice").cmd("last") end,                                   desc = "Noice Last Message" },
    { "<leader>snh", function() require("noice").cmd("history") end,                                desc = "Noice History" },
    { "<leader>sna", function() require("noice").cmd("all") end,                                    desc = "Noice All" },
    { "<leader>snd", function() require("noice").cmd("dismiss") end,                                desc = "Dismiss All" },
    { "<C-f>",       function() if not require("noice.lsp").scroll(4) then return "<C-f>" end end,  silent = true,                           expr = true,              desc = "Scroll Forward",  mode = { "i", "n", "s" } },
    { "<C-b>",       function() if not require("noice.lsp").scroll(-4) then return "<C-b>" end end, silent = true,                           expr = true,              desc = "Scroll Backward", mode = { "i", "n", "s" } },
  },
  dependencies = {
    "nui.nvim",
    "nvim-notify",
  },
}

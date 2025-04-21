return {
  name = "noice.nvim",
  lazy = false,
  opts = {
    notify = {
      enabled = false,
    },
    lsp = {
      progress = {
        enabled = false,
      },
      override = {
        ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
        ["vim.lsp.util.stylize_markdown"] = true,
      },
    },
    routes = {
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
      lsp_doc_border = true,
    },
  },
  config = function(_, opts)
    -- HACK: noice shows messages from before it was enabled, but this is not ideal when Lazy is
    -- installing plugins, so clear the messages in this case.
    if vim.o.filetype == "lazy" then
      vim.cmd("messages clear")
    end
    require("noice").setup(opts)
  end,
  keys = {
    -- stylua: ignore start
    { "<leader>sn",  "",                                                                            desc = "+noice" },
    { "<leader>snl", function() require("noice").cmd("last") end,                                   desc = "Noice Last Message" },
    { "<leader>snh", function() require("noice").cmd("history") end,                                desc = "Noice History" },
    { "<leader>sna", function() require("noice").cmd("all") end,                                    desc = "Noice All" },
    { "<leader>snd", function() require("noice").cmd("dismiss") end,                                desc = "Dismiss All" },
    { "<C-f>",       function() if not require("noice.lsp").scroll(4) then return "<C-f>" end end,  desc = "Scroll Forward",  silent = true, expr = true, mode = { "i", "n", "s" } },
    { "<C-b>",       function() if not require("noice.lsp").scroll(-4) then return "<C-b>" end end, desc = "Scroll Backward", silent = true, expr = true, mode = { "i", "n", "s" } },
    -- stylua: ignore end
  },
  dependencies = {
    "nui.nvim",
  },
}

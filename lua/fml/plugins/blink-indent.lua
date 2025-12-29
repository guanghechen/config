---@see https://github.com/saghen/blink.indent/tree/2f4ac0d1bc642049d97da909cae02a5a5bd0beab

return {
  name = "blink.indent",
  event = "VeryLazy",
  opts = {
    blocked = {
      buftypes = {
        include_defaults = true,
      },
      filetypes = {
        include_defaults = true,
        "mason",
        "lazy",
      },
    },
    mappings = {
      border = "both",
      object_scope = "", --- "ii",
      object_scope_with_border = "", --- "ai",
      goto_top = "", --- "[i",
      goto_bottom = "", --- "]i",
    },
    static = {
      enabled = true,
      char = "│",
      priority = 1,
      highlights = {
        "f_indentline_1",
        "f_indentline_2",
        "f_indentline_3",
        "f_indentline_4",
        "f_indentline_5",
        "f_indentline_6",
        "f_indentline_7",
      },
    },
    scope = {
      enabled = false,
      char = "╎",
      priority = 1000,
      highlights = {
        "f_indentscope_1",
        "f_indentscope_2",
        "f_indentscope_3",
        "f_indentscope_4",
        "f_indentscope_5",
        "f_indentscope_6",
        "f_indentscope_7",
      },
      underline = {
        enabled = false,
        highlights = {
          "f_indent_underline_1",
          "f_indent_underline_2",
          "f_indent_underline_3",
          "f_indent_underline_4",
          "f_indent_underline_5",
          "f_indent_underline_6",
          "f_indent_underline_7",
        },
      },
    },
  },
  config = function(_, opts)
    local indent = require("blink.indent")
    indent.setup(opts)

    stl.fn.observe({ dot.context.flight.dressing_indent }, function()
      local flag = dot.context.flight.dressing_indent:snapshot() ---@type boolean
      indent.enable(flag)
    end, false)
  end,
}

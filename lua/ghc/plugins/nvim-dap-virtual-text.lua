return {
  "nvim-dap-virtual-text",
  opts = {
    virt_text_pos = "eol",
    text_prefix = "",
    separator = ",",
    error_prefix = " " .. eve.c.icon.diagnostic.Error_alt .. " ",
    info_prefix = "  " .. eve.c.icon.diagnostic.Information_alt .. " ",
  },
}

return {
  "nvim-dap-virtual-text",
  opts = {
    virt_text_pos = "eol",
    text_prefix = "",
    separator = ",",
    error_prefix = " " .. ark.icon.diagnostic.Error_alt .. " ",
    info_prefix = "  " .. ark.icon.diagnostic.Information_alt .. " ",
  },
}

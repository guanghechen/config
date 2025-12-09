return {
  "nvim-dap-virtual-text",
  opts = {
    virt_text_pos = "eol",
    text_prefix = "",
    separator = ",",
    error_prefix = " " .. dot.icon.diagnostic.Error_alt .. " ",
    info_prefix = "  " .. dot.icon.diagnostic.Information_alt .. " ",
  },
}

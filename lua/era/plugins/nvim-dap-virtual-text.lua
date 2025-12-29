return {
  name = "nvim-dap-virtual-text",
  opts = {
    virt_text_pos = "eol",
    text_prefix = "",
    separator = ",",
    error_prefix = " " .. stl.icon.diagnostic.Error_alt .. " ",
    info_prefix = "  " .. stl.icon.diagnostic.Information_alt .. " ",
  },
}

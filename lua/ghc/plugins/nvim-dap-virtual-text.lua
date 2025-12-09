return {
  "nvim-dap-virtual-text",
  opts = {
    virt_text_pos = "eol",
    text_prefix = "",
    separator = ",",
    error_prefix = " " .. std.icon.diagnostic.Error_alt .. " ",
    info_prefix = "  " .. std.icon.diagnostic.Information_alt .. " ",
  },
}

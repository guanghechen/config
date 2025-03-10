local icons = require("eve.constant.icon")

return {
  "nvim-dap-virtual-text",
  opts = {
    virt_text_pos = "eol",
    text_prefix = "",
    separator = ",",
    error_prefix = " " .. icons.diagnostic.Error_alt .. " ",
    info_prefix = "  " .. icons.diagnostic.Information_alt .. " ",
  },
}

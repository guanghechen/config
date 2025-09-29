---@alias std.e.LogLevelEnum
---| 'TRACE'
---| 'DEBUG'
---| 'INFO'
---| 'WARN'
---| 'ERROR'

---@alias std.e.FindFileScope
---|"W"
---|"C"
---|"D"

---@alias std.e.FindBufferScope
---| "A"
---| "F"
---| "L"
---| "T"

---@alias std.e.SearchFileScope
---|"W"
---|"C"
---|"D"
---|"B"

---@alias std.e.ThemeFullName
---|"catppuccin-frappe"
---|"catppuccin-latte"
---|"catppuccin-macchiato"
---|"catppuccin-mocha"
---|"gruvbox-light"
---|"gruvbox-dark"
---|"nord"
---|"onehalf-light"
---|"onehalf-dark"
---|"rosepine-main"
---|"rosepine-moon"
---|"rosepine-dawn"

---@alias std.e.ThemeFamily
---|"catppuccin"
---|"gruvbox"
---|"nord"
---|"onehalf"
---|"rosepine"

---@alias std.e.ThemeVariant
---|"frappe"
---|"latte"
---|"macchiato"
---|"mocha"
---|"light"
---|"dark"
---|"main"
---|"moon"
---|"dawn"

---@alias std.e.ThemeIntegration
---|"basic"
---|"common"
---|"lsp"
---|"nvimbar"
---|"widget"
---|"treesitter"
---|"plugin"

----------------------------------------------------------------------------------------------------

---@alias std.e.BoxPosition
---| "cursor"
---| "center"

---@alias std.e.NvimbarCompPosition
---| "left"
---| "center"
---| "right"

---@alias std.e.TermPosition
---| "bottom"
---| "right"
---| "float"

---@alias std.e.VimMode
---| "c" Command-line
---| "i" Insert
---| "n" Normal
---| "o" Operator-pending
---| "s" Select
---| "S" Select-line
---| "t" Terminal
---| "v" Visual
---| "V" Visual-line
---| "x" Visual-block

---@alias std.e.VimModeName
---| "normal"
---| "visual"
---| "insert"
---| "terminal"
---| "nterminal"
---| "replace"
---| "confirm"
---| "command"
---| "select"

---@alias std.e.WidgetStatus
---| "visible"
---| "hidden"
---| "closed"

---@alias std.e.WidgetStatuslineItemType
---| "enum"
---| "flag"
---| "popup"

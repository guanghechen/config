---@alias eve.e.TabTypeEnum
---| 'all'
---| 'diffview'
---| 'normal'

----------------------------------------------------------------------------------------------------

---@alias eve.e.FindFileScope
---|"W"
---|"C"
---|"D"

---@alias eve.e.FindBufferScope
---| "A"
---| "F"
---| "L"
---| "T"

---@alias eve.e.SearchFileScope
---|"W"
---|"C"
---|"D"
---|"B"

---@alias eve.e.Theme
---|"catppuccin-frappe"
---|"catppuccin-latte"
---|"catppuccin-macchiato"
---|"catppuccin-mocha"
---|"gruvbox-light"
---|"gruvbox-dark"
---|"nord"
---|"one-half-light"
---|"one-half-dark"
---|"rose-pine-main"
---|"rose-pine-moon"
---|"rose-pine-dawn"

---@alias eve.e.ThemeVariant
---|"dark"
---|"neutral"
---|"light"

---@alias eve.e.ThemeIntegration
---|"basic"
---|"nvimbar"
---|"widget"
---|"treesitter"
---|"plugin"

----------------------------------------------------------------------------------------------------

---@alias eve.e.BoxPosition
---| "cursor"
---| "center"

---@alias eve.e.NvimbarCompPosition
---| "left"
---| "center"
---| "right"

---@alias eve.e.ReportLevel
---| "DEBUG"
---| "INFO"
---| "WARN"
---| "ERROR"

---@alias eve.e.TermPosition
---| "bottom"
---| "right"
---| "float"

---@alias eve.e.VimMode
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

---@alias eve.e.VimModeName
---| "normal"
---| "visual"
---| "insert"
---| "terminal"
---| "nterminal"
---| "replace"
---| "confirm"
---| "command"
---| "select"

---@alias eve.e.WidgetStatus
---| "visible"
---| "hidden"
---| "closed"

---@alias eve.e.WidgetStatuslineItemType
---| "enum"
---| "flag"
---| "popup"

----------------------------------------------------------------------------------------------------

---@alias eve.e.AiProvider
---| "aoai"
---| "copilot"
---| "deepseek"

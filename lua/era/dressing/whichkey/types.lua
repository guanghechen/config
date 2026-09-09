---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.dressing.whichkey.types" ---@type string

---@meta

---@alias era.dressing.whichkey.Mode
---| "n"
---| "x"
---| "s"
---| "i"
---| "c"
---| "t"

---@alias era.dressing.whichkey.Color
---| "red"
---| "green"
---| "blue"
---| "cyan"
---| "yellow"
---| "orange"
---| "purple"
---| "grey"
---| "azure"

---@class era.dressing.whichkey.IIcon
---@field public icon                   string
---@field public color                  ?era.dressing.whichkey.Color
---@field public hl                     ?string
---@field public cat                    ?string
---@field public name                   ?string

---@class era.dressing.whichkey.IMapping
---@field public [1]                    string                                                                  -- lhs (key sequence)
---@field public [2]                    (string|fun(): nil)?                                                    -- rhs or description
---@field public desc                   string?                                                                 -- description
---@field public mode                   (string|era.dressing.whichkey.Mode[])?                                               -- modes this mapping applies to
---@field public group                  string?                                                                 -- group name for prefix keys
---@field public icon                   era.dressing.whichkey.IIcon?                                                         -- icon configuration
---@field public nowait                 boolean?                                                                -- execute immediately without waiting for timeoutlen
---@field public proxy                  string?                                                                 -- proxy prefix (e.g., "<c-w>" for "<leader>w")
---@field public expand                 (fun(): era.dressing.whichkey.IMapping[])?                                           -- function to expand dynamic mappings

---@class era.dressing.whichkey.IDisable
---@field public ft                     string[]?                       -- disable for these filetypes

---@class era.dressing.whichkey.ITrigger
---@field public [1]                    string                          -- trigger sequence ("<auto>" for automatic)
---@field public mode                   string?                         -- mode string (e.g., "nxs")

---@class era.dressing.whichkey.ISetupOpts
---@field public preset                 string?                         -- preset style ("classic")
---@field public triggers               era.dressing.whichkey.ITrigger[]?            -- trigger configurations
---@field public disable                era.dressing.whichkey.IDisable?              -- disable settings
---@field public spec                   era.dressing.whichkey.IMapping[]?            -- initial mappings
---@field public delay                  (integer | fun(ctx: { mode: era.dressing.whichkey.Mode, keys: string }): integer)? -- delay before showing (ms)

---@class era.dressing.whichkey.IAddOpts
---@field public notify                 boolean?                        -- whether to notify on add (default: true)
---@field public mode                   era.dressing.whichkey.Mode[]?                -- default modes if not specified in mapping

---@class era.dressing.whichkey.IShowOpts
---@field public keys                   string?                         -- keys to show help for
---@field public mode                   era.dressing.whichkey.Mode?                  -- mode to show help for
---@field public bufnr                  integer?                        -- buffer number

---@class era.dressing.whichkey.INode
---@field public key                    string                          -- single key (e.g., "a")
---@field public lhs                    string                          -- full key sequence (e.g., "<leader>a")
---@field public desc                   string                          -- description
---@field public icon                   era.dressing.whichkey.IIcon?                 -- icon configuration
---@field public is_group               boolean                         -- whether this is a group
---@field public rhs                    string?                         -- right hand side string (for feedkeys)
---@field public action                 fun()?                          -- wk spec defined action (direct call)
---@field public nowait                 boolean?                        -- execute immediately without waiting for timeoutlen
---@field public proxy                  string?                         -- proxy prefix
---@field public expand                 (fun(): era.dressing.whichkey.IMapping[])?   -- expand function
---@field public children               table<string, era.dressing.whichkey.INode>   -- child nodes

---@class era.dressing.whichkey.IState
---@field public opts                   era.dressing.whichkey.ISetupOpts             -- configuration
---@field public buf_trees              table<integer, table<era.dressing.whichkey.Mode, table<string, era.dressing.whichkey.INode>>> -- keymap trees
---@field public suspended              table<string, boolean>          -- suspended triggers by buf+mode
---@field public keys                   string                          -- currently pending key sequence
---@field public mode                   era.dressing.whichkey.Mode                   -- current mode
---@field public bufnr                  integer                         -- current buffer
---@field public winnr                  integer?                        -- which-key window number
---@field public popup_bufnr            integer?                        -- which-key buffer number
---@field public started_at             number                          -- timestamp of last keypress
---@field public show_popup             boolean                         -- whether popup is showing

---@class era.dressing.whichkey.IViewItem
---@field public key                    string                          -- display key
---@field public desc                   string                          -- description
---@field public icon                   string?                         -- icon text
---@field public icon_hl                string?                         -- icon highlight group
---@field public is_group               boolean                         -- whether this is a group

---@class era.dressing.whichkey.ILayout
---@field public grid                   era.dressing.whichkey.IViewItem[][]          -- 2D grid of items [row][col]
---@field public rows                   integer                         -- number of rows
---@field public cols                   integer                         -- number of columns
---@field public col_width              integer                         -- width of each column
---@field public key_width              integer                         -- max key width for alignment
---@field public content_width          integer                         -- total content width for popup sizing

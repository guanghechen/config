---@meta

---@alias era.m.wk.Mode
---| "n"
---| "x"
---| "s"
---| "i"
---| "c"
---| "t"

---@alias era.m.wk.Color
---| "red"
---| "green"
---| "blue"
---| "cyan"
---| "yellow"
---| "orange"
---| "purple"
---| "grey"
---| "azure"

---@class era.m.wk.IIcon
---@field public icon                   string
---@field public color                  ?era.m.wk.Color
---@field public hl                     ?string
---@field public cat                    ?string
---@field public name                   ?string

---@class era.m.wk.IMapping
---@field public [1]                    string                                                                  -- lhs (key sequence)
---@field public [2]                    (string|fun(): nil)?                                                    -- rhs or description
---@field public desc                   string?                                                                 -- description
---@field public mode                   (string|era.m.wk.Mode[])?                                               -- modes this mapping applies to
---@field public group                  string?                                                                 -- group name for prefix keys
---@field public icon                   era.m.wk.IIcon?                                                         -- icon configuration
---@field public nowait                 boolean?                                                                -- execute immediately without waiting for timeoutlen
---@field public proxy                  string?                                                                 -- proxy prefix (e.g., "<c-w>" for "<leader>w")
---@field public expand                 (fun(): era.m.wk.IMapping[])?                                           -- function to expand dynamic mappings

---@class era.m.wk.IDisable
---@field public ft                     string[]?                       -- disable for these filetypes

---@class era.m.wk.ITrigger
---@field public [1]                    string                          -- trigger sequence ("<auto>" for automatic)
---@field public mode                   string?                         -- mode string (e.g., "nxs")

---@class era.m.wk.ISetupOpts
---@field public preset                 string?                         -- preset style ("classic")
---@field public triggers               era.m.wk.ITrigger[]?            -- trigger configurations
---@field public disable                era.m.wk.IDisable?              -- disable settings
---@field public spec                   era.m.wk.IMapping[]?            -- initial mappings
---@field public delay                  (integer | fun(ctx: { mode: era.m.wk.Mode, keys: string }): integer)? -- delay before showing (ms)

---@class era.m.wk.IAddOpts
---@field public notify                 boolean?                        -- whether to notify on add (default: true)
---@field public mode                   era.m.wk.Mode[]?                -- default modes if not specified in mapping

---@class era.m.wk.IShowOpts
---@field public keys                   string?                         -- keys to show help for
---@field public mode                   era.m.wk.Mode?                  -- mode to show help for
---@field public bufnr                  integer?                        -- buffer number

---@class era.m.wk.INode
---@field public key                    string                          -- single key (e.g., "a")
---@field public lhs                    string                          -- full key sequence (e.g., "<leader>a")
---@field public desc                   string                          -- description
---@field public icon                   era.m.wk.IIcon?                 -- icon configuration
---@field public is_group               boolean                         -- whether this is a group
---@field public rhs                    string?                         -- right hand side string (for feedkeys)
---@field public action                 fun()?                          -- wk spec defined action (direct call)
---@field public nowait                 boolean?                        -- execute immediately without waiting for timeoutlen
---@field public proxy                  string?                         -- proxy prefix
---@field public expand                 (fun(): era.m.wk.IMapping[])?   -- expand function
---@field public children               table<string, era.m.wk.INode>   -- child nodes

---@class era.m.wk.IState
---@field public opts                   era.m.wk.ISetupOpts             -- configuration
---@field public buf_trees              table<integer, table<era.m.wk.Mode, table<string, era.m.wk.INode>>> -- keymap trees
---@field public suspended              table<string, boolean>          -- suspended triggers by buf+mode
---@field public keys                   string                          -- currently pending key sequence
---@field public mode                   era.m.wk.Mode                   -- current mode
---@field public bufnr                  integer                         -- current buffer
---@field public winnr                  integer?                        -- which-key window number
---@field public popup_bufnr            integer?                        -- which-key buffer number
---@field public started_at             number                          -- timestamp of last keypress
---@field public show_popup             boolean                         -- whether popup is showing

---@class era.m.wk.IViewItem
---@field public key                    string                          -- display key
---@field public desc                   string                          -- description
---@field public icon                   string?                         -- icon text
---@field public icon_hl                string?                         -- icon highlight group
---@field public is_group               boolean                         -- whether this is a group

---@class era.m.wk.ILayout
---@field public grid                   era.m.wk.IViewItem[][]          -- 2D grid of items [row][col]
---@field public rows                   integer                         -- number of rows
---@field public cols                   integer                         -- number of columns
---@field public col_width              integer                         -- width of each column
---@field public key_width              integer                         -- max key width for alignment
---@field public content_width          integer                         -- total content width for popup sizing

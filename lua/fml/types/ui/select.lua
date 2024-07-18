---@class fml.types.ui.select.IItem
---@field public display                string

---@class fml.types.ui.select.ILineMatchPiece
---@field public l                      integer
---@field public r                      integer

---@class fml.types.ui.select.ILineMatch
---@field public idx                    integer
---@field public score                  integer
---@field public pieces                 fml.types.ui.select.ILineMatchPiece[]

---@alias fml.types.ui.select.ILineMatchCmp
---| fun(item1: fml.types.ui.select.ILineMatch, item2: fml.types.ui.select.ILineMatch): boolean

---@alias fml.types.ui.select.IMatch
---| fun(lower_input: string, lower_texts: string[], old_matches: fml.types.ui.select.ILineMatch[]): fml.types.ui.select.ILineMatch[]

---@class fml.types.ui.select.IState
---@field public uuid                   string
---@field public title                  string
---@field public input                  fml.types.collection.IObservable
---@field public input_history          fml.types.collection.IHistory
---@field public items                  fml.types.ui.select.IItem[]
---@field public items_lowercase        string[]
---@field public max_width              integer
---@field public ticker                 fml.types.collection.ITicker
---@field public filter                 fun(self: fml.types.ui.select.IState): fml.types.ui.select.ILineMatch[]
---@field public get_current            fun(self: fml.types.ui.select.IState): fml.types.ui.select.IItem|nil, integer|nil
---@field public get_lnum               fun(self: fml.types.ui.select.IState): integer
---@field public is_visible             fun(self: fml.types.ui.select.IState): boolean
---@field public locate                 fun(self: fml.types.ui.select.IState, lnum: integer): integer
---@field public moveup                 fun(self: fml.types.ui.select.IState): integer
---@field public movedown               fun(self: fml.types.ui.select.IState): integer
---@field public toggle_visible         fun(self: fml.types.ui.select.IState, visible?: boolean): nil
---@field public update_items           fun(self: fml.types.ui.select.IState, items: fml.types.ui.select.IItem[]): nil

---@class fml.types.ui.select.main.IRenderLineParams
---@field public item                   fml.types.ui.select.IItem
---@field public match                  fml.types.ui.select.ILineMatch

---@class fml.types.ui.select.IMain
---@field public create_buf_as_needed   fun(self: fml.types.ui.select.IMain): integer
---@field public place_lnum_sign        fun(self: fml.types.ui.select.IMain): integer|nil
---@field public render                 fun(self: fml.types.ui.select.IMain): nil

---@class fml.types.ui.select.IInput
---@field public create_buf_as_needed   fun(self: fml.types.ui.select.IInput): integer

---@class fml.types.ui.select.ISelect
---@field public close                  fun(self: fml.types.ui.select.ISelect): nil
---@field public open                   fun(self: fml.types.ui.select.ISelect): nil
---@field public toggle                 fun(self: fml.types.ui.select.ISelect): nil

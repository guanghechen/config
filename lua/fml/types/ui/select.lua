---@class fml.types.ui.select.IItem
---@field public uuid                   string
---@field public display                string
---@field public lower                  string

---@class fml.types.ui.select.IFileItem
---@field public display                string
---@field public filename               ?string
---@field public icon                   ?string
---@field public icon_hl                ?string

---@class fml.types.ui.select.ILineMatchPiece
---@field public l                      integer
---@field public r                      integer

---@class fml.types.ui.select.ILineMatch
---@field public idx                    integer
---@field public score                  integer
---@field public pieces                 fml.types.ui.select.ILineMatchPiece[]

---@class fml.types.ui.select.main.IRenderLineParams
---@field public item                   fml.types.ui.select.IItem
---@field public match                  fml.types.ui.select.ILineMatch

---@alias fml.types.ui.select.ILineMatchCmp
---| fun(item1: fml.types.ui.select.ILineMatch, item2: fml.types.ui.select.ILineMatch): boolean

---@alias fml.types.ui.select.IMatch
---| fun(lower_input: string, items: fml.types.ui.select.IItem[], old_matches: fml.types.ui.select.ILineMatch[]): fml.types.ui.select.ILineMatch[]

---@alias fml.types.ui.select.IOnClose
---| fun(): nil

---@alias fml.types.ui.select.IOnConfirm
---| fun(item: fml.types.ui.select.IItem, idx: number): boolean

---@alias fml.types.ui.select.main.IRenderLine
---| fun(params: fml.types.ui.select.main.IRenderLineParams): string

---@class fml.types.ui.select.IState
---@field public uuid                   string
---@field public title                  string
---@field public input                  fml.types.collection.IObservable
---@field public input_history          fml.types.collection.IHistory|nil
---@field public items                  fml.types.ui.select.IItem[]
---@field public max_width              integer
---@field public ticker                 fml.types.collection.ITicker
---@field public filter                 fun(self: fml.types.ui.select.IState): fml.types.ui.select.ILineMatch[]
---@field public get_current            fun(self: fml.types.ui.select.IState): fml.types.ui.select.IItem|nil, integer|nil
---@field public is_visible             fun(self: fml.types.ui.select.IState): boolean
---@field public locate                 fun(self: fml.types.ui.select.IState, lnum: integer): integer
---@field public moveup                 fun(self: fml.types.ui.select.IState): integer
---@field public movedown               fun(self: fml.types.ui.select.IState): integer
---@field public on_confirmed           fun(self: fml.types.ui.select.IState, item: fml.types.ui.select.IItem, idx: integer): nil
---@field public toggle_visible         fun(self: fml.types.ui.select.IState, visible?: boolean): nil
---@field public update_items           fun(self: fml.types.ui.select.IState, items: fml.types.ui.select.IItem[]): nil

---@class fml.types.ui.select.main.IRenderParams
---@field public force                  ?boolean

---@class fml.types.ui.select.IMain
---@field public create_buf_as_needed   fun(self: fml.types.ui.select.IMain): integer
---@field public place_lnum_sign        fun(self: fml.types.ui.select.IMain): integer|nil
---@field public render                 fun(self: fml.types.ui.select.IMain, opts?: fml.types.ui.select.main.IRenderParams): nil

---@class fml.types.ui.select.IInput
---@field public create_buf_as_needed   fun(self: fml.types.ui.select.IInput): integer
---@field public reset_input            fun(self: fml.types.ui.select.IInput, input: string): nil

---@class fml.types.ui.select.ISelect
---@field public state                  fml.types.ui.select.IState
---@field public close                  fun(self: fml.types.ui.select.ISelect): nil
---@field public open                   fun(self: fml.types.ui.select.ISelect): nil
---@field public toggle                 fun(self: fml.types.ui.select.ISelect): nil

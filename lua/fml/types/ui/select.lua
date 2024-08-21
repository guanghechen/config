---@class fml.types.ui.select.IItem
---@field public group                  string|nil
---@field public uuid                   string
---@field public text                   string
---@field public text_lower             string|nil

---@alias fml.types.ui.select.preview.IFetchData
---| fun(item: fml.types.ui.select.IItem): fml.ui.search.preview.IData

---@alias fml.types.ui.select.preview.IPatchData
---| fun(item: fml.types.ui.select.IItem, last_item: fml.types.ui.select.IItem, last_data: fml.ui.search.preview.IData|nil): fml.ui.search.preview.IData

---@class fml.types.ui.select.ILineMatch
---@field public order                  integer
---@field public uuid                   string
---@field public score                  integer
---@field public pieces                 fml.std.oxi.search.IMatchPoint[]

---@alias fml.types.ui.select.ILineMatchCmp
---| fun(item1: fml.types.ui.select.ILineMatch, item2: fml.types.ui.select.ILineMatch): boolean

---@class fml.types.ui.select.IMatchParams
---@field public input                  string
---@field public case_sensitive         boolean
---@field public item_map               table<string, fml.types.ui.select.IItem>
---@field public old_matches            fml.types.ui.select.ILineMatch[]

---@alias fml.types.ui.select.IMatch
---| fun(params: fml.types.ui.select.IMatchParams): fml.types.ui.select.ILineMatch[]

---@alias fml.types.ui.select.IOnConfirm
---| fun(item: fml.types.ui.select.IItem): boolean

---@alias fml.types.ui.select.IRenderItem
---| fun(item: fml.types.ui.select.IItem, match: fml.types.ui.select.ILineMatch): string, fml.types.ui.IInlineHighlight[]

---@class fml.types.ui.ISelect
---@field public state                  fml.types.ui.search.IState
---@field public get_winnr_input        fun(self: fml.types.ui.ISelect): integer|nil
---@field public get_winnr_main         fun(self: fml.types.ui.ISelect): integer|nil
---@field public get_winnr_preview      fun(self: fml.types.ui.ISelect): integer|nil
---@field public update_data            fun(self: fml.types.ui.ISelect, items: fml.types.ui.select.IItem[]): nil
---@field public close                  fun(self: fml.types.ui.ISelect): nil
---@field public focus                  fun(self: fml.types.ui.ISelect): nil
---@field public open                   fun(self: fml.types.ui.ISelect): nil
---@field public resume                 fun(self: fml.types.ui.ISelect): nil
---@field public toggle                 fun(self: fml.types.ui.ISelect): nil

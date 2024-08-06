---@alias fml.types.ui.search.IOnClose
---| fun(): nil

---@alias fml.types.ui.search.IOnConfirm
---| fun(item: fml.types.ui.search.IItem): boolean

---@alias fml.types.ui.search.main.IOnRendered
---| fun(): nil

---@alias fml.types.ui.search.IFetchItemsCallback
---| fun(ok: true, items: fml.types.ui.search.IItem[]|nil): nil
---| fun(ok: false, error: string|nil): nil

---@alias fml.types.ui.search.IFetchItems
---| fun(input: string, callback: fml.types.ui.search.IFetchItemsCallback): nil

---@class fml.types.ui.search.IItem
---@field public group                  string|nil
---@field public uuid                   string
---@field public text                   string
---@field public highlights             fml.types.ui.printer.ILineHighlight[]

---@class fml.types.ui.search.IState
---@field public uuid                   string
---@field public title                  string
---@field public items                  fml.types.ui.search.IItem[]
---@field public input                  fml.types.collection.IObservable
---@field public input_history          fml.types.collection.IHistory|nil
---@field public visible                fml.types.collection.IObservable
---@field public dirty_items            fml.types.collection.IObservable
---@field public dirty_main             fml.types.collection.IObservable
---@field public max_width              integer
---@field public get_current            fun(self: fml.types.ui.search.IState): fml.types.ui.search.IItem|nil, integer
---@field public locate                 fun(self: fml.types.ui.search.IState): integer
---@field public mark_items_dirty       fun(self: fml.types.ui.search.IState): nil
---@field public moveup                 fun(self: fml.types.ui.search.IState): integer
---@field public movedown               fun(self: fml.types.ui.search.IState): integer

---@class fml.types.ui.search.IMain
---@field public state                  fml.types.ui.search.IState
---@field public create_buf_as_needed   fun(self: fml.types.ui.search.IMain): integer
---@field public destroy                fun(self: fml.types.ui.search.IMain): nil
---@field public place_lnum_sign        fun(self: fml.types.ui.search.IMain): integer|nil
---@field public render                 fun(self: fml.types.ui.search.IMain, force?: boolean): nil

---@class fml.types.ui.search.IInput
---@field public create_buf_as_needed   fun(self: fml.types.ui.search.IInput): integer
---@field public destroy                fun(self: fml.types.ui.search.IInput): nil
---@field public reset_input            fun(self: fml.types.ui.search.IInput, input?: string): nil

---@class fml.types.ui.search.ISearch
---@field public state                  fml.types.ui.search.IState
---@field public get_winnr_input        fun(self: fml.types.ui.search.ISearch): integer|nil
---@field public get_winnr_main         fun(self: fml.types.ui.search.ISearch): integer|nil
---@field public close                  fun(self: fml.types.ui.search.ISearch): nil
---@field public focus                  fun(self: fml.types.ui.search.ISearch): nil
---@field public open                   fun(self: fml.types.ui.search.ISearch): nil
---@field public toggle                 fun(self: fml.types.ui.search.ISearch): nil
